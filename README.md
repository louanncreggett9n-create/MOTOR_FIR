# FPGA 片内六类电机工况分类演示

本仓库包含 AMD Artix-7 XC7A35T + STM32F407 + AD7606/TPC116S4 + GT911 的完整演示工程。

## 功能

- F407 内部 Flash 保存六槽 8192 点电机振动数据
- TPC116S4 与 AD7606 形成同步模拟采集链路
- FPGA 完成 FIR、128-bin Goertzel、波形显示和触摸 UI
- 128 bin 压缩为 16 频带，使用 L1 最近类中心分类
- 类别：H、UNBAL、MISAL、BF、BOW、BROKEN
- UNKNOWN 拒识
- 分类不需要上位机参与

## 目录

```text
FPGA/                 FPGA RTL、IP、约束和构建脚本
F407/                 STM32F407 Keil 工程
Classifier/           分类器模型、RTL、模板和测试向量
Release_R2/           最终 bit、F407 HEX、数据镜像和 Flash 候选镜像
Acceptance/           R2 验收记录、扫描证据、时序与实现报告
Tools/                工程重建、bitgen、扫描、数据加载脚本
```

## 最终版本

```text
R2 bit SHA256
4EDC220AF3CBF82D127351A3B6BF539B4A9D367A5FEF2E9E4894B9938ADBF092
```

F407：

```text
STM32F407_multidataset_6slot_8192_20261021.hex
```

## 快速烧录

1. Vivado/JTAG 烧录 `Release_R2/MOTOR_FIR_unified_classifier_fixed_20261022.bit`。
2. Keil/ST-Link 烧录 F407 HEX，不要全片擦除，保留数据集所在 Sector。
3. F407 进入 DATASET 播放。
4. FPGA CTRL 页选择 ADC + CH0。
5. 点击 SCAN。

## 构建

FPGA：

```powershell
cd FPGA/build
vivado -mode batch -source .\build_full_relative.tcl
```

分类器仿真：

```powershell
cd Classifier
xvlog -i .\rtl .\rtl\damage_classifier_l1.v .\rtl\tb_damage_classifier_l1.v
xelab -debug typical work.tb_damage_classifier_l1 -s classifier_sim
xsim classifier_sim -R
```

F407 工程：

```text
F407/Project/STM32F407_DatasetPlayer.uvprojx
```

## 验收结果

```text
六槽自动频谱：PASS
六类 UI 分类：PASS
触摸交互：PASS
N1/N2/N3 显示：PASS
UNKNOWN：PASS
30 分钟稳定性：PASS
综合/实现/bitgen：PASS
```

峰值 bin：

```text
H17 / UNBAL18 / MISAL27 / BF16 / BOW17 / BROKEN18
```

## 已知限制

- 当前为已知六类真实工况数据回放验证，不代表真实传感器跨设备泛化。
- MX25L12845G Flash 烧录尚未验证；现场使用 JTAG/RAM 配置。
- SPIx4/MCS/BIN 已生成，但未完成 Flash 编程验证。

## 关键词

```text
FPGA片内推理
电机振动诊断
六类工况识别
```