%[text] `群体响应模式在转移条件下是否复现了训练条件的模式（文献Fig 1i口径）。`
%
% 指标：每个细胞取运动起始后0~0.5 s的平均z分数响应，再跨细胞求相关。
%   - 实测：训练模态 vs 转移模态
%   - 上界（虚线）：同一训练条件下把试次随机对半拆分后的两半之间
%   - 下界（点线）：细胞身份随机打乱
% 另含负对照：同一线索在学习前（Naive）与学习后（Learned/Recall）之间的一致性。
%
% 数据来源：AudioLightBaseline / LightAudioBaseline（非穿插）、ALInterspersed / LAInterspersed（穿插）、
% ALDelayed（延迟）。LADelayed v1 只含光水块、无声水块，无法做转移对照。
%
% 执行方式（硬性要求）：本文件保持脚本，不要用 run，在 MATLAB 编辑器（Editor）中直接 Run/F5。

% --- 0) Ensure project loaded
if ~exist('TransferLearning','class') || ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

Entries = cell(0, 4);

% --- 1) 非穿插：声→光
ALB = TransferLearning.AudioLightBaseline();
PB = TransferLearning.TransferOnsetCells(ALB, TrainedStimulus="AudioWater", TransferStimulus="LightWater", ...
	TrainedDesigns="AudioWater", TransferDesigns="LightWater", AlignBy="cell");
Entries(end+1, :) = iBuildEntry(PB, ALB, "AudioWater", "AudioWater", "AL");

% --- 2) 非穿插：光→声
LAB = TransferLearning.LightAudioBaseline();
PL = TransferLearning.TransferOnsetCells(LAB, TrainedStimulus="LightWater", TransferStimulus="AudioWater", ...
	TrainedDesigns="LightWater", TransferDesigns="AudioWater", AlignBy="cell");
Entries(end+1, :) = iBuildEntry(PL, LAB, "LightWater", "LightWater", "LA");

% --- 3) 延迟：声→光（训练态只取已学会会话；转移态剔除平台期后的掉线会话）
AD = TransferLearning.ALDelayed();
delayedLearnedSessions = TransferLearning.LearnedSessions(AD, "AudioLearnWater");
delayedTiming = TransferLearning.BuildTrialTiming(AD);
delayedLight = setdiff(sort(unique(delayedTiming.DateTime(delayedTiming.Design == "LightLearnWater"))), ...
	TransferLearning.PlateauDropouts(AD, "LightLearnWater"));
PD = TransferLearning.TransferOnsetCells(AD, TrainedStimulus="AudioLearnWater", TransferStimulus="LightLearnWater", ...
	TrainedDesigns="AudioLearnWater", TransferDesigns="LightLearnWater", ...
	TrainedSessions=delayedLearnedSessions, TransferSessions=delayedLight, AlignBy="cell", ...
	MinRT=1.0, MaxRT=2.0, MovementOnset="outcome", MinTrialsPerSession=5);
Entries(end+1, :) = iBuildEntry(PD, AD, "AudioLearnWater", "AudioLearnWater", "AL delayed", ...
	MinRT=1.0, MaxRT=2.0, MovementOnset="outcome", MinTrialsPerSession=5, LearnedSessions=delayedLearnedSessions);
% --- 4) 负对照：同一线索学习前 vs 学习后（仅非穿插声数据可用）
T0 = TransferLearning.BuildTrialTiming(ALB);
naiveSessions = sort(unique(T0.DateTime(T0.Design=="AudioWater" & T0.Phase=="Naive")));
learnedSessions = sort(unique(T0.DateTime(T0.Design=="AudioWater" & ismember(T0.Phase, ["Learned","Recall"]))));
RN = TransferLearning.EarlyOnsetCells(ALB, Stimulus="AudioWater", Designs="AudioWater", ...
	Sessions=naiveSessions, MinTrialsPerSession=3, ExcludePhases=strings(1, 0));
RLa = TransferLearning.EarlyOnsetCells(ALB, Stimulus="AudioWater", Designs="AudioWater", ...
	Sessions=learnedSessions, MinTrialsPerSession=3);
Control = TransferLearning.OnsetAgreement(RN, RLa, AlignBy="cell");
Entries(end+1, :) = {Control.Stats.MeanResponseCorrelation, NaN, Control.Stats.MeanResponseCorrelationNull, "AL naive vs learned"};

% --- 5) Plot
svgPath = TransferLearning.PlotPatternAgreement(Entries, FileName="FigPatternAgreement.svg");
fprintf('Wrote: %s\n', svgPath);

for iEntry = 1:size(Entries, 1)
	fprintf('%-22s R=%.3f  ceiling=%.3f  floor=%.3f\n', Entries{iEntry, 4}, ...
		Entries{iEntry, 1}, Entries{iEntry, 2}, Entries{iEntry, 3});
end

function entry = iBuildEntry(P, DS, trainedStimulus, trainedDesign, label, Options)
arguments
	P
	DS
	trainedStimulus (1,1) string
	trainedDesign (1,1) string
	label (1,1) string
	Options.MinRT (1,1) double = 0.10
	Options.MaxRT (1,1) double = 0.50
	Options.MovementOnset (1,1) string = "lick"
	Options.MinTrialsPerSession (1,1) double = 3
	Options.LearnedSessions (:,1) datetime = NaT(0, 1)
end
shared = {'Designs', trainedDesign, 'MinRT', Options.MinRT, 'MaxRT', Options.MaxRT, ...
	'MovementOnset', Options.MovementOnset, 'MinTrialsPerSession', Options.MinTrialsPerSession, 'Sessions', Options.LearnedSessions};
half1 = TransferLearning.EarlyOnsetCells(DS, 'Stimulus', trainedStimulus, 'TrialFraction', 0.5, 'TrialSeed', 1, shared{:});
half2 = TransferLearning.EarlyOnsetCells(DS, 'Stimulus', trainedStimulus, 'TrialFraction', 0.5, 'TrialSeed', 2, shared{:});

aTrained = TransferLearning.CellResponseTable(P.Trained);
aTransfer = TransferLearning.CellResponseTable(P.Transfer);
aHalf1 = TransferLearning.CellResponseTable(half1);
aHalf2 = TransferLearning.CellResponseTable(half2);
J = innerjoin(innerjoin(innerjoin(aTrained, aTransfer, 'Keys', 'Key'), aHalf1, 'Keys', 'Key'), aHalf2, 'Keys', 'Key');
ok = J.ActiveFrac_aTrained >= 0.5 & J.ActiveFrac_aTransfer >= 0.5 & ...
	J.ActiveFrac_left >= 0.5 & J.ActiveFrac_aHalf2 >= 0.5;
observed = corr(J.RespMove_aTrained(ok), J.RespMove_aTransfer(ok));
ceiling = corr(J.RespMove_left(ok), J.RespMove_aHalf2(ok));

stream = RandStream('Threefry', 'Seed', 42);
shuffled = zeros(1000, 1);
target = J.RespMove_aTransfer(ok);
for iShuffle = 1:1000
	shuffled(iShuffle) = corr(J.RespMove_aTrained(ok), target(randperm(stream, numel(target))));
end
entry = {observed, ceiling, median(shuffled), label};
end
