% 英文图3D：Naive LW vs Transfer LW 细胞间 SD@1s (邻会话均值) — 分 2/3 层和 5 层
%
% SD 指标 = mean(SD_session_k, SD_session_{k+1})，以相邻会话对为统计单位。
% 每个会话对内，对该层细胞的 per-cell median ZScore@1s 计算 inter-cell SD，
% 然后取前后两个会话的 SD 均值。
%
% Layout: tiledlayout(2,1) — 上 MOp2/3, 下 MOp5
%
% Naive LW 来源：LightAudioBaseline + LAInterspersed，全部 LW 会话（ceiling excluded）
% Transfer LW 来源：AudioLightBaseline，全部 LW 会话（ceiling excluded）
%
% 样式参考：英文图2K（3×4cm, 2×1 tile，BarScatterCompare 无散点，PLine）
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图3.D_SD1s_NaiveVsTransfer_ByLayer

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName   = "English_Fig3D_SD1s_NaiveVsTransfer_ByLayer.svg";

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('EnglishFig3D:No1s', 'Cannot find a sample close to 1s.');
end

%% ===== Part 1: Transfer LW — AudioLightBaseline =====
DS_ALB = TransferLearning.AudioLightBaseline();

% Cell layer mapping
CellLayer_T = DS_ALB.Cells(:, {'CellUID','ZLayer'});
CellLayer_T.CellUID = uint64(CellLayer_T.CellUID);
CellLayer_T.ZLayer = string(CellLayer_T.ZLayer);

SessT = iLightWaterSessions(DS_ALB);
SessT = iExcludeCeiling(SessT);
PairsT = iSessionPairs(SessT);

fprintf('Transfer LW: %d adjacent session pairs\n', height(PairsT));

allDTs_T = unique([PairsT.DateTime; PairsT.DateTimeNext]);
q = struct('Stimulus', 'LightWater', 'DateTime', allDTs_T);
ntsCell = DS_ALB.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
sdTbl_T = iBatchSD1s(ntsCell{1}, idx1s, CellLayer_T);

maxP = height(PairsT);
T_SD_23 = nan(maxP, 1);
T_SD_5  = nan(maxP, 1);

for iP = 1:maxP
	dtK  = PairsT.DateTime(iP);
	dtK1 = PairsT.DateTimeNext(iP);
	rK  = sdTbl_T(sdTbl_T.DateTime == dtK, :);
	rK1 = sdTbl_T(sdTbl_T.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_23) && isfinite(rK1.SD_23)
			T_SD_23(iP) = (rK.SD_23 + rK1.SD_23) / 2;
		end
		if isfinite(rK.SD_5) && isfinite(rK1.SD_5)
			T_SD_5(iP) = (rK.SD_5 + rK1.SD_5) / 2;
		end
	end
end

%% ===== Part 2: Naive LW — LightAudioBaseline + LAInterspersed =====
naiveDSList = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
	builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};

allNaiveSess = table(string.empty(0,1), NaT(0,1), nan(0,1), string.empty(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});
for d = 1:numel(naiveDSList)
	DS = naiveDSList{d}.DS;
	dsName = naiveDSList{d}.Name;
	Sess = iLightWaterSessions(DS);
	Sess = iKeepPureLW(DS, Sess);
	Sess = iExcludeCeiling(Sess);
	if isempty(Sess), continue; end
	Sess.Source = repmat(dsName, height(Sess), 1);
	allNaiveSess = [allNaiveSess; Sess]; %#ok<AGROW>
end

allNaiveSess = sortrows(allNaiveSess, {'Mouse','DateTime'});
[~, iU] = unique(allNaiveSess(:, {'Mouse','DateTime'}), 'rows', 'first');
allNaiveSess = allNaiveSess(iU, :);

PairsN = iSessionPairs(allNaiveSess);
fprintf('Naive LW: %d adjacent session pairs\n', height(PairsN));

