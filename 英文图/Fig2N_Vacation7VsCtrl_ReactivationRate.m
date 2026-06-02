% English Fig2N: Vacation7 vs Control — Reactivation & Divergence (双 tile)
%
% v6 Panel N 合并原 K+L:
%   上面板: Reactivation P(T|L) 条形图
%   下面板: Population Divergence 条形图
%
% 共用: Ctrl = AudioLightBaseline, Vac7 = Vacation7
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图2.N_Vacation7VsCtrl_ReactivationRate


sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s  = idxCue + sampleRate;

%% ===== 1) Load datasets (shared) =====
CtrlDS = TransferLearning.AudioLightBaseline();
V7DS   = TransferLearning.Vacation7();

%% ===== 2) Compute P(T|L) per mouse (Reactivation — upper tile) =====
RCtrl = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet=CtrlDS, Source="AudioLightBaseline", RequireHitMiss=false);
RV7 = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet=V7DS, Source="Vacation7", RequireHitMiss=false);

if isempty(RCtrl) || isempty(RV7)
	error('English_Fig2M:EmptyBuild', 'Empty rows from P(T|L) builder.');
end

RCtrl.Group = repmat("Control",   height(RCtrl), 1);
RV7.Group   = repmat("Vacation7", height(RV7),   1);
R = [RCtrl; RV7];
R.Mouse = string(R.Mouse);

% Combine layers: weighted average P(T|L) across MOp2/3 + MOp5
n23 = R.NLearnedActive23;
n5  = R.NLearnedActive5;
n23(~isfinite(n23)) = 0;
n5(~isfinite(n5))   = 0;

w23 = n23 .* R.Prob23;
w5  = n5  .* R.Prob5;
w23(~isfinite(w23)) = 0;
w5(~isfinite(w5))   = 0;

nTotal = n23 + n5;
R.PTgivenL = (w23 + w5) ./ nTotal;
R.PTgivenL(nTotal == 0) = NaN;

reactCtrlMask = R.Group == "Control" & isfinite(R.PTgivenL);
reactV7Mask = R.Group == "Vacation7" & isfinite(R.PTgivenL);
xReactCtrl = R.PTgivenL(reactCtrlMask);
xReactV7   = R.PTgivenL(reactV7Mask);
nReactCellsCtrl = sum(nTotal(reactCtrlMask), 'omitnan');
nReactCellsV7 = sum(nTotal(reactV7Mask), 'omitnan');

fprintf('\n=== Upper tile: Reactivation P(T|L) ===\n');
fprintf('  Control:   mice n=%d, learned-active cells n=%d, mean=%.4f\n', numel(xReactCtrl), nReactCellsCtrl, mean(xReactCtrl));
fprintf('  Gap:       mice n=%d, learned-active cells n=%d, mean=%.4f\n', numel(xReactV7), nReactCellsV7, mean(xReactV7));
pReact = ranksum(xReactCtrl, xReactV7);
fprintf('  ranksum p=%.4g\n', pReact);

%% ===== 3) Compute Divergence per mouse (lower tile) =====

% --- Control ---
TctrlLW = CtrlDS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], ...
	Phase="Transfer", Stimulus="LightWater");
TctrlLW.Mouse = string(TctrlLW.Mouse);
TctrlLW.DateTime = datetime(TctrlLW.DateTime);
TctrlLW.DateTime.TimeZone = '';

ctrlMice = unique(TctrlLW.Mouse);
nCtrl = numel(ctrlMice);
divCtrl = nan(nCtrl, 1);
divCellCtrl = zeros(nCtrl, 1);

for i = 1:nCtrl
	m = ctrlMice(i);
	Tm = TctrlLW(TctrlLW.Mouse == m, :);
	dt1 = min(Tm.DateTime);
	Tm = sortrows(Tm(Tm.DateTime == dt1, :), "TrialIndex");
	trialUIDs = unique(uint64(Tm.TrialUID), 'stable');
	if numel(trialUIDs) < 2, continue; end

	nts = CtrlDS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), ...
		UniExp.Flags.ZScore, 1:24);
	if iscell(nts), nts = nts{1}; end
	if isempty(nts), continue; end

	[CTT, divCellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end
	divCtrl(i) = iDivAtIdx(CTT, idx1s);
	divCellCtrl(i) = numel(divCellUIDs);
end

% --- Vacation7 ---
Tv7LW = V7DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], ...
	Phase="Transfer", Stimulus="LightWater");
