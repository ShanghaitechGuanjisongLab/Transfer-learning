# ExperimentDesign.cpp 逐行注解

说明：
- 本文按 [ExperimentDesign.cpp](d:/Users/杨青宁/Documents/MATLAB/Transfer-learning/20260330/+Gbec/Gbec/ExperimentDesign.cpp) 的源码行号解释非空行。
- 空行主要用于视觉分段，含义通常只是“结束上一段、开始下一段”，因此不逐条重复解释。
- 为了避免污染原始 Arduino/C++ 配置文件，注解单独写在本文件。
- 结合 [Predefined.hpp](d:/Users/杨青宁/Documents/MATLAB/Transfer-learning/20260330/+Gbec/Gbec/Predefined.hpp) 可理解底层模块执行框架，结合 [UID.hpp](d:/Users/杨青宁/Documents/MATLAB/Transfer-learning/20260330/+Gbec/Gbec/UID.hpp) 可理解事件和回合 ID。

## 1-47 文件头与硬件引脚

1. 第1行：使用 pragma once，防止本文件被重复包含。
2. 第2行：引入 Predefined.hpp，后续所有 Delay、Sequential、MonitorPin、Trial 等模板都在这里定义。
3. 第3行：注释说明 BOX 宏用于快速切换实验箱硬件配置。
4. 第4行：当前选择 BOX 2 这套硬件引脚映射。
5. 第6行：说明下面的条件编译块用于给不同设备记录不同引脚编号。
6. 第7行：开始定义 BOX 1 的引脚配置。
7. 第8行：BOX 1 下 BlueLed 接 11 号引脚。
8. 第9行：BOX 1 下 WaterPump 接 2 号引脚。
9. 第10行：BOX 1 下 CapacitorVdd 接 7 号引脚。
10. 第11行：BOX 1 下 CapacitorOut 接 18 号引脚，用于检测舔水或触碰信号。
11. 第12行：BOX 1 下 CD1 接 10 号引脚。
12. 第13行：BOX 1 下 ActiveBuzzer 接 52 号引脚。
13. 第14行：BOX 1 下 AirPump 接 8 号引脚。
14. 第15行：BOX 1 下 PassiveBuzzer 接 12 号引脚。
15. 第16行：BOX 1 下 Laser 接 29 号引脚。
16. 第17行：BOX 1 下 Laser2 接 98 号引脚，这里更像占位编号。
17. 第18行：BOX 1 下 Laser3 接 99 号引脚，同样像占位编号。
18. 第19行：结束 BOX 1 条件块。
19. 第20行：开始定义 BOX 2 的引脚配置。
20. 第21行：BOX 2 下 BlueLed 接 8 号引脚。
21. 第22行：BOX 2 下 WaterPump 接 2 号引脚。
22. 第23行：BOX 2 下 CapacitorVdd 接 7 号引脚。
23. 第24行：BOX 2 下 CapacitorOut 接 18 号引脚。
24. 第25行：BOX 2 下 CD1 接 6 号引脚。
25. 第26行：BOX 2 下 ActiveBuzzer 接 22 号引脚。
26. 第27行：BOX 2 下 AirPump 接 12 号引脚。
27. 第28行：BOX 2 下 Laser 接 51 号引脚。
28. 第29行：BOX 2 下 Laser2 接 34 号引脚。
29. 第30行：BOX 2 下 Laser3 接 40 号引脚。
30. 第31行：BOX 2 下 Laser4 接 46 号引脚，说明这一版支持四路光刺激。
31. 第32行：BOX 2 下 PassiveBuzzer 接 3 号引脚。
32. 第33行：结束 BOX 2 条件块，也是当前实际生效的配置块。
33. 第34行：开始定义 BOX 3 的引脚配置。
34. 第35行：BOX 3 下 BlueLed 接 4 号引脚。
35. 第36行：BOX 3 下 WaterPump 接 2 号引脚。
36. 第37行：BOX 3 下 CapacitorVdd 接 6 号引脚。
37. 第38行：BOX 3 下 CapacitorOut 接 18 号引脚。
38. 第39行：BOX 3 下 CD1 接 6 号引脚。
39. 第40行：BOX 3 下 ActiveBuzzer 接 3 号引脚。
40. 第41行：BOX 3 下 AirPump 接 12 号引脚。
41. 第42行：BOX 3 下 Laser 接 7 号引脚。
42. 第43行：BOX 3 下 Laser2 接 98 号引脚。
43. 第44行：BOX 3 下 Laser3 接 99 号引脚。
44. 第45行：BOX 3 下 PassiveBuzzer 接 32 号引脚。
45. 第46行：结束 BOX 3 条件块。

## 48-143 框架内置模块说明块