naiveSD = table(NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_23','SD_5'});
for d = 1:numel(naiveDSList)
	DS = naiveDSList{d}.DS;
	dsName = naiveDSList{d}.Name;
	CellLayer_N = DS.Cells(:, {'CellUID','ZLayer'});
	CellLayer_N.CellUID = uint64(CellLayer_N.CellUID);
	CellLayer_N.ZLayer = string(CellLayer_N.ZLayer);
	dts = unique([PairsN.DateTime(PairsN.Source == dsName); PairsN.DateTimeNext(PairsN.SourceNext == dsName)]);
	if isempty(dts), continue; end
	q = struct('Stimulus', 'LightWater', 'DateTime', dts);
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	if ~isempty(ntsCell) && ~isempty(ntsCell{1})
		tbl = iBatchSD1s(ntsCell{1}, idx1s, CellLayer_N);
		naiveSD = [naiveSD; tbl(:, {'DateTime','SD_23','SD_5'})]; %#ok<AGROW>
	end
end
[~, iU] = unique(naiveSD.DateTime);
naiveSD = naiveSD(iU, :);

maxPN = height(PairsN);
N_SD_23 = nan(maxPN, 1);
N_SD_5  = nan(maxPN, 1);

for iP = 1:maxPN
	dtK  = PairsN.DateTime(iP);
	dtK1 = PairsN.DateTimeNext(iP);
	rK  = naiveSD(naiveSD.DateTime == dtK, :);
	rK1 = naiveSD(naiveSD.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_23) && isfinite(rK1.SD_23)
			N_SD_23(iP) = (rK.SD_23 + rK1.SD_23) / 2;
		end
		if isfinite(rK.SD_5) && isfinite(rK1.SD_5)
			N_SD_5(iP) = (rK.SD_5 + rK1.SD_5) / 2;
		end
	end
end

%% ===== Statistics =====
kN23 = isfinite(N_SD_23); kT23 = isfinite(T_SD_23);
kN5  = isfinite(N_SD_5);  kT5  = isfinite(T_SD_5);

p23 = ranksum(N_SD_23(kN23), T_SD_23(kT23));
p5  = ranksum(N_SD_5(kN5),   T_SD_5(kT5));

fprintf('\n=== MOp2/3: Naive vs Transfer inter-cell SD (mean of pair) ===\n');
fprintf('  Naive:    %.4f ± %.4f (n=%d)\n', mean(N_SD_23(kN23)), std(N_SD_23(kN23))/sqrt(sum(kN23)), sum(kN23));
fprintf('  Transfer: %.4f ± %.4f (n=%d)\n', mean(T_SD_23(kT23)), std(T_SD_23(kT23))/sqrt(sum(kT23)), sum(kT23));
fprintf('  ranksum p = %.4g\n', p23);

fprintf('\n=== MOp5: Naive vs Transfer inter-cell SD (mean of pair) ===\n');
fprintf('  Naive:    %.4f ± %.4f (n=%d)\n', mean(N_SD_5(kN5)), std(N_SD_5(kN5))/sqrt(sum(kN5)), sum(kN5));
fprintf('  Transfer: %.4f ± %.4f (n=%d)\n', mean(T_SD_5(kT5)), std(T_SD_5(kT5))/sqrt(sum(kT5)), sum(kT5));
fprintf('  ranksum p = %.4g\n', p5);

%% ===== Plot (2×1 tiledlayout, style: English Fig2K) =====
f = figure('Color', 'w', 'Name', 'English Fig3D SD Naive vs Transfer ByLayer');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

colorNaive = [1 0 0];
colorTransfer = [0 0 1];

% --- Tile 1: MOp2/3
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare({N_SD_23(kN23), T_SD_23(kT23)}, false);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end

ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {'Naive', 'Transfer'};
ax1.XAxis.Visible = 'off';
ylabel(ax1, 'SD (L2/3)', 'FontSize', 6);
legend(ax1, 'off');
box(ax1, 'off');
grid(ax1, 'off');
ax1.Toolbar.Visible = 'off';

if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	nB = numel(Bars1.YData);
	Bars1.CData = repmat([colorNaive; colorTransfer], ceil(nB/2), 1);
	Bars1.CData = Bars1.CData(1:nB, :);
	Bars1.BarWidth = 0.5; Bars1.LineWidth = 0.5; Bars1.FaceAlpha = 1/3;
else
	if numel(Bars1) >= 2
		Bars1(1).FaceColor = colorNaive;    Bars1(1).FaceAlpha = 1/3; Bars1(1).LineWidth = 0.5;
		Bars1(2).FaceColor = colorTransfer; Bars1(2).FaceAlpha = 1/3; Bars1(2).LineWidth = 0.5;
	end
end

star1 = iAsterisk(p23);
Desc1 = table(EB1.Object(1), EB1.Object(2), EB1.Index(1), EB1.Index(2), star1, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT1] = MATLAB.Graphics.PLine(Desc1);
for t = PT1(:)', t.FontSize = 6; end

% --- Tile 2: MOp5
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare({N_SD_5(kN5), T_SD_5(kT5)}, false);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end

ax2 = gca;
ax2.FontSize = 6;
ax2.XTick = [1 2];
ax2.XTickLabel = {'Naive', 'Transfer'};
ylabel(ax2, 'SD (L5)', 'FontSize', 6);
legend(ax2, 'off');
box(ax2, 'off');
grid(ax2, 'off');
ax2.Toolbar.Visible = 'off';

if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB2 = numel(Bars2.YData);
	Bars2.CData = repmat([colorNaive; colorTransfer], ceil(nB2/2), 1);
	Bars2.CData = Bars2.CData(1:nB2, :);
	Bars2.BarWidth = 0.5; Bars2.LineWidth = 0.5; Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorNaive;    Bars2(1).FaceAlpha = 1/3; Bars2(1).LineWidth = 0.5;
		Bars2(2).FaceColor = colorTransfer; Bars2(2).FaceAlpha = 1/3; Bars2(2).LineWidth = 0.5;
	end
end

star2 = iAsterisk(p5);
Desc2 = table(EB2.Object(1), EB2.Object(2), EB2.Index(1), EB2.Index(2), star2, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT2] = MATLAB.Graphics.PLine(Desc2);
for t = PT2(:)', t.FontSize = 6; end

%% ===== Export =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3D_Naive_SD_23',    N_SD_23(kN23));
assignin('base', 'Fig3D_Transfer_SD_23', T_SD_23(kT23));
assignin('base', 'Fig3D_Naive_SD_5',     N_SD_5(kN5));
assignin('base', 'Fig3D_Transfer_SD_5',  T_SD_5(kT5));
assignin('base', 'Fig3D_p23', p23);
assignin('base', 'Fig3D_p5',  p5);

%% ===== Local functions =====

function sdTbl = iBatchSD1s(nts, idx1s, CellLayer)
% Compute inter-cell SD@1s per session (DateTime), split by layer.
% Returns table(DateTime, SD_23, SD_5).
minCells = 3;

if isempty(nts) || ~istable(nts) || height(nts) == 0
	sdTbl = table(NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_23','SD_5'});
	return;
end

nts.CellUID = uint64(nts.CellUID);
nts.DateTime = datetime(nts.DateTime);
if ~isempty(nts.DateTime.TimeZone), nts.DateTime.TimeZone = ''; end

% Build CellUID → Layer lookup
[tf, loc] = ismember(nts.CellUID, CellLayer.CellUID);
cellZLayer = strings(height(nts), 1);
cellZLayer(tf) = CellLayer.ZLayer(loc(tf));

uDTs = unique(nts.DateTime);
nDT = numel(uDTs);
sd23 = nan(nDT, 1);
sd5  = nan(nDT, 1);

for iDT = 1:nDT
	dt = uDTs(iDT);
	mask = nts.DateTime == dt;
	sessRows = nts(mask, :);
	sessLayers = cellZLayer(mask);

	uCells = unique(sessRows.CellUID);
	nC = numel(uCells);
	vals = nan(nC, 1);
	layers = strings(nC, 1);
	for iC = 1:nC
		cMask = sessRows.CellUID == uCells(iC);
		cRows = sessRows.TrialSignal(cMask, :);
		med = median(double(cRows), 1, 'omitnan');
		if numel(med) >= idx1s
			vals(iC) = med(idx1s);
		end
		cL = sessLayers(cMask);
		layers(iC) = cL(1);
	end

	v23 = vals(isfinite(vals) & (layers == "MOp2/3"));
	if numel(v23) >= minCells, sd23(iDT) = std(v23, 0, 1); end

	v5 = vals(isfinite(vals) & (layers == "MOp5"));
	if numel(v5) >= minCells, sd5(iDT) = std(v5, 0, 1); end
end

sdTbl = table(uDTs, sd23, sd5, 'VariableNames', {'DateTime','SD_23','SD_5'});
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks;
blkVars = string(Blocks.Properties.VariableNames);
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
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

function SessOut = iKeepPureLW(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", :);
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
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
if ismember('Source', Sess.Properties.VariableNames)
	outSrc  = strings(nTotal, 1);
	outSrc2 = strings(nTotal, 1);
	hasSrc = true;
else
	hasSrc = false;
end
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
	if hasSrc
		src = string(R.Source);
		outSrc(idx)  = src(1:end-1);
		outSrc2(idx) = src(2:end);
	end
	pos = pos + n;
end
Pairs = table(outMouse(1:pos), outDT(1:pos), outPerf(1:pos), outDT2(1:pos), outPerf2(1:pos), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext'});
if hasSrc
	Pairs.Source     = outSrc(1:pos);
	Pairs.SourceNext = outSrc2(1:pos);
end
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
