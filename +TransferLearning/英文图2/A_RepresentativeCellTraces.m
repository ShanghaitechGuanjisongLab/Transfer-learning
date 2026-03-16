% 英文图2A：3个代表性细胞 × 3阶段 × 3回合 = 27条DeltaF曲线
%
% 从声转光组(AudioLightBaseline)中自动挑选3个细胞和9个回合，
% 以彰显Naive阶段活跃模式的不稳定性和Learned/Transfer阶段的稳定性。
%
% 布局：3行(细胞) × 3列(阶段)，每个子图叠加3条DeltaF曲线(0~2s)。
%
% 细胞+回合选取规则：
%   Naive AudioOnly 3回合：至少有一个活跃、一个不活跃，且3细胞的模式不完全相同
%   Learned AudioWater 3回合：2个细胞都活跃、1个不活跃
%   Transfer LightWater 3回合：同Learned要求，且活跃模式与Learned一致
%
% Execution:
%   TransferLearning.英文图2.A_RepresentativeCellTraces


rng(42); % 固定随机种子，确保可复现

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

baseMask = (xsSec >= -3) & (xsSec < 0);
plotMask = (xsSec >= 0) & (xsSec <= 1);
xsPlot = xsSec(plotMask);

% Find index of t=0 within plotMask for baseline alignment
[idx0Plot, ~] = iFindTimeIndex(xsPlot, 0, 0.25);
kSigma = 5;

[idx0s, ok0s] = iFindTimeIndex(xsSec, 0, 0.25);
if ~ok0s
	error('Fig2A:No0s', 'Cannot find sample close to 0s.');
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig2A:No1s', 'Cannot find sample close to 1s.');
end

% --- Query single-trial DeltaF for 3 phases
ntsNaive    = DS.QueryNTS(struct('Stimulus', 'AudioOnly'),                          UniExp.Flags.DeltaF, 1:24);
ntsLearned  = DS.QueryNTS(struct('Phase', 'Learned',  'Stimulus', 'AudioWater'),    UniExp.Flags.DeltaF, 1:24);
ntsTransfer = DS.QueryNTS(struct('Phase', 'Transfer', 'Stimulus', 'LightWater'),    UniExp.Flags.DeltaF, 1:24);

ntsN = ntsNaive{1};
ntsL = ntsLearned{1};
ntsT = ntsTransfer{1};

% --- Find common cells across all 3 phases
cellsN = unique(uint64(ntsN.CellUID));
cellsL = unique(uint64(ntsL.CellUID));
cellsT = unique(uint64(ntsT.CellUID));
commonCells = intersect(intersect(cellsN, cellsL), cellsT);
fprintf('Common cells across 3 phases: %d\n', numel(commonCells));

if numel(commonCells) < 3
	error('Fig2A:TooFewCells', 'Need at least 3 common cells, found %d.', numel(commonCells));
end

% --- Precompute per-cell, per-trial activity for each phase
% Active: (v1-v0) > kSigma*baseSd; Inactive: (v1-v0)<0 AND max(0~1s)-v0 <= kSigma*baseSd
[cellActN, cellInactN, cellTrialsN, cellSigN] = iComputeTrialActivity(ntsN, commonCells, baseMask, idx0s, idx1s, kSigma, plotMask);
[cellActL, cellInactL, cellTrialsL, cellSigL] = iComputeTrialActivity(ntsL, commonCells, baseMask, idx0s, idx1s, kSigma, plotMask);
[cellActT, cellInactT, cellTrialsT, cellSigT] = iComputeTrialActivity(ntsT, commonCells, baseMask, idx0s, idx1s, kSigma, plotMask);

% --- Search for 3 cells meeting all criteria
nCommon = numel(commonCells);

% Per-cell trial counts: how many active/inactive trials in each phase
nActL = zeros(nCommon, 1); nInactL = zeros(nCommon, 1);
nActT = zeros(nCommon, 1); nInactT = zeros(nCommon, 1);
nActN = zeros(nCommon, 1); nInactN = zeros(nCommon, 1);

for iC = 1:nCommon
	if ~isempty(cellActL{iC}),   nActL(iC) = sum(cellActL{iC});   nInactL(iC) = sum(cellInactL{iC}); end
	if ~isempty(cellActT{iC}),   nActT(iC) = sum(cellActT{iC});   nInactT(iC) = sum(cellInactT{iC}); end
	if ~isempty(cellActN{iC}),   nActN(iC) = sum(cellActN{iC});   nInactN(iC) = sum(cellInactN{iC}); end
end

