################################################################################
# ACX720 开发板 Top 工程管脚约束
# 对应模块端口：CLK, Reset_n, UART_rx, UART_tx,
#               Mode_SW, Src_SW, Key, Wave_SW[1:0], Freq_SW[3:0],
#               LED[7:0], ADC_SCLK, ADC_CS_N, ADC_DIN, ADC_DOUT
# 依据：ACX720_FPGA管脚分配表20201221.xlsx（基本管脚 / 扩展接口GPIO0）
# 时钟：50MHz，与全组参数表一致
################################################################################

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# ==============================================
# 1. 50MHz 系统时钟
# 官方管脚：系统时钟50MHz -> FPGA_GCLK1 Y18
# ==============================================
set_property PACKAGE_PIN Y18 [get_ports CLK]
set_property IOSTANDARD LVCMOS33 [get_ports CLK]
create_clock -add -name sys_clk -period 20 -waveform {0 10} [get_ports CLK]

# ==============================================
# 2. 复位按键 S4
# 官方管脚：按键S4 -> B21，低电平有效
# ==============================================
set_property PACKAGE_PIN B21 [get_ports Reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports Reset_n]

# ==============================================
# 3. 串口收发
# 官方管脚：FPGA_UART_RX -> J21（输入）
#           FPGA_UART_TX -> M15（输出）
# ==============================================
set_property PACKAGE_PIN J21 [get_ports UART_rx]
set_property IOSTANDARD LVCMOS33 [get_ports UART_rx]
set_property PACKAGE_PIN M15 [get_ports UART_tx]
set_property IOSTANDARD LVCMOS33 [get_ports UART_tx]

