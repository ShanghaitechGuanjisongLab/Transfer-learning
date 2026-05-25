# ExperimentDesign.cpp 对照注解

说明：
- 本文采用“三列表格”：行号、源码、注解。
- 为空行补写“空行，分隔上下一段定义”，这样可以直接逐行对照 [ExperimentDesign.cpp](20260330/+Gbec/Gbec/ExperimentDesign.cpp)。
- 注解内容来源于 [ExperimentDesign_逐行注解.md](20260330/+Gbec/Gbec/ExperimentDesign_逐行注解.md)，这里只重新排版，不改原解释口径。

| 行号 | 源码 | 注解 |
| --- | --- | --- |
| 1 | <pre>#pragma once</pre> | 使用 pragma once，防止本文件被重复包含。 |
| 2 | <pre>#include "Predefined.hpp"</pre> | 引入 Predefined.hpp，后续所有 Delay、Sequential、MonitorPin、Trial 等模板都在这里定义。 |
| 3 | <pre>// 快速切换BOX设定集</pre> | 注释说明 BOX 宏用于快速切换实验箱硬件配置。 |
| 4 | <pre>#define BOX 2</pre> | 当前选择 BOX 2 这套硬件引脚映射。 |
| 5 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 6 | <pre>// 引脚设定集，你可以为每套设备创建一个#if BOX块，记录不同设备的不同引脚信息，然后通过设定BOX宏进行快速切换。</pre> | 说明下面的条件编译块用于给不同设备记录不同引脚编号。 |
| 7 | <pre>#if BOX == 1</pre> | 开始定义 BOX 1 的引脚配置。 |
| 8 | <pre>Pin BlueLed = 11;</pre> | BOX 1 下 BlueLed 接 11 号引脚。 |
| 9 | <pre>Pin WaterPump = 2;</pre> | BOX 1 下 WaterPump 接 2 号引脚。 |
| 10 | <pre>Pin CapacitorVdd = 7;</pre> | BOX 1 下 CapacitorVdd 接 7 号引脚。 |
| 11 | <pre>Pin CapacitorOut = 18;</pre> | BOX 1 下 CapacitorOut 接 18 号引脚，用于检测舔水或触碰信号。 |
| 12 | <pre>Pin CD1 = 10;</pre> | BOX 1 下 CD1 接 10 号引脚。 |
| 13 | <pre>Pin ActiveBuzzer = 52;</pre> | BOX 1 下 ActiveBuzzer 接 52 号引脚。 |
| 14 | <pre>Pin AirPump = 8;</pre> | BOX 1 下 AirPump 接 8 号引脚。 |
| 15 | <pre>Pin PassiveBuzzer = 12;</pre> | BOX 1 下 PassiveBuzzer 接 12 号引脚。 |
| 16 | <pre>Pin Laser = 29;</pre> | BOX 1 下 Laser 接 29 号引脚。 |
| 17 | <pre>Pin Laser2 = 98;</pre> | BOX 1 下 Laser2 接 98 号引脚，这里更像占位编号。 |
| 18 | <pre>Pin Laser3 = 99;</pre> | BOX 1 下 Laser3 接 99 号引脚，同样像占位编号。 |
| 19 | <pre>#endif</pre> | 结束 BOX 1 条件块。 |
| 20 | <pre>#if BOX == 2</pre> | 开始定义 BOX 2 的引脚配置。 |
| 21 | <pre>Pin BlueLed = 8;</pre> | BOX 2 下 BlueLed 接 8 号引脚。 |
| 22 | <pre>Pin WaterPump = 2;</pre> | BOX 2 下 WaterPump 接 2 号引脚。 |
| 23 | <pre>Pin CapacitorVdd = 7;</pre> | BOX 2 下 CapacitorVdd 接 7 号引脚。 |
| 24 | <pre>Pin CapacitorOut = 18;</pre> | BOX 2 下 CapacitorOut 接 18 号引脚。 |
| 25 | <pre>Pin CD1 = 6;</pre> | BOX 2 下 CD1 接 6 号引脚。 |
| 26 | <pre>Pin ActiveBuzzer = 22;</pre> | BOX 2 下 ActiveBuzzer 接 22 号引脚。 |
| 27 | <pre>Pin AirPump = 12;</pre> | BOX 2 下 AirPump 接 12 号引脚。 |
| 28 | <pre>Pin Laser = 51;</pre> | BOX 2 下 Laser 接 51 号引脚。 |
| 29 | <pre>Pin Laser2 = 34;</pre> | BOX 2 下 Laser2 接 34 号引脚。 |
| 30 | <pre>Pin Laser3 = 40;</pre> | BOX 2 下 Laser3 接 40 号引脚。 |
| 31 | <pre>Pin Laser4 = 46;</pre> | BOX 2 下 Laser4 接 46 号引脚，说明这一版支持四路光刺激。 |
| 32 | <pre>Pin PassiveBuzzer = 3;</pre> | BOX 2 下 PassiveBuzzer 接 3 号引脚。 |
| 33 | <pre>#endif</pre> | 结束 BOX 2 条件块，也是当前实际生效的配置块。 |
| 34 | <pre>#if BOX == 3</pre> | 开始定义 BOX 3 的引脚配置。 |
| 35 | <pre>Pin BlueLed = 4;</pre> | BOX 3 下 BlueLed 接 4 号引脚。 |
| 36 | <pre>Pin WaterPump = 2;</pre> | BOX 3 下 WaterPump 接 2 号引脚。 |
| 37 | <pre>Pin CapacitorVdd = 6;</pre> | BOX 3 下 CapacitorVdd 接 6 号引脚。 |
| 38 | <pre>Pin CapacitorOut = 18;</pre> | BOX 3 下 CapacitorOut 接 18 号引脚。 |
| 39 | <pre>Pin CD1 = 6;</pre> | BOX 3 下 CD1 接 6 号引脚。 |
| 40 | <pre>Pin ActiveBuzzer = 3;</pre> | BOX 3 下 ActiveBuzzer 接 3 号引脚。 |
| 41 | <pre>Pin AirPump = 12;</pre> | BOX 3 下 AirPump 接 12 号引脚。 |
| 42 | <pre>Pin Laser = 7;</pre> | BOX 3 下 Laser 接 7 号引脚。 |
| 43 | <pre>Pin Laser2 = 98;</pre> | BOX 3 下 Laser2 接 98 号引脚。 |
| 44 | <pre>Pin Laser3 = 99;</pre> | BOX 3 下 Laser3 接 99 号引脚。 |
| 45 | <pre>Pin PassiveBuzzer = 32;</pre> | BOX 3 下 PassiveBuzzer 接 32 号引脚。 |
| 46 | <pre>#endif</pre> | 结束 BOX 3 条件块。 |
| 47 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 48 | <pre>/* 可以将基础模块using组合成自定义的复杂模块，可以是有参数的模板或无参数的实例。语法中的参数前缀提示参数类型，使用时不用写。例如DurationRep前缀表示模板参数是uint32_t类型，typename前缀表示参数是其它模块或类型等。基础模块介绍如下：</pre> | 开启一个大块注释，作者在文件内部直接写了 DSL 的使用说明。 |
| 49 | <pre>————————————</pre> | 分隔线，仅用于增强可读性。 |
| 50 | <pre># 整数类模块</pre> | 开始介绍“整数类模块”。 |
| 51 | <pre>————————————</pre> | 分隔线。 |
| 52 | <pre>整数类模块自身不能执行，只能为其它模块的整数参数提供值，可以是常数或随机数。</pre> | 说明整数类模块本身不执行，只给别的模块提供参数值。 |
| 53 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 54 | <pre>## ConstantInteger&lt;DurationRep Value&gt;</pre> | 介绍 ConstantInteger 模板。 |
| 55 | <pre>表示一个常数整数。例如ConstantInteger&lt;1000&gt;表示常数1000</pre> | 说明 ConstantInteger 用来表达编译期常数。 |
| 56 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 57 | <pre>## RandomInteger&lt;DurationRep Min, DurationRep Max, UID CustomID = UID::Module_RandomInteger&gt;</pre> | 介绍 RandomInteger 模板。 |
| 58 | <pre>表示一个最小Min（含）最大Max（含）的随机整数，还可以额外指定一个ID用于区分不同的实例。此模块在进程创建时提供一个随机初始值，那之后便不会再自动重新随机化，必须对其使用ModuleRandomize以更新随机数，否则每次使用时都会取到相同的值。</pre> | 说明 RandomInteger 在进程创建时给出一个随机值，之后不会自动再随机，必须手动 ModuleRandomize。 |
| 59 | <pre>————————————</pre> | 分隔线。 |
| 60 | <pre># 延时类模块</pre> | 开始介绍“延时类模块”。 |
| 61 | <pre>————————————</pre> | 分隔线。 |
| 62 | <pre>延时类模块的执行通常需要消耗一段可观的时间才能结束。</pre> | 说明延时类模块通常会占用可观时间。 |
| 63 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 64 | <pre>## Delay</pre> | 介绍 Delay 模块。 |
| 65 | <pre>等待一定延迟时间。支持多种语法：</pre> | 说明 Delay 用于等待一段时间。 |
| 66 | <pre>- Delay&lt;typename Unit, typename Value&gt;，需要输入等待时间的单位和值，例如Delay&lt;std::chrono::seconds,RandomInteger&lt;5,10&gt;&gt;表示随机等待5~10秒</pre> | 解释 Delay 的有参形式，由单位和数值共同决定等待时长。 |
| 67 | <pre>- Delay&lt;&gt;，无限等待。出于可读性考虑，还可以写成Delay&lt;Infinite&gt;。</pre> | 解释 Delay 的无参形式代表无限等待。 |
| 68 | <pre>允许的Unit包括 std::chrono::microseconds std::chrono::milliseconds std::chrono::seconds std::chrono::minutes std::chrono::hours，允许的Value只能是ConstantInteger或RandomInteger。</pre> | 列出允许的时间单位与数值类型。 |
| 69 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 70 | <pre>## RepeatEvery&lt;typename Content, typename Unit, typename Period, typename Times = Infinite&gt;</pre> | 介绍 RepeatEvery 模板。 |
| 71 | <pre>每隔一段时间就重复执行模块，第一次重复也需要先等待时间。此模块可用于生成音调。参数说明：</pre> | 说明它会按固定周期重复执行模块。 |
| 72 | <pre>Content，要执行的内容模块。Content本身异步执行，不会占用重复周期。如果Content执行时间比重复周期还长，就会每到重复周期就自动重启，不会拖慢重复周期。</pre> | 解释 Content 异步执行，不会把周期拖长。 |
| 73 | <pre>Unit，重复周期的时间单位</pre> | 说明 Unit 表示周期单位。 |
| 74 | <pre>Period，重复周期的时间值，可以是ConstantInteger或RandomInteger。如果指定RandomInteger，只会在此模块每次开始时取一次值；重复Content的过程中，再重新随机化RandomInteger，也不会再改变重复周期，因此不能用此模块实现每次重复随机间隔，只能用Delay和Repeat组合实现。</pre> | 说明 Period 的取值与随机化时机。 |
| 75 | <pre>Times，重复次数，可以是ConstantInteger或RandomInteger，或者不提供此参数则默认无限重复。</pre> | 说明 Times 控制重复次数，默认可无限重复。 |
| 76 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 77 | <pre>## DoubleRepeat&lt;typename ContentA, typename ContentB, typename Unit, typename PeriodA, typename PeriodB, typename Times = Infinite&gt;</pre> | 介绍 DoubleRepeat 模板。 |
| 78 | <pre>类似于RepeatEvery，但是交替执行两个内容模块ContentA和ContentB。先等待PeriodA时间后执行ContentA，再等待PeriodB时间后执行ContentB，然后循环。Times指定的是两个内容总计执行的次数之和，而不是完整周期数，因此可以指定奇数Times以使得ContentA比ContentB多执行一次。</pre> | 说明 DoubleRepeat 在 ContentA 与 ContentB 之间交替执行，Times 计的是总执行次数。 |
| 79 | <pre>————————————</pre> | 分隔线。 |
| 80 | <pre># 瞬时类模块</pre> | 开始介绍“瞬时类模块”。 |
| 81 | <pre>————————————</pre> | 分隔线。 |
| 82 | <pre>瞬时类模块执行时不需要等待时间，可以立即完成</pre> | 说明瞬时类模块不需要等待，可立即完成。 |
| 83 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 84 | <pre>## ModuleAbort&lt;typename Target&gt;</pre> | 介绍 ModuleAbort。 |
| 85 | <pre>执行此模块将导致Target模块被立即放弃（包括无限执行的模块），结束执行。如果Target模块当前未在执行中，则不进行任何操作。</pre> | 说明 ModuleAbort 会立刻终止目标模块。 |
| 86 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 87 | <pre>## ModuleRestart&lt;typename Target&gt;</pre> | 介绍 ModuleRestart。 |
| 88 | <pre>执行此模块将导致Target模块被立即重新开始执行。如果Target模块当前未在执行中，则立即开始执行。</pre> | 说明 ModuleRestart 会立刻从头重启目标模块。 |
| 89 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 90 | <pre>## ModuleRandomize&lt;typename Target&gt;</pre> | 介绍 ModuleRandomize。 |
| 91 | <pre>执行此模块将导致具有随机功能的Target模块，如RandomInteger和RandomSequential，被重新随机化。不能对非随机化模块使用此模块。</pre> | 说明 ModuleRandomize 用来刷新随机模块的内部随机值。 |
| 92 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 93 | <pre>## DigitalWrite&lt;uint8_t Pin, bool HighOrLow&gt;</pre> | 介绍 DigitalWrite。 |
| 94 | <pre>执行此模块将导致指定引脚的输出电平被设置为HIGH或LOW。</pre> | 说明 DigitalWrite 直接写高低电平。 |
| 95 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 96 | <pre>## DigitalToggle&lt;uint8_t Pin&gt;</pre> | 介绍 DigitalToggle。 |
| 97 | <pre>执行此模块将导致指定引脚的输出电平被翻转。此模块可配合RepeatEvery模块用于输出音调。</pre> | 说明 DigitalToggle 多用于和 RepeatEvery 组合生成音调或闪烁。 |
| 98 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 99 | <pre>## MonitorPin&lt;uint8_t Pin, typename Monitor&gt;</pre> | 介绍 MonitorPin。 |
| 100 | <pre>对指定引脚注册一个中断监听器，每当引脚电平RISING时开始执行Monitor模块。Monitor模块的执行不会打断中断触发时正在执行的模块，两者将同步执行。对此模块使用ModuleAbort以停止监视引脚，但正在执行的Monitor模块不会中止。要中止Monitor模块，请对Monitor直接使用ModuleAbort。</pre> | 说明 MonitorPin 基于上升沿中断启动一个监视模块，而且不会打断主流程。 |
| 101 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 102 | <pre>## SerialMessage&lt;UID Message&gt;</pre> | 介绍 SerialMessage。 |
| 103 | <pre>向PC端发送一个预定义的Message，通常前缀Event_表示一个事件消息，将被PC端记录；Host_表示一个主机动作消息，令PC端执行相应的动作。</pre> | 说明 SerialMessage 会把预定义消息发给 PC 端记录或触发主机动作。 |
| 104 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 105 | <pre>## CleanWhenAbort&lt;typename Target, typename Cleaner&gt;</pre> | 介绍 CleanWhenAbort。 |
| 106 | <pre>将一个Cleaner模块附加到Target模块上，监听Target的开始、重启、终止或析构，这些事件之前会先执行Cleaner，但目标模块正常结束时则不会清理。Cleaner一般应是瞬时的，如果有延时操作则不会等待其完成。</pre> | 说明它给目标模块附加清理动作，但目标模块正常结束时不会触发清理。 |
| 107 | <pre>————————————</pre> | 分隔线。 |
| 108 | <pre># 容器类模块</pre> | 开始介绍“容器类模块”。 |
| 109 | <pre>————————————</pre> | 分隔线。 |
| 110 | <pre>容器类模块可以包含其他模块，并控制这些模块的执行顺序。执行时间取决于所包含模块的执行时间。</pre> | 说明容器类模块通过组合其他模块来形成流程。 |
| 111 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 112 | <pre>## Sequential&lt;SubModules...&gt;</pre> | 介绍 Sequential。 |
| 113 | <pre>按指定顺序执行多个SubModules模块，等待前一个模块执行结束才会继续执行下一个。</pre> | 说明 Sequential 按顺序依次执行各子模块。 |
| 114 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 115 | <pre>## RandomSequential&lt;typename... SubModules&gt;</pre> | 介绍 RandomSequential。 |
| 116 | <pre>类似于Sequential，但执行顺序随机。这个随机顺序在重复运行时保持相同，要重新随机化请使用ModuleRandomize模块。此模块还支持以下扩展：</pre> | 说明 RandomSequential 的子模块顺序随机，但重复执行时会保持当前随机顺序。 |
| 117 | <pre>- typename RandomSequential&lt;typename... SubModules&gt;::template WithRepeat&lt;uint16_t... Repeats&gt;：指定的Repeats对应每个SubModules的重复次数，这些重复也将互相穿插随机打乱执行。例如`typename RandomSequential&lt;A,B,C&gt;::template WithRepeat&lt;20,30,10&gt;`将会把20次A、30次B、10次C模块随机穿插洗牌执行。</pre> | 解释 WithRepeat 扩展能为每个子模块指定重复次数并一起打乱。 |
| 118 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 119 | <pre>## Repeat&lt;typename Content, typename Times = Infinite&gt;</pre> | 介绍 Repeat。 |
| 120 | <pre>重复执行Content模块，等待前一次重复执行结束才会继续执行下一次。Times是重复次数，可以是ConstantInteger或RandomInteger，或者不提供此参数则默认无限重复；如果指定RandomInteger，将在此模块开始时确定重复次数；在重复执行过程中重新随机化RandomInteger不会改变重复次数。</pre> | 说明 Repeat 等前一次结束后再进入下一次，若 Times 是随机数则在开始时固定。 |
| 121 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 122 | <pre>## Trial&lt;UID TrialID, typename Content&gt;</pre> | 介绍 Trial。 |
| 123 | <pre>表示一个回合。TrialID是该模块的唯一标识符。Content是回合内要执行的内容模块。回合开始时将把TrialID发往PC端进行记录并提示回合开始。</pre> | 说明 Trial 用来标记“一个回合”，会向 PC 发送 TrialID。 |
| 124 | <pre>回合还是断线重连恢复执行的基本单位。断线重连后，尚未执行完毕的回合将从头开始重新执行，已经执行完毕的回合将不会重复执行。不在回合内的模块在断线重连后不会跳过，仍会重复执行。</pre> | 说明断线重连恢复也是以 Trial 为基本单位。 |
| 125 | <pre>回合内不允许嵌套回合。</pre> | 说明 Trial 内不允许再嵌套 Trial。 |
| 126 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 127 | <pre>## DynamicSlot&lt;UID UniqueID = UID::Module_DynamicSlot&gt;</pre> | 介绍 DynamicSlot。 |
| 128 | <pre>表示一个动态插槽，可以在运行时动态加载、清除或切换其内容模块。UniqueID是该模块的唯一标识符。执行此模块时，将执行当前插槽内的内容模块（如果有），否则什么也不做。对此模块的重启和终止操作也将传递给当前插槽内的内容模块（如果有）。要修改插槽内容，请使用以下扩展：</pre> | 说明 DynamicSlot 是一个可在运行时替换内容的动态插槽。 |
| 129 | <pre>- typename DynamicSlot&lt;UniqueID&gt;::template Load&lt;Content&gt;：将插槽内容设置为Content模块。如果插槽内已经有内容模块正在运行，不会终止它，换新后仍继续执行。</pre> | 解释 Load 扩展用来把某个模块装入插槽。 |
| 130 | <pre>- typename DynamicSlot&lt;UniqueID&gt;::Clear：清除插槽内容。不会终止当前正在运行的内容模块，清除后仍继续执行。</pre> | 解释 Clear 扩展用来清空插槽，但不打断已经在运行的旧内容。 |
| 131 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 132 | <pre>## IDModule&lt;UID ID&gt;</pre> | 介绍 IDModule。 |
| 133 | <pre>使用此模块后，必须用AssignModuleID宏将某个模块绑定到TargetID上：</pre> | 说明 IDModule 需要配合 AssignModuleID 使用。 |
| 134 | <pre>```</pre> | 代码块起始，仅展示绑定语法。 |
| 135 | <pre>AssignModuleID(TargetModule, TargetID);</pre> | 给出 AssignModuleID 的调用格式示例。 |
| 136 | <pre>```</pre> | 代码块结束。 |
| 137 | <pre>这样执行此模块时，将视为执行与TargetID所绑定的模块TargetModule相同的模块。此模块的重启和终止操作也将传递给TargetModule。此模块主要用于实现自我循环引用。IDModule可以在TargetModule之前声明，但AssignModuleID必须在TargetModule定义之后。</pre> | 说明 IDModule 允许在其他位置通过 ID 引用已绑定的目标模块，也支持自引用式控制。 |
| 138 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 139 | <pre>## Async&lt;typename Content&gt;</pre> | 介绍 Async。 |
| 140 | <pre>异步执行Content模块。执行此模块时，将立即返回并继续执行后续模块，而Content模块将在后台异步执行。此模块的Restart和Abort操作也将传递给Content模块。此模块主要用于实现后台任务。</pre> | 说明 Async 会后台启动内容模块，当前流程立即继续。 |
| 141 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 142 | <pre>——以下提供实际用例，用户可根据需要进行修改——</pre> | 提示下面开始进入真实实验定义，不再只是框架说明。 |
| 143 | <pre>*/</pre> | 结束这整段模块说明注释。 |
| 144 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 145 | <pre>template&lt;DurationRep Milliseconds&gt;</pre> | 定义一个以毫秒为参数的模板别名。 |
| 146 | <pre>using DelayMilliseconds = Delay&lt;std::chrono::milliseconds, ConstantInteger&lt;Milliseconds&gt;&gt;;</pre> | 把 Delay 的单位固定成毫秒，简化后续写法。 |
| 147 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 148 | <pre>template&lt;uint8_t PinIndex, DurationRep Milliseconds&gt;</pre> | 定义 PinFlash 的模板别名。 |
| 149 | <pre>using PinFlash = Sequential&lt;DigitalWrite&lt;PinIndex, HIGH&gt;, DelayMilliseconds&lt;Milliseconds&gt;, DigitalWrite&lt;PinIndex, LOW&gt;&gt;;</pre> | PinFlash 的逻辑是拉高引脚、等待若干毫秒、再拉低。 |
| 150 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 151 | <pre>template&lt;uint8_t PinIndex, DurationRep Milliseconds, UID Up&gt;</pre> | 定义 PinFlashUp 的模板别名。 |
| 152 | <pre>using PinFlashUp = Sequential&lt;DigitalWrite&lt;PinIndex, HIGH&gt;, SerialMessage&lt;Up&gt;, DelayMilliseconds&lt;Milliseconds&gt;, DigitalWrite&lt;PinIndex, LOW&gt;&gt;;</pre> | PinFlashUp 在拉高后额外发送一个事件消息，常用于记录刺激开始。 |
| 153 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 154 | <pre>template&lt;uint8_t PinIndex, DurationRep Milliseconds, UID Up, UID Down&gt;</pre> | 定义 PinFlashUpDown 的模板别名。 |
| 155 | <pre>using PinFlashUpDown = Sequential&lt;DigitalWrite&lt;PinIndex, HIGH&gt;, SerialMessage&lt;Up&gt;, DelayMilliseconds&lt;Milliseconds&gt;, DigitalWrite&lt;PinIndex, LOW&gt;, SerialMessage&lt;Down&gt;&gt;;</pre> | PinFlashUpDown 同时在开始和结束时各发送一个消息。 |
| 156 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 157 | <pre>using Random100To1000 = RandomInteger&lt;100, 1000&gt;;</pre> | 定义一个 100 到 1000 毫秒的随机整数。 |
| 158 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 159 | <pre>using RandomFlash = Repeat&lt;Sequential&lt;DigitalToggle&lt;Laser&gt;, Delay&lt;std::chrono::milliseconds, Random100To1000&gt;, ModuleRandomize&lt;Random100To1000&gt;&gt;&gt;;</pre> | RandomFlash 会无限重复“翻转激光引脚、等待随机时长、重随机化等待时间”。 |
| 160 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 161 | <pre>using Random5To10 = RandomInteger&lt;5, 10&gt;;</pre> | 定义一个 5 到 10 秒的随机整数。 |
| 162 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 163 | <pre>using Delay5To10 = Delay&lt;std::chrono::seconds, Random5To10&gt;;</pre> | Delay5To10 把上面的随机整数作为秒级延时使用。 |
| 164 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 165 | <pre>using MonitorRestart = MonitorPin&lt;CapacitorOut, ModuleRestart&lt;Delay5To10&gt;&gt;;</pre> | MonitorRestart 监听 CapacitorOut，一旦触发就重启 Delay5To10，相当于“有舔水就重新计时”。 |
| 166 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 167 | <pre>template&lt;DurationRep Seconds&gt;</pre> | 定义以秒为单位的模板别名。 |
| 168 | <pre>using DelaySeconds = Delay&lt;std::chrono::seconds, ConstantInteger&lt;Seconds&gt;&gt;;</pre> | 把 Delay 的单位固定成秒。 |
| 169 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 170 | <pre>template&lt;DurationRep FrequencyHz, DurationRep Milliseconds&gt;</pre> | 定义 Tone 的模板别名。 |
| 171 | <pre>using Tone = RepeatEvery&lt;DigitalToggle&lt;PassiveBuzzer&gt;, std::chrono::microseconds, ConstantInteger&lt;500000 / FrequencyHz&gt;, ConstantInteger&lt;Milliseconds * FrequencyHz / 500&gt;&gt;;</pre> | Tone 通过重复翻转 PassiveBuzzer 引脚形成指定频率与总时长的方波。 |
| 172 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 173 | <pre>using ResponseWindow = MonitorPin&lt;CapacitorOut, Sequential&lt;DynamicSlot&lt;&gt;::Clear, ModuleAbort&lt;IDModule&lt;UID::Module_ResponseWindow&gt;&gt;, SerialMessage&lt;UID::Event_MonitorHit&gt;&gt;&gt;;</pre> | ResponseWindow 监听 CapacitorOut，命中后会清空动态插槽、终止自身并发送命中事件。 |
| 174 | <pre>AssignModuleID(ResponseWindow, UID::Module_ResponseWindow);</pre> | 把 ResponseWindow 绑定到 UID::Module_ResponseWindow，便于在别处通过 ID 中止它。 |
| 175 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 176 | <pre>using CalmDown = Sequential&lt;DynamicSlot&lt;&gt;::Load&lt;Sequential&lt;ModuleAbort&lt;ResponseWindow&gt;, SerialMessage&lt;UID::Event_MonitorMiss&gt;&gt;&gt;, MonitorRestart, Delay5To10, ModuleAbort&lt;MonitorRestart&gt;&gt;;</pre> | CalmDown 的逻辑是先把“未命中处理”装入默认动态插槽，再监听舔水触发、等待 5 到 10 秒安静期，最后取消监听。 |
| 177 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 178 | <pre>using Settlement = Sequential&lt;ModuleRandomize&lt;Random5To10&gt;, DelaySeconds&lt;20&gt;&gt;;</pre> | Settlement 会先重新随机化 5 到 10 秒，再固定等待 20 秒，作为回合后的稳定期。 |
| 179 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 180 | <pre>using Delay800ms = DelayMilliseconds&lt;800&gt;;</pre> | 把 800 毫秒延时起一个短别名。 |
| 181 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 182 | <pre>template&lt;uint8_t CuePin, UID CueUp, UID CueDown&gt;</pre> | 定义 AssociationTrial 的模板参数，接受线索引脚和两个事件 ID。 |
| 183 | <pre>using AssociationTrial = Sequential&lt;CalmDown, ResponseWindow, PinFlashUpDown&lt;CuePin, 200, CueUp, CueDown&gt;, Delay800ms, DynamicSlot&lt;&gt;, DigitalWrite&lt;WaterPump, HIGH&gt;, SerialMessage&lt;UID::Event_Water&gt;, DelayMilliseconds&lt;150&gt;, DigitalWrite&lt;WaterPump, LOW&gt;, Settlement&gt;;</pre> | AssociationTrial 的完整流程是安静期、开启反应窗口、呈现线索、给 800 毫秒缓冲、执行默认插槽内容、出水并进入稳定期。 |
| 184 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 185 | <pre>template&lt;typename Cue&gt;</pre> | 定义 CueOnlyTrial，接受一个已经构好的 Cue 模块。 |
| 186 | <pre>using CueOnlyTrial = Sequential&lt;CalmDown, ResponseWindow, Cue, Delay800ms, DynamicSlot&lt;&gt;, Settlement&gt;;</pre> | CueOnlyTrial 与 AssociationTrial 类似，但没有给水，只呈现线索后结束。 |
| 187 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 188 | <pre>using BackgroundMonitor = MonitorPin&lt;CapacitorOut, SerialMessage&lt;UID::Event_HitCount&gt;&gt;;</pre> | BackgroundMonitor 在整个 session 期间持续监听舔水并累计命中事件。 |
| 189 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 190 | <pre>using CapacitorInitialize = Sequential&lt;DigitalWrite&lt;CapacitorVdd, HIGH&gt;, DelaySeconds&lt;1&gt;, BackgroundMonitor&gt;;</pre> | CapacitorInitialize 会先给电容供电、等待 1 秒、再启动背景监视器。 |
| 191 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 192 | <pre>// 点亮电容后等待1s，渡过刚启动的不稳定期</pre> | 注释说明下面这个 session 定义为什么要先等 1 秒。 |
| 193 | <pre>template&lt;typename TrialType&gt;</pre> | 定义 AssociationSession 模板。 |
| 194 | <pre>using AssociationSession = Sequential&lt;DigitalWrite&lt;CapacitorVdd, HIGH&gt;, DelaySeconds&lt;1&gt;, BackgroundMonitor, Repeat&lt;TrialType, ConstantInteger&lt;30&gt;&gt;, ModuleAbort&lt;BackgroundMonitor&gt;&gt;;</pre> | AssociationSession 会初始化电容后重复执行 30 次指定 trial，最后停止背景监视。 |
| 195 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 196 | <pre>//自定义次数</pre> | 注释说明下面是可自定义次数的 session 版本。 |
| 197 | <pre>template&lt;typename TrialType, uint16_t Times&gt;</pre> | 定义 AssociationSessionTimes 模板。 |
| 198 | <pre>using AssociationSessionTimes = Sequential&lt;CapacitorInitialize, Repeat&lt;TrialType, ConstantInteger&lt;Times&gt;&gt; &gt;;</pre> | AssociationSessionTimes 重用 CapacitorInitialize，但把 trial 次数交给模板参数 Times。 |
| 199 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 200 | <pre>/*Optogenetics*/</pre> | 注释说明下面进入光遗传刺激相关模块。 |
| 201 | <pre>template&lt;uint8_t PinIndex, uint16_t Times&gt;</pre> | 定义 Opto30Hz 的模板参数。 |
| 202 | <pre>using Opto30Hz = Sequential&lt;</pre> | 开始定义 30Hz 光刺激序列。 |
| 203 | <pre>                  DigitalWrite&lt;PinIndex, HIGH&gt;,</pre> | 先把指定激光引脚拉高，形成起始高电平。 |
| 204 | <pre>                  DoubleRepeat&lt;</pre> | 开始用 DoubleRepeat 展开高低脉冲串。 |
| 205 | <pre>                    DigitalWrite&lt;PinIndex, LOW&gt;,</pre> | DoubleRepeat 的第一个内容是把引脚拉低。 |
| 206 | <pre>                    DigitalWrite&lt;PinIndex, HIGH&gt;,</pre> | DoubleRepeat 的第二个内容是把引脚拉高。 |
| 207 | <pre>                    std::chrono::milliseconds, </pre> | 两个相位的时间单位都用毫秒。 |
| 208 | <pre>                    ConstantInteger&lt;10&gt;,</pre> | 低电平持续 10 毫秒。 |
| 209 | <pre>                    ConstantInteger&lt;23&gt;,</pre> | 高电平持续 23 毫秒。 |
| 210 | <pre>                    ConstantInteger&lt;Times&gt;</pre> | 总切换次数由模板参数 Times 决定。 |
| 211 | <pre>                  &gt;,</pre> | 结束 DoubleRepeat 定义。 |
| 212 | <pre>                  DigitalWrite&lt;PinIndex, LOW&gt;</pre> | 序列最后显式把引脚拉低，确保刺激结束后关闭激光。 |
| 213 | <pre>                &gt;;</pre> | 结束 Opto30Hz 定义。 |
| 214 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 215 | <pre>template&lt;uint8_t PinIndex, uint16_t Times1, uint16_t Times2&gt;</pre> | 定义 Opto30HzRandom 的模板参数。 |
| 216 | <pre>using Opto30HzRandom = Sequential&lt;</pre> | 开始定义带随机脉冲次数的 30Hz 光刺激序列。 |
| 217 | <pre>                  DigitalWrite&lt;PinIndex, HIGH&gt;,</pre> | 先把激光引脚拉高。 |
| 218 | <pre>                  DoubleRepeat&lt;</pre> | 开始定义交替高低电平。 |
| 219 | <pre>                    DigitalWrite&lt;PinIndex, LOW&gt;,</pre> | 低相位写成拉低操作。 |
| 220 | <pre>                    DigitalWrite&lt;PinIndex, HIGH&gt;,</pre> | 高相位写成拉高操作。 |
| 221 | <pre>                    std::chrono::milliseconds, </pre> | 时间单位同样使用毫秒。 |
| 222 | <pre>                    ConstantInteger&lt;10&gt;,</pre> | 低电平保持 10 毫秒。 |
| 223 | <pre>                    ConstantInteger&lt;23&gt;,</pre> | 高电平保持 23 毫秒。 |
| 224 | <pre>                    RandomInteger&lt;Times1, Times2&gt;</pre> | 脉冲总次数在 Times1 到 Times2 之间随机抽取。 |
| 225 | <pre>                  &gt;,</pre> | 结束 DoubleRepeat。 |
| 226 | <pre>                  DigitalWrite&lt;PinIndex, LOW&gt;</pre> | 刺激结束后再次拉低输出。 |
| 227 | <pre>                &gt;;</pre> | 结束 Opto30HzRandom。 |
| 228 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 229 | <pre>template&lt;uint8_t PinIndex, uint16_t Times&gt;</pre> | 定义 Opto40Hz 的模板参数。 |
| 230 | <pre>using Opto40Hz = Sequential&lt;</pre> | 开始定义 40Hz 光刺激序列。 |
| 231 | <pre>                  DigitalWrite&lt;PinIndex, HIGH&gt;,</pre> | 先把激光引脚拉高。 |
| 232 | <pre>                  DoubleRepeat&lt;</pre> | 开始定义交替重复模块。 |
| 233 | <pre>                    DigitalWrite&lt;PinIndex, LOW&gt;,</pre> | 低相位对应拉低。 |
| 234 | <pre>                    DigitalWrite&lt;PinIndex, HIGH&gt;,</pre> | 高相位对应拉高。 |
| 235 | <pre>                    std::chrono::milliseconds, </pre> | 时间单位仍为毫秒。 |
| 236 | <pre>                    ConstantInteger&lt;2&gt;,</pre> | 40Hz 模式下低电平只保持 2 毫秒。 |
| 237 | <pre>                    ConstantInteger&lt;23&gt;,</pre> | 高电平保持 23 毫秒。 |
| 238 | <pre>                    ConstantInteger&lt;Times&gt;</pre> | 总次数由模板参数 Times 决定。 |
| 239 | <pre>                  &gt;,</pre> | 结束 DoubleRepeat。 |
| 240 | <pre>                  DigitalWrite&lt;PinIndex, LOW&gt;</pre> | 最后把引脚拉低以复位状态。 |
| 241 | <pre>                &gt;;</pre> | 结束 Opto40Hz 定义。 |
| 242 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 243 | <pre>template&lt;uint8_t PinIndex1, uint8_t PinIndex2, uint16_t Times1, uint16_t Times2&gt;</pre> | 定义双引脚 30Hz 模板参数。 |
| 244 | <pre>using Opto30Hz2Pin = Sequential&lt;Async&lt;Opto30Hz&lt;PinIndex1, Times1&gt;&gt;, Opto30Hz&lt;PinIndex2, Times2&gt;&gt;;</pre> | Opto30Hz2Pin 让第一个引脚异步刺激，同时在当前流程里对第二个引脚刺激，实现双路近同步。 |
| 245 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 246 | <pre>template&lt;uint8_t PinIndex1, uint8_t PinIndex2, uint8_t PinIndex3, uint16_t Times1, uint16_t Times2, uint16_t Times3&gt;</pre> | 定义三引脚 30Hz 模板参数。 |
| 247 | <pre>using Opto30Hz3Pin = Sequential&lt;Async&lt;Opto30Hz&lt;PinIndex1, Times1&gt;&gt;, Async&lt;Opto30Hz&lt;PinIndex2, Times2&gt;&gt;, Opto30Hz&lt;PinIndex3, Times3&gt;&gt;;</pre> | Opto30Hz3Pin 让前两路异步开始，第三路在当前流程里执行，实现三路近同步。 |
| 248 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 249 | <pre>template&lt;uint8_t PinIndex1, uint8_t PinIndex2, uint16_t Times1, uint16_t Times2&gt;</pre> | 定义双引脚 40Hz 模板参数。 |
| 250 | <pre>using Opto40Hz2Pin = Sequential&lt;Async&lt;Opto40Hz&lt;PinIndex1, Times1&gt;&gt;, Opto40Hz&lt;PinIndex2, Times2&gt;&gt;;</pre> | Opto40Hz2Pin 用和双路 30Hz 同样的思路并联两路 40Hz。 |
| 251 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 252 | <pre>template&lt;uint8_t PinIndex1, uint8_t PinIndex2&gt;</pre> | 定义 Theta-Gamma 组合刺激的双引脚模板参数。 |
| 253 | <pre>using OptoThetaGamma1 = Sequential&lt;Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1&gt;,DelayMilliseconds&lt;73&gt;,</pre> | OptoThetaGamma1 先做一段双路 40Hz 刺激，再等待 73 毫秒。 |
| 254 | <pre>                                  Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1&gt;,DelayMilliseconds&lt;73&gt;&gt;;</pre> | 随后再做第二段相同刺激并再等 73 毫秒，拼出 theta 节律上的 gamma burst。 |
| 255 | <pre>/*using OptoThetaGamma1 = Sequential&lt;Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 50/25*2-1, 50/25*2-1&gt;,DelayMilliseconds&lt;98&gt;,</pre> | 注释掉一种候选参数方案，使用 50 毫秒 burst 与 98 毫秒间隔。 |
| 256 | <pre>                                  Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 50/25*2-1, 50/25*2-1&gt;,DelayMilliseconds&lt;98&gt;&gt;;75+23</pre> | 这行注释补充说明 75+23 的节律长度。 |
| 257 | <pre>using OptoThetaGamma1 = Sequential&lt;Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1&gt;,DelayMilliseconds&lt;73&gt;,</pre> | 注释中再次给出当前启用的 75 毫秒 burst 版本。 |
| 258 | <pre>                                  Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1&gt;,DelayMilliseconds&lt;73&gt;&gt;;50+23</pre> | 注释中补充 50+23 的说明。 |
| 259 | <pre>using OptoThetaGamma1 = Sequential&lt;Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 100/25*2-1, 100/25*2-1&gt;,DelayMilliseconds&lt;48&gt;,</pre> | 注释中给出 100 毫秒 burst 的另一种备选方案。 |
| 260 | <pre>                                  Opto40Hz2Pin&lt;PinIndex1, PinIndex2, 100/25*2-1, 100/25*2-1&gt;,DelayMilliseconds&lt;48&gt;&gt;;25+23*/</pre> | 注释中补充 25+23 的说明并结束整段备选注释。 |
| 261 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 262 | <pre>template&lt;uint8_t PinIndex1&gt;</pre> | 定义单引脚 Theta-Gamma 模板参数。 |
| 263 | <pre>using SingleThetaGamma1 = Sequential&lt;Opto40Hz&lt;PinIndex1, 75/25*2-1&gt;, DelayMilliseconds&lt;73&gt;,</pre> | SingleThetaGamma1 在单路激光上做第一段 40Hz burst 后等待 73 毫秒。 |
| 264 | <pre>                                   Opto40Hz&lt;PinIndex1, 75/25*2-1&gt;, DelayMilliseconds&lt;73&gt;&gt;;</pre> | 然后执行第二段相同 burst 再等 73 毫秒。 |
| 265 | <pre>/*using SingleThetaGamma1 = Sequential&lt;Opto40Hz&lt;PinIndex1, 50/25*2-1&gt;, DelayMilliseconds&lt;98&gt;,</pre> | 注释掉单路 50 毫秒 burst 备选方案。 |
| 266 | <pre>                                   Opto40Hz&lt;PinIndex1, 50/25*2-1&gt;, DelayMilliseconds&lt;98&gt;&gt;;75+23</pre> | 注释里补充 75+23 的节律说明。 |
| 267 | <pre>using SingleThetaGamma1 = Sequential&lt;Opto40Hz&lt;PinIndex1, 75/25*2-1&gt;, DelayMilliseconds&lt;73&gt;,</pre> | 注释里再次写出 75 毫秒 burst 版本。 |
| 268 | <pre>                                   Opto40Hz&lt;PinIndex1, 75/25*2-1&gt;, DelayMilliseconds&lt;73&gt;&gt;;50+23</pre> | 注释里补充 50+23 的说明。 |
| 269 | <pre>using SingleThetaGamma1 = Sequential&lt;Opto40Hz&lt;PinIndex1, 100/25*2-1&gt;, DelayMilliseconds&lt;48&gt;,</pre> | 注释里写出 100 毫秒 burst 版本。 |
| 270 | <pre>                                   Opto40Hz&lt;PinIndex1, 100/25*2-1&gt;, DelayMilliseconds&lt;48&gt;&gt;;25+23*/</pre> | 注释里补充 25+23 的说明并结束整段注释。 |
| 271 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 272 | <pre>/*Tone,delay,air,water*/</pre> | 注释说明下面进入声音、延时、气吹和给水模块。 |
| 273 | <pre>using HighTone500 = Sequential&lt;SerialMessage&lt;UID::Event_HighUp&gt;, Tone&lt;10000, 500&gt;, SerialMessage&lt;UID::Event_HighDown&gt;&gt;;</pre> | HighTone500 会发高音开始事件、播放 10000Hz 的 500ms 方波、再发高音结束事件。 |
| 274 | <pre>using LowTone500 = Sequential&lt;SerialMessage&lt;UID::Event_LowUp&gt;, Tone&lt;2400, 500&gt;, SerialMessage&lt;UID::Event_LowDown&gt;&gt;;</pre> | LowTone500 逻辑相同，但频率换成 2400Hz。 |
| 275 | <pre>using Air100 = PinFlashUp&lt;AirPump, 100, UID::Event_AirPuff&gt;;</pre> | Air100 把气泵拉高 100ms，并发送气吹事件。 |
| 276 | <pre>using Water100 = PinFlashUp&lt;WaterPump, 150, UID::Event_Water&gt;;</pre> | Water100 把水泵拉高 150ms，并发送给水事件。 |
| 277 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 278 | <pre>/*Response*/</pre> | 注释说明下面进入反应检测模块。 |
| 279 | <pre>using RightDetector = MonitorPin&lt;CapacitorOut, Sequential&lt;ModuleAbort&lt;IDModule&lt;UID::Module_RightDetector&gt;&gt;, DynamicSlot&lt;UID::Module_LickDetector&gt;::Clear, SerialMessage&lt;UID::Event_MonitorHit&gt;, Water100&gt;&gt;;</pre> | RightDetector 在舔水命中时会终止自身、清空舔检测动态插槽、发送命中事件并给水。 |
| 280 | <pre>AssignModuleID(RightDetector, UID::Module_RightDetector);</pre> | 将 RightDetector 绑定到 UID::Module_RightDetector。 |
| 281 | <pre>using FalseDetector = MonitorPin&lt;CapacitorOut, Sequential&lt;ModuleAbort&lt;IDModule&lt;UID::Module_FalseDetector&gt;&gt;, DynamicSlot&lt;UID::Module_LickDetector&gt;::Clear, SerialMessage&lt;UID::Event_FalseChoice&gt;, Air100&gt;&gt;;</pre> | FalseDetector 在错误舔水时会终止自身、清空舔检测插槽、发送错误选择事件并施加气吹。 |
| 282 | <pre>AssignModuleID(FalseDetector, UID::Module_FalseDetector);</pre> | 将 FalseDetector 绑定到 UID::Module_FalseDetector。 |
| 283 | <pre>using WaterAlwaysDetector = MonitorPin&lt;</pre> | 开始定义 WaterAlwaysDetector，它是一个多行写法的监听器。 |
| 284 | <pre>                                CapacitorOut, </pre> | 指定被监听的仍然是 CapacitorOut。 |
| 285 | <pre>                                Sequential&lt; </pre> | 进入 WaterAlwaysDetector 触发后要执行的顺序模块。 |
| 286 | <pre>                                  ModuleAbort&lt;IDModule&lt;UID::Module_WaterAlwaysDetector&gt;&gt;,</pre> | 命中后先终止 WaterAlwaysDetector 自身，避免重复触发。 |
| 287 | <pre>                                  SerialMessage&lt;UID::Event_MonitorHit&gt;, </pre> | 然后发送命中事件。 |
| 288 | <pre>                                  Water100,</pre> | 接着无条件给水。 |
| 289 | <pre>                                  DynamicSlot&lt;UID::Module_Water&gt;::Clear,</pre> | 清除专门用于“持续可给水”条件的动态水插槽。 |
| 290 | <pre>                                  DynamicSlot&lt;UID::Module_LickDetector&gt;::Clear</pre> | 清除舔水检测插槽，避免残留逻辑干扰。 |
| 291 | <pre>                                &gt;</pre> | 结束内部 Sequential。 |
| 292 | <pre>                                &gt;;</pre> | 结束 WaterAlwaysDetector 模块定义。 |
| 293 | <pre>AssignModuleID(WaterAlwaysDetector, UID::Module_WaterAlwaysDetector);</pre> | 将 WaterAlwaysDetector 绑定到 UID::Module_WaterAlwaysDetector。 |
| 294 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 295 | <pre>using ResponseRight = Sequential&lt;DynamicSlot&lt;UID::Module_LickDetector&gt;::Load&lt;SerialMessage&lt;UID::Event_MonitorMiss&gt;&gt;, RightDetector, DelayMilliseconds&lt;1000&gt;, ModuleAbort&lt;RightDetector&gt;, DynamicSlot&lt;UID::Module_LickDetector&gt;&gt;;</pre> | ResponseRight 先把“未命中”消息装入舔检测插槽，再开 RightDetector，等待 1 秒后关掉检测器并执行插槽内容。 |
| 296 | <pre>using ResponseFalse = Sequential&lt;DynamicSlot&lt;UID::Module_LickDetector&gt;::Load&lt;SerialMessage&lt;UID::Event_CorrectReject&gt;&gt;, FalseDetector, DelayMilliseconds&lt;1000&gt;, ModuleAbort&lt;FalseDetector&gt;, DynamicSlot&lt;UID::Module_LickDetector&gt;&gt;;</pre> | ResponseFalse 类似，但默认插槽写入的是正确拒绝事件，真正舔水时反而被 FalseDetector 改写成错误选择。 |
| 297 | <pre>using ResponseWaterAlways = Sequential&lt;</pre> | 开始定义 ResponseWaterAlways。 |
| 298 | <pre>                              DynamicSlot&lt;UID::Module_Water&gt;::Load&lt;Water100&gt;,</pre> | 先把 Water100 装入动态水插槽。 |
| 299 | <pre>                              WaterAlwaysDetector,</pre> | 然后开启 WaterAlwaysDetector。 |
| 300 | <pre>                              DelayMilliseconds&lt;1000&gt;,</pre> | 给一个 1 秒反应窗口。 |
| 301 | <pre>                              ModuleAbort&lt;WaterAlwaysDetector&gt;, </pre> | 时间到后终止 WaterAlwaysDetector。 |
| 302 | <pre>                              DynamicSlot&lt;UID::Module_LickDetector&gt;,</pre> | 执行舔检测动态插槽中的默认内容。 |
| 303 | <pre>                              DynamicSlot&lt;UID::Module_Water&gt;</pre> | 执行动态水插槽中的内容。 |
| 304 | <pre>                            &gt;;</pre> | 结束 ResponseWaterAlways 定义。 |
| 305 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 306 | <pre>using CalmDownSimple = Sequential&lt;DelayMilliseconds&lt;1000&gt;, DynamicSlot&lt;UID::Module_LickDetector&gt;::Load&lt;SerialMessage&lt;UID::Event_MonitorMiss&gt;&gt;&gt;;</pre> | CalmDownSimple 是一个简化安静期，只等 1 秒后把“未命中”消息装入舔检测插槽。 |
| 307 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 308 | <pre>using MonitorRestart1 = MonitorPin&lt;CapacitorOut, ModuleRestart&lt;DelayMilliseconds&lt;5000&gt;&gt;&gt;;</pre> | MonitorRestart1 会在每次检测到舔水时重启一个 5 秒延时。 |
| 309 | <pre>using CalmDown1 = Sequential&lt;MonitorRestart1, DelayMilliseconds&lt;5000&gt;, ModuleAbort&lt;MonitorRestart1&gt;&gt;;</pre> | CalmDown1 通过“触发即重启计时”的方式要求连续 5 秒无舔水才通过。 |
| 310 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 311 | <pre>using WaitingTime2 = Delay&lt;&gt;;</pre> | WaitingTime2 是无限等待，只有被外部 skip 才会结束。 |
| 312 | <pre>using MonitorRestartRight = MonitorPin&lt;CapacitorOut, Sequential&lt;ModuleAbort&lt;IDModule&lt;UID::Module_MonitorRestartRight&gt;&gt;, SerialMessage&lt;UID::Event_MonitorHit&gt;, Water100, ModuleSkip&lt;WaitingTime2&gt;&gt;&gt;;</pre> | MonitorRestartRight 监听到舔水时发送命中事件、给水并跳过 WaitingTime2。 |
| 313 | <pre>AssignModuleID(MonitorRestartRight, UID::Module_MonitorRestartRight);</pre> | 将 MonitorRestartRight 绑定到对应 UID。 |
| 314 | <pre>using MonitorRestartFalse = MonitorPin&lt;CapacitorOut, Sequential&lt;ModuleAbort&lt;IDModule&lt;UID::Module_MonitorRestartFalse&gt;&gt;, SerialMessage&lt;UID::Event_FalseChoice&gt;, DelayMilliseconds&lt;100&gt;, ModuleSkip&lt;WaitingTime2&gt;&gt;&gt;;</pre> | MonitorRestartFalse 监听到舔水时发送错误选择事件、短暂等待 100ms 后跳过 WaitingTime2。 |
| 315 | <pre>AssignModuleID(MonitorRestartFalse, UID::Module_MonitorRestartFalse);</pre> | 将 MonitorRestartFalse 绑定到对应 UID。 |
| 316 | <pre>using LickBeginRight = Sequential&lt;MonitorRestartRight, WaitingTime2&gt;;</pre> | LickBeginRight 表示“等待直到出现一次应答性舔水”。 |
| 317 | <pre>using LickBeginFalse = Sequential&lt;MonitorRestartFalse, WaitingTime2&gt;;</pre> | LickBeginFalse 表示“等待直到出现一次错误性舔水”。 |
| 318 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 319 | <pre>using Shaping = Sequential&lt;DelayMilliseconds&lt;5000&gt;, ResponseRight&gt;; </pre> | Shaping 的 shaping 试次很简单，等 5 秒后进入正确反应窗口。 |
| 320 | <pre>using ShapingTrial = Trial&lt;UID::Trial_Shaping, Shaping&gt;;</pre> | 把 shaping 流程包成一个 Trial。 |
| 321 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 322 | <pre>/*OriginalTrials(NoOpto)*/</pre> | 注释说明下面是无光刺激的原始任务。 |
| 323 | <pre>using HighWater = Sequential&lt;CalmDownSimple, DelayMilliseconds&lt;3000&gt;, HighTone500, DelayMilliseconds&lt;500&gt;, ResponseRight, DelayMilliseconds&lt;15000&gt;&gt;;</pre> | HighWater 是单高音提示后正确舔水给水的试次。 |
| 324 | <pre>using HighWaterAlways = Sequential&lt;CalmDownSimple, DelayMilliseconds&lt;3000&gt;, HighTone500, DelayMilliseconds&lt;500&gt;, ResponseWaterAlways, DelayMilliseconds&lt;15000&gt;&gt;;</pre> | HighWaterAlways 与 HighWater 相近，但使用 WaterAlways 型反应窗口。 |
| 325 | <pre>using LowAir = Sequential&lt;CalmDownSimple, DelayMilliseconds&lt;500&gt;, ResponseFalse, DelayMilliseconds&lt;7000&gt;&gt;;</pre> | LowAir 是低音条件下等待错误拒绝，若错误舔水则气吹。 |
| 326 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 327 | <pre>using HighWaterTrial = Trial&lt;UID::Trial_HighWater, HighWater&gt;;</pre> | 把 HighWater 封装成一个 Trial。 |
| 328 | <pre>using HighWaterAlwaysTrial = Trial&lt;UID::Trial_HighWaterAlways, HighWaterAlways&gt;;</pre> | 把 HighWaterAlways 封装成一个 Trial。 |
| 329 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 330 | <pre>/*PreSession*/</pre> | 注释说明下面是预训练 session。 |
| 331 | <pre>template&lt;typename TrialType1, uint16_t Times1&gt;</pre> | 定义 PreSession 模板参数。 |
| 332 | <pre>using PreSession = Sequential&lt;</pre> | 开始定义 PreSession。 |
| 333 | <pre>                  CapacitorInitialize, </pre> | session 开始时先初始化电容与背景监听。 |
| 334 | <pre>                  typename Repeat&lt;TrialType1&gt;::template UntilTimes&lt;Times1&gt;</pre> | 然后持续重复 trial，直到达到模板参数 Times1 次数为止。 |
| 335 | <pre>                &gt;;</pre> | 结束 PreSession。 |
| 336 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 337 | <pre>/*AlwaysAndAssociatonFixedSession*/</pre> | 注释说明下面是固定两段 session 的模板。 |
| 338 | <pre>template&lt;typename TrialType1, uint16_t Times1, typename TrialType2, uint16_t Times2&gt;</pre> | 定义 A3FixedSession 模板参数。 |
| 339 | <pre>using A3FixedSession = Sequential&lt;</pre> | 开始定义 A3FixedSession。 |
| 340 | <pre>                        CapacitorInitialize, </pre> | 先做 CapacitorInitialize。 |
| 341 | <pre>                        Repeat&lt;TrialType1, ConstantInteger&lt;Times1&gt;&gt;,</pre> | 第一阶段固定重复 TrialType1 指定次数。 |
| 342 | <pre>                        Repeat&lt;TrialType2, ConstantInteger&lt;Times2&gt;&gt;</pre> | 第二阶段固定重复 TrialType2 指定次数。 |
| 343 | <pre>                      &gt;;</pre> | 结束 A3FixedSession。 |
| 344 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 345 | <pre>/*OptoOnePinActTrial*/</pre> | 注释说明下面是单引脚光刺激的试次。 |
| 346 | <pre>using OptoHighWater = Sequential&lt;CalmDownSimple, Async&lt;Opto30Hz&lt;Laser, 2000/33/2*2+1&gt;&gt;, HighTone500, DelayMilliseconds&lt;500&gt;, ResponseRight, DelayMilliseconds&lt;7000&gt;&gt;;</pre> | OptoHighWater 在高音任务前异步启动单路 30Hz 激光刺激，再进入 ResponseRight。 |
| 347 | <pre>using OptoLowAir = Sequential&lt;CalmDownSimple, Async&lt;Opto30Hz&lt;Laser, 122&gt;&gt;, LowTone500, DelayMilliseconds&lt;500&gt;, ResponseFalse, DelayMilliseconds&lt;7000&gt;&gt;;</pre> | OptoLowAir 在低音任务前异步启动较短的单路 30Hz 激光刺激，再进入 ResponseFalse。 |
| 348 | <pre>using OptoSingleAudioTrial0 = typename RandomSequential&lt;</pre> | 开始定义单音节光刺激任务的随机试次集合。 |
| 349 | <pre>                          Trial&lt;UID::Trial_OptoHighWater, OptoHighWater&gt;, </pre> | 集合第一项是 OptoHighWater trial。 |
| 350 | <pre>                          Trial&lt;UID::Trial_OptoLowAir, OptoLowAir&gt;</pre> | 集合第二项是 OptoLowAir trial。 |
| 351 | <pre>                          &gt;::template WithRepeat&lt;2, 2&gt;;</pre> | 规定两类试次各重复 2 次并随机穿插。 |
| 352 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 353 | <pre>using OptoSingleAudioTrial = Sequential&lt;OptoSingleAudioTrial0, ModuleRandomize&lt;OptoSingleAudioTrial0&gt;&gt;;</pre> | OptoSingleAudioTrial 在执行完随机集合后立即重随机化，为下一轮 session 准备新的顺序。 |
| 354 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 355 | <pre>/*MutiplePinsActTrial*/ </pre> | 注释说明下面是多引脚激活版本的单音节任务。 |
| 356 | <pre>using MultiOptoHighWater = Sequential&lt;CalmDownSimple, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 1500/33*2, 1500/33*2&gt;&gt;, HighTone500, Async&lt;Opto30Hz2Pin&lt;Laser, Laser3, 1500/33*2, 1500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseRight, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHighWater 在高音前后分别异步并行两组双路激光刺激，然后进入正确反应窗口。 |
| 357 | <pre>using MultiOptoLowAir = Sequential&lt;CalmDownSimple, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 1500/33*2, 1500/33*2&gt;&gt;, LowTone500, Async&lt;Opto30Hz2Pin&lt;Laser, Laser3, 1500/33*2, 1500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseFalse, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLowAir 是与之对应的低音错误拒绝版本。 |
| 358 | <pre>using MultiOptoSingleAudioTrial0 = typename RandomSequential&lt;</pre> | 开始定义多引脚单音节随机试次集合。 |
| 359 | <pre>                          Trial&lt;UID::Trial_MultiOptoHighWater, MultiOptoHighWater&gt;, </pre> | 第一项是 MultiOptoHighWater。 |
| 360 | <pre>                          Trial&lt;UID::Trial_MultiOptoLowAir, MultiOptoLowAir&gt;</pre> | 第二项是 MultiOptoLowAir。 |
| 361 | <pre>                          &gt;::template WithRepeat&lt;2, 2&gt;;</pre> | 两类试次各重复 2 次并打乱。 |
| 362 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 363 | <pre>using MultiOptoSingleAudioTrial = Sequential&lt;MultiOptoSingleAudioTrial0, ModuleRandomize&lt;MultiOptoSingleAudioTrial0&gt;&gt;;</pre> | MultiOptoSingleAudioTrial 执行完后重随机化顺序。 |
| 364 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 365 | <pre>using OptoSingleAudioTrial = Sequential&lt;OptoSingleAudioTrial0, ModuleRandomize&lt;OptoSingleAudioTrial0&gt;&gt;;</pre> | 这里再次定义 OptoSingleAudioTrial，效果与第353行相同，等于重复写了一次同名别名。 |
| 366 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 367 | <pre>/*double*/</pre> | 注释说明下面进入双音节任务。 |
| 368 | <pre>using HLWater = Sequential&lt;CalmDown1, HighTone500, LowTone500, DelayMilliseconds&lt;500&gt;, ResponseRight, DelayMilliseconds&lt;5000&gt;&gt;;</pre> | HLWater 表示高音后接低音，随后进入正确反应窗口。 |
| 369 | <pre>using HLWaterAlways = Sequential&lt;CalmDown1, HighTone500, LowTone500, DelayMilliseconds&lt;500&gt;, ResponseWaterAlways, DelayMilliseconds&lt;5000&gt;&gt;;</pre> | HLWaterAlways 用同样线索，但采用总会给水的反应窗口。 |
| 370 | <pre>using HHAir = Sequential&lt;CalmDown1, HighTone500, HighTone500, DelayMilliseconds&lt;500&gt;, ResponseFalse, DelayMilliseconds&lt;5000&gt;&gt;;</pre> | HHAir 表示双高音条件，对应错误拒绝任务。 |
| 371 | <pre>using LHAir = Sequential&lt;CalmDown1, LowTone500, HighTone500, DelayMilliseconds&lt;500&gt;, ResponseFalse, DelayMilliseconds&lt;5000&gt;&gt;;</pre> | LHAir 表示低音再高音条件，对应错误拒绝任务。 |
| 372 | <pre>using LLAir = Sequential&lt;CalmDown1, LowTone500, LowTone500, DelayMilliseconds&lt;500&gt;, ResponseFalse, DelayMilliseconds&lt;5000&gt;&gt;;</pre> | LLAir 表示双低音条件，对应错误拒绝任务。 |
| 373 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 374 | <pre>using HLWaterAlwaysTrial = Trial&lt;UID::Trial_HLWaterAlways, HLWaterAlways&gt;;</pre> | 把 HLWaterAlways 包成 Trial。 |
| 375 | <pre>using HLWaterTrial = Trial&lt;UID::Trial_HLWater, HLWater&gt;;</pre> | 把 HLWater 包成 Trial。 |
| 376 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 377 | <pre>using DoubleAudioTrial0 = typename RandomSequential&lt;</pre> | 开始定义双音节随机试次集合。 |
| 378 | <pre>                          Trial&lt;UID::Trial_HLWater, HLWater&gt;, </pre> | 主目标试次是 HLWater。 |
| 379 | <pre>                          Trial&lt;UID::Trial_HHAir, HHAir&gt;,</pre> | 第一类干扰试次是 HHAir。 |
| 380 | <pre>                          Trial&lt;UID::Trial_LHAir, LHAir&gt;, </pre> | 第二类干扰试次是 LHAir。 |
| 381 | <pre>                          Trial&lt;UID::Trial_LLAir, LLAir&gt;</pre> | 第三类干扰试次是 LLAir。 |
| 382 | <pre>                          &gt;::template WithRepeat&lt;3, 1, 1, 1&gt;;</pre> | 规定 HLWater 出现 3 次，其他每类出现 1 次。 |
| 383 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 384 | <pre>using DoubleAudioTrial = Sequential&lt;DoubleAudioTrial0, ModuleRandomize&lt;DoubleAudioTrial0&gt;&gt;;</pre> | DoubleAudioTrial 在每轮结束后重随机化顺序。 |
| 385 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 386 | <pre>/*double MultiOpto*/</pre> | 注释说明下面是双音节任务的多光刺激版本。 |
| 387 | <pre>using HighToneOpto1 = Sequential&lt;Async&lt;HighTone500&gt;, Opto30Hz2Pin&lt;Laser, Laser2, 200/33*2, 200/33*2&gt;, Opto30Hz&lt;Laser, 300/33*2&gt;&gt;;</pre> | HighToneOpto1 表示高音同时伴随激光方案 1。 |
| 388 | <pre>using LowToneOpto1 = Sequential&lt;Async&lt;LowTone500&gt;, Opto30Hz2Pin&lt;Laser, Laser2, 200/33*2, 200/33*2&gt;, Opto30Hz&lt;Laser, 300/33*2&gt;&gt;;</pre> | LowToneOpto1 表示低音同时伴随激光方案 1。 |
| 389 | <pre>using OptoRightWindow1 = Sequential&lt;Async&lt;Opto30Hz2Pin&lt;Laser, Laser3, 1500/33*2, 1500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseRight&gt;;</pre> | OptoRightWindow1 在反应窗口前异步启动一段双路激光，然后进入正确反应窗口。 |
| 390 | <pre>using OptoFalseWindow1 = Sequential&lt;Async&lt;Opto30Hz2Pin&lt;Laser, Laser3, 1500/33*2, 1500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseFalse&gt;;</pre> | OptoFalseWindow1 是对应的错误拒绝版本。 |
| 391 | <pre>using OptoAlwaysWindow1 = Sequential&lt;Async&lt;Opto30Hz2Pin&lt;Laser, Laser3, 1500/33*2, 1500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseWaterAlways&gt;;</pre> | OptoAlwaysWindow1 是对应的总会给水版本。 |
| 392 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 393 | <pre>using HighToneOpto2 = Sequential&lt;Async&lt;HighTone500&gt;, OptoThetaGamma1&lt;Laser, Laser2&gt;, SingleThetaGamma1&lt;Laser&gt;&gt;;</pre> | HighToneOpto2 表示高音同时伴随 theta-gamma 型激光方案 2。 |
| 394 | <pre>using LowToneOpto2 = Sequential&lt;Async&lt;LowTone500&gt;, OptoThetaGamma1&lt;Laser, Laser2&gt;, SingleThetaGamma1&lt;Laser&gt;&gt;;</pre> | LowToneOpto2 表示低音同时伴随 theta-gamma 型激光方案 2。 |
| 395 | <pre>using OptoRightWindow2 = Sequential&lt;Async&lt;Repeat&lt;OptoThetaGamma1&lt;Laser, Laser3&gt;, ConstantInteger&lt;6&gt; &gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseRight&gt;;</pre> | OptoRightWindow2 在反应窗口前异步重复 6 次 theta-gamma 刺激，然后进入正确反应窗口。 |
| 396 | <pre>using OptoFalseWindow2 = Sequential&lt;Async&lt;Repeat&lt;OptoThetaGamma1&lt;Laser, Laser3&gt;, ConstantInteger&lt;6&gt; &gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseFalse&gt;;</pre> | OptoFalseWindow2 是方案 2 的错误拒绝版本。 |
| 397 | <pre>using OptoAlwaysWindow2 = Sequential&lt;Async&lt;Repeat&lt;OptoThetaGamma1&lt;Laser, Laser3&gt;, ConstantInteger&lt;6&gt; &gt;&gt;, DelayMilliseconds&lt;500&gt;, ResponseWaterAlways&gt;;</pre> | OptoAlwaysWindow2 是方案 2 的总会给水版本。 |
| 398 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 399 | <pre>using HighToneOpto31 = Sequential&lt;Async&lt;HighTone500&gt;, Opto30Hz2Pin&lt;Laser2, Laser4, 200/33*2, 200/33*2&gt;, Opto30Hz2Pin&lt;Laser, Laser4, 300/33*2, 300/33*2&gt;&gt;;</pre> | HighToneOpto31 把高音和 Laser2/Laser4 及 Laser/Laser4 的双路刺激绑定起来。 |
| 400 | <pre>using HighToneOpto32 = Sequential&lt;Async&lt;HighTone500&gt;, Opto30Hz3Pin&lt;Laser, Laser2, Laser4, 200/33*2, 200/33*2, 200/33*2&gt;, Opto30Hz2Pin&lt;Laser, Laser4, 300/33*2, 300/33*2&gt;&gt;;</pre> | HighToneOpto32 把高音和三路刺激版本绑定起来。 |
| 401 | <pre>using LowToneOpto31 = Sequential&lt;Async&lt;LowTone500&gt;, Opto30Hz2Pin&lt;Laser2, Laser4, 200/33*2, 200/33*2&gt;, Opto30Hz2Pin&lt;Laser, Laser4, 300/33*2, 300/33*2&gt;&gt;;</pre> | LowToneOpto31 是低音对应的双路刺激版本。 |
| 402 | <pre>using LowToneOpto32 = Sequential&lt;Async&lt;LowTone500&gt;, Opto30Hz3Pin&lt;Laser, Laser2, Laser4, 200/33*2, 200/33*2, 200/33*2&gt;, Opto30Hz2Pin&lt;Laser, Laser4, 300/33*2, 300/33*2&gt;&gt;;</pre> | LowToneOpto32 是低音对应的三路刺激版本。 |
| 403 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 404 | <pre>using TestGamma1=Sequential&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, OptoThetaGamma1&lt;Laser3, Laser2&gt;&gt;;</pre> | TestGamma1 只是把两段 Theta-Gamma 组合顺序执行，用于单独测试。 |
| 405 | <pre>using TestGamma1Trial = Trial&lt;UID::Trial_HLHWater, TestGamma1&gt;;</pre> | 将 TestGamma1 包成 Trial。 |
| 406 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 407 | <pre>using MultiOptoHLWater = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;, HighToneOpto1, LowToneOpto1, OptoRightWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHLWater 是方案 1 下的目标双音节试次。 |
| 408 | <pre>using MultiOptoHLWaterAlways = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;, HighToneOpto1, LowToneOpto1, OptoAlwaysWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHLWaterAlways 是方案 1 下总会给水的目标试次。 |
| 409 | <pre>using MultiOptoHHAir = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;, HighToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHHAir 是方案 1 下的高高干扰试次。 |
| 410 | <pre>using MultiOptoLHAir = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;, LowToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLHAir 是方案 1 下的低高干扰试次。 |
| 411 | <pre>using MultiOptoLLAir = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;, LowToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLLAir 是方案 1 下的低低干扰试次。 |
| 412 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 413 | <pre>using MultiOptoHLWater2 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, OptoRightWindow2, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHLWater2 是方案 2 下的目标双音节试次。 |
| 414 | <pre>using MultiOptoHLWaterAlways2 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, OptoAlwaysWindow2, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHLWaterAlways2 是方案 2 下总会给水的目标试次。 |
| 415 | <pre>using MultiOptoHHAir2 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHHAir2 是方案 2 下的高高干扰试次。 |
| 416 | <pre>using MultiOptoLHAir2 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLHAir2 是方案 2 下的低高干扰试次。 |
| 417 | <pre>using MultiOptoLLAir2 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLLAir2 是方案 2 下的低低干扰试次。 |
| 418 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 419 | <pre>using MultiOptoHLWater3 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser4, Laser2, 500/33*2, 500/33*2&gt;, HighToneOpto31, LowToneOpto32, OptoRightWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHLWater3 是方案 3 下更换引脚组合后的目标试次。 |
| 420 | <pre>using MultiOptoHLWaterAlways3 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser4, Laser2, 500/33*2, 500/33*2&gt;, HighToneOpto31, LowToneOpto32, OptoAlwaysWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHLWaterAlways3 是方案 3 下总会给水的目标试次。 |
| 421 | <pre>using MultiOptoHHAir3 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser4, Laser2, 500/33*2, 500/33*2&gt;, HighToneOpto31, HighToneOpto32, OptoFalseWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHHAir3 是方案 3 下的高高干扰试次。 |
| 422 | <pre>using MultiOptoLHAir3 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser4, Laser2, 500/33*2, 500/33*2&gt;, LowToneOpto31, HighToneOpto32, OptoFalseWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLHAir3 是方案 3 下的低高干扰试次。 |
| 423 | <pre>using MultiOptoLLAir3 = Sequential&lt;CalmDown1, Async&lt;DelayMilliseconds&lt;500&gt;&gt;, Opto30Hz2Pin&lt;Laser4, Laser2, 500/33*2, 500/33*2&gt;, LowToneOpto31, LowToneOpto32, OptoFalseWindow1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLLAir3 是方案 3 下的低低干扰试次。 |
| 424 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 425 | <pre>using MultiOptoHLWater4 = Sequential&lt;CalmDown1, LickBeginRight, HighToneOpto1, LowToneOpto1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHLWater4 不再用固定 500ms 等待，而是等待一次正确性舔水开始后再呈现双音节激光高低组合。 |
| 426 | <pre>using MultiOptoHHAir4 = Sequential&lt;CalmDown1, LickBeginFalse, HighToneOpto1, HighToneOpto1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoHHAir4 是等待一次错误型舔水开始后进入高高版本。 |
| 427 | <pre>using MultiOptoLHAir4 = Sequential&lt;CalmDown1, LickBeginFalse, LowToneOpto1, HighToneOpto1,  DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLHAir4 是等待一次错误型舔水开始后进入低高版本。 |
| 428 | <pre>using MultiOptoLLAir4 = Sequential&lt;CalmDown1, LickBeginFalse, LowToneOpto1, LowToneOpto1, DelayMilliseconds&lt;8000&gt;&gt;;</pre> | MultiOptoLLAir4 是等待一次错误型舔水开始后进入低低版本。 |
| 429 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 430 | <pre>using MultiOptoDoubleAudioTrialPre = Trial&lt;UID::Trial_MultiOptoHLWaterAlways, MultiOptoHLWaterAlways&gt;;</pre> | MultiOptoDoubleAudioTrialPre 用总会给水的目标试次作为预训练 trial。 |
| 431 | <pre>using MultiOptoDoubleAudioTrialPre2 = Trial&lt;UID::Trial_MultiOptoHLWaterAlways, MultiOptoHLWaterAlways2&gt;;</pre> | MultiOptoDoubleAudioTrialPre2 用方案 2 的总会给水目标试次做预训练。 |
| 432 | <pre>using MultiOptoDoubleAudioTrialPre3 = Trial&lt;UID::Trial_MultiOptoHLWaterAlways, MultiOptoHLWaterAlways3&gt;;</pre> | MultiOptoDoubleAudioTrialPre3 用方案 3 的总会给水目标试次做预训练。 |
| 433 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 434 | <pre>using MultiOptoDoubleAudioTrial0 = typename RandomSequential&lt;</pre> | 开始定义方案 1 的多光双音节随机试次集合。 |
| 435 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLWater, MultiOptoHLWater&gt;, </pre> | 第一项是目标试次 MultiOptoHLWater。 |
| 436 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHAir, MultiOptoHHAir&gt;,</pre> | 第二项是 HHAir 干扰。 |
| 437 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHAir, MultiOptoLHAir&gt;, </pre> | 第三项是 LHAir 干扰。 |
| 438 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLAir, MultiOptoLLAir&gt;</pre> | 第四项是 LLAir 干扰。 |
| 439 | <pre>                          &gt;::template WithRepeat&lt;3, 1, 1, 1&gt;;</pre> | 目标试次重复 3 次，其余各 1 次。 |
| 440 | <pre>using MultiOptoDoubleAudioTrial = Sequential&lt;MultiOptoDoubleAudioTrial0, ModuleRandomize&lt;MultiOptoDoubleAudioTrial0&gt;&gt;;</pre> | MultiOptoDoubleAudioTrial 在执行后重随机化集合顺序。 |
| 441 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 442 | <pre>using MultiOptoDoubleAudioTrial02 = typename RandomSequential&lt;</pre> | 开始定义方案 2 的多光双音节随机试次集合。 |
| 443 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLWater, MultiOptoHLWater2&gt;, </pre> | 第一项换成 MultiOptoHLWater2。 |
| 444 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHAir, MultiOptoHHAir2&gt;,</pre> | 第二项换成 MultiOptoHHAir2。 |
| 445 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHAir, MultiOptoLHAir2&gt;, </pre> | 第三项换成 MultiOptoLHAir2。 |
| 446 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLAir, MultiOptoLLAir2&gt;</pre> | 第四项换成 MultiOptoLLAir2。 |
| 447 | <pre>                          &gt;::template WithRepeat&lt;3, 1, 1, 1&gt;;</pre> | 重复次数仍保持 3,1,1,1。 |
| 448 | <pre>using MultiOptoDoubleAudioTrial2 = Sequential&lt;MultiOptoDoubleAudioTrial02, ModuleRandomize&lt;MultiOptoDoubleAudioTrial02&gt;&gt;;</pre> | MultiOptoDoubleAudioTrial2 在执行后重随机化。 |
| 449 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 450 | <pre>using MultiOptoDoubleAudioTrial03 = typename RandomSequential&lt;</pre> | 开始定义方案 3 的多光双音节随机试次集合。 |
| 451 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLWater, MultiOptoHLWater3&gt;, </pre> | 第一项换成 MultiOptoHLWater3。 |
| 452 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHAir, MultiOptoHHAir3&gt;,</pre> | 第二项换成 MultiOptoHHAir3。 |
| 453 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHAir, MultiOptoLHAir3&gt;, </pre> | 第三项换成 MultiOptoLHAir3。 |
| 454 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLAir, MultiOptoLLAir3&gt;</pre> | 第四项换成 MultiOptoLLAir3。 |
| 455 | <pre>                          &gt;::template WithRepeat&lt;3, 1, 1, 1&gt;;</pre> | 重复次数依旧是 3,1,1,1。 |
| 456 | <pre>using MultiOptoDoubleAudioTrial3 = Sequential&lt;MultiOptoDoubleAudioTrial03, ModuleRandomize&lt;MultiOptoDoubleAudioTrial03&gt;&gt;;</pre> | MultiOptoDoubleAudioTrial3 在执行后重随机化。 |
| 457 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 458 | <pre>using MultiOptoDoubleAudioTrial4 = Sequential&lt;</pre> | 开始定义一个手工拼接的分阶段双音节 session 序列。 |
| 459 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoHLWater, MultiOptoHLWaterAlways&gt;, ConstantInteger&lt;7&gt;&gt;,</pre> | 先连做 7 次总会给水的目标试次。 |
| 460 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoHHAir, MultiOptoHHAir&gt;, ConstantInteger&lt;3&gt;&gt;,</pre> | 再做 3 次 HHAir。 |
| 461 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoHLWater, MultiOptoHLWaterAlways&gt;, ConstantInteger&lt;7&gt;&gt;,</pre> | 再回到 7 次目标试次。 |
| 462 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoLHAir, MultiOptoLHAir&gt;, ConstantInteger&lt;3&gt;&gt;,</pre> | 再做 3 次 LHAir。 |
| 463 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoHLWater, MultiOptoHLWaterAlways&gt;, ConstantInteger&lt;7&gt;&gt;, </pre> | 再来 7 次目标试次。 |
| 464 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoLLAir, MultiOptoLLAir&gt;, ConstantInteger&lt;3&gt;&gt;&gt;;</pre> | 最后做 3 次 LLAir 并结束该手工序列。 |
| 465 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 466 | <pre>using MultiOptoDoubleAudioTrial041 = typename RandomSequential&lt;</pre> | 开始定义只包含目标试次 4 版本的随机集合。 |
| 467 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLWater, MultiOptoHLWater4&gt;</pre> | 集合中唯一的 trial 是 MultiOptoHLWater4。 |
| 468 | <pre>                          &gt;::template WithRepeat&lt;6&gt;;</pre> | 把它重复 6 次。 |
| 469 | <pre>using MultiOptoDoubleAudioTrial41 = Sequential&lt;MultiOptoDoubleAudioTrial041&gt;;</pre> | MultiOptoDoubleAudioTrial41 只是顺序执行这组 6 次目标试次。 |
| 470 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 471 | <pre>using MultiOptoDoubleAudioTrial42 = Sequential&lt;</pre> | 开始定义 MultiOptoDoubleAudioTrial42。 |
| 472 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoHHAir, MultiOptoHHAir4&gt;, ConstantInteger&lt;2&gt;&gt;,</pre> | 先做 2 次 HHAir4。 |
| 473 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoLHAir, MultiOptoLHAir4&gt;, ConstantInteger&lt;2&gt;&gt;,</pre> | 再做 2 次 LHAir4。 |
| 474 | <pre>                          Repeat&lt;Trial&lt;UID::Trial_MultiOptoLLAir, MultiOptoLLAir4&gt;, ConstantInteger&lt;2&gt;&gt;&gt;;</pre> | 最后做 2 次 LLAir4。 |
| 475 | <pre>//ModuleRandomize&lt;MultiOptoDoubleAudioTrial04&gt;&gt;;</pre> | 这行注释掉了原本可能想加入的随机化调用。 |
| 476 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 477 | <pre>using LaserOnlyTrial = Sequential&lt; AssociationSessionTimes&lt;MultiOptoDoubleAudioTrialPre2, 12&gt;, AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial, 1&gt; &gt;;</pre> | LaserOnlyTrial 先执行 12 次预训练 trial，再执行 1 次正式双音节随机任务。 |
| 478 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 479 | <pre>/*triple*/</pre> | 注释说明下面进入三音节任务。 |
| 480 | <pre>using HLHWater = Sequential&lt;DelayMilliseconds&lt;2000&gt;, HighTone500, LowTone500, HighTone500, DelayMilliseconds&lt;500&gt;, ResponseRight, DelayMilliseconds&lt;7000&gt;&gt;;</pre> | HLHWater 定义了高-低-高三音节目标试次，随后进入正确反应窗口。 |
| 481 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 482 | <pre>using TripleAudioTrialPre = Trial&lt;UID::Trial_HLHWater, HLHWater&gt;;</pre> | 把 HLHWater 封装成预训练用的 Trial。 |
| 483 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 484 | <pre>/*triple MultiOpto*/</pre> | 注释说明下面进入三音节多光刺激版本。 |
| 485 | <pre>using MultiOptoHLHWater = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;,  HighToneOpto1, LowToneOpto1, HighToneOpto1, OptoRightWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLHWater 是方案 1 下的高低高目标试次。 |
| 486 | <pre>using MultiOptoHLLAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, HighToneOpto1, LowToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLLAir 是高低低干扰试次。 |
| 487 | <pre>using MultiOptoHHLAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, HighToneOpto1, HighToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHLAir 是高高低干扰试次。 |
| 488 | <pre>using MultiOptoHHHAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, HighToneOpto1, HighToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHHAir 是高高高干扰试次。 |
| 489 | <pre>using MultiOptoLLHAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, LowToneOpto1, LowToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLHAir 是低低高干扰试次。 |
| 490 | <pre>using MultiOptoLLLAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, LowToneOpto1, LowToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLLAir 是低低低干扰试次。 |
| 491 | <pre>using MultiOptoLHLAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, LowToneOpto1, HighToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHLAir 是低高低干扰试次。 |
| 492 | <pre>using MultiOptoLHHAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, LowToneOpto1, HighToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHHAir 是低高高干扰试次。 |
| 493 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 494 | <pre>using MultiOptoHLHWater2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoRightWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLHWater2 是方案 2 下的高低高目标试次。 |
| 495 | <pre>using MultiOptoHLLAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLLAir2 是方案 2 下的高低低干扰试次。 |
| 496 | <pre>using MultiOptoHHLAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHLAir2 是方案 2 下的高高低干扰试次。 |
| 497 | <pre>using MultiOptoHHHAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHHAir2 是方案 2 下的高高高干扰试次。 |
| 498 | <pre>using MultiOptoLLHAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLHAir2 是方案 2 下的低低高干扰试次。 |
| 499 | <pre>using MultiOptoLLLAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLLAir2 是方案 2 下的低低低干扰试次。 |
| 500 | <pre>using MultiOptoLHLAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHLAir2 是方案 2 下的低高低干扰试次。 |
| 501 | <pre>using MultiOptoLHHAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHHAir2 是方案 2 下的低高高干扰试次。 |
| 502 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 503 | <pre>using MultiOptoLHLWater2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoRightWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHLWater2 是方案 2 下的低高低目标试次，说明目标模式在这一版本里被换成了 LHL。 |
| 504 | <pre>using MultiOptoHLHAir2 = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLHAir2 是方案 2 下的高低高干扰试次，与上行形成目标/干扰对调。 |
| 505 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 506 | <pre>using MultiOptoLHLWater = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, LowToneOpto1, HighToneOpto1, LowToneOpto1, OptoRightWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHLWater 是方案 1 下的低高低目标试次。 |
| 507 | <pre>using MultiOptoHLHAir = Sequential&lt;CalmDown1, Async&lt;Opto30Hz2Pin&lt;Laser, Laser2, 500/33*2, 500/33*2&gt;&gt;, DelayMilliseconds&lt;500&gt;, HighToneOpto1, LowToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLHAir 是方案 1 下的高低高干扰试次。 |
| 508 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 509 | <pre>using MultiOptoTripleAudioTrialPre = Trial&lt;UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater&gt;;</pre> | 把 MultiOptoLHLWater 封装成三音节预训练 Trial。 |
| 510 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 511 | <pre>using MultiOptoTripleAudioTrial0 = typename RandomSequential&lt;</pre> | 开始定义方案 1 的三音节随机试次集合。 |
| 512 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater&gt;, </pre> | 第一项是目标试次 MultiOptoLHLWater。 |
| 513 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHHAir, MultiOptoHHHAir&gt;,</pre> | 第二项是 HHH 干扰。 |
| 514 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHHAir, MultiOptoLHHAir&gt;, </pre> | 第三项是 LHH 干扰。 |
| 515 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLHAir, MultiOptoLLHAir&gt;,</pre> | 第四项是 LLH 干扰。 |
| 516 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLLAir, MultiOptoHLLAir&gt;, </pre> | 第五项是 HLL 干扰。 |
| 517 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHLAir, MultiOptoHHLAir&gt;,</pre> | 第六项是 HHL 干扰。 |
| 518 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLHAir, MultiOptoHLHAir&gt;, </pre> | 第七项是 HLH 干扰。 |
| 519 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLLAir, MultiOptoLLLAir&gt;</pre> | 第八项是 LLL 干扰。 |
| 520 | <pre>                          &gt;::template WithRepeat&lt;7, 1, 1, 1, 1, 1, 1, 1&gt;;</pre> | 规定目标试次 7 次，其余每类 1 次。 |
| 521 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 522 | <pre>using MultiOptoTripleAudioTrial = Sequential&lt;MultiOptoTripleAudioTrial0, ModuleRandomize&lt;MultiOptoTripleAudioTrial0&gt;&gt;;</pre> | MultiOptoTripleAudioTrial 执行完后重随机化顺序。 |
| 523 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 524 | <pre>using MultiOptoTripleAudioTrialPre2 = Trial&lt;UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater2&gt;;</pre> | 把方案 2 下的目标试次 MultiOptoLHLWater2 封装成预训练 Trial。 |
| 525 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 526 | <pre>using MultiOptoTripleAudioTrial01 = typename RandomSequential&lt;</pre> | 开始定义方案 2 的三音节随机试次集合。 |
| 527 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater2&gt;, </pre> | 第一项是目标试次 MultiOptoLHLWater2。 |
| 528 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHHAir, MultiOptoHHHAir2&gt;,</pre> | 第二项是 HHH 干扰方案 2。 |
| 529 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHHAir, MultiOptoLHHAir2&gt;, </pre> | 第三项是 LHH 干扰方案 2。 |
| 530 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLHAir, MultiOptoLLHAir2&gt;,</pre> | 第四项是 LLH 干扰方案 2。 |
| 531 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLLAir, MultiOptoHLLAir2&gt;, </pre> | 第五项是 HLL 干扰方案 2。 |
| 532 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHLAir, MultiOptoHHLAir2&gt;,</pre> | 第六项是 HHL 干扰方案 2。 |
| 533 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLHAir, MultiOptoHLHAir2&gt;, </pre> | 第七项是 HLH 干扰方案 2。 |
| 534 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLLAir, MultiOptoLLLAir2&gt;</pre> | 第八项是 LLL 干扰方案 2。 |
| 535 | <pre>                          &gt;::template WithRepeat&lt;7, 1, 1, 1, 1, 1, 1, 1&gt;;</pre> | 重复次数仍是 7,1,1,1,1,1,1,1。 |
| 536 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 537 | <pre>using MultiOptoTripleAudioTrial2 = Sequential&lt;MultiOptoTripleAudioTrial01, ModuleRandomize&lt;MultiOptoTripleAudioTrial01&gt;&gt;;</pre> | MultiOptoTripleAudioTrial2 执行完后重随机化顺序。 |
| 538 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 539 | <pre>/*Quadruple*/</pre> | 注释说明下面进入四音节任务。 |
| 540 | <pre>using HLHLWater = Sequential&lt;DelayMilliseconds&lt;2000&gt;, HighTone500, LowTone500, HighTone500, LowTone500, DelayMilliseconds&lt;500&gt;, ResponseRight, DelayMilliseconds&lt;7000&gt;&gt;;</pre> | HLHLWater 定义高低高低四音节目标试次。 |
| 541 | <pre>using QuadrupleAudioTrialPre = Trial&lt;UID::Trial_HLHLWater, HLHLWater&gt;;</pre> | 把 HLHLWater 包装成预训练 Trial。 |
| 542 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 543 | <pre>/*Quadruple MultiOpto*/</pre> | 注释说明下面进入四音节多光刺激版本。 |
| 544 | <pre>using MultiOptoHLHLWater = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoRightWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLHLWater 是方案 2 下的四音节目标试次。 |
| 545 | <pre>using MultiOptoHLLLAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLLLAir 是高低低低干扰。 |
| 546 | <pre>using MultiOptoHHLLAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, HighToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHLLAir 是高高低低干扰。 |
| 547 | <pre>using MultiOptoHHHLAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, HighToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHHLAir 是高高高低干扰。 |
| 548 | <pre>using MultiOptoLLHLAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLHLAir 是低低高低干扰。 |
| 549 | <pre>using MultiOptoLLLLAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, LowToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLLLAir 是低低低低干扰。 |
| 550 | <pre>using MultiOptoLHLLAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHLLAir 是低高低低干扰。 |
| 551 | <pre>using MultiOptoLHHLAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHHLAir 是低高高低干扰。 |
| 552 | <pre>using MultiOptoHLHHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLHHAir 是高低高高干扰。 |
| 553 | <pre>using MultiOptoHLLHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLLHAir 是高低低高干扰。 |
| 554 | <pre>using MultiOptoHHLHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHLHAir 是高高低高干扰。 |
| 555 | <pre>using MultiOptoHHHHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, HighToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHHHHAir 是高高高高干扰。 |
| 556 | <pre>using MultiOptoLLHHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, LowToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLHHAir 是低低高高干扰。 |
| 557 | <pre>using MultiOptoLLLHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, LowToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLLLHAir 是低低低高干扰。 |
| 558 | <pre>using MultiOptoLHLHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHLHAir 是低高低高干扰。 |
| 559 | <pre>using MultiOptoLHHHAir = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, LowToneOpto2, HighToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoLHHHAir 是低高高高干扰。 |
| 560 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 561 | <pre>using MultiOptoHLHLWaterAlways = Sequential&lt;CalmDown1, Repeat&lt;OptoThetaGamma1&lt;Laser, Laser2&gt;, ConstantInteger&lt;2&gt;&gt;, HighToneOpto2, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoAlwaysWindow2, DelayMilliseconds&lt;3000&gt;&gt;;</pre> | MultiOptoHLHLWaterAlways 是四音节目标试次的总会给水预训练版本。 |
| 562 | <pre>using MultiOptoQuadrupleAudioTrialPre = Trial&lt;UID::Trial_MultiOptoHLHLWaterAlways, MultiOptoHLHLWaterAlways&gt;;</pre> | 把它封装成预训练 Trial。 |
| 563 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 564 | <pre>using MultiOptoQuadrupleAudioTrialP1 = typename RandomSequential&lt;</pre> | 开始定义四音节随机试次集合 P1。 |
| 565 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLHLWater, MultiOptoHLHLWater&gt;,  </pre> | P1 第一项是目标试次 HLHLWater。 |
| 566 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHLLAir, MultiOptoHHLLAir&gt;,</pre> | P1 第二项是 HHLLAir。 |
| 567 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHLLAir, MultiOptoLHLLAir&gt;, </pre> | P1 第三项是 LHLLAir。 |
| 568 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLLLAir, MultiOptoLLLLAir&gt;,</pre> | P1 第四项是 LLLLAir。 |
| 569 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLHHAir, MultiOptoHLHHAir&gt;, </pre> | P1 第五项是 HLHHAir。 |
| 570 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHHHAir, MultiOptoHHHHAir&gt;</pre> | P1 第六项是 HHHHAir。 |
| 571 | <pre>                          &gt;::template WithRepeat&lt;5, 1, 1, 1, 1, 1&gt;;</pre> | P1 中目标重复 5 次，其余各 1 次。 |
| 572 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 573 | <pre>using MultiOptoQuadrupleAudioTrialP2 = typename RandomSequential&lt;</pre> | 开始定义四音节随机试次集合 P2。 |
| 574 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLHLWater, MultiOptoHLHLWater&gt;, </pre> | P2 第一项仍是目标试次 HLHLWater。 |
| 575 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLHLAir, MultiOptoLLHLAir&gt;,</pre> | P2 第二项是 LLHLAir。 |
| 576 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLLLAir, MultiOptoHLLLAir&gt;, </pre> | P2 第三项是 HLLLAir。 |
| 577 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHHHAir, MultiOptoLHHHAir&gt;, </pre> | P2 第四项是 LHHHAir。 |
| 578 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLHHAir, MultiOptoLLHHAir&gt;,</pre> | P2 第五项是 LLHHAir。 |
| 579 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLLHAir, MultiOptoHLLHAir&gt;</pre> | P2 第六项是 HLLHAir。 |
| 580 | <pre>                          &gt;::template WithRepeat&lt;5, 1, 1, 1, 1, 1&gt;;</pre> | P2 中目标重复 5 次，其余各 1 次。 |
| 581 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 582 | <pre>using MultiOptoQuadrupleAudioTrialP3 = typename RandomSequential&lt;</pre> | 开始定义四音节随机试次集合 P3。 |
| 583 | <pre>                          Trial&lt;UID::Trial_MultiOptoHLHLWater, MultiOptoHLHLWater&gt;, </pre> | P3 第一项仍是目标试次 HLHLWater。 |
| 584 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHHLAir, MultiOptoHHHLAir&gt;,</pre> | P3 第二项是 HHHLAir。 |
| 585 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHHLAir, MultiOptoLHHLAir&gt;,  </pre> | P3 第三项是 LHHLAir。 |
| 586 | <pre>                          Trial&lt;UID::Trial_MultiOptoHHLHAir, MultiOptoHHLHAir&gt;,</pre> | P3 第四项是 HHLHAir。 |
| 587 | <pre>                          Trial&lt;UID::Trial_MultiOptoLHLHAir, MultiOptoLHLHAir&gt;, </pre> | P3 第五项是 LHLHAir。 |
| 588 | <pre>                          Trial&lt;UID::Trial_MultiOptoLLLHAir, MultiOptoLLLHAir&gt;</pre> | P3 第六项是 LLLHAir。 |
| 589 | <pre>                          &gt;::template WithRepeat&lt;5, 1, 1, 1, 1, 1&gt;;</pre> | P3 中目标重复 5 次，其余各 1 次。 |
| 590 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 591 | <pre>using MultiOptoQuadrupleAudioTrial0 = typename RandomSequential&lt;MultiOptoQuadrupleAudioTrialP1, </pre> | 开始把 P1、P2、P3 三个子集合再随机穿插一次。 |
| 592 | <pre>                                                               MultiOptoQuadrupleAudioTrialP2, </pre> | 第二个子集合是 P2。 |
| 593 | <pre>                                                               MultiOptoQuadrupleAudioTrialP3</pre> | 第三个子集合是 P3。 |
| 594 | <pre>                                                               &gt;::template WithRepeat&lt;1, 1, 1&gt;;</pre> | 三个子集合各执行 1 次。 |
| 595 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 596 | <pre>using MultiOptoQuadrupleAudioTrial = Sequential&lt;MultiOptoQuadrupleAudioTrial0, ModuleRandomize&lt;MultiOptoQuadrupleAudioTrial0&gt;&gt;;</pre> | MultiOptoQuadrupleAudioTrial 在整个大集合执行后重随机化顺序。 |
| 597 | <pre>&nbsp;</pre> | 空行，分隔上下一段定义。 |
| 598 | <pre>// ——以下列出所有公开模块，均绑定到ID，允许PC端调用——</pre> | 注释说明下面这张表是所有暴露给 PC 端的公开 session 入口。 |
| 599 | <pre>std::unordered_map&lt;UID, uint16_t (*)(Process *)&gt; SessionMap = {</pre> | 定义 SessionMap，把 UID 映射到具体 Session 工厂函数。 |
| 600 | <pre>  { UID::Test_BlueLed, Session&lt;PinFlash&lt;BlueLed, 200&gt;&gt; },</pre> | Test_BlueLed 会闪一下蓝灯 200ms。 |
| 601 | <pre>  { UID::Test_WaterPump, Session&lt;PinFlash&lt;WaterPump, 150&gt;&gt; },</pre> | Test_WaterPump 会打开水泵 150ms。 |
| 602 | <pre>  { UID::Test_CapacitorReset, Session&lt;Sequential&lt;DigitalWrite&lt;CapacitorVdd, LOW&gt;, DelayMilliseconds&lt;100&gt;, DigitalWrite&lt;CapacitorVdd, HIGH&gt;&gt;&gt; },</pre> | Test_CapacitorReset 会先断电电容 100ms 再重新上电。 |
| 603 | <pre>  { UID::Test_CapacitorMonitor, Session&lt;Sequential&lt;DigitalWrite&lt;CapacitorVdd, HIGH&gt;, MonitorPin&lt;CapacitorOut, SerialMessage&lt;UID::Event_MonitorHit&gt;&gt;&gt;&gt; },</pre> | Test_CapacitorMonitor 会持续监听 CapacitorOut 并把命中事件发到 PC。 |
| 604 | <pre>  { UID::Test_CD1, Session&lt;PinFlash&lt;CD1, 200&gt;&gt; },</pre> | Test_CD1 会闪一下 CD1 引脚。 |
| 605 | <pre>  { UID::Test_ActiveBuzzer, Session&lt;PinFlash&lt;ActiveBuzzer, 200&gt;&gt; },</pre> | Test_ActiveBuzzer 会短暂触发主动蜂鸣器。 |
| 606 | <pre>  { UID::Test_AirPump, Session&lt;PinFlash&lt;AirPump, 200&gt;&gt; },</pre> | Test_AirPump 会短暂触发气泵。 |
| 607 | <pre>  { UID::Test_Optogenetic, Session&lt;PinFlash&lt;Laser, 200&gt;&gt; },</pre> | Test_Optogenetic 会闪一下主激光引脚。 |
| 608 | <pre>  { UID::Test_HostAction, Session&lt;SerialMessage&lt;UID::Host_GratingImage&gt;&gt; },</pre> | Test_HostAction 会向上位机发送 Host_GratingImage 指令。 |
| 609 | <pre>  { UID::Test_SquareWave, Session&lt;DoubleRepeat&lt;DigitalWrite&lt;Laser, HIGH&gt;, DigitalWrite&lt;Laser, LOW&gt;, std::chrono::seconds, ConstantInteger&lt;1&gt;, ConstantInteger&lt;2&gt;, ConstantInteger&lt;6&gt;&gt;&gt; },  // 注意是6次变灯，不是6个周期</pre> | Test_SquareWave 会输出一个低频方波序列，注释额外提醒 6 指的是变灯次数而非周期数。 |
| 610 | <pre>  { UID::Test_RandomFlash, Session&lt;Sequential&lt;Async&lt;RandomFlash&gt;, DelaySeconds&lt;10&gt;, ModuleAbort&lt;RandomFlash&gt;&gt;&gt; },</pre> | Test_RandomFlash 会异步开始随机闪烁，持续 10 秒后中止。 |
| 611 | <pre>  { UID::Test_LowTone, Session&lt;Tone&lt;6000, 500&gt;&gt; },</pre> | Test_LowTone 会播放一个 6000Hz、500ms 的音调。 |
| 612 | <pre>  { UID::Test_HighTone, Session&lt;Tone&lt;14000, 500&gt;&gt; },</pre> | Test_HighTone 会播放一个 14000Hz、500ms 的音调。 |
| 613 | <pre>  /*{ UID::Session_Shaping, Session&lt;AssociationSessionTimes&lt;Trial&lt;UID::Trial_Shaping, Sequential&lt;DelayMilliseconds&lt;2500&gt;, OptoRightWindow2&gt;&gt;, 100&gt;&gt; },</pre> | 这一行起始了一个被整体注释掉的历史 session 集合。 |
| 614 | <pre>  { UID::Session_AudioWater, Session&lt;AssociationSession&lt;Trial&lt;UID::Trial_AudioWater, AssociationTrial&lt;ActiveBuzzer, UID::Event_AudioUp, UID::Event_AudioDown&gt;&gt;&gt;&gt; },</pre> | 历史注释中保留了音水关联 session 的写法。 |
| 615 | <pre>  { UID::Session_LightWater, Session&lt;AssociationSession&lt;Trial&lt;UID::Trial_LightWater, AssociationTrial&lt;BlueLed, UID::Event_LightUp, UID::Event_LightDown&gt;&gt;&gt;&gt; },</pre> | 历史注释中保留了光水关联 session 的写法。 |
| 616 | <pre>  { UID::Session_LAuW, Session&lt;Sequential&lt;DigitalWrite&lt;CapacShapingitorVdd, HIGH&gt;, RandomSequential&lt;</pre> | 历史注释中开始保留一个 LAuW session 的旧定义。 |
| 617 | <pre>                                                                              Trial&lt;UID::Trial_LightOnly, CueOnlyTrial&lt;PinFlashUpDown&lt;BlueLed, 200, UID::Event_LightUp, UID::Event_LightDown&gt;&gt;&gt;,</pre> | 旧定义里列出 LightOnly trial。 |
| 618 | <pre>                                                                              Trial&lt;UID::Trial_AudioOnly, CueOnlyTrial&lt;PinFlashUpDown&lt;ActiveBuzzer, 200, UID::Event_AudioUp, UID::Event_AudioDown&gt;&gt;&gt;,</pre> | 旧定义里列出 AudioOnly trial。 |
| 619 | <pre>                                                                              Trial&lt;UID::Trial_WaterOnly, CueOnlyTrial&lt;PinFlashUp&lt;WaterPump, 150, UID::Event_Water&gt;&gt;&gt;&gt;::WithRepeat&lt;20, 20, 20&gt;&gt;&gt; },</pre> | 旧定义里列出 WaterOnly trial，并结束这段旧 session。 |
| 620 | <pre>  { UID::Session_SingleAudioShaping, Session&lt;A3FixedSession&lt;HighWaterAlwaysTrial, 100, HighWaterTrial, 1&gt;&gt; },</pre> | 旧定义里保留了单音 shaping session。 |
| 621 | <pre>  { UID::Session_OptoSingleAudioTask, Session&lt;Sequential&lt; AssociationSessionTimes&lt;OptoSingleAudioTrial, 25&gt;&gt;&gt; },</pre> | 旧定义里保留了单音光刺激 task。 |
| 622 | <pre>  { UID::Session_MultiOptoSingleAudioTask, Session&lt;Sequential&lt; AssociationSessionTimes&lt;MultiOptoSingleAudioTrial, 25&gt;&gt;&gt; },</pre> | 旧定义里保留了多引脚单音光刺激 task。 |
| 623 | <pre>  { UID::Session_DoubleAudioShaping, Session&lt;A3FixedSession&lt;HLWaterAlwaysTrial, 5, HLWaterTrial, 25&gt;&gt; },*/</pre> | 旧定义里保留了双音 shaping task，并结束这一大段注释。 |
| 624 | <pre>  { UID::Session_DoubleAudioRecon, Session&lt;Sequential&lt;AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial4, 1&gt;, </pre> | Session_DoubleAudioRecon 的第一段是 1 次手工序列 MultiOptoDoubleAudioTrial4。 |
| 625 | <pre>                                                      AssociationSessionTimes&lt;MultiOptoDoubleAudioTrialPre, 6&gt;&gt;&gt; },</pre> | 随后追加 6 次 MultiOptoDoubleAudioTrialPre 预训练。 |
| 626 | <pre>  { UID::Session_MultiOptoDoubleAudioTask, Session&lt;Sequential&lt;SerialMessage&lt;UID::Event_Pulse5&gt;,</pre> | Session_MultiOptoDoubleAudioTask 开头先发送 Event_Pulse5，用作上位机侧标记或同步。 |
| 627 | <pre>                                                              AssociationSessionTimes&lt;MultiOptoDoubleAudioTrialPre, 5&gt;, </pre> | 然后做 5 次 MultiOptoDoubleAudioTrialPre 预训练。 |
| 628 | <pre>                                                              AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial, 20&gt;&gt;&gt; },</pre> | 最后做 20 次正式的 MultiOptoDoubleAudioTrial。 |
| 629 | <pre>  /*{ UID::Session_MultiOptoDoubleAudioTask2, Session&lt;Sequential&lt;SerialMessage&lt;UID::Event_LickBegin&gt;,</pre> | 这一行开始了另一套被注释掉的双音任务变体。 |
| 630 | <pre>                                                                SerialMessage&lt;UID::Event_Pulse5&gt;,</pre> | 注释变体里还会发送 LickBegin 与 Pulse5 标记。 |
| 631 | <pre>                                                                AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial, 2&gt;,</pre> | 注释变体里先做 2 次正式双音任务。 |
| 632 | <pre>                                                                AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial4, 1&gt;, </pre> | 然后插入 1 次 MultiOptoDoubleAudioTrial4。 |
| 633 | <pre>                                                                AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial, 5&gt;,</pre> | 接着再做 5 次正式双音任务。 |
| 634 | <pre>                                                                AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial41, 1&gt;, </pre> | 然后插入 1 次 MultiOptoDoubleAudioTrial41。 |
| 635 | <pre>                                                                AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial, 4&gt;,</pre> | 接着再做 4 次正式双音任务。 |
| 636 | <pre>                                                                AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial, 5&gt; &gt;&gt; },*/</pre> | 最后再做 5 次正式双音任务并结束这段注释。 |
| 637 | <pre>  /*{ UID::Session_MultiOptoDoubleAudioTask3, Session&lt;Sequential&lt;AssociationSessionTimes&lt;MultiOptoDoubleAudioTrialPre2, 5&gt;, </pre> | 这一行开始另一大段被注释掉的历史多光双音/三音/四音 session。 |
| 638 | <pre>                                                              AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial2, 20&gt;,</pre> | 注释中先给出 Pre2 与正式 Trial2 交替的双音版本。 |
| 639 | <pre>                                                              AssociationSessionTimes&lt;MultiOptoDoubleAudioTrialPre2, 5&gt;, </pre> | 然后再次插入 Pre2。 |
| 640 | <pre>                                                              AssociationSessionTimes&lt;MultiOptoDoubleAudioTrial2, 20&gt;&gt;&gt; },</pre> | 最后再跑一轮 Trial2，并结束这个 session 片段。 |
| 641 | <pre>  { UID::Session_LaserOnly, Session&lt;Sequential&lt; AssociationSessionTimes&lt;MultiOptoDoubleAudioTrialPre, 5&gt;, AssociationSessionTimes&lt;LaserOnlyTrial, 3&gt; &gt;&gt; },</pre> | 注释里保留了 LaserOnly session 的旧入口。 |
| 642 | <pre>  /*{ UID::Session_DoubleAudioTask, Session&lt;Sequential&lt; AssociationSessionTimes&lt;DoubleAudioTrial, 20&gt;&gt;&gt; },</pre> | 注释里保留了纯双音任务入口。 |
| 643 | <pre>  { UID::Session_MultiOptoTripeAudioTask, Session&lt;Sequential&lt;AssociationSessionTimes&lt;MultiOptoTripleAudioTrialPre2, 20&gt;, </pre> | 注释里保留了三音任务入口 1。 |
| 644 | <pre>                                                             AssociationSessionTimes&lt;MultiOptoTripleAudioTrial, 10&gt;&gt;&gt; },</pre> | 该入口先做三音预训练再做正式三音任务。 |
| 645 | <pre>  { UID::Session_MultiOptoTripeAudioTask2, Session&lt;Sequential&lt;AssociationSessionTimes&lt;MultiOptoTripleAudioTrialPre2, 5&gt;, </pre> | 注释里保留了三音任务入口 2。 |
| 646 | <pre>                                                             AssociationSessionTimes&lt;MultiOptoTripleAudioTrial2, 10&gt;&gt;&gt; },</pre> | 该入口先短预训练再做正式三音任务 2。 |
| 647 | <pre>  { UID::Session_MultiOptoTripeAudioTask3, Session&lt;Sequential&lt;AssociationSessionTimes&lt;MultiOptoTripleAudioTrial2, 10&gt;&gt;&gt; },*/</pre> | 注释里保留了只跑正式三音任务 2 的入口，并结束这段注释。 |
| 648 | <pre>  /*{ UID::Session_QuadrupleAudioShaping, Session&lt;AssociationSessionTimes&lt;QuadrupleAudioTrialPre, 100&gt;&gt; },</pre> | 注释里保留了四音 shaping 入口。 |
| 649 | <pre>  { UID::Session_MultiOptoQuadrupleAudioTask, Session&lt;Sequential&lt;AssociationSessionTimes&lt;MultiOptoQuadrupleAudioTrialPre, 20&gt;, </pre> | 注释里保留了四音多光任务入口。 |
| 650 | <pre>                                                             AssociationSessionTimes&lt;MultiOptoQuadrupleAudioTrial, 5&gt;&gt;&gt; },*/</pre> | 该入口先做四音预训练再做正式四音任务，并结束这段注释。 |
| 651 | <pre>  /*{ UID::Session_MultiOptoQuadrupleAudioTask2, Session&lt;Sequential&lt;AssociationSessionTimes&lt;MultiOptoQuadrupleAudioTrialPre, 5&gt;, </pre> | 注释里保留了另一个四音任务入口。 |
| 652 | <pre>                                                             AssociationSessionTimes&lt;MultiOptoQuadrupleAudioTrial, 5&gt;&gt;&gt; },*/</pre> | 该入口是更短的四音预训练加正式任务组合，并结束这段注释。 |
| 653 | <pre>};</pre> | 结束 SessionMap 初始化。 |

