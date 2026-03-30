# Introduction

## Transfer Learning Should Be Decomposed Into Initial Performance and Subsequent Learning

在共享相同行为输出规则但改变感觉线索模态的任务中，迁移学习并不只是“旧经验让动物学得更快”这样一句总括性描述。更关键的问题是，旧经验究竟改变了新任务的哪一部分学习过程。在本研究中，小鼠先学习声水偶联任务，再转入输出规则保持不变的光水偶联任务。与从零开始学习光水偶联任务的 Naive 组相比，Transfer 组既表现出更高的首个 block 命中率，也在控制初始表现后仍保留更快的后续习得。这提示迁移优势至少包含两个成分：新任务开始时的起点优势，以及之后沿学习曲线继续推进的速度优势（Thorndike and Woodworth, 1901; Perkins and Salomon, 1992, 1994; Barnett and Ceci, 2002）。

> In tasks that preserve the same behavioral output rule while changing the sensory cue modality, transfer learning should not be reduced to the generic statement that prior experience makes animals “learn faster.” The more informative question is which part of the new learning process is altered by previous experience. In the present study, mice first learned an auditory cue-water coupling task and were then transferred to a light cue-water coupling task with the same licking output rule. Relative to mice that learned the light cue-water coupling task de novo, transfer mice showed both a higher first-block hit rate and faster subsequent acquisition even after adjustment for initial performance. This pattern suggests that transfer advantage contains at least two components: an initial entry advantage and a later advantage in continued learning along the learning curve (Thorndike and Woodworth, 1901; Perkins and Salomon, 1992, 1994; Barnett and Ceci, 2002).

这种拆分并非纯粹统计技巧，而是机制分析的前提。若不区分起点优势与后续习得，就很难判断较高表现究竟来自旧任务结构的快速调用，还是来自更高的整体学习率、觉醒水平或任务熟悉度。与其把迁移看作单一行为现象，更合理的做法是把它拆成两个可检验的问题：第一，旧任务中形成的任务相关群体是否能在新线索下被快速再激活，从而提高初始表现；第二，先前经验是否还会重塑后续学习轨迹，使群体活动更高效地向目标状态推进（Soderstrom and Bjork, 2015; Smith et al., 2006）。

> This decomposition is not merely a statistical convenience, but a prerequisite for mechanism. Without separating initial advantage from later acquisition, it is difficult to determine whether improved behavior reflects rapid recruitment of prior task structure or instead arises from higher global learning rate, arousal, or task familiarity. Rather than treating transfer as a unitary behavioral phenomenon, it is more informative to divide it into two testable questions. First, can task-related populations formed in the prior task be rapidly reactivated by the new cue to improve initial performance? Second, does prior experience also reshape subsequent learning so that population activity progresses more efficiently toward the target state (Soderstrom and Bjork, 2015; Smith et al., 2006).

## Transfer Is Likely Implemented by Reuse of Population Structure Rather Than Uniform Gain

越来越多的群体记录研究表明，学习并不总是表现为所有神经元活动统一升高。相反，学习更常体现为细胞集合的重组、低维状态空间的保留以及群体轨迹几何的重定向。对于迁移学习而言，这类结果提出了一个更具体的可能性：先前任务并不是简单地让整个网络变得“更强”，而是留下了一个接近新任务解的群体组织骨架。这样，新任务到来时，系统就可以通过重用已有集合、减少无效发散、并沿更直接的方向更新状态，而不必从头构建一套全新的表征（Sadtler et al., 2014; Perich et al., 2018; Vyas et al., 2020）。

> A growing body of population-recording work indicates that learning does not necessarily appear as a uniform increase in activity across all neurons. Instead, it is more often expressed as reorganization of ensembles, preservation of low-dimensional state-space structure, and redirection of population trajectories. For transfer learning, these findings motivate a more specific possibility: prior training may not simply make the entire network “stronger,” but may leave behind a population scaffold already close to the solution required by the new task. Under this view, the new task can be acquired by reusing existing ensembles, suppressing unnecessary divergence, and updating population states along a more direct path rather than constructing a wholly new representation from scratch (Sadtler et al., 2014; Perich et al., 2018; Vyas et al., 2020).

