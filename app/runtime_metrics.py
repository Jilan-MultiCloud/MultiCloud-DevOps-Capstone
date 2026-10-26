"""Prometheus process metrics with no third-party runtime dependencies."""
from collections import Counter
import os
from pathlib import Path
import threading

_requests = Counter()
_lock = threading.Lock()


def record(status):
    with _lock:
        _requests[str(status)] += 1


def render():
    cpu = os.times()
    lines = ["# TYPE process_cpu_seconds_total counter",
             f"process_cpu_seconds_total {cpu.user + cpu.system}"]
    try:
        pages = int(Path("/proc/self/statm").read_text().split()[1])
        memory = pages * os.sysconf("SC_PAGE_SIZE")
        lines += ["# TYPE process_resident_memory_bytes gauge",
                  f"process_resident_memory_bytes {memory}"]
    except (OSError, ValueError, AttributeError):
        pass
    limit_mb = os.getenv("MEMORY_LIMIT_MB", os.getenv("AWS_LAMBDA_FUNCTION_MEMORY_SIZE", "0"))
    if float(limit_mb) > 0:
        lines += ["# TYPE process_memory_limit_bytes gauge",
                  f"process_memory_limit_bytes {float(limit_mb) * 1024 * 1024}"]
    lines.append("# TYPE http_requests_total counter")
    with _lock:
        for status, count in sorted(_requests.items()):
            lines.append(f'http_requests_total{{status="{status}"}} {count}')
    return "\n".join(lines) + "\n"
