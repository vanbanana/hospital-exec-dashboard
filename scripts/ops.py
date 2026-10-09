#!/usr/bin/env python3
"""Local EDSS operations; credentials and row contents never enter reports."""
import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import functools
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ('sys', 'dim', 'dwd', 'dws', 'ads', 'sim')


class OpsError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def number(name, default, minimum=0):
    try:
        value = float(os.environ.get(name, default))
        if not math.isfinite(value) or value < minimum:
            raise ValueError()
        return value
    except ValueError:
        raise OpsError(f'{name} must be a finite number >= {minimum}') from None


def database(value):
    if not re.fullmatch(r'[a-z][a-z0-9_]{0,62}', value):
        raise OpsError('Invalid database name')
    return value


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def event(kind, **fields):
    print(json.dumps({'time': utc(), 'event': kind, **fields}, ensure_ascii=False), flush=True)


def private_dir(path):
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.is_symlink():
        raise OpsError('Operation directory must not be a symlink')
    return path.resolve()


def atomic_json(path, value):
    fd, name = tempfile.mkstemp(prefix='.edss-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as out:
            json.dump(value, out, ensure_ascii=False, sort_keys=True)
            out.write('\n')
            out.flush()
            os.fsync(out.fileno())
        os.replace(name, path)
        sync_dir(path.parent)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(name)


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def read_json(path):
    try:
        with path.open() as src:
            value = json.load(src)
            if not isinstance(value, dict):
                raise ValueError()
            return value
    except FileNotFoundError:
        return None
    except (ValueError, OSError):
        raise OpsError(f'Unreadable JSON state: {path.name}') from None


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as src:
        for chunk in iter(lambda: src.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def compose():
    command = ['docker', 'compose', '--project-name', os.environ.get('EDSS_DEV_PROJECT', 'edss-dev')]
    for name in os.environ.get('EDSS_COMPOSE_FILES', 'deploy/docker-compose.yml').split(','):
        p = Path(name.strip())
        if not name.strip() or not p.is_file():
            raise OpsError('EDSS_COMPOSE_FILES must list existing Compose files')
        command += ['-f', str(p)]
    if os.environ.get('EDSS_ENV_FILE'):
        p = Path(os.environ['EDSS_ENV_FILE'])
        if not p.is_file():
            raise OpsError('EDSS_ENV_FILE is not readable')
        command += ['--env-file', str(p)]
    return command


def execute(command, *, stdin=None, stdout=subprocess.PIPE):
    try:
        result = subprocess.run(command, stdin=stdin, stdout=stdout, stderr=subprocess.PIPE,
                                timeout=number('EDSS_BACKUP_TIMEOUT_SECONDS', 1800, 1), check=False)
    except subprocess.TimeoutExpired:
        raise OpsError('Operation timed out') from None
    if result.returncode:
        # Compose errors can echo interpolated environment values. Do not forward stderr.
        raise OpsError(f'Container operation failed (exit {result.returncode}); inspect local service logs')
    return result.stdout


@functools.lru_cache(maxsize=1)
def source_database():
    try:
        config = json.loads(execute(compose() + ['config', '--format', 'json']))
        dsn = config['services']['backend']['environment']['DATABASE_URL']
        parsed = urllib.parse.urlsplit(dsn)
        if parsed.scheme not in ('postgres', 'postgresql') or parsed.hostname != 'db' or parsed.port not in (None, 5432):
            raise ValueError()
        name = database(urllib.parse.unquote(parsed.path.removeprefix('/')))
    except (KeyError, ValueError, TypeError):
        raise OpsError('Backup source must be the Compose db service via a PostgreSQL URL') from None
    assertion = os.environ.get('EDSS_DB_NAME')
    if assertion is not None and assertion != name:
        raise OpsError('EDSS_DB_NAME does not match the configured backend database')
    return name


def pg(*args):
    return compose() + ['exec', '-T', 'db', *args]


def backup(destination):
    name = source_database()
    destination = destination.absolute()
    private_dir(destination.parent)
    manifest_path = Path(str(destination) + '.json')
    if any(os.path.lexists(p) for p in (destination, manifest_path, Path(str(destination) + '.partial'))):
        raise OpsError('Backup output already exists')
    if shutil.disk_usage(destination.parent).free < number('EDSS_BACKUP_MIN_FREE_BYTES', 1073741824, 1):
        raise OpsError('Insufficient backup disk space')
    started, begin = utc(), time.monotonic()
    fd, temporary = tempfile.mkstemp(prefix='.edss-dump-', dir=destination.parent)
    published = False
    published_meta = False
    try:
        with os.fdopen(fd, 'wb') as out:
            execute(pg('pg_dump', '-U', 'postgres', '-d', name, '-Fc', '--lock-wait-timeout=15s'), stdout=out)
            out.flush()
            os.fsync(out.fileno())
        temp = Path(temporary)
        if not temp.stat().st_size:
            raise OpsError('Empty backup archive')
        with temp.open('rb') as src:
            execute(pg('pg_restore', '--list'), stdin=src, stdout=subprocess.DEVNULL)
        checksum = digest(temp)
        manifest = {'format_version': 1, 'database': name, 'file': destination.name,
                    'started_at': started, 'completed_at': utc(), 'duration_s': time.monotonic() - begin,
                    'bytes': temp.stat().st_size, 'sha256': checksum}
        # A hard link publishes a complete file atomically and refuses races/overwrites.
        os.link(temp, destination)
        published = True
        fd_meta, temporary_meta = tempfile.mkstemp(prefix='.edss-manifest-', dir=destination.parent)
        try:
            with os.fdopen(fd_meta, 'w') as out:
                json.dump(manifest, out, sort_keys=True)
                out.write('\n')
                out.flush()
                os.fsync(out.fileno())
            os.link(temporary_meta, manifest_path)
            published_meta = True
        finally:
            os.unlink(temporary_meta)
        sync_dir(destination.parent)
        return manifest
    except BaseException:
        if published:
            destination.unlink(missing_ok=True)
        if published_meta:
            manifest_path.unlink(missing_ok=True)
        raise
    finally:
        Path(temporary).unlink(missing_ok=True)


def validate_archive(source):
    if not source.is_file() or not source.stat().st_size:
        raise OpsError('Backup archive is not readable or empty')
    manifest = read_json(Path(str(source) + '.json'))
    if manifest is None:
        if os.environ.get('EDSS_ALLOW_LEGACY_BACKUP') != '1':
            raise OpsError('Manifest missing; legacy archives require EDSS_ALLOW_LEGACY_BACKUP=1')
    elif (manifest.get('format_version') != 1 or manifest.get('bytes') != source.stat().st_size
          or manifest.get('sha256') != digest(source)):
        raise OpsError('Backup checksum or manifest verification failed')
    with source.open('rb') as src:
        execute(pg('pg_restore', '--list'), stdin=src, stdout=subprocess.DEVNULL)
    return manifest


def restore(source, target):
    target = database(target)
    manifest = validate_archive(source)
    blocked = {'hospital_edss', 'hospital_edss_w', 'postgres', 'template0', 'template1',
               source_database()}
    if manifest:
        blocked.add(manifest.get('database'))
    if target in blocked:
        raise OpsError('Restore requires a new, non-source database')
    execute(pg('createdb', '-U', 'postgres', target))
    try:
        with source.open('rb') as src:
            execute(pg('pg_restore', '-U', 'postgres', '-d', target, '--exit-on-error', '--single-transaction'),
                    stdin=src, stdout=subprocess.DEVNULL)
    except OpsError:
        raise OpsError('Restore failed; new database retained for diagnosis; existing databases untouched') from None
    event('restore_complete', database=target)


@contextlib.contextmanager
def exclusive_lock(directory, name):
    path = directory / name
    if path.is_symlink():
        raise OpsError('Lock must not be a symlink')
    with path.open('a') as lock:
        os.chmod(path, 0o600)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise OpsError('Another operation is active') from None
        yield


def backup_cycle():
    directory = private_dir(Path(os.environ.get('EDSS_BACKUP_DIR', 'backups/automatic')))
    keep_value = number('EDSS_BACKUP_KEEP', 48, 2)
    if not keep_value.is_integer():
        raise OpsError('EDSS_BACKUP_KEEP must be an integer')
    keep = int(keep_value)
    with exclusive_lock(directory, '.backup.lock'):
        status_path = directory / 'backup-status.json'
        previous = read_json(status_path) or {}
        status = {'last_attempt': utc(), 'last_success': previous.get('last_success'), 'backup': previous.get('backup'),
                  'bytes': previous.get('bytes'), 'state': 'running'}
        atomic_json(status_path, status)
        try:
            destination = directory / ('edss-' + dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
                                       + '-' + uuid.uuid4().hex[:12] + '.dump')
            manifest = backup(destination)
            status.update(database=manifest['database'], last_success=manifest['completed_at'],
                          backup=destination.name, bytes=manifest['bytes'], duration_s=manifest['duration_s'])
            # Retention only touches this tool's archives for this source, after success.
            eligible = []
            for p in directory.glob('edss-*.dump'):
                if not re.fullmatch(r'edss-\d{8}T\d{6}Z-[a-f0-9]{12}\.dump', p.name) or p.is_symlink():
                    continue
                meta = read_json(Path(str(p) + '.json'))
                if (meta and meta.get('format_version') == 1 and meta.get('file') == p.name
                        and meta.get('database') == manifest['database'] and meta.get('sha256') == digest(p)):
                    eligible.append((p == destination, meta.get('completed_at', ''), p))
            eligible.sort(key=lambda item: (item[0], item[1], item[2].name), reverse=True)
            for _, _, p in eligible[keep:]:
                p.unlink()
                Path(str(p) + '.json').unlink()
            status.update(state='ok', database=manifest['database'], last_success=manifest['completed_at'], backup=destination.name,
                          bytes=manifest['bytes'], duration_s=manifest['duration_s'])
            atomic_json(status_path, status)
            event('backup_complete', **status)
        except (OpsError, OSError) as exc:
            status.update(state='failed', error=str(exc) if isinstance(exc, OpsError) else 'Filesystem operation failed')
            event('backup_failed', **status)
            try:
                atomic_json(status_path, status)
            except OSError:
                event('backup_state_unavailable')
            raise


def quote_identifier(name):
    return '"' + name.replace('"', '""') + '"'


def sql(database_name, query):
    with tempfile.TemporaryFile() as src:
        src.write(query.encode())
        src.seek(0)
        return execute(pg('psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres',
                          '-d', database(database_name)), stdin=src).decode()


def fingerprint(name):
    schema_literals = ','.join("'" + s + "'" for s in SCHEMAS)
    predicate = f"(n.nspname IN ({schema_literals}) OR (n.nspname='public' AND c.relname='schema_migrations'))"
    rows = sql(name, f"SELECT n.nspname||'.'||c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE {predicate} AND c.relkind IN ('r','p') ORDER BY 1;")
    tables = [x.split('.', 1) for x in rows.splitlines()]
    sequences = [x.split('.', 1) for x in sql(name, f"SELECT schemaname||'.'||sequencename FROM pg_sequences WHERE schemaname IN ({schema_literals}) ORDER BY 1;").splitlines()]
    script = ["BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SET TIME ZONE 'UTC'; SET statement_timeout='120s';"]
    for schema, table in tables:
        qualified = quote_identifier(schema) + '.' + quote_identifier(table)
        literal = qualified.replace("'", "''")
        script += [f"SELECT 'TABLE {schema}.{table}';",
                   f"SELECT 'META '||COALESCE(jsonb_agg(to_jsonb(a) ORDER BY a.attnum)::text,'[]') FROM (SELECT attnum,attname,format_type(atttypid,atttypmod) AS type,attnotnull,attidentity,attgenerated,pg_get_expr(d.adbin,d.adrelid) AS default_expr FROM pg_attribute LEFT JOIN pg_attrdef d ON d.adrelid=attrelid AND d.adnum=attnum WHERE attrelid='{literal}'::regclass AND attnum>0 AND NOT attisdropped) a;",
                   f"SELECT 'CONSTRAINTS '||COALESCE(jsonb_agg(pg_get_constraintdef(oid) ORDER BY conname)::text,'[]') FROM pg_constraint WHERE conrelid='{literal}'::regclass;",
                   f"SELECT 'INDEXES '||COALESCE(jsonb_agg(pg_get_indexdef(indexrelid) ORDER BY pg_get_indexdef(indexrelid))::text,'[]') FROM pg_index WHERE indrelid='{literal}'::regclass;",
                   f"SELECT 'TRIGGERS '||COALESCE(jsonb_agg(jsonb_build_object('definition',pg_get_triggerdef(oid),'enabled',tgenabled) ORDER BY tgname)::text,'[]') FROM pg_trigger WHERE tgrelid='{literal}'::regclass AND NOT tgisinternal;",
                   f"COPY (SELECT to_jsonb(t)::text FROM {qualified} t ORDER BY (to_jsonb(t)::text) COLLATE \"C\") TO STDOUT;"]
    for schema, seq in sequences:
        qualified = quote_identifier(schema) + '.' + quote_identifier(seq)
        script += [f"SELECT 'SEQUENCE {schema}.{seq}';", f"SELECT row_to_json(s)::text FROM (SELECT last_value,is_called FROM {qualified}) s;"]
    script += ['COMMIT;']
    script.insert(-1, f"SELECT 'FUNCTIONS '||COALESCE(jsonb_agg(pg_get_functiondef(p.oid) ORDER BY n.nspname,p.proname,p.oid::regprocedure::text)::text,'[]') FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ({schema_literals}) AND p.prokind IN ('f','p');")
    result = {'tables': {}, 'sequences': {}, 'functions_sha256': None}
    with tempfile.TemporaryFile() as src, tempfile.TemporaryFile() as errors:
        src.write(('\n'.join(script)).encode()); src.seek(0)
        process = subprocess.Popen(pg('psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', database(name)),
                                   stdin=src, stdout=subprocess.PIPE, stderr=errors)
        timer = threading.Timer(number('EDSS_BACKUP_TIMEOUT_SECONDS', 1800, 1), process.kill)
        timer.start()
        current, sequence, hasher = None, None, None
        try:
            for line in process.stdout:
                if line.startswith(b'TABLE '):
                    if current is not None:
                        result['tables'][current]['sha256'] = hasher.hexdigest()
                    current = line[6:].decode().strip(); sequence = None
                    result['tables'][current] = {'rows': 0}; hasher = hashlib.sha256()
                elif line.startswith((b'META ', b'CONSTRAINTS ', b'INDEXES ', b'TRIGGERS ')):
                    key, value = line.decode().split(' ', 1)
                    result['tables'][current][key.lower()] = json.loads(value)
                elif line.startswith(b'SEQUENCE '):
                    if current is not None:
                        result['tables'][current]['sha256'] = hasher.hexdigest(); current = None
                    sequence = line[9:].decode().strip()
                elif line.startswith(b'FUNCTIONS '):
                    result['functions_sha256'] = hashlib.sha256(line[10:].strip()).hexdigest()
                    sequence = None
                elif sequence is not None:
                    result['sequences'][sequence] = json.loads(line)
                elif current is not None:
                    hasher.update(line); result['tables'][current]['rows'] += 1
                else:
                    raise OpsError('Unexpected database fingerprint output')
            if current is not None:
                result['tables'][current]['sha256'] = hasher.hexdigest()
            if process.wait() != 0:
                raise OpsError('Database fingerprint failed or timed out')
        finally:
            timer.cancel()
            process.stdout.close()
            if process.poll() is None:
                process.kill(); process.wait()
    return result


def verify(source, target, report):
    if database(source) == database(target):
        raise OpsError('Verification requires different source and restored databases')
    started = time.monotonic()
    a, b = fingerprint(source), fingerprint(target)
    if not {'sim.clock', 'dws.hospital_oper_day', 'ads.todo_order', 'public.schema_migrations'} <= a['tables'].keys():
        raise OpsError('Source database lacks required EDSS tables')
    differences = {kind: sorted(k for k in a[kind].keys() | b[kind].keys() if a[kind].get(k) != b[kind].get(k))
                   for kind in ('tables', 'sequences')}
    differences['functions'] = [] if a['functions_sha256'] == b['functions_sha256'] else ['schema_functions']
    same = not any(differences.values())
    report = report.absolute(); private_dir(report.parent)
    atomic_json(report, {'completed_at': utc(), 'source': source, 'restored': target, 'match': same,
                         'duration_s': time.monotonic()-started, 'differences': differences,
                         'source_fingerprint': a, 'restored_fingerprint': b})
    event('restore_verified', match=same, tables=len(a['tables']), differences=differences)
    if not same:
        raise OpsError('Restored database contents or structure differ')


def base_url():
    value = os.environ.get('EDSS_API_URL', 'http://127.0.0.1:8080').rstrip('/')
    u = urllib.parse.urlsplit(value)
    if u.scheme not in ('http', 'https') or not u.hostname or u.username or u.password or u.query or u.fragment or u.path:
        raise OpsError('EDSS_API_URL must be an HTTP(S) origin without credentials')
    return value


def fetch(url):
    # Preserve proxy policy and normal TLS trust; loopback uses inherited NO_PROXY.
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    try:
        with opener.open(url, timeout=number('EDSS_MONITOR_TIMEOUT_SECONDS', 5, 1)) as response:
            data = response.read(2 * 1024 * 1024 + 1)
            if len(data) > 2 * 1024 * 1024:
                raise ValueError()
            envelope = json.loads(data)
            if envelope.get('code') != 0 or not isinstance(envelope.get('data'), dict):
                raise ValueError()
            return envelope['data']
    except (urllib.error.URLError, ValueError, TimeoutError, OSError):
        raise OpsError('API probe failed') from None


def monitor():
    directory = private_dir(Path(os.environ.get('EDSS_BACKUP_DIR', 'backups/automatic')))
    with exclusive_lock(directory, '.monitor.lock'):
        path = directory / 'monitor-state.json'
        previous = read_json(path) or {}
        alerts = []
        base = base_url()
        ready, stats = None, None
        for label, endpoint in (('ready', '/ready'), ('stats', '/stats')):
            try:
                data = fetch(base + endpoint)
                if label == 'ready': ready = data
                else: stats = data
            except OpsError:
                alerts.append(label + '_unavailable')
        status = read_json(directory / 'backup-status.json') or {}
        meta = {}
        if status.get('state') == 'failed': alerts.append('backup_failed')
        archive = directory / str(status.get('backup') or '.missing')
        if not archive.is_file() or archive.is_symlink() or archive.stat().st_size != status.get('bytes'):
            alerts.append('backup_archive_missing')
        else:
            try:
                meta = read_json(Path(str(archive) + '.json')) or {}
                if meta.get('database') != source_database():
                    alerts.append('backup_source_mismatch')
                if (meta.get('format_version') != 1 or meta.get('file') != archive.name
                        or meta.get('bytes') != archive.stat().st_size or meta.get('sha256') != digest(archive)):
                    alerts.append('backup_integrity_failed')
            except (OpsError, OSError):
                alerts.append('backup_integrity_failed')
        if status.get('state') == 'running':
            try:
                running_s = (dt.datetime.now(dt.timezone.utc)-dt.datetime.fromisoformat(status['last_attempt'])).total_seconds()
                if running_s > number('EDSS_BACKUP_TIMEOUT_SECONDS', 1800, 1): alerts.append('backup_stuck')
            except (KeyError, ValueError, TypeError): alerts.append('backup_invalid_state')
        try:
            age = (dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(meta['started_at'])).total_seconds()
            if age < -60 or age > number('EDSS_BACKUP_MAX_AGE_SECONDS', 3900, 1): alerts.append('backup_stale')
        except (KeyError, ValueError, TypeError):
            alerts.append('backup_missing')
        disk = shutil.disk_usage(directory)
        used_pct = disk.used / disk.total * 100
        if used_pct >= number('EDSS_DISK_MAX_USED_PCT', 90, 1): alerts.append('disk_pressure')
        if stats:
            if not stats.get('started_at') or 'by_route' not in stats or 'latency_bounds_ms' not in stats:
                alerts.append('metrics_unavailable')
            db = stats.get('db', {})
            if db.get('max_open', 0) and db.get('in_use', 0) / db['max_open'] * 100 >= number('EDSS_DB_MAX_IN_USE_PCT', 90, 1):
                alerts.append('db_pool_pressure')
            old = previous.get('stats') or {}
            if (stats.get('started_at') and stats.get('started_at') == old.get('started_at')
                    and stats.get('requests_total', 0) >= old.get('requests_total', 0)):
                delta = stats['requests_total'] - old.get('requests_total', 0)
                if delta >= number('EDSS_MONITOR_MIN_REQUESTS', 20, 1):
                    failures = sum(v - old.get('by_status', {}).get(k, 0) for k, v in stats.get('by_status', {}).items() if int(k) >= 500)
                    if failures / delta * 100 > number('EDSS_MAX_ERROR_PCT', 1, 0): alerts.append('http_5xx_rate')
                    for route, bucket in stats.get('by_route', {}).items():
                        if route in ('GET /health', 'GET /ready', 'GET /stats'): continue
                        prior = old.get('by_route', {}).get(route, {})
                        n = bucket['count'] - prior.get('count', 0)
                        bins = bucket['latency_buckets']
                        old_bins = prior.get('latency_buckets', [0] * len(bins))
                        if n < number('EDSS_MONITOR_MIN_REQUESTS', 20, 1) or len(bins) != len(old_bins): continue
                        total = 0
                        for index, (count, old_count) in enumerate(zip(bins, old_bins)):
                            total += count - old_count
                            if total >= math.ceil(n * .95):
                                bounds = stats['latency_bounds_ms']
                                p95 = bounds[index] if index < len(bounds) else bucket['latency_max_ms']
                                if p95 > number('EDSS_MAX_P95_MS', 1000, 1): alerts.append('slow_route:' + route)
                                break
                if db.get('wait_count', 0) > old.get('db', {}).get('wait_count', 0): alerts.append('db_pool_wait')
        recovered = sorted(set(previous.get('alerts', [])) - set(alerts))
        event('monitor_alert' if alerts else 'monitor_ok', alerts=alerts, recovered=recovered,
              ready=ready is not None, disk_used_pct=round(used_pct, 2),
              runtime=(stats or {}).get('runtime'), db=(stats or {}).get('db'),
              requests_total=(stats or {}).get('requests_total'))
        try:
            atomic_json(path, {'sampled_at': utc(), 'stats': stats, 'alerts': alerts, 'disk_used_pct': used_pct})
        except OSError:
            event('monitor_state_unavailable')
            raise
        if alerts:
            raise OpsError('Operational alerts active')


def resources():
    ids = execute(compose() + ['ps', '-q']).decode().splitlines()
    # cloud-dev starts its source API separately from Compose, on the same project network.
    name = os.environ.get('EDSS_DEV_PROJECT', 'edss-dev') + '-api'
    if re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]+', name):
        probe = subprocess.run(['docker', 'inspect', '--format', '{{if .State.Running}}{{.Id}}{{end}}', name],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=5)
        if probe.returncode == 0:
            ids += probe.stdout.decode().split()
    ids = list(dict.fromkeys(ids))
    rows = []
    if ids:
        output = execute(['docker', 'stats', '--no-stream', '--format', '{{json .}}', *ids]).decode()
        rows = [json.loads(line) for line in output.splitlines()]
    disk = shutil.disk_usage(ROOT)
    event('resources', containers=rows, disk={'total_bytes': disk.total, 'free_bytes': disk.free})


def run():
    """Foreground supervisor for hosts where service timers are unavailable."""
    directory = private_dir(Path(os.environ.get('EDSS_BACKUP_DIR', 'backups/automatic')))
    intervals = {'backup-cycle': number('EDSS_BACKUP_INTERVAL_SECONDS', 3600, 10),
                 'monitor': number('EDSS_MONITOR_INTERVAL_SECONDS', 60, 5),
                 'resources': number('EDSS_RESOURCES_INTERVAL_SECONDS', 60, 5)}
    limits = {'backup-cycle': number('EDSS_BACKUP_JOB_TIMEOUT_SECONDS', 2400, 1),
              'monitor': 45, 'resources': 30}
    stopping = threading.Event()
    previous_handlers = {s: signal.signal(s, lambda *_: stopping.set())
                         for s in (signal.SIGINT, signal.SIGTERM)}
    jobs, state = {}, {'started_at': utc(), 'state': 'running', 'jobs': {}}
    owns_lock = False
    due = dict.fromkeys(intervals, 0)
    path = directory / 'scheduler-state.json'
    def save_state():
        try:
            atomic_json(path, state)
        except OSError:
            # Disk pressure must not stop probes or the next backup retry.
            event('scheduler_state_unavailable')
    lock_stack = contextlib.ExitStack()
    try:
        lock_stack.enter_context(exclusive_lock(directory, '.scheduler.lock'))
        owns_lock = True
        save_state()
        event('scheduler_started', intervals=intervals)
        while not stopping.is_set():
            now = time.monotonic()
            for name in intervals:
                if name in jobs:
                    process, started, timed_out = jobs[name]
                    if process.poll() is None and now - started > limits[name] and not timed_out:
                        with contextlib.suppress(ProcessLookupError):
                            os.killpg(process.pid, signal.SIGKILL)
                        jobs[name] = (process, started, True)
                    code = process.poll()
                    if code is not None:
                        outcome = state['jobs'][name]
                        outcome.update(completed_at=utc(), exit_code=code,
                                       timed_out=jobs[name][2], duration_s=now-started)
                        outcome['state'] = 'ok' if code == 0 else 'failed'
                        event('scheduled_job_complete', job=name, **outcome)
                        del jobs[name]
                        # Failed jobs retry on the next normal interval, without a tight loop.
                        due[name] = now + intervals[name]
                        save_state()
                if name not in jobs and now >= due[name]:
                    process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), name],
                                               start_new_session=True)
                    jobs[name] = (process, now, False)
                    state['jobs'][name] = {'state': 'running', 'started_at': utc()}
                    save_state()
            stopping.wait(.5)
    finally:
        for process, _, _ in jobs.values():
            if process.poll() is None:
                with contextlib.suppress(ProcessLookupError):
                    os.killpg(process.pid, signal.SIGTERM)
        deadline = time.monotonic() + 10
        for name, (process, _, _) in jobs.items():
            try:
                process.wait(timeout=max(.01, deadline-time.monotonic()))
            except subprocess.TimeoutExpired:
                with contextlib.suppress(ProcessLookupError):
                    os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            state['jobs'][name].update(state='interrupted', exit_code=process.returncode)
        for s, handler in previous_handlers.items():
            signal.signal(s, handler)
        # A contender must never replace the active scheduler's status.
        if owns_lock:
            state.update(state='stopped', stopped_at=utc())
            save_state()
            event('scheduler_stopped')
        lock_stack.close()


def main():
    os.umask(0o077)
    os.chdir(ROOT)
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('backup'); p.add_argument('destination', type=Path)
    p = sub.add_parser('restore'); p.add_argument('source', type=Path); p.add_argument('target')
    p = sub.add_parser('verify-db'); p.add_argument('source'); p.add_argument('target')
    p.add_argument('--report', type=Path, default=Path('backups/restore-verification.json'))
    for command in ('backup-cycle', 'monitor', 'resources', 'run'): sub.add_parser(command)
    args = parser.parse_args()
    try:
        if args.command == 'backup': event('backup_complete', **backup(args.destination))
        elif args.command == 'restore': restore(args.source, args.target)
        elif args.command == 'verify-db': verify(args.source, args.target, args.report)
        elif args.command == 'backup-cycle': backup_cycle()
        elif args.command == 'monitor': monitor()
        elif args.command == 'resources': resources()
        else: run()
    except (OpsError, OSError, subprocess.SubprocessError) as exc:
        event('operation_failed', operation=args.command,
              error=str(exc) if isinstance(exc, OpsError) else 'Local system operation failed')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
