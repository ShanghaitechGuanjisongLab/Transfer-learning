%[text] `早期起始细胞标定（文献定义）在声水→光水与光水→声水非穿插成像数据中的验证图。`
%
% 数据来源：TransferLearning.AudioLightBaseline（声水→光水，训练模态为声）与
% TransferLearning.LightAudioBaseline（光水→声水，训练模态为光）。均为非穿插成像行为数据库。
%
% 上排：声水→光水；下排：光水→声水。
% 左列：movement-active 细胞按活动起始时刻排序的 z 分数热图，横轴为相对运动起始的时间。
% 右列：early-onset（onset<0）与 late-onset（onset>0）的平均轨迹。
%
% 图注口径：只纳入训练模态、排除 Naive 阶段、且舔舐起始落在线索后 0.10~0.50 s 的命中试次；
% 运动起始取 CD2 标通道首次超阈值时刻；活动起始取运动起始前 0.2 s 至后 1.0 s 内首个
% 超过"运动前 1~0.5 s 基线均值 + 1 SD"并维持 200 ms 的帧。
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

% --- 1) Analyse both paradigms on their trained modality
AL = TransferLearning.AudioLightBaseline();
LA = TransferLearning.LightAudioBaseline();
RA = TransferLearning.EarlyOnsetCells(AL, Stimulus="AudioWater");
RL = TransferLearning.EarlyOnsetCells(LA, Stimulus="LightWater");

% --- 2) Plot
svgPath = TransferLearning.PlotEarlyOnsetCells(RA, RL, ...
	LabelA="AL", LabelB="LA", ...
	ModalityA="audio trained", ModalityB="light trained", ...
	FileName="FigEarlyOnsetCells.svg");
fprintf('Wrote: %s\n', svgPath);

for R = {RA, RL}
	C = R{1}.Cells;
	fprintf('trials=%d cells=%d active=%d early=%d late=%d\n', R{1}.NTrials, height(C), ...
		sum(C.Class=="movement-active"), sum(C.IsEarlyOnset), ...
		sum(C.Class=="movement-active" & ~C.IsEarlyOnset & ~isnan(C.Onset)));
end
