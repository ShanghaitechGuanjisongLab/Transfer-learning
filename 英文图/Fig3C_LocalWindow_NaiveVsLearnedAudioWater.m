% 英文图3C：2×3局部均值解码图，上排Naive AudioWater训练，下排Learned AudioWater训练。
% 第一列分别汇总对应训练情境的逐鼠OOF自测，二三列始终测试12 h/7 d队列的Transfer LightWater全部hit/miss。
% 保留±250 ms局部均值、trial-aware五折CV、200次训练标签shuffle和vtf0353排除，各鼠独立训练。
% 配色、版式沿用新3B；输出English_Fig3C_LocalWindow_NaiveVsLearnedAudioWater.svg。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
rng(42, 'twister');
rowSpecs = ["Naive", "AudioWater", "Naive 🔊💧"; "Learned", "AudioWater", "Learned 🔊💧"];
Fig3C_LocalWindowDecoderStats = TransferLearning.PlotLocalWindowCueTransferRows(rowSpecs, "3C", "English_Fig3C_LocalWindow_NaiveVsLearnedAudioWater.svg");
assignin('base', 'Fig3C_LocalWindowDecoderStats', Fig3C_LocalWindowDecoderStats);