% Candidate "active" cells: >=3 active in L, >=3 active in T, has both active+inactive in N
% These cells will be shown as "active" in Learned/Transfer (pick 3 consistently active trials)
candActive = (nActL >= 3) & (nActT >= 3) & (nActN >= 1) & (nInactN >= 1);
% Candidate "inactive" cells: >=3 inactive in L, >=3 inactive in T, has both active+inactive in N
candInactive = (nInactL >= 3) & (nInactT >= 3) & (nActN >= 1) & (nInactN >= 1);

idxActive   = find(candActive);
idxInactive = find(candInactive);
fprintf('Candidate active cells: %d, candidate inactive cells: %d\n', numel(idxActive), numel(idxInactive));

% If no active candidates, relax: allow Naive to just have >=3 trials with any pattern
if isempty(idxActive)
	candActive2 = (nActL >= 3) & (nActT >= 3) & ((nActN + nInactN) >= 3);
	idxActive = find(candActive2);
	fprintf('(Relaxed) Candidate active cells: %d\n', numel(idxActive));
end

if isempty(idxActive) && isempty(idxInactive)
	error('Fig2A:NoCandidates', 'No candidate cells found.');
end

% If still no active cells, try "all inactive" with Naive variation
if isempty(idxActive)
	% Fall back to 3 inactive cells with different Naive patterns
	fprintf('No active candidates. Using 3 inactive cells with Naive variability.\n');
	idxActive = []; % ensure empty
end

% We want at least one active and one inactive. If missing, flip or relax further.
if isempty(idxActive) || isempty(idxInactive)
	% Use whatever we have - at least 3 cells of one type
	if numel(idxActive) >= 3
		allCand = idxActive;
		candTypes = true(size(allCand)); % all "active"
	elseif numel(idxInactive) >= 3
		allCand = idxInactive;
		candTypes = false(size(allCand)); % all "inactive"
	else
		error('Fig2A:NoCandidates', 'Need at least 3 candidate cells of at least one type.');
	end
	% Still search for best variability in Naive
	bestScore = -Inf;
	bestCells = [];
	bestTrialsN = {};
	bestTrialsL = {};
	bestTrialsT = {};
	nCand = numel(allCand);
	maxSearch = min(nCand, 200);
	searchIdx = allCand(randperm(nCand, maxSearch));
	for iCombo = 1:min(nchoosek(maxSearch, 3), 5000)
		cIdx = searchIdx(randperm(maxSearch, 3));
		cIdx = sort(cIdx);
		isAct = candTypes(1); % all same type
		[tN, okN] = iPickNaiveTrials_Indep(cellActN, cellInactN, cellSigN, cIdx);
		if ~okN, continue; end
		[tL, okL] = iPickSameStatusTrials(cellActL, cellInactL, cIdx, isAct);
		if ~okL, continue; end
		[tT, okT] = iPickSameStatusTrials(cellActT, cellInactT, cIdx, isAct);
		if ~okT, continue; end
		if isAct && ~iCheckActivePeakIncrease(cIdx, true(size(cIdx)), tN, tL, tT, cellSigN, cellSigL, cellSigT, cellActN, idx0s, idx1s)
			continue;
		end
		sc = iNaiveVariabilityScore(cellActN, cellSigN, cIdx, tN, idx1s);
		if sc > bestScore
			bestScore = sc;
			bestCells = cIdx;
			bestTrialsN = tN;
			bestTrialsL = tL;
			bestTrialsT = tT;
		end
	end
else
	% Normal case: mix of active and inactive cells
	% Use (2 active, 1 inactive) only
	bestScore = -Inf;
	bestCells = [];
	bestTrialsN = {};
	bestTrialsL = {};
	bestTrialsT = {};

	% Limit search space
	maxA = min(numel(idxActive), 84);
	maxI = min(numel(idxInactive), 200);
	% Sort by signal strength / variability for smarter selection
	sortA = idxActive(randperm(numel(idxActive), maxA));
	sortI = idxInactive(randperm(numel(idxInactive), maxI));

	% (2 active, 1 inactive)
	if maxA >= 2
		for iA1 = 1:maxA-1
			for iA2 = iA1+1:min(iA1+30, maxA)
				for iI = 1:maxI
					cIdx = [sortA(iA1), sortA(iA2), sortI(iI)];
					cIsAct = [true, true, false];
					[tN, okN] = iPickNaiveTrials_Indep(cellActN, cellInactN, cellSigN, cIdx);
					if ~okN, continue; end
					[tL, okL] = iPickMixedStatusTrials(cellActL, cellInactL, cIdx, cIsAct);
					if ~okL, continue; end
					[tT, okT] = iPickMixedStatusTrials(cellActT, cellInactT, cIdx, cIsAct);
					if ~okT, continue; end
					if ~iCheckActivePeakIncrease(cIdx, cIsAct, tN, tL, tT, cellSigN, cellSigL, cellSigT, cellActN, idx0s, idx1s)
						continue;
					end
					sc = iNaiveVariabilityScore(cellActN, cellSigN, cIdx, tN, idx1s);
					if sc > bestScore
						bestScore = sc;
						bestCells = cIdx;
						bestTrialsN = tN;
						bestTrialsL = tL;
						bestTrialsT = tT;
					end
				end
			end
		end
	end
