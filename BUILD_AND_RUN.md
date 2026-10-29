# 构建与运行

## FPGA

统一图形工程：

```text
Tools/create_unified_project.tcl
Tools/verify_unified_project.tcl
Tools/build_unified_bit.tcl
```

独立构建入口：

```powershell
cd FPGA/build
vivado -mode batch -source .\build_full_relative.tcl
```

最终发布位流：

```text
Release_Final/MOTOR_FIR_unified_classifier_block1to4_final_20261029.bit
```

## F407

使用 Keil 打开：

```text
F407/Project/STM32F407_DatasetPlayer.uvprojx
```

烧录：

```text
Release_Final/STM32F407_multidataset_6slot_8192_20261021.hex
```

五块数据镜像位于：

```text
Release_Final/images/
```

首次或更换数据时使用：

```powershell
.\Tools\load_multidataset_com.ps1 -PortName COM5 -ImageFile .\Release_Final\images\block5_six_slot.bin
```

## 自动扫描

```powershell
.\Tools\run_six_scan.ps1 -ComF407 COM5 -ComFpga COM7 -StartSlot 0 -EndSlot 5
```

## Flash 镜像

`Release_R2` 中的 SPIx4 bit/MCS/BIN 属于历史 R2 构建，MX25L12845G 烧录尚未验证。最终现场验证使用 `Release_Final` 的 JTAG 普通 bit。