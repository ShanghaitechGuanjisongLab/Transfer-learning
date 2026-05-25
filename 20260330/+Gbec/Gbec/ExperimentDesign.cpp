#pragma once
#include "Predefined.hpp"
// 快速切换BOX设定集
#define BOX 2

// 引脚设定集，你可以为每套设备创建一个#if BOX块，记录不同设备的不同引脚信息，然后通过设定BOX宏进行快速切换。
#if BOX == 1
Pin BlueLed = 11;
Pin WaterPump = 2;
Pin CapacitorVdd = 7;
Pin CapacitorOut = 18;
Pin CD1 = 10;
Pin ActiveBuzzer = 52;
Pin AirPump = 8;
Pin PassiveBuzzer = 12;
Pin Laser = 29;
Pin Laser2 = 98;
Pin Laser3 = 99;
#endif
#if BOX == 2
Pin BlueLed = 8;
Pin WaterPump = 2;
Pin CapacitorVdd = 7;
Pin CapacitorOut = 18;
Pin CD1 = 6;
Pin ActiveBuzzer = 22;
Pin AirPump = 12;
Pin Laser = 51;
Pin Laser2 = 34;
Pin Laser3 = 40;
Pin Laser4 = 46;
Pin PassiveBuzzer = 3;
#endif
#if BOX == 3
Pin BlueLed = 4;
Pin WaterPump = 2;
Pin CapacitorVdd = 6;
Pin CapacitorOut = 18;
Pin CD1 = 6;
Pin ActiveBuzzer = 3;
Pin AirPump = 12;
Pin Laser = 7;
Pin Laser2 = 98;
Pin Laser3 = 99;
Pin PassiveBuzzer = 32;
#endif

/* 可以将基础模块using组合成自定义的复杂模块，可以是有参数的模板或无参数的实例。语法中的参数前缀提示参数类型，使用时不用写。例如DurationRep前缀表示模板参数是uint32_t类型，typename前缀表示参数是其它模块或类型等。基础模块介绍如下：
————————————
# 整数类模块
————————————
整数类模块自身不能执行，只能为其它模块的整数参数提供值，可以是常数或随机数。

## ConstantInteger<DurationRep Value>
表示一个常数整数。例如ConstantInteger<1000>表示常数1000

## RandomInteger<DurationRep Min, DurationRep Max, UID CustomID = UID::Module_RandomInteger>
表示一个最小Min（含）最大Max（含）的随机整数，还可以额外指定一个ID用于区分不同的实例。此模块在进程创建时提供一个随机初始值，那之后便不会再自动重新随机化，必须对其使用ModuleRandomize以更新随机数，否则每次使用时都会取到相同的值。
————————————
# 延时类模块
————————————
延时类模块的执行通常需要消耗一段可观的时间才能结束。

## Delay
等待一定延迟时间。支持多种语法：
- Delay<typename Unit, typename Value>，需要输入等待时间的单位和值，例如Delay<std::chrono::seconds,RandomInteger<5,10>>表示随机等待5~10秒
- Delay<>，无限等待。出于可读性考虑，还可以写成Delay<Infinite>。
允许的Unit包括 std::chrono::microseconds std::chrono::milliseconds std::chrono::seconds std::chrono::minutes std::chrono::hours，允许的Value只能是ConstantInteger或RandomInteger。

## RepeatEvery<typename Content, typename Unit, typename Period, typename Times = Infinite>
每隔一段时间就重复执行模块，第一次重复也需要先等待时间。此模块可用于生成音调。参数说明：
Content，要执行的内容模块。Content本身异步执行，不会占用重复周期。如果Content执行时间比重复周期还长，就会每到重复周期就自动重启，不会拖慢重复周期。
Unit，重复周期的时间单位
Period，重复周期的时间值，可以是ConstantInteger或RandomInteger。如果指定RandomInteger，只会在此模块每次开始时取一次值；重复Content的过程中，再重新随机化RandomInteger，也不会再改变重复周期，因此不能用此模块实现每次重复随机间隔，只能用Delay和Repeat组合实现。
Times，重复次数，可以是ConstantInteger或RandomInteger，或者不提供此参数则默认无限重复。

## DoubleRepeat<typename ContentA, typename ContentB, typename Unit, typename PeriodA, typename PeriodB, typename Times = Infinite>
类似于RepeatEvery，但是交替执行两个内容模块ContentA和ContentB。先等待PeriodA时间后执行ContentA，再等待PeriodB时间后执行ContentB，然后循环。Times指定的是两个内容总计执行的次数之和，而不是完整周期数，因此可以指定奇数Times以使得ContentA比ContentB多执行一次。
————————————
# 瞬时类模块
————————————
瞬时类模块执行时不需要等待时间，可以立即完成

## ModuleAbort<typename Target>
执行此模块将导致Target模块被立即放弃（包括无限执行的模块），结束执行。如果Target模块当前未在执行中，则不进行任何操作。

## ModuleRestart<typename Target>
执行此模块将导致Target模块被立即重新开始执行。如果Target模块当前未在执行中，则立即开始执行。

## ModuleRandomize<typename Target>
执行此模块将导致具有随机功能的Target模块，如RandomInteger和RandomSequential，被重新随机化。不能对非随机化模块使用此模块。

## DigitalWrite<uint8_t Pin, bool HighOrLow>
执行此模块将导致指定引脚的输出电平被设置为HIGH或LOW。

## DigitalToggle<uint8_t Pin>
执行此模块将导致指定引脚的输出电平被翻转。此模块可配合RepeatEvery模块用于输出音调。

## MonitorPin<uint8_t Pin, typename Monitor>
对指定引脚注册一个中断监听器，每当引脚电平RISING时开始执行Monitor模块。Monitor模块的执行不会打断中断触发时正在执行的模块，两者将同步执行。对此模块使用ModuleAbort以停止监视引脚，但正在执行的Monitor模块不会中止。要中止Monitor模块，请对Monitor直接使用ModuleAbort。

## SerialMessage<UID Message>
向PC端发送一个预定义的Message，通常前缀Event_表示一个事件消息，将被PC端记录；Host_表示一个主机动作消息，令PC端执行相应的动作。

## CleanWhenAbort<typename Target, typename Cleaner>
将一个Cleaner模块附加到Target模块上，监听Target的开始、重启、终止或析构，这些事件之前会先执行Cleaner，但目标模块正常结束时则不会清理。Cleaner一般应是瞬时的，如果有延时操作则不会等待其完成。
————————————
# 容器类模块
————————————
容器类模块可以包含其他模块，并控制这些模块的执行顺序。执行时间取决于所包含模块的执行时间。

## Sequential<SubModules...>
按指定顺序执行多个SubModules模块，等待前一个模块执行结束才会继续执行下一个。

## RandomSequential<typename... SubModules>
类似于Sequential，但执行顺序随机。这个随机顺序在重复运行时保持相同，要重新随机化请使用ModuleRandomize模块。此模块还支持以下扩展：
- typename RandomSequential<typename... SubModules>::template WithRepeat<uint16_t... Repeats>：指定的Repeats对应每个SubModules的重复次数，这些重复也将互相穿插随机打乱执行。例如`typename RandomSequential<A,B,C>::template WithRepeat<20,30,10>`将会把20次A、30次B、10次C模块随机穿插洗牌执行。

## Repeat<typename Content, typename Times = Infinite>
重复执行Content模块，等待前一次重复执行结束才会继续执行下一次。Times是重复次数，可以是ConstantInteger或RandomInteger，或者不提供此参数则默认无限重复；如果指定RandomInteger，将在此模块开始时确定重复次数；在重复执行过程中重新随机化RandomInteger不会改变重复次数。

## Trial<UID TrialID, typename Content>
表示一个回合。TrialID是该模块的唯一标识符。Content是回合内要执行的内容模块。回合开始时将把TrialID发往PC端进行记录并提示回合开始。
回合还是断线重连恢复执行的基本单位。断线重连后，尚未执行完毕的回合将从头开始重新执行，已经执行完毕的回合将不会重复执行。不在回合内的模块在断线重连后不会跳过，仍会重复执行。
回合内不允许嵌套回合。

## DynamicSlot<UID UniqueID = UID::Module_DynamicSlot>
表示一个动态插槽，可以在运行时动态加载、清除或切换其内容模块。UniqueID是该模块的唯一标识符。执行此模块时，将执行当前插槽内的内容模块（如果有），否则什么也不做。对此模块的重启和终止操作也将传递给当前插槽内的内容模块（如果有）。要修改插槽内容，请使用以下扩展：
- typename DynamicSlot<UniqueID>::template Load<Content>：将插槽内容设置为Content模块。如果插槽内已经有内容模块正在运行，不会终止它，换新后仍继续执行。
- typename DynamicSlot<UniqueID>::Clear：清除插槽内容。不会终止当前正在运行的内容模块，清除后仍继续执行。

## IDModule<UID ID>
使用此模块后，必须用AssignModuleID宏将某个模块绑定到TargetID上：
```
AssignModuleID(TargetModule, TargetID);
```
这样执行此模块时，将视为执行与TargetID所绑定的模块TargetModule相同的模块。此模块的重启和终止操作也将传递给TargetModule。此模块主要用于实现自我循环引用。IDModule可以在TargetModule之前声明，但AssignModuleID必须在TargetModule定义之后。

## Async<typename Content>
异步执行Content模块。执行此模块时，将立即返回并继续执行后续模块，而Content模块将在后台异步执行。此模块的Restart和Abort操作也将传递给Content模块。此模块主要用于实现后台任务。

——以下提供实际用例，用户可根据需要进行修改——
*/

