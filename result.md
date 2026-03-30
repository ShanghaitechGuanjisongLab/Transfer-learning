# Results

## Behavioral Definition of Transfer in the Current Paradigm

为避免把迁移学习简化为“学过一个任务后另一个任务表现更好”，本文将其严格限定为跨模态条件化任务中的加速习得现象：小鼠在学会声水偶联任务后转入光水偶联任务，相较 Naive 组直接学习光水偶联任务，表现出更高的新任务起点和更快的后续行为推进。训练范式由随机冷静期、200 ms 线索、1 s 响应窗和延迟给水构成，因此行为成功既依赖线索前抑制过早舔水，也依赖线索后迅速启动舔水反应。

> To avoid reducing transfer learning to the vague statement that one task improves another, we defined transfer as accelerated acquisition in a cross-modal conditioning paradigm: after mastering the auditory cue-water coupling task, mice transitioned to the light cue-water coupling task and showed both a higher starting point and faster subsequent improvement than Naive mice learning the light cue-water coupling task directly. The paradigm consisted of a random no-lick foreperiod, a 200 ms cue, a 1 s response window, and delayed reward delivery, so successful performance depended both on suppressing premature licking before cue onset and on rapidly initiating licking after cue onset.

![Experimental design](盲审/图3-1-1.svg)

## Transfer Produces Both a Higher Starting Point and Faster Subsequent Learning

在行为层面，迁移效应首先表现为学习曲线整体上移。无论比较声水偶联任务还是光水偶联任务，迁移组均表现出更高的第1训练日命中率，并更早达到100%命中标准。这说明当前范式可以稳定复现经典迁移研究中所强调的起点优势。进一步地，在将第1训练日表现纳入模型后，迁移组仍保留更大的增长斜率，说明迁移优势并不只是“起步更高”，而是“起步更高且后续更快”。

> At the behavioral level, the transfer effect first appeared as an upward shift of the learning curve. For both the auditory cue-water coupling task and the light cue-water coupling task, transfer groups showed higher Day 1 hit rates and reached 100% criterion earlier. This demonstrates that the present paradigm reliably reproduces the initial-entry advantage emphasized in classical transfer research. Importantly, after Day 1 performance was included in the model, transfer animals still retained steeper growth slopes, indicating that transfer was not merely “starting higher,” but “starting higher and continuing to learn faster.”

基于这一结果，后续所有分析均围绕两个相互关联但可分离的结果变量展开：一是新任务第1训练日表现，二是控制起点差异后的后续习得速度。这一拆分同时为神经层面的机制判定提供了坐标系，因为不同回路节点和不同群体指标未必作用于同一行为分量。

> On the basis of this result, all subsequent analyses were organized around two related but separable outcome variables: Day 1 performance in the new task and the rate of subsequent acquisition after controlling for starting-point differences. This decomposition also provided the coordinate system for neural interpretation, because different circuit nodes and population metrics need not act on the same behavioral component.

![Learning curves and first-session effect](盲审/图3-1-2.svg)

![Slope after controlling Day 1](盲审/图3-1-3.svg)

## Naive Learning Reveals a Cue-Triggered Transition from Resting to Action States

为了理解迁移首日优势究竟在调用什么，本文首先分析了 Naive 学习中的基本神经组织。双光子钙成像显示，学会后的 MOp 并非简单叠加纯线索与纯奖励反应，而是形成了更清晰的任务相关结构。线索到来后，静息态活跃细胞被抑制，动作态活跃细胞被启动，表明学会后的任务执行依赖于一个由线索驱动的状态切换过程，而非单纯依赖等待期内部的自发衰变。

> To understand what is being recruited on transfer Day 1, we first characterized the basic neural organization of Naive learning. Two-photon calcium imaging showed that learned MOp activity was not a simple superposition of cue-only and reward-only responses, but instead formed a clearer task-related structure. After cue onset, resting-state-active cells were suppressed while action-state-active cells were engaged, indicating that learned task execution depends on a cue-driven state transition rather than a simple spontaneous decay during the waiting period.

PCA 进一步表明，不同试次在起始时点的网络状态可以分散，但线索后 1 s 内的群体偏移方向相对一致，且终点离散度小于起点离散度。这意味着线索并不是把网络拉向某一完全固定的终点，而是在不同背景状态上施加方向稳定的推进信号，使网络快速进入与舔水输出相容的轨迹区间。

> PCA further showed that network states at trial onset could be broadly distributed across trials, yet the population shift during the 1 s after cue onset followed a relatively consistent direction, and the end-state dispersion was smaller than the start-state dispersion. Thus, the cue did not pull the network toward one rigid endpoint, but instead imposed a directionally stable drive on variable background states, pushing the system into a trajectory regime compatible with licking output.

![Resting and action states](盲审/图3-2-1.svg)

![In vivo calcium imaging in MOp](盲审/图3-2-2.svg)

![State switching model](盲审/图3-2-4.svg)

## Day 1 Advantage Is Linked to Ensemble Reactivation and Reduced Divergence

