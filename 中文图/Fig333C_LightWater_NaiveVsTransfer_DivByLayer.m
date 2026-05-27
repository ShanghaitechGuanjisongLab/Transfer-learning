% English Fig2H: LightWater Naive vs Transfer Divergence by layer
%
% 上面板：L2/3  Naive LW vs Transfer LW（非配对 ranksum）
% 下面板：L5    Naive LW vs Transfer LW（非配对 ranksum）
%
% 数据来源：
%   Naive LW = LightAudioBaseline + LAInterspersed 的首个 Naive LightWater 会话
%   Transfer LW = AudioLightBaseline 的首个 Transfer LightWater 会话
%   混入 AudioWater trial 的会话排除
%
% 输出: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图2.H_LightWater_NaiveVsTransfer_DivByLayer


sampleRate = 8;
idx1s = 4 * sampleRate;

palette2 = TransferLearning.FigurePalette(2);
RED = palette2(1,:);
BLUE = palette2(2,:);

Sources = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline(), 'Group', "Naive", 'StartPhase', "Naive")
	builtin('struct', 'Name', "LAInterspersed", 'DS', TransferLearning.LAInterspersed(), 'Group', "Naive", 'StartPhase', "Naive")
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline(), 'Group', "Transfer", 'StartPhase', "Transfer")
};

rows = cell(numel(Sources), 1);
for iS = 1:numel(Sources)
	rows{iS} = iBuildStartSessionDivergenceRows(Sources{iS}, idx1s, sampleRate);
end

T = vertcat(rows{:});
if isempty(T)
	error('English_Fig2H:EmptyData', 'No valid LightWater sessions found for panel H.');
end

% Collapse by mouse if duplicated across sources.
[G, mouseU, groupU] = findgroups(string(T.Mouse), string(T.Group));
aggL23 = splitapply(@(x) mean(x, 'omitnan'), T.DivL23, G);
aggL5  = splitapply(@(x) mean(x, 'omitnan'), T.DivL5, G);
aggCellL23 = splitapply(@iSumFinite, T.NCellL23, G);
aggCellL5 = splitapply(@iSumFinite, T.NCellL5, G);
S = table(mouseU, groupU, aggL23, aggL5, aggCellL23, aggCellL5, 'VariableNames', {'Mouse','Group','DivL23','DivL5','NCellL23','NCellL5'});

maskNaiveL23 = S.Group == "Naive" & isfinite(S.DivL23);
maskTranL23 = S.Group == "Transfer" & isfinite(S.DivL23);
maskNaiveL5 = S.Group == "Naive" & isfinite(S.DivL5);
maskTranL5 = S.Group == "Transfer" & isfinite(S.DivL5);

naiveL23 = S.DivL23(maskNaiveL23);
tranL23 = S.DivL23(maskTranL23);
naiveL5 = S.DivL5(maskNaiveL5);
tranL5 = S.DivL5(maskTranL5);

nCellNaiveL23 = iSumFinite(S.NCellL23(maskNaiveL23));
nCellTranL23 = iSumFinite(S.NCellL23(maskTranL23));
nCellNaiveL5 = iSumFinite(S.NCellL5(maskNaiveL5));
nCellTranL5 = iSumFinite(S.NCellL5(maskTranL5));

if isempty(naiveL23) || isempty(tranL23) || isempty(naiveL5) || isempty(tranL5)
	error('English_Fig2H:InsufficientData', 'At least one LightWater layer comparison is empty.');
end

pL23 = ranksum(naiveL23, tranL23);
pL5 = ranksum(naiveL5, tranL5);

fprintf('\n=== Fig333C: NaiveLW vs ContinualLW Div by layer (ranksum) ===\n');
fprintf('  L2/3 counts: Naive %d mice, %d cells; Continual %d mice, %d cells\n', ...
	nnz(maskNaiveL23), nCellNaiveL23, nnz(maskTranL23), nCellTranL23);
fprintf('  L2/3: Naive %.3f ± %.3f (n=%d) vs Continual %.3f ± %.3f (n=%d), p=%.4g\n', ...
	mean(naiveL23), std(naiveL23)/sqrt(numel(naiveL23)), numel(naiveL23), ...
	mean(tranL23), std(tranL23)/sqrt(numel(tranL23)), numel(tranL23), pL23);
fprintf('  L5 counts: Naive %d mice, %d cells; Continual %d mice, %d cells\n', ...
	nnz(maskNaiveL5), nCellNaiveL5, nnz(maskTranL5), nCellTranL5);
