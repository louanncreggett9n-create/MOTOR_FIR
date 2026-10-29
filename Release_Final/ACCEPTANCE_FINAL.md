# Final acceptance record

Date: 2026-10-30

## Release identity

```text
Bit: MOTOR_FIR_unified_classifier_block1to4_final_20261029.bit
SHA256: 10115BE11CC0DFCBF51D9F80FB0C04393D47CB70FF4F3EDA3DBFE613574564CD
```

## Evidence

| Check | Result |
|---|---|
| Blocks 1-4 leave-one-block-out | 22/24 |
| Block 5 independent hardware test | 6/6 PASS |
| RTL simulation | 14/14 PASS |
| Zero-vector UNKNOWN rejection | PASS |
| Timing constraints | PASS |
| WNS | 0.237 ns |
| WHS | 0.046 ns |
| N1 shorted-input noise RMS | 0.9047 LSB |
| N1 100 Hz sine SNR | >= 67.95 dB |
| N1 ENOB at test amplitude | 10.99 bit |

## Model decision rules

```text
Global: BEST <= 1250 and MARGIN >= 80
BF:     BEST <= 500 and MARGIN >= 80
```

## Notes

- Training blocks: 1, 2, 3, 4.
- Holdout block: 5.
- Block 5 was not used to compute centroids or thresholds.
- The five blocks are dataset replay blocks, not independent field measurements.
- Noise, SNR, SINAD, THD, and ENOB are measured on the N1 800 SPS diagnostic path, not on the AD7606 die alone.