end

if isempty(bestCells)
	error('Fig2A:NoValidCombo', 'Cannot find 3 cells + trials meeting all criteria.');
end

fprintf('Selected cells (common-idx): [%d, %d, %d], score=%.4f\n', bestCells(1), bestCells(2), bestCells(3), bestScore);
selectedCellUIDs = commonCells(bestCells);
fprintf('CellUIDs: [%d, %d, %d]\n', selectedCellUIDs(1), selectedCellUIDs(2), selectedCellUIDs(3));

% --- 验证：打印每个细胞在每个阶段的每个选中回合的活跃状态
phaseLabels_ = {'Naive', 'Learned', 'Transfer'};
phaseActs_   = {cellActN, cellActL, cellActT};
phaseInacts_ = {cellInactN, cellInactL, cellInactT};
phaseSigs_   = {cellSigN, cellSigL, cellSigT};
phaseTrials_ = {bestTrialsN, bestTrialsL, bestTrialsT};
fprintf('\n=== Activity verification (active: delta>%d*baseSd; inactive: delta<0 AND maxDelta<=%d*baseSd) ===\n', kSigma, kSigma);
for iC_ = 1:3
	ci_ = bestCells(iC_);
	cuid_ = commonCells(ci_);
	for iP_ = 1:3
		actAll_   = phaseActs_{iP_}{ci_};
		inactAll_ = phaseInacts_{iP_}{ci_};
		sigAll_   = phaseSigs_{iP_}{ci_};
		tIdx_     = phaseTrials_{iP_}{iC_};
		for iT_ = 1:numel(tIdx_)
			ti_ = tIdx_(iT_);
			v0_ = sigAll_(ti_, idx0s);
			v1_ = sigAll_(ti_, idx1s);
			delta_ = v1_ - v0_;
			maxD_  = max(sigAll_(ti_, plotMask)) - v0_;
			baseSd_ = std(sigAll_(ti_, baseMask), 0, 'omitnan');
			thresh_ = kSigma * baseSd_;
			isAct_   = actAll_(ti_);
			isInact_ = inactAll_(ti_);
			fprintf('  Cell %d (UID=%d) %-8s Trial#%02d: v0=%.2f v1=%.2f delta=%7.2f maxD=%7.2f thresh=%7.2f act=%d inact=%d\n', ...
				iC_, cuid_, phaseLabels_{iP_}, ti_, v0_, v1_, delta_, maxD_, thresh_, isAct_, isInact_);
		end
	end
end
fprintf('\n');

% --- Extract traces for plotting
traceData = cell(3, 3); % {cell, phase}, each is [3 x nTimePlot]
for iC = 1:3
	ci = bestCells(iC);
	% Naive
	sigAll = cellSigN{ci};
	tIdx = bestTrialsN{iC};
	raw = sigAll(tIdx, plotMask);
	traceData{iC, 1} = raw - raw(:, idx0Plot);
	% Learned
	sigAll = cellSigL{ci};
	tIdx = bestTrialsL{iC};
	raw = sigAll(tIdx, plotMask);
	traceData{iC, 2} = raw - raw(:, idx0Plot);
	% Transfer
	sigAll = cellSigT{ci};
	tIdx = bestTrialsT{iC};
	raw = sigAll(tIdx, plotMask);
	traceData{iC, 3} = raw - raw(:, idx0Plot);
end

%% 
% --- Plot: 3 rows (cells) × 3 columns (phases)
f = figure('Color', 'w', 'Name', 'English Fig2A Representative Cell Traces');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