fprintf('  L5:   Naive %.3f ± %.3f (n=%d) vs Continual %.3f ± %.3f (n=%d), p=%.4g\n', ...
	mean(naiveL5), std(naiveL5)/sqrt(numel(naiveL5)), numel(naiveL5), ...
	mean(tranL5), std(tranL5)/sqrt(numel(tranL5)), numel(tranL5), pL5);

f = figure('Color', 'w', 'Name', 'English Fig2H NaiveLW vs TransferLW Div by layer');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
yl = ylabel(Layout, 'Divergence');
yl.FontName = 'Arial';
yl.FontSize = 6;

ax1 = nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare({double(naiveL23(:)), double(tranL23(:))}, false, ...
	table([1 2], 'VariableNames', {'GroupPair'}));
delete(findobj(ax1, 'Type', 'Scatter'));
for eb = EB1.Object(:)'
	eb.LineWidth = 1;
end
iStylePValue(ax1);
iStyleAxes(ax1, 'L2/3');
iStyleBars(Bars1, RED, BLUE);

ax2 = nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare({double(naiveL5(:)), double(tranL5(:))}, false, ...
	table([1 2], 'VariableNames', {'GroupPair'}));
delete(findobj(ax2, 'Type', 'Scatter'));
for eb = EB2.Object(:)'
	eb.LineWidth = 1;
end
iStylePValue(ax2);
iStyleAxes(ax2, 'L5');
xlabel(ax2, '💡💧', 'FontName', 'Arial', 'FontSize', 6);
iStyleBars(Bars2, RED, BLUE);

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgPath = '中文图Fig333C_LightWater_NaiveVsTransfer_DivByLayer.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'English_Fig2H_Table', T);
assignin('base', 'English_Fig2H_Summary', S);
assignin('base', 'English_Fig2H_pL23', pL23);
assignin('base', 'English_Fig2H_pL5', pL5);

function out = iBuildStartSessionDivergenceRows(spec, idx1s, sampleRate)
DS = spec.DS;
groupName = string(spec.Group);
startPhase = string(spec.StartPhase);

T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Phase","Stimulus","BlockUID"]);
if isempty(T)
	out = table();
	return;
end

T.Mouse = string(T.Mouse);
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);
T.DateTime = iNormalizeDateTime(T.DateTime);

CellTbl = DS.Cells;
CellTbl.Mouse = string(CellTbl.Mouse);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.ZLayer = string(CellTbl.ZLayer);

mice = unique(T.Mouse);
selMouse = strings(0,1);
selDT = NaT(0,1);
trialSets = cell(0,1);