46. 第48行：开启一个大块注释，作者在文件内部直接写了 DSL 的使用说明。
47. 第49行：分隔线，仅用于增强可读性。
48. 第50行：开始介绍“整数类模块”。
49. 第51行：分隔线。
50. 第52行：说明整数类模块本身不执行，只给别的模块提供参数值。
51. 第54行：介绍 ConstantInteger 模板。
52. 第55行：说明 ConstantInteger 用来表达编译期常数。
53. 第57行：介绍 RandomInteger 模板。
54. 第58行：说明 RandomInteger 在进程创建时给出一个随机值，之后不会自动再随机，必须手动 ModuleRandomize。
55. 第59行：分隔线。
56. 第60行：开始介绍“延时类模块”。
57. 第61行：分隔线。
58. 第62行：说明延时类模块通常会占用可观时间。
59. 第64行：介绍 Delay 模块。
60. 第65行：说明 Delay 用于等待一段时间。
61. 第66行：解释 Delay 的有参形式，由单位和数值共同决定等待时长。
62. 第67行：解释 Delay 的无参形式代表无限等待。
63. 第68行：列出允许的时间单位与数值类型。
64. 第70行：介绍 RepeatEvery 模板。
65. 第71行：说明它会按固定周期重复执行模块。
66. 第72行：解释 Content 异步执行，不会把周期拖长。
67. 第73行：说明 Unit 表示周期单位。
68. 第74行：说明 Period 的取值与随机化时机。
69. 第75行：说明 Times 控制重复次数，默认可无限重复。
70. 第77行：介绍 DoubleRepeat 模板。
71. 第78行：说明 DoubleRepeat 在 ContentA 与 ContentB 之间交替执行，Times 计的是总执行次数。
72. 第79行：分隔线。
73. 第80行：开始介绍“瞬时类模块”。
74. 第81行：分隔线。
75. 第82行：说明瞬时类模块不需要等待，可立即完成。
76. 第84行：介绍 ModuleAbort。
77. 第85行：说明 ModuleAbort 会立刻终止目标模块。
78. 第87行：介绍 ModuleRestart。
79. 第88行：说明 ModuleRestart 会立刻从头重启目标模块。
80. 第90行：介绍 ModuleRandomize。
81. 第91行：说明 ModuleRandomize 用来刷新随机模块的内部随机值。
82. 第93行：介绍 DigitalWrite。
83. 第94行：说明 DigitalWrite 直接写高低电平。
84. 第96行：介绍 DigitalToggle。
85. 第97行：说明 DigitalToggle 多用于和 RepeatEvery 组合生成音调或闪烁。
86. 第99行：介绍 MonitorPin。
87. 第100行：说明 MonitorPin 基于上升沿中断启动一个监视模块，而且不会打断主流程。
88. 第102行：介绍 SerialMessage。
89. 第103行：说明 SerialMessage 会把预定义消息发给 PC 端记录或触发主机动作。
90. 第105行：介绍 CleanWhenAbort。
91. 第106行：说明它给目标模块附加清理动作，但目标模块正常结束时不会触发清理。
92. 第107行：分隔线。
93. 第108行：开始介绍“容器类模块”。
94. 第109行：分隔线。
95. 第110行：说明容器类模块通过组合其他模块来形成流程。
96. 第112行：介绍 Sequential。
97. 第113行：说明 Sequential 按顺序依次执行各子模块。
98. 第115行：介绍 RandomSequential。
99. 第116行：说明 RandomSequential 的子模块顺序随机，但重复执行时会保持当前随机顺序。
100. 第117行：解释 WithRepeat 扩展能为每个子模块指定重复次数并一起打乱。
101. 第119行：介绍 Repeat。
102. 第120行：说明 Repeat 等前一次结束后再进入下一次，若 Times 是随机数则在开始时固定。
103. 第122行：介绍 Trial。
104. 第123行：说明 Trial 用来标记“一个回合”，会向 PC 发送 TrialID。
105. 第124行：说明断线重连恢复也是以 Trial 为基本单位。
106. 第125行：说明 Trial 内不允许再嵌套 Trial。
107. 第127行：介绍 DynamicSlot。
108. 第128行：说明 DynamicSlot 是一个可在运行时替换内容的动态插槽。
109. 第129行：解释 Load 扩展用来把某个模块装入插槽。
110. 第130行：解释 Clear 扩展用来清空插槽，但不打断已经在运行的旧内容。
111. 第132行：介绍 IDModule。
112. 第133行：说明 IDModule 需要配合 AssignModuleID 使用。
113. 第134行：代码块起始，仅展示绑定语法。
114. 第135行：给出 AssignModuleID 的调用格式示例。
115. 第136行：代码块结束。
116. 第137行：说明 IDModule 允许在其他位置通过 ID 引用已绑定的目标模块，也支持自引用式控制。
117. 第139行：介绍 Async。
118. 第140行：说明 Async 会后台启动内容模块，当前流程立即继续。
119. 第142行：提示下面开始进入真实实验定义，不再只是框架说明。
120. 第143行：结束这整段模块说明注释。

## 145-199 基础别名、反应窗口与基础 session