迁移首日高命中的最直接神经特征是旧任务相关群体的重激活。声水偶联任务学会阶段活跃的细胞，在光水偶联任务迁移阶段命中试次中更容易再次活跃，其重激活率和 1 s 响应强度均高于错失试次；在鼠间比较中，重激活率越高，迁移首日命中率也越高。这表明迁移首日优势并非随机波动，而是与旧任务群体结构能否被新线索再次调用密切相关。

> The most direct neural signature of high Day 1 transfer performance was reactivation of prior-task ensembles. Cells active during the learned auditory cue-water coupling task were more likely to become active again during hit trials in the transfer light cue-water coupling task, and both their reactivation rate and 1 s response magnitude were higher in hits than in misses. Across mice, higher reactivation rates were associated with higher transfer Day 1 hit rates. Thus, the Day 1 advantage was not a random fluctuation, but closely linked to whether the new cue could recruit the prior-task population structure.

然而，迁移与 Naive 的差异并不能被“总体活动更强”概括。全细胞平均曲线在两组间基本相近，但迁移组具有更高的活跃细胞比例与更低的相对散度，尤其体现在 MOp2/3。换言之，迁移不是把整个群体统一抬高，而是使一部分正确的细胞更稳定地进入任务相关状态，从而降低试次间的不确定性。

> Importantly, the difference between transfer and Naive could not be reduced to “more overall activity.” Population-averaged traces were broadly similar between groups, yet transfer mice showed a higher fraction of active cells and lower relative divergence, especially in MOp2/3. In other words, transfer did not elevate the whole population uniformly; instead, it stabilized the recruitment of a subset of appropriate cells, thereby reducing trial-to-trial uncertainty.

两类操纵为这一解释提供了因果支持。其一，利用 cFos 标记并抑制声水偶联任务学会阶段活跃的 MOp 细胞，可使迁移学习曲线整体下移，而非特异性广谱抑制 MOp 并不产生同样效应。其二，在声水偶联任务学会与光水偶联任务迁移之间加入 7 天间隔，会同时降低重激活率、提高散度并削弱迁移首日表现。这两项结果共同支持：迁移起点优势依赖于一组可被再次调取的历史活跃细胞，而不是单纯依赖一般性学习能力或短暂状态变化。

> Two manipulations provided causal support for this interpretation. First, cFos-based tagging and inhibition of MOp cells active during the learned auditory cue-water coupling task shifted the transfer learning curve downward, whereas nonspecific broad inhibition of MOp did not produce the same effect. Second, imposing a 7-day delay between the learned auditory cue-water coupling task and transfer to the light cue-water coupling task reduced reactivation, increased divergence, and weakened transfer Day 1 performance. Together, these findings support the idea that the initial transfer advantage depends on a historical cell population that can be recruited again, rather than on generic learning ability or transient state changes alone.

![Reactivation during transfer](盲审/图3-3-1.svg)

![Naive versus transfer population response](盲审/图3-3-2.svg)

![Trial-to-trial divergence](盲审/图3-3-3.svg)

![cFos manipulation](盲审/图3-3-4.svg)

![Seven-day interval manipulation](盲审/图3-3-5.svg)

## Subsequent Learning Is Associated with More Efficient State-Space Trajectories and Response Heterogeneity

在控制第1训练日表现之后，迁移学习仍表现出更快的后续推进。状态空间分析表明，这种优势并不是因为每一步都更大，而是因为迁移组的跨训练日轨迹更接近起点到终点的直线方向，曲折度更低。与之相符，单步总长度在组间并无显著差异，但沿最优方向的有效投影在迁移组更大。这说明迁移后续优势更接近“方向优化”，而不是“非特异性增量放大”。

> Even after controlling for Day 1 performance, transfer learning still showed faster subsequent progression. State-space analysis indicated that this advantage did not arise because each step was larger, but because trajectories across training days were more closely aligned with the straight start-to-end direction and were less tortuous. Consistent with this, total step length did not differ markedly between groups, whereas effective projection onto the optimal direction was larger in transfer animals. Thus, the later advantage of transfer is better understood as directional optimization rather than nonspecific amplification of update size.

这一过程对应的细胞层指标是响应异质性。迁移阶段的群体并非总体更亮，而是更多细胞从 0 附近分化到正负两端，形成更明确的响应梯度。响应异质性越高，学习斜率越大，轨迹偏离越小，说明群体分化有助于把跨训练日更新限制在行为相关方向上。与首日机制不同，这一表型主要集中在 MOp5，而不是 MOp2/3。

> The cell-level correlate of this process was response heterogeneity. The transfer population was not globally brighter; rather, more cells were polarized away from zero toward positive and negative response extremes, creating a clearer response gradient. Higher response heterogeneity was associated with steeper learning slopes and smaller path deviation, indicating that population differentiation helps constrain across-day updating to behaviorally relevant directions. Unlike the Day 1 mechanism, this phenotype was concentrated mainly in MOp5 rather than MOp2/3.

