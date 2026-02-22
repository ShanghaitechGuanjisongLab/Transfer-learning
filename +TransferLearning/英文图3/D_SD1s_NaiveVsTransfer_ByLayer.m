% 英文图3D：SD 组间与组内比较（合层 2×1 tiledlayout）
%
% 上 tile：Transfer vs Naive SD（合层，session pair 均值）
% 下 tile：Transfer 内 AW-Responsive vs AW-Non-responsive SD（合层，首 LW 会话）
%
% SD 指标（上 tile）= mean(SD_session_k, SD_session_{k+1})，以相邻会话对为统计单位。
% SD 指标（下 tile）= 首个 LW 会话中，AW 末 session abs(median NTATS@1s) top/bottom 50% 分组的 SD
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

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('EnglishFig3D:No1s', 'Cannot find a sample close to 1s.');
end

%% ===== Part 1: Transfer LW — AudioLightBaseline =====
DS_ALB = TransferLearning.AudioLightBaseline();

SessT = iLightWaterSessions(DS_ALB);
SessT = iExcludeCeiling(SessT);
PairsT = iSessionPairs(SessT);

fprintf('Transfer LW: %d adjacent session pairs\n', height(PairsT));

allDTs_T = unique([PairsT.DateTime; PairsT.DateTimeNext]);
q = struct('Stimulus', 'LightWater', 'DateTime', allDTs_T);
ntsCell = DS_ALB.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
sdTbl_T = iBatchSD1s_All(ntsCell{1}, idx1s);

maxP = height(PairsT);
T_SD_All = nan(maxP, 1);

for iP = 1:maxP
	dtK  = PairsT.DateTime(iP);
	dtK1 = PairsT.DateTimeNext(iP);
	rK  = sdTbl_T(sdTbl_T.DateTime == dtK, :);
	rK1 = sdTbl_T(sdTbl_T.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_All) && isfinite(rK1.SD_All)
			T_SD_All(iP) = (rK.SD_All + rK1.SD_All) / 2;
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

