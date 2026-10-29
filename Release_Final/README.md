# Final FPGA classifier release

Release date: 2026-10-30

This directory is the validated final build for the six-class FPGA motor-vibration classifier. The older R2 release remains under `../Release_R2` as a historical baseline.

## Release bit

```text
MOTOR_FIR_unified_classifier_block1to4_final_20261029.bit
SHA256: 10115BE11CC0DFCBF51D9F80FB0C04393D47CB70FF4F3EDA3DBFE613574564CD
```

Implementation results:

```text
WNS: 0.237 ns
WHS: 0.046 ns
TNS/THS: 0
Timing constraints: met
Device: XC7A35T-FGG484-2
Tool: Vivado 2018.3
```

## Model

- 128 Goertzel bins, grouped into 16 bands of eight bins each.
- Bin height: `mag_clip[13:6]`.
- Manhattan-distance nearest centroid.
- Training: blocks 1-4.
- Independent test: block 5.
- Global decision threshold: `BEST <= 1250`, `MARGIN >= 80`.
- BF-specific decision threshold: `BEST <= 500`.

The BF-specific threshold prevents a zero/no-signal vector from being accepted as BF. The all-zero vector is correctly rejected as `UNKNOWN` in RTL simulation.

## Validation summary

- Blocks 1-4 leave-one-block-out: 22/24 nearest-class decisions correct.
- Block 5 independent hardware test: 6/6 PASS.
- RTL simulation: 14/14 PASS, including the UNKNOWN zero-vector case.
- Classifier latency: 97 cycles, 1.94 microseconds at 50 MHz.

See `CROSS_BLOCK_VALIDATION.md` and `block5_final_bfgate_results_20261030.csv` for the evidence record.

## Quick programming

1. Program `MOTOR_FIR_unified_classifier_block1to4_final_20261029.bit` with Vivado/JTAG.
2. Program `STM32F407_multidataset_6slot_8192_20261021.hex` with ST-Link/Keil.
3. Select a block image under `images/` with the F407 loader if needed.
4. In the FPGA CTRL page select ADC + CH0, then run SCAN.

## Scope and limitations

The five blocks come from the project dataset. Block 5 is an independent block split, not a new field-motor installation. The release does not establish generalization to arbitrary motors, sensor mounting conditions, loads, or noise environments. SNR, SINAD, THD, and ENOB were not measured in this release.