后部丘脑抑制进一步表明，这一后续习得优势依赖上游输入门控。抑制以 PO 为中心的后部丘脑不会明显降低迁移首日表现，也不会显著降低旧群体重激活率，却会降低 MOp5 响应异质性并减小相邻训练日间的 ΔHit。由此可见，后部丘脑更可能参与后续习得速度的组织，而非首日旧结构调用本身。

> Posterior thalamic inhibition further demonstrated that this later learning advantage depends on upstream gating. Inhibiting the posterior thalamic region centered on PO did not strongly reduce transfer Day 1 performance and did not significantly reduce reactivation of prior-task ensembles, but it did decrease MOp5 response heterogeneity and reduce ΔHit between adjacent training days. Thus, posterior thalamus appears to organize the speed of subsequent acquisition rather than the initial recruitment of prior structure itself.

![State-space trajectory efficiency](盲审/图3-4-1.svg)

![Response heterogeneity](盲审/图3-4-2.svg)

![Posterior thalamic manipulation](盲审/图3-4-3.svg)

## RSP Behaves Like a Visually Biased Upstream Input Rather Than the Core Bottleneck

RSP 的位置与响应特征都支持其作为视觉相关上游节点的身份。它位于视觉皮层与运动皮层之间，对光水偶联任务线索的反应强于对声水偶联任务线索的反应，且对光线索的启动早于 MOp。这说明 RSP 具备把视觉信息更早送入感觉-运动网络的条件。

> Both the location and response profile of RSP support its identity as a visually biased upstream node. It lies between visual and motor cortex, responds more strongly to the light cue-water coupling task than to the auditory cue-water coupling task, and exhibits earlier visual-cue onset than MOp. This places RSP in a suitable position to deliver visual information into the broader sensorimotor network at an earlier stage.

但现有证据并不支持 RSP 是驱动迁移成绩变化的核心瓶颈。RSP 内旧任务活跃细胞的重激活与迁移首日命中率相关性不强，命中与错失试次间差异也较弱；更重要的是，单独抑制 RSP 未显著降低迁移学习曲线。因此，RSP 更适合被解释为偏视觉模态的信息接入或辅助整合节点，而不是决定迁移成败的主要存储位点。

> However, the available evidence does not support RSP as the core bottleneck that determines transfer performance. Reactivation of prior-task-active cells in RSP showed weak association with transfer Day 1 hit rate, and the difference between hit and miss trials was modest. More importantly, selective RSP inhibition alone did not significantly reduce the transfer learning curve. RSP is therefore better interpreted as a visually biased access or auxiliary integration node, rather than the main storage site that determines transfer success.

![RSP as a visually biased upstream input](盲审/图3-5-1.svg)

## Transfer Reuses Shared Information Structure and Enters a More Prepared Baseline State

信息论分析从另一个角度支持了上述双分量框架。相较 Naive 学习，迁移阶段与学会阶段共享的信息结构更多，而从迁移到最终学会所需新增的信息成分较少，甚至伴随更多旧成分弃用。这说明迁移并不主要依赖从零搭建新结构，而更像是在较大共享背景上的定向重组、精简和特化。

> Information-theoretic analysis supported the same two-component framework from a different angle. Relative to Naive learning, the transfer stage shared more information structure with the learned stage, while the amount of newly added information required to reach final learning was smaller and was even accompanied by greater pruning of obsolete components. This indicates that transfer does not mainly rely on constructing a new structure from scratch, but rather on targeted reorganization, refinement, and specialization on top of a broad shared background.

在线索前的静息态分析则显示，学会与迁移阶段在基线期均呈现更强的自发收敛：试次间散度在接近线索前逐渐下降，且这一收敛也与无线索条件下的自发舔水前过程相关。尽管当前证据仍主要停留在相关层面，但它提示迁移优势不仅体现在“线索来了之后网络读得更快”，也体现在“线索到来之前网络已经更接近可被推进的准备状态”。

> Analysis of the pre-cue resting state showed that both learned and transfer stages exhibited stronger spontaneous convergence during baseline: trial-to-trial divergence gradually declined as cue onset approached, and this convergence was also temporally related to spontaneous uncued licking. Although the present evidence remains primarily correlational, it suggests that transfer advantage is not expressed only because the network responds better after cue onset, but also because the network is already closer to a pushable preparatory state before the cue arrives.

综上，结果部分支持一个清晰的双分量结论：迁移首日优势主要对应旧任务相关群体的重激活与低散度稳定进入；迁移后续优势主要对应 MOp5 响应异质性升高、状态空间轨迹更接近目标方向，并受到后部丘脑输入的支持。

> Taken together, the Results support a clear two-component conclusion: the Day 1 transfer advantage corresponds primarily to reactivation of prior-task ensembles and stable low-divergence entry into the new task, whereas the later transfer advantage corresponds primarily to elevated MOp5 response heterogeneity, more target-aligned state-space trajectories, and support from posterior thalamic input.

![Shared and added information structure](盲审/图3-6-3.svg)

![Baseline convergence before cue](盲审/图3-7-1.svg)
