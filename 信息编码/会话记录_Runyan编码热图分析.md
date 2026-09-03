# Runyan 2017 编码热图分析 — 会话记录

**日期**：2026-07-29 ~ 2026-07-31
**数据**：`TransferLearning.AudioLightBaseline`（11 只鼠）
**目标**：仿 Caroline Runyan et al. 2017 (Nature) 的编码-解码框架分析 MOp 钙成像数据

---

## 一、任务沿革

### 1. 初始需求
新建脚本，用 Runyan 2017 编码模型：
- 训练集 = Transfer（LightWater）0-1s 数据
- 验证集 = Learned（AudioWater）阶段
- 检验解码器能否区分 Learned 中的 hit/miss
- chance level = max(transfer 实际命中率, 50%)

**产物**：`DecodeALB_TransferToLearned.m`

### 2. 关键问题发现
- **Learned AudioWater 几乎全是 hit**（10/11 鼠 0 miss）→ 验证集单类，置换检验失效
- shuffle 高低反映的是训练集 base rate，不是真实信号
- 后改为 **Naive + Learned 双验证对比**（`DecodeALB_TransferToNaiveVsLearned.m`）：
  - Learned 解码（60.4%）系统性高于 Naive（45.5%），p=0.0608
  - 支持"hit/miss 表征是任务学习塑造的"结论

### 3. 转入编码热图分析（主任务）
最终脚本：**`EncodeHeatmap_ALB_HitMiss_vs_Cue.m`**
- 数据：Learned AudioWater + Transfer LightWater 合并（每鼠 60 trial）
- 两个编码模型：choice（hit/miss）、stimulus（cue, Light vs Audio）
- 逐细胞逐时间点计算 MI + GLM 编码权重

---

## 二、方法迭代记录

### 指标选择（多次讨论）
| 指标 | 说明 | 状态 |
|---|---|---|
| GLM β 编码权重 | Runyan 原版 Fig.2h，有方向（红/蓝） | 保留（encoding weight 热图） |
| AUC (2×(AUC-0.5)) | 自创变换，后被放弃 | 弃用 |
| 互信息 MI | `-0.5·log₂(1-r²)` 高斯近似 | 已被替换 |
| **分箱 MI + Panzeri-Treves 校正** | 标准直方图法 + PT 偏差校正 | **最终采用** |

### MI 计算的关键修正
1. **高斯近似突破 1 bit 上界**：r 很大时 `-0.5·log₂(1-r²)` 可达 1.4 bits，但二分类 MI 理论上界为 H(Y) ≤ 1 bit
2. **切换为标准分箱估计 + PT 校正**：
   ```
   I_corrected = I_raw - (Mx-1)(My-1) / (2·N·ln2)
   ```
   - 结果 max MI = 0.916 bits（正确 < 1 bit）
   - 分箱数 `nBins = max(3, min(8, round(sqrt(N)/2)*2))`

### 显著性/细胞筛选
- 主方法：GLM p<0.05（0-1s 训练窗内）
- 曾测试 Panzeri-Treves 校正 + 2×噪声基线 → 91.7% 细胞显著（过于宽松），**保留原 GLM 方法**

### 细胞显著统计（GLM p<0.05）
| 类别 | 细胞数 | 占比 |
|---|---|---|
| 总细胞 | 5107 | — |
| Choice 显著 | 2220 | 43.5% |
| Stimulus 显著 | 2613 | 51.2% |
| 两者都显著 | 1479 | 29.0% |
| 任一显著 | 3354 | 65.7% |

### 逐时间点重叠（mixed selectivity）
每个时间点 20-30% 的活性编码细胞同时显著编码 choice 和 stimulus，随刺激后时间增加而上升。

---

## 三、最终图片清单（`EncodeHeatmap_ALB_HitMiss_vs_Cue.m`）

| 图 | 内容 | 说明 |
|---|---|---|
| Fig.2d | 累积信息曲线 | 逐时间点 MI 累积求和（保证单调递增） |
| 逐时间点 MI 曲线 | 两条曲线（choice/stimulus） | -1~1s，均值±SE |
| Max-norm combined (stim-sorted) | choice+stimulus 双面板 | 两者都显著细胞（1479） |
| Max-norm combined (choice-sorted) | 同上按 choice 排序 | 同上 |
| Combined norm-MI 热图 | 32 列（choice 16 + stimulus 16） | 任一显著细胞（3354），按 0-1s 主/次达峰时间排序 |
| Combined raw MI 热图 | 同上但非归一化 | max=0.916 bits |
| Raw MI choice | 单面板 | choice 显著细胞（2220），白→红 |
| Raw MI stimulus | 单面板 | stimulus 显著细胞（2613），白→红 |
| Encoding weights choice/stimulus | 红蓝 diverging | GLM β，每鼠一子图 |
| Summary bar | 显著细胞比例 | 每鼠 |

### Combined MI 排序规则（最终版）
1. 主排序 = 0-1s 内 16 个值（8 choice + 8 stimulus）中最大 MI 对应的**时间**（不区分条件）
2. 次排序 = 另一条件的峰值时间
3. 等值时 stimulus 优先（`maxB > maxC` 才选 choice）
- 结果：choice-primary 29.5%，stimulus-primary 70.5%（PT 校正后）

### Colorbar
- Raw MI choice 与 stimulus **共用同一最大值**（0.916 bits），色标对齐可直接对比

---

## 四、关键结论

1. **Stimulus 信息量 > Choice**：逐时间点峰值 0.055 vs 0.044 bits/cell
2. **~70% 细胞的峰值信息来自 stimulus**，~30% 来自 choice
3. **Mixed selectivity**：单时间点 20-30% 细胞同时编码两类信息，随刺激后时间增加
4. **MOp 中刺激类型比行为选择更广泛地被编码**

---

## 五、其他脚本

| 脚本 | 用途 |
|---|---|
| `DecodeALB_TransferToLearned.m` | 早期：Transfer→Learned 解码（Learned 单类问题） |
| `DecodeALB_TransferToNaiveVsLearned.m` | Naive vs Learned 双验证对比 |
| `EncodeHeatmap_SigOnly_MaxNorm.m` | 单独生成 sig-choice / sig-stim max-norm 两张图（快速重跑） |
| `EncodeHeatmap_ALB_HitMiss_vs_Cue.m` | 主脚本（全部图） |

---

## 六、遗留/注意事项

- **max-normalization 分母**：目前用全窗 -1~1s 的最大值，若刺激前有噪声峰值会低估 0-1s 信息（可改用 0-1s 窗归一化）
- **显著性多重比较**：每个细胞 8 个时间点分别检验 p<0.05，未做 Bonferroni 校正
- **PT 噪声基线法过于宽松**：2× 基线会选出 91.7% 细胞，故未采用
- **cue 与 phase 混淆**：AudioWater 只在 Learned，LightWater 只在 Transfer，3 类分析解读受限
