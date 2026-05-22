% Fig382D model first formal training unit L5 response heatmap.

svgName = '中文图Fig382D_ModelFirstFormalUnitDecisionHeatmap.svg';
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end

run(fullfile(fileparts(mfilename('fullpath')), 'Fig382383_LoadSharedModelData.m'));
FullCellDeltaFHeatmapData = Fig382383Data.HeatmapData;
Params = Fig382383Data.Params;
RunInfo = Fig382383Data.HeatmapRunInfo;

HeatmapData = iBuildL5RawResponseHeatmapData(FullCellDeltaFHeatmapData, Params);
[fig, PlotData] = TransferLearning.PlotModelFirstFormalUnitDecisionHeatmap(HeatmapData, ...
	YLabel=sprintf('%d L5 cells', HeatmapData.NumCells), ...
	ColorbarLabel="Response", ...
	FigureName="Model first formal unit L5 response heatmap");
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig382D_ModelDecisionHeatmapData', HeatmapData);
assignin('base', 'Fig382D_ModelDecisionHeatmapRunInfo', RunInfo);
assignin('base', 'Fig382D_ModelDecisionHeatmapPlotData', PlotData);
assignin('base', 'Fig382D_ModelDecisionHeatmapSvgPath', svgPath);

function HeatmapData = iBuildL5RawResponseHeatmapData(HeatmapData, Params)
cellsPerMouse = HeatmapData.NumCellsPerMouse;
rowWithinMouse = mod((1:HeatmapData.NumCells)' - 1, cellsPerMouse) + 1;
l5Mask = rowWithinMouse > Params.NL23;

for conditionIndex = 1:numel(HeatmapData.ConditionData)
	conditionData = HeatmapData.ConditionData{conditionIndex};
	deltaHistory = conditionData.DeltaHistory(l5Mask, :, :);
	baselineMean = conditionData.NoiseBaselineMean(l5Mask, :);
	rawHistory = deltaHistory + reshape(baselineMean, size(baselineMean, 1), 1, size(baselineMean, 2));
	conditionData.MedianDelta = median(rawHistory, 3, 'omitnan');
	conditionData.DeltaHistory = rawHistory;
	conditionData.NoiseBaselineMean = baselineMean;
	HeatmapData.ConditionData{conditionIndex} = conditionData;
end

HeatmapData.Naive = HeatmapData.ConditionData{1};
HeatmapData.Continual = HeatmapData.ConditionData{2};
HeatmapData.NumCellsPerMouse = Params.NL5RewardRecv + Params.NL5Read;
HeatmapData.NumCells = sum(l5Mask);
HeatmapData.Layer = "L5";
HeatmapData.ResponseType = "Response";
end
