% 探索 Naive 学习过程：哪些特征能显著预测 Naive→Learned 相邻会话对的 ΔHit？
%
% 数据源：LightAudioBaseline + LAInterspersed（排除 AudioWater 混鼠）
% 会话范围：Naive→Learned（若无 Learned，以 Transfer 前最后一个 LW 会话代替）
% 排除 AudioWater 回合的会话、以及首次达到 100% 及之后的会话
% 时间点：0.3s, 0.5s, 1.0s, 1.5s
% 层分组：合并L2/3+L5, 仅L2/3, 仅L5

fprintf('=== Naive Feature Exploration ===\n');

% --- Load datasets ---
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

% --- Time axis ---
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);

timePoints = [0.3, 0.5, 1.0, 1.5];
idxTP = nan(size(timePoints));
for iT = 1:numel(timePoints)
	[dt, idx] = min(abs(xsSec - timePoints(iT)));
	if dt <= 0.25, idxTP(iT) = idx; end
end
kSigma = 3;

% --- Gather sessions from both datasets ---
fprintf('Building session list from LightAudioBaseline + LAInterspersed...\n');
AllSess = iGatherNaiveSessions(LAB, LAI);
fprintf('Total Naive sessions (before filtering): %d from %d mice\n', height(AllSess), numel(unique(AllSess.Mouse)));

% --- Exclude AudioWater-contaminated sessions ---
AllSess = iExcludeAudioWaterSessions(AllSess);
fprintf('After AudioWater exclusion: %d sessions\n', height(AllSess));

% --- Exclude 100% ceiling and after ---
AllSess = iExcludeCeiling(AllSess);
fprintf('After ceiling exclusion: %d sessions\n', height(AllSess));

% --- Build adjacent pairs ---
SessSpeed = iSessionDeltaNext(AllSess);
nPairs = height(SessSpeed);
fprintf('Naive session pairs: %d\n', nPairs);

% --- Learned LW signal (per cell, per mouse) ---
% For each mouse, get Learned LW NTATS. If no Learned phase,
% use the last LW session before Transfer.
% We will do this per-mouse inside the loop.

% --- Build feature name list (same as Transfer exploration) ---
layerNames = ["All","MOp23","MOp5"];
nTP = numel(timePoints); nLayers = numel(layerNames);

featureNames = {};
for iTP = 1:nTP
	tpStr = strrep(sprintf('%.1fs', timePoints(iTP)), '.', 'p');
	for iL = 1:nLayers
		prefix = [tpStr '_' char(layerNames(iL)) '_'];
		featureNames = [featureNames, ...
			{[prefix 'ReuseKL'], [prefix 'CorrKL'], [prefix 'CorrK1L'], ...
			 [prefix 'CorrKK1'], [prefix 'SD_K'], [prefix 'SD_K1'], ...
			 [prefix 'ActFrac_K'], [prefix 'ActFrac_K1'], ...
			 [prefix 'MeanNTATS_K'], [prefix 'MeanNTATS_K1'], ...
			 [prefix 'DeltaCorrL'], [prefix 'DeltaSD'], ...
			 [prefix 'DeltaActFrac'], [prefix 'DeltaMeanNTATS'], ...
			 [prefix 'ReuseK1L'], [prefix 'DeltaReuse']}]; %#ok<AGROW>
	end
end
featureNames = [featureNames, {'Hit_K'}];
for iL = 1:nLayers
	ln = char(layerNames(iL));
	featureNames = [featureNames, {['Div1s_' ln '_K'], ['Div1s_' ln '_K1'], ['DeltaDiv1s_' ln]}]; %#ok<AGROW>
end

nFeatures = numel(featureNames);
featureValues = nan(nPairs, nFeatures);

layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};