tlo = tiledlayout(f, 3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

phaseNames = ["Naïve", "Learned", "Transfer"];
trialColors = TransferLearning.FigurePalette(3);
trialLabels = ["Trial 1", "Trial 2", "Trial 3"];
hLeg = gobjects(3, 1);
axPerRow = gobjects(3, 3); % [row, col]

for iC = 1:3
	for iP = 1:3
		ax = nexttile(tlo);
		axPerRow(iC, iP) = ax;
		hold(ax, 'on');

		traces = traceData{iC, iP}; % [3 x nTime]
		for iT = 1:3
			h = plot(ax, xsPlot, traces(iT, :), 'Color', trialColors(iT, :), 'LineWidth', 0.8);
			if iC == 1 && iP == 1
				hLeg(iT) = h;
			end
		end

		xlim(ax, [xsPlot(1), xsPlot(end)]);

		box(ax, 'off');
		grid(ax, 'off');
		ax.FontSize = 12;
		ax.TickDir = 'out';

		% Column titles on top row only
		if iC == 1
			title(ax, phaseNames(iP),FontSize=12);
		end

		% Y axis: hide for non-left columns
		if iP == 1
			ylabel(ax, sprintf('Cell %d', iC),FontSize=12);
		else
			ax.YAxis.Visible = false;
		end
		ax.YTick = [];

		% X axis: hide for non-bottom rows
		if iC < 3
			ax.XAxis.Visible = false;
		end
	end
end

% Unify ylim per row (same cell across phases)
for iC = 1:3
	MATLAB.Graphics.UnifyAxesLims(axPerRow(iC, :), @ylim);
end

xlabel(tlo, 'Time (s)');

% --- Legend
lg = legend(hLeg, trialLabels, 'Box', 'off', 'Orientation', 'horizontal',FontSize=12);
lg.Layout.Tile = 'north';

% --- Export SVG
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgName = "English_Fig2A_RepresentativeCellTraces.svg";
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'English_Fig2A_CellUIDs', selectedCellUIDs);

%% --- Local helpers

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function [cellAct, cellInact, cellTrials, cellSig] = iComputeTrialActivity(nts, commonCells, baseMask, idx0s, idx1s, kSigma, respMask)
% For each common cell, compute per-trial activity (logical vector) and store signals.
% Active:   (v1s - v0s) > kSigma * baseSd
% Inactive: (v1s - v0s) < 0  AND  max(sig(0~1s)) - v0s <= kSigma * baseSd
% cellAct{i}:   logical vector [nTrials x 1] — active
% cellInact{i}: logical vector [nTrials x 1] — inactive (strict)
% cellTrials{i}: TrialUID vector
% cellSig{i}: [nTrials x nTime] signal matrix
nC = numel(commonCells);
cellAct   = cell(nC, 1);
cellInact = cell(nC, 1);
cellTrials = cell(nC, 1);
cellSig   = cell(nC, 1);

allCUID = uint64(nts.CellUID);
allSig = double(nts.TrialSignal);

for iC = 1:nC
	rows = (allCUID == commonCells(iC));
	if ~any(rows), continue; end
	sig = allSig(rows, :);
	tuid = uint64(nts.TrialUID(rows));

	baseSd = std(sig(:, baseMask), 0, 2, 'omitnan');
	v0 = sig(:, idx0s);
	v1 = sig(:, idx1s);
	delta = v1 - v0;

	% Peak increment in 0~1s window relative to value at t=0
	maxDelta = max(sig(:, respMask), [], 2) - v0;

	act   = isfinite(delta)    & isfinite(baseSd) & (delta > kSigma .* baseSd);
	inact = isfinite(maxDelta) & isfinite(baseSd) & (delta < 0) & (maxDelta <= kSigma .* baseSd);

	cellAct{iC}   = act;
	cellInact{iC} = inact;
	cellTrials{iC} = tuid;
	cellSig{iC}   = sig;
end
end

function [trialIdx, ok] = iPickNaiveTrials_Indep(cellAct, cellInact, cellSig, cIdx)
% Pick 3 Naive trials per cell independently (each cell gets its own 3 trials).
% Goal: for each cell, pick trials that show VARIABILITY (mix of active/inactive).
% Overall: at least one cell should have mixed active/inactive among its 3 trials.
ok = false;
trialIdx = {};

trialIdx = cell(3, 1);
hasVariation = false;

for k = 1:3
	ci = cIdx(k);
	act = cellAct{ci};
	inact = cellInact{ci};
	nT = numel(act);
	if nT < 3
		return;
	end

	actIdx = find(act);
	inactIdx = find(inact);

	if ~isempty(actIdx) && ~isempty(inactIdx)
		% Pick a mix: 1-2 active + rest inactive (or vice versa) for maximum variability
		nAct = min(numel(actIdx), 2);
		nInact = 3 - nAct;
		if numel(inactIdx) < nInact
			nInact = numel(inactIdx);
			nAct = 3 - nInact;
		end
		chosen = [actIdx(randperm(numel(actIdx), nAct)); inactIdx(randperm(numel(inactIdx), nInact))];
		trialIdx{k} = sort(chosen)';
		hasVariation = true;
	else
		% All same status - just pick first 3
		trialIdx{k} = (1:3);
	end
