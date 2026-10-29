# 代码包内容

## 源码

- `FPGA/new`：通用 RTL 和 scan_b
- `FPGA/ui_rtl`：UI、GT911、显示与 UART RTL
- `FPGA/vendor_touch`：GT911 底层 RTL
- `FPGA/ip`：10 个 Vivado IP
- `FPGA/ui_mem`：字体和字符平面
- `FPGA/ui_constr`：UI 约束
- `FPGA/build`：FPGA 构建脚本与板级约束
- `F407`：完整 Keil 工程
- `Classifier/rtl`：最终分类器 RTL 与 testbench
- `Classifier/model`：最终模型、5 块验证向量和仿真向量

## 发布文件

- `Release_Final`：最终 bit、F407 HEX、五块数据镜像、模型、跨块验收记录和时序报告
- `Release_R2`：历史 R2 基准版本
- `Acceptance`：历史验收、自动扫描、时序、资源和 FIR 修复证据
- `Tools`：工程重建、bitgen、六类扫描和 F407 数据加载工具

## 已排除

- Vivado `.Xil`、`.cache`、`.runs`、`.hw`
- Keil 编译中间文件和输出目录
- 历史 `before_*` 备份
- 临时仿真数据库
- 与最终提交无关的调试候选 bit