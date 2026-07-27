% 中文图342F：初始/迁移光水在基线窗 [-3,0] s 的 DeltaF NTATS 时间维标准差

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "中文图Fig52B_BaselineTemporalStd_NaiveTransfer_ByLayer.svg";

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 2
	error('Fig342F:BadBaselineWindow', 'Baseline window [-3,0] s contains too few samples.');
end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["MOp2/3"; "MOp5"];
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

naiveLab = iCollectMouseLayerTemporalStd(LAB, "Naive", "LightWater", string.empty(0,1), "Naive", "LAB", baseMask, layers);
badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
naiveLaiMice = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badNaive);
naiveLai = iCollectMouseLayerTemporalStd(LAI, "Naive", "LightWater", naiveLaiMice, "Naive", "LAI", baseMask, layers);
transferAlb = iCollectMouseLayerTemporalStd(ALB, "Transfer", "LightWater", string.empty(0,1), "Transfer", "ALB", baseMask, layers);

T = [naiveLab; naiveLai; transferAlb];
if isempty(T)
	error('Fig342F:Empty', 'No valid mouse-level temporal-std rows were built.');
end

Stats = table(layerLabels, nan(2,1), nan(2,1), nan(2,1), nan(2,1), nan(2,1), nan(2,1), nan(2,1), nan(2,1), ...
	'VariableNames', {'Layer', 'NaiveMean', 'TransferMean', 'NaiveN', 'TransferN', 'NaiveCells', 'TransferCells', 'PValue', 'DeltaMean'});
%% 

f = figure('Color', 'w', 'Name', 'Fig342F baseline temporal std by layer');
f.Units = 'centimeters';
f.Position(3:4) = [4, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4, 8];
f.PaperSize = [4, 8];

layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
ylabel(layout, '💡💧 Baseline temporal std', 'FontSize', 6);

for iL = 1:numel(layers)
	layerName = layers(iL);
	xNaive = double(T.MeanTemporalStd(T.Group == "Naive" & T.Layer == layerName));
	xTran = double(T.MeanTemporalStd(T.Group == "Transfer" & T.Layer == layerName));
	nCellsNaive = sum(T.NCells(T.Group == "Naive" & T.Layer == layerName), 'omitnan');
	nCellsTran = sum(T.NCells(T.Group == "Transfer" & T.Layer == layerName), 'omitnan');
	xNaive = xNaive(isfinite(xNaive));
	xTran = xTran(isfinite(xTran));
	if isempty(xNaive) || isempty(xTran)
		error('Fig342F:EmptyLayer', 'Layer %s has empty Naive or Transfer values.', layerName);
	end
	p = ranksum(xNaive, xTran);
	Stats.NaiveMean(iL) = mean(xNaive, 'omitnan');
	Stats.TransferMean(iL) = mean(xTran, 'omitnan');
	Stats.NaiveN(iL) = numel(xNaive);
	Stats.TransferN(iL) = numel(xTran);
	Stats.NaiveCells(iL) = nCellsNaive;
	Stats.TransferCells(iL) = nCellsTran;
	Stats.PValue(iL) = p;
	Stats.DeltaMean(iL) = Stats.TransferMean(iL) - Stats.NaiveMean(iL);

	fprintf('\n=== Fig342F %s ===\n', layerLabels(iL));
	fprintf('Naive:    %.4f ± %.4f (n=%d mice, %d cells)\n', mean(xNaive), std(xNaive) / sqrt(numel(xNaive)), numel(xNaive), round(nCellsNaive));
	fprintf('Transfer: %.4f ± %.4f (n=%d mice, %d cells)\n', mean(xTran), std(xTran) / sqrt(numel(xTran)), numel(xTran), round(nCellsTran));
	fprintf('ranksum p = %.6g\n', p);

	ax = nexttile(layout, iL);
	[~, optional, bars, errorBars] = UniExp.BarScatterCompare({xNaive(:), xTran(:)}, compareGroup, 'AsteriskThreshold', 1);
	TransferLearning.Style.SetBarPValues(optional);
	if isfield(optional, 'MultiCompare') && ismember('PText', optional.MultiCompare.Properties.VariableNames)
		fprintf('  BarScatterCompare on figure: PValue=%.5g PText="%s"\n', ...
			optional.MultiCompare.PValue, optional.MultiCompare.PText.String);
	end
	iStyleTile(ax, bars, errorBars, optional, TransferLearning.NaiveColor,TransferLearning.TransferColor, iL == numel(layers), layerLabels(iL));
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig342F_MouseLayerStd', T);
assignin('base', 'Fig342F_Stats', Stats);

