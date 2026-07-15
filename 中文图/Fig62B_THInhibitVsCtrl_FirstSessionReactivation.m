% 中文图62B：TH抑制与对照组首会话重激活率
%
% 样式模仿中文图45E中的上下双 bar tile：
% - 上下双 tile
% - 白底
% - 仅下 tile 显示 Ctrl/TH xticklabels
% - Ctrl 使用 Continual 标准色，TH 使用 ColorA，不透明柱
%
% Reactivation = P(Transfer active | Learned AudioWater active) at 1 s
% 按鼠汇总，2/3层与5层分开计算。

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "中文图Fig62B_THInhibitVsCtrl_FirstSessionReactivation.svg";

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

RCtrl = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayerLocal(CtrlDS, "AudioLightBaseline");
RTH = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayerLocal(THDS, "THInhibit");

if isempty(RCtrl) || isempty(RTH)
	error('Fig62B:Empty', 'No valid mice for first-session reactivation comparison.');
end

R = outerjoin(RCtrl, RTH, 'Keys', 'Mouse', 'MergeKeys', true, 'Type', 'full');

xCtrl23 = double(RCtrl.Prob23);
xTH23 = double(RTH.Prob23);
xCtrl5 = double(RCtrl.Prob5);
xTH5 = double(RTH.Prob5);

xCtrl23 = xCtrl23(isfinite(xCtrl23));
xTH23 = xTH23(isfinite(xTH23));
xCtrl5 = xCtrl5(isfinite(xCtrl5));
xTH5 = xTH5(isfinite(xTH5));

if isempty(xCtrl23) || isempty(xTH23) || isempty(xCtrl5) || isempty(xTH5)
	error('Fig62B:NoFiniteData', 'No finite layer-wise reactivation values in one or both groups.');
end

ctrlCells23 = sum(double(RCtrl.NLearnedActive23), 'omitnan');
thCells23 = sum(double(RTH.NLearnedActive23), 'omitnan');
ctrlCells5 = sum(double(RCtrl.NLearnedActive5), 'omitnan');
thCells5 = sum(double(RTH.NLearnedActive5), 'omitnan');

fprintf('\n=== Fig62B MOp2/3 reactivation ===\n');
fprintf('Ctrl: %.3f ± %.3f (n=%d)\n', mean(xCtrl23), std(xCtrl23) / sqrt(numel(xCtrl23)), numel(xCtrl23));
fprintf('TH:   %.3f ± %.3f (n=%d)\n', mean(xTH23), std(xTH23) / sqrt(numel(xTH23)), numel(xTH23));
fprintf('Learned-audio active cells: Ctrl=%d, TH=%d\n', ctrlCells23, thCells23);

fprintf('\n=== Fig62B MOp5 reactivation ===\n');
fprintf('Ctrl: %.3f ± %.3f (n=%d)\n', mean(xCtrl5), std(xCtrl5) / sqrt(numel(xCtrl5)), numel(xCtrl5));
fprintf('TH:   %.3f ± %.3f (n=%d)\n', mean(xTH5), std(xTH5) / sqrt(numel(xTH5)), numel(xTH5));
fprintf('Learned-audio active cells: Ctrl=%d, TH=%d\n', ctrlCells5, thCells5);
fprintf('Reactivation comparison: Spearman rho is not applicable.\n');
%% 

f = figure('Color', 'w', 'Name', 'Fig62B TH first-session reactivation');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
ylabel(layout, 'Reactivation', 'FontSize', 6);
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});