template<DurationRep Milliseconds>
using DelayMilliseconds = Delay<std::chrono::milliseconds, ConstantInteger<Milliseconds>>;

template<uint8_t PinIndex, DurationRep Milliseconds>
using PinFlash = Sequential<DigitalWrite<PinIndex, HIGH>, DelayMilliseconds<Milliseconds>, DigitalWrite<PinIndex, LOW>>;

template<uint8_t PinIndex, DurationRep Milliseconds, UID Up>
using PinFlashUp = Sequential<DigitalWrite<PinIndex, HIGH>, SerialMessage<Up>, DelayMilliseconds<Milliseconds>, DigitalWrite<PinIndex, LOW>>;

template<uint8_t PinIndex, DurationRep Milliseconds, UID Up, UID Down>
using PinFlashUpDown = Sequential<DigitalWrite<PinIndex, HIGH>, SerialMessage<Up>, DelayMilliseconds<Milliseconds>, DigitalWrite<PinIndex, LOW>, SerialMessage<Down>>;

using Random100To1000 = RandomInteger<100, 1000>;

using RandomFlash = Repeat<Sequential<DigitalToggle<Laser>, Delay<std::chrono::milliseconds, Random100To1000>, ModuleRandomize<Random100To1000>>>;

using Random5To10 = RandomInteger<5, 10>;

using Delay5To10 = Delay<std::chrono::seconds, Random5To10>;

using MonitorRestart = MonitorPin<CapacitorOut, ModuleRestart<Delay5To10>>;

template<DurationRep Seconds>
using DelaySeconds = Delay<std::chrono::seconds, ConstantInteger<Seconds>>;

template<DurationRep FrequencyHz, DurationRep Milliseconds>
using Tone = RepeatEvery<DigitalToggle<PassiveBuzzer>, std::chrono::microseconds, ConstantInteger<500000 / FrequencyHz>, ConstantInteger<Milliseconds * FrequencyHz / 500>>;

using ResponseWindow = MonitorPin<CapacitorOut, Sequential<DynamicSlot<>::Clear, ModuleAbort<IDModule<UID::Module_ResponseWindow>>, SerialMessage<UID::Event_MonitorHit>>>;
AssignModuleID(ResponseWindow, UID::Module_ResponseWindow);

using CalmDown = Sequential<DynamicSlot<>::Load<Sequential<ModuleAbort<ResponseWindow>, SerialMessage<UID::Event_MonitorMiss>>>, MonitorRestart, Delay5To10, ModuleAbort<MonitorRestart>>;

using Settlement = Sequential<ModuleRandomize<Random5To10>, DelaySeconds<20>>;

using Delay800ms = DelayMilliseconds<800>;

template<uint8_t CuePin, UID CueUp, UID CueDown>
using AssociationTrial = Sequential<CalmDown, ResponseWindow, PinFlashUpDown<CuePin, 200, CueUp, CueDown>, Delay800ms, DynamicSlot<>, DigitalWrite<WaterPump, HIGH>, SerialMessage<UID::Event_Water>, DelayMilliseconds<150>, DigitalWrite<WaterPump, LOW>, Settlement>;

template<typename Cue>
using CueOnlyTrial = Sequential<CalmDown, ResponseWindow, Cue, Delay800ms, DynamicSlot<>, Settlement>;

using BackgroundMonitor = MonitorPin<CapacitorOut, SerialMessage<UID::Event_HitCount>>;

using CapacitorInitialize = Sequential<DigitalWrite<CapacitorVdd, HIGH>, DelaySeconds<1>, BackgroundMonitor>;

// 点亮电容后等待1s，渡过刚启动的不稳定期
template<typename TrialType>
using AssociationSession = Sequential<DigitalWrite<CapacitorVdd, HIGH>, DelaySeconds<1>, BackgroundMonitor, Repeat<TrialType, ConstantInteger<30>>, ModuleAbort<BackgroundMonitor>>;

