% 英文图3B的0.3 s版本：前段保持不变，训练与测试后段均缩短，并保留±250 ms跨界平滑。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	PrjFile = fullfile(ThisDir, '..', 'Transferlearning.prj');
	if exist(PrjFile, 'file')
		matlab.project.loadProject(PrjFile);
	end
end
rng(42, 'twister');
RowSpecs = ["Naive", "AudioOnly", "Naive 🔊"; "Learned", "AudioWater", "Learned 🔊💧"];
Fig3B_Post300msStats = TransferLearning.PlotLocalWindowCueTransferRows(RowSpecs, "3B (post 0.3 s)", "English_Fig3B_LocalWindow_GapDecoderTransfer_Post300ms.svg", 0.3);
assignin('base', 'Fig3B_Post300msStats', Fig3B_Post300msStats);