121. 第145行：定义一个以毫秒为参数的模板别名。
122. 第146行：把 Delay 的单位固定成毫秒，简化后续写法。
123. 第148行：定义 PinFlash 的模板别名。
124. 第149行：PinFlash 的逻辑是拉高引脚、等待若干毫秒、再拉低。
125. 第151行：定义 PinFlashUp 的模板别名。
126. 第152行：PinFlashUp 在拉高后额外发送一个事件消息，常用于记录刺激开始。
127. 第154行：定义 PinFlashUpDown 的模板别名。
128. 第155行：PinFlashUpDown 同时在开始和结束时各发送一个消息。
129. 第157行：定义一个 100 到 1000 毫秒的随机整数。
130. 第159行：RandomFlash 会无限重复“翻转激光引脚、等待随机时长、重随机化等待时间”。
131. 第161行：定义一个 5 到 10 秒的随机整数。
132. 第163行：Delay5To10 把上面的随机整数作为秒级延时使用。
133. 第165行：MonitorRestart 监听 CapacitorOut，一旦触发就重启 Delay5To10，相当于“有舔水就重新计时”。
134. 第167行：定义以秒为单位的模板别名。
135. 第168行：把 Delay 的单位固定成秒。
136. 第170行：定义 Tone 的模板别名。
137. 第171行：Tone 通过重复翻转 PassiveBuzzer 引脚形成指定频率与总时长的方波。
138. 第173行：ResponseWindow 监听 CapacitorOut，命中后会清空动态插槽、终止自身并发送命中事件。
139. 第174行：把 ResponseWindow 绑定到 UID::Module_ResponseWindow，便于在别处通过 ID 中止它。
140. 第176行：CalmDown 的逻辑是先把“未命中处理”装入默认动态插槽，再监听舔水触发、等待 5 到 10 秒安静期，最后取消监听。
141. 第178行：Settlement 会先重新随机化 5 到 10 秒，再固定等待 20 秒，作为回合后的稳定期。
142. 第180行：把 800 毫秒延时起一个短别名。
143. 第182行：定义 AssociationTrial 的模板参数，接受线索引脚和两个事件 ID。
144. 第183行：AssociationTrial 的完整流程是安静期、开启反应窗口、呈现线索、给 800 毫秒缓冲、执行默认插槽内容、出水并进入稳定期。
145. 第185行：定义 CueOnlyTrial，接受一个已经构好的 Cue 模块。
146. 第186行：CueOnlyTrial 与 AssociationTrial 类似，但没有给水，只呈现线索后结束。
147. 第188行：BackgroundMonitor 在整个 session 期间持续监听舔水并累计命中事件。
148. 第190行：CapacitorInitialize 会先给电容供电、等待 1 秒、再启动背景监视器。
149. 第192行：注释说明下面这个 session 定义为什么要先等 1 秒。
150. 第193行：定义 AssociationSession 模板。
151. 第194行：AssociationSession 会初始化电容后重复执行 30 次指定 trial，最后停止背景监视。
152. 第196行：注释说明下面是可自定义次数的 session 版本。
153. 第197行：定义 AssociationSessionTimes 模板。
154. 第198行：AssociationSessionTimes 重用 CapacitorInitialize，但把 trial 次数交给模板参数 Times。

## 200-270 光遗传刺激模板

155. 第200行：注释说明下面进入光遗传刺激相关模块。
156. 第201行：定义 Opto30Hz 的模板参数。
157. 第202行：开始定义 30Hz 光刺激序列。
158. 第203行：先把指定激光引脚拉高，形成起始高电平。
159. 第204行：开始用 DoubleRepeat 展开高低脉冲串。
160. 第205行：DoubleRepeat 的第一个内容是把引脚拉低。
161. 第206行：DoubleRepeat 的第二个内容是把引脚拉高。
162. 第207行：两个相位的时间单位都用毫秒。
163. 第208行：低电平持续 10 毫秒。
164. 第209行：高电平持续 23 毫秒。
165. 第210行：总切换次数由模板参数 Times 决定。
166. 第211行：结束 DoubleRepeat 定义。
167. 第212行：序列最后显式把引脚拉低，确保刺激结束后关闭激光。
168. 第213行：结束 Opto30Hz 定义。
169. 第215行：定义 Opto30HzRandom 的模板参数。
170. 第216行：开始定义带随机脉冲次数的 30Hz 光刺激序列。
171. 第217行：先把激光引脚拉高。
172. 第218行：开始定义交替高低电平。
173. 第219行：低相位写成拉低操作。
174. 第220行：高相位写成拉高操作。
175. 第221行：时间单位同样使用毫秒。
176. 第222行：低电平保持 10 毫秒。
177. 第223行：高电平保持 23 毫秒。
178. 第224行：脉冲总次数在 Times1 到 Times2 之间随机抽取。
179. 第225行：结束 DoubleRepeat。
180. 第226行：刺激结束后再次拉低输出。
181. 第227行：结束 Opto30HzRandom。
182. 第229行：定义 Opto40Hz 的模板参数。
183. 第230行：开始定义 40Hz 光刺激序列。
184. 第231行：先把激光引脚拉高。
185. 第232行：开始定义交替重复模块。
186. 第233行：低相位对应拉低。
187. 第234行：高相位对应拉高。
188. 第235行：时间单位仍为毫秒。
189. 第236行：40Hz 模式下低电平只保持 2 毫秒。
190. 第237行：高电平保持 23 毫秒。
191. 第238行：总次数由模板参数 Times 决定。
192. 第239行：结束 DoubleRepeat。
193. 第240行：最后把引脚拉低以复位状态。
194. 第241行：结束 Opto40Hz 定义。
195. 第243行：定义双引脚 30Hz 模板参数。
196. 第244行：Opto30Hz2Pin 让第一个引脚异步刺激，同时在当前流程里对第二个引脚刺激，实现双路近同步。
197. 第246行：定义三引脚 30Hz 模板参数。
198. 第247行：Opto30Hz3Pin 让前两路异步开始，第三路在当前流程里执行，实现三路近同步。
199. 第249行：定义双引脚 40Hz 模板参数。
200. 第250行：Opto40Hz2Pin 用和双路 30Hz 同样的思路并联两路 40Hz。
201. 第252行：定义 Theta-Gamma 组合刺激的双引脚模板参数。
202. 第253行：OptoThetaGamma1 先做一段双路 40Hz 刺激，再等待 73 毫秒。
203. 第254行：随后再做第二段相同刺激并再等 73 毫秒，拼出 theta 节律上的 gamma burst。
204. 第255行：注释掉一种候选参数方案，使用 50 毫秒 burst 与 98 毫秒间隔。
205. 第256行：这行注释补充说明 75+23 的节律长度。
206. 第257行：注释中再次给出当前启用的 75 毫秒 burst 版本。
207. 第258行：注释中补充 50+23 的说明。
208. 第259行：注释中给出 100 毫秒 burst 的另一种备选方案。
209. 第260行：注释中补充 25+23 的说明并结束整段备选注释。
210. 第262行：定义单引脚 Theta-Gamma 模板参数。
211. 第263行：SingleThetaGamma1 在单路激光上做第一段 40Hz burst 后等待 73 毫秒。
212. 第264行：然后执行第二段相同 burst 再等 73 毫秒。
213. 第265行：注释掉单路 50 毫秒 burst 备选方案。
214. 第266行：注释里补充 75+23 的节律说明。
215. 第267行：注释里再次写出 75 毫秒 burst 版本。
216. 第268行：注释里补充 50+23 的说明。
217. 第269行：注释里写出 100 毫秒 burst 版本。
218. 第270行：注释里补充 25+23 的说明并结束整段注释。