//自定义次数
template<typename TrialType, uint16_t Times>
using AssociationSessionTimes = Sequential<CapacitorInitialize, Repeat<TrialType, ConstantInteger<Times>> >;

/*Optogenetics*/
template<uint8_t PinIndex, uint16_t Times>
using Opto30Hz = Sequential<
                  DigitalWrite<PinIndex, HIGH>,
                  DoubleRepeat<
                    DigitalWrite<PinIndex, LOW>,
                    DigitalWrite<PinIndex, HIGH>,
                    std::chrono::milliseconds, 
                    ConstantInteger<10>,
                    ConstantInteger<23>,
                    ConstantInteger<Times>
                  >,
                  DigitalWrite<PinIndex, LOW>
                >;

template<uint8_t PinIndex, uint16_t Times1, uint16_t Times2>
using Opto30HzRandom = Sequential<
                  DigitalWrite<PinIndex, HIGH>,
                  DoubleRepeat<
                    DigitalWrite<PinIndex, LOW>,
                    DigitalWrite<PinIndex, HIGH>,
                    std::chrono::milliseconds, 
                    ConstantInteger<10>,
                    ConstantInteger<23>,
                    RandomInteger<Times1, Times2>
                  >,
                  DigitalWrite<PinIndex, LOW>
                >;

template<uint8_t PinIndex, uint16_t Times>
using Opto40Hz = Sequential<
                  DigitalWrite<PinIndex, HIGH>,
                  DoubleRepeat<
                    DigitalWrite<PinIndex, LOW>,
                    DigitalWrite<PinIndex, HIGH>,
                    std::chrono::milliseconds, 
                    ConstantInteger<2>,
                    ConstantInteger<23>,
                    ConstantInteger<Times>
                  >,
                  DigitalWrite<PinIndex, LOW>
                >;

template<uint8_t PinIndex1, uint8_t PinIndex2, uint16_t Times1, uint16_t Times2>
using Opto30Hz2Pin = Sequential<Async<Opto30Hz<PinIndex1, Times1>>, Opto30Hz<PinIndex2, Times2>>;

template<uint8_t PinIndex1, uint8_t PinIndex2, uint8_t PinIndex3, uint16_t Times1, uint16_t Times2, uint16_t Times3>
using Opto30Hz3Pin = Sequential<Async<Opto30Hz<PinIndex1, Times1>>, Async<Opto30Hz<PinIndex2, Times2>>, Opto30Hz<PinIndex3, Times3>>;

template<uint8_t PinIndex1, uint8_t PinIndex2, uint16_t Times1, uint16_t Times2>
using Opto40Hz2Pin = Sequential<Async<Opto40Hz<PinIndex1, Times1>>, Opto40Hz<PinIndex2, Times2>>;

template<uint8_t PinIndex1, uint8_t PinIndex2>
using OptoThetaGamma1 = Sequential<Opto40Hz2Pin<PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1>,DelayMilliseconds<73>,
                                  Opto40Hz2Pin<PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1>,DelayMilliseconds<73>>;
/*using OptoThetaGamma1 = Sequential<Opto40Hz2Pin<PinIndex1, PinIndex2, 50/25*2-1, 50/25*2-1>,DelayMilliseconds<98>,
                                  Opto40Hz2Pin<PinIndex1, PinIndex2, 50/25*2-1, 50/25*2-1>,DelayMilliseconds<98>>;75+23
using OptoThetaGamma1 = Sequential<Opto40Hz2Pin<PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1>,DelayMilliseconds<73>,
                                  Opto40Hz2Pin<PinIndex1, PinIndex2, 75/25*2-1, 75/25*2-1>,DelayMilliseconds<73>>;50+23
using OptoThetaGamma1 = Sequential<Opto40Hz2Pin<PinIndex1, PinIndex2, 100/25*2-1, 100/25*2-1>,DelayMilliseconds<48>,
                                  Opto40Hz2Pin<PinIndex1, PinIndex2, 100/25*2-1, 100/25*2-1>,DelayMilliseconds<48>>;25+23*/

template<uint8_t PinIndex1>
using SingleThetaGamma1 = Sequential<Opto40Hz<PinIndex1, 75/25*2-1>, DelayMilliseconds<73>,
                                   Opto40Hz<PinIndex1, 75/25*2-1>, DelayMilliseconds<73>>;
/*using SingleThetaGamma1 = Sequential<Opto40Hz<PinIndex1, 50/25*2-1>, DelayMilliseconds<98>,
                                   Opto40Hz<PinIndex1, 50/25*2-1>, DelayMilliseconds<98>>;75+23
using SingleThetaGamma1 = Sequential<Opto40Hz<PinIndex1, 75/25*2-1>, DelayMilliseconds<73>,
                                   Opto40Hz<PinIndex1, 75/25*2-1>, DelayMilliseconds<73>>;50+23
using SingleThetaGamma1 = Sequential<Opto40Hz<PinIndex1, 100/25*2-1>, DelayMilliseconds<48>,
                                   Opto40Hz<PinIndex1, 100/25*2-1>, DelayMilliseconds<48>>;25+23*/

/*Tone,delay,air,water*/
using HighTone500 = Sequential<SerialMessage<UID::Event_HighUp>, Tone<10000, 500>, SerialMessage<UID::Event_HighDown>>;
using LowTone500 = Sequential<SerialMessage<UID::Event_LowUp>, Tone<2400, 500>, SerialMessage<UID::Event_LowDown>>;
using Air100 = PinFlashUp<AirPump, 100, UID::Event_AirPuff>;
using Water100 = PinFlashUp<WaterPump, 150, UID::Event_Water>;

/*Response*/
using RightDetector = MonitorPin<CapacitorOut, Sequential<ModuleAbort<IDModule<UID::Module_RightDetector>>, DynamicSlot<UID::Module_LickDetector>::Clear, SerialMessage<UID::Event_MonitorHit>, Water100>>;
AssignModuleID(RightDetector, UID::Module_RightDetector);
using FalseDetector = MonitorPin<CapacitorOut, Sequential<ModuleAbort<IDModule<UID::Module_FalseDetector>>, DynamicSlot<UID::Module_LickDetector>::Clear, SerialMessage<UID::Event_FalseChoice>, Air100>>;
AssignModuleID(FalseDetector, UID::Module_FalseDetector);
using WaterAlwaysDetector = MonitorPin<
                                CapacitorOut, 
                                Sequential< 
                                  ModuleAbort<IDModule<UID::Module_WaterAlwaysDetector>>,
                                  SerialMessage<UID::Event_MonitorHit>, 
                                  Water100,
                                  DynamicSlot<UID::Module_Water>::Clear,
                                  DynamicSlot<UID::Module_LickDetector>::Clear
                                >
                                >;
AssignModuleID(WaterAlwaysDetector, UID::Module_WaterAlwaysDetector);

