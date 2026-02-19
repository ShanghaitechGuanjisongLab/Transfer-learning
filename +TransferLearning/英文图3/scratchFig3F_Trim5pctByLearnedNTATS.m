% scratchFig3F_Trim5pctByLearnedNTATS.m
%
% Question:
% In English Fig3F metric (pair-averaged inter-cell SD@1s in Transfer LW),
% if we trim AW-Learned cells by removing:
%   - top 5% largest cells among NTATS@1s > 0
%   - bottom 5% smallest cells among NTATS@1s < 0
% (defined on AudioWater Learned phase, per mouse),
% then recompute Transfer LW inter-cell SD using remaining cells.
%
% This script tests:
%   1) Whether trimmed Transfer SD is significantly LOWER than full-cell Transfer SD
%      (paired across the same session pairs).
%   2) Whether trimmed Transfer SD differs from Naive SD (unpaired vs Fig3F Naive).
%
% Execution:
%   TransferLearning.英文图3.scratchFig3F_Trim5pctByLearnedNTATS

%% --- Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

trimPct = 0.05;
minCells = 3;

%% --- Time axis / index for 1s
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('Trim5pct:No1s', 'Cannot find a sample close to 1s.');
end

%% ===== Transfer: build session pairs (matches English Fig3F) =====
ALB = TransferLearning.AudioLightBaseline();
SessT = iLightWaterSessions(ALB);
SessT = iExcludeCeiling(SessT);
PairsT = iSessionPairs(SessT);

fprintf('\n=== Fig3F metric with AW-Learned trimming (%.1f%% per tail group) ===\n', trimPct*100);
fprintf('Transfer LW: %d adjacent session pairs (%d mice)\n', height(PairsT), numel(unique(string(PairsT.Mouse))));

% DateTime -> Mouse lookup table
SessT.DateTime = datetime(SessT.DateTime);
if ~isempty(SessT.DateTime.TimeZone), SessT.DateTime.TimeZone = ''; end
SessT.Mouse = string(SessT.Mouse);
dtMouseT = unique(SessT(:, {'DateTime','Mouse'}));

%% ===== Step 1: per-mouse keep CellUID set based on AW Learned NTATS@1s =====
miceT = unique(string(PairsT.Mouse));
keepMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

fprintf('\nBuilding per-mouse keep-cell sets from AW Learned NTATS@1s...\n');
for iM = 1:numel(miceT)
	m = miceT(iM);
	[uid, ntats_aw] = iAWLearnedNTATS(ALB, m);
	if isempty(uid) || isempty(ntats_aw)
		keepMap(char(m)) = uint64.empty(0,1);
		fprintf('  %s: AW Learned missing -> keep=0 (will yield NaNs)\n', m);
		continue;
	end
	if size(ntats_aw, 2) < idx1s
		keepMap(char(m)) = uint64.empty(0,1);
		fprintf('  %s: AW Learned NTATS shorter than idx1s -> keep=0\n', m);
		continue;
	end

	v1s = double(ntats_aw(:, idx1s));
	finiteMask = isfinite(v1s);
	uid = uint64(uid(finiteMask));
	v1s = v1s(finiteMask);

	posMask = v1s > 0;
	negMask = v1s < 0;

	nPos = nnz(posMask);
	nNeg = nnz(negMask);
	nRemPos = floor(trimPct * nPos);
	nRemNeg = floor(trimPct * nNeg);

	remove = false(numel(uid), 1);
	if nRemPos > 0
		posIdx = find(posMask);
		[~, ord] = sort(v1s(posMask), 'descend');
		remove(posIdx(ord(1:nRemPos))) = true;
	end
	if nRemNeg > 0
		negIdx = find(negMask);
		[~, ord] = sort(v1s(negMask), 'ascend');
		remove(negIdx(ord(1:nRemNeg))) = true;
	end

	keepUID = uid(~remove);
	keepMap(char(m)) = keepUID;

	fprintf('  %s: AW Learned finite=%d, pos=%d(rem %d), neg=%d(rem %d) -> keep=%d\n', ...
		m, numel(uid), nPos, nRemPos, nNeg, nRemNeg, numel(keepUID));
end

