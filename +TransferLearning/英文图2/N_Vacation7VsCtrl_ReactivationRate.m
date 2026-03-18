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
RCtrl = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	'DataSet', CtrlDS, 'Source', "AudioLightBaseline");
RV7 = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	'DataSet', V7DS, 'Source', "Vacation7");

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

xReactCtrl = R.PTgivenL(R.Group == "Control");
xReactV7   = R.PTgivenL(R.Group == "Vacation7");
xReactCtrl = xReactCtrl(isfinite(xReactCtrl));
xReactV7   = xReactV7(isfinite(xReactV7));

fprintf('\n=== Upper tile: Reactivation P(T|L) ===\n');
fprintf('  Control:   n=%d, mean=%.4f\n', numel(xReactCtrl), mean(xReactCtrl));
fprintf('  Vacation7: n=%d, mean=%.4f\n', numel(xReactV7),   mean(xReactV7));
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

	[CTT, ~] = iLocalBuildCTT(nts, trialUIDs, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end
	divCtrl(i) = iDivAtIdx(CTT, idx1s);
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

	[CTT, ~] = iLocalBuildCTT(nts, trialUIDs, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end
	divV7(i) = iDivAtIdx(CTT, idx1s);
end

kC = isfinite(divCtrl);
kV = isfinite(divV7);
xDivCtrl = divCtrl(kC);
xDivV7   = divV7(kV);

fprintf('\n=== Lower tile: Population Divergence ===\n');
fprintf('  Control:   %.3f ± %.3f (n=%d)\n', mean(xDivCtrl), std(xDivCtrl)/sqrt(numel(xDivCtrl)), numel(xDivCtrl));
fprintf('  Vacation7: %.3f ± %.3f (n=%d)\n', mean(xDivV7),   std(xDivV7)/sqrt(numel(xDivV7)),     numel(xDivV7));
pDiv = ranksum(xDivCtrl, xDivV7);
fprintf('  ranksum p=%.4g\n', pDiv);

%% ===== 4) Plot (tiledlayout 2×1) =====
f = figure('Color', 'w', 'Name', 'English Fig2N Vacation7 Reactivation + Divergence');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

palette2 = TransferLearning.FigurePalette(2);
colorA = palette2(1,:);
colorB = palette2(2,:);

% --- Tile 1: Reactivation ---
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare( ...
	{double(xReactCtrl(:)), double(xReactV7(:))}, false);
delete(findobj(gca, 'Type', 'Scatter'));
delete(EB1.Object(isgraphics(EB1.Object)));

ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {'Ctrl', 'Vac7'};
ax1.XAxis.Visible = 'off';
legend(ax1, 'off');
box(ax1, 'off');
grid(ax1, 'off');
ax1.Toolbar.Visible = 'off';
ylabel(ax1, 'Reactivation', 'FontSize', 6);

if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	nB = numel(Bars1.YData);
	Bars1.CData = repmat([colorA; colorB], ceil(nB/2), 1);
	Bars1.CData = Bars1.CData(1:nB, :);
	Bars1.BarWidth = 0.5; Bars1.LineWidth = 1; Bars1.FaceAlpha = 1/3;
else
	if numel(Bars1) >= 2
		Bars1(1).FaceColor = colorA; Bars1(1).FaceAlpha = 1/3; Bars1(1).LineWidth = 1;
		Bars1(2).FaceColor = colorB; Bars1(2).FaceAlpha = 1/3; Bars1(2).LineWidth = 1;
	end
end
iDrawUpperErrorBars(ax1, [1 2], [mean(xReactCtrl) mean(xReactV7)], ...
	[std(xReactCtrl)/sqrt(numel(xReactCtrl)) std(xReactV7)/sqrt(numel(xReactV7))], [colorA; colorB], 1);

star1 = iAsterisk(pReact);
iDrawSigLabel(ax1, [1 2], [mean(xReactCtrl) mean(xReactV7)], ...
	[std(xReactCtrl)/sqrt(numel(xReactCtrl)) std(xReactV7)/sqrt(numel(xReactV7))], star1, 6);

% --- Tile 2: Divergence ---
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare( ...
	{double(xDivCtrl(:)), double(xDivV7(:))}, false);
delete(findobj(gca, 'Type', 'Scatter'));
delete(EB2.Object(isgraphics(EB2.Object)));

ax2 = gca;
ax2.FontSize = 6;
ax2.XTick = [1 2];
ax2.XTickLabel = {'Ctrl', 'Vac7'};
legend(ax2, 'off');
box(ax2, 'off');
grid(ax2, 'off');
ax2.Toolbar.Visible = 'off';
ylabel(ax2, 'Divergence', 'FontSize', 6);

if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB2 = numel(Bars2.YData);
	Bars2.CData = repmat([colorA; colorB], ceil(nB2/2), 1);
	Bars2.CData = Bars2.CData(1:nB2, :);
	Bars2.BarWidth = 0.5; Bars2.LineWidth = 1; Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorA; Bars2(1).FaceAlpha = 1/3; Bars2(1).LineWidth = 1;
		Bars2(2).FaceColor = colorB; Bars2(2).FaceAlpha = 1/3; Bars2(2).LineWidth = 1;
	end
end
iDrawUpperErrorBars(ax2, [1 2], [mean(xDivCtrl) mean(xDivV7)], ...
	[std(xDivCtrl)/sqrt(numel(xDivCtrl)) std(xDivV7)/sqrt(numel(xDivV7))], [colorA; colorB], 1);

star2 = iAsterisk(pDiv);
iDrawSigLabel(ax2, [1 2], [mean(xDivCtrl) mean(xDivV7)], ...
	[std(xDivCtrl)/sqrt(numel(xDivCtrl)) std(xDivV7)/sqrt(numel(xDivV7))], star2, 6);

%% ===== 5) Export =====
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgName = "English_Fig2N_Vacation7VsCtrl_Reactivation_Divergence.svg";
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== 6) Save to workspace =====
assignin('base', 'English_Fig2N_R', R);
assignin('base', 'English_Fig2N_pReact', pReact);
assignin('base', 'English_Fig2N_DivCtrl', xDivCtrl);
assignin('base', 'English_Fig2N_DivVac7', xDivV7);
assignin('base', 'English_Fig2N_pDiv', pDiv);