Tv7LW.Mouse = string(Tv7LW.Mouse);
Tv7LW.DateTime = datetime(Tv7LW.DateTime);
Tv7LW.DateTime.TimeZone = '';

v7Mice = unique(Tv7LW.Mouse);
nV7 = numel(v7Mice);
divV7 = nan(nV7, 1);
divCellV7 = zeros(nV7, 1);

for i = 1:nV7
	m = v7Mice(i);
	Tm = Tv7LW(Tv7LW.Mouse == m, :);
	dt1 = min(Tm.DateTime);
	Tm = sortrows(Tm(Tm.DateTime == dt1, :), "TrialIndex");
	trialUIDs = unique(uint64(Tm.TrialUID), 'stable');
	if numel(trialUIDs) < 2, continue; end

	nts = V7DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), ...
		UniExp.Flags.ZScore, 1:24);
	if iscell(nts), nts = nts{1}; end
	if isempty(nts), continue; end

	[CTT, divCellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end
	divV7(i) = iDivAtIdx(CTT, idx1s);
	divCellV7(i) = numel(divCellUIDs);
end

kC = isfinite(divCtrl);
kV = isfinite(divV7);
xDivCtrl = divCtrl(kC);
xDivV7   = divV7(kV);
nDivCellsCtrl = sum(divCellCtrl(kC));
nDivCellsV7 = sum(divCellV7(kV));

fprintf('\n=== Lower tile: Population Divergence ===\n');
fprintf('  Control:   %.3f ± %.3f (mice n=%d, cells n=%d)\n', mean(xDivCtrl), std(xDivCtrl)/sqrt(numel(xDivCtrl)), numel(xDivCtrl), nDivCellsCtrl);
fprintf('  Gap:       %.3f ± %.3f (mice n=%d, cells n=%d)\n', mean(xDivV7), std(xDivV7)/sqrt(numel(xDivV7)), numel(xDivV7), nDivCellsV7);
pDiv = ranksum(xDivCtrl, xDivV7);
fprintf('  ranksum p=%.4g\n', pDiv);

%% ===== 4) Plot (tiledlayout 2×1) =====
f = figure('Color', 'w', 'Name', 'English Fig2N Gap Reactivation + Divergence');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');

barColors = TransferLearning.GroupColors(["Control", "Gap"]);
barColors(1, :) = TransferLearning.ContinualColor;
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});
Options = cell(2, 1);