for iM = 1:numel(mice)
	m = mice(iM);
	Tm = T(T.Mouse == m, :);
	startRows = Tm(Tm.Phase == startPhase & Tm.Stimulus == "LightWater", :);
	if isempty(startRows)
		continue;
	end
	startDT = min(startRows.DateTime);
	sessRows = Tm(Tm.DateTime == startDT, :);
	if any(sessRows.Stimulus == "AudioWater")
		continue;
	end
	lwRows = sortrows(sessRows(sessRows.Stimulus == "LightWater", :), 'TrialIndex');
	trialUIDs = unique(uint64(lwRows.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	selMouse(end+1,1) = m; %#ok<AGROW>
	selDT(end+1,1) = startDT; %#ok<AGROW>
	trialSets{end+1,1} = trialUIDs; %#ok<AGROW>
	end

if isempty(selMouse)
	out = table();
	return;
end

Q = table(selMouse, selDT, repmat("LightWater", numel(selMouse), 1), ...
	'VariableNames', {'Mouse','DateTime','Stimulus'});
ntsRaw = iQueryBatchNts(DS, Q);
if isempty(ntsRaw)
	out = table();
	return;
end

ntsRaw.Mouse = string(ntsRaw.Mouse);
ntsRaw.DateTime = iNormalizeDateTime(ntsRaw.DateTime);
ntsRaw.CellUID = uint64(ntsRaw.CellUID);
ntsRaw.TrialUID = uint64(ntsRaw.TrialUID);

nSess = numel(selMouse);
divL23 = nan(nSess, 1);
divL5 = nan(nSess, 1);
nCellL23 = zeros(nSess, 1);
nCellL5 = zeros(nSess, 1);
for i = 1:nSess
	m = selMouse(i);
	dt = selDT(i);
	rawRows = ntsRaw(ntsRaw.Mouse == m & ntsRaw.DateTime == dt, :);
	if isempty(rawRows)
		continue;
	end
	[CTT, cellUIDs] = iBuildCttFromRows(rawRows, trialSets{i}, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3
		continue;
	end
	X = CTT(:, :, idx1s);
	cellMeta = CellTbl(CellTbl.Mouse == m, {'CellUID','ZLayer'});
	[tf, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs), 1);
	layers(tf) = cellMeta.ZLayer(loc(tf));
	mask23 = layers == "MOp2/3";
	mask5 = layers == "MOp5";
	if sum(mask23) >= 3
		nCellL23(i) = sum(mask23);
		divL23(i) = iDivFromX(X(mask23, :));
	end
	if sum(mask5) >= 3
		nCellL5(i) = sum(mask5);
		divL5(i) = iDivFromX(X(mask5, :));
	end
	end

out = table(selMouse, repmat(groupName, nSess, 1), selDT, divL23, divL5, nCellL23, nCellL5, ...
	'VariableNames', {'Mouse','Group','DateTime','DivL23','DivL5','NCellL23','NCellL5'});
end

function total = iSumFinite(values)
values = values(isfinite(values));
total = sum(values);
end

function ntsRaw = iQueryBatchNts(DS, Q)
ntsRaw = table();
try
	res = DS.QueryNTS(Q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime","Mouse"]);
	ntsRaw = iCollapseNtsResult(res);
catch
	parts = cell(height(Q), 1);
	for i = 1:height(Q)
		qi = Q(i, :);
		res = DS.QueryNTS(qi, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime","Mouse"]);
		parts{i} = iCollapseNtsResult(res);
	end
	parts = parts(~cellfun(@isempty, parts));
	if ~isempty(parts)
		ntsRaw = vertcat(parts{:});
	end
	end
end

function tbl = iCollapseNtsResult(res)
tbl = table();
if isempty(res)
	return;
end
if istable(res)
	tbl = res;
	return;
end
if iscell(res)
	parts = res(~cellfun(@isempty, res));
	if isempty(parts)
		return;
	end
	if istable(parts{1})
		tbl = vertcat(parts{:});
	end
	return;
end
end

function [CTT, cellUIDs] = iBuildCttFromRows(rawRows, trialUIDs, sampleRate)
CTT = [];
cellUIDs = uint64([]);
if isempty(rawRows) || numel(trialUIDs) < 2
	return;
end

rawRows = rawRows(ismember(uint64(rawRows.TrialUID), trialUIDs), :);
if isempty(rawRows)
	return;
end

allCells = unique(uint64(rawRows.CellUID));
traces = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rows = uint64(rawRows.CellUID) == cid;
	uid = uint64(rawRows.TrialUID(rows));
	sig = double(rawRows.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	so = sig(loc, :);
	if size(so, 2) < sampleRate || any(~isfinite(so), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepUID(nKeep) = cid;
	end

if nKeep < 3
	return;
end

traces = traces(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = numel(trialUIDs);
nTime = size(traces{1}, 2);
CTT = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, nTrial, nTime);
	end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function iStyleAxes(ax, titleText)
ax.FontName = 'Arial';
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ax.XTick = [1 2];
ax.XTickLabel = {'Naive', 'Continual'};
legend(ax, 'off');
box(ax, 'off');
grid(ax, 'off');
title(ax, titleText, 'FontName', 'Arial', 'FontSize', 6, 'FontWeight', 'normal');
for t = findobj(ax, 'Type', 'Text')'
	t.FontName = 'Arial';
	t.FontSize = 6;
end
end

function iStyleBars(Bars, colorA, colorB)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	Bars.CData = repmat([colorA; colorB], ceil(nB/2), 1);
	Bars.CData = Bars.CData(1:nB, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1/3;
else
	if numel(Bars) >= 2
		Bars(1).FaceColor = colorA;
		Bars(2).FaceColor = colorB;
		Bars(1).FaceAlpha = 1/3;
		Bars(2).FaceAlpha = 1/3;
		Bars(1).LineWidth = 1;
		Bars(2).LineWidth = 1;
		Bars(1).BaseLine.LineWidth = 1;
		Bars(2).BaseLine.LineWidth = 1;
		Bars(1).EdgeColor = 'none';
		Bars(2).EdgeColor = 'none';
	end
	end
end

function iStylePValue(ax)
for h = findobj(ax, 'Type', 'Line')'
	h.LineWidth = 1;
end
end