%% ===== Step 2: compute Transfer SD per session (full vs trimmed) from NTS =====
allDTs_T = unique([PairsT.DateTime; PairsT.DateTimeNext]);
qT = struct('Stimulus', 'LightWater', 'DateTime', allDTs_T);
ntsCellT = ALB.QueryNTS(qT, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
if isempty(ntsCellT) || isempty(ntsCellT{1})
	error('Trim5pct:NoNTS', 'ALB.QueryNTS returned empty for Transfer sessions.');
end
sdSessT = iBatchSD1s_FullAndTrimmed(ntsCellT{1}, idx1s, dtMouseT, keepMap, minCells);

% Pair-averaged SD: mean(SD_k, SD_{k+1})
T_SD_All  = nan(height(PairsT), 1);
T_SD_Trim = nan(height(PairsT), 1);

for iP = 1:height(PairsT)
	dtK  = PairsT.DateTime(iP);
	dtK1 = PairsT.DateTimeNext(iP);
	rK  = sdSessT(sdSessT.DateTime == dtK, :);
	rK1 = sdSessT(sdSessT.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_All) && isfinite(rK1.SD_All)
			T_SD_All(iP) = (rK.SD_All + rK1.SD_All) / 2;
		end
		if isfinite(rK.SD_Trim) && isfinite(rK1.SD_Trim)
			T_SD_Trim(iP) = (rK.SD_Trim + rK1.SD_Trim) / 2;
		end
	end
end

kPair = isfinite(T_SD_All) & isfinite(T_SD_Trim);

%% ===== Naive SD (matches English Fig3F) =====
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

naiveSD = table(NaT(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_All'});
for d = 1:numel(naiveDSList)
	DS = naiveDSList{d}.DS;
	dsName = naiveDSList{d}.Name;
	dts = unique([PairsN.DateTime(PairsN.Source == dsName); PairsN.DateTimeNext(PairsN.SourceNext == dsName)]);
	if isempty(dts), continue; end
	q = struct('Stimulus', 'LightWater', 'DateTime', dts);
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	if ~isempty(ntsCell) && ~isempty(ntsCell{1})
		naiveSD = [naiveSD; iBatchSD1s_OneColumn(ntsCell{1}, idx1s, minCells)]; %#ok<AGROW>
	end
end
[~, iU] = unique(naiveSD.DateTime);
naiveSD = naiveSD(iU, :);

N_SD = nan(height(PairsN), 1);
for iP = 1:height(PairsN)
	dtK  = PairsN.DateTime(iP);
	dtK1 = PairsN.DateTimeNext(iP);
	rK  = naiveSD(naiveSD.DateTime == dtK, :);
	rK1 = naiveSD(naiveSD.DateTime == dtK1, :);
	if height(rK) == 1 && height(rK1) == 1
		if isfinite(rK.SD_All) && isfinite(rK1.SD_All)
			N_SD(iP) = (rK.SD_All + rK1.SD_All) / 2;
		end
	end
end

kN = isfinite(N_SD);
kTrim = isfinite(T_SD_Trim);

%% ===== Statistics =====
% 1) Paired test: Trimmed Transfer < Full Transfer
if any(kPair)
	d = T_SD_Trim(kPair) - T_SD_All(kPair);
	pPairedLess = signrank(d, 0, 'tail', 'left');
	pPairedTwo  = signrank(d, 0, 'tail', 'both');
else
	pPairedLess = NaN; pPairedTwo = NaN;
end

% 2) Unpaired test: Trimmed Transfer vs Naive (difference)
pTrimVsNaive = ranksum(T_SD_Trim(kTrim), N_SD(kN));

fprintf('\n=== Results (All cells, SD@1s mean of adjacent pair) ===\n');
fprintf('Transfer FULL:  mean=%.4f, SEM=%.4f, n=%d pairs\n', mean(T_SD_All(isfinite(T_SD_All))), std(T_SD_All(isfinite(T_SD_All)))/sqrt(nnz(isfinite(T_SD_All))), nnz(isfinite(T_SD_All)));
fprintf('Transfer TRIM:  mean=%.4f, SEM=%.4f, n=%d pairs\n', mean(T_SD_Trim(kTrim)), std(T_SD_Trim(kTrim))/sqrt(nnz(kTrim)), nnz(kTrim));
fprintf('Naive (FULL):   mean=%.4f, SEM=%.4f, n=%d pairs\n', mean(N_SD(kN)), std(N_SD(kN))/sqrt(nnz(kN)), nnz(kN));

fprintf('\nPaired (Transfer TRIM < Transfer FULL):\n');
fprintf('  signrank(one-sided, left) p = %.6g\n', pPairedLess);
fprintf('  signrank(two-sided)       p = %.6g\n', pPairedTwo);

fprintf('\nUnpaired (Transfer TRIM vs Naive FULL):\n');
fprintf('  ranksum(two-sided)        p = %.6g\n', pTrimVsNaive);

assignin('base', 'Fig3F_Transfer_SD_Full', T_SD_All(isfinite(T_SD_All)));
assignin('base', 'Fig3F_Transfer_SD_Trim5pct', T_SD_Trim(kTrim));
assignin('base', 'Fig3F_Naive_SD_Full', N_SD(kN));
assignin('base', 'Fig3F_Trim5pct_pPairedLess', pPairedLess);
assignin('base', 'Fig3F_Trim5pct_pTrimVsNaive', pTrimVsNaive);

%% ===== Local functions (copied from English Fig3F / mediation scripts) =====

function sdTbl = iBatchSD1s_OneColumn(nts, idx1s, minCells)
if nargin < 3, minCells = 3; end
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

function sdTbl = iBatchSD1s_FullAndTrimmed(nts, idx1s, dtMouseTbl, keepMap, minCells)
if nargin < 5, minCells = 3; end
if isempty(nts) || ~istable(nts) || height(nts) == 0
	sdTbl = table(NaT(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
		'VariableNames', {'DateTime','SD_All','SD_Trim','NCells_All','NCells_Trim','Mouse'});
	return;
end

nts.CellUID = uint64(nts.CellUID);
nts.DateTime = datetime(nts.DateTime);
if ~isempty(nts.DateTime.TimeZone), nts.DateTime.TimeZone = ''; end

% Normalize dtMouseTbl
if ~isempty(dtMouseTbl)
	dtMouseTbl.DateTime = datetime(dtMouseTbl.DateTime);
	if ~isempty(dtMouseTbl.DateTime.TimeZone), dtMouseTbl.DateTime.TimeZone = ''; end
	dtMouseTbl.Mouse = string(dtMouseTbl.Mouse);
end

uDTs = unique(nts.DateTime);
nDT = numel(uDTs);

sdAll  = nan(nDT, 1);
sdTrim = nan(nDT, 1);
nAll   = nan(nDT, 1);
nTrim  = nan(nDT, 1);
outMouse = strings(nDT, 1);

for iDT = 1:nDT
	dt = uDTs(iDT);
	sessRows = nts(nts.DateTime == dt, :);

	% lookup mouse
	m = "";
	if ~isempty(dtMouseTbl)
		r = dtMouseTbl(dtMouseTbl.DateTime == dt, :);
		if height(r) >= 1
			m = string(r.Mouse(1));
		end
	end
	outMouse(iDT) = m;

	% KeepUID for this mouse
	keepUID = uint64.empty(0,1);
	if m ~= "" && keepMap.isKey(char(m))
		keepUID = uint64(keepMap(char(m)));
	end

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
		nAll(iDT) = numel(vAll);
	end

	if ~isempty(keepUID)
		keepMask = ismember(uCells, keepUID);
		vKeep = vals(keepMask & isfinite(vals));
		if numel(vKeep) >= minCells
			sdTrim(iDT) = std(vKeep, 0, 1);
			nTrim(iDT) = numel(vKeep);
		end
	end
end

sdTbl = table(uDTs, sdAll, sdTrim, nAll, nTrim, outMouse, ...
	'VariableNames', {'DateTime','SD_All','SD_Trim','NCells_All','NCells_Trim','Mouse'});
end

function [uid, ntats] = iAWLearnedNTATS(DS, mouse)
uid = uint64.empty(0,1); ntats = [];
Tcheck = DS.TableQuery(["TrialUID"], Mouse=char(mouse), Stimulus="AudioWater", Phase="Learned");
if isempty(Tcheck) || height(Tcheck) == 0, return; end
G = DS.QueryNTATS(struct('Mouse',char(mouse),'Stimulus','AudioWater','Phase','Learned'), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
if isempty(G) || height(G) == 0, return; end
uid = uint64(G.CellUID);
X = G.NTATS;
if isa(X, 'MATLAB.DataTypes.NDTable'), X = X.Data; end
ntats = squeeze(double(X));
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
