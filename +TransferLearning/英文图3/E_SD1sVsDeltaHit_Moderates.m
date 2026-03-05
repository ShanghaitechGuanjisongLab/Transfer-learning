% 英文图3D：Inter-cell SD@1s (Moderates only) vs ΔHit — N/T 合并
%
% 仅使用 Moderates 细胞（z-score@1s ∈ [-1,1]）计算 SD。
% 区分方法同 B 图。Naive 与 Transfer 合并为一张散点图。
%
% Data scope:
% - Transfer: AudioLightBaseline，全部 LW 会话（ceiling excluded）
% - Naive: LightAudioBaseline + LAInterspersed，纯 LW 会话（ceiling excluded）
% - One point = one adjacent session pair (session k → session k+1).
% - ΔHit = Hit(k+1) − Hit(k).
% - x = inter-cell SD of median ZScore at 1s in session k+1, Moderates cells only.
%
% Layout: single axes
% Style: scatter + fit line + simple Spearman.
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.D_SD1sVsDeltaHit_Moderates

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

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
SessT = iKeepPureLW(DS_ALB, SessT);
SessT = iExcludeCeiling(SessT);
PairsT = iSessionPairs(SessT);
fprintf('Transfer LW: %d adjacent session pairs\n', height(PairsT));

% Batch query Moderates SD for session k+1
allDTs_T = unique(PairsT.DateTimeNext);
sdTbl_T = iBatchSD1s_Moderates(DS_ALB, allDTs_T, idx1s);

% Build Transfer data vectors
nPT = height(PairsT);
T_SD = nan(nPT, 1);
T_DH = nan(nPT, 1);
T_HK = nan(nPT, 1);
for iP = 1:nPT
	dtK1 = PairsT.DateTimeNext(iP);
	r = sdTbl_T(sdTbl_T.DateTime == dtK1, :);
	if height(r) == 1
		T_SD(iP) = r.SD_Mod;
	end
	T_DH(iP) = PairsT.PerformanceNext(iP) - PairsT.Performance(iP);
	T_HK(iP) = PairsT.Performance(iP);
end

%% ===== Part 2: Naive LW — LightAudioBaseline + LAInterspersed =====
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();

naiveDSNames  = ["LAB"; "LAI"];
naiveDSObjs   = {DS_LAB; DS_LAI};

allNaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
allNaiveSess = iExcludeAudioWaterSessions(allNaiveSess, DS_LAB, DS_LAI);
allNaiveSess = iExcludeCeilingNaive(allNaiveSess);

PairsN = iSessionPairs(allNaiveSess);
fprintf('Naive LW: %d adjacent session pairs (phase-based)\n', height(PairsN));