## 272-365 听觉/气吹/给水与单音节任务

219. 第272行：注释说明下面进入声音、延时、气吹和给水模块。
220. 第273行：HighTone500 会发高音开始事件、播放 10000Hz 的 500ms 方波、再发高音结束事件。
221. 第274行：LowTone500 逻辑相同，但频率换成 2400Hz。
222. 第275行：Air100 把气泵拉高 100ms，并发送气吹事件。
223. 第276行：Water100 把水泵拉高 150ms，并发送给水事件。
224. 第278行：注释说明下面进入反应检测模块。
225. 第279行：RightDetector 在舔水命中时会终止自身、清空舔检测动态插槽、发送命中事件并给水。
226. 第280行：将 RightDetector 绑定到 UID::Module_RightDetector。
227. 第281行：FalseDetector 在错误舔水时会终止自身、清空舔检测插槽、发送错误选择事件并施加气吹。
228. 第282行：将 FalseDetector 绑定到 UID::Module_FalseDetector。
229. 第283行：开始定义 WaterAlwaysDetector，它是一个多行写法的监听器。
230. 第284行：指定被监听的仍然是 CapacitorOut。
231. 第285行：进入 WaterAlwaysDetector 触发后要执行的顺序模块。
232. 第286行：命中后先终止 WaterAlwaysDetector 自身，避免重复触发。
233. 第287行：然后发送命中事件。
234. 第288行：接着无条件给水。
235. 第289行：清除专门用于“持续可给水”条件的动态水插槽。
236. 第290行：清除舔水检测插槽，避免残留逻辑干扰。
237. 第291行：结束内部 Sequential。
238. 第292行：结束 WaterAlwaysDetector 模块定义。
239. 第293行：将 WaterAlwaysDetector 绑定到 UID::Module_WaterAlwaysDetector。
240. 第295行：ResponseRight 先把“未命中”消息装入舔检测插槽，再开 RightDetector，等待 1 秒后关掉检测器并执行插槽内容。
241. 第296行：ResponseFalse 类似，但默认插槽写入的是正确拒绝事件，真正舔水时反而被 FalseDetector 改写成错误选择。
242. 第297行：开始定义 ResponseWaterAlways。
243. 第298行：先把 Water100 装入动态水插槽。
244. 第299行：然后开启 WaterAlwaysDetector。
245. 第300行：给一个 1 秒反应窗口。
246. 第301行：时间到后终止 WaterAlwaysDetector。
247. 第302行：执行舔检测动态插槽中的默认内容。
248. 第303行：执行动态水插槽中的内容。
249. 第304行：结束 ResponseWaterAlways 定义。
250. 第306行：CalmDownSimple 是一个简化安静期，只等 1 秒后把“未命中”消息装入舔检测插槽。
251. 第308行：MonitorRestart1 会在每次检测到舔水时重启一个 5 秒延时。
252. 第309行：CalmDown1 通过“触发即重启计时”的方式要求连续 5 秒无舔水才通过。
253. 第311行：WaitingTime2 是无限等待，只有被外部 skip 才会结束。
254. 第312行：MonitorRestartRight 监听到舔水时发送命中事件、给水并跳过 WaitingTime2。
255. 第313行：将 MonitorRestartRight 绑定到对应 UID。
256. 第314行：MonitorRestartFalse 监听到舔水时发送错误选择事件、短暂等待 100ms 后跳过 WaitingTime2。
257. 第315行：将 MonitorRestartFalse 绑定到对应 UID。
258. 第316行：LickBeginRight 表示“等待直到出现一次应答性舔水”。
259. 第317行：LickBeginFalse 表示“等待直到出现一次错误性舔水”。
260. 第319行：Shaping 的 shaping 试次很简单，等 5 秒后进入正确反应窗口。
261. 第320行：把 shaping 流程包成一个 Trial。
262. 第322行：注释说明下面是无光刺激的原始任务。
263. 第323行：HighWater 是单高音提示后正确舔水给水的试次。
264. 第324行：HighWaterAlways 与 HighWater 相近，但使用 WaterAlways 型反应窗口。
265. 第325行：LowAir 是低音条件下等待错误拒绝，若错误舔水则气吹。
266. 第327行：把 HighWater 封装成一个 Trial。
267. 第328行：把 HighWaterAlways 封装成一个 Trial。
268. 第330行：注释说明下面是预训练 session。
269. 第331行：定义 PreSession 模板参数。
270. 第332行：开始定义 PreSession。
271. 第333行：session 开始时先初始化电容与背景监听。
272. 第334行：然后持续重复 trial，直到达到模板参数 Times1 次数为止。
273. 第335行：结束 PreSession。
274. 第337行：注释说明下面是固定两段 session 的模板。
275. 第338行：定义 A3FixedSession 模板参数。
276. 第339行：开始定义 A3FixedSession。
277. 第340行：先做 CapacitorInitialize。
278. 第341行：第一阶段固定重复 TrialType1 指定次数。
279. 第342行：第二阶段固定重复 TrialType2 指定次数。
280. 第343行：结束 A3FixedSession。
281. 第345行：注释说明下面是单引脚光刺激的试次。
282. 第346行：OptoHighWater 在高音任务前异步启动单路 30Hz 激光刺激，再进入 ResponseRight。
283. 第347行：OptoLowAir 在低音任务前异步启动较短的单路 30Hz 激光刺激，再进入 ResponseFalse。
284. 第348行：开始定义单音节光刺激任务的随机试次集合。
285. 第349行：集合第一项是 OptoHighWater trial。
286. 第350行：集合第二项是 OptoLowAir trial。
287. 第351行：规定两类试次各重复 2 次并随机穿插。
288. 第353行：OptoSingleAudioTrial 在执行完随机集合后立即重随机化，为下一轮 session 准备新的顺序。
289. 第355行：注释说明下面是多引脚激活版本的单音节任务。
290. 第356行：MultiOptoHighWater 在高音前后分别异步并行两组双路激光刺激，然后进入正确反应窗口。
291. 第357行：MultiOptoLowAir 是与之对应的低音错误拒绝版本。
292. 第358行：开始定义多引脚单音节随机试次集合。
293. 第359行：第一项是 MultiOptoHighWater。
294. 第360行：第二项是 MultiOptoLowAir。
295. 第361行：两类试次各重复 2 次并打乱。
296. 第363行：MultiOptoSingleAudioTrial 执行完后重随机化顺序。
297. 第365行：这里再次定义 OptoSingleAudioTrial，效果与第353行相同，等于重复写了一次同名别名。