% --- Compute features ---
fprintf('Computing %d features for %d session pairs...\n', nFeatures, nPairs);
for iPair = 1:nPairs
	m = SessSpeed.Mouse(iPair);
	dtK = SessSpeed.DateTime(iPair);
	dtK1 = SessSpeed.DateTimeNext(iPair);
	src = SessSpeed.Source(iPair);

	% Select which DS this mouse belongs to
	DS = iGetDS(src, LAB, LAI);

	% Per-cell NTATS for session k and k+1
	[uidK, ntatsK] = iSessionNTATS(DS, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(DS, m, dtK1);

	% Learned signal for this mouse
	[learnedMouseUID, learnedMouseX] = iLearnedSignal(DS, m);

	% Cell layer lookup
	C = DS.Cells;
	C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse); C.ZLayer = string(C.ZLayer);
	cellLayer = iCellLayerLookup(C, m);

	% Trial-level data for divergence
	trialsK = iSessionTrials(DS, m, dtK);
	trialsK1 = iSessionTrials(DS, m, dtK1);

	col = 0;

	for iTP = 1:nTP
		idx = idxTP(iTP);
		if ~isfinite(idx), col = col + 16*nLayers; continue; end

		for iL = 1:nLayers
			lFilt = layerFilters{iL};

			[~, iK_kl, iL_kl] = iCommonCells(uidK, learnedMouseUID, cellLayer, lFilt);
			[~, iK1_k1l, iL_k1l] = iCommonCells(uidK1, learnedMouseUID, cellLayer, lFilt);
			[~, iK_kk1, iK1_kk1] = iCommonCells(uidK, uidK1, cellLayer, lFilt);
			[~, iaK] = iLayerCells(uidK, cellLayer, lFilt);
			[~, iaK1] = iLayerCells(uidK1, cellLayer, lFilt);

			reuseKL  = iReuseRate(ntatsK,  iK_kl,   learnedMouseX, iL_kl,  baseMask, idx, kSigma);
			corrKL   = iVecCorr(ntatsK,  iK_kl,   learnedMouseX, iL_kl,  idx);
			corrK1L  = iVecCorr(ntatsK1, iK1_k1l, learnedMouseX, iL_k1l, idx);
			corrKK1  = iVecCorr(ntatsK,  iK_kk1,  ntatsK1, iK1_kk1, idx);
			sdK      = iInterCellSD(ntatsK, iaK, idx);
			sdK1     = iInterCellSD(ntatsK1, iaK1, idx);
			afK      = iActiveFrac(ntatsK,  iaK,  baseMask, idx, kSigma);
			afK1     = iActiveFrac(ntatsK1, iaK1, baseMask, idx, kSigma);
			mnK      = iMeanNTATS(ntatsK, iaK, idx);
			mnK1     = iMeanNTATS(ntatsK1, iaK1, idx);
			reuseK1L = iReuseRate(ntatsK1, iK1_k1l, learnedMouseX, iL_k1l, baseMask, idx, kSigma);

			vals = [reuseKL, corrKL, corrK1L, corrKK1, sdK, sdK1, ...
				afK, afK1, mnK, mnK1, ...
				corrK1L - corrKL, sdK1 - sdK, afK1 - afK, mnK1 - mnK, ...
				reuseK1L, reuseK1L - reuseKL];

			featureValues(iPair, col+1:col+16) = vals;
			col = col + 16;
		end
	end

	% Hit_K
	col = col + 1;
	featureValues(iPair, col) = SessSpeed.Performance(iPair);

	% Divergence @1s
	idxDiv = idxTP(3);
	for iL = 1:nLayers
		lFilt = layerFilters{iL};
		divK  = iDivergence(trialsK,  uidK,  cellLayer, lFilt, idxDiv);
		divK1 = iDivergence(trialsK1, uidK1, cellLayer, lFilt, idxDiv);
		featureValues(iPair, col+1) = divK;
		featureValues(iPair, col+2) = divK1;
		featureValues(iPair, col+3) = divK1 - divK;
		col = col + 3;
	end

	fprintf('  Pair %d/%d done (%s %s %s)\n', iPair, nPairs, src, m, datestr(dtK,'yyyy-mm-dd'));
end

