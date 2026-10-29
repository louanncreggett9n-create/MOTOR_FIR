# P0 跨块独立验证记录

日期：2026-10-30

## 1. 验证目的

在真实电机数据不可得的条件下，使用数据集中的不同数据块检验 FPGA 16 频带分类器能否跨块工作，避免只在单一参考块上报告结果。

## 2. 模型与数据划分

- 特征：128 个 Goertzel 频点按每 8 个频点合并为 16 个频带；每个频点高度取 `mag_clip[13:6]`，每带为 8 个频点高度之和。
- 分类器：16 维曼哈顿距离最近质心分类。
- 训练：block1、block2、block3、block4。
- 独立测试：block5。
- 全局拒识：`BEST > 1250` 或 `MARGIN < 80` 时输出 `UNKNOWN`。
- BF 类能量尺度明显低于其余类别，另设 `BEST > 500` 拒识；该门限可拒绝全零/无信号向量，同时不拒绝已采集的 BF 样本（最大 BEST 为 183）。
- 质心和阈值只由 block1–4 确定，block5 未参与训练或阈值选择。

## 3. 训练集内部验证

对 block1–4 做留一块交叉验证，即每次用其中 3 块训练、剩余 1 块测试：

- 最近类别正确：22/24，91.7%。
- 主要混淆：block3 的 UNBAL 被最近质心判为 H；block4 的 H 被最近质心判为 MISAL。
- 该结果说明类别特征存在可分性，但 UNBAL 与 H、H 与 MISAL 的边界仍不稳定。

## 4. 仿真验证

Vivado xsim 使用 14 组代表性向量进行固定点 RTL 验证：

- 6 类代表向量：PASS
- BROKEN 多块样本：PASS
- 全零无信号向量：正确输出 `UNKNOWN`
- 总计：14/14 PASS
- 分类器状态机延迟：97 个时钟周期，50 MHz 下约 1.94 微秒

## 5. block5 独立测试

最终位流在 block5 上的 FPGA 实际显示结果：

| 类别 | 显示结果 | 结果 |
|---|---|---|
| H | H | PASS |
| UNBAL | UNBAL | PASS |
| MISAL | MISAL | PASS |
| BF | BF | PASS |
| BOW | BOW | PASS |
| BROKEN | BROKEN | PASS |

硬件结果为 6/6。与离线频带计算一致：

| 类别 | BEST | SECOND | MARGIN |
|---|---:|---|---:|
| H | 547 | UNBAL 949 | 402 |
| UNBAL | 765 | H 1035 | 270 |
| MISAL | 662 | H 1396 | 734 |
| BF | 183 | BOW 4056 | 3873 |
| BOW | 725 | BROKEN 1226 | 501 |
| BROKEN | 1039 | UNBAL 1161 | 122 |

## 6. 位流与实现信息

- 位流：`artifacts/MOTOR_FIR_unified_classifier_block1to4_release_20261029.bit`
- SHA256：`10115BE11CC0DFCBF51D9F80FB0C04393D47CB70FF4F3EDA3DBFE613574564CD`
- WNS：0.237 ns
- WHS：0.046 ns
- TNS/THS：0
- Vivado：2018.3
- 器件：XC7A35T-FGG484-2
- 时序约束全部满足。

## 7. 证据文件

- `artifacts/block5_final_bfgate_results_20261030.csv`
- `artifacts/model_final_block1to4_20261029/model.json`
- `artifacts/model_final_block1to4_20261029/centroids.csv`
- `artifacts/model_final_block1to4_20261029/classifier_templates_16band_candidate.vh`
- `artifacts/model_final_block1to4_20261029/damage_classifier_l1_final_block1to4_candidate.v`
- `artifacts/final_timing_summary_20261029.rpt`
- `captures/band_vector_training.json`
- `captures/final_holdout_analysis.json`

## 8. 适用边界

- 五个数据块均来自项目所用数据集，不是现场真实电机采集数据。
- block5 的 6/6 是一次独立数据块验证，不等同于对任意电机、工况和传感器安装条件普适。
- 留一块交叉验证仍有 2/24 错误，说明类别边界并非完全分离。
- 本文的验证范围是六类状态的离线回放与 FPGA 板级分类链路，不包含现场长期稳定性、不同转速负载和真实噪声条件下的泛化结论。
- 本记录不包含 SNR、SINAD、THD 或 ENOB 实测结果。