## 367-477 双音节任务与多光刺激双音节任务

298. 第367行：注释说明下面进入双音节任务。
299. 第368行：HLWater 表示高音后接低音，随后进入正确反应窗口。
300. 第369行：HLWaterAlways 用同样线索，但采用总会给水的反应窗口。
301. 第370行：HHAir 表示双高音条件，对应错误拒绝任务。
302. 第371行：LHAir 表示低音再高音条件，对应错误拒绝任务。
303. 第372行：LLAir 表示双低音条件，对应错误拒绝任务。
304. 第374行：把 HLWaterAlways 包成 Trial。
305. 第375行：把 HLWater 包成 Trial。
306. 第377行：开始定义双音节随机试次集合。
307. 第378行：主目标试次是 HLWater。
308. 第379行：第一类干扰试次是 HHAir。
309. 第380行：第二类干扰试次是 LHAir。
310. 第381行：第三类干扰试次是 LLAir。
311. 第382行：规定 HLWater 出现 3 次，其他每类出现 1 次。
312. 第384行：DoubleAudioTrial 在每轮结束后重随机化顺序。
313. 第386行：注释说明下面是双音节任务的多光刺激版本。
314. 第387行：HighToneOpto1 表示高音同时伴随激光方案 1。
315. 第388行：LowToneOpto1 表示低音同时伴随激光方案 1。
316. 第389行：OptoRightWindow1 在反应窗口前异步启动一段双路激光，然后进入正确反应窗口。
317. 第390行：OptoFalseWindow1 是对应的错误拒绝版本。
318. 第391行：OptoAlwaysWindow1 是对应的总会给水版本。
319. 第393行：HighToneOpto2 表示高音同时伴随 theta-gamma 型激光方案 2。
320. 第394行：LowToneOpto2 表示低音同时伴随 theta-gamma 型激光方案 2。
321. 第395行：OptoRightWindow2 在反应窗口前异步重复 6 次 theta-gamma 刺激，然后进入正确反应窗口。
322. 第396行：OptoFalseWindow2 是方案 2 的错误拒绝版本。
323. 第397行：OptoAlwaysWindow2 是方案 2 的总会给水版本。
324. 第399行：HighToneOpto31 把高音和 Laser2/Laser4 及 Laser/Laser4 的双路刺激绑定起来。
325. 第400行：HighToneOpto32 把高音和三路刺激版本绑定起来。
326. 第401行：LowToneOpto31 是低音对应的双路刺激版本。
327. 第402行：LowToneOpto32 是低音对应的三路刺激版本。
328. 第404行：TestGamma1 只是把两段 Theta-Gamma 组合顺序执行，用于单独测试。
329. 第405行：将 TestGamma1 包成 Trial。
330. 第407行：MultiOptoHLWater 是方案 1 下的目标双音节试次。
331. 第408行：MultiOptoHLWaterAlways 是方案 1 下总会给水的目标试次。
332. 第409行：MultiOptoHHAir 是方案 1 下的高高干扰试次。
333. 第410行：MultiOptoLHAir 是方案 1 下的低高干扰试次。
334. 第411行：MultiOptoLLAir 是方案 1 下的低低干扰试次。
335. 第413行：MultiOptoHLWater2 是方案 2 下的目标双音节试次。
336. 第414行：MultiOptoHLWaterAlways2 是方案 2 下总会给水的目标试次。
337. 第415行：MultiOptoHHAir2 是方案 2 下的高高干扰试次。
338. 第416行：MultiOptoLHAir2 是方案 2 下的低高干扰试次。
339. 第417行：MultiOptoLLAir2 是方案 2 下的低低干扰试次。
340. 第419行：MultiOptoHLWater3 是方案 3 下更换引脚组合后的目标试次。
341. 第420行：MultiOptoHLWaterAlways3 是方案 3 下总会给水的目标试次。
342. 第421行：MultiOptoHHAir3 是方案 3 下的高高干扰试次。
343. 第422行：MultiOptoLHAir3 是方案 3 下的低高干扰试次。
344. 第423行：MultiOptoLLAir3 是方案 3 下的低低干扰试次。
345. 第425行：MultiOptoHLWater4 不再用固定 500ms 等待，而是等待一次正确性舔水开始后再呈现双音节激光高低组合。
346. 第426行：MultiOptoHHAir4 是等待一次错误型舔水开始后进入高高版本。
347. 第427行：MultiOptoLHAir4 是等待一次错误型舔水开始后进入低高版本。
348. 第428行：MultiOptoLLAir4 是等待一次错误型舔水开始后进入低低版本。
349. 第430行：MultiOptoDoubleAudioTrialPre 用总会给水的目标试次作为预训练 trial。
350. 第431行：MultiOptoDoubleAudioTrialPre2 用方案 2 的总会给水目标试次做预训练。
351. 第432行：MultiOptoDoubleAudioTrialPre3 用方案 3 的总会给水目标试次做预训练。
352. 第434行：开始定义方案 1 的多光双音节随机试次集合。
353. 第435行：第一项是目标试次 MultiOptoHLWater。
354. 第436行：第二项是 HHAir 干扰。
355. 第437行：第三项是 LHAir 干扰。
356. 第438行：第四项是 LLAir 干扰。
357. 第439行：目标试次重复 3 次，其余各 1 次。
358. 第440行：MultiOptoDoubleAudioTrial 在执行后重随机化集合顺序。
359. 第442行：开始定义方案 2 的多光双音节随机试次集合。
360. 第443行：第一项换成 MultiOptoHLWater2。
361. 第444行：第二项换成 MultiOptoHHAir2。
362. 第445行：第三项换成 MultiOptoLHAir2。
363. 第446行：第四项换成 MultiOptoLLAir2。
364. 第447行：重复次数仍保持 3,1,1,1。
365. 第448行：MultiOptoDoubleAudioTrial2 在执行后重随机化。
366. 第450行：开始定义方案 3 的多光双音节随机试次集合。
367. 第451行：第一项换成 MultiOptoHLWater3。
368. 第452行：第二项换成 MultiOptoHHAir3。
369. 第453行：第三项换成 MultiOptoLHAir3。
370. 第454行：第四项换成 MultiOptoLLAir3。
371. 第455行：重复次数依旧是 3,1,1,1。
372. 第456行：MultiOptoDoubleAudioTrial3 在执行后重随机化。
373. 第458行：开始定义一个手工拼接的分阶段双音节 session 序列。
374. 第459行：先连做 7 次总会给水的目标试次。
375. 第460行：再做 3 次 HHAir。
376. 第461行：再回到 7 次目标试次。
377. 第462行：再做 3 次 LHAir。
378. 第463行：再来 7 次目标试次。
379. 第464行：最后做 3 次 LLAir 并结束该手工序列。
380. 第466行：开始定义只包含目标试次 4 版本的随机集合。
381. 第467行：集合中唯一的 trial 是 MultiOptoHLWater4。
382. 第468行：把它重复 6 次。
383. 第469行：MultiOptoDoubleAudioTrial41 只是顺序执行这组 6 次目标试次。
384. 第471行：开始定义 MultiOptoDoubleAudioTrial42。
385. 第472行：先做 2 次 HHAir4。
386. 第473行：再做 2 次 LHAir4。
387. 第474行：最后做 2 次 LLAir4。
388. 第475行：这行注释掉了原本可能想加入的随机化调用。
389. 第477行：LaserOnlyTrial 先执行 12 次预训练 trial，再执行 1 次正式双音节随机任务。

