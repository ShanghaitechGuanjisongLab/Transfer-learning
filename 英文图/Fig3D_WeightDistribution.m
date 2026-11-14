% 英文图3D：Learned声水cue前后解码器的base/cued细胞绝对系数分布及逐鼠均值插图。
% 直接使用原1 s LASSO缓存的全部AudioLightBaseline鼠；负系数支持base判别，正系数支持cued判别。
% 零系数不归入任一组，但保留在全部解码细胞的比例分母中；两组逐鼠均值采用配对符号秩检验。

ThisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	PrjFile = fullfile(ThisDir, '..', 'Transferlearning.prj');
	if exist(PrjFile, 'file')
		matlab.project.loadProject(PrjFile);
	end
end

CueData = TransferLearning.LoadLearnedCueDecoderWeights();
Models = CueData.Cohorts{1};
WBase = [];
WCued = [];
PerMouseBase = nan(numel(Models), 1);
PerMouseCued = nan(numel(Models), 1);
Mice = strings(numel(Models), 1);
TotalCells = 0;
NZero = 0;
for MouseIndex = 1:numel(Models)
	Model = Models{MouseIndex};
	Weights = Model.Weights;
	BaseWeights = abs(Weights(Weights < 0));
	CuedWeights = Weights(Weights > 0);
	WBase = [WBase; BaseWeights];
	WCued = [WCued; CuedWeights];
	Mice(MouseIndex) = Model.Mouse;
	TotalCells = TotalCells + Model.NCells;
	NZero = NZero + Model.NZero;
	if ~isempty(BaseWeights)
		PerMouseBase(MouseIndex) = mean(BaseWeights);
	end
	if ~isempty(CuedWeights)
		PerMouseCued(MouseIndex) = mean(CuedWeights);
	end
end
assert(numel(WBase) + numel(WCued) + NZero == TotalCells);
PairedMice = isfinite(PerMouseBase) & isfinite(PerMouseCued);
PerMouseBase = PerMouseBase(PairedMice);
PerMouseCued = PerMouseCued(PairedMice);
PairedNames = Mice(PairedMice);
PPaired = signrank(PerMouseBase, PerMouseCued, 'method', 'exact');
fprintf('3D逐鼠绝对cue系数：base %.6f ± %.6f，cued %.6f ± %.6f，n=%d，配对p=%.9g。\n', mean(PerMouseBase), std(PerMouseBase) / sqrt(numel(PerMouseBase)), mean(PerMouseCued), std(PerMouseCued) / sqrt(numel(PerMouseCued)), numel(PerMouseBase), PPaired);
ColorBase = TransferLearning.ColorMiss / 255;
ColorCued = TransferLearning.ColorHit / 255;

%% 主图
Fig = figure('Color', 'w', 'Name', '英文图3D：base/cued绝对cue权重分布');
Fig.Units = 'centimeters';
Fig.Position(3:4) = [9, 8];
Fig.PaperUnits = 'centimeters';
Fig.PaperSize = [9, 8];
Fig.PaperPositionMode = 'auto';
hold('on');
AxMain = gca;
Edges = linspace(0, max([WBase; WCued]), 41);
BinCenters = (Edges(1:end - 1) + Edges(2:end)) / 2;
CountsBase = histcounts(WBase, Edges);
CountsCued = histcounts(WCued, Edges);
assert(sum(CountsBase) == numel(WBase) && sum(CountsCued) == numel(WCued));
plot(AxMain, BinCenters, CountsBase / TotalCells, '-', 'Color', ColorBase, 'DisplayName', 'base');
plot(AxMain, BinCenters, CountsCued / TotalCells, '-', 'Color', ColorCued, 'DisplayName', 'cued');
xlabel(AxMain, '|cue decoder weight|');
ylabel(AxMain, 'Proportion of all decoder cells');
box(AxMain, 'off');
AxMain.Color = 'none';
legend(AxMain, 'Location', 'northeast', 'Box', 'off');
if isprop(AxMain, 'Toolbar') && ~isempty(AxMain.Toolbar)
	AxMain.Toolbar.Visible = 'off';
