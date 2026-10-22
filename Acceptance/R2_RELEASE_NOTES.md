# R2 发布说明

## 相对旧版本的变化

- 修复统一 Vivado 工程中 7 个 FIR IP 错误共用同一组 Vector 系数的问题。
- 恢复 L1、L2、N1、N2、N3、RB、ENV 各自的原始 COE。
- 修复后 N1/N2/N3 不再饱和，SCAN 的 L2 输入频谱恢复正常。
- 新增统一工程的综合、实现、时序、bitgen证据。
- 新增 SPIx4 bit/MCS/BIN 候选镜像。

## 验证状态

- FPGA 综合：PASS
- 布局布线：PASS
- 时序：PASS
- bitgen：PASS
- JTAG 上板：用户已确认问题消失
- R2 bit JTAG 下载：PASS
- 六槽自动频谱扫描：PASS（峰值 bin 全部匹配）
- 六类 UI 分类：PASS
- 触摸和 UNKNOWN：PASS
- 30 分钟稳定性：PASS
- Flash 烧录：PENDING / 尚未验证

## 风险

1. 当前 Flash 编程仍受 Vivado 2018.3 `Failure to set flash parameters` 影响。
2. 现场演示必须准备 JTAG 重烧流程和旧版本回滚 bit。
3. 所有后续截图和视频都必须使用 R2 普通 bit，不能混用旧 bit。