using ResponseRight = Sequential<DynamicSlot<UID::Module_LickDetector>::Load<SerialMessage<UID::Event_MonitorMiss>>, RightDetector, DelayMilliseconds<1000>, ModuleAbort<RightDetector>, DynamicSlot<UID::Module_LickDetector>>;
using ResponseFalse = Sequential<DynamicSlot<UID::Module_LickDetector>::Load<SerialMessage<UID::Event_CorrectReject>>, FalseDetector, DelayMilliseconds<1000>, ModuleAbort<FalseDetector>, DynamicSlot<UID::Module_LickDetector>>;
using ResponseWaterAlways = Sequential<
                              DynamicSlot<UID::Module_Water>::Load<Water100>,
                              WaterAlwaysDetector,
                              DelayMilliseconds<1000>,
                              ModuleAbort<WaterAlwaysDetector>, 
                              DynamicSlot<UID::Module_LickDetector>,
                              DynamicSlot<UID::Module_Water>
                            >;

using CalmDownSimple = Sequential<DelayMilliseconds<1000>, DynamicSlot<UID::Module_LickDetector>::Load<SerialMessage<UID::Event_MonitorMiss>>>;

using MonitorRestart1 = MonitorPin<CapacitorOut, ModuleRestart<DelayMilliseconds<5000>>>;
using CalmDown1 = Sequential<MonitorRestart1, DelayMilliseconds<5000>, ModuleAbort<MonitorRestart1>>;

using WaitingTime2 = Delay<>;
using MonitorRestartRight = MonitorPin<CapacitorOut, Sequential<ModuleAbort<IDModule<UID::Module_MonitorRestartRight>>, SerialMessage<UID::Event_MonitorHit>, Water100, ModuleSkip<WaitingTime2>>>;
AssignModuleID(MonitorRestartRight, UID::Module_MonitorRestartRight);
using MonitorRestartFalse = MonitorPin<CapacitorOut, Sequential<ModuleAbort<IDModule<UID::Module_MonitorRestartFalse>>, SerialMessage<UID::Event_FalseChoice>, DelayMilliseconds<100>, ModuleSkip<WaitingTime2>>>;
AssignModuleID(MonitorRestartFalse, UID::Module_MonitorRestartFalse);
using LickBeginRight = Sequential<MonitorRestartRight, WaitingTime2>;
using LickBeginFalse = Sequential<MonitorRestartFalse, WaitingTime2>;

using Shaping = Sequential<DelayMilliseconds<5000>, ResponseRight>; 
using ShapingTrial = Trial<UID::Trial_Shaping, Shaping>;

/*OriginalTrials(NoOpto)*/
using HighWater = Sequential<CalmDownSimple, DelayMilliseconds<3000>, HighTone500, DelayMilliseconds<500>, ResponseRight, DelayMilliseconds<15000>>;
using HighWaterAlways = Sequential<CalmDownSimple, DelayMilliseconds<3000>, HighTone500, DelayMilliseconds<500>, ResponseWaterAlways, DelayMilliseconds<15000>>;
using LowAir = Sequential<CalmDownSimple, DelayMilliseconds<500>, ResponseFalse, DelayMilliseconds<7000>>;

using HighWaterTrial = Trial<UID::Trial_HighWater, HighWater>;
using HighWaterAlwaysTrial = Trial<UID::Trial_HighWaterAlways, HighWaterAlways>;

/*PreSession*/
template<typename TrialType1, uint16_t Times1>
using PreSession = Sequential<
                  CapacitorInitialize, 
                  typename Repeat<TrialType1>::template UntilTimes<Times1>
                >;

/*AlwaysAndAssociatonFixedSession*/
template<typename TrialType1, uint16_t Times1, typename TrialType2, uint16_t Times2>
using A3FixedSession = Sequential<
                        CapacitorInitialize, 
                        Repeat<TrialType1, ConstantInteger<Times1>>,
                        Repeat<TrialType2, ConstantInteger<Times2>>
                      >;

/*OptoOnePinActTrial*/
using OptoHighWater = Sequential<CalmDownSimple, Async<Opto30Hz<Laser, 2000/33/2*2+1>>, HighTone500, DelayMilliseconds<500>, ResponseRight, DelayMilliseconds<7000>>;
using OptoLowAir = Sequential<CalmDownSimple, Async<Opto30Hz<Laser, 122>>, LowTone500, DelayMilliseconds<500>, ResponseFalse, DelayMilliseconds<7000>>;
using OptoSingleAudioTrial0 = typename RandomSequential<
                          Trial<UID::Trial_OptoHighWater, OptoHighWater>, 
                          Trial<UID::Trial_OptoLowAir, OptoLowAir>
                          >::template WithRepeat<2, 2>;

using OptoSingleAudioTrial = Sequential<OptoSingleAudioTrial0, ModuleRandomize<OptoSingleAudioTrial0>>;

/*MutiplePinsActTrial*/ 
using MultiOptoHighWater = Sequential<CalmDownSimple, Async<Opto30Hz2Pin<Laser, Laser2, 1500/33*2, 1500/33*2>>, HighTone500, Async<Opto30Hz2Pin<Laser, Laser3, 1500/33*2, 1500/33*2>>, DelayMilliseconds<500>, ResponseRight, DelayMilliseconds<8000>>;
using MultiOptoLowAir = Sequential<CalmDownSimple, Async<Opto30Hz2Pin<Laser, Laser2, 1500/33*2, 1500/33*2>>, LowTone500, Async<Opto30Hz2Pin<Laser, Laser3, 1500/33*2, 1500/33*2>>, DelayMilliseconds<500>, ResponseFalse, DelayMilliseconds<8000>>;
using MultiOptoSingleAudioTrial0 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHighWater, MultiOptoHighWater>, 
                          Trial<UID::Trial_MultiOptoLowAir, MultiOptoLowAir>
                          >::template WithRepeat<2, 2>;

using MultiOptoSingleAudioTrial = Sequential<MultiOptoSingleAudioTrial0, ModuleRandomize<MultiOptoSingleAudioTrial0>>;

using OptoSingleAudioTrial = Sequential<OptoSingleAudioTrial0, ModuleRandomize<OptoSingleAudioTrial0>>;

/*double*/
using HLWater = Sequential<CalmDown1, HighTone500, LowTone500, DelayMilliseconds<500>, ResponseRight, DelayMilliseconds<5000>>;
using HLWaterAlways = Sequential<CalmDown1, HighTone500, LowTone500, DelayMilliseconds<500>, ResponseWaterAlways, DelayMilliseconds<5000>>;
using HHAir = Sequential<CalmDown1, HighTone500, HighTone500, DelayMilliseconds<500>, ResponseFalse, DelayMilliseconds<5000>>;
using LHAir = Sequential<CalmDown1, LowTone500, HighTone500, DelayMilliseconds<500>, ResponseFalse, DelayMilliseconds<5000>>;
using LLAir = Sequential<CalmDown1, LowTone500, LowTone500, DelayMilliseconds<500>, ResponseFalse, DelayMilliseconds<5000>>;

