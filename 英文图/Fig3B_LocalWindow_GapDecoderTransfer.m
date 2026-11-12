% 英文图3B：原3B与原3C合为2×3，使用缓存保留原来的逐鼠解码结果。
% 上排Naive AudioOnly训练，下排Learned AudioWater训练；三列为对应情境的OOF自测、12 h迁移、7 d迁移。
% 测试均为Transfer LightWater全部hit/miss；保留±250 ms局部均值、trial-aware五折CV、200次shuffle和vtf0353排除。
% 每鼠独立训练，仅汇总显示；不画null曲线或显著性。保持脚本形式，在MATLAB编辑器运行。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(thisDir,'..','Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end
rng(42,'twister');
rowSpecs = ["Naive", "AudioOnly", "Naive 🔊"; "Learned", "AudioWater", "Learned 🔊💧"];
Fig3B_LocalWindowDecoderStats = TransferLearning.PlotLocalWindowCueTransferRows(rowSpecs, "3B", "English_Fig3B_LocalWindow_GapDecoderTransfer.svg");
assignin('base', 'Fig3B_LocalWindowDecoderStats', Fig3B_LocalWindowDecoderStats);