# ==============================================
# 4. 开关 SW0 ~ SW7
# 官方管脚：SW0->G22  SW1->D22  SW2->E22  SW3->G21
#           SW4->E21  SW5->D21  SW6->C22  SW7->B22
#
# SW0（Mode_SW）模式
#     0 = 串口回环（拨下）      1 = 上传（拨上）
# SW1（Src_SW）上传时的数据源，只在 SW0 = 1 时有意义
#     0 = ADC 上传（拨下）      1 = DDS 上传（拨上）
# SW3:SW2（Wave_SW）DDS 波形
#     0 = 正弦   1 = 方波   2 = 三角波
# SW7:SW4（Freq_SW）DDS 频率档位 0~15，对应 0.5Hz~20Hz
# ==============================================
set_property PACKAGE_PIN G22 [get_ports Mode_SW]
set_property IOSTANDARD LVCMOS33 [get_ports Mode_SW]
set_property PACKAGE_PIN D22 [get_ports Src_SW]
set_property IOSTANDARD LVCMOS33 [get_ports Src_SW]
set_property PACKAGE_PIN E22 [get_ports {Wave_SW[0]}]
set_property PACKAGE_PIN G21 [get_ports {Wave_SW[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Wave_SW[*]}]
set_property PACKAGE_PIN E21 [get_ports {Freq_SW[0]}]
set_property PACKAGE_PIN D21 [get_ports {Freq_SW[1]}]
set_property PACKAGE_PIN C22 [get_ports {Freq_SW[2]}]
set_property PACKAGE_PIN B22 [get_ports {Freq_SW[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {Freq_SW[*]}]

# ==============================================
# 5. 按键 S0，切换 ADC 采样通道（0~7 循环）
# 官方管脚：按键S0 -> F15
# ==============================================
set_property PACKAGE_PIN F15 [get_ports Key]
set_property IOSTANDARD LVCMOS33 [get_ports Key]

# ==============================================
# 6. LED0 ~ LED7
# 官方管脚：LED0->M22, LED1->N22, LED2->L21, LED3->K21
#           LED4->K22, LED5->J22, LED6->H22, LED7->M21
# ==============================================
set_property PACKAGE_PIN M22 [get_ports {LED[0]}]
set_property PACKAGE_PIN N22 [get_ports {LED[1]}]
set_property PACKAGE_PIN L21 [get_ports {LED[2]}]
set_property PACKAGE_PIN K21 [get_ports {LED[3]}]
set_property PACKAGE_PIN K22 [get_ports {LED[4]}]
set_property PACKAGE_PIN J22 [get_ports {LED[5]}]
set_property PACKAGE_PIN H22 [get_ports {LED[6]}]
set_property PACKAGE_PIN M21 [get_ports {LED[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[*]}]

# ==============================================
# 7. External AD7606 ADC module on GPIO0
# cs_n=F14 rd_n=A18 busy=F13 reset=A19 convst=A15
# TOUCH TEST: db[2],db[3],db[10] moved to E13,E17,E19; AD7606 driver Go=0.
# os[2:0]=A16,A14,A13  db[15:0]=C13,B13,D14,D15,C14,C15,B15,B16,D17,C17,E16,D16,B17,B18,C18,C19
set_property PACKAGE_PIN F14 [get_ports ad7606_cs_n_o]
set_property PACKAGE_PIN A18 [get_ports ad7606_rd_n_o]
set_property PACKAGE_PIN F13 [get_ports ad7606_busy_i]
set_property PACKAGE_PIN A19 [get_ports ad7606_reset_o]
set_property PACKAGE_PIN A15 [get_ports ad7606_convst_o]
set_property PACKAGE_PIN A14 [get_ports {ad7606_os_o[0]}]
set_property PACKAGE_PIN A13 [get_ports {ad7606_os_o[1]}]
set_property PACKAGE_PIN A16 [get_ports {ad7606_os_o[2]}]
set_property PACKAGE_PIN C13 [get_ports {ad7606_db_i[0]}]
set_property PACKAGE_PIN B13 [get_ports {ad7606_db_i[1]}]
set_property PACKAGE_PIN E13 [get_ports {ad7606_db_i[2]}]
set_property PACKAGE_PIN E17 [get_ports {ad7606_db_i[3]}]
set_property PACKAGE_PIN C14 [get_ports {ad7606_db_i[4]}]
set_property PACKAGE_PIN C15 [get_ports {ad7606_db_i[5]}]
set_property PACKAGE_PIN B15 [get_ports {ad7606_db_i[6]}]
set_property PACKAGE_PIN B16 [get_ports {ad7606_db_i[7]}]
set_property PACKAGE_PIN D17 [get_ports {ad7606_db_i[8]}]
set_property PACKAGE_PIN C17 [get_ports {ad7606_db_i[9]}]
set_property PACKAGE_PIN E19 [get_ports {ad7606_db_i[10]}]
set_property PACKAGE_PIN D16 [get_ports {ad7606_db_i[11]}]
set_property PACKAGE_PIN B17 [get_ports {ad7606_db_i[12]}]
set_property PACKAGE_PIN B18 [get_ports {ad7606_db_i[13]}]
set_property PACKAGE_PIN C18 [get_ports {ad7606_db_i[14]}]
set_property PACKAGE_PIN C19 [get_ports {ad7606_db_i[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports ad7606_cs_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports ad7606_rd_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports ad7606_busy_i]
set_property IOSTANDARD LVCMOS33 [get_ports ad7606_reset_o]
set_property IOSTANDARD LVCMOS33 [get_ports ad7606_convst_o]
set_property IOSTANDARD LVCMOS33 [get_ports {ad7606_os_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ad7606_db_i[*]}]

# 8. Onboard 74HC595 8-digit display
#   SEG7_DIO  -> M18
#   SEG7_RCLK -> C2
#   SEG7_SCLK -> F4
# ==============================================
set_property PACKAGE_PIN M18 [get_ports SEG7_DIO]
set_property PACKAGE_PIN C2  [get_ports SEG7_RCLK]
set_property PACKAGE_PIN F4  [get_ports SEG7_SCLK]
set_property IOSTANDARD LVCMOS33 [get_ports SEG7_DIO]
set_property IOSTANDARD LVCMOS33 [get_ports SEG7_RCLK]
set_property IOSTANDARD LVCMOS33 [get_ports SEG7_SCLK]
# S1 key: amplitude level cycle
set_property PACKAGE_PIN A20 [get_ports Key_S1]
set_property IOSTANDARD LVCMOS33 [get_ports Key_S1]

# 2026-09-23: 25.6 kSPS synchronization pulse for STM32 TIM2_ETR (PA0).
set_property PACKAGE_PIN D20 [get_ports sync_25k6_o]
set_property IOSTANDARD LVCMOS33 [get_ports sync_25k6_o]
