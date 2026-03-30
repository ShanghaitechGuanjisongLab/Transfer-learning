# Discussion

## Cross-Modal Transfer Contains Two Mechanistically Distinct Components

本研究支持一个比“迁移让动物学得更快”更具体的结论：跨模态迁移优势由两个彼此衔接、但并不等价的组成部分构成。第一部分是新任务开始时的初始表现优势，其主要对应旧任务相关细胞集合在新线索下的再激活，以及更低的试次间散度。第二部分是在控制首日表现后依然存在的后续学习优势，其主要对应更高的响应异质性和更定向的状态空间推进。这样的双成分框架能够同时解释 Figure 1 到 Figure 3 的结果，也解释了为什么不同指标和不同操纵并不会全部指向同一个单一答案（Smith et al., 2006; Vyas et al., 2020）。

> The present study supports a more specific conclusion than the generic statement that transfer simply makes animals “learn faster.” Cross-modal transfer advantage contains two linked but non-equivalent components. The first is an initial-performance advantage at the onset of the new task, associated primarily with reactivation of prior-task ensembles under the new cue and with reduced inter-trial divergence. The second is a subsequent-learning advantage that persists after adjustment for Day 1 performance and is associated primarily with greater response heterogeneity and more directed progression through state space. This two-component framework explains the results across Figures 1 to 3 and also explains why different metrics and manipulations do not collapse into a single uniform answer (Smith et al., 2006; Vyas et al., 2020).

这一区分在理论上很重要，因为它把迁移从笼统的行为现象转化为可分解的机制问题。更高的起点并不必然意味着后续学习更快，而后续学习更快也不一定要求首日表现显著升高。我们观察到，旧集合再激活、cFos 标记抑制和 7 天间隔效应主要影响首日进入 learned-like 状态的能力；而 ΔHit、响应异质性和后部丘脑抑制则更多指向后续学习过程中的群体组织维持与轨迹优化。因此，迁移并不是一个单一总量的增强，而是状态初始化与后续动力学重整共同作用的结果。

> This distinction matters theoretically because it converts transfer from a broad behavioral phenomenon into a decomposable mechanistic problem. A higher starting point does not necessarily imply faster later learning, and faster later learning does not require a large Day 1 advantage. In our data, reactivation of prior ensembles, cFos-tagged inhibition, and the 7-day interval manipulation primarily affected the ability to enter a learned-like state at the beginning of transfer. By contrast, Delta Hit, response heterogeneity, and posterior-thalamic inhibition pointed more strongly to maintenance of population organization and trajectory optimization during subsequent acquisition. Transfer is therefore not a unitary increase in one global quantity, but the combined outcome of state initialization and later dynamical refinement.

## Initial Advantage Reflects Reuse of Pre-Training Ensembles Rather Than Nonspecific Gain

Results 的第一条主线是，迁移的首日优势更符合“旧集合复用”而非“全局增益放大”。Transfer 组在新任务中具有更高的初始命中率，而这一优势伴随 learned auditory 状态中活跃细胞在 visual transfer 中的显著再激活。再激活在 hit 中高于 miss，并且与首日表现正相关；对这些预训练活跃集合进行化学遗传抑制会直接损害迁移表现。这组结果使得“首日优势只是觉醒更高、动机更强或系统整体反应更大”的解释变得不充分，因为真正与行为关联的是特定旧集合的重用，而不是无差别的活动升高（Tonegawa et al., 2015; Josselyn and Tonegawa, 2020）。

> The first major result-level conclusion is that the Day 1 advantage of transfer is better explained by reuse of prior ensembles than by global gain amplification. Transfer mice showed higher initial performance in the new task, and this advantage was accompanied by prominent reactivation of cells that had been active in the learned auditory state. Reactivation was higher in hit than in miss trials and positively associated with initial transfer performance; chemogenetic inhibition of these pre-training-related ensembles directly impaired transfer. This pattern makes it difficult to explain the initial advantage as merely higher arousal, stronger motivation, or globally enhanced responsiveness, because behavior tracked the reuse of a specific prior ensemble rather than indiscriminate activity elevation (Tonegawa et al., 2015; Josselyn and Tonegawa, 2020).