% --- Target ---
deltaHit = double(SessSpeed.Speed_DeltaNext);

% --- Spearman correlation sweep ---
fprintf('\n========== [NAIVE] Spearman correlation with ΔHit (sorted by p) ==========\n');
fprintf('%-48s %5s %8s %8s\n', 'Feature', 'n', 'rho', 'p');
fprintf('%s\n', repmat('-', 1, 75));

rhoVec = nan(nFeatures,1); pVec = nan(nFeatures,1); nVec = nan(nFeatures,1);
for iF = 1:nFeatures
	x = featureValues(:, iF); y = deltaHit;
	mask = isfinite(x) & isfinite(y);
	n = nnz(mask); nVec(iF) = n;
	if n >= 5 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rhoVec(iF), pVec(iF)] = corr(x(mask), y(mask), 'Type', 'Spearman');
	end
end

resultsNaive = table(string(featureNames)', nVec, rhoVec, pVec, ...
	'VariableNames', {'Feature','n','rho','p'});
resultsNaive = sortrows(resultsNaive, 'p');

for iR = 1:min(50, height(resultsNaive))
	if isnan(resultsNaive.p(iR)), continue; end
	sig = "";
	if resultsNaive.p(iR) < 0.001, sig = "***";
	elseif resultsNaive.p(iR) < 0.01, sig = "**";
	elseif resultsNaive.p(iR) < 0.05, sig = "*";
	elseif resultsNaive.p(iR) < 0.1, sig = ".";
	end
	fprintf('%-48s %5d %+8.3f %8.4f %s\n', resultsNaive.Feature(iR), resultsNaive.n(iR), resultsNaive.rho(iR), resultsNaive.p(iR), sig);
end

% --- Partial Spearman controlling for Hit_K ---
fprintf('\n========== [NAIVE] Partial Spearman (control Hit_K) ==========\n');
fprintf('%-48s %5s %8s %8s\n', 'Feature', 'n', 'rho_p', 'p');
fprintf('%s\n', repmat('-', 1, 75));

hitK_col = find(strcmp(featureNames, 'Hit_K'));
hitK_vals = featureValues(:, hitK_col);

rhoP = nan(nFeatures,1); pP = nan(nFeatures,1); nP = nan(nFeatures,1);
for iF = 1:nFeatures
	if iF == hitK_col, continue; end
	x = featureValues(:, iF); y = deltaHit; z = hitK_vals;
	mask = isfinite(x) & isfinite(y) & isfinite(z);
	n = nnz(mask); nP(iF) = n;
	if n >= 7 && std(x(mask))>0 && std(y(mask))>0 && std(z(mask))>0
		[rhoP(iF), pP(iF)] = iPartialSpearman(x(mask), y(mask), z(mask));
	end
end

resultsNaiveP = table(string(featureNames)', nP, rhoP, pP, ...
	'VariableNames', {'Feature','n','rho_partial','p_partial'});
resultsNaiveP = sortrows(resultsNaiveP, 'p_partial');

for iR = 1:min(50, height(resultsNaiveP))
	if isnan(resultsNaiveP.p_partial(iR)), continue; end
	sig = "";
	if resultsNaiveP.p_partial(iR) < 0.001, sig = "***";
	elseif resultsNaiveP.p_partial(iR) < 0.01, sig = "**";
	elseif resultsNaiveP.p_partial(iR) < 0.05, sig = "*";
	elseif resultsNaiveP.p_partial(iR) < 0.1, sig = ".";
	end
	fprintf('%-48s %5d %+8.3f %8.4f %s\n', resultsNaiveP.Feature(iR), resultsNaiveP.n(iR), resultsNaiveP.rho_partial(iR), resultsNaiveP.p_partial(iR), sig);
end

