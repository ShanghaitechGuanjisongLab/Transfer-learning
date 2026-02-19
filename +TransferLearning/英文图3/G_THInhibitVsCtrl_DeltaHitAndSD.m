% 英文图3I：TH 抑制组 vs 对照组 ΔHit 和 细胞间 SD（会话对平均）
%
% 两个面板（上下 tiledlayout，参照英文图2K）：
%   上: ΔHit — 前后会话命中率差值（iBuildSessionDeltaNextTable）
%   下: Inter-cell SD@1s — 相邻会话对均值 mean(SD_k, SD_{k+1})
%       参考英文图3E/F 的口径（per-cell median ZScore@1s，取细胞间 std）
%
% 数据源（模仿 Fig3.5C/E/F）：
% - 对照组：TransferLearning.AudioLightBaseline
% - 抑制组：TransferLearning.THInhibit
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图3.I_THInhibitVsCtrl_DeltaHitAndSD

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3G_THInhibitVsCtrl_DeltaHitAndSD.svg";

%% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try, matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

%% --- 1) Load datasets
CtrlDS = TransferLearning.AudioLightBaseline();
THDS   = TransferLearning.THInhibit();

%% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('EnglishFig3G:No1s', 'Cannot find a sample close to 1s.');
end

minCells = 3;

%% ======================================================================
%  Part A: ΔHit (forward difference)
%  ======================================================================

Bc = TransferLearning.Fig35.iQueryLightWaterBlocks(CtrlDS, false);
Bt = TransferLearning.Fig35.iQueryLightWaterBlocks(THDS, false);
Bc.Group = repmat("Ctrl", height(Bc), 1);
Bt.Group = repmat("TH",   height(Bt), 1);
Bc.Mouse = string(Bc.Mouse);
Bt.Mouse = string(Bt.Mouse);
Bc.DateTime = TransferLearning.Fig35.iNormalizeDateTime(Bc.DateTime);
Bt.DateTime = TransferLearning.Fig35.iNormalizeDateTime(Bt.DateTime);

J = MATLAB.DataTypes.MergeTables(Bc, Bt);
J.Group = string(J.Group);

vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
SessAll = TransferLearning.Fig35.iSessionizeByDateTime(J(:, vars));
SessAll = sortrows(SessAll, {'Group','Mouse','DateTime'});
SessAll = TransferLearning.Fig35.iAddSessionIndex(SessAll);

Delta = TransferLearning.Fig35.iBuildSessionDeltaNextTable(SessAll);
dCtrl = Delta.DeltaPerf(string(Delta.Group) == "Ctrl");
dTH   = Delta.DeltaPerf(string(Delta.Group) == "TH");

pDelta = iRanksumSafe(dCtrl, dTH);

fprintf('=== ΔHit (forward difference) ===\n');
fprintf('  Ctrl: %.4f ± %.4f (n=%d pairs)\n', mean(dCtrl,'omitnan'), std(dCtrl,'omitnan')/sqrt(nnz(isfinite(dCtrl))), nnz(isfinite(dCtrl)));
fprintf('  TH:   %.4f ± %.4f (n=%d pairs)\n', mean(dTH,'omitnan'),   std(dTH,'omitnan')/sqrt(nnz(isfinite(dTH))),     nnz(isfinite(dTH)));
fprintf('  ranksum p = %.4g\n', pDelta);

%% ======================================================================
%  Part B: Pair-averaged inter-cell SD@1s (matching English Fig3E/F)
%  ======================================================================

%% --- Ctrl
SessCtrl = iLightWaterSessions(CtrlDS);
SessCtrl = iExcludeCeiling(SessCtrl);
PairsCtrl = iSessionPairs(SessCtrl);
fprintf('\nCtrl LW: %d adjacent session pairs\n', height(PairsCtrl));

allDTs_C = unique([PairsCtrl.DateTime; PairsCtrl.DateTimeNext]);
sdTblCtrl = iBatchSD1s(CtrlDS, allDTs_C, idx1s, minCells);

SD_Ctrl = nan(height(PairsCtrl), 1);
for iP = 1:height(PairsCtrl)
	rK  = sdTblCtrl(sdTblCtrl.DateTime == PairsCtrl.DateTime(iP), :);
	rK1 = sdTblCtrl(sdTblCtrl.DateTime == PairsCtrl.DateTimeNext(iP), :);
	if height(rK)==1 && height(rK1)==1
		if isfinite(rK.SD_All) && isfinite(rK1.SD_All)
			SD_Ctrl(iP) = (rK.SD_All + rK1.SD_All) / 2;
		end
	end
