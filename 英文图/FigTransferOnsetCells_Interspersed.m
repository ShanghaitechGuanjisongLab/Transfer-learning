%[text] `转移模态试次是否仍落在同一批 early-onset 细胞上（穿插数据库）。`
%
% 数据来源：TransferLearning.ALInterspersed（声光穿插迁移，训练模态=声，转移模态=光）与
% TransferLearning.LAInterspersed（光声穿插迁移，训练模态=光，转移模态=声）。
% 均为 Interspersed（穿插）成像行为数据库。
%
% 穿插数据库的训练模态与转移模态试次位于同一会话的同一Block内（AL: LwAuw；LA: LAuWLwAuw），
% 因此按 (Mouse, Session, CellUID) 直接对齐，无需跨天配准。
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

% --- 1) Paired analysis within the interspersed blocks
AL = TransferLearning.ALInterspersed();
LA = TransferLearning.LAInterspersed();
PA = TransferLearning.TransferOnsetCells(AL, ...
	TrainedStimulus="AudioWater", TransferStimulus="LightWater", ...
	TrainedDesigns="LwAuw", TransferDesigns="LwAuw", AlignBy="session");
PL = TransferLearning.TransferOnsetCells(LA, ...
	TrainedStimulus="LightWater", TransferStimulus="AudioWater", ...
	TrainedDesigns="LAuWLwAuw", TransferDesigns="LAuWLwAuw", AlignBy="session");

% --- 2) Plot
svgPath = TransferLearning.PlotTransferOnsetCells({PA, "AL audio→light", "audio→light"; PL, "LA light→audio", "light→audio"}, ...
	FileName="FigTransferOnsetCells_Interspersed.svg");
fprintf('Wrote: %s\n', svgPath);

for P = {PA, PL}
	S = P{1}.Stats;
	fprintf(['cells=%d activeBoth=%d | trainedEarly=%d -> transferEarly=%d (%.1f%%), ', ...
		'trainedOther=%d -> transferEarly=%d (%.1f%%), base=%.1f%%, mousePermP=%.3f, onset rho=%.2f (n=%d)\n'], ...
		S.NMatched, S.NActiveBoth, S.NTrainedEarly, S.NTrainedEarlyTransferEarly, 100*S.FracTransferEarlyGivenTrainedEarly, ...
		S.NTrainedNotEarly, S.NTrainedNotEarlyTransferEarly, 100*S.FracTransferEarlyGivenTrainedNotEarly, ...
		100*S.BaseRateTransferEarly, S.MousePermP, S.OnsetSpearman, S.NOnsetPaired);
end
