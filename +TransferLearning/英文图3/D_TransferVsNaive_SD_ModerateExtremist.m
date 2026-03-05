% 英文图3D：Transfer vs Naive inter-cell SD，分 Moderates / Extremists 统计
%
% Moderates：z-score@1s ∈ [-1,1]
% Extremists：z-score@1s ∈ [-2,-1) ∪ (1,2]
% 区分方法参考 B 图（z-score@1s 分布中 [-1,1] 为 Moderates）
%
% 布局：2×1 tiledlayout
%   上 tile：Moderates — Transfer vs Naive inter-cell SD
%   下 tile：Extremists — Transfer vs Naive inter-cell SD
%
% 数据来源同原 E 图上半 tile：
%   Transfer: AudioLightBaseline，全部 LW 会话（ceiling excluded）
%   Naive: LightAudioBaseline + LAInterspersed，纯 LW 会话（ceiling excluded）
%   一个点 = 一对相邻会话 (k, k+1)，SD = mean(SD_k, SD_k+1)
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.C_TransferVsNaive_SD_ModerateExtremist

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
svgName = "English_Fig3D_TransferVsNaive_SD_ModerateExtremist.svg";

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('EnglishFig3C:No1s', 'Cannot find a sample close to 1s.');
end
baseMask = 1:24;

%% ===== Part 1: Transfer LW — AudioLightBaseline =====
DS_ALB = TransferLearning.AudioLightBaseline();

SessT = iLightWaterSessions(DS_ALB);
SessT = iExcludeCeiling(SessT);
PairsT = iSessionPairs(SessT);
fprintf('Transfer LW: %d adjacent session pairs\n', height(PairsT));

allDTs_T = unique([PairsT.DateTime; PairsT.DateTimeNext]);
q = struct('Stimulus', 'LightWater', 'DateTime', allDTs_T);
ntsCell = DS_ALB.QueryNTS(q, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["DateTime"]);
sdTbl_T = iBatchSD1s_ModExt(ntsCell{1}, idx1s);

maxPT = height(PairsT);
T_SD_Mod = nan(maxPT, 1);
T_SD_Ext = nan(maxPT, 1);
for iP = 1:maxPT
	dtK  = PairsT.DateTime(iP);
	dtK1 = PairsT.DateTimeNext(iP);
	rK  = sdTbl_T(sdTbl_T.DateTime == dtK, :);
	rK1 = sdTbl_T(sdTbl_T.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_Mod) && isfinite(rK1.SD_Mod)
			T_SD_Mod(iP) = (rK.SD_Mod + rK1.SD_Mod) / 2;
		end
		if isfinite(rK.SD_Ext) && isfinite(rK1.SD_Ext)
			T_SD_Ext(iP) = (rK.SD_Ext + rK1.SD_Ext) / 2;
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

naiveSD = table(NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_Mod','SD_Ext'});
for d = 1:numel(naiveDSList)
	DS = naiveDSList{d}.DS;
	dsName = naiveDSList{d}.Name;
	dts = unique([PairsN.DateTime(PairsN.Source == dsName); PairsN.DateTimeNext(PairsN.SourceNext == dsName)]);
	if isempty(dts), continue; end
	q = struct('Stimulus', 'LightWater', 'DateTime', dts);
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["DateTime"]);
	if ~isempty(ntsCell) && ~isempty(ntsCell{1})
		tbl = iBatchSD1s_ModExt(ntsCell{1}, idx1s);
		naiveSD = [naiveSD; tbl]; %#ok<AGROW>
	end
end
[~, iU] = unique(naiveSD.DateTime);
naiveSD = naiveSD(iU, :);

maxPN = height(PairsN);
N_SD_Mod = nan(maxPN, 1);
N_SD_Ext = nan(maxPN, 1);
for iP = 1:maxPN
	dtK  = PairsN.DateTime(iP);
	dtK1 = PairsN.DateTimeNext(iP);
	rK  = naiveSD(naiveSD.DateTime == dtK, :);
	rK1 = naiveSD(naiveSD.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_Mod) && isfinite(rK1.SD_Mod)
			N_SD_Mod(iP) = (rK.SD_Mod + rK1.SD_Mod) / 2;
		end
		if isfinite(rK.SD_Ext) && isfinite(rK1.SD_Ext)
			N_SD_Ext(iP) = (rK.SD_Ext + rK1.SD_Ext) / 2;
		end
	end
end

%% ===== Statistics =====
kNM = isfinite(N_SD_Mod); kTM = isfinite(T_SD_Mod);
pMod = ranksum(N_SD_Mod(kNM), T_SD_Mod(kTM));
fprintf('\n=== Moderates: Transfer vs Naive inter-cell SD ===\n');
fprintf('  Naive:    %.4f ± %.4f (n=%d)\n', mean(N_SD_Mod(kNM)), std(N_SD_Mod(kNM))/sqrt(sum(kNM)), sum(kNM));
fprintf('  Transfer: %.4f ± %.4f (n=%d)\n', mean(T_SD_Mod(kTM)), std(T_SD_Mod(kTM))/sqrt(sum(kTM)), sum(kTM));
fprintf('  ranksum p = %.4g\n', pMod);

kNE = isfinite(N_SD_Ext); kTE = isfinite(T_SD_Ext);
pExt = ranksum(N_SD_Ext(kNE), T_SD_Ext(kTE));
fprintf('\n=== Extremists: Transfer vs Naive inter-cell SD ===\n');
fprintf('  Naive:    %.4f ± %.4f (n=%d)\n', mean(N_SD_Ext(kNE)), std(N_SD_Ext(kNE))/sqrt(sum(kNE)), sum(kNE));
fprintf('  Transfer: %.4f ± %.4f (n=%d)\n', mean(T_SD_Ext(kTE)), std(T_SD_Ext(kTE))/sqrt(sum(kTE)), sum(kTE));
fprintf('  ranksum p = %.4g\n', pExt);