% --- Cross-compare with Transfer results ---
fprintf('\n========== Cross-comparison: Naive vs Transfer ==========\n');
if evalin('base', "exist('ExploreFeatures_Results','var')")
	resultsTransfer = evalin('base', 'ExploreFeatures_Results');
	resultsTransferP = evalin('base', 'ExploreFeatures_Partial');

	% Merge by Feature name
	pThresh = 0.05;

	% (A) Spearman: both p < 0.05
	sigT = resultsTransfer(resultsTransfer.p < pThresh, :);
	sigN = resultsNaive(resultsNaive.p < pThresh, :);
	shared = intersect(sigT.Feature, sigN.Feature);
	fprintf('\n--- Shared features p<0.05 (Spearman, both stages) ---\n');
	if isempty(shared)
		fprintf('  (none)\n');
	else
		fprintf('%-48s | %8s %8s | %8s %8s\n', 'Feature', 'T_rho', 'T_p', 'N_rho', 'N_p');
		for i = 1:numel(shared)
			rowT = resultsTransfer(resultsTransfer.Feature == shared(i), :);
			rowN = resultsNaive(resultsNaive.Feature == shared(i), :);
			fprintf('%-48s | %+8.3f %8.4f | %+8.3f %8.4f\n', shared(i), rowT.rho(1), rowT.p(1), rowN.rho(1), rowN.p(1));
		end
	end

	% (B) Partial Spearman: both p < 0.05
	sigTP = resultsTransferP(resultsTransferP.p_partial < pThresh, :);
	sigNP = resultsNaiveP(resultsNaiveP.p_partial < pThresh, :);
	sharedP = intersect(sigTP.Feature, sigNP.Feature);
	fprintf('\n--- Shared features p<0.05 (Partial Spearman ctrl Hit_K, both stages) ---\n');
	if isempty(sharedP)
		fprintf('  (none)\n');
	else
		fprintf('%-48s | %8s %8s | %8s %8s\n', 'Feature', 'T_rhoP', 'T_pP', 'N_rhoP', 'N_pP');
		for i = 1:numel(sharedP)
			rowT = resultsTransferP(resultsTransferP.Feature == sharedP(i), :);
			rowN = resultsNaiveP(resultsNaiveP.Feature == sharedP(i), :);
			fprintf('%-48s | %+8.3f %8.4f | %+8.3f %8.4f\n', sharedP(i), rowT.rho_partial(1), rowT.p_partial(1), rowN.rho_partial(1), rowN.p_partial(1));
		end
	end

	% (C) Also show top-10 Naive + Transfer together for broader view
	% Relaxed: p < 0.1 in both
	sigT01 = resultsTransfer(resultsTransfer.p < 0.1, :);
	sigN01 = resultsNaive(resultsNaive.p < 0.1, :);
	shared01 = intersect(sigT01.Feature, sigN01.Feature);
	fprintf('\n--- Shared features p<0.1 (Spearman, both stages) ---\n');
	if isempty(shared01)
		fprintf('  (none)\n');
	else
		fprintf('%-48s | %8s %8s | %8s %8s\n', 'Feature', 'T_rho', 'T_p', 'N_rho', 'N_p');
		for i = 1:numel(shared01)
			rowT = resultsTransfer(resultsTransfer.Feature == shared01(i), :);
			rowN = resultsNaive(resultsNaive.Feature == shared01(i), :);
			fprintf('%-48s | %+8.3f %8.4f | %+8.3f %8.4f\n', shared01(i), rowT.rho(1), rowT.p(1), rowN.rho(1), rowN.p(1));
		end
	end
else
	fprintf('Transfer results (ExploreFeatures_Results) not found in workspace.\n');
	fprintf('Run Z_ExploreFeatures_DeltaHit.m first, then re-run this script.\n');
end

assignin('base', 'NaiveFeatures_Results', resultsNaive);
assignin('base', 'NaiveFeatures_Partial', resultsNaiveP);
assignin('base', 'NaiveFeatures_Values', featureValues);
assignin('base', 'NaiveFeatures_DeltaHit', deltaHit);
assignin('base', 'NaiveFeatures_SessSpeed', SessSpeed);
fprintf('\nDone. Saved to workspace: NaiveFeatures_Results, NaiveFeatures_Partial\n');