## 479-537 三音节任务与多光刺激三音节任务

390. 第479行：注释说明下面进入三音节任务。
391. 第480行：HLHWater 定义了高-低-高三音节目标试次，随后进入正确反应窗口。
392. 第482行：把 HLHWater 封装成预训练用的 Trial。
393. 第484行：注释说明下面进入三音节多光刺激版本。
394. 第485行：MultiOptoHLHWater 是方案 1 下的高低高目标试次。
395. 第486行：MultiOptoHLLAir 是高低低干扰试次。
396. 第487行：MultiOptoHHLAir 是高高低干扰试次。
397. 第488行：MultiOptoHHHAir 是高高高干扰试次。
398. 第489行：MultiOptoLLHAir 是低低高干扰试次。
399. 第490行：MultiOptoLLLAir 是低低低干扰试次。
400. 第491行：MultiOptoLHLAir 是低高低干扰试次。
401. 第492行：MultiOptoLHHAir 是低高高干扰试次。
402. 第494行：MultiOptoHLHWater2 是方案 2 下的高低高目标试次。
403. 第495行：MultiOptoHLLAir2 是方案 2 下的高低低干扰试次。
404. 第496行：MultiOptoHHLAir2 是方案 2 下的高高低干扰试次。
405. 第497行：MultiOptoHHHAir2 是方案 2 下的高高高干扰试次。
406. 第498行：MultiOptoLLHAir2 是方案 2 下的低低高干扰试次。
407. 第499行：MultiOptoLLLAir2 是方案 2 下的低低低干扰试次。
408. 第500行：MultiOptoLHLAir2 是方案 2 下的低高低干扰试次。
409. 第501行：MultiOptoLHHAir2 是方案 2 下的低高高干扰试次。
410. 第503行：MultiOptoLHLWater2 是方案 2 下的低高低目标试次，说明目标模式在这一版本里被换成了 LHL。
411. 第504行：MultiOptoHLHAir2 是方案 2 下的高低高干扰试次，与上行形成目标/干扰对调。
412. 第506行：MultiOptoLHLWater 是方案 1 下的低高低目标试次。
413. 第507行：MultiOptoHLHAir 是方案 1 下的高低高干扰试次。
414. 第509行：把 MultiOptoLHLWater 封装成三音节预训练 Trial。
415. 第511行：开始定义方案 1 的三音节随机试次集合。
416. 第512行：第一项是目标试次 MultiOptoLHLWater。
417. 第513行：第二项是 HHH 干扰。
418. 第514行：第三项是 LHH 干扰。
419. 第515行：第四项是 LLH 干扰。
420. 第516行：第五项是 HLL 干扰。
421. 第517行：第六项是 HHL 干扰。
422. 第518行：第七项是 HLH 干扰。
423. 第519行：第八项是 LLL 干扰。
424. 第520行：规定目标试次 7 次，其余每类 1 次。
425. 第522行：MultiOptoTripleAudioTrial 执行完后重随机化顺序。
426. 第524行：把方案 2 下的目标试次 MultiOptoLHLWater2 封装成预训练 Trial。
427. 第526行：开始定义方案 2 的三音节随机试次集合。
428. 第527行：第一项是目标试次 MultiOptoLHLWater2。
429. 第528行：第二项是 HHH 干扰方案 2。
430. 第529行：第三项是 LHH 干扰方案 2。
431. 第530行：第四项是 LLH 干扰方案 2。
432. 第531行：第五项是 HLL 干扰方案 2。
433. 第532行：第六项是 HHL 干扰方案 2。
434. 第533行：第七项是 HLH 干扰方案 2。
435. 第534行：第八项是 LLL 干扰方案 2。
436. 第535行：重复次数仍是 7,1,1,1,1,1,1,1。
437. 第537行：MultiOptoTripleAudioTrial2 执行完后重随机化顺序。

