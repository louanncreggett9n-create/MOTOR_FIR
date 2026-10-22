# R2 最终验收记录

日期：2026-10-22

## 结论

```text
R2 FPGA 构建：PASS
JTAG 下载：PASS
六槽自动频谱：PASS
六类 UI 分类：PASS
触摸页面切换：PASS
N1/N2/N3 显示：PASS，不再饱和
UNKNOWN 拒识：PASS
30 分钟稳定性：PASS
Flash 烧录：未验证
```

## 六类结果

| Slot | 类别 | 峰值 bin | UI 分类 | 结果 |
|---|---|---:|---|---|
| 0 | H | 17 | H | PASS |
| 1 | UNBAL | 18 | UNBAL | PASS |
| 2 | MISAL | 27 | MISAL | PASS |
| 3 | BF | 16 | BF | PASS |
| 4 | BOW | 17 | BOW | PASS |
| 5 | BROKEN | 18 | BROKEN | PASS |

UNKNOWN：

```text
CLASS: ---
CONF: 0.00
SEV: 0
ROUTE: HW-CHAIN
```

## 使用版本

```text
R2 bit:
artifacts/MOTOR_FIR_unified_classifier_fixed_20261022.bit
SHA256 4EDC220AF3CBF82D127351A3B6BF539B4A9D367A5FEF2E9E4894B9938ADBF092
```

F407：

```text
STM32F407_multidataset_6slot_8192_20261021.hex
```

## 证据

- `acceptance_results.csv`
- `evidence/program_r2_bit.log`
- `evidence/detect_hardware.log`
- `evidence/scan_r2/`
- `docs/R2_SCAN_EVIDENCE.md`

## 备注

BROKEN 原始 2 Mbps 串口抓包偶发丢失非峰值 bin，但重复帧恢复后的峰值为预期 bin18，且屏幕 UI 分类正常。