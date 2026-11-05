%[text] `转移模态试次是否仍落在同一批 early-onset 细胞上（延迟数据库）。`
%
% 数据来源：TransferLearning.ALDelayed（声水→光水，延迟范式，训练模态=声，转移模态=光）。
% LADelayed v1 只含光水块（LightLearnWater），没有声水块，因此无法做转移对照，只能做训练模态的标定。
%
% 延迟范式的特殊性：线索后最先出现的是等待期的预期性舔舐（约0.4~0.8 s），学会的定时反应在约1.65 s。
% 因此这里用 EventLog 的"命中"时刻作为运动起始（MovementOnset="outcome"），
% 并把二值化运动序列截断到该时刻之后，避免把预期性舔舐当成运动起始。
% RT 限制在 1.0~2.0 s：上界保证运动起始+1 s 仍落在 [-3, +3] s 的成像窗内。
% 训练态只取"已学会"会话：首次出现连续两次命中率>0.80 之后的会话（TransferLearning.LearnedSessions）。
% 转移模态剔除"到平台期后掉线"的会话：yqn2200 光水最后一天(07-13)命中率跌到0.38，已到平台期，忽略
% （TransferLearning.PlateauDropouts）。
%
% 左列：训练模态 vs 转移模态的活动起始时刻散点，虚线为 y=x。
% 右列：转移模态中判为 early-onset 的比例；柱顶为"转移态early细胞数/该组细胞数"，
%       标题内为鼠内分层置换检验 p 值。
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

% --- 1) Paired analysis across sessions on matched cells
AD = TransferLearning.ALDelayed();
learnedSessions = TransferLearning.LearnedSessions(AD, "AudioLearnWater");
timing = TransferLearning.BuildTrialTiming(AD);
lightSessions = setdiff(sort(unique(timing.DateTime(timing.Design == "LightLearnWater"))), ...
	TransferLearning.PlateauDropouts(AD, "LightLearnWater"));
PD = TransferLearning.TransferOnsetCells(AD, ...
	TrainedStimulus="AudioLearnWater", TransferStimulus="LightLearnWater", ...
	TrainedDesigns="AudioLearnWater", TransferDesigns="LightLearnWater", ...
	TrainedSessions=learnedSessions, TransferSessions=lightSessions, ...
	AlignBy="cell", MinRT=1.0, MaxRT=2.0, MovementOnset="outcome", MinTrialsPerSession=5);

% --- 2) Plot
svgPath = TransferLearning.PlotTransferOnsetCells({PD, "AL delayed audio→light", "audio→light"}, ...
	FileName="FigTransferOnsetCells_Delayed.svg");
fprintf('Wrote: %s\n', svgPath);

S = PD.Stats;
fprintf(['AL delayed: cells=%d activeBoth=%d | trainedEarly=%d -> transferEarly=%d (%.1f%%), ', ...
	'trainedOther=%d -> transferEarly=%d (%.1f%%), base=%.1f%%, mousePermP=%.3f, n=%d mice\n'], ...
	S.NMatched, S.NActiveBoth, S.NTrainedEarly, S.NTrainedEarlyTransferEarly, 100*S.FracTransferEarlyGivenTrainedEarly, ...
	S.NTrainedNotEarly, S.NTrainedNotEarlyTransferEarly, 100*S.FracTransferEarlyGivenTrainedNotEarly, ...
	100*S.BaseRateTransferEarly, S.MousePermP, S.NMouse);
