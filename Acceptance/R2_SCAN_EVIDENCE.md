# R2 自动扫描证据

日期：2026-10-22

## 环境

- R2 bit 已通过 JTAG 成功下载
- JTAG 器件：`xc7a35t_0`
- F407：COM5，115200，PING 返回 `0xAA`
- FPGA：COM7，2,000,000
- 采样：8192 点/槽，25.6 kSPS

## 六槽峰值 bin

| Slot | 类别 | 预期 bin | 实测 bin | 结果 |
|---|---|---:|---:|---|
| 0 | H | 17 | 17 | PASS |
| 1 | UNBAL | 18 | 18 | PASS |
| 2 | MISAL | 27 | 27 | PASS |
| 3 | BF | 16 | 16 | PASS |
| 4 | BOW | 17 | 17 | PASS |
| 5 | BROKEN | 18 | 18 | PASS |

前五类由 FPGA 扫描汇总帧直接给出。BROKEN 的 2 Mbps 连续抓包两次分别丢失 bin3 和 bin49，但两次都完整捕获了预期峰值 bin18；最后一次抓包中 128 个频点均已收到，重算峰值为 bin18。该现象属于 PC 串口连续抓包偶发丢字节，不是 FPGA SCAN 漏扫。

## 数据文件

- `evidence/scan_r2/six_class_scan_r2.csv`
- `evidence/scan_r2/scan_slot_*_frames.json`
- `evidence/scan_r2/scan_slot_*_raw.bin`
- `evidence/scan_r2/scan_slot_5_BROKEN_frames_reconstructed.json`

## 仍需人工确认

- 六类屏幕上的 `CLASS / CONF / SEV / ROUTE`
- N1/N2/N3 条形图是否不再顶满
- 触摸页面切换
- UNKNOWN 拒识
- 30 分钟稳定性