# 构建与运行

## FPGA

工作目录：

```text
FPGA/build
```

执行：

```powershell
vivado -mode batch -source .\build_full_relative.tcl
```

输出：

```text
FPGA/build/MOTOR_FIR_system_touch_rebuilt.bit
```

统一图形工程的重建脚本位于：

```text
Tools/create_unified_project.tcl
Tools/verify_unified_project.tcl
Tools/build_unified_bit.tcl
```

## F407

使用 Keil 打开：

```text
F407/Project/STM32F407_DatasetPlayer.uvprojx
```

烧录：

```text
Release_R2/STM32F407_multidataset_6slot_8192_20261021.hex
```

数据镜像：

```text
Release_R2/multidataset_8192_0x1000_0x1FFFF.bin
```

首次或更换数据时运行：

```powershell
.\Tools\load_multidataset_com.ps1 -PortName COM5 -ImageFile .\Release_R2\multidataset_8192_0x1000_0x1FFFF.bin
```

## 自动扫描

```powershell
.\Tools\run_six_scan.ps1 -ComF407 COM5 -ComFpga COM7 -StartSlot 0 -EndSlot 5
```

## Flash 镜像

`Release_R2` 中的 `spix4.bit/mcs/bin` 已从 R2 实现结果生成，但 MX25L12845G 烧录尚未验证。现场优先使用 JTAG 普通 bit。