% --- Tile 1: Reactivation ---
ax1 = nexttile(Layout, 1);
[~, Options{1}, Bars1, EB1] = UniExp.BarScatterCompare( ...
	{double(xReactCtrl(:)), double(xReactV7(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
delete(findobj(ax1, 'Type', 'Scatter'));
iStyleAxes(ax1, false);
ylabel(ax1, 'Reactivation', 'FontSize', 6);
iStyleBars(Bars1, barColors(1, :), barColors(2, :));
iStyleErrorBars(EB1, barColors);

% --- Tile 2: Divergence ---
ax2 = nexttile(Layout, 2);
[~, Options{2}, Bars2, EB2] = UniExp.BarScatterCompare( ...
	{double(xDivCtrl(:)), double(xDivV7(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
delete(findobj(ax2, 'Type', 'Scatter'));
iStyleAxes(ax2, true);
ylabel(ax2, 'Divergence', 'FontSize', 6);
iStyleBars(Bars2, barColors(1, :), barColors(2, :));
iStyleErrorBars(EB2, barColors);

iTagRetunablePValues(Options);
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgName = "English_Fig2N_Vacation7VsCtrl_Reactivation_Divergence.svg";
svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== 6) Save to workspace =====
reactSampleCounts = table(["Control"; "Gap"], [numel(xReactCtrl); numel(xReactV7)], [nReactCellsCtrl; nReactCellsV7], ...
	'VariableNames', {'Group','NMouse','NLearnedActiveCell'});
divSampleCounts = table(["Control"; "Gap"], [numel(xDivCtrl); numel(xDivV7)], [nDivCellsCtrl; nDivCellsV7], ...
	'VariableNames', {'Group','NMouse','NCell'});
assignin('base', 'English_Fig2N_R', R);
assignin('base', 'English_Fig2N_pReact', pReact);
assignin('base', 'English_Fig2N_DivCtrl', xDivCtrl);
assignin('base', 'English_Fig2N_DivVac7', xDivV7);
assignin('base', 'English_Fig2N_pDiv', pDiv);
assignin('base', 'English_Fig2N_ReactivationSampleCounts', reactSampleCounts);
assignin('base', 'English_Fig2N_DivergenceSampleCounts', divSampleCounts);

%% ===== Local functions =====

function iStyleAxes(ax, showX)
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ax.XTick = [1 2];
if showX
	ax.XTickLabel = {'Ctrl', 'Gap'};
else
	ax.XTickLabel = {};
end
legend(ax, 'off');
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iStyleBars(Bars, colorControl, colorGap)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nBar = numel(Bars.YData);
	Bars.CData = repmat([colorControl; colorGap], ceil(nBar/2), 1);
	Bars.CData = Bars.CData(1:nBar, :);
	Bars.BarWidth = 0.5;
	Bars.FaceAlpha = 1;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	return;
end
if numel(Bars) >= 2
	Bars(1).FaceColor = colorControl;
	Bars(2).FaceColor = colorGap;
	Bars(1).BarWidth = 0.5;
	Bars(2).BarWidth = 0.5;
	Bars(1).FaceAlpha = 1;
	Bars(2).FaceAlpha = 1;
	Bars(1).LineWidth = 1;
	Bars(1).BaseLine.LineWidth = 1;
	Bars(2).LineWidth = 1;
	Bars(2).BaseLine.LineWidth = 1;
	Bars(1).EdgeColor = 'none';
	Bars(2).EdgeColor = 'none';
end
end

function iStyleErrorBars(errorBars, colors)
for iE = 1:height(errorBars)
	errorBar = errorBars.Object(iE);
	errorBar.LineWidth = 1;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
end
end

function iTagRetunablePValues(options)
for iOption = 1:numel(options)
	option = options{iOption};
	if ~isfield(option, 'MultiCompare')
		continue;
	end
	multiCompare = option.MultiCompare;
	if ismember('PLine', multiCompare.Properties.VariableNames)
		for pLine = reshape(multiCompare.PLine, 1, [])
			pLine.Tag = 'PLine';
		end
	end
	if ismember('PText', multiCompare.Properties.VariableNames)
		for pText = reshape(multiCompare.PText, 1, [])
			pText.Tag = 'PText';
			pText.FontName = 'Microsoft YaHei';
		end
	end
end
end

function div = iDivAtIdx(CTT, timeIdx)
X = CTT(:, :, timeIdx);
totalSignal = sum(mean(X, 2).^2);
totalNoise  = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate)
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs) < 2, return; end
inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial, :);
if isempty(nts2), return; end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2, return; end
allC = unique(uint64(nts2.CellUID));
nAllC = numel(allC);
traces = cell(nAllC, 1);
keepU = zeros(nAllC, 1, 'uint64');
nKeep = 0;
for ci = 1:nAllC
	cid = allC(ci);
	rows = (uint64(nts2.CellUID) == cid);
	if sum(rows) < numel(trialUIDs), continue; end
	uid = uint64(nts2.TrialUID(rows));
	sig = double(nts2.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf), continue; end
	so = sig(loc, :);
	if any(~isfinite(so), 'all'), continue; end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepU(nKeep) = cid;
end
if nKeep < 1, return; end
traces = traces(1:nKeep);
keepU = keepU(1:nKeep);
nTr = size(traces{1}, 1);
nTi = size(traces{1}, 2);
CTT = nan(nKeep, nTr, nTi);
for ci = 1:nKeep
	CTT(ci, :, :) = traces{ci};
end
idx0 = 3 * sampleRate;
CTT = CTT - CTT(:, :, idx0);
cellUIDs = keepU;
end

