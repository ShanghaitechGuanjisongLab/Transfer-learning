%[text] `转移模态试次是否仍落在同一批 early-onset 细胞上（非穿插数据库）。`
%
% 数据来源：TransferLearning.AudioLightBaseline（声水→光水，训练模态=声，转移模态=光）与
% TransferLearning.LightAudioBaseline（光水→声水，训练模态=光，转移模态=声）。
%
% 非穿插数据库的训练模态与转移模态分处不同会话，因此按 (Mouse, CellUID) 跨会话聚合对齐：
% movement-active 比例取各会话均值（>=0.5 记为活跃）、onset 取各会话中位数、
% cue 锁定轨迹取各会话均值。训练模态取排除 Naive 后的纯模态块，转移模态取另一模态的纯块。
%
% 左列：训练模态 vs 转移模态的活动起始时刻散点（仅双模态均 movement-active 且起始可检出），
%       虚线为 y=x。
% 右列：转移模态中被判为 early-onset 的比例，分"训练模态中为 early-onset"与
%       "训练模态中非 early-onset"两组；柱顶数字为"转移态early细胞数/该组细胞数"，
%       标题内为超几何检验 p 值。
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
AL = TransferLearning.AudioLightBaseline();
LA = TransferLearning.LightAudioBaseline();
PA = TransferLearning.TransferOnsetCells(AL, ...
	TrainedStimulus="AudioWater", TransferStimulus="LightWater", ...
	TrainedDesigns="AudioWater", TransferDesigns="LightWater", AlignBy="cell");
PL = TransferLearning.TransferOnsetCells(LA, ...
	TrainedStimulus="LightWater", TransferStimulus="AudioWater", ...
	TrainedDesigns="LightWater", TransferDesigns="AudioWater", AlignBy="cell");

% --- 2) Plot
svgPath = TransferLearning.PlotTransferOnsetCells({PA, "AL audio→light", "audio→light"; PL, "LA light→audio", "light→audio"}, ...
	FileName="FigTransferOnsetCells.svg");
fprintf('Wrote: %s\n', svgPath);

for P = {PA, PL}
	S = P{1}.Stats;
	fprintf(['cells=%d activeBoth=%d | trainedEarly=%d -> transferEarly=%d (%.1f%%), ', ...
		'trainedOther=%d -> transferEarly=%d (%.1f%%), base=%.1f%%, mousePermP=%.3f, onset rho=%.2f (n=%d)\n'], ...
		S.NMatched, S.NActiveBoth, S.NTrainedEarly, S.NTrainedEarlyTransferEarly, 100*S.FracTransferEarlyGivenTrainedEarly, ...
		S.NTrainedNotEarly, S.NTrainedNotEarlyTransferEarly, 100*S.FracTransferEarlyGivenTrainedNotEarly, ...
		100*S.BaseRateTransferEarly, S.MousePermP, S.OnsetSpearman, S.NOnsetPaired);
end