end

ok = hasVariation;
end

function [trialIdx, ok] = iPickMixedStatusTrials(cellAct, cellInact, cIdx, cIsAct)
% Pick 3 trials where active cells are all active and inactive cells are all inactive.
% cIsAct: logical [3x1], true = this cell should be active in these trials.
ok = false;
trialIdx = {};

nTrials = cellfun(@numel, cellAct(cIdx));
nMin = min(nTrials);
if nMin < 3, return; end

% Build activity / inactivity matrices
actMat   = false(nMin, 3);
inactMat = false(nMin, 3);
for k = 1:3
	actMat(:, k)   = cellAct{cIdx(k)}(1:nMin);
	inactMat(:, k) = cellInact{cIdx(k)}(1:nMin);
end

% Find trials where each cell matches its expected status
valid = true(nMin, 1);
for k = 1:3
	if cIsAct(k)
		valid = valid & actMat(:, k);
	else
		valid = valid & inactMat(:, k);
	end
end

validIdx = find(valid);
if numel(validIdx) < 3, return; end

chosen = validIdx(1:3);
trialIdx = cell(3, 1);
for k = 1:3
	trialIdx{k} = chosen';
end
ok = true;
end

function [trialIdx, ok] = iPickSameStatusTrials(cellAct, cellInact, cIdx, isActive)
% Pick 3 trials where all cells have the same status (all active or all inactive).
ok = false;
trialIdx = {};

nTrials = cellfun(@numel, cellAct(cIdx));
nMin = min(nTrials);
if nMin < 3, return; end

actMat   = false(nMin, 3);
inactMat = false(nMin, 3);
for k = 1:3
	actMat(:, k)   = cellAct{cIdx(k)}(1:nMin);
	inactMat(:, k) = cellInact{cIdx(k)}(1:nMin);
end

if isActive
	valid = all(actMat, 2);
else
	valid = all(inactMat, 2);
end

validIdx = find(valid);
if numel(validIdx) < 3, return; end

chosen = validIdx(1:3);
trialIdx = cell(3, 1);
for k = 1:3
	trialIdx{k} = chosen';
end
ok = true;
end

function score = iNaiveVariabilityScore(cellActN, cellSigN, cIdx, naiveTrialIdx, idx1s)
% Score how variable the Naive responses are for selected cells+trials.
% Higher = more variability = better illustration.
score = 0;
for k = 1:3
	ci = cIdx(k);
	tIdx = naiveTrialIdx{k};
	sig = cellSigN{ci};
	vals = sig(tIdx, idx1s);
	score = score + std(vals, 'omitnan');
end
end

function ok = iCheckActivePeakIncrease(cIdx, cIsAct, tN, tL, tT, sigN, sigL, sigT, actN, idx0s, idx1s)
% For each "active" cell:
%   1) max(delta in Learned) > max(delta in Naive)  (delta = v1 - v0)
%   2) max(delta in Transfer) > max(delta in Naive)
%   3) Among ALL selected active trials (Naive active + Learned + Transfer),
%      max(delta) / min(delta) <= 2  (strongest ≤ 2× weakest)
ok = true;
for k = 1:numel(cIdx)
	if ~cIsAct(k), continue; end
	ci = cIdx(k);
	% delta = v1 - v0 for selected trials in each phase
	deltaN = sigN{ci}(tN{k}, idx1s) - sigN{ci}(tN{k}, idx0s);
	deltaL = sigL{ci}(tL{k}, idx1s) - sigL{ci}(tL{k}, idx0s);
	deltaT = sigT{ci}(tT{k}, idx1s) - sigT{ci}(tT{k}, idx0s);

	% Check 1 & 2: peak delta in L/T > peak delta in N
	if max(deltaL) <= max(deltaN) || max(deltaT) <= max(deltaN)
		ok = false;
		return;
	end

	% Check 3 (relaxed): collect delta of all "active" trials across phases
	actNaive = actN{ci};
	actTrialsN = tN{k};
	isActN = actNaive(actTrialsN);
	allActDelta = [deltaN(isActN); deltaL; deltaT];
	if max(allActDelta) > 5 * min(allActDelta)
		ok = false;
		return;
	end
end
end
