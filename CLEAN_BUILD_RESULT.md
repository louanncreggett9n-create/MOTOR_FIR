# 提交包干净构建验证

日期：2026-10-22

## 验证方式

提交包内只保留 IP 的 `.xci` 源配置和原始 COE，不携带 IP 生成缓存。执行：

```powershell
cd FPGA/build
vivado -mode batch -source .\build_full_relative.tcl
```

构建脚本会：

1. 创建 `xc7a35tfgg484-2` 内存工程
2. 读取 10 个 XCI
3. `generate_target all`
4. 以分类器 UI 为活动 UI，综合、实现、时序和 bitgen

## 结果

```text
IP stale/locked critical warnings: 0
Synthesis: 0 errors, 0 critical warnings
Route: PASS
Bitgen: PASS
WNS: +0.674 ns
WHS: +0.056 ns
All user specified timing constraints are met.
```

重建 bit：

- `FPGA/build/MOTOR_FIR_system_touch_rebuilt.bit`
- SHA256：`E82921D9051439A5319363CB3E9D725C122698D06810C0BD7B8B0F669E6DEC0B`

注意：这个 bit 是“干净代码包可重建”证据，现场最终验证使用的是：

```text
Release_R2/MOTOR_FIR_unified_classifier_fixed_20261022.bit
SHA256 4EDC220AF3CBF82D127351A3B6BF539B4A9D367A5FEF2E9E4894B9938ADBF092
```