function T = iCollectMouseLayerTemporalStd(DS, phaseName, stimulusName, mice, groupName, sourceName, baseMask, layers)
	if isempty(mice)
		mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, string.empty(0,1));
	end
	if isempty(mice)
		T = iEmptyTable();
		return;
	end
	CellMap = iCellMap(DS);
	rows = cell(numel(mice), 1);
	for iM = 1:numel(mice)
		m = mice(iM);
		G = DS.QueryNTATS(struct('Mouse', m, 'Phase', phaseName, 'Stimulus', stimulusName), UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
		[X, cellUID] = iExtractNtats2D(G);
		if isempty(X) || isempty(cellUID)
			rows{iM} = iEmptyTable();
			continue;
		end
		z = iLookupZLayer(CellMap, cellUID);
		mouseRows = iEmptyTable();
		for j = 1:numel(layers)
			mask = z == layers(j);
			if nnz(mask) < 3
				continue;
			end
			v = std(double(X(mask, baseMask)), 0, 2, 'omitnan');
			v = v(isfinite(v));
			if numel(v) < 3
				continue;
			end
			mouseRows = [mouseRows; table(string(m), string(groupName), string(sourceName), string(layers(j)), mean(v, 'omitnan'), numel(v), ...
				'VariableNames', {'Mouse', 'Group', 'Source', 'Layer', 'MeanTemporalStd', 'NCells'})]; %#ok<AGROW>
		end
		rows{iM} = mouseRows;
	end
	T = vertcat(rows{:});
end

function T = iEmptyTable()
	T = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse', 'Group', 'Source', 'Layer', 'MeanTemporalStd', 'NCells'});
end

function CellMap = iCellMap(DS)
	CellMap = DS.Cells(:, {'CellUID', 'ZLayer'});
	CellMap.CellUID = uint64(CellMap.CellUID);
	CellMap.ZLayer = string(CellMap.ZLayer);
end

function [X, cellUID] = iExtractNtats2D(G)
	X = [];
	cellUID = uint64([]);
	if isempty(G) || ~istable(G)
		return;
	end
	if ~all(ismember(["NTATS", "CellUID"], string(G.Properties.VariableNames)))
		return;
	end
	cellUID = uint64(G.CellUID);
	nt = G.NTATS;
	if isa(nt, 'MATLAB.DataTypes.NDTable')
		X = double(nt.Data);
	elseif isnumeric(nt) && ismatrix(nt)
		X = double(nt);
	else
		try
			X = double(nt{:,:});
		catch
			X = [];
		end
	end
	if size(X, 1) ~= numel(cellUID)
		X = [];
		cellUID = uint64([]);
	end
end

function z = iLookupZLayer(CellMap, cellUID)
	[tf, loc] = ismember(uint64(cellUID), CellMap.CellUID);
	z = strings(numel(cellUID), 1);
	z(tf) = CellMap.ZLayer(loc(tf));
end

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
	T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
	if isempty(T)
		mice = string.empty(0,1);
		return;
	end
	mice = unique(string(T.Mouse));
	if ~isempty(excludeMice)
		mice = mice(~ismember(mice, string(excludeMice(:))));
	end
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
	if isempty(T)
		badMice = strings(0,1);
		return;
	end
	Tr = DS.Trials;
	TrStim = string(Tr.Stimulus);
	TrBU = uint64(Tr.BlockUID);
	T.Mouse = string(T.Mouse);
	blkBU = uint64(T.BlockUID);
	mice = unique(T.Mouse);
	bad = false(size(mice));
	for i = 1:numel(mice)
		bu = blkBU(T.Mouse == mice(i));
		rows = ismember(TrBU, bu);
		bad(i) = any(TrStim(rows) == "AudioWater");
	end
	badMice = mice(bad);
end

function iStyleTile(ax, bars, errorBars, optional, colorNaive, colorTransfer, showXTick, titleText)
	ax.FontSize = 6;
	ax.LineWidth = 1;
	ax.TickDir = 'out';
	if isprop(ax.XAxis, 'LineWidth')
		ax.XAxis.LineWidth = 1;
		ax.YAxis.LineWidth = 1;
	end
	ax.XTick = [1 2];
	if showXTick
		ax.XTickLabel = {'Naive', 'Transfer'};
	else
		ax.XTickLabel = {'', ''};
	end
	box(ax, 'off');
	grid(ax, 'off');
	legend(ax, 'off');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');

	iStyleBars(bars, colorNaive, colorTransfer);
	iKeepUpperErrorBarOnly(errorBars, bars, colorNaive, colorTransfer);
	for sc = findobj(ax, 'Type', 'Scatter')'
		sc.LineWidth = 0.2;
		if isprop(sc, 'MarkerEdgeAlpha')
			sc.MarkerEdgeAlpha = 0.5;
		end
		if isprop(sc, 'MarkerFaceAlpha')
			sc.MarkerFaceAlpha = 0.6;
		end
	end
	if isstruct(optional) && isfield(optional, 'MultiCompare') && istable(optional.MultiCompare)
		if ismember('PText', optional.MultiCompare.Properties.VariableNames)
			for pt = optional.MultiCompare.PText(:)'
				pt.FontSize = 6;
				pt.Tag = 'PText';
			end
		end
		if ismember('PLine', optional.MultiCompare.Properties.VariableNames)
			if ismember('PText', optional.MultiCompare.Properties.VariableNames)
				MATLAB.Graphics.PLineRetune(optional.MultiCompare.PLine, optional.MultiCompare.PText);
			end
			for pl = optional.MultiCompare.PLine(:)'
				pl.LineWidth = 1;
				pl.Tag = 'PLine';
			end
		end
	end
end

function iStyleBars(Bars, colorNaive, colorTransfer)
	if isscalar(Bars)
		Bars.FaceColor = 'flat';
		nBar = numel(Bars.YData);
		Bars.CData = repmat([colorNaive; colorTransfer], ceil(nBar / 2), 1);
		Bars.CData = Bars.CData(1:nBar, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 1;
		Bars.BaseLine.LineWidth = 1;
		Bars.EdgeColor = 'none';
		Bars.FaceAlpha = 1;
	else
		Bars(1).FaceColor = colorNaive;
		Bars(2).FaceColor = colorTransfer;
		Bars(1).BarWidth = 0.5;
		Bars(2).BarWidth = 0.5;
		Bars(1).LineWidth = 1;
		Bars(2).LineWidth = 1;
		Bars(1).BaseLine.LineWidth = 1;
		Bars(2).BaseLine.LineWidth = 1;
		Bars(1).EdgeColor = 'none';
		Bars(2).EdgeColor = 'none';
		Bars(1).FaceAlpha = 1;
		Bars(2).FaceAlpha = 1;
	end
end

function iKeepUpperErrorBarOnly(errorBars, ~, colorNaive, colorTransfer)
	barColors = [colorNaive; colorTransfer];
	for eb = errorBars.Object(:)'
		if ~isgraphics(eb)
			continue;
		end
		eb.YNegativeDelta(:) = 0;
		eb.LineWidth = 1;
		eb.LineStyle = 'none';
		eb.HandleVisibility = 'off';
		x = double(eb.XData(:));
		[~, colorIndex] = min(abs((1:size(barColors, 1)).' - x(1)));
		eb.Color = barColors(colorIndex, :);
	end
end

function s = iFormatPValue(p)
	if ~isfinite(p)
		s = 'p = NaN';
	elseif p < 0.001
		s = 'p < 0.001';
	elseif p < 0.01
		s = sprintf('p = %.3f', p);
	else
		s = sprintf('p = %.2f', p);
	end
end