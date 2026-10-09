// edss-loadbench uses bounded histograms and measures complete API responses.
// Timing is operational wall time, not the simulated business clock.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

const maxBody = 8 << 20

var bounds = [...]float64{1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 30000, 60000, 120000}

type observation struct {
	ms      float64
	bytes   int64
	status  int
	failure string
}

type aggregate struct {
	Count    int64                  `json:"requests"`
	Errors   int64                  `json:"errors"`
	Bytes    int64                  `json:"response_bytes"`
	MaxMS    float64                `json:"max_ms"`
	SumMS    float64                `json:"latency_sum_ms"`
	Buckets  [len(bounds) + 1]int64 `json:"latency_buckets"`
	Status   map[int]int64          `json:"http_status"`
	Failures map[string]int64       `json:"failure_types"`
}

func (a *aggregate) add(s observation) {
	a.Count++
	a.Bytes += s.bytes
	a.SumMS += s.ms
	if s.ms > a.MaxMS {
		a.MaxMS = s.ms
	}
	if a.Status == nil {
		a.Status = make(map[int]int64)
		a.Failures = make(map[string]int64)
	}
	a.Status[s.status]++
	if s.failure != "" {
		a.Errors++
		a.Failures[s.failure]++
	}
	i := len(bounds)
	for k, b := range bounds {
		if s.ms <= b {
			i = k
			break
		}
	}
	a.Buckets[i]++
}
func (a *aggregate) merge(b aggregate) {
	if a.Status == nil {
		a.Status = make(map[int]int64)
		a.Failures = make(map[string]int64)
	}
	a.Count += b.Count
	a.Errors += b.Errors
	a.Bytes += b.Bytes
	a.SumMS += b.SumMS
	if b.MaxMS > a.MaxMS {
		a.MaxMS = b.MaxMS
	}
	for i, n := range b.Buckets {
		a.Buckets[i] += n
	}
	for k, n := range b.Status {
		a.Status[k] += n
	}
	for k, n := range b.Failures {
		a.Failures[k] += n
	}
}
func (a aggregate) percentile(p float64) float64 {
	if a.Count == 0 {
		return 0
	}
	target := int64(math.Ceil(float64(a.Count) * p))
	var n int64
	for i, count := range a.Buckets {
		n += count
		if n >= target {
			if i < len(bounds) {
				return math.Min(bounds[i], a.MaxMS)
			}
			return a.MaxMS
		}
	}
	return a.MaxMS
}

type envelope struct {
	Code *int            `json:"code"`
	Data json.RawMessage `json:"data"`
}

func call(client *http.Client, method, endpoint string, body []byte) observation {
	started := time.Now()
	result := observation{}
	request, err := http.NewRequest(method, endpoint, bytes.NewReader(body))
	if err != nil {
		result.failure = "request"
		return result
	}
	request.Header.Set("Accept", "application/json")
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}
	response, err := client.Do(request)
	if err != nil {
		result.ms = float64(time.Since(started)) / float64(time.Millisecond)
		result.failure = "transport_or_timeout"
		return result
	}
	defer response.Body.Close()
	result.status = response.StatusCode
	raw, err := io.ReadAll(io.LimitReader(response.Body, maxBody+1))
	result.bytes = int64(len(raw))
	if err != nil || len(raw) > maxBody {
		result.failure = "body"
	} else {
		var env envelope
		if json.Unmarshal(raw, &env) != nil || env.Code == nil || len(env.Data) == 0 {
			result.failure = "invalid_envelope"
		} else if response.StatusCode != http.StatusOK {
			result.failure = "http_status"
		} else if *env.Code != 0 {
			result.failure = "business_code"
		}
	}
	result.ms = float64(time.Since(started)) / float64(time.Millisecond)
	return result
}

func phase(parent context.Context, client *http.Client, base string, paths []string, concurrency int, duration time.Duration, rps float64) ([]aggregate, time.Duration) {
	ctx, cancel := context.WithTimeout(parent, duration)
	defer cancel()
	var tickets <-chan time.Time
	if rps > 0 {
		tick := time.NewTicker(time.Duration(float64(time.Second) / rps))
		defer tick.Stop()
		tickets = tick.C
	}
	results := make([][]aggregate, concurrency)
	var workers sync.WaitGroup
	started := time.Now()
	for i := 0; i < concurrency; i++ {
		workers.Add(1)
		go func(worker int) {
			defer workers.Done()
			local := make([]aggregate, len(paths))
			next := worker % len(paths)
			defer func() { results[worker] = local }()
			for {
				if tickets != nil {
					select {
					case <-ctx.Done():
						return
					case <-tickets:
					}
				}
				if ctx.Err() != nil {
					return
				}
				// Stop launching at the deadline; drain complete responses using Client.Timeout.
				local[next].add(call(client, http.MethodGet, base+paths[next], nil))
				next = (next + 1) % len(paths)
			}
		}(i)
	}
	workers.Wait()
	elapsed := time.Since(started)
	combined := make([]aggregate, len(paths))
	for _, local := range results {
		for i, a := range local {
			combined[i].merge(a)
		}
	}
	return combined, elapsed
}