using HLWaterAlwaysTrial = Trial<UID::Trial_HLWaterAlways, HLWaterAlways>;
using HLWaterTrial = Trial<UID::Trial_HLWater, HLWater>;

using DoubleAudioTrial0 = typename RandomSequential<
                          Trial<UID::Trial_HLWater, HLWater>, 
                          Trial<UID::Trial_HHAir, HHAir>,
                          Trial<UID::Trial_LHAir, LHAir>, 
                          Trial<UID::Trial_LLAir, LLAir>
                          >::template WithRepeat<3, 1, 1, 1>;

using DoubleAudioTrial = Sequential<DoubleAudioTrial0, ModuleRandomize<DoubleAudioTrial0>>;

/*double MultiOpto*/
using HighToneOpto1 = Sequential<Async<HighTone500>, Opto30Hz2Pin<Laser, Laser2, 200/33*2, 200/33*2>, Opto30Hz<Laser, 300/33*2>>;
using LowToneOpto1 = Sequential<Async<LowTone500>, Opto30Hz2Pin<Laser, Laser2, 200/33*2, 200/33*2>, Opto30Hz<Laser, 300/33*2>>;
using OptoRightWindow1 = Sequential<Async<Opto30Hz2Pin<Laser, Laser3, 1500/33*2, 1500/33*2>>, DelayMilliseconds<500>, ResponseRight>;
using OptoFalseWindow1 = Sequential<Async<Opto30Hz2Pin<Laser, Laser3, 1500/33*2, 1500/33*2>>, DelayMilliseconds<500>, ResponseFalse>;
using OptoAlwaysWindow1 = Sequential<Async<Opto30Hz2Pin<Laser, Laser3, 1500/33*2, 1500/33*2>>, DelayMilliseconds<500>, ResponseWaterAlways>;

using HighToneOpto2 = Sequential<Async<HighTone500>, OptoThetaGamma1<Laser, Laser2>, SingleThetaGamma1<Laser>>;
using LowToneOpto2 = Sequential<Async<LowTone500>, OptoThetaGamma1<Laser, Laser2>, SingleThetaGamma1<Laser>>;
using OptoRightWindow2 = Sequential<Async<Repeat<OptoThetaGamma1<Laser, Laser3>, ConstantInteger<6> >>, DelayMilliseconds<500>, ResponseRight>;
using OptoFalseWindow2 = Sequential<Async<Repeat<OptoThetaGamma1<Laser, Laser3>, ConstantInteger<6> >>, DelayMilliseconds<500>, ResponseFalse>;
using OptoAlwaysWindow2 = Sequential<Async<Repeat<OptoThetaGamma1<Laser, Laser3>, ConstantInteger<6> >>, DelayMilliseconds<500>, ResponseWaterAlways>;

using HighToneOpto31 = Sequential<Async<HighTone500>, Opto30Hz2Pin<Laser2, Laser4, 200/33*2, 200/33*2>, Opto30Hz2Pin<Laser, Laser4, 300/33*2, 300/33*2>>;
using HighToneOpto32 = Sequential<Async<HighTone500>, Opto30Hz3Pin<Laser, Laser2, Laser4, 200/33*2, 200/33*2, 200/33*2>, Opto30Hz2Pin<Laser, Laser4, 300/33*2, 300/33*2>>;
using LowToneOpto31 = Sequential<Async<LowTone500>, Opto30Hz2Pin<Laser2, Laser4, 200/33*2, 200/33*2>, Opto30Hz2Pin<Laser, Laser4, 300/33*2, 300/33*2>>;
using LowToneOpto32 = Sequential<Async<LowTone500>, Opto30Hz3Pin<Laser, Laser2, Laser4, 200/33*2, 200/33*2, 200/33*2>, Opto30Hz2Pin<Laser, Laser4, 300/33*2, 300/33*2>>;

using TestGamma1=Sequential<OptoThetaGamma1<Laser, Laser2>, OptoThetaGamma1<Laser3, Laser2>>;
using TestGamma1Trial = Trial<UID::Trial_HLHWater, TestGamma1>;

using MultiOptoHLWater = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>, HighToneOpto1, LowToneOpto1, OptoRightWindow1, DelayMilliseconds<8000>>;
using MultiOptoHLWaterAlways = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>, HighToneOpto1, LowToneOpto1, OptoAlwaysWindow1, DelayMilliseconds<8000>>;
using MultiOptoHHAir = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>, HighToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds<8000>>;
using MultiOptoLHAir = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>, LowToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds<8000>>;
using MultiOptoLLAir = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>, LowToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds<8000>>;

using MultiOptoHLWater2 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, OptoRightWindow2, DelayMilliseconds<8000>>;
using MultiOptoHLWaterAlways2 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, OptoAlwaysWindow2, DelayMilliseconds<8000>>;
using MultiOptoHHAir2 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<8000>>;
using MultiOptoLHAir2 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<8000>>;
using MultiOptoLLAir2 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<8000>>;

using MultiOptoHLWater3 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser4, Laser2, 500/33*2, 500/33*2>, HighToneOpto31, LowToneOpto32, OptoRightWindow1, DelayMilliseconds<8000>>;
using MultiOptoHLWaterAlways3 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser4, Laser2, 500/33*2, 500/33*2>, HighToneOpto31, LowToneOpto32, OptoAlwaysWindow1, DelayMilliseconds<8000>>;
using MultiOptoHHAir3 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser4, Laser2, 500/33*2, 500/33*2>, HighToneOpto31, HighToneOpto32, OptoFalseWindow1, DelayMilliseconds<8000>>;
using MultiOptoLHAir3 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser4, Laser2, 500/33*2, 500/33*2>, LowToneOpto31, HighToneOpto32, OptoFalseWindow1, DelayMilliseconds<8000>>;
using MultiOptoLLAir3 = Sequential<CalmDown1, Async<DelayMilliseconds<500>>, Opto30Hz2Pin<Laser4, Laser2, 500/33*2, 500/33*2>, LowToneOpto31, LowToneOpto32, OptoFalseWindow1, DelayMilliseconds<8000>>;

using MultiOptoHLWater4 = Sequential<CalmDown1, LickBeginRight, HighToneOpto1, LowToneOpto1, DelayMilliseconds<8000>>;
using MultiOptoHHAir4 = Sequential<CalmDown1, LickBeginFalse, HighToneOpto1, HighToneOpto1, DelayMilliseconds<8000>>;
using MultiOptoLHAir4 = Sequential<CalmDown1, LickBeginFalse, LowToneOpto1, HighToneOpto1,  DelayMilliseconds<8000>>;
using MultiOptoLLAir4 = Sequential<CalmDown1, LickBeginFalse, LowToneOpto1, LowToneOpto1, DelayMilliseconds<8000>>;

