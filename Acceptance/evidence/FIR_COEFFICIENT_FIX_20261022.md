# FIR 系数错误修复记录

日期：2026-10-22

## 现象

- UI 中 N1、N2、N3 几乎一直显示为最大值。
- SCAN 可以启动，但无法得到有效分类结果。

## 根因

统一工程第一次生成时，为了让 IP 脱离旧工程的相对路径，把 7 个 FIR Compiler IP 的 `CoefficientSource` 错设为 `Vector`，并给所有 FIR 写入了同一组 21 点系数。

原工程实际是 7 组完全不同的滤波器：

- L1：25.6 kSPS 到 3.2 kSPS 抽取低通
- L2：3.2 kSPS 到 800 SPS 抽取低通
- N1：约 100 Hz 带通
- N2：约 200 Hz 带通
- N3：约 300 Hz 带通
- RB：700 Hz 到 1500 Hz 带通
- ENV：包络低通

`spectrum_scan_b` 的输入正是 `chain_l2_out`，所以 L1/L2 系数错误不仅会让 N1/N2/N3 顶满，也会直接破坏 Goertzel 频谱和分类结果。

## 修复

1. 从原工程恢复 7 个原始 COE 文件到：

```text
PROJECT_SUMMARY_20261022\vivado_out3.0\fir_compiler
```

2. 将 7 个 FIR IP 的 `CoefficientSource` 改回 `COE_File`。
3. 对 7 个 IP 执行 `reset_target` 和 `generate_target`，重新生成各自的 MIF/DCP。
4. 重新运行综合、布局布线、时序检查和 bitgen。

## 修复验证

工程自检确认：

```text
fir_L1  SOURCE=COE_File
fir_L2  SOURCE=COE_File
fir_N1  SOURCE=COE_File
fir_N2  SOURCE=COE_File
fir_N3  SOURCE=COE_File
fir_RB  SOURCE=COE_File
fir_ENV SOURCE=COE_File
```

各 IP 生成后的 MIF 首列已恢复为不同系数。例如：

- `fir_L1` 起始为 `-11, -15, -18, -20...`
- `fir_L2` 起始为 `-8, -3, 8, 17...`
- `fir_N1` 起始为 `2, 6, 6, 3...`
- `fir_N2` 起始为 `4, -4, -5, 5...`
- `fir_N3` 起始为 `-5, 2, 2, -6...`
- `fir_RB` 起始为 `-7, -11, -15, -19...`
- `fir_ENV` 起始为 `81, 158, 266, 408...`

## 构建结果

- 综合：0 errors，0 critical warnings
- `synth_1`：`synth_design Complete!`
- `impl_1`：`write_bitstream Complete!`
- 布局布线 WNS：`+0.818 ns`
- 布局布线 WHS：`+0.028 ns`

修复后的 bit：

```text
output\MOTOR_FIR_unified_classifier_fixed_20261022.bit
SHA256 4EDC220AF3CBF82D127351A3B6BF539B4A9D367A5FEF2E9E4894B9938ADBF092
```

## 上板复核顺序

1. 烧录修复后的 bit。
2. F407 进入 DATASET 播放。
3. FPGA CTRL 页选择 ADC + CH0。
4. 观察 N1/N2/N3，不应再同时顶满。
5. 点击 SCAN，等待 CLASS/CONF/SEV 更新。