同样重要的是，补充分析显示迁移并未带来所有细胞平均响应的统一增强。整体热图和平均钙信号高度重叠，而 1 s z-score 与活跃细胞比例呈现并不同步的变化，更接近于群体响应再分配而不是统一放大。换言之，迁移的首日优势并不是“更多细胞一起更强地响应”，而是“更合适的那部分细胞集合被重新组织到新任务中”。这一点为后续关于散度和响应异质性的解释奠定了基础（Komiyama et al., 2010; Gallego et al., 2020）。

> Equally important, the supplementary analyses showed that transfer did not produce a uniform increase in mean population response. Global heatmaps and average calcium signals overlapped substantially between groups, whereas the 1 s z-score and active-cell fraction changed in non-parallel ways, consistent with redistribution of population responses rather than uniform amplification. In other words, the initial transfer advantage did not arise because more cells responded more strongly in general, but because the appropriate subset of cells was reorganized into the new task. This point is critical for interpreting the later results on divergence and response heterogeneity (Komiyama et al., 2010; Gallego et al., 2020).

## Later Learning Depends on Inherited Population Geometry and Response Heterogeneity

Results 的第二和第三条主线共同说明，迁移的后续优势并不能被旧集合再激活单独解释。群体轨迹分析表明，transfer 学习并没有显著增加每天更新的总步长，而是减少了路径弯曲，使状态推进更接近起点到终点的直接方向。与此同时，响应异质性在迁移学习中增强，并与学习斜率相关。这意味着迁移改善的不是“变化幅度”，而是“变化方向和群体分化结构”。先前经验似乎留下了一种可以继续被利用的群体组织，使系统在新任务中不必盲目探索，而能更快进入有效的状态空间区域（Sadtler et al., 2014; Perich et al., 2018; Vyas et al., 2020）。

> The second and third result-level conclusions jointly show that later transfer advantage cannot be explained by ensemble reactivation alone. Population trajectory analyses indicated that transfer did not significantly increase the total magnitude of day-to-day updates, but instead reduced path curvature and made state progression more closely aligned with the direct start-to-end direction. At the same time, response heterogeneity increased during transfer and correlated with learning slope. This implies that transfer improves not the size of change, but the direction of change and the organization of population differentiation. Prior experience appears to leave behind a reusable architecture that allows the system to avoid blind exploration and move more efficiently into an effective region of state space in the new task (Sadtler et al., 2014; Perich et al., 2018; Vyas et al., 2020).

这种解释也帮助理解为什么 reactivation rate 和 divergence 能解释首日表现，却不能显著解释 ΔHit。首日优势更像是系统能否快速调用旧状态；而后续学习速度更像是系统在进入新任务后，能否维持并扩展一种有利的群体分化结构。我们观察到的响应分布远离零值、正负两端更明显极化，正是这种结构化分化的一个直接表征。因此，后续学习的关键不是简单重复旧任务，而是在旧结构基础上进行带方向的再组织。

> This interpretation also explains why reactivation rate and divergence accounted for initial performance but did not significantly explain Delta Hit. The Day 1 advantage is more about whether the system can rapidly recruit a prior state, whereas the speed of later learning is more about whether the system can maintain and extend a favorable architecture of population differentiation after entering the new task. The observed shift of response distributions away from zero, with stronger positive and negative polarization, is a direct expression of this structured differentiation. Later learning therefore depends not on simply repeating the prior task, but on directionally reorganizing activity on top of inherited structure.

## Circuit Dissociation: MOp, Posterior Thalamus, and RSPd Contribute Differently

从回路角度看，当前结果更支持分工模型而不是单中心模型。MOp 是迁移优势的主要表达位点，但不同层次承担的角色并不相同。较浅层在视觉迁移中表现出更明显的散度降低，更接近旧结构稳定调用这一过程；较深层则与 ΔHit 和响应异质性变化联系更紧，更接近后续学习中与行为输出相关的群体重整。这种层间分化与运动皮层中不同投射类群和层特异学习机制的文献是一致的（Oswald et al., 2013; Currie et al., 2022）。

