# Final 16-band classifier

This directory contains the classifier used by the final validated FPGA build on 2026-10-29.

## Model

- Feature: 128 Goertzel bins reduced to 16 bands, eight bins per band.
- Bin height: `mag_clip[13:6]`.
- Classifier: Manhattan-distance nearest centroid.
- Classes: H, UNBAL, MISAL, BF, BOW, BROKEN.
- Training data: blocks 1-4 from the five-block hardware capture set.
- Independent test: block 5, not used for centroids or threshold selection.
- Decision threshold: global `BEST <= 1250`, `MARGIN >= 80`; BF uses `BEST <= 500` because its spectral vectors have a much smaller amplitude scale and the tighter radius rejects no-signal inputs.

## Validation

- Leave-one-block-out on blocks 1-4: 22/24 nearest-class decisions correct.
- Block 5 hardware test: 6/6 classes PASS.
- RTL simulation: 14/14 cases pass, including the zero-vector UNKNOWN case.
- Classifier latency: 97 cycles, 1.94 microseconds at 50 MHz.

## Files

- `rtl/damage_classifier_l1.v`: final classifier RTL.
- `rtl/classifier_templates_16band.vh`: final centroid constants.
- `model/classifier_model_16band.json`: model metadata and threshold rationale.
- `model/centroids.csv`: centroid table.
- `model/classifier_validation_vectors_5block.csv`: all 30 captured hardware vectors.
- `model/classifier_test_vectors.mem`: 14 simulation vectors.
- `model/classifier_test_labels.txt`: expected simulation labels.

## Scope

The five blocks come from the project dataset, not from an independent field motor installation. The result supports cross-block hardware validation on the captured dataset; it does not establish generalization to arbitrary motors, sensor mounts, loads, or noise conditions.