%% ===== Plot (2×1 tiledlayout) =====
f = figure('Color', 'w', 'Name', 'English Fig3C SD Moderate vs Extremist');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
yl = ylabel(Layout, 'Inter-cell SD');
yl.FontSize = 6;

colorNaive = [1 0 0];
colorTransfer = [0 0 1];

% --- Tile 1: Moderates ---
nexttile(Layout, 1);
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Opt1, Bars1, EB1] = UniExp.BarScatterCompare( ...
	{N_SD_Mod(kNM), T_SD_Mod(kTM)}, false, CompareGroup, 'AsteriskThreshold', 0.05);
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end

ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {};
title(ax1, 'Moderates', 'FontSize', 6);
legend(ax1, 'off');
box(ax1, 'off');
grid(ax1, 'off');

if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	nB = numel(Bars1.YData);
	Bars1.CData = repmat([colorNaive; colorTransfer], ceil(nB/2), 1);
	Bars1.CData = Bars1.CData(1:nB, :);
	Bars1.BarWidth = 0.5; Bars1.LineWidth = 0.5; Bars1.FaceAlpha = 1/3;
end
if isfield(Opt1, 'MultiCompare') && ismember('PText', Opt1.MultiCompare.Properties.VariableNames)
	for pt = Opt1.MultiCompare.PText(:)', pt.FontSize = 6; end
end

% --- Tile 2: Extremists ---
nexttile(Layout, 2);
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Opt2, Bars2, EB2] = UniExp.BarScatterCompare( ...
	{N_SD_Ext(kNE), T_SD_Ext(kTE)}, false, CompareGroup, 'AsteriskThreshold', 0.05);
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end

ax2 = gca;
ax2.FontSize = 6;
ax2.XTick = [1 2];
ax2.XTickLabel = {'Naive', 'Transfer'};

title(ax2, 'Extremists', 'FontSize', 6);
legend(ax2, 'off');
box(ax2, 'off');
grid(ax2, 'off');

if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB = numel(Bars2.YData);
	Bars2.CData = repmat([colorNaive; colorTransfer], ceil(nB/2), 1);
	Bars2.CData = Bars2.CData(1:nB, :);
	Bars2.BarWidth = 0.5; Bars2.LineWidth = 0.5; Bars2.FaceAlpha = 1/3;
end
if isfield(Opt2, 'MultiCompare') && ismember('PText', Opt2.MultiCompare.Properties.VariableNames)
	for pt = Opt2.MultiCompare.PText(:)', pt.FontSize = 6; end
end

%% ===== Export =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3C_Naive_SD_Mod', N_SD_Mod(kNM));
assignin('base', 'Fig3C_Transfer_SD_Mod', T_SD_Mod(kTM));
assignin('base', 'Fig3C_pMod', pMod);
assignin('base', 'Fig3C_Naive_SD_Ext', N_SD_Ext(kNE));
assignin('base', 'Fig3C_Transfer_SD_Ext', T_SD_Ext(kTE));
assignin('base', 'Fig3C_pExt', pExt);

%% ===== Local functions =====

function sdTbl = iBatchSD1s_ModExt(nts, idx1s)
% Compute inter-cell SD@1s separately for Moderates and Extremists.
% Moderates: z-score@1s ∈ [-1,1]
% Extremists: z-score@1s ∈ [-2,-1) ∪ (1,2]
minCells = 3;
if isempty(nts) || ~istable(nts) || height(nts) == 0
	sdTbl = table(NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_Mod','SD_Ext'});
	return;
end
nts.CellUID = uint64(nts.CellUID);
nts.DateTime = datetime(nts.DateTime);
if ~isempty(nts.DateTime.TimeZone), nts.DateTime.TimeZone = ''; end
uDTs = unique(nts.DateTime);
nDT = numel(uDTs);
sdMod = nan(nDT, 1);
sdExt = nan(nDT, 1);
for iDT = 1:nDT
	dt = uDTs(iDT);
	sessRows = nts(nts.DateTime == dt, :);
	uCells = unique(sessRows.CellUID);
	nC = numel(uCells);
	vals = nan(nC, 1);
	for iC = 1:nC
		cRows = sessRows.TrialSignal(sessRows.CellUID == uCells(iC), :);
		med = median(double(cRows), 1, 'omitnan');
		if numel(med) >= idx1s, vals(iC) = med(idx1s); end
	end
	% Moderates: [-1,1]
	vMod = vals(isfinite(vals) & vals >= -1 & vals <= 1);
	if numel(vMod) >= minCells, sdMod(iDT) = std(vMod, 0, 1); end
	% Extremists: [-2,-1) ∪ (1,2]
	vExt = vals(isfinite(vals) & ((vals >= -2 & vals < -1) | (vals > 1 & vals <= 2)));
	if numel(vExt) >= minCells, sdExt(iDT) = std(vExt, 0, 1); end
end
sdTbl = table(uDTs, sdMod, sdExt, 'VariableNames', {'DateTime','SD_Mod','SD_Ext'});
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
	if ~isempty(i100), remove(rows(i100:end)) = true; end
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
hasSrc = ismember('Source', Sess.Properties.VariableNames);
if hasSrc
	outSrc  = strings(nTotal, 1);
	outSrc2 = strings(nTotal, 1);
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