> At the circuit level, the data favor a division-of-labor model rather than a single-center account. MOp is the principal locus in which transfer advantage is expressed, but different layers do not appear to serve identical functions. More superficial layers showed clearer reduction of divergence during visual transfer and are therefore more closely associated with stable recruitment of prior structure. Deeper layers were more tightly linked to Delta Hit and response heterogeneity and therefore appear more closely related to population reorganization supporting later learning and behavioral output. This laminar dissociation is consistent with the literature on projection-class diversity and layer-specific learning mechanisms in motor cortex (Oswald et al., 2013; Currie et al., 2022).

后部丘脑提供了更关键的因果分离。其抑制对初始表现影响有限，却削弱了响应分化并降低了 ΔHit。这说明后部丘脑更可能参与维持后续学习所需的群体组织，而不是直接决定旧集合是否能在首日被调用。换言之，旧结构调用与后续学习支持在实验上是可以拆开的。RSPd 的结果则进一步限定了上游视觉输入的角色。RSPd 对视觉任务反应更早、更强，说明它确实携带视觉偏置输入；但其再激活与首日表现的关系较弱，单独抑制对迁移行为影响也有限，因此它更像上游接入节点，而不是控制迁移成败的主要瓶颈（Halassa and Sherman, 2019; Shepherd and Yamawaki, 2021; Alexander et al., 2023; Vedder et al., 2017）。

> Posterior thalamus provided the clearest causal dissociation. Its inhibition had limited impact on initial performance, yet reduced response polarization and lowered Delta Hit. This suggests that posterior thalamus contributes more to maintaining the population organization required for later learning than to determining whether prior ensembles can be recruited at the outset. In other words, prior-structure recruitment and subsequent-learning support can be experimentally separated. The RSPd results further delimit the role of upstream visual input. RSPd responded earlier and more strongly to the visual task, indicating that it does provide visually biased input; however, its reactivation showed only a weak relation to initial performance, and inhibition of RSPd alone had limited behavioral impact. RSPd therefore appears to function more as an upstream access node than as the principal bottleneck that controls transfer success (Halassa and Sherman, 2019; Shepherd and Yamawaki, 2021; Alexander et al., 2023; Vedder et al., 2017).

## Relation to Competing Accounts, Limitations, and Outlook

这些结果共同排除了几种过于简化的解释。纯泛化模型可以解释首日优势，但难以解释控制初始表现后仍存在的后续学习差异。纯全局学习率模型预期每天都会出现更大的步长更新，但我们看到的是方向性更优而非幅度更大。纯记忆印迹再激活模型则很好地解释了首日优势，却不足以涵盖后续学习中响应异质性、轨迹定向化和后部丘脑调制的结果。因此，更符合数据的解释是一个混合框架：旧任务留下可复用的群体结构，先支持新任务的快速进入，再为后续学习提供有利的动力学约束（Thorndike and Woodworth, 1901; Perkins and Salomon, 1992, 1994; Tonegawa et al., 2015）。

> Taken together, these results rule out several overly simplified explanations. A pure generalization account can explain the Day 1 advantage, but not the persistence of later learning differences after adjustment for initial performance. A pure global learning-rate account predicts larger updates on each day, whereas we observed better directionality rather than larger step magnitude. A pure engram-reactivation account explains the initial advantage well, but is insufficient to capture the results on response heterogeneity, directional trajectories, and posterior-thalamic modulation during later learning. A hybrid framework therefore fits the data better: prior training leaves behind a reusable population structure that first supports rapid entry into the new task and then provides favorable dynamical constraints for subsequent learning (Thorndike and Woodworth, 1901; Perkins and Salomon, 1992, 1994; Tonegawa et al., 2015).

当然，本文仍有边界。部分操纵尤其是 RSPd 的证据更接近“效应有限”而非“完全排除作用”。此外，再激活、散度和响应异质性都属于操作性指标，它们抓住了迁移中的关键结构，但并不穷尽全部机制。未来若能在同一动物中结合跨区同步记录、投射特异操纵以及更精细的时间窗分析，将更有助于澄清视觉输入如何进入既有感觉-动作框架，以及后部丘脑如何在跨训练日尺度上稳定后续学习所需的群体结构。总体而言，当前结果把行为迁移、集合复用、群体几何和回路因果性连成了一条更完整的解释链。