end

%% --- TH
SessTH = iLightWaterSessions(THDS);
SessTH = iExcludeCeiling(SessTH);
PairsTH = iSessionPairs(SessTH);
fprintf('TH LW:   %d adjacent session pairs\n', height(PairsTH));

allDTs_T = unique([PairsTH.DateTime; PairsTH.DateTimeNext]);
sdTblTH = iBatchSD1s(THDS, allDTs_T, idx1s, minCells);

SD_TH = nan(height(PairsTH), 1);
for iP = 1:height(PairsTH)
	rK  = sdTblTH(sdTblTH.DateTime == PairsTH.DateTime(iP), :);
	rK1 = sdTblTH(sdTblTH.DateTime == PairsTH.DateTimeNext(iP), :);
	if height(rK)==1 && height(rK1)==1
		if isfinite(rK.SD_All) && isfinite(rK1.SD_All)
			SD_TH(iP) = (rK.SD_All + rK1.SD_All) / 2;
		end
	end
end

kC = isfinite(SD_Ctrl);
kT = isfinite(SD_TH);
pSD = iRanksumSafe(SD_Ctrl(kC), SD_TH(kT));

fprintf('\n=== Pair-averaged inter-cell SD@1s ===\n');
fprintf('  Ctrl: %.4f ± %.4f (n=%d pairs)\n', mean(SD_Ctrl(kC)), std(SD_Ctrl(kC))/sqrt(sum(kC)), sum(kC));
fprintf('  TH:   %.4f ± %.4f (n=%d pairs)\n', mean(SD_TH(kT)),   std(SD_TH(kT))/sqrt(sum(kT)),   sum(kT));
fprintf('  ranksum p = %.4g\n', pSD);

%% ======================================================================
%  Plot (2×1 tiledlayout, bar only, style: English Fig2K)
%  ======================================================================

f = figure('Color', 'w', 'Name', 'English Fig3G TH DeltaHit & SD');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

colorA = [1 0 0];   % Ctrl = red
colorB = [0 0 1];   % TH   = blue

%% --- Tile 1: ΔHit
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare( ...
	{double(dCtrl(:)), double(dTH(:))}, false);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end

ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {'Ctrl', 'TH'};
ax1.XAxis.Visible = 'off';
legend(ax1, 'off');
box(ax1, 'off');
grid(ax1, 'off');
ax1.Toolbar.Visible = 'off';
ylabel(ax1, '\DeltaHit', 'FontSize', 6);

if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	nB = numel(Bars1.YData);
	Bars1.CData = repmat([colorA; colorB], ceil(nB/2), 1);
	Bars1.CData = Bars1.CData(1:nB, :);
	Bars1.BarWidth = 0.5; Bars1.LineWidth = 0.5; Bars1.FaceAlpha = 1/3;
else
	if numel(Bars1) >= 2
		Bars1(1).FaceColor = colorA; Bars1(1).FaceAlpha = 1/3; Bars1(1).LineWidth = 0.5;
		Bars1(2).FaceColor = colorB; Bars1(2).FaceAlpha = 1/3; Bars1(2).LineWidth = 0.5;
	end
end

star1 = iAsterisk(pDelta);
Desc1 = table(EB1.Object(1), EB1.Object(2), EB1.Index(1), EB1.Index(2), star1, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT1] = MATLAB.Graphics.PLine(Desc1);
for t = PT1(:)', t.FontSize = 6; end

%% --- Tile 2: Pair-averaged SD
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare( ...
	{double(SD_Ctrl(kC)), double(SD_TH(kT))}, false);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end

ax2 = gca;
ax2.FontSize = 6;
ax2.XTick = [1 2];
ax2.XTickLabel = {'Ctrl', 'TH'};
legend(ax2, 'off');
box(ax2, 'off');
grid(ax2, 'off');
ax2.Toolbar.Visible = 'off';
ylabel(ax2, 'Inter-cell SD', 'FontSize', 6);

if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB2 = numel(Bars2.YData);
	Bars2.CData = repmat([colorA; colorB], ceil(nB2/2), 1);
	Bars2.CData = Bars2.CData(1:nB2, :);
	Bars2.BarWidth = 0.5; Bars2.LineWidth = 0.5; Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorA; Bars2(1).FaceAlpha = 1/3; Bars2(1).LineWidth = 0.5;
		Bars2(2).FaceColor = colorB; Bars2(2).FaceAlpha = 1/3; Bars2(2).LineWidth = 0.5;
	end
