# FPGA 片内六类电机工况分类演示

本仓库包含 AMD Artix-7 XC7A35T + STM32F407 + AD7606/TPC116S4 + GT911 的演示工程。

## 最终版本

最终验证位流位于 `Release_Final/`：

```text
MOTOR_FIR_unified_classifier_block1to4_final_20261029.bit
SHA256: 10115BE11CC0DFCBF51D9F80FB0C04393D47CB70FF4F3EDA3DBFE613574564CD
```

实现结果：

```text
WNS: 0.237 ns
WHS: 0.046 ns
TNS/THS: 0
时序约束：全部满足
器件：XC7A35T-FGG484-2
工具：Vivado 2018.3
```

模型验证：

- block1–4 留一块交叉验证：22/24 最近类别正确
- block5 独立硬件测试：6/6 PASS
- Vivado xsim：14/14 PASS，包含全零输入 `UNKNOWN`
- 分类器延迟：97 个时钟周期，约 1.94 微秒

## 功能

- F407 内部 Flash 保存六槽 8192 点电机振动数据
- TPC116S4 与 AD7606 形成同步模拟采集链路
- FPGA 完成 FIR、128-bin Goertzel、波形显示和触摸 UI
- 128 bin 压缩为 16 频带，使用 L1 最近质心分类
- 类别：H、UNBAL、MISAL、BF、BOW、BROKEN
- 全局阈值 `BEST <= 1250`、`MARGIN >= 80`
- BF 专用阈值 `BEST <= 500`，避免无信号输入被误判为 BF
- 分类不需要上位机参与

## 目录

```text
FPGA/                 FPGA RTL、IP、约束和构建脚本
F407/                 STM32F407 Keil 工程
Classifier/           最终分类器模型、RTL、模板和测试向量
Release_Final/        最终 bit、F407 HEX、五块数据镜像和验收记录
Release_R2/           历史 R2 基准版本，保留用于追溯
Acceptance/           历史验收、扫描证据、时序与实现报告
Tools/                工程重建、bitgen、扫描和数据加载脚本
```

## 快速烧录

1. Vivado/JTAG 烧录 `Release_Final/MOTOR_FIR_unified_classifier_block1to4_final_20261029.bit`。
2. Keil/ST-Link 烧录 `Release_Final/STM32F407_multidataset_6slot_8192_20261021.hex`。
3. 需要更换数据块时，用 `Release_Final/images/` 中对应镜像加载。
4. FPGA CTRL 页选择 ADC + CH0 后执行 SCAN。

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

## 已知限制

- 五个数据块来自项目数据集，block5 是独立数据块测试，不等于真实电机现场跨设备泛化。
- 留一块交叉验证仍有 2/24 错误，UNBAL 与 H、H 与 MISAL 的边界并非完全分离。
- MX25L12845G Flash 烧录尚未验证；现场使用 JTAG/RAM 配置。
- SNR、SINAD、THD 和 ENOB 尚未实测。

## 关键词

```text
FPGA片内推理
电机振动诊断
六类工况识别
跨块硬件验证
```