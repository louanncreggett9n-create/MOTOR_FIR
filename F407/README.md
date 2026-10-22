# STM32F407数据集信号源

## 目标
- MCU：STM32F407VGT6，内部 1 MB Flash。
- 不再使用外部 W25Q64。
- 使用内部 Flash 保存 Raw data1 数据集。
- 使用 1.54 寸 240x240 ST7789 LCD，替代原 OLED。
- 保留原数据集加载命令和 TPC116S4 输出协议。
- FPGA 采样同步输入仍使用 PA0/EXTI0。

## 内部 Flash 布局
- 代码区：0x08000000 ~ 0x0807FFFF，共 512 KB。
- 数据扇区：0x08080000 ~ 0x0809FFFF，使用 Sector 8，共 128 KB。
- 头部映射偏移：0x1000。
- 数据映射偏移：0x2000。
- 单组数据集最大 61440 个 16 位样本。

## 外设引脚
- TPC116S4：PB12 SYNC，PB13 SCLK，PB15 DIN，LOAD 接 GND。
- TPC116S4 输出：OUTA -> AD7606 AIN_V1。
- FPGA 同步：ACX720 GPIO0_28/D20 -> STM32 PA0。
- UART：PA9 TX，PA10 RX，115200 8-N-1。
- 1.54 寸 LCD：PB3 SCK，PB5 SDA，PA15 CS，PD13 DC，PD12 背光。
- 用户按键：PC1。
- LED：PC0。

## Keil 工程
打开：

`Project\STM32F407_DatasetPlayer.uvprojx`

工程已经把 IROM 大小限制为 0x80000，避免下载程序时擦除数据集所在的 Sector 8。

## 数据加载
使用 `Tools\load_dataset_com.ps1`，参数指定 COM 口、16 位小端数据文件和 64 字节头部文件。命令协议与原 W25Q64 工程兼容。

## 注意
- 第一次上电如果内部 Flash 没有有效数据集，程序会自动写入 256 点正弦默认数据。
- 下载程序时使用 Keil 的 Sector Erase，不要使用全片擦除。
- 1.54 寸 LCD 引脚按参考例程，软排线连接时不要改变 PB3/PB5/PA15/PD12/PD13。
