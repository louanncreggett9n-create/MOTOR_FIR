# MOTOR_FIR R2 发布候选

日期：2026-10-22

状态：

- FPGA 构建：PASS
- 实现与 bitgen：PASS
- FIR 系数修复：PASS
- R2 bit JTAG 下载：PASS
- 六槽自动频谱扫描：PASS
- 六类 UI 分类：PASS
- 触摸页面切换：PASS
- UNKNOWN 拒识：PASS
- 30 分钟稳定性：PASS
- Flash 烧录：未验证

## 当前最终候选 bit

JTAG 验证用普通 bit：

```text
artifacts/MOTOR_FIR_unified_classifier_fixed_20261022.bit
SHA256 4EDC220AF3CBF82D127351A3B6BF539B4A9D367A5FEF2E9E4894B9938ADBF092
```

SPIx4/Flash 候选镜像：

```text
artifacts/MOTOR_FIR_unified_classifier_fixed_20261022_spix4.bit
artifacts/MOTOR_FIR_unified_classifier_fixed_20261022_spix4.mcs
artifacts/MOTOR_FIR_unified_classifier_fixed_20261022_spix4.bin
```

这些 Flash 镜像已经从同一 routed DCP 生成，但尚未完成 MX25L12845G 烧录验证。

## F407 配套文件

```text
artifacts/STM32F407_multidataset_6slot_8192_20261021.hex
artifacts/multidataset_8192_0x1000_0x1FFFF.bin
```

## 构建结果

```text
Synthesis:       0 errors, 0 critical warnings
Implementation:  write_bitstream Complete!
WNS:             +0.818 ns
WHS:             +0.028 ns
Slice LUTs:      18505 / 20800  (88.97%)
Slice Registers: 18488 / 41600 (44.44%)
Block RAM Tile:  18.5 / 50      (37.00%)
DSP:             15 / 90        (16.67%)
```

## 目录

- `artifacts/`：bit、MCS/BIN、F407 HEX 和数据镜像
- `evidence/`：综合、实现、时序、资源、FIR 修复记录
- `tools/`：工程重建、验证、bitgen、六类扫描和 F407 数据加载脚本
- `docs/`：发布说明、自动扫描证据和验收指南
- `ACCEPTANCE_R2.md`：六类最终验收清单
- `acceptance_results.csv`：现场结果记录表

## 六类验收

请按 `ACCEPTANCE_R2.md` 操作，并将结果填入 `acceptance_results.csv`。

预期峰值 bin：

```text
H 17 / UNBAL 18 / MISAL 27 / BF 16 / BOW 17 / BROKEN 18
```

## 回滚策略

如果 R2 现场异常，回退到原有已验证发布 bit：

```text
PROJECT_SUMMARY_20261022/01_RAM_DEMO/fpga/MOTOR_FIR_system_touch_classifier_qspi_x4_20261022.bit
```

不要让未验证的 Flash 镜像覆盖唯一可用配置；现场优先使用 JTAG/RAM 模式。