type summary struct {
	aggregate
	RPS        float64 `json:"request_rps"`
	SuccessRPS float64 `json:"success_rps"`
	ErrorPct   float64 `json:"error_pct"`
	P50        float64 `json:"p50_ms_upper_bound"`
	P95        float64 `json:"p95_ms_upper_bound"`
	P99        float64 `json:"p99_ms_upper_bound"`
}

func summarize(a aggregate, elapsed time.Duration) summary {
	s := summary{aggregate: a, P50: a.percentile(.5), P95: a.percentile(.95), P99: a.percentile(.99)}
	if elapsed > 0 {
		s.RPS = float64(a.Count) / elapsed.Seconds()
		s.SuccessRPS = float64(a.Count-a.Errors) / elapsed.Seconds()
	}
	if a.Count > 0 {
		s.ErrorPct = float64(a.Errors) / float64(a.Count) * 100
	}
	return s
}
func finite(n float64) bool { return !math.IsNaN(n) && !math.IsInf(n, 0) }
func validBase(s string) (*url.URL, error) {
	u, err := url.Parse(s)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Hostname() == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || (u.Path != "" && u.Path != "/") {
		return nil, fmt.Errorf("base must be an HTTP(S) origin without credentials")
	}
	return u, nil
}
func validPath(s string) bool {
	u, err := url.Parse(s)
	if err != nil || u.IsAbs() || u.Host != "" || u.Fragment != "" || !strings.HasPrefix(u.Path, "/api/v1/") || strings.Contains(u.Path, "..") {
		return false
	}
	for k := range u.Query() {
		switch strings.ToLower(k) {
		case "token", "password", "authorization", "cookie", "api_key", "access_token":
			return false
		}
	}
	return true
}

