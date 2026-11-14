% 英文图3B：1×3的1 s局部均值叠加图，按Naive声与Learned声水训练区分颜色，并用共享图例说明。
% 三列依次测试Learned声水、12 h光水和7 d光水；第一列合并两队列，所有情境使用共同细胞。
% Learned声水训练在第一列使用trial-aware五折OOF自测，标准化仅用各折训练样本；外部测试trial与训练不重叠。
% 保留±250 ms跨界平滑和200次训练标签shuffle；八项Holm校正不变，同列两条曲线均显著时在1 s上方只标一个共享星号。

%% 计算
thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(thisDir,'..','Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end
rng(42,'twister');
Fig3B_LocalWindowPlotData = TransferLearning.ComputeLocalWindowGapDecoderMatrix();
assignin('base', 'Fig3B_LocalWindowPlotData', Fig3B_LocalWindowPlotData);

%% 作图
if ~exist('Fig3B_LocalWindowPlotData', 'var')
	PlotDataPath = TransferLearning.CachePath('Fig3B_LocalWindow_GapDecoderTransfer_PlotData_Results.mat');
	assert(isfile(PlotDataPath), 'Fig3BMatrix:MissingPlotData', '没有预计算绘图数据，请先运行计算节。');
	SavedPlotData = load(PlotDataPath, 'PlotData');
	Fig3B_LocalWindowPlotData = SavedPlotData.PlotData;
end
Fig3B_LocalWindowDecoderStats = TransferLearning.PlotLocalWindowGapDecoderMatrix(Fig3B_LocalWindowPlotData, "English_Fig3B_LocalWindow_GapDecoderTransfer.svg");
assignin('base', 'Fig3B_LocalWindowDecoderStats', Fig3B_LocalWindowDecoderStats);

