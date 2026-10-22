# R2 六类板级验收指南

## 验收前准备

1. ACX720 使用独立 5 V 供电并开机。
2. 连接 JTAG。
3. 烧录：

```text
artifacts/MOTOR_FIR_unified_classifier_fixed_20261022.bit
```

4. F407 烧录：

```text
artifacts/STM32F407_multidataset_6slot_8192_20261021.hex
```

5. 确认 F407 已加载六槽数据并进入 DATASET 播放。
6. FPGA CTRL 页选择 `ADC + CH0`。

## A. 基础功能

- [x] OVERVIEW、WAVEFORM、SPECTRUM、CTRL 四个页面可触摸切换
- [x] 当前页高亮跟随
- [x] 点击顶部标签不会误触内容区操作
- [x] N1/N2/N3/ENV 不再同时显示最大值
- [x] ADC 波形有明显交流变化

## B. 六类扫描

每类完成后记录：`CLASS / CONF / SEV / ROUTE`、N1/N2/N3 最大条形值和截图文件名。

| Slot | 类别 | 预期峰值 bin | 预期 CLASS | 记录状态 |
|---|---|---:|---|---|
| 0 | H | 17 | H | PENDING |
| 1 | UNBAL | 18 | UNBAL | PENDING |
| 2 | MISAL | 27 | MISAL | PENDING |
| 3 | BF | 16 | BF | PENDING |
| 4 | BOW | 17 | BOW | PENDING |
| 5 | BROKEN | 18 | BROKEN | PENDING |

判据：

- 实际 CLASS 与类别一致
- CONF 大于 0
- ROUTE 为 `HW-CHAIN`
- N1/N2/N3 不应长期同时处于最大值

## C. UNKNOWN 拒识

1. 切换到固定 A/B/C/D DC TEST。
2. 点击 SCAN。
3. 预期：

```text
CLASS: ---
CONF: 0.00
SEV: 0
ROUTE: HW-CHAIN
```

## D. 稳定性

- [x] 连续运行 30 分钟
- [x] 期间至少扫描 6 次
- [x] FPGA 断电、重新上电、重新烧录后再扫描一次
- [x] 触摸、UART、F407 数据集播放均恢复正常

## E. 可选自动扫描

如果 COM 口与现场一致，可运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_six_scan.ps1 -ComF407 COM5 -ComFpga COM7
```

自动扫描只能证明频谱帧完整，最终类别和触摸交互仍需人工确认。

## 结果填写

将结果填入：

```text
acceptance_results.csv
```

完成后把 CSV、六类屏幕照片和 30 分钟稳定性结论交给项目负责人，作为 R2 冻结依据。