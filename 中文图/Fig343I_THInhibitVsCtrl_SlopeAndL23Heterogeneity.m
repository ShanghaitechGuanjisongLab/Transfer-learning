% 中文图343I：TH抑制与对照组学习斜率和2/3层响应异质性
%
% 数据路径参照英文图3J：Ctrl = AudioLightBaseline，TH = THInhibit，
% 均取 LightWater Transfer -> Final，并排除混有 AudioWater 的训练单元。
% 上半 tile：学习斜率，按英文图1C算法做单鼠 slope，并用 BaselinePerf 做 ANCOVA。
% 下半 tile：响应异质性，沿用英文图3J算法，但层位改为 MOp2/3。

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "中文图Fig343I_THInhibitVsCtrl_SlopeAndL23Heterogeneity.svg";

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig343I:No1s', 'Cannot find sample close to 1 s.');
end

ctrlSess = iSlopeSessionsFrom3J(CtrlDS, "Ctrl", "Transfer", "Final");
thSess = iSlopeSessionsFrom3J(THDS, "TH", "Transfer", "Final");
allSessions = [ctrlSess; thSess];
if isempty(allSessions)
	error('Fig343I:EmptySessions', 'No valid sessions were retained from the Fig3J data path.');
end

allSessions = sortrows(allSessions, {'Group','Mouse','DateTime'});
allSessions = iAddSessionIndex(allSessions);
allSessions = iAddBaselinePerf(allSessions);
perMouse = iPerMouseSlope(allSessions);

slopeCtrl = double(perMouse.Slope(string(perMouse.Group) == "Ctrl"));
slopeTH = double(perMouse.Slope(string(perMouse.Group) == "TH"));
slopeCtrl = slopeCtrl(isfinite(slopeCtrl));
slopeTH = slopeTH(isfinite(slopeTH));
pSlope = iSlopeAncovaP(perMouse);

hetCtrl = iResponseHeterogeneityByMouse(CtrlDS, ctrlSess, idx1s, "MOp2/3");
hetTH = iResponseHeterogeneityByMouse(THDS, thSess, idx1s, "MOp2/3");
hetCtrl = hetCtrl(isfinite(hetCtrl));
hetTH = hetTH(isfinite(hetTH));
pHet = iRanksumSafe(hetCtrl, hetTH);

fprintf('\n=== Fig343I learning slope ===\n');
fprintf('Ctrl: %.4f ± %.4f (n=%d)\n', mean(slopeCtrl, 'omitnan'), std(slopeCtrl, 'omitnan') / sqrt(numel(slopeCtrl)), numel(slopeCtrl));
fprintf('TH:   %.4f ± %.4f (n=%d)\n', mean(slopeTH, 'omitnan'), std(slopeTH, 'omitnan') / sqrt(numel(slopeTH)), numel(slopeTH));
fprintf('ANCOVA p = %.4g\n', pSlope);

fprintf('\n=== Fig343I MOp2/3 response heterogeneity ===\n');
fprintf('Ctrl: %.4f ± %.4f (n=%d)\n', mean(hetCtrl, 'omitnan'), std(hetCtrl, 'omitnan') / sqrt(numel(hetCtrl)), numel(hetCtrl));
fprintf('TH:   %.4f ± %.4f (n=%d)\n', mean(hetTH, 'omitnan'), std(hetTH, 'omitnan') / sqrt(numel(hetTH)), numel(hetTH));
fprintf('ranksum p = %.4g\n', pHet);