naiveSD = table(NaT(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_All'});
for d = 1:numel(naiveDSList)
	DS = naiveDSList{d}.DS;
	dsName = naiveDSList{d}.Name;
	dts = unique([PairsN.DateTime(PairsN.Source == dsName); PairsN.DateTimeNext(PairsN.SourceNext == dsName)]);
	if isempty(dts), continue; end
	q = struct('Stimulus', 'LightWater', 'DateTime', dts);
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	if ~isempty(ntsCell) && ~isempty(ntsCell{1})
		tbl = iBatchSD1s_All(ntsCell{1}, idx1s);
		naiveSD = [naiveSD; tbl]; %#ok<AGROW>
	end
end
[~, iU] = unique(naiveSD.DateTime);
naiveSD = naiveSD(iU, :);

maxPN = height(PairsN);
N_SD_All = nan(maxPN, 1);

for iP = 1:maxPN
	dtK  = PairsN.DateTime(iP);
	dtK1 = PairsN.DateTimeNext(iP);
	rK  = naiveSD(naiveSD.DateTime == dtK, :);
	rK1 = naiveSD(naiveSD.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_All) && isfinite(rK1.SD_All)
			N_SD_All(iP) = (rK.SD_All + rK1.SD_All) / 2;
		end
	end
end

%% ===== Part 3: AW-Responsive vs AW-Non-responsive SD (Transfer only, first LW) =====
baseMask = 1:24;
Blocks_ALB = DS_ALB.Blocks;
Blocks_ALB.BlockUID = uint64(Blocks_ALB.BlockUID);
Blocks_ALB.DateTime = datetime(Blocks_ALB.DateTime);
if ~isempty(Blocks_ALB.DateTime.TimeZone), Blocks_ALB.DateTime.TimeZone = ''; end

DT_ALB = DS_ALB.DateTimes(:, {'DateTime','Mouse'});
DT_ALB.DateTime = datetime(DT_ALB.DateTime);
if ~isempty(DT_ALB.DateTime.TimeZone), DT_ALB.DateTime.TimeZone = ''; end
DT_ALB.Mouse = string(DT_ALB.Mouse);

Trials_ALB = DS_ALB.Trials;
Trials_ALB.BlockUID = uint64(Trials_ALB.BlockUID);

mice_T = unique(DT_ALB.Mouse);
SD_active = nan(numel(mice_T), 1);
SD_inactive = nan(numel(mice_T), 1);

for mi = 1:numel(mice_T)
	m = mice_T(mi);
	mouseDTs = DT_ALB.DateTime(DT_ALB.Mouse == m);

	% Find AW sessions
	awTrials = Trials_ALB(string(Trials_ALB.Stimulus) == "AudioWater", :);
	awBlkDTs = innerjoin(awTrials(:,'BlockUID'), Blocks_ALB(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
	awMouseDates = intersect(unique(awBlkDTs.DateTime), mouseDTs);
	if isempty(awMouseDates), continue; end
	lastAWdt = max(awMouseDates);

	% Find LW sessions
	lwTrials = Trials_ALB(string(Trials_ALB.Stimulus) == "LightWater", :);
	lwBlkDTs = innerjoin(lwTrials(:,'BlockUID'), Blocks_ALB(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
	lwMouseDates = intersect(unique(lwBlkDTs.DateTime), mouseDTs);
	if isempty(lwMouseDates), continue; end
	firstLWdt = min(lwMouseDates);

	% Get ZScore for last AW session → classify cells
	qAW = struct('Stimulus', 'AudioWater', 'DateTime', lastAWdt);
	ntsAW = DS_ALB.QueryNTS(qAW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsAW) || isempty(ntsAW{1}), continue; end
	ntsAW = ntsAW{1};
	if ~istable(ntsAW) || height(ntsAW) == 0, continue; end

	awCells = unique(uint64(ntsAW.CellUID));
	medAW = nan(numel(awCells), 1);
	for ic = 1:numel(awCells)
		rows = ntsAW(uint64(ntsAW.CellUID) == awCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medAW(ic) = med(idx1s); end
	end

	validAW = isfinite(medAW);
	medAW_v = medAW(validAW);
	awCells_v = awCells(validAW);
	if numel(medAW_v) < 6, continue; end

	% Sort by abs(median@1s), top 50% = responsive
	absVals = abs(medAW_v);
	nHalf = ceil(numel(medAW_v) / 2);
	[~, sortIdx] = sort(absVals, 'descend');
	activeCIDs = awCells_v(sortIdx(1:nHalf));
	inactiveCIDs = awCells_v(sortIdx(nHalf+1:end));

	% Get ZScore for first LW session → compute SD per group
	qLW = struct('Stimulus', 'LightWater', 'DateTime', firstLWdt);
	ntsLW = DS_ALB.QueryNTS(qLW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsLW) || isempty(ntsLW{1}), continue; end
	ntsLW = ntsLW{1};
	if ~istable(ntsLW) || height(ntsLW) == 0, continue; end

	lwCells = unique(uint64(ntsLW.CellUID));
	medLW = nan(numel(lwCells), 1);
	for ic = 1:numel(lwCells)
		rows = ntsLW(uint64(ntsLW.CellUID) == lwCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medLW(ic) = med(idx1s); end
	end

	lwActiveVals = medLW(ismember(lwCells, activeCIDs));
	lwInactiveVals = medLW(ismember(lwCells, inactiveCIDs));
	lwActiveVals = lwActiveVals(isfinite(lwActiveVals));
	lwInactiveVals = lwInactiveVals(isfinite(lwInactiveVals));

	if numel(lwActiveVals) >= 3
		SD_active(mi) = std(lwActiveVals);
	end
	if numel(lwInactiveVals) >= 3
		SD_inactive(mi) = std(lwInactiveVals);
	end
end

validMice = isfinite(SD_active) & isfinite(SD_inactive);
pAI = signrank(SD_active(validMice), SD_inactive(validMice));
fprintf('\nAW-Resp. vs AW-Non-r. SD (Transfer, first LW, merged layers):\n');
fprintf('  Resp.:    %.4f ± %.4f (n=%d)\n', mean(SD_active(validMice)), std(SD_active(validMice))/sqrt(sum(validMice)), sum(validMice));
fprintf('  Non-r.:   %.4f ± %.4f (n=%d)\n', mean(SD_inactive(validMice)), std(SD_inactive(validMice))/sqrt(sum(validMice)), sum(validMice));
fprintf('  paired signrank p = %.4g\n', pAI);

%% ===== Statistics =====
kN = isfinite(N_SD_All); kT = isfinite(T_SD_All);
pNvsT = ranksum(N_SD_All(kN), T_SD_All(kT));

fprintf('\n=== Transfer vs Naive inter-cell SD (merged layers, mean of pair) ===\n');
fprintf('  Naive:    %.4f ± %.4f (n=%d)\n', mean(N_SD_All(kN)), std(N_SD_All(kN))/sqrt(sum(kN)), sum(kN));
fprintf('  Transfer: %.4f ± %.4f (n=%d)\n', mean(T_SD_All(kT)), std(T_SD_All(kT))/sqrt(sum(kT)), sum(kT));
fprintf('  ranksum p = %.4g\n', pNvsT);

%% ===== Plot (2×1 tiledlayout) =====
svgName = "English_Fig3D_SD_GroupAndSubgroup.svg";
f = figure('Color', 'w', 'Name', 'English Fig3D SD Group & Subgroup');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
yl = ylabel(Layout, 'Inter-cell SD');
yl.FontSize = 6;

colorNaive = [1 0 0];
colorTransfer = [0 0 1];
colorActive = [0.4660 0.6740 0.1880];   % green
colorInactive = [0.5 0.5 0.5];          % gray

% --- Tile 1: Transfer vs Naive SD (merged layers)
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare({N_SD_All(kN), T_SD_All(kT)}, false);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end

ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {'Naive', 'Transfer'};

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

star1 = iAsterisk(pNvsT);
Desc1 = table(EB1.Object(1), EB1.Object(2), EB1.Index(1), EB1.Index(2), star1, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT1] = MATLAB.Graphics.PLine(Desc1);
for t = PT1(:)', t.FontSize = 6; end

% --- Tile 2: AW-Resp. vs AW-Non-r. SD (Transfer only)
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare({SD_active(validMice), SD_inactive(validMice)}, false);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end

ax2 = gca;
ax2.FontSize = 6;
ax2.FontName = 'Segoe UI Emoji';
ax2.XTick = [1 2];
ax2.XTickLabel = {'Resp.', 'Non-r.'};
title(ax2, 'Cell subgroups of 💡💧', 'FontSize', 6);
xlabel(ax2, '🔊💧', 'FontSize', 6);
legend(ax2, 'off');
box(ax2, 'off');
grid(ax2, 'off');
ax2.Toolbar.Visible = 'off';

if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB2 = numel(Bars2.YData);
	Bars2.CData = repmat([colorActive; colorInactive], ceil(nB2/2), 1);
	Bars2.CData = Bars2.CData(1:nB2, :);
	Bars2.BarWidth = 0.5; Bars2.LineWidth = 0.5; Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorActive;   Bars2(1).FaceAlpha = 1/3; Bars2(1).LineWidth = 0.5;
		Bars2(2).FaceColor = colorInactive; Bars2(2).FaceAlpha = 1/3; Bars2(2).LineWidth = 0.5;
	end
end

star2 = iAsterisk(pAI);
Desc2 = table(EB2.Object(1), EB2.Object(2), EB2.Index(1), EB2.Index(2), star2, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT2] = MATLAB.Graphics.PLine(Desc2);
for t = PT2(:)', t.FontSize = 6; end

% ===== Export =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3D_Naive_SD',    N_SD_All(kN));
assignin('base', 'Fig3D_Transfer_SD', T_SD_All(kT));
assignin('base', 'Fig3D_pNvsT', pNvsT);
assignin('base', 'Fig3D_SD_Active',   SD_active(validMice));
assignin('base', 'Fig3D_SD_Inactive', SD_inactive(validMice));
assignin('base', 'Fig3D_pAI', pAI);

%% ===== Local functions =====

function sdTbl = iBatchSD1s_All(nts, idx1s)
% Compute merged-layer inter-cell SD@1s per session (DateTime).
% Returns table(DateTime, SD_All).
minCells = 3;

if isempty(nts) || ~istable(nts) || height(nts) == 0
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
	if numel(vAll) >= minCells, sdAll(iDT) = std(vAll, 0, 1); end
end

sdTbl = table(uDTs, sdAll, 'VariableNames', {'DateTime','SD_All'});
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