end

star2 = iAsterisk(pSD);
Desc2 = table(EB2.Object(1), EB2.Object(2), EB2.Index(1), EB2.Index(2), star2, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT2] = MATLAB.Graphics.PLine(Desc2);
for t = PT2(:)', t.FontSize = 6; end

%% --- Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'English_Fig3G_DeltaHit_Ctrl', dCtrl);
assignin('base', 'English_Fig3G_DeltaHit_TH',   dTH);
assignin('base', 'English_Fig3G_SD_Ctrl', SD_Ctrl(kC));
assignin('base', 'English_Fig3G_SD_TH',   SD_TH(kT));
assignin('base', 'English_Fig3G_pDelta', pDelta);
assignin('base', 'English_Fig3G_pSD',    pSD);

%% ===== Local functions =====

function sdTbl = iBatchSD1s(DS, dts, idx1s, minCells)
q = struct('Stimulus', 'LightWater', 'DateTime', dts);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
if isempty(ntsCell) || isempty(ntsCell{1})
	sdTbl = table(NaT(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_All'});
	return;
end
nts = ntsCell{1};
if ~istable(nts) || height(nts) == 0
	sdTbl = table(NaT(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_All'});
	return;
end

nts.CellUID = uint64(nts.CellUID);
nts.DateTime = datetime(nts.DateTime);
if ~isempty(nts.DateTime.TimeZone), nts.DateTime.TimeZone = ''; end

uDTs = unique(nts.DateTime);
nDT = numel(uDTs);
sdAll = nan(nDT, 1);

for iDT = 1:nDT
	dt = uDTs(iDT);
	sessRows = nts(nts.DateTime == dt, :);
	uCells = unique(sessRows.CellUID);
	nC = numel(uCells);
	vals = nan(nC, 1);
	for iC = 1:nC
		cRows = sessRows.TrialSignal(sessRows.CellUID == uCells(iC), :);
		med = median(double(cRows), 1, 'omitnan');
		if numel(med) >= idx1s
			vals(iC) = med(idx1s);
		end
	end
	vAll = vals(isfinite(vals));
	if numel(vAll) >= minCells
		sdAll(iDT) = std(vAll, 0, 1);
	end
end

sdTbl = table(uDTs, sdAll, 'VariableNames', {'DateTime','SD_All'});
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
blkVars = string(Blocks.Properties.VariableNames);
if ismember("MustWarn", blkVars)
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks = Blocks(:, {'BlockUID','DateTime','MustWarn'});

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", :);
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});

T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');

[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perfSess = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
Sess = table(mouse, dt, perfSess, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(p >= 1 - 1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function Pairs = iSessionPairs(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(Sess.Mouse);

nTotal = 0;
for mi = 1:numel(mice)
	nS = nnz(Sess.Mouse == mice(mi));
	if nS >= 2, nTotal = nTotal + nS - 1; end
end

outMouse = strings(nTotal, 1);
outDT    = NaT(nTotal, 1);
outPerf  = nan(nTotal, 1);
outDT2   = NaT(nTotal, 1);
outPerf2 = nan(nTotal, 1);

pos = 0;
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance);
	dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	R = R(use, :);
	perf = perf(use);
	dt = dt(use);
	if numel(perf) < 2, continue; end
	n = numel(perf) - 1;
	idx = (pos + 1):(pos + n);
	outMouse(idx) = repmat(m, n, 1);
	outDT(idx)    = dt(1:end-1);
	outPerf(idx)  = perf(1:end-1);
	outDT2(idx)   = dt(2:end);
	outPerf2(idx) = perf(2:end);
	pos = pos + n;
end

Pairs = table(outMouse(1:pos), outDT(1:pos), outPerf(1:pos), outDT2(1:pos), outPerf2(1:pos), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext'});
end

function p = iRanksumSafe(x, y)
p = NaN;
x = double(x(:)); y = double(y(:));
x = x(isfinite(x)); y = y(isfinite(y));
if numel(x) >= 2 && numel(y) >= 2
	try, p = ranksum(x, y); catch, end
end
end

function s = iAsterisk(p)
if ~isfinite(p)
	s = "n.s.";
elseif p < 0.001
	s = "***";
elseif p < 0.01
	s = "**";
elseif p < 0.05
	s = "*";
else
	s = "n.s.";
end
end