f = figure('Color', 'w', 'Name', 'Fig343I TH slope and L2/3 heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});

nexttile(layout, 1);
[~, optSlope, barsSlope, ebSlope] = UniExp.BarScatterCompare({slopeCtrl(:), slopeTH(:)}, false, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
iStyleTile(gca, barsSlope, ebSlope, false, 'Learning slope');
iApplyPText(optSlope, pSlope);

nexttile(layout, 2);
[~, optHet, barsHet, ebHet] = UniExp.BarScatterCompare({hetCtrl(:), hetTH(:)}, false, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
iStyleTile(gca, barsHet, ebHet, true, 'Respo. heter. L2/3');
iApplyPText(optHet, pHet);

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig343I_AllSessions', allSessions);
assignin('base', 'Fig343I_PerMouseSlope', perMouse);
assignin('base', 'Fig343I_SlopeP', pSlope);
assignin('base', 'Fig343I_L23HeterogeneityP', pHet);

function SessOut = iSlopeSessionsFrom3J(DS, groupName, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
if isempty(Sess)
	SessOut = iEmptySessionsTable();
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
out = cell(numel(mice), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2
		continue;
	end
	first100 = find(double(R.Performance) >= 1, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100 - 1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2
		continue;
	end
	R.Group = repmat(string(groupName), height(R), 1);
	out{iM} = R(:, {'Mouse','DateTime','Performance','Group'});
end

out = out(~cellfun('isempty', out));
if isempty(out)
	SessOut = iEmptySessionsTable();
	return;
end
SessOut = vertcat(out{:});
end

function T = iEmptySessionsTable()
T = table(string.empty(0,1), NaT(0,1), nan(0,1), string.empty(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Group'});
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
T.Session = zeros(height(T), 1);
ug = unique(G);
for iG = 1:numel(ug)
	rows = G == ug(iG);
	T.Session(rows) = (1:sum(rows)).';
end
end

function T = iAddBaselinePerf(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','Session'});
T.BaselinePerf = nan(height(T), 1);
[G, ~] = findgroups(T.Group, T.Mouse);
ug = unique(G);
for iG = 1:numel(ug)
	rows = G == ug(iG);
	p = double(T.Performance(rows));
	T.BaselinePerf(rows) = p(1);
end
end

function perMouse = iPerMouseSlope(allSessions)
T = allSessions;
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','Session'});

[mice, ~, g] = unique(T.Mouse);
group = strings(numel(mice), 1);
slope = nan(numel(mice), 1);
nSess = nan(numel(mice), 1);
baselinePerf = nan(numel(mice), 1);

for iM = 1:numel(mice)
	rows = g == iM;
	group(iM) = string(T.Group(find(rows, 1, 'first')));
	x = double(T.Session(rows));
	y = double(T.Performance(rows));
	baselinePerf(iM) = y(1);
	ok = isfinite(x) & isfinite(y);
	x = x(ok);
	y = y(ok);
	nSess(iM) = numel(x);
	if numel(x) < 2
		continue;
	end
	fitP = polyfit(x, y, 1);
	slope(iM) = fitP(1);
end

perMouse = table(mice, group, slope, nSess, baselinePerf, ...
	'VariableNames', {'Mouse','Group','Slope','NSessions','BaselinePerf'});
end

function pValue = iSlopeAncovaP(perMouse)
Tm = perMouse(:, {'Mouse','Group','Slope','BaselinePerf'});
Tm.Mouse = categorical(string(Tm.Mouse));
Tm.Group = categorical(string(Tm.Group));
Tm.Slope = double(Tm.Slope);
Tm.BaselinePerf = double(Tm.BaselinePerf);
ok = isfinite(Tm.Slope) & isfinite(Tm.BaselinePerf) & ~isundefined(Tm.Group);
Tm = Tm(ok, :);
lmSimple = fitlm(Tm, 'Slope ~ 1 + Group + BaselinePerf');
coef = lmSimple.Coefficients;
idx = find(strcmp(string(coef.Properties.RowNames), 'Group_TH'), 1);
if isempty(idx)
	idx = find(startsWith(string(coef.Properties.RowNames), 'Group_'), 1);
end
pValue = coef.pValue(idx);
end

function sdVec = iResponseHeterogeneityByMouse(DS, Sess, idx1s, layerName)
if isempty(Sess)
	sdVec = [];
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
mice = unique(string(Sess.Mouse));
allUsedDTs = unique(Sess.DateTime);
q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
if isempty(ntsCell) || isempty(ntsCell{1})
	sdVec = [];
	return;
end

rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
rawTbl = iAttachLayer(rawTbl, DS.Cells);
rawTbl = rawTbl(string(rawTbl.ZLayer) == layerName, :);
if isempty(rawTbl)
	sdVec = [];
	return;
end

sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);
[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouseMap = Sess(:, {'DateTime','Mouse'});
dtMouseMap.Mouse = string(dtMouseMap.Mouse);
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);
medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');

sdVec = nan(numel(mice), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	sessDates = Sess.DateTime(string(Sess.Mouse) == m);
	mRows = medTbl(string(medTbl.Mouse) == m & ismember(medTbl.DateTime, sessDates), :);
	if isempty(mRows)
		continue;
	end
	[~, ~, cellID] = unique(mRows.CellUID);
	meanPerCell = accumarray(cellID, mRows.Med1s, [], @mean);
	vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
	if numel(vals) >= 3
		sdVec(iM) = std(vals);
	end
end
sdVec = sdVec(isfinite(sdVec));
end

function Sess = iLightWaterSessions(DS)
blkCols = DS.Blocks.Properties.VariableNames;
hasMustWarn = ismember('MustWarn', blkCols);
if hasMustWarn
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Phase','Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | T.MustWarn == "";
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW)
	return;
end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	dtM = DT(DT.Mouse == m, :);
	startDates = dtM.DateTime(dtM.Phase == phaseStart);
	endDates = dtM.DateTime(dtM.Phase == phaseEnd);
	if isempty(startDates) || isempty(endDates)
		continue;
	end
	startDT = min(startDates);
	endDT = max(endDates);
	rows = string(SessOut.Mouse) == m & SessOut.DateTime >= startDT & SessOut.DateTime <= endDT;
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function dt = iNormDT(dt)
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function T = iAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
cellMap.CellUID = uint64(cellMap.CellUID);
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = string(cellMap.ZLayer(loc(has)));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && d <= tolSec;
end

function p = iRanksumSafe(x, y)
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if numel(x) < 2 || numel(y) < 2
	p = NaN;
	return;
end
p = ranksum(x, y);
end

function iStyleTile(ax, bars, errorBars, showXTick, yText)
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ax.XTick = [1 2];
if showXTick
	ax.XTickLabel = {'Ctrl', 'TH'};
else
	ax.XTickLabel = {};
end
box(ax, 'off');
grid(ax, 'off');
legend(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
ylabel(ax, yText, 'FontSize', 6);

colorCtrl = [1, 0, 0];
colorTH = [0, 0, 1];
if isscalar(bars)
	bars.FaceColor = 'flat';
	nBars = numel(bars.YData);
	barColors = repmat([colorCtrl; colorTH], ceil(nBars / 2), 1);
	bars.CData = barColors(1:nBars, :);
	bars.BarWidth = 0.5;
	bars.LineWidth = 1;
	bars.BaseLine.LineWidth = 1;
	bars.EdgeColor = 'none';
	bars.FaceAlpha = 1/3;
else
	if numel(bars) >= 2
		bars(1).FaceColor = colorCtrl;
		bars(1).LineWidth = 1;
		bars(1).BaseLine.LineWidth = 1;
		bars(1).EdgeColor = 'none';
		bars(1).FaceAlpha = 1/3;
		bars(2).FaceColor = colorTH;
		bars(2).LineWidth = 1;
		bars(2).BaseLine.LineWidth = 1;
		bars(2).EdgeColor = 'none';
		bars(2).FaceAlpha = 1/3;
	end
end

for eb = errorBars.Object(:)'
	eb.LineWidth = 1;
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
	end
end
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PLine', options.MultiCompare.Properties.VariableNames)
	for pl = options.MultiCompare.PLine(:)'
		pl.LineWidth = 1;
	end
end
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