using MultiOptoDoubleAudioTrialPre = Trial<UID::Trial_MultiOptoHLWaterAlways, MultiOptoHLWaterAlways>;
using MultiOptoDoubleAudioTrialPre2 = Trial<UID::Trial_MultiOptoHLWaterAlways, MultiOptoHLWaterAlways2>;
using MultiOptoDoubleAudioTrialPre3 = Trial<UID::Trial_MultiOptoHLWaterAlways, MultiOptoHLWaterAlways3>;

using MultiOptoDoubleAudioTrial0 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHLWater, MultiOptoHLWater>, 
                          Trial<UID::Trial_MultiOptoHHAir, MultiOptoHHAir>,
                          Trial<UID::Trial_MultiOptoLHAir, MultiOptoLHAir>, 
                          Trial<UID::Trial_MultiOptoLLAir, MultiOptoLLAir>
                          >::template WithRepeat<3, 1, 1, 1>;
using MultiOptoDoubleAudioTrial = Sequential<MultiOptoDoubleAudioTrial0, ModuleRandomize<MultiOptoDoubleAudioTrial0>>;

using MultiOptoDoubleAudioTrial02 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHLWater, MultiOptoHLWater2>, 
                          Trial<UID::Trial_MultiOptoHHAir, MultiOptoHHAir2>,
                          Trial<UID::Trial_MultiOptoLHAir, MultiOptoLHAir2>, 
                          Trial<UID::Trial_MultiOptoLLAir, MultiOptoLLAir2>
                          >::template WithRepeat<3, 1, 1, 1>;
using MultiOptoDoubleAudioTrial2 = Sequential<MultiOptoDoubleAudioTrial02, ModuleRandomize<MultiOptoDoubleAudioTrial02>>;

using MultiOptoDoubleAudioTrial03 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHLWater, MultiOptoHLWater3>, 
                          Trial<UID::Trial_MultiOptoHHAir, MultiOptoHHAir3>,
                          Trial<UID::Trial_MultiOptoLHAir, MultiOptoLHAir3>, 
                          Trial<UID::Trial_MultiOptoLLAir, MultiOptoLLAir3>
                          >::template WithRepeat<3, 1, 1, 1>;
using MultiOptoDoubleAudioTrial3 = Sequential<MultiOptoDoubleAudioTrial03, ModuleRandomize<MultiOptoDoubleAudioTrial03>>;

using MultiOptoDoubleAudioTrial4 = Sequential<
                          Repeat<Trial<UID::Trial_MultiOptoHLWater, MultiOptoHLWaterAlways>, ConstantInteger<7>>,
                          Repeat<Trial<UID::Trial_MultiOptoHHAir, MultiOptoHHAir>, ConstantInteger<3>>,
                          Repeat<Trial<UID::Trial_MultiOptoHLWater, MultiOptoHLWaterAlways>, ConstantInteger<7>>,
                          Repeat<Trial<UID::Trial_MultiOptoLHAir, MultiOptoLHAir>, ConstantInteger<3>>,
                          Repeat<Trial<UID::Trial_MultiOptoHLWater, MultiOptoHLWaterAlways>, ConstantInteger<7>>, 
                          Repeat<Trial<UID::Trial_MultiOptoLLAir, MultiOptoLLAir>, ConstantInteger<3>>>;

using MultiOptoDoubleAudioTrial041 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHLWater, MultiOptoHLWater4>
                          >::template WithRepeat<6>;
using MultiOptoDoubleAudioTrial41 = Sequential<MultiOptoDoubleAudioTrial041>;

using MultiOptoDoubleAudioTrial42 = Sequential<
                          Repeat<Trial<UID::Trial_MultiOptoHHAir, MultiOptoHHAir4>, ConstantInteger<2>>,
                          Repeat<Trial<UID::Trial_MultiOptoLHAir, MultiOptoLHAir4>, ConstantInteger<2>>,
                          Repeat<Trial<UID::Trial_MultiOptoLLAir, MultiOptoLLAir4>, ConstantInteger<2>>>;
//ModuleRandomize<MultiOptoDoubleAudioTrial04>>;

using LaserOnlyTrial = Sequential< AssociationSessionTimes<MultiOptoDoubleAudioTrialPre2, 12>, AssociationSessionTimes<MultiOptoDoubleAudioTrial, 1> >;

/*triple*/
using HLHWater = Sequential<DelayMilliseconds<2000>, HighTone500, LowTone500, HighTone500, DelayMilliseconds<500>, ResponseRight, DelayMilliseconds<7000>>;

using TripleAudioTrialPre = Trial<UID::Trial_HLHWater, HLHWater>;

/*triple MultiOpto*/
using MultiOptoHLHWater = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>,  HighToneOpto1, LowToneOpto1, HighToneOpto1, OptoRightWindow1, DelayMilliseconds<3000>>;
using MultiOptoHLLAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, HighToneOpto1, LowToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;
using MultiOptoHHLAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, HighToneOpto1, HighToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;
using MultiOptoHHHAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, HighToneOpto1, HighToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;
using MultiOptoLLHAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, LowToneOpto1, LowToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;
using MultiOptoLLLAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, LowToneOpto1, LowToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;
using MultiOptoLHLAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, LowToneOpto1, HighToneOpto1, LowToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;
using MultiOptoLHHAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, LowToneOpto1, HighToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;

using MultiOptoHLHWater2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoRightWindow2, DelayMilliseconds<3000>>;
using MultiOptoHLLAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHHLAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHHHAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLLHAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLLLAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLHLAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLHHAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;

using MultiOptoLHLWater2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoRightWindow2, DelayMilliseconds<3000>>;
using MultiOptoHLHAir2 = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;

using MultiOptoLHLWater = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, LowToneOpto1, HighToneOpto1, LowToneOpto1, OptoRightWindow1, DelayMilliseconds<3000>>;
using MultiOptoHLHAir = Sequential<CalmDown1, Async<Opto30Hz2Pin<Laser, Laser2, 500/33*2, 500/33*2>>, DelayMilliseconds<500>, HighToneOpto1, LowToneOpto1, HighToneOpto1, OptoFalseWindow1, DelayMilliseconds<3000>>;

using MultiOptoTripleAudioTrialPre = Trial<UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater>;

