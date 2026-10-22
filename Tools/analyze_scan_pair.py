import json
import math
import sys
from pathlib import Path


def parse_scan(path):
    data = Path(path).read_bytes()
    frames = {}
    i = 0
    while i + 9 < len(data):
        if data[i] == 0xAB and (sum(data[i:i + 9]) & 0xFF) == data[i + 9]:
            idx = data[i + 1]
            if idx < 128:
                xr = int.from_bytes(data[i + 2:i + 5], "big", signed=True)
                xi = int.from_bytes(data[i + 5:i + 8], "big", signed=True)
                frames[idx] = (xr, xi, data[i + 8])
            i += 10
            continue
        i += 1
    missing = [idx for idx in range(128) if idx not in frames]
    if missing:
        raise RuntimeError(f"{path}: missing bins {missing}")
    return [frames[idx] for idx in range(128)]


def metrics(a, b):
    ma = [math.hypot(xr, xi) for xr, xi, _ in a]
    mb = [math.hypot(xr, xi) for xr, xi, _ in b]
    dot = sum(x * y for x, y in zip(ma, mb))
    cosine = dot / (math.sqrt(sum(x * x for x in ma)) * math.sqrt(sum(y * y for y in mb)))
    peak_a = max(range(128), key=ma.__getitem__)
    peak_b = max(range(128), key=mb.__getitem__)
    ratio = min(ma[peak_a], mb[peak_b]) / max(ma[peak_a], mb[peak_b])
    l2 = math.sqrt(sum((x - y) ** 2 for x, y in zip(ma, mb)))
    return {
        "peak_bin_run1": peak_a,
        "peak_bin_run2": peak_b,
        "peak_mag_run1": ma[peak_a],
        "peak_mag_run2": mb[peak_b],
        "spectral_cosine": cosine,
        "peak_magnitude_ratio": ratio,
        "normalized_l2_delta": l2,
    }


if len(sys.argv) != 3:
    raise SystemExit("usage: analyze_scan_pair.py RUN1_RAW RUN2_RAW")

run1 = parse_scan(sys.argv[1])
run2 = parse_scan(sys.argv[2])
result = metrics(run1, run2)
result["pass"] = (
    result["peak_bin_run1"] == result["peak_bin_run2"]
    and result["spectral_cosine"] >= 0.95
    and result["peak_magnitude_ratio"] >= 0.80
)
print(json.dumps(result, indent=2))
Path("broken_8192_repeatability.json").write_text(
    json.dumps(result, indent=2), encoding="utf-8"
)
raise SystemExit(0 if result["pass"] else 2)