这一框架还自然预言了迁移的两阶段表现。若旧结构被快速调用，则首日表现应与旧任务相关细胞集合的再激活和较低的试次间散度相关。若旧结构还能为后续学习提供有利的初始条件，则后续习得不一定体现为每一步变化幅度更大，而更可能体现为状态空间轨迹更单调、更接近目标方向，以及细胞响应分布更早地形成有组织的正负分化。这种预测与运动皮层群体动力学研究中关于“约束下学习”和“方向性更新优于无差别放大”的观点一致（Gallego et al., 2020; Inagaki et al., 2018; Vyas et al., 2020）。

> This framework also predicts a two-stage manifestation of transfer. If prior structure is rapidly recruited, Day 1 performance should be associated with reactivation of prior-task ensembles and reduced trial-to-trial divergence. If the same inherited structure also provides a favorable starting condition for later learning, subsequent acquisition need not appear as larger updates at each step. Instead, it should appear as more monotonic trajectories through state space, greater alignment with the target direction, and earlier emergence of organized positive and negative response polarization across cells. These predictions are consistent with the view from motor-cortical population dynamics that learning is constrained and that directional updates matter more than indiscriminate amplification (Gallego et al., 2020; Inagaki et al., 2018; Vyas et al., 2020).

## MOp, Posterior Thalamus, and RSPd Are Candidate Nodes for Distinct Components of Transfer

MOp 是检验这一假说的关键窗口，因为无论线索来自听觉还是视觉，最终都必须被转化为相同的舔水动作输出。若迁移确实依赖旧结构调用与后续轨迹优化两个阶段，那么 MOp 不仅应表现出与首日优势相关的集合再激活，也应表现出与后续学习速度相关的群体动力学差异。进一步地，不同层次的 MOp 可能承担不同角色：较浅层更接近旧结构的稳定调用，较深层则更接近与行为输出和后续习得相关的轨迹组织（Komiyama et al., 2010; Inagaki et al., 2018; Currie et al., 2022）。

> MOp provides a critical window for testing this hypothesis because auditory and visual cues must ultimately be transformed into the same licking output. If transfer indeed contains separable components of prior-structure recruitment and later trajectory optimization, MOp should exhibit both ensemble reactivation linked to the Day 1 advantage and population-dynamic signatures linked to the speed of subsequent learning. Moreover, different MOp layers may contribute differently, with more superficial layers supporting stable recruitment of prior structure and deeper layers participating more strongly in trajectory organization related to output and later acquisition (Komiyama et al., 2010; Inagaki et al., 2018; Currie et al., 2022).

与此同时，后部丘脑和 RSPd 可能为这两个阶段提供不同类型的上游支持。高阶丘脑已被认为能够调节皮层间通信、增益和可塑性，因此更可能影响后续学习所需的群体组织维持，而不一定直接决定首日是否能调用旧集合。RSPd 则位于视觉皮层与运动皮层之间，更适合作为视觉偏置的上游输入节点，可能帮助新线索进入既有的感觉-动作框架，但未必构成决定迁移成败的主瓶颈（Halassa and Sherman, 2019; Shepherd and Yamawaki, 2021; Alexander et al., 2023; Vedder et al., 2017）。

> At the same time, posterior thalamus and RSPd may provide distinct forms of upstream support for these two stages. Higher-order thalamus is thought to regulate cortical communication, gain, and plasticity, making it a plausible contributor to the maintenance of population architecture required for later learning rather than the immediate recruitment of prior ensembles. By contrast, RSPd lies between visual cortex and motor cortex and is well positioned to provide visually biased upstream input, helping the new cue access an existing sensorimotor framework without necessarily forming the principal bottleneck for transfer success (Halassa and Sherman, 2019; Shepherd and Yamawaki, 2021; Alexander et al., 2023; Vedder et al., 2017).

## Objective and Working Hypothesis

基于上述考虑，本文围绕三个彼此关联的问题展开。第一，迁移学习的首日优势是否来自预训练阶段形成的细胞集合在新任务中的再激活。第二，后续学习速度是否由一种不同于再激活的群体结构性质所支持，例如较低的试次间散度、更定向的状态空间推进和更高的响应异质性。第三，MOp、后部丘脑和 RSPd 是否分别参与迁移的不同组成环节，而不是共同承担同一种功能。