nexttile(layout, 1);
[~, options23, bars23, errorBars23] = UniExp.BarScatterCompare({xCtrl23(:), xTH23(:)}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
delete(findobj(gca, 'Type', 'Scatter'));
iStyleTile(gca, bars23, errorBars23, false, 'MOp2/3');
TransferLearning.Style.SetBarPValues(options23);
fprintf('\n=== Figure caption (6.2B MOp2/3): %s ===\n', ...
	TransferLearning.Style.iFormatPText(options23.MultiCompare.PValue(1)));

nexttile(layout, 2);
[~, options5, bars5, errorBars5] = UniExp.BarScatterCompare({xCtrl5(:), xTH5(:)}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
delete(findobj(gca, 'Type', 'Scatter'));
iStyleTile(gca, bars5, errorBars5, true, 'MOp5');
TransferLearning.Style.SetBarPValues(options5);
fprintf('\n=== Figure caption (6.2B MOp5): %s ===\n', ...
	TransferLearning.Style.iFormatPText(options5.MultiCompare.PValue(1)));

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig62B_ReactivationTable', R);
assignin('base', 'Fig62B_ReactivationOptions23', options23);
assignin('base', 'Fig62B_ReactivationOptions5', options5);
assignin('base', 'Fig62B_ReactivationCells23', [ctrlCells23, thCells23]);
assignin('base', 'Fig62B_ReactivationCells5', [ctrlCells5, thCells5]);

function iStyleTile(ax, bars, errorBars, showXTick, titleText)
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ax.YLim(1) = 0;
ax.XTick = [1 2];
if showXTick
	ax.XTickLabel = {'Control', 'TH'};
else
	ax.XTickLabel = {};
end
box(ax, 'off');
grid(ax, 'off');
legend(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');

colorCtrl = TransferLearning.ContinualColor;
colorTH = TransferLearning.ColorB;
if isscalar(bars)
	bars.FaceColor = 'flat';
	nBars = numel(bars.YData);
	barColors = repmat([colorCtrl; colorTH], ceil(nBars / 2), 1);
	bars.CData = barColors(1:nBars, :);
	bars.BarWidth = 0.5;
	bars.LineWidth = 1;
	bars.BaseLine.LineWidth = 1;
	try, bars.FaceAlpha = 1; catch, end
	try, bars.EdgeColor = 'none'; catch, end
else
	if numel(bars) >= 2
		bars(1).FaceColor = colorCtrl;
		bars(1).LineWidth = 1;
		bars(1).BaseLine.LineWidth = 1;
		try, bars(1).FaceAlpha = 1; catch, end
		try, bars(1).EdgeColor = 'none'; catch, end
		bars(2).FaceColor = colorTH;
		bars(2).LineWidth = 1;
		bars(2).BaseLine.LineWidth = 1;
		try, bars(2).FaceAlpha = 1; catch, end
		try, bars(2).EdgeColor = 'none'; catch, end
	end
end

colors = [colorCtrl; colorTH];
for iE = 1:height(errorBars)
	eb = errorBars.Object(iE);
	eb.LineWidth = 1;
	xData = double(eb.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - xData(1)));
	eb.Color = colors(colorIndex, :);
end
for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 1;
end
end

function iApplyPText(options, pValue)
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PText', options.MultiCompare.Properties.VariableNames)
	for pt = options.MultiCompare.PText(:)'
		pt.FontSize = 6;
		pt.String = iFormatPValue(pValue);
		pt.Tag = 'PText';
	end
end
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PLine', options.MultiCompare.Properties.VariableNames)
	for pl = options.MultiCompare.PLine(:)'
		pl.LineWidth = 0.5;
		pl.Tag = 'PLine';
	end
end
end

function R = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayerLocal(DS, sourceName)
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig62B:No1s', 'Cannot find sample close to 1 s.');
end

TLearn = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
TTran = DS.TableQuery(["Mouse","DateTime","Behavior"], Phase="Transfer", Stimulus="LightWater", Design="LightWater");

if isempty(TLearn) || isempty(TTran)
	R = iEmptyResult();
	return;
end

TLearn.Mouse = string(TLearn.Mouse);
TLearn.DateTime = iNormalizeDateTime(TLearn.DateTime);
TTran.Mouse = string(TTran.Mouse);
TTran.DateTime = iNormalizeDateTime(TTran.DateTime);

dtLearnT = groupsummary(TLearn, "Mouse", "max", "DateTime");
	dtLearnT.Properties.VariableNames{end} = 'DateTimeLearned';
dtTranT = groupsummary(TTran(:, ["Mouse","DateTime"]), "Mouse", "min", "DateTime");
	dtTranT.Properties.VariableNames{end} = 'DateTimeTransfer';

Sess = innerjoin(dtLearnT(:, ["Mouse","DateTimeLearned"]), dtTranT(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');
if isempty(Sess)
	R = iEmptyResult();
	return;
end

CellMeta = DS.Cells(:, ["CellUID","ZLayer"]);
CellMeta.CellUID = uint64(CellMeta.CellUID);
CellMeta.ZLayer = string(CellMeta.ZLayer);

rows = repmat(iEmptyResult(), 0, 1);
for iRow = 1:height(Sess)
	mouseName = string(Sess.Mouse(iRow));
	dtLearned = Sess.DateTimeLearned(iRow);
	dtTransfer = Sess.DateTimeTransfer(iRow);

	GLearn = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dtLearned, ...
		'Phase', 'Learned', 'Stimulus', 'AudioWater', 'Design', 'AudioWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	GTran = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dtTransfer, ...
		'Phase', 'Transfer', 'Stimulus', 'LightWater', 'Design', 'LightWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

	[XLearn, cellLearn] = iExtractNtats2D(GLearn);
	[XTran, cellTran] = iExtractNtats2D(GTran);
	if isempty(XLearn) || isempty(XTran)
		continue;
	end

	[commonCells, idxL, idxT] = intersect(cellLearn, cellTran, 'stable');
	if isempty(commonCells)
		continue;
	end

	XLearn = XLearn(idxL, :);
	XTran = XTran(idxT, :);
	cellLayers = iMapLayer(CellMeta, commonCells);

	learnedActive = iIsActiveAt1s(XLearn, baseMask, idx1s, 3);
	transferActive = iIsActiveAt1s(XTran, baseMask, idx1s, 3);
	mask23 = iIsLayer23(cellLayers);
	mask5 = iIsLayer5(cellLayers);

	[n23, prob23] = iConditionalProb(learnedActive, transferActive, mask23);
	[n5, prob5] = iConditionalProb(learnedActive, transferActive, mask5);
	beh = double(TTran.Behavior(TTran.Mouse == mouseName & TTran.DateTime == dtTransfer));
	transferHitRate = mean(beh, 'omitnan');

	rows = [rows; table(mouseName, dtLearned, dtTransfer, transferHitRate, ...
		n23, n5, prob23, prob5, string(sourceName), ...
		'VariableNames', iEmptyResult().Properties.VariableNames)]; %#ok<AGROW>
	end

	R = rows;
end

function T = iEmptyResult()
T = table(strings(0, 1), NaT(0, 1), NaT(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
	nan(0, 1), nan(0, 1), strings(0, 1), ...
	'VariableNames', {'Mouse','DateTimeLearned','DateTimeTransfer','TransferHitRate', ...
	'NLearnedActive23','NLearnedActive5','Prob23','Prob5','Source'});
end

function [X, cellUID] = iExtractNtats2D(G)
cellUID = uint64([]);
X = [];
if isempty(G)
	return;
end
nt = G.NTATS;
cellUID = uint64(G.CellUID);
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data;
else
	X = nt;
end
X = double(X);
if ndims(X) == 3
	X = squeeze(X(:, :, 1));
end
end

function active = iIsActiveAt1s(X, baseMask, idx1s, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
active = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma .* baseSd));
end

function [nLearned, prob] = iConditionalProb(learnedActive, transferActive, layerMask)
use = layerMask & learnedActive;
	nLearned = nnz(use);
	if nLearned < 1
		prob = NaN;
	else
		prob = mean(double(transferActive(use)), 'omitnan');
	end
end

function layers = iMapLayer(CellMeta, cellUID)
[tf, loc] = ismember(cellUID, CellMeta.CellUID);
layers = strings(size(cellUID));
layers(tf) = CellMeta.ZLayer(loc(tf));
end

function tf = iIsLayer23(layers)
layers = lower(strtrim(layers));
tf = contains(layers, "2/3") | contains(layers, "23");
end

function tf = iIsLayer5(layers)
layers = lower(strtrim(layers));
tf = contains(layers, "5");
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end

function txt = iFormatPValue(p)
if ~isfinite(p)
	txt = 'p = NaN';
elseif p < 0.001
	txt = '***';
elseif p < 0.01
	txt = '**';
elseif p < 0.05
	txt = '*';
else
	txt = sprintf('p = %.2f', p);
end
end