## 539-596 四音节任务与多光刺激四音节任务

438. 第539行：注释说明下面进入四音节任务。
439. 第540行：HLHLWater 定义高低高低四音节目标试次。
440. 第541行：把 HLHLWater 包装成预训练 Trial。
441. 第543行：注释说明下面进入四音节多光刺激版本。
442. 第544行：MultiOptoHLHLWater 是方案 2 下的四音节目标试次。
443. 第545行：MultiOptoHLLLAir 是高低低低干扰。
444. 第546行：MultiOptoHHLLAir 是高高低低干扰。
445. 第547行：MultiOptoHHHLAir 是高高高低干扰。
446. 第548行：MultiOptoLLHLAir 是低低高低干扰。
447. 第549行：MultiOptoLLLLAir 是低低低低干扰。
448. 第550行：MultiOptoLHLLAir 是低高低低干扰。
449. 第551行：MultiOptoLHHLAir 是低高高低干扰。
450. 第552行：MultiOptoHLHHAir 是高低高高干扰。
451. 第553行：MultiOptoHLLHAir 是高低低高干扰。
452. 第554行：MultiOptoHHLHAir 是高高低高干扰。
453. 第555行：MultiOptoHHHHAir 是高高高高干扰。
454. 第556行：MultiOptoLLHHAir 是低低高高干扰。
455. 第557行：MultiOptoLLLHAir 是低低低高干扰。
456. 第558行：MultiOptoLHLHAir 是低高低高干扰。
457. 第559行：MultiOptoLHHHAir 是低高高高干扰。
458. 第561行：MultiOptoHLHLWaterAlways 是四音节目标试次的总会给水预训练版本。
459. 第562行：把它封装成预训练 Trial。
460. 第564行：开始定义四音节随机试次集合 P1。
461. 第565行：P1 第一项是目标试次 HLHLWater。
462. 第566行：P1 第二项是 HHLLAir。
463. 第567行：P1 第三项是 LHLLAir。
464. 第568行：P1 第四项是 LLLLAir。
465. 第569行：P1 第五项是 HLHHAir。
466. 第570行：P1 第六项是 HHHHAir。
467. 第571行：P1 中目标重复 5 次，其余各 1 次。
468. 第573行：开始定义四音节随机试次集合 P2。
469. 第574行：P2 第一项仍是目标试次 HLHLWater。
470. 第575行：P2 第二项是 LLHLAir。
471. 第576行：P2 第三项是 HLLLAir。
472. 第577行：P2 第四项是 LHHHAir。
473. 第578行：P2 第五项是 LLHHAir。
474. 第579行：P2 第六项是 HLLHAir。
475. 第580行：P2 中目标重复 5 次，其余各 1 次。
476. 第582行：开始定义四音节随机试次集合 P3。
477. 第583行：P3 第一项仍是目标试次 HLHLWater。
478. 第584行：P3 第二项是 HHHLAir。
479. 第585行：P3 第三项是 LHHLAir。
480. 第586行：P3 第四项是 HHLHAir。
481. 第587行：P3 第五项是 LHLHAir。
482. 第588行：P3 第六项是 LLLHAir。
483. 第589行：P3 中目标重复 5 次，其余各 1 次。
484. 第591行：开始把 P1、P2、P3 三个子集合再随机穿插一次。
485. 第592行：第二个子集合是 P2。
486. 第593行：第三个子集合是 P3。
487. 第594行：三个子集合各执行 1 次。
488. 第596行：MultiOptoQuadrupleAudioTrial 在整个大集合执行后重随机化顺序。