func run() int {
	concurrency := flag.Int("c", 32, "concurrent workers")
	duration := flag.Float64("d", 15, "measured launch duration in seconds; response drain is included in actual time")
	baseArg := flag.String("base", "http://localhost:8080", "API origin")
	profile := flag.String("profile", "public", "public or business")
	pathsArg := flag.String("paths", "", "comma-separated GET API paths (overrides profile)")
	warmup := flag.Float64("warmup", 5, "warmup seconds, excluded from report")
	timeout := flag.Float64("timeout", 10, "request timeout seconds")
	rate := flag.Float64("rps", 0, "total request start rate limit; zero means unrestricted")
	jsonPath := flag.String("json", "", "new private JSON report file")
	maxError := flag.Float64("max-error-pct", 1, "fail if an endpoint error percentage exceeds threshold")
	maxP95 := flag.Float64("max-p95-ms", 1000, "fail if approximate endpoint p95 exceeds threshold")
	flag.Parse()
	if *concurrency < 1 || *concurrency > 1024 || !finite(*duration) || *duration < 0.001 || *duration > 86400 || !finite(*warmup) || *warmup < 0 || *warmup > 3600 || !finite(*timeout) || *timeout < 0.001 || *timeout > 300 || !finite(*rate) || *rate < 0 || *rate > 1000000 || !finite(*maxError) || *maxError < 0 || *maxError > 100 || !finite(*maxP95) || *maxP95 <= 0 {
		fmt.Fprintln(os.Stderr, "Invalid concurrency, duration, rate or threshold")
		return 2
	}
	base := strings.TrimRight(*baseArg, "/")
	origin, err := validBase(base)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	paths := []string{"/api/v1/screen/snapshot", "/health"}
	if *profile == "business" {
		paths = []string{"/api/v1/screen/snapshot", "/api/v1/workbench/overview", "/api/v1/workbench/operations", "/api/v1/todos?size=20"}
	} else if *profile != "public" {
		fmt.Fprintln(os.Stderr, "Invalid profile")
		return 2
	}
	if *pathsArg != "" {
		paths = nil
		seen := map[string]bool{}
		for _, p := range strings.Split(*pathsArg, ",") {
			p = strings.TrimSpace(p)
			if !validPath(p) || seen[p] {
				fmt.Fprintln(os.Stderr, "Invalid or duplicate API path")
				return 2
			}
			paths = append(paths, p)
			seen[p] = true
		}
	}
	if len(paths) > 64 {
		fmt.Fprintln(os.Stderr, "At most 64 paths are supported")
		return 2
	}
	if *jsonPath != "" {
		if _, err := os.Lstat(*jsonPath); !os.IsNotExist(err) {
			fmt.Fprintln(os.Stderr, "JSON report target already exists or is inaccessible")
			return 2
		}
	}
	jar, _ := cookiejar.New(nil)
	transport := &http.Transport{Proxy: http.ProxyFromEnvironment, MaxIdleConns: *concurrency * 2, MaxIdleConnsPerHost: *concurrency * 2, MaxConnsPerHost: *concurrency, IdleConnTimeout: 90 * time.Second}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Jar: jar, Timeout: time.Duration(*timeout * float64(time.Second)), CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
	if probe := call(client, http.MethodGet, base+"/health", nil); probe.failure != "" {
		fmt.Fprintln(os.Stderr, "Health preflight failed:", probe.failure)
		return 1
	}
	username, password := os.Getenv("EDSS_LOAD_USERNAME"), os.Getenv("EDSS_LOAD_PASSWORD")
	if *profile == "business" || username != "" || password != "" {
		if username == "" || password == "" {
			fmt.Fprintln(os.Stderr, "Set EDSS_LOAD_USERNAME and EDSS_LOAD_PASSWORD for business requests")
			return 2
		}
		credentials, _ := json.Marshal(map[string]string{"username": username, "password": password})
		login := call(client, http.MethodPost, base+"/api/v1/auth/login", credentials)
		for i := range credentials {
			credentials[i] = 0
		}
		if login.failure != "" {
			fmt.Fprintln(os.Stderr, "Login preflight failed:", login.failure)
			return 1
		}
		authenticated := false
		for _, cookie := range jar.Cookies(origin) {
			if cookie.Name == "edss_sid" {
				authenticated = true
			}
		}
		if !authenticated {
			fmt.Fprintln(os.Stderr, "Login did not provide a usable session Cookie")
			return 1
		}
		defer func() {
			if r := call(client, http.MethodPost, base+"/api/v1/auth/logout", []byte("{}")); r.failure != "" {
				fmt.Fprintln(os.Stderr, "Session cleanup failed:", r.failure)
			}
		}()
	}
	for _, p := range paths {
		if r := call(client, http.MethodGet, base+p, nil); r.failure != "" {
			fmt.Fprintln(os.Stderr, "Endpoint preflight failed:", p, r.failure)
			return 1
		}
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if *warmup > 0 {
		phase(ctx, client, base, paths, *concurrency, time.Duration(*warmup*float64(time.Second)), *rate)
	}
	if ctx.Err() != nil {
		fmt.Fprintln(os.Stderr, "Interrupted before measured phase")
		return 1
	}
	stats, elapsed := phase(ctx, client, base, paths, *concurrency, time.Duration(*duration*float64(time.Second)), *rate)
	total := aggregate{}
	summaries := make(map[string]summary, len(paths))
	passed := ctx.Err() == nil
	fmt.Printf("profile=%s c=%d configured_s=%.3f actual_s=%.3f rate_limit=%.2f\n", *profile, *concurrency, *duration, elapsed.Seconds(), *rate)
	fmt.Printf("%-48s %9s %10s %10s %10s %10s\n", "path", "requests", "success/s", "p95<=ms", "p99<=ms", "error%")
	for i, p := range paths {
		s := summarize(stats[i], elapsed)
		summaries[p] = s
		total.merge(stats[i])
		fmt.Printf("%-48s %9d %10.1f %10.1f %10.1f %10.2f\n", p, s.Count, s.SuccessRPS, s.P95, s.P99, s.ErrorPct)
		if s.Count == 0 || s.ErrorPct > *maxError || s.P95 > *maxP95 {
			passed = false
		}
	}
	report := struct {
		CompletedAt       string               `json:"completed_at"`
		Base              string               `json:"base"`
		Profile           string               `json:"profile"`
		Concurrency       int                  `json:"concurrency"`
		ConfiguredSeconds float64              `json:"configured_seconds"`
		ActualSeconds     float64              `json:"actual_seconds"`
		WarmupSeconds     float64              `json:"warmup_seconds"`
		RateLimit         float64              `json:"rate_limit"`
		MaxErrorPct       float64              `json:"max_error_pct"`
		MaxP95MS          float64              `json:"max_p95_ms"`
		LatencyBounds     [len(bounds)]float64 `json:"latency_bounds_ms"`
		Endpoints         map[string]summary   `json:"endpoints"`
		Total             summary              `json:"total"`
		Passed            bool                 `json:"passed"`
	}{time.Now().UTC().Format(time.RFC3339Nano), base, *profile, *concurrency, *duration, elapsed.Seconds(), *warmup, *rate, *maxError, *maxP95, bounds, summaries, summarize(total, elapsed), passed}
	if *jsonPath != "" {
		out, err := os.OpenFile(*jsonPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			fmt.Fprintln(os.Stderr, "Cannot create JSON report")
			return 1
		}
		writeErr := json.NewEncoder(out).Encode(report)
		syncErr := out.Sync()
		closeErr := out.Close()
		if writeErr != nil || syncErr != nil || closeErr != nil {
			os.Remove(*jsonPath)
			fmt.Fprintln(os.Stderr, "Cannot write JSON report")
			return 1
		}
	}
	if !passed {
		fmt.Fprintln(os.Stderr, "Load thresholds failed or measurement was interrupted")
		return 1
	}
	return 0
}
func main() { os.Exit(run()) }