% Batch query Moderates SD per source dataset
naiveSD = table(NaT(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_Mod'});
for d = 1:numel(naiveDSObjs)
	DS = naiveDSObjs{d};
	dsName = naiveDSNames(d);
	dts = unique(PairsN.DateTimeNext(PairsN.SourceNext == dsName));
	if isempty(dts), continue; end
	sdPart = iBatchSD1s_Moderates(DS, dts, idx1s);
	if ~isempty(sdPart)
		naiveSD = [naiveSD; sdPart]; %#ok<AGROW>
	end
end
[~, iU] = unique(naiveSD.DateTime);
naiveSD = naiveSD(iU, :);

nPN = height(PairsN);
N_SD = nan(nPN, 1);
N_DH = nan(nPN, 1);
N_HK = nan(nPN, 1);
for iP = 1:nPN
	dtK1 = PairsN.DateTimeNext(iP);
	r = naiveSD(naiveSD.DateTime == dtK1, :);
	if height(r) == 1
		N_SD(iP) = r.SD_Mod;
	end
	N_DH(iP) = PairsN.PerformanceNext(iP) - PairsN.Performance(iP);
	N_HK(iP) = PairsN.Performance(iP);
end

%% ===== Statistics (merged N+T, simple Spearman) =====
all_SD = [N_SD; T_SD];
all_DH = [N_DH; T_DH];

k = isfinite(all_SD) & isfinite(all_DH);
[rho, pVal] = corr(all_SD(k), all_DH(k), 'Type', 'Spearman');
fprintf('\n=== Panel D: SD@1s (Moderates) vs ΔHit (merged N+T) ===\n');
fprintf('  Simple Spearman: rho=%+.3f p=%.4g (n=%d)\n', rho, pVal, sum(k));

%% ===== Plot (single axes, 30mm wide) =====
svgName = "English_Fig3E_SD1sVsDeltaHit_Moderates.svg";
f = figure('Color', 'w', 'Name', 'English Fig3D SD@1s (Moderates) vs ΔHit');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

ax = axes(f);
hold(ax, 'on'); box(ax, 'off'); grid(ax, 'off');
ax.FontSize = 6;

colorMerge = [0.4 0.4 0.4];
scatter(ax, all_SD(k), all_DH(k), 5, colorMerge, 'LineWidth', 0.2);

% Fit line
xd = all_SD(k); yd = all_DH(k);
if numel(xd) >= 2 && std(xd) > 0
	pFit = polyfit(xd, yd, 1);
	xFit = [min(xd), max(xd)];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1);
end
hold(ax, 'off');

xlabel(ax, 'Inter-cell SD (Moderates)');
ylabel(ax, 'ΔHit');

% p-value annotation
text(ax, 0.95, 0.95, sprintf('p=%.2g', pVal), ...
	'Units', 'normalized', 'FontSize', 6, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');

% --- Export SVG
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function sdTbl = iBatchSD1s_Moderates(DS, dts, idx1s)
% Batch compute Moderates-only inter-cell SD@1s for a list of sessions.
% Moderates: per-cell median z-score@1s ∈ [-1,1]
% Returns table(DateTime, SD_Mod).
minCells = 3;

q = struct('Stimulus', 'LightWater', 'DateTime', dts);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
nts = ntsCell{1};

if isempty(nts) || ~istable(nts) || height(nts) == 0
	sdTbl = table(NaT(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_Mod'});
	return;
end

nts.CellUID = uint64(nts.CellUID);
nts.DateTime = datetime(nts.DateTime);
if ~isempty(nts.DateTime.TimeZone), nts.DateTime.TimeZone = ''; end

uDTs = unique(nts.DateTime);
nDT = numel(uDTs);
sdMod = nan(nDT, 1);

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

	% Moderates only: [-1, 1]
	vMod = vals(isfinite(vals) & vals >= -1 & vals <= 1);
	if numel(vMod) >= minCells, sdMod(iDT) = std(vMod, 0, 1); end
end

sdTbl = table(uDTs, sdMod, 'VariableNames', {'DateTime','SD_Mod'});
end

function s = iAsterisk(p)
if p < 0.001
	s = "***";
elseif p < 0.01
	s = "**";
elseif p < 0.05
	s = "*";
else
	s = " n.s.";
end
end

function [rho, p] = iPartialSpearman(x, y, z)
% Partial Spearman correlation of x and y, controlling for z.
rx = tiedrank(x); ry = tiedrank(y); rz = tiedrank(z);
rx_res = rx - rz * (rz \ rx);
ry_res = ry - rz * (rz \ ry);
[rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end

function AllSess = iGatherNaiveSessions(LAB, LAI)
% Gather Naive learning sessions from LAB + LAI (phase-based range selection).
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});

for iDS = 1:2
	if iDS == 1, DS = LAB; srcName = "LAB"; else, DS = LAI; srcName = "LAI"; end

	if iDS == 2
		badMice = iFindBadMiceLAI(DS);
	else
		badMice = string.empty;
	end

	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
	T.Phase = string(T.Phase);
	Tr = DS.Trials;
	mice = unique(T.Mouse);

	for iM = 1:numel(mice)
		m = mice(iM);
		if iDS == 2 && any(m == badMice), continue; end
		Tm = T(T.Mouse == m, :);
		phases = unique(Tm.Phase);
		if ~any(phases == "Naive"), continue; end

		hasLearned = any(phases == "Learned");
		hasTransfer = any(phases == "Transfer");
		sessDTs = sort(unique(Tm.DateTime));

		sessPhase = strings(numel(sessDTs), 1);
		for ii = 1:numel(sessDTs)
			ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
			ph = ph(ph ~= "" & ~ismissing(ph));
			if isempty(ph), sessPhase(ii) = ""; continue; end
			[uPh,~,ic] = unique(ph); counts = accumarray(ic,1);
			[~,mx] = max(counts); sessPhase(ii) = uPh(mx);
		end

		idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
		if hasLearned
			idxEnd = find(sessPhase == "Learned", 1, 'last');
		elseif hasTransfer
			idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
			idxEnd = idxTransferStart - 1;
		else
			idxEnd = numel(sessDTs);
		end

		if isempty(idxNaiveStart) || idxEnd < idxNaiveStart, continue; end

		for k = idxNaiveStart:idxEnd
			dt = sessDTs(k);
			blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
			TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
			if isempty(TrSess), continue; end
			lwMask = string(TrSess.Stimulus) == "LightWater";
			if ~any(lwMask), continue; end
			perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
			if ~isfinite(perf), continue; end
			AllSess = [AllSess; table(m, dt, perf, srcName, ...
				'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
		end
	end
end
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows', 'first');
AllSess = AllSess(ia, :);
end

function badMice = iFindBadMiceLAI(DS)
badMice = string.empty;
T = DS.TableQuery(["Mouse","DateTime","Phase"]);
T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
T.Phase = string(T.Phase);
mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM);
	Tm = T(T.Mouse == m, :);
	dts = unique(Tm.DateTime);
	for iDT = 1:numel(dts)
		ph = Tm.Phase(Tm.DateTime == dts(iDT));
		if any(ph == "Naive" | ph == "Learned")
			if iHasStimulus(DS, m, dts(iDT), "AudioWater")
				badMice = [badMice; m]; %#ok<AGROW>
				break;
			end
		end
	end
end
badMice = unique(badMice);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess), 1);
for i = 1:height(AllSess)
	if AllSess.Source(i) == "LAB", DS = LAB; else, DS = LAI; end
	if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
		keep(i) = false;
	end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
	rows = find(AllSess.Mouse == m);
	p = double(AllSess.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus)); st = st(~ismissing(st));
tf = any(st == string(stim));
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