> The study nevertheless has clear boundaries. Some manipulations, especially those involving RSPd, provide evidence more consistent with limited effect than with complete exclusion. In addition, reactivation, divergence, and response heterogeneity are operational metrics that capture key structures in transfer but do not exhaust the full mechanism. Future work combining inter-regional simultaneous recordings, projection-specific manipulations, and finer temporal analyses in the same animals should better resolve how visual input accesses an existing sensorimotor framework and how posterior thalamus stabilizes the population structure required for later learning across training days. Overall, the present results link behavioral transfer, ensemble reuse, population geometry, and circuit-level causality within a more coherent mechanistic account.

## References

Alexander, A. S., Place, R., Starrett, M. J., Chrastil, E. R., & Nitz, D. A. (2023). Rethinking retrosplenial cortex: Perspectives and predictions. Neuron, 111(2), 150-175.

Barnett, S. M., & Ceci, S. J. (2002). When and where do we apply what we learn?: A taxonomy for far transfer. Psychological Bulletin, 128(4), 612-637.

Currie, S. P., Ammer, J. J., Premchand, B., et al. (2022). Movement-specific signaling is differentially distributed across motor cortex layer 5 projection neuron classes. Cell Reports, 39(6), 110801.

Gallego, J. A., Perich, M. G., Chowdhury, R. H., Solla, S. A., & Miller, L. E. (2020). Long-term stability of cortical population dynamics underlying consistent behavior. Nature Neuroscience, 23(2), 260-270.

Halassa, M. M., & Sherman, S. M. (2019). Thalamocortical circuit motifs: a general framework. Neuron, 103(5), 762-770.

Inagaki, H. K., Inagaki, M., Romani, S., & Svoboda, K. (2018). Low-dimensional and monotonic preparatory activity in mouse anterior lateral motor cortex. The Journal of Neuroscience, 38(17), 4163-4185.

Josselyn, S. A., & Tonegawa, S. (2020). Memory engrams: recalling the past and imagining the future. Science, 367(6473), eaaw4325.

Komiyama, T., Sato, T. R., O'Connor, D. H., et al. (2010). Learning-related fine-scale specificity imaged in motor cortex circuits of behaving mice. Nature, 464, 1182-1186.

Oswald, M. J., Tantirigama, M. L. S., Sonntag, I., Hughes, S. M., & Empson, R. M. (2013). Diversity of layer 5 projection neurons in the mouse motor cortex. Frontiers in Cellular Neuroscience, 7, 174.

Perich, M. G., Gallego, J. A., & Miller, L. E. (2018). A neural population mechanism for rapid learning. Neuron, 100(4), 964-976.

Perkins, D. N., & Salomon, G. (1992). Transfer of learning. In International Encyclopedia of Education. Pergamon Press.

Perkins, D. N., & Salomon, G. (1994). Transfer of learning. In International Encyclopedia of Education (Second Edition). Pergamon Press.

Sadtler, P. T., Quick, K. M., Golub, M. D., et al. (2014). Neural constraints on learning. Nature, 512, 423-426.

Shepherd, G. M. G., & Yamawaki, N. (2021). Untangling the cortico-thalamo-cortical loop: cellular pieces of a knotty circuit puzzle. Nature Reviews Neuroscience, 22, 389-406.

Smith, M. A., Ghazizadeh, A., & Shadmehr, R. (2006). Interacting adaptive processes with different timescales underlie short-term motor learning. PLoS Biology, 4(6), e179.

Thorndike, E. L., & Woodworth, R. S. (1901). The influence of improvement in one mental function upon the efficiency of other functions. Psychological Review, 8(3), 247-261.

Tonegawa, S., Liu, X., Ramirez, S., & Redondo, R. (2015). Memory Engram Cells Have Come of Age. Neuron, 87(5), 918-931.

Vedder, L. C., Miller, A. M. P., Harrison, M. B., & Smith, D. M. (2017). Retrosplenial cortical neurons encode navigational cues, trajectories and reward locations during goal directed navigation. Cerebral Cortex, 27(7), 3713-3723.

Vyas, S., Golub, M. D., Sussillo, D., & Shenoy, K. V. (2020). Computation through neural population dynamics. Annual Review of Neuroscience, 43, 249-275.
