%[text] `早期起始细胞标定（文献定义）在延迟范式成像数据中的验证图。`
%
% 数据来源：TransferLearning.ALDelayed（声水→光水延迟，训练模态为声）与
% TransferLearning.LADelayed（光水→声水延迟，训练模态为光）。
%
% 延迟范式里线索后最先出现的是等待期的预期性舔舐（约0.4~0.8 s），学会的定时反应在约1.65~2.5 s。
% 因此运动起始取 EventLog 的"命中"时刻（MovementOnset="outcome"），二值化运动序列截断到该时刻之后。
% ALDelayed：RT 限 1.0~2.0 s（保证运动起始+1 s 仍在 [-3,+3] s 成像窗内）。
% LADelayed：RT 约 2.5 s，运动起始后成像窗只剩约0.5 s，故收缩起始搜索窗至 [-0.2, 0.4] s、RT 限 2.0~2.6 s。
%
% 左列：movement-active 细胞按活动起始时刻排序的 z 分数热图。
% 右列：early-onset 与 late-onset 的平均轨迹。
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

% --- 1) Analyse the trained modality of each delayed cohort
AD = TransferLearning.ALDelayed();
LD = TransferLearning.LADelayed();
RA = TransferLearning.EarlyOnsetCells(AD, Stimulus="AudioLearnWater", Designs="AudioLearnWater", ...
	MinRT=1.0, MaxRT=2.0, MovementOnset="outcome", MinTrialsPerSession=5);
RL = TransferLearning.EarlyOnsetCells(LD, Stimulus="LightLearnWater", Designs="LightLearnWater", ...
	MinRT=2.0, MaxRT=2.6, MovementOnset="outcome", MinTrialsPerSession=5, OnsetSearchWindow=[-0.2, 0.4]);

% --- 2) Plot
svgPath = TransferLearning.PlotEarlyOnsetCells(RA, RL, ...
	LabelA="AL delayed", LabelB="LA delayed", ...
	ModalityA="audio trained", ModalityB="light trained", ...
	FileName="FigEarlyOnsetCells_Delayed.svg");
fprintf('Wrote: %s\n', svgPath);

for R = {RA, RL}
	C = R{1}.Cells;
	fprintf('trials=%d cells=%d active=%d early=%d late=%d\n', R{1}.NTrials, height(C), ...
		sum(C.Class=="movement-active"), sum(C.IsEarlyOnset), ...
		sum(C.Class=="movement-active" & ~C.IsEarlyOnset & ~isnan(C.Onset)));
end