%% ======== SESSION BUILDING HELPERS ========

function AllSess = iGatherNaiveSessions(LAB, LAI)
% Gather LightWater sessions from Naive→Learned for both datasets.
% If a mouse has no Learned phase, use the last pure LW session before Transfer.
% Also record which DS each session belongs to.

AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});

% Process each dataset
for iDS = 1:2
	if iDS == 1, DS = LAB; srcName = "LAB"; else, DS = LAI; srcName = "LAI"; end

	% Check LAI for AudioWater purity at mouse level
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

		% Skip bad LAI mice
		if iDS == 2 && any(m == badMice), continue; end

		Tm = T(T.Mouse == m, :);

		% Find phase range: Naive → Learned
		phases = unique(Tm.Phase);
		hasLearned = any(phases == "Learned");
		hasTransfer = any(phases == "Transfer");

		if ~any(phases == "Naive"), continue; end

		% Get all session DateTimes
		sessDTs = unique(Tm.DateTime);
		sessDTs = sort(sessDTs);

		% Session-level phase (mode)
		sessPhase = strings(numel(sessDTs), 1);
		for ii = 1:numel(sessDTs)
			ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
			ph = ph(ph ~= "" & ~ismissing(ph));
			if isempty(ph), sessPhase(ii) = ""; continue; end
			[uPh,~,ic] = unique(ph); counts = accumarray(ic,1);
			[~,mx] = max(counts); sessPhase(ii) = uPh(mx);
		end

		% Determine range
		idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
		if hasLearned
			idxLearnedEnd = find(sessPhase == "Learned", 1, 'last');
		else
			% No Learned: use through last session before Transfer
			if hasTransfer
				idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
				idxLearnedEnd = idxTransferStart - 1;
			else
				% No Learned, no Transfer: use all sessions
				idxLearnedEnd = numel(sessDTs);
			end
		end

		if isempty(idxNaiveStart) || idxLearnedEnd < idxNaiveStart
			continue;
		end

		for k = idxNaiveStart:idxLearnedEnd
			dt = sessDTs(k);

			% Check this session has LightWater trials
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
% Remove duplicates (same mouse+datetime from both datasets — shouldn't happen but safety)
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows', 'first');
AllSess = AllSess(ia, :);
end

function badMice = iFindBadMiceLAI(DS)
% Find mice in LAI whose LightWater sessions are contaminated with AudioWater at session level
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

function AllSess = iExcludeAudioWaterSessions(AllSess)
% Remove sessions that contain AudioWater blocks
% We already excluded bad LAI mice at the mouse level.
% Here we do per-session check for both datasets.
keep = true(height(AllSess), 1);

% Preload datasets once
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
for i = 1:height(AllSess)
	DS = iGetDS(AllSess.Source(i), LAB, LAI);
	if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
		keep(i) = false;
	end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeiling(AllSess)
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

function SessSpeed = iSessionDeltaNext(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'}); Sess.Mouse = string(Sess.Mouse);
outM = strings(0,1); outDT = NaT(0,1); outP = nan(0,1);
outDT2 = NaT(0,1); outP2 = nan(0,1); outDN = nan(0,1); outSrc = strings(0,1);
for m = unique(Sess.Mouse)'
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance); dt = R.DateTime; src = R.Source;
	use = isfinite(perf) & ~ismissing(dt); perf = perf(use); dt = dt(use); src = src(use);
	if numel(perf) < 2, continue; end
	dn = diff(perf); n = numel(dn);
	outM = [outM; repmat(m,n,1)]; outDT = [outDT; dt(1:end-1)]; outP = [outP; perf(1:end-1)]; %#ok<AGROW>
	outDT2 = [outDT2; dt(2:end)]; outP2 = [outP2; perf(2:end)]; outDN = [outDN; dn(:)]; outSrc = [outSrc; src(1:end-1)]; %#ok<AGROW>
end
SessSpeed = table(outM, outDT, outP, outDT2, outP2, outDN, outSrc, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext','Source'});
end

function DS = iGetDS(src, LAB, LAI)
if src == "LAB"
	DS = LAB;
else
	DS = LAI;
end
end

%% ======== LEARNED SIGNAL HELPER ========

function [learnedUID, learnedX] = iLearnedSignal(DS, mouse)
% Get Learned LightWater NTATS for this mouse.
% If no Learned phase, try to use the last pure LW session before Transfer.
learnedUID = uint64.empty(0,1); learnedX = [];

% Check if Learned LightWater exists for this mouse
Tcheck = DS.TableQuery(["TrialUID"], Mouse=char(mouse), Stimulus="LightWater", Phase="Learned");
if ~isempty(Tcheck) && height(Tcheck) > 0
	G = DS.QueryNTATS(struct('Mouse',char(mouse),'Stimulus','LightWater','Phase','Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	if ~isempty(G) && height(G) > 0
		learnedUID = uint64(G.CellUID);
		X = G.NTATS;
		if isa(X, 'MATLAB.DataTypes.NDTable'), X = X.Data; end
		learnedX = squeeze(double(X));
		return;
	end
end

% Fallback: last LW session before Transfer
T = DS.TableQuery(["DateTime","Phase","TrialUID"], Mouse=char(mouse), Stimulus="LightWater");
if isempty(T), return; end
T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
T.Phase = string(T.Phase);

% Find Transfer start
allPhases = DS.TableQuery(["DateTime","Phase"], Mouse=char(mouse));
allPhases.DateTime = datetime(allPhases.DateTime); allPhases.DateTime.TimeZone = '';
allPhases.Phase = string(allPhases.Phase);
transferDTs = allPhases.DateTime(allPhases.Phase == "Transfer");

if isempty(transferDTs)
	% No Transfer either: use last LW session
	lastDT = max(T.DateTime);
else
	preDTs = T.DateTime(T.DateTime < min(transferDTs));
	if isempty(preDTs), return; end
	lastDT = max(preDTs);
end

if ismissing(lastDT), return; end

% Use iSessionNTATS which handles empty groups gracefully via QueryNTS
[learnedUID, learnedX] = iSessionNTATS(DS, mouse, lastDT);
end

%% ======== FEATURE COMPUTATION HELPERS ========

function [rho, p] = iPartialSpearman(x, y, z)
rx = tiedrank(x); ry = tiedrank(y); rz = tiedrank(z);
rx_res = rx - rz * (rz \ rx);
ry_res = ry - rz * (rz \ ry);
[rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end

function [uid, ntats] = iSessionNTATS(DS, mouse, dt)
q = struct('Mouse', char(mouse), 'DateTime', dt, 'Stimulus', 'LightWater');
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
uid = uint64.empty(0,1); ntats = [];
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
nts = ntsCell{1};
if ~istable(nts) || height(nts)==0, return; end
if ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames))), return; end
uid = unique(uint64(nts.CellUID));
nT = size(nts.TrialSignal, 2);
ntats = nan(numel(uid), nT);
for iC = 1:numel(uid)
	rows = uint64(nts.CellUID) == uid(iC);
	if nnz(rows)<1, continue; end
	ntats(iC,:) = median(double(nts.TrialSignal(rows,:)), 1, 'omitnan');
end
end

function nts = iSessionTrials(DS, mouse, dt)
q = struct('Mouse', char(mouse), 'DateTime', dt, 'Stimulus', 'LightWater');
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
nts = [];
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
nts = ntsCell{1};
if ~istable(nts) || height(nts)==0, nts = []; end
end

function cellLayer = iCellLayerLookup(C, mouse)
idx = C.Mouse == string(mouse);
cellLayer = containers.Map('KeyType','uint64','ValueType','char');
uids = uint64(C.CellUID(idx)); zls = string(C.ZLayer(idx));
for i = 1:numel(uids), cellLayer(uids(i)) = char(zls(i)); end
end

function [common, idxA, idxB] = iCommonCells(uidA, uidB, cellLayer, layerFilter)
common = intersect(uint64(uidA), uint64(uidB));
if isempty(common), idxA = []; idxB = []; return; end
zl = strings(numel(common), 1);
for i = 1:numel(common)
	if cellLayer.isKey(common(i)), zl(i) = string(cellLayer(common(i))); end
end
keep = layerFilter(zl); common = common(keep);
if isempty(common), idxA = []; idxB = []; return; end
[~, idxA] = ismember(common, uint64(uidA));
[~, idxB] = ismember(common, uint64(uidB));
end

function [uids, idx] = iLayerCells(allUID, cellLayer, layerFilter)
zl = strings(numel(allUID), 1);
for i = 1:numel(allUID)
	if cellLayer.isKey(allUID(i)), zl(i) = string(cellLayer(allUID(i))); end
end
keep = layerFilter(zl); uids = allUID(keep); idx = find(keep);
end

function r = iReuseRate(ntatsTarget, idxTarget, ntatsRef, idxRef, baseMask, idxTP, kSigma)
r = NaN;
if isempty(idxTarget) || isempty(idxRef), return; end
refBase = ntatsRef(idxRef, baseMask);
refAct = ntatsRef(idxRef, idxTP) > (mean(refBase,2,'omitnan') + kSigma*std(refBase,0,2,'omitnan'));
if nnz(refAct)<1, return; end
tarBase = ntatsTarget(idxTarget, baseMask);
tarAct = ntatsTarget(idxTarget, idxTP) > (mean(tarBase,2,'omitnan') + kSigma*std(tarBase,0,2,'omitnan'));
r = mean(double(tarAct(refAct)), 'omitnan');
end

function r = iVecCorr(ntatsA, idxA, ntatsB, idxB, idxTP)
r = NaN;
if isempty(idxA) || isempty(idxB) || numel(idxA)<5, return; end
vA = double(ntatsA(idxA, idxTP)); vB = double(ntatsB(idxB, idxTP));
use = isfinite(vA) & isfinite(vB);
if nnz(use)<5 || std(vA(use))==0 || std(vB(use))==0, return; end
r = corr(vA(use), vB(use), 'Type', 'Pearson');
end

function sd = iInterCellSD(ntats, idx, idxTP)
sd = NaN; if isempty(idx), return; end
v = double(ntats(idx, idxTP)); v = v(isfinite(v));
if numel(v)<3, return; end
sd = std(v,0,1);
end

function af = iActiveFrac(ntats, idx, baseMask, idxTP, kSigma)
af = NaN; if isempty(idx), return; end
base = ntats(idx, baseMask);
act = ntats(idx, idxTP) > (mean(base,2,'omitnan') + kSigma*std(base,0,2,'omitnan'));
af = mean(double(act), 'omitnan');
end

function mn = iMeanNTATS(ntats, idx, idxTP)
mn = NaN; if isempty(idx), return; end
mn = mean(double(ntats(idx, idxTP)), 'omitnan');
end

function div = iDivergence(nts, uidAll, cellLayer, layerFilter, idxTP)
div = NaN;
if isempty(nts) || ~istable(nts) || isempty(uidAll), return; end
if ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames))), return; end
[~, layerIdx] = iLayerCells(uidAll, cellLayer, layerFilter);
if isempty(layerIdx), return; end
layerUID = uidAll(layerIdx);
varSum = 0; meanSqSum = 0; nCells = 0;
for iC = 1:numel(layerUID)
	rows = uint64(nts.CellUID) == layerUID(iC);
	if nnz(rows)<2, continue; end
	vals = double(nts.TrialSignal(rows, idxTP)); vals = vals(isfinite(vals));
	if numel(vals)<2, continue; end
	varSum = varSum + var(vals); meanSqSum = meanSqSum + mean(vals)^2; nCells = nCells+1;
end
if nCells<3 || meanSqSum==0, return; end
div = sqrt(varSum) / sqrt(meanSqSum);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus)); st = st(~ismissing(st));
tf = any(st == string(stim));
end