> On this basis, the present study addresses three related questions. First, does the Day 1 advantage of transfer arise from reactivation of ensembles formed during pre-training? Second, is the speed of later learning supported by a population-structural property distinct from reactivation, such as reduced inter-trial divergence, more directed state-space progression, and greater response heterogeneity? Third, do MOp, posterior thalamus, and RSPd contribute to different components of transfer rather than serving the same function in parallel?

我们的工作假设是，跨模态迁移优势由两个机制上可分离但行为上相互衔接的部分构成。其一，旧任务相关集合在新线索下被调用，并使群体活动更快进入 learned-like 状态，从而提高新任务初始表现。其二，预训练留下的群体组织在后部丘脑调制下保留了更有利的分化结构，使后续学习能够沿更有效的方向推进；而 RSPd 则主要提供视觉偏置的上游输入，而非决定迁移成功与否的核心瓶颈。

> Our working hypothesis is that cross-modal transfer advantage consists of two mechanistically separable but behaviorally linked parts. First, prior-task ensembles are recruited by the new cue, enabling population activity to enter a learned-like state more rapidly and thereby improving initial performance. Second, pre-training leaves behind a favorable population architecture that, under posterior-thalamic modulation, supports more efficient subsequent learning; RSPd, in contrast, contributes mainly visually biased upstream input rather than serving as the core bottleneck that determines transfer success.

## References

Alexander, A. S., Place, R., Starrett, M. J., Chrastil, E. R., & Nitz, D. A. (2023). Rethinking retrosplenial cortex: Perspectives and predictions. Neuron, 111(2), 150-175.

Barnett, S. M., & Ceci, S. J. (2002). When and where do we apply what we learn?: A taxonomy for far transfer. Psychological Bulletin, 128(4), 612-637.

Currie, S. P., Ammer, J. J., Premchand, B., et al. (2022). Movement-specific signaling is differentially distributed across motor cortex layer 5 projection neuron classes. Cell Reports, 39(6), 110801.

Gallego, J. A., Perich, M. G., Chowdhury, R. H., Solla, S. A., & Miller, L. E. (2020). Long-term stability of cortical population dynamics underlying consistent behavior. Nature Neuroscience, 23(2), 260-270.

Halassa, M. M., & Sherman, S. M. (2019). Thalamocortical circuit motifs: a general framework. Neuron, 103(5), 762-770.

Inagaki, H. K., Inagaki, M., Romani, S., & Svoboda, K. (2018). Low-dimensional and monotonic preparatory activity in mouse anterior lateral motor cortex. The Journal of Neuroscience, 38(17), 4163-4185.

Komiyama, T., Sato, T. R., O'Connor, D. H., et al. (2010). Learning-related fine-scale specificity imaged in motor cortex circuits of behaving mice. Nature, 464, 1182-1186.

Perich, M. G., Gallego, J. A., & Miller, L. E. (2018). A neural population mechanism for rapid learning. Neuron, 100(4), 964-976.

Perkins, D. N., & Salomon, G. (1992). Transfer of learning. In International Encyclopedia of Education. Pergamon Press.

Perkins, D. N., & Salomon, G. (1994). Transfer of learning. In International Encyclopedia of Education (Second Edition). Pergamon Press.

Sadtler, P. T., Quick, K. M., Golub, M. D., et al. (2014). Neural constraints on learning. Nature, 512, 423-426.

Shepherd, G. M. G., & Yamawaki, N. (2021). Untangling the cortico-thalamo-cortical loop: cellular pieces of a knotty circuit puzzle. Nature Reviews Neuroscience, 22, 389-406.

Smith, M. A., Ghazizadeh, A., & Shadmehr, R. (2006). Interacting adaptive processes with different timescales underlie short-term motor learning. PLoS Biology, 4(6), e179.

Soderstrom, N. C., & Bjork, R. A. (2015). Learning versus performance: An integrative review. Perspectives on Psychological Science, 10(2), 176-199.

Thorndike, E. L., & Woodworth, R. S. (1901). The influence of improvement in one mental function upon the efficiency of other functions. Psychological Review, 8(3), 247-261.

Vedder, L. C., Miller, A. M. P., Harrison, M. B., & Smith, D. M. (2017). Retrosplenial cortical neurons encode navigational cues, trajectories and reward locations during goal directed navigation. Cerebral Cortex, 27(7), 3713-3723.

Vyas, S., Golub, M. D., Sussillo, D., & Shenoy, K. V. (2020). Computation through neural population dynamics. Annual Review of Neuroscience, 43, 249-275.