using MultiOptoTripleAudioTrial0 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater>, 
                          Trial<UID::Trial_MultiOptoHHHAir, MultiOptoHHHAir>,
                          Trial<UID::Trial_MultiOptoLHHAir, MultiOptoLHHAir>, 
                          Trial<UID::Trial_MultiOptoLLHAir, MultiOptoLLHAir>,
                          Trial<UID::Trial_MultiOptoHLLAir, MultiOptoHLLAir>, 
                          Trial<UID::Trial_MultiOptoHHLAir, MultiOptoHHLAir>,
                          Trial<UID::Trial_MultiOptoHLHAir, MultiOptoHLHAir>, 
                          Trial<UID::Trial_MultiOptoLLLAir, MultiOptoLLLAir>
                          >::template WithRepeat<7, 1, 1, 1, 1, 1, 1, 1>;

using MultiOptoTripleAudioTrial = Sequential<MultiOptoTripleAudioTrial0, ModuleRandomize<MultiOptoTripleAudioTrial0>>;

using MultiOptoTripleAudioTrialPre2 = Trial<UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater2>;

using MultiOptoTripleAudioTrial01 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoLHLWater, MultiOptoLHLWater2>, 
                          Trial<UID::Trial_MultiOptoHHHAir, MultiOptoHHHAir2>,
                          Trial<UID::Trial_MultiOptoLHHAir, MultiOptoLHHAir2>, 
                          Trial<UID::Trial_MultiOptoLLHAir, MultiOptoLLHAir2>,
                          Trial<UID::Trial_MultiOptoHLLAir, MultiOptoHLLAir2>, 
                          Trial<UID::Trial_MultiOptoHHLAir, MultiOptoHHLAir2>,
                          Trial<UID::Trial_MultiOptoHLHAir, MultiOptoHLHAir2>, 
                          Trial<UID::Trial_MultiOptoLLLAir, MultiOptoLLLAir2>
                          >::template WithRepeat<7, 1, 1, 1, 1, 1, 1, 1>;

using MultiOptoTripleAudioTrial2 = Sequential<MultiOptoTripleAudioTrial01, ModuleRandomize<MultiOptoTripleAudioTrial01>>;

/*Quadruple*/
using HLHLWater = Sequential<DelayMilliseconds<2000>, HighTone500, LowTone500, HighTone500, LowTone500, DelayMilliseconds<500>, ResponseRight, DelayMilliseconds<7000>>;
using QuadrupleAudioTrialPre = Trial<UID::Trial_HLHLWater, HLHLWater>;

/*Quadruple MultiOpto*/
using MultiOptoHLHLWater = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoRightWindow2, DelayMilliseconds<3000>>;
using MultiOptoHLLLAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHHLLAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, HighToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHHHLAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, HighToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLLHLAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLLLLAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, LowToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLHLLAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, LowToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLHHLAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, HighToneOpto2, LowToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHLHHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHLLHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHHLHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoHHHHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, HighToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLLHHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, LowToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLLLHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, LowToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLHLHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, LowToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;
using MultiOptoLHHHAir = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, LowToneOpto2, HighToneOpto2, HighToneOpto2, HighToneOpto2, OptoFalseWindow2, DelayMilliseconds<3000>>;

using MultiOptoHLHLWaterAlways = Sequential<CalmDown1, Repeat<OptoThetaGamma1<Laser, Laser2>, ConstantInteger<2>>, HighToneOpto2, LowToneOpto2, HighToneOpto2, LowToneOpto2, OptoAlwaysWindow2, DelayMilliseconds<3000>>;
using MultiOptoQuadrupleAudioTrialPre = Trial<UID::Trial_MultiOptoHLHLWaterAlways, MultiOptoHLHLWaterAlways>;

using MultiOptoQuadrupleAudioTrialP1 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHLHLWater, MultiOptoHLHLWater>,  
                          Trial<UID::Trial_MultiOptoHHLLAir, MultiOptoHHLLAir>,
                          Trial<UID::Trial_MultiOptoLHLLAir, MultiOptoLHLLAir>, 
                          Trial<UID::Trial_MultiOptoLLLLAir, MultiOptoLLLLAir>,
                          Trial<UID::Trial_MultiOptoHLHHAir, MultiOptoHLHHAir>, 
                          Trial<UID::Trial_MultiOptoHHHHAir, MultiOptoHHHHAir>
                          >::template WithRepeat<5, 1, 1, 1, 1, 1>;

using MultiOptoQuadrupleAudioTrialP2 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHLHLWater, MultiOptoHLHLWater>, 
                          Trial<UID::Trial_MultiOptoLLHLAir, MultiOptoLLHLAir>,
                          Trial<UID::Trial_MultiOptoHLLLAir, MultiOptoHLLLAir>, 
                          Trial<UID::Trial_MultiOptoLHHHAir, MultiOptoLHHHAir>, 
                          Trial<UID::Trial_MultiOptoLLHHAir, MultiOptoLLHHAir>,
                          Trial<UID::Trial_MultiOptoHLLHAir, MultiOptoHLLHAir>
                          >::template WithRepeat<5, 1, 1, 1, 1, 1>;

using MultiOptoQuadrupleAudioTrialP3 = typename RandomSequential<
                          Trial<UID::Trial_MultiOptoHLHLWater, MultiOptoHLHLWater>, 
                          Trial<UID::Trial_MultiOptoHHHLAir, MultiOptoHHHLAir>,
                          Trial<UID::Trial_MultiOptoLHHLAir, MultiOptoLHHLAir>,  
                          Trial<UID::Trial_MultiOptoHHLHAir, MultiOptoHHLHAir>,
                          Trial<UID::Trial_MultiOptoLHLHAir, MultiOptoLHLHAir>, 
                          Trial<UID::Trial_MultiOptoLLLHAir, MultiOptoLLLHAir>
                          >::template WithRepeat<5, 1, 1, 1, 1, 1>;

using MultiOptoQuadrupleAudioTrial0 = typename RandomSequential<MultiOptoQuadrupleAudioTrialP1, 
                                                               MultiOptoQuadrupleAudioTrialP2, 
                                                               MultiOptoQuadrupleAudioTrialP3
                                                               >::template WithRepeat<1, 1, 1>;

using MultiOptoQuadrupleAudioTrial = Sequential<MultiOptoQuadrupleAudioTrial0, ModuleRandomize<MultiOptoQuadrupleAudioTrial0>>;