%% ===== Local functions =====

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

function s = iAsterisk(p)
if p < 0.001
	s = "***";
elseif p < 0.01
	s = "**";
elseif p < 0.05
	s = "*";
else
	s = "n.s.";
end
end

function iDrawUpperErrorBars(ax, xs, ys, errs, colors, lineWidth)
capWidth = 0.18;
hold(ax, 'on');
for i = 1:numel(xs)
	if ~isfinite(ys(i)) || ~isfinite(errs(i))
		continue;
	end
	yTop = ys(i) + errs(i);
	v = line(ax, [xs(i) xs(i)], [ys(i) yTop], 'Color', colors(i, :), 'LineWidth', lineWidth);
	setappdata(v, 'TransferLearningPreserveLineWidth', true);
	h = line(ax, [xs(i)-capWidth/2 xs(i)+capWidth/2], [yTop yTop], 'Color', colors(i, :), 'LineWidth', lineWidth);
	setappdata(h, 'TransferLearningPreserveLineWidth', true);
	try
		v.Annotation.LegendInformation.IconDisplayStyle = 'off';
		h.Annotation.LegendInformation.IconDisplayStyle = 'off';
	catch
	end
end
end

function iDrawSigLabel(ax, xs, ys, errs, label, fontSize)
if label == ""
	return;
end
hold(ax, 'on');
yl = ylim(ax);
yMax = max(ys + errs, [], 'omitnan');
if ~isfinite(yMax)
	yMax = yl(2);
end
yRange = yl(2) - yl(1);
if ~isfinite(yRange) || yRange <= 0
	yRange = max(1, abs(yMax));
end
yLine = yMax + 0.04 * yRange;
yTick = 0.02 * yRange;
yText = yLine + 0.02 * yRange;

hl = line(ax, [xs(1) xs(1) xs(2) xs(2)], [yLine-yTick yLine yLine yLine-yTick], ...
	'Color', 'k', 'LineWidth', 1);
setappdata(hl, 'TransferLearningPreserveLineWidth', true);
ht = text(ax, mean(xs), yText, label, 'HorizontalAlignment', 'center', ...
	'VerticalAlignment', 'bottom', 'FontSize', fontSize, 'Color', 'k');
try
	hl.Annotation.LegendInformation.IconDisplayStyle = 'off';
	ht.Annotation.LegendInformation.IconDisplayStyle = 'off';
catch
end

newTop = max(yl(2), yText + 0.05 * yRange);
ylim(ax, [yl(1) newTop]);
end