end
SvgPath = TransferLearning.ExportStandardFigure(Fig, 2, 'English_Fig3D_WeightDistribution.svg');
fprintf('3D细胞：总计%d，base %d，cued %d，未加权零系数%d。\n', TotalCells, numel(WBase), numel(WCued), NZero);

%% 插图
FigInset = figure('Color', 'none', 'Name', '英文图3D插图：逐鼠base/cued平均绝对cue权重');
FigInset.Units = 'centimeters';
FigInset.Position(3:4) = [4, 4];
FigInset.PaperUnits = 'centimeters';
FigInset.PaperSize = [4, 4];
FigInset.PaperPositionMode = 'auto';
DataCell = {double(PerMouseBase(:)), double(PerMouseCued(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
AxInset = gca;
set(AxInset, 'XTick', [1, 2], 'XTickLabel', {'base', 'cued'});
ylabel(AxInset, 'Mean |w|');
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = [ColorBase; ColorCued];
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
	Bars.BarWidth = 0.5;
else
	Bars(1).FaceColor = ColorBase;
	Bars(2).FaceColor = ColorCued;
	for BarIndex = 1:numel(Bars)
		Bars(BarIndex).EdgeColor = 'none';
		Bars(BarIndex).FaceAlpha = 1;
		Bars(BarIndex).BarWidth = 0.5;
	end
end
if istable(ErrorBars) && ~isempty(ErrorBars) && ismember('Object', ErrorBars.Properties.VariableNames)
	BarColors = [ColorBase; ColorCued];
	for ErrorIndex = 1:height(ErrorBars)
		ErrorBar = ErrorBars.Object(ErrorIndex);
		if isgraphics(ErrorBar) && ErrorIndex <= size(BarColors, 1)
			ErrorBar.Color = BarColors(ErrorIndex, :);
		end
	end
end
if isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare)
	Comparisons = Optional.MultiCompare;
	if ismember('PText', Comparisons.Properties.VariableNames)
		for ComparisonIndex = 1:height(Comparisons)
			PText = Comparisons.PText(ComparisonIndex);
			if isgraphics(PText)
				PText.String = TransferLearning.Style.iFormatPText(PPaired);
				PText.Tag = 'PText';
				PText.UserData = struct('Method', "PairedSignedRank", 'PValue', PPaired, 'Classes', ["base", "cued"]);
			end
		end
	end
	if ismember('PLine', Comparisons.Properties.VariableNames)
		for ComparisonIndex = 1:height(Comparisons)
			PLine = Comparisons.PLine(ComparisonIndex);
			if isgraphics(PLine)
				PLine.Tag = 'PLine';
			end
		end
	end
end
box(AxInset, 'off');
AxInset.Color = 'none';
legend(AxInset, 'off');
if isprop(AxInset, 'Toolbar') && ~isempty(AxInset.Toolbar)
	AxInset.Toolbar.Visible = 'off';
end
SvgInset = TransferLearning.ExportStandardFigureTransparent(FigInset, 1, 'English_Fig3D_PerMouseMeanWeight_Inset.svg');
Fig3D_WeightStats = struct('WBase', WBase, 'WCued', WCued, 'TotalCells', TotalCells, 'NZero', NZero, 'Mice', Mice, 'PairedMice', PairedNames, 'PerMouseBase', PerMouseBase, 'PerMouseCued', PerMouseCued, 'PPaired', PPaired, 'Edges', Edges, 'CountsBase', CountsBase, 'CountsCued', CountsCued, 'SourceCache', CueData.SourceCache, 'WeightType', CueData.WeightType, 'Figure', Fig, 'InsetFigure', FigInset, 'Axes', AxMain, 'InsetAxes', AxInset, 'InsetOptional', Optional, 'SvgPath', SvgPath, 'SvgInset', SvgInset);
assignin('base', 'Fig3D_WeightStats', Fig3D_WeightStats);
