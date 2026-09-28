// edss-loadbench —— 只读公开端点压测基线工具(纯 stdlib,零三方依赖)。
// 混合负载:worker 按序号奇偶分流 GET /api/v1/screen/snapshot 与 GET /health
// (契约公开端点,免会话;大屏快照为重读端点,/health 为下限参照)。
//
// 用法: go run ./cmd/loadbench -c 32 -d 15 -base http://localhost:8080
// 输出: 每端点 + 合计的 n / rps / p50 / p95 / p99 / max / err%。
//
// 注:延迟计时用 time.Now 属"传输/运维层墙钟"(与 requestlog.go 同类),
// 非业务时基;机械自查豁免清单若扫到此文件,由主控补豁免条目。
package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"sync"
	"time"
)

var targets = []string{"/api/v1/screen/snapshot", "/health"}

type sample struct {
	path string
	ms   float64
	err  bool
}

func main() {
	c := flag.Int("c", 32, "并发 worker 数")
	d := flag.Float64("d", 15, "压测时长(秒)")
	base := flag.String("base", "http://localhost:8080", "目标 base URL")
	flag.Parse()
	if *c < 1 || *d <= 0 {
		fmt.Fprintln(os.Stderr, "用法: -c>=1 -d>0")
		os.Exit(2)
	}

	tr := &http.Transport{
		MaxIdleConns:        *c * 2,
		MaxIdleConnsPerHost: *c * 2, // 关键:默认 2 会把 keep-alive 打回短连接,压不出真并发
		IdleConnTimeout:     90 * time.Second,
	}
	client := &http.Client{Transport: tr, Timeout: 10 * time.Second}

	// 探活:base 不可达直接退出,免得空跑 15s 全是 dial error 还误以为有基线
	if resp, err := client.Get(*base + "/health"); err != nil {
		fmt.Fprintf(os.Stderr, "探活失败 %s/health: %v\n", *base, err)
		os.Exit(1)
	} else {
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}

	dur := time.Duration(*d * float64(time.Second))
	deadline := time.Now().Add(dur)
	results := make([][]sample, *c)
	var wg sync.WaitGroup
	for i := 0; i < *c; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			path := targets[i%len(targets)] // 奇偶分流,两端点各约一半并发
			url := *base + path
			var ss []sample
			for time.Now().Before(deadline) {
				t0 := time.Now()
				resp, err := client.Get(url)
				ms := float64(time.Since(t0)) / float64(time.Millisecond)
				s := sample{path: path, ms: ms}
				if err != nil {
					s.err = true
				} else {
					// 排空+关闭:连接可复用;非 200 计 err(包络 code 不细判)
					io.Copy(io.Discard, resp.Body)
					resp.Body.Close()
					if resp.StatusCode != http.StatusOK {
						s.err = true
					}
				}
				ss = append(ss, s)
			}
			results[i] = ss
		}(i)
	}
	wg.Wait()
	actual := dur // 设计时长;尾延迟被 client.Timeout 截断,实测偏差计入报告口径

	var all []sample
	for _, ss := range results {
		all = append(all, ss...)
	}
	fmt.Printf("base=%s c=%d d=%gs  samples=%d\n\n", *base, *c, *d, len(all))
	fmt.Printf("%-28s %8s %9s %8s %8s %8s %8s %7s\n", "path", "n", "rps", "p50ms", "p95ms", "p99ms", "maxms", "err%")
	for _, p := range targets {
		report(p, filter(all, p), actual)
	}
	report("TOTAL", all, actual)
}

func filter(all []sample, path string) []sample {
	var out []sample
	for _, s := range all {
		if s.path == path {
			out = append(out, s)
		}
	}
	return out
}

func report(name string, ss []sample, dur time.Duration) {
	if len(ss) == 0 {
		fmt.Printf("%-28s %8d %9s %8s %8s %8s %8s %7s\n", name, 0, "-", "-", "-", "-", "-", "-")
		return
	}
	lat := make([]float64, 0, len(ss))
	errs := 0
	for _, s := range ss {
		if s.err {
			errs++
			continue // 错误样本不计延迟分位(超时 10s 会污染 p99 失真)
		}
		lat = append(lat, s.ms)
	}
	sort.Float64s(lat)
	pct := func(p float64) float64 {
		if len(lat) == 0 {
			return 0
		}
		idx := int(p / 100 * float64(len(lat)))
		if idx >= len(lat) {
			idx = len(lat) - 1
		}
		return lat[idx]
	}
	max := 0.0
	if len(lat) > 0 {
		max = lat[len(lat)-1]
	}
	fmt.Printf("%-28s %8d %9.1f %8.1f %8.1f %8.1f %8.1f %6.2f%%\n",
		name, len(ss), float64(len(ss))/dur.Seconds(),
		pct(50), pct(95), pct(99), max, float64(errs)/float64(len(ss))*100)
}