// ——以下列出所有公开模块，均绑定到ID，允许PC端调用——
std::unordered_map<UID, uint16_t (*)(Process *)> SessionMap = {
  { UID::Test_BlueLed, Session<PinFlash<BlueLed, 200>> },
  { UID::Test_WaterPump, Session<PinFlash<WaterPump, 150>> },
  { UID::Test_CapacitorReset, Session<Sequential<DigitalWrite<CapacitorVdd, LOW>, DelayMilliseconds<100>, DigitalWrite<CapacitorVdd, HIGH>>> },
  { UID::Test_CapacitorMonitor, Session<Sequential<DigitalWrite<CapacitorVdd, HIGH>, MonitorPin<CapacitorOut, SerialMessage<UID::Event_MonitorHit>>>> },
  { UID::Test_CD1, Session<PinFlash<CD1, 200>> },
  { UID::Test_ActiveBuzzer, Session<PinFlash<ActiveBuzzer, 200>> },
  { UID::Test_AirPump, Session<PinFlash<AirPump, 200>> },
  { UID::Test_Optogenetic, Session<PinFlash<Laser, 200>> },
  { UID::Test_HostAction, Session<SerialMessage<UID::Host_GratingImage>> },
  { UID::Test_SquareWave, Session<DoubleRepeat<DigitalWrite<Laser, HIGH>, DigitalWrite<Laser, LOW>, std::chrono::seconds, ConstantInteger<1>, ConstantInteger<2>, ConstantInteger<6>>> },  // 注意是6次变灯，不是6个周期
  { UID::Test_RandomFlash, Session<Sequential<Async<RandomFlash>, DelaySeconds<10>, ModuleAbort<RandomFlash>>> },
  { UID::Test_LowTone, Session<Tone<6000, 500>> },
  { UID::Test_HighTone, Session<Tone<14000, 500>> },
  /*{ UID::Session_Shaping, Session<AssociationSessionTimes<Trial<UID::Trial_Shaping, Sequential<DelayMilliseconds<2500>, OptoRightWindow2>>, 100>> },
  { UID::Session_AudioWater, Session<AssociationSession<Trial<UID::Trial_AudioWater, AssociationTrial<ActiveBuzzer, UID::Event_AudioUp, UID::Event_AudioDown>>>> },
  { UID::Session_LightWater, Session<AssociationSession<Trial<UID::Trial_LightWater, AssociationTrial<BlueLed, UID::Event_LightUp, UID::Event_LightDown>>>> },
  { UID::Session_LAuW, Session<Sequential<DigitalWrite<CapacShapingitorVdd, HIGH>, RandomSequential<
                                                                              Trial<UID::Trial_LightOnly, CueOnlyTrial<PinFlashUpDown<BlueLed, 200, UID::Event_LightUp, UID::Event_LightDown>>>,
                                                                              Trial<UID::Trial_AudioOnly, CueOnlyTrial<PinFlashUpDown<ActiveBuzzer, 200, UID::Event_AudioUp, UID::Event_AudioDown>>>,
                                                                              Trial<UID::Trial_WaterOnly, CueOnlyTrial<PinFlashUp<WaterPump, 150, UID::Event_Water>>>>::WithRepeat<20, 20, 20>>> },
  { UID::Session_SingleAudioShaping, Session<A3FixedSession<HighWaterAlwaysTrial, 100, HighWaterTrial, 1>> },
  { UID::Session_OptoSingleAudioTask, Session<Sequential< AssociationSessionTimes<OptoSingleAudioTrial, 25>>> },
  { UID::Session_MultiOptoSingleAudioTask, Session<Sequential< AssociationSessionTimes<MultiOptoSingleAudioTrial, 25>>> },
  { UID::Session_DoubleAudioShaping, Session<A3FixedSession<HLWaterAlwaysTrial, 5, HLWaterTrial, 25>> },*/
  { UID::Session_DoubleAudioRecon, Session<Sequential<AssociationSessionTimes<MultiOptoDoubleAudioTrial4, 1>, 
                                                      AssociationSessionTimes<MultiOptoDoubleAudioTrialPre, 6>>> },
  { UID::Session_MultiOptoDoubleAudioTask, Session<Sequential<SerialMessage<UID::Event_Pulse5>,
                                                              AssociationSessionTimes<MultiOptoDoubleAudioTrialPre, 5>, 
                                                              AssociationSessionTimes<MultiOptoDoubleAudioTrial, 20>>> },
  /*{ UID::Session_MultiOptoDoubleAudioTask2, Session<Sequential<SerialMessage<UID::Event_LickBegin>,
                                                                SerialMessage<UID::Event_Pulse5>,
                                                                AssociationSessionTimes<MultiOptoDoubleAudioTrial, 2>,
                                                                AssociationSessionTimes<MultiOptoDoubleAudioTrial4, 1>, 
                                                                AssociationSessionTimes<MultiOptoDoubleAudioTrial, 5>,
                                                                AssociationSessionTimes<MultiOptoDoubleAudioTrial41, 1>, 
                                                                AssociationSessionTimes<MultiOptoDoubleAudioTrial, 4>,
                                                                AssociationSessionTimes<MultiOptoDoubleAudioTrial, 5> >> },*/
  /*{ UID::Session_MultiOptoDoubleAudioTask3, Session<Sequential<AssociationSessionTimes<MultiOptoDoubleAudioTrialPre2, 5>, 
                                                              AssociationSessionTimes<MultiOptoDoubleAudioTrial2, 20>,
                                                              AssociationSessionTimes<MultiOptoDoubleAudioTrialPre2, 5>, 
                                                              AssociationSessionTimes<MultiOptoDoubleAudioTrial2, 20>>> },
  { UID::Session_LaserOnly, Session<Sequential< AssociationSessionTimes<MultiOptoDoubleAudioTrialPre, 5>, AssociationSessionTimes<LaserOnlyTrial, 3> >> },
  /*{ UID::Session_DoubleAudioTask, Session<Sequential< AssociationSessionTimes<DoubleAudioTrial, 20>>> },
  { UID::Session_MultiOptoTripeAudioTask, Session<Sequential<AssociationSessionTimes<MultiOptoTripleAudioTrialPre2, 20>, 
                                                             AssociationSessionTimes<MultiOptoTripleAudioTrial, 10>>> },
  { UID::Session_MultiOptoTripeAudioTask2, Session<Sequential<AssociationSessionTimes<MultiOptoTripleAudioTrialPre2, 5>, 
                                                             AssociationSessionTimes<MultiOptoTripleAudioTrial2, 10>>> },
  { UID::Session_MultiOptoTripeAudioTask3, Session<Sequential<AssociationSessionTimes<MultiOptoTripleAudioTrial2, 10>>> },*/
  /*{ UID::Session_QuadrupleAudioShaping, Session<AssociationSessionTimes<QuadrupleAudioTrialPre, 100>> },
  { UID::Session_MultiOptoQuadrupleAudioTask, Session<Sequential<AssociationSessionTimes<MultiOptoQuadrupleAudioTrialPre, 20>, 
                                                             AssociationSessionTimes<MultiOptoQuadrupleAudioTrial, 5>>> },*/
  /*{ UID::Session_MultiOptoQuadrupleAudioTask2, Session<Sequential<AssociationSessionTimes<MultiOptoQuadrupleAudioTrialPre, 5>, 
                                                             AssociationSessionTimes<MultiOptoQuadrupleAudioTrial, 5>>> },*/
};