## 598-653 SessionMap 公开入口

489. 第598行：注释说明下面这张表是所有暴露给 PC 端的公开 session 入口。
490. 第599行：定义 SessionMap，把 UID 映射到具体 Session 工厂函数。
491. 第600行：Test_BlueLed 会闪一下蓝灯 200ms。
492. 第601行：Test_WaterPump 会打开水泵 150ms。
493. 第602行：Test_CapacitorReset 会先断电电容 100ms 再重新上电。
494. 第603行：Test_CapacitorMonitor 会持续监听 CapacitorOut 并把命中事件发到 PC。
495. 第604行：Test_CD1 会闪一下 CD1 引脚。
496. 第605行：Test_ActiveBuzzer 会短暂触发主动蜂鸣器。
497. 第606行：Test_AirPump 会短暂触发气泵。
498. 第607行：Test_Optogenetic 会闪一下主激光引脚。
499. 第608行：Test_HostAction 会向上位机发送 Host_GratingImage 指令。
500. 第609行：Test_SquareWave 会输出一个低频方波序列，注释额外提醒 6 指的是变灯次数而非周期数。
501. 第610行：Test_RandomFlash 会异步开始随机闪烁，持续 10 秒后中止。
502. 第611行：Test_LowTone 会播放一个 6000Hz、500ms 的音调。
503. 第612行：Test_HighTone 会播放一个 14000Hz、500ms 的音调。
504. 第613行：这一行起始了一个被整体注释掉的历史 session 集合。
505. 第614行：历史注释中保留了音水关联 session 的写法。
506. 第615行：历史注释中保留了光水关联 session 的写法。
507. 第616行：历史注释中开始保留一个 LAuW session 的旧定义。
508. 第617行：旧定义里列出 LightOnly trial。
509. 第618行：旧定义里列出 AudioOnly trial。
510. 第619行：旧定义里列出 WaterOnly trial，并结束这段旧 session。
511. 第620行：旧定义里保留了单音 shaping session。
512. 第621行：旧定义里保留了单音光刺激 task。
513. 第622行：旧定义里保留了多引脚单音光刺激 task。
514. 第623行：旧定义里保留了双音 shaping task，并结束这一大段注释。
515. 第624行：Session_DoubleAudioRecon 的第一段是 1 次手工序列 MultiOptoDoubleAudioTrial4。
516. 第625行：随后追加 6 次 MultiOptoDoubleAudioTrialPre 预训练。
517. 第626行：Session_MultiOptoDoubleAudioTask 开头先发送 Event_Pulse5，用作上位机侧标记或同步。
518. 第627行：然后做 5 次 MultiOptoDoubleAudioTrialPre 预训练。
519. 第628行：最后做 20 次正式的 MultiOptoDoubleAudioTrial。
520. 第629行：这一行开始了另一套被注释掉的双音任务变体。
521. 第630行：注释变体里还会发送 LickBegin 与 Pulse5 标记。
522. 第631行：注释变体里先做 2 次正式双音任务。
523. 第632行：然后插入 1 次 MultiOptoDoubleAudioTrial4。
524. 第633行：接着再做 5 次正式双音任务。
525. 第634行：然后插入 1 次 MultiOptoDoubleAudioTrial41。
526. 第635行：接着再做 4 次正式双音任务。
527. 第636行：最后再做 5 次正式双音任务并结束这段注释。
528. 第637行：这一行开始另一大段被注释掉的历史多光双音/三音/四音 session。
529. 第638行：注释中先给出 Pre2 与正式 Trial2 交替的双音版本。
530. 第639行：然后再次插入 Pre2。
531. 第640行：最后再跑一轮 Trial2，并结束这个 session 片段。
532. 第641行：注释里保留了 LaserOnly session 的旧入口。
533. 第642行：注释里保留了纯双音任务入口。
534. 第643行：注释里保留了三音任务入口 1。
535. 第644行：该入口先做三音预训练再做正式三音任务。
536. 第645行：注释里保留了三音任务入口 2。
537. 第646行：该入口先短预训练再做正式三音任务 2。
538. 第647行：注释里保留了只跑正式三音任务 2 的入口，并结束这段注释。
539. 第648行：注释里保留了四音 shaping 入口。
540. 第649行：注释里保留了四音多光任务入口。
541. 第650行：该入口先做四音预训练再做正式四音任务，并结束这段注释。
542. 第651行：注释里保留了另一个四音任务入口。
543. 第652行：该入口是更短的四音预训练加正式任务组合，并结束这段注释。
544. 第653行：结束 SessionMap 初始化。

## 补充理解

- 这个文件本质上不是传统意义上的“算法实现 cpp”，而是一个基于模板 DSL 的实验流程编排文件。
- 真正的底层执行机制在 [Predefined.hpp](d:/Users/杨青宁/Documents/MATLAB/Transfer-learning/20260330/+Gbec/Gbec/Predefined.hpp)；这里主要做三件事：硬件引脚映射、流程模块组合、向 PC 暴露 session 入口。
- 整体组织规律很稳定：先定义原子模块，再定义 response window，然后拼成单 trial，最后用 RandomSequential 或 Repeat 拼成 session 并挂到 SessionMap。
- 如果你后面想要，我可以继续把这份注解升级成“结构图 + 流程图版”，专门画出单音、双音、三音、四音任务各自的控制流。