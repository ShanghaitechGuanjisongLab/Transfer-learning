% Z_AW_Mediation_Analysis.m
% AudioWater 介导分析：3 个通过严格三方筛选的 Learned-independent 特征
%
% 严格三方筛选条件：
%   1) Transfer Partial Spearman p<0.05 (与ΔHit, 控制Hit_K)
%   2) Naive Partial Spearman p<0.05
%   3) Rank-sum Transfer vs Naive p<0.05, 方向一致 (T>N, 因 rho>0)
% 排除需要 Learned LW 数据的特征后剩余 3 个 (全是 1.0s SD_K1)。
% 本脚本测试：
%   A) 第一个 Transfer 会话特征值与 AW Learned 特征的 Spearman 相关 (N=11 mice)
%   B) 消融：剔除 AW Learned 阶段活跃细胞后重算特征，
%      检查是否丧失（i）对 ΔHit 的 Partial Spearman 预测力
%      和（ii）与 Naive 的 rank-sum 组间差异

fprintf('=== AudioWater Mediation Analysis ===\n');
fprintf('Testing if Transfer advantage is mediated by AW Learned experience\n\n');

%% 1. Setup
ALB = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);

timePoints = [0.3, 0.5, 1.0, 1.5];
nTP = numel(timePoints);
idxTP = nan(1, nTP);
for iT = 1:nTP
	[dt, idx] = min(abs(xsSec - timePoints(iT)));
	if dt <= 0.25, idxTP(iT) = idx; end
end
kSigma = 3;

layerNames = ["All","MOp23","MOp5"];
layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};
nLayers = numel(layerNames);

%% 2. Build Transfer session pairs from ALB (Transfer→Final)
fprintf('Building Transfer session pairs from AudioLightBaseline...\n');
TransferSess = iGatherTransferSessions(ALB);
fprintf('Transfer sessions (before ceiling): %d from %d mice\n', height(TransferSess), numel(unique(TransferSess.Mouse)));
TransferSess = iExcludeCeiling(TransferSess);
fprintf('Transfer sessions (after ceiling): %d\n', height(TransferSess));
SessSpeedT = iSessionDeltaNext(TransferSess);
nPairsT = height(SessSpeedT);
deltaHitT = double(SessSpeedT.Speed_DeltaNext);
hitKT = double(SessSpeedT.Performance);
fprintf('Transfer session pairs: %d from %d mice\n\n', nPairsT, numel(unique(SessSpeedT.Mouse)));

%% 2b. First Transfer LW session per mouse (ALL mice, no ceiling/pairing)
% For Test A: mouse-level correlation with AW characteristics
fprintf('Building first Transfer LW session per mouse (all mice)...\n');
FirstTransferSess = iFirstTransferSession(ALB);
nMiceAll = height(FirstTransferSess);
fprintf('First Transfer sessions: %d mice\n', nMiceAll);
for iM = 1:nMiceAll
	fprintf('  %s: %s, perf=%.0f%%\n', FirstTransferSess.Mouse(iM), ...
		datestr(FirstTransferSess.DateTime(iM),'yyyy-mm-dd'), FirstTransferSess.Performance(iM)*100);
end
fprintf('\n');

%% 3. Get AW Learned data per mouse (ALL mice): NTATS + NTS trial-level
fprintf('Loading AudioWater Learned data per mouse...\n');
miceAll = unique([string(SessSpeedT.Mouse); FirstTransferSess.Mouse]);
awStore = struct();
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	mSafe = matlab.lang.makeValidName(char(m));
	[uid, ntats_aw] = iAWLearnedNTATS(ALB, m);
	nts_aw = iAWLearnedNTS(ALB, m);
	awStore.(mSafe) = struct('uid', uid, 'ntats', ntats_aw, 'nts', nts_aw);
	fprintf('  %s: %d cells (NTATS), %d NTS rows\n', m, numel(uid), ...
		height(nts_aw));
end
fprintf('\n');

%% 4. Define 3 target features (strict three-way filter, Learned-independent)
% Format: {name, iTP_idx, iL_idx, metricType}
% All are SD_K1 at 1.0s in different layers
targets = {
	'1p0s_All_SD_K1',    3, 1, 'SD_K1';
	'1p0s_MOp23_SD_K1',  3, 2, 'SD_K1';
	'1p0s_MOp5_SD_K1',   3, 3, 'SD_K1';
	};
nTargets = size(targets, 1);

%% 5. Compute features: normal, ablated, and AW characteristics
featNormal  = nan(nPairsT, nTargets);
featAblated = nan(nPairsT, nTargets);
awCharActFrac = nan(nPairsT, nTargets);
awCharMean    = nan(nPairsT, nTargets);
awCharSD      = nan(nPairsT, nTargets);
nCellsNormal  = nan(nPairsT, nTargets);
nCellsAblated = nan(nPairsT, nTargets);
pctRemoved    = nan(nPairsT, nTargets);

% Cell table (load once)
CAll = ALB.Cells;
CAll.CellUID = uint64(CAll.CellUID); CAll.Mouse = string(CAll.Mouse); CAll.ZLayer = string(CAll.ZLayer);

fprintf('Computing features for %d Transfer pairs...\n', nPairsT);
for iPair = 1:nPairsT
	m = SessSpeedT.Mouse(iPair);
	dtK  = SessSpeedT.DateTime(iPair);
	dtK1 = SessSpeedT.DateTimeNext(iPair);
	mSafe = matlab.lang.makeValidName(char(m));

	% Session NTATS
	[uidK,  ntatsK]  = iSessionNTATS(ALB, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(ALB, m, dtK1);

	% Cell layer lookup
	cellLayer = iCellLayerLookup(CAll, m);

	% AW Learned data for this mouse
	awUID   = awStore.(mSafe).uid;
	awNTATS = awStore.(mSafe).ntats;

	% Trial-level data (for divergence only)
	trialsK = iSessionTrials(ALB, m, dtK);

	for iF = 1:nTargets
		tpI  = targets{iF, 2};
		lI   = targets{iF, 3};
		mType = targets{iF, 4};

		idx = idxTP(tpI);
		if ~isfinite(idx), continue; end
		lFilt = layerFilters{lI};

		% AW-active cells in this layer at this timepoint
		awActiveUIDs = iAWActiveCells(awUID, awNTATS, cellLayer, lFilt, baseMask, idx, kSigma);

		% Layer cells for K and K+1
		[layerUIDK,  layerIdxK]  = iLayerCells(uidK,  cellLayer, lFilt);
		[layerUIDK1, layerIdxK1] = iLayerCells(uidK1, cellLayer, lFilt);

		% Ablated: exclude AW-active cells
		[~, ablIdxK]  = iExcludeCells(layerUIDK,  layerIdxK,  awActiveUIDs);
		[~, ablIdxK1] = iExcludeCells(layerUIDK1, layerIdxK1, awActiveUIDs);

		nOrig = numel(layerIdxK1); nAbl = numel(ablIdxK1);
		nCellsNormal(iPair, iF)  = nOrig;
		nCellsAblated(iPair, iF) = nAbl;
		if nOrig > 0
			pctRemoved(iPair, iF) = 100 * (1 - nAbl / nOrig);
		end

		% AW Learned characteristics for correlation
		[awAF, awMN, awSD_val] = iAWCharacteristics(awUID, awNTATS, cellLayer, lFilt, baseMask, idx, kSigma);
		awCharActFrac(iPair, iF) = awAF;
		awCharMean(iPair, iF)    = awMN;
		awCharSD(iPair, iF)      = awSD_val;

		% Compute normal and ablated feature values
		switch mType
			case 'SD_K1'
				featNormal(iPair, iF)  = iInterCellSD(ntatsK1, layerIdxK1, idx);
				featAblated(iPair, iF) = iInterCellSD(ntatsK1, ablIdxK1, idx);

			case 'ActFrac_K1'
				featNormal(iPair, iF)  = iActiveFrac(ntatsK1, layerIdxK1, baseMask, idx, kSigma);
				featAblated(iPair, iF) = iActiveFrac(ntatsK1, ablIdxK1, baseMask, idx, kSigma);

			case 'DeltaSD'
				sdK  = iInterCellSD(ntatsK,  layerIdxK,  idx);
				sdK1 = iInterCellSD(ntatsK1, layerIdxK1, idx);
				featNormal(iPair, iF) = sdK1 - sdK;
				sdKa  = iInterCellSD(ntatsK,  ablIdxK,  idx);
				sdK1a = iInterCellSD(ntatsK1, ablIdxK1, idx);
				featAblated(iPair, iF) = sdK1a - sdKa;

			case 'DeltaActFrac'
				afK  = iActiveFrac(ntatsK,  layerIdxK,  baseMask, idx, kSigma);
				afK1 = iActiveFrac(ntatsK1, layerIdxK1, baseMask, idx, kSigma);
				featNormal(iPair, iF) = afK1 - afK;
				afKa  = iActiveFrac(ntatsK,  ablIdxK,  baseMask, idx, kSigma);
				afK1a = iActiveFrac(ntatsK1, ablIdxK1, baseMask, idx, kSigma);
				featAblated(iPair, iF) = afK1a - afKa;

			case 'DeltaMeanNTATS'
				mnK  = iMeanNTATS(ntatsK,  layerIdxK,  idx);
				mnK1 = iMeanNTATS(ntatsK1, layerIdxK1, idx);
				featNormal(iPair, iF) = mnK1 - mnK;
				mnKa  = iMeanNTATS(ntatsK,  ablIdxK,  idx);
				mnK1a = iMeanNTATS(ntatsK1, ablIdxK1, idx);
				featAblated(iPair, iF) = mnK1a - mnKa;

			case 'Div_K'
				featNormal(iPair, iF)  = iDivergence(trialsK, uidK, cellLayer, lFilt, idx);
				featAblated(iPair, iF) = iDivergenceExclude(trialsK, uidK, cellLayer, lFilt, idx, awActiveUIDs);
		end
	end
	fprintf('  Pair %d/%d done (%s %s)\n', iPair, nPairsT, m, datestr(dtK, 'yyyy-mm-dd'));
end

%% 5b. Compute mouse-level features for Test A (first Transfer session, all mice)
% 8 AW metrics per mouse/feature: ActFrac, MeanNTATS, SD, nCells, nActiveCells,
% Divergence, MeanBaseline, PeakResponse
fprintf('\nComputing mouse-level features for Test A (%d mice)...\n', nMiceAll);
nAWMetrics = 8;
awMetricLabels = {'AW_ActFrac','AW_MeanNTATS','AW_SD','AW_nCells','AW_nActive',...
	'AW_Divergence','AW_MeanBaseline','AW_PeakResp'};

featMouseA  = nan(nMiceAll, nTargets);
awMouseAll  = nan(nMiceAll, nTargets, nAWMetrics);  % (mice, features, AW metrics)

xs = TransferLearning.Xs;
if isduration(xs), xsSec2 = seconds(xs); else, xsSec2 = double(xs); end
postMask = (xsSec2 >= 0) & (xsSec2 <= 2);  % 0~2s for peak response

for iM = 1:nMiceAll
	m  = FirstTransferSess.Mouse(iM);
	dt = FirstTransferSess.DateTime(iM);
	mSafe = matlab.lang.makeValidName(char(m));

	% Session NTATS and trials
	[uid1, ntats1] = iSessionNTATS(ALB, m, dt);
	trials1 = iSessionTrials(ALB, m, dt);
	cellLayer = iCellLayerLookup(CAll, m);

	awUID   = awStore.(mSafe).uid;
	awNTATS = awStore.(mSafe).ntats;
	awNTS   = awStore.(mSafe).nts;

	for iF = 1:nTargets
		tpI   = targets{iF, 2};
		lI    = targets{iF, 3};
		mType = targets{iF, 4};
		idx   = idxTP(tpI);
		if ~isfinite(idx), continue; end
		lFilt = layerFilters{lI};

		% === Transfer feature value from first Transfer session ===
		[layerUID1, layerIdx1] = iLayerCells(uid1, cellLayer, lFilt);
		switch mType
			case 'SD_K1'
				featMouseA(iM, iF) = iInterCellSD(ntats1, layerIdx1, idx);
			case 'ActFrac_K1'
				featMouseA(iM, iF) = iActiveFrac(ntats1, layerIdx1, baseMask, idx, kSigma);
			case 'Div_K'
				featMouseA(iM, iF) = iDivergence(trials1, uid1, cellLayer, lFilt, idx);
		end

		% === All 8 AW metrics (from AW Learned calcium data) ===
		[awLayerUID, awLayerIdx] = iLayerCells(awUID, cellLayer, lFilt);
		if isempty(awLayerIdx), continue; end

		% 1. ActFrac
		base_aw = awNTATS(awLayerIdx, baseMask);
		resp_aw = awNTATS(awLayerIdx, idx);
		thresh_aw = mean(base_aw, 2, 'omitnan') + kSigma * std(base_aw, 0, 2, 'omitnan');
		activeVec = resp_aw > thresh_aw;
		awMouseAll(iM, iF, 1) = mean(double(activeVec), 'omitnan');

		% 2. MeanNTATS
		awMouseAll(iM, iF, 2) = mean(double(resp_aw), 'omitnan');

		% 3. SD (inter-cell)
		vals_aw = double(resp_aw); vals_aw = vals_aw(isfinite(vals_aw));
		if numel(vals_aw) >= 3
			awMouseAll(iM, iF, 3) = std(vals_aw);
		end

		% 4. nCells (layer total)
		awMouseAll(iM, iF, 4) = numel(awLayerIdx);

		% 5. nActiveCells
		awMouseAll(iM, iF, 5) = nnz(activeVec);

		% 6. Divergence (trial-to-trial variability in AW Learned)
		awMouseAll(iM, iF, 6) = iDivergence(awNTS, awUID, cellLayer, lFilt, idx);

		% 7. MeanBaseline (average baseline activity)
		baseAll = awNTATS(awLayerIdx, baseMask);
		awMouseAll(iM, iF, 7) = mean(baseAll(:), 'omitnan');

		% 8. PeakResponse (max in 0~2s post-stimulus window)
		postAll = awNTATS(awLayerIdx, postMask);
		meanPost = mean(postAll, 1, 'omitnan');  % mean across cells per timepoint
		awMouseAll(iM, iF, 8) = max(meanPost);
	end
	fprintf('  Mouse %d/%d done (%s %s)\n', iM, nMiceAll, m, datestr(dt, 'yyyy-mm-dd'));
end
fprintf('\n');

%% 6. Load Naive feature values for rank-sum comparison
NaiveVals = evalin('base', 'NaiveFeatures_Values');

% Build full feature name list (same order as in the exploration scripts)
featNamesFull = {};
for iTP = 1:nTP
	tpStr = strrep(sprintf('%.1fs', timePoints(iTP)), '.', 'p');
	for iL = 1:nLayers
		prefix = [tpStr '_' char(layerNames(iL)) '_'];
		featNamesFull = [featNamesFull, ...
			{[prefix 'ReuseKL'], [prefix 'CorrKL'], [prefix 'CorrK1L'], ...
			 [prefix 'CorrKK1'], [prefix 'SD_K'], [prefix 'SD_K1'], ...
			 [prefix 'ActFrac_K'], [prefix 'ActFrac_K1'], ...
			 [prefix 'MeanNTATS_K'], [prefix 'MeanNTATS_K1'], ...
			 [prefix 'DeltaCorrL'], [prefix 'DeltaSD'], ...
			 [prefix 'DeltaActFrac'], [prefix 'DeltaMeanNTATS'], ...
			 [prefix 'ReuseK1L'], [prefix 'DeltaReuse']}]; %#ok<AGROW>
	end
end
featNamesFull = [featNamesFull, {'Hit_K'}];
for iL = 1:nLayers
	ln = char(layerNames(iL));
	featNamesFull = [featNamesFull, {['Div1s_' ln '_K'], ['Div1s_' ln '_K1'], ['DeltaDiv1s_' ln]}]; %#ok<AGROW>
end

%% 7. Run tests and report
fprintf('\n================================================================================\n');
fprintf('  RESULTS: AudioWater Mediation Analysis (3 Learned-independent features)\n');
fprintf('================================================================================\n\n');

summaryTable = cell(nTargets, 11);

for iF = 1:nTargets
	fname = targets{iF, 1};

	% Find column in NaiveVals
	colIdx = find(strcmp(featNamesFull, fname));
	if isempty(colIdx)
		fprintf('WARNING: %s not found in feature names\n', fname);
		continue;
	end
	naiveVals_f = NaiveVals(:, colIdx);

	xT  = featNormal(:, iF);
	xTa = featAblated(:, iF);
	xN  = naiveVals_f;

	maskT  = isfinite(xT)  & isfinite(deltaHitT) & isfinite(hitKT);
	maskTa = isfinite(xTa) & isfinite(deltaHitT) & isfinite(hitKT);

	avgRemoved = mean(pctRemoved(:, iF), 'omitnan');

	fprintf('--- %s ---\n', fname);
	fprintf('  Cells per pair: normal≈%d, ablated≈%d (removed %.1f%%)\n', ...
		round(mean(nCellsNormal(:,iF),'omitnan')), ...
		round(mean(nCellsAblated(:,iF),'omitnan')), avgRemoved);

	% ===== A) Mouse-level correlation with AW Learned characteristics =====
	% Uses first Transfer session per mouse (N=nMiceAll, no ceiling/pairing needed)
	% Tests all 8 AW metrics from AW Learned calcium data
	xT_mouse = featMouseA(:, iF);
	bestAW_rho = NaN; bestAW_p = NaN; bestAW_label = "";

	for awI = 1:nAWMetrics
		awV = squeeze(awMouseAll(:, iF, awI));
		msk = isfinite(xT_mouse) & isfinite(awV);
		if nnz(msk) >= 5 && std(xT_mouse(msk)) > 0 && std(awV(msk)) > 0
			[rho_aw, p_aw] = corr(xT_mouse(msk), awV(msk), 'Type', 'Spearman');
			sigStr = "";
			if p_aw < 0.01, sigStr = " **";
			elseif p_aw < 0.05, sigStr = " *";
			elseif p_aw < 0.1, sigStr = " ."; end
			fprintf('  [A] Corr with %s (N=%d mice): rho=%+.3f, p=%.4f%s\n', awMetricLabels{awI}, nnz(msk), rho_aw, p_aw, sigStr);
			if isnan(bestAW_p) || p_aw < bestAW_p
				bestAW_rho = rho_aw; bestAW_p = p_aw; bestAW_label = awMetricLabels{awI};
			end
		end
	end

	% ===== B) Original vs Ablated partial Spearman =====
	rhoOrig = NaN; pOrig = NaN; rhoAbl = NaN; pAbl = NaN;
	if nnz(maskT) >= 7
		[rhoOrig, pOrig] = iPartialSpearman(xT(maskT), deltaHitT(maskT), hitKT(maskT));
		fprintf('  [B] Original partial Spearman:  rho=%+.3f, p=%.4f\n', rhoOrig, pOrig);
	end
	if nnz(maskTa) >= 7
		[rhoAbl, pAbl] = iPartialSpearman(xTa(maskTa), deltaHitT(maskTa), hitKT(maskTa));
		lostPS = (pAbl >= 0.05 && pOrig < 0.05);
		fprintf('  [B] Ablated partial Spearman:   rho=%+.3f, p=%.4f', rhoAbl, pAbl);
		if lostPS, fprintf(' <= LOST significance'); end
		fprintf('\n');
	end

	% ===== C) Original vs Ablated rank-sum vs Naive =====
	xT_clean  = xT(isfinite(xT));
	xTa_clean = xTa(isfinite(xTa));
	xN_clean  = xN(isfinite(xN));

	pRS_orig = NaN; pRS_abl = NaN;
	if numel(xT_clean) >= 3 && numel(xN_clean) >= 3
		pRS_orig = ranksum(xT_clean, xN_clean);
		fprintf('  [C] Original rank-sum vs Naive: p=%.4f\n', pRS_orig);
	end
	if numel(xTa_clean) >= 3 && numel(xN_clean) >= 3
		pRS_abl = ranksum(xTa_clean, xN_clean);
		lostRS = (pRS_abl >= 0.05 && pRS_orig < 0.05);
		fprintf('  [C] Ablated rank-sum vs Naive:  p=%.4f', pRS_abl);
		if lostRS, fprintf(' <= LOST significance'); end
		fprintf('\n');
	end

	% Summary
	passA = bestAW_p < 0.05;  % correlated with AW characteristic
	passB = pAbl >= 0.05 && pOrig < 0.05;  % lost partial Spearman
	passC = pRS_abl >= 0.05 && pRS_orig < 0.05;  % lost rank-sum

	summaryTable{iF,1}  = fname;
	summaryTable{iF,2}  = avgRemoved;
	summaryTable{iF,3}  = bestAW_rho;
	summaryTable{iF,4}  = bestAW_p;
	summaryTable{iF,5}  = char(bestAW_label);
	summaryTable{iF,6}  = rhoOrig;
	summaryTable{iF,7}  = rhoAbl;
	summaryTable{iF,8}  = pOrig;
	summaryTable{iF,9}  = pAbl;
	summaryTable{iF,10} = pRS_orig;
	summaryTable{iF,11} = pRS_abl;

	if passA || passB || passC
		flags = "";
		if passA, flags = flags + "A"; end
		if passB, flags = flags + "B"; end
		if passC, flags = flags + "C"; end
		fprintf('  >>> AW-mediated evidence: %s\n', flags);
	else
		fprintf('  >>> No AW mediation evidence\n');
	end
	fprintf('\n');
end

%% 8. Final summary table
fprintf('\n================================================================================\n');
fprintf('  SUMMARY\n');
fprintf('================================================================================\n');
fprintf('Criteria for AW mediation:\n');
fprintf('  A: First Transfer LW session feature correlates with AW Learned characteristic (N=%d mice, Spearman p<0.05)\n', nMiceAll);
fprintf('  B: Ablation of AW-active cells eliminates Partial Spearman with ΔHit (p>=0.05)\n');
fprintf('  C: Ablation eliminates rank-sum difference vs Naive (p>=0.05)\n\n');

fprintf('%-40s | %%Rem | AW_corr_p | pSpear_orig → pSpear_abl | RS_orig → RS_abl | Evidence\n', 'Feature');
fprintf('%s\n', repmat('-',1,130));

nFullPass = 0;
for iF = 1:nTargets
	fname    = summaryTable{iF,1};
	pctR     = summaryTable{iF,2};
	awP      = summaryTable{iF,4};
	rhoO     = summaryTable{iF,6};
	rhoA     = summaryTable{iF,7};
	pO       = summaryTable{iF,8};
	pA       = summaryTable{iF,9};
	pRSo     = summaryTable{iF,10};
	pRSa     = summaryTable{iF,11};

	passA = awP < 0.05;
	passB = pA >= 0.05 && pO < 0.05;
	passC = pRSa >= 0.05 && pRSo < 0.05;

	flags = "";
	if passA, flags = flags + "A"; end
	if passB, flags = flags + "B"; end
	if passC, flags = flags + "C"; end
	if strlength(flags) == 0, flags = "-"; end

	% Full pass: A + (B or C)
	fullPass = passA && (passB || passC);
	if fullPass, nFullPass = nFullPass + 1; end

	fprintf('%-40s | %4.1f | %9.4f | %+.3f(%.4f) → %+.3f(%.4f) | %.4f → %.4f | %s%s\n', ...
		fname, pctR, awP, rhoO, pO, rhoA, pA, ...
		pRSo, pRSa, flags, ...
		ternary(fullPass, ' *** FULL PASS', ''));
end

fprintf('\n==> Features with FULL AW mediation (A + B|C): %d / %d\n', nFullPass, nTargets);
fprintf('Done.\n');

% Save to workspace
assignin('base', 'AW_Mediation_Summary', summaryTable);
assignin('base', 'AW_Mediation_FeatNormal', featNormal);
assignin('base', 'AW_Mediation_FeatAblated', featAblated);
assignin('base', 'AW_Mediation_FeatMouseA', featMouseA);
assignin('base', 'AW_Mediation_FirstTransferSess', FirstTransferSess);

%% ======== HELPER: Gather Transfer sessions ========
function AllSess = iGatherTransferSessions(ALB)
% Collect ALL LightWater sessions from first Transfer to last Final (inclusive),
% including intermediate sessions whose Phase field may be empty.
T = ALB.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
T.Phase = string(T.Phase);
T.Phase(ismissing(T.Phase)) = "";
Tr = ALB.Trials;

AllSess = table(strings(0,1), NaT(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance'});

mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM);
	Tm = T(T.Mouse == m, :);
	sessDTs = sort(unique(Tm.DateTime));

	% Find session-level phase labels
	sessPhase = strings(numel(sessDTs), 1);
	for ii = 1:numel(sessDTs)
		ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
		ph = ph(ph ~= "" & ~ismissing(ph));
		if isempty(ph), sessPhase(ii) = ""; continue; end
		[uPh,~,ic] = unique(ph); counts = accumarray(ic,1);
		[~,mx] = max(counts); sessPhase(ii) = uPh(mx);
	end

	% Find range: first Transfer → last Final
	idxTransfer = find(sessPhase == "Transfer", 1, 'first');
	idxFinal    = find(sessPhase == "Final", 1, 'last');
	if isempty(idxTransfer) || isempty(idxFinal) || idxFinal < idxTransfer
		continue;
	end

	% Collect ALL LW sessions in this range (regardless of Phase label)
	for k = idxTransfer:idxFinal
		dt = sessDTs(k);
		blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
		TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
		if isempty(TrSess), continue; end
		lwMask = string(TrSess.Stimulus) == "LightWater";
		if ~any(lwMask), continue; end
		perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
		if ~isfinite(perf), continue; end
		AllSess = [AllSess; table(m, dt, perf, ...
			'VariableNames', {'Mouse','DateTime','Performance'})]; %#ok<AGROW>
	end
end
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
end

%% ======== HELPER: First Transfer LW session per mouse ========
function FirstSess = iFirstTransferSession(ALB)
% Return the FIRST LightWater session in the Transfer phase for each mouse.
% No ceiling exclusion or pairing needed — one row per mouse.
T = ALB.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
T.Phase = string(T.Phase); T.Phase(ismissing(T.Phase)) = "";
Tr = ALB.Trials;

FirstSess = table(strings(0,1), NaT(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance'});

mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM);
	Tm = T(T.Mouse == m, :);
	sessDTs = sort(unique(Tm.DateTime));

	% Find session-level phase labels
	sessPhase = strings(numel(sessDTs), 1);
	for ii = 1:numel(sessDTs)
		ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
		ph = ph(ph ~= "" & ~ismissing(ph));
		if isempty(ph), sessPhase(ii) = ""; continue; end
		[uPh,~,ic] = unique(ph); counts = accumarray(ic,1);
		[~,mx] = max(counts); sessPhase(ii) = uPh(mx);
	end

	idxTransfer = find(sessPhase == "Transfer", 1, 'first');
	if isempty(idxTransfer), continue; end

	% First Transfer session — find its LW performance
	dt = sessDTs(idxTransfer);
	blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
	TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
	if isempty(TrSess), continue; end
	lwMask = string(TrSess.Stimulus) == "LightWater";
	if ~any(lwMask), continue; end
	perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
	if ~isfinite(perf), continue; end
	FirstSess = [FirstSess; table(m, dt, perf, ...
		'VariableNames', {'Mouse','DateTime','Performance'})]; %#ok<AGROW>
end
FirstSess = sortrows(FirstSess, 'Mouse');
end

%% ======== HELPER: Session pairing ========
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
outDT2 = NaT(0,1); outP2 = nan(0,1); outDN = nan(0,1);
for m = unique(Sess.Mouse)'
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance); dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt); perf = perf(use); dt = dt(use);
	if numel(perf) < 2, continue; end
	dn = diff(perf); n = numel(dn);
	outM = [outM; repmat(m,n,1)]; outDT = [outDT; dt(1:end-1)]; outP = [outP; perf(1:end-1)]; %#ok<AGROW>
	outDT2 = [outDT2; dt(2:end)]; outP2 = [outP2; perf(2:end)]; outDN = [outDN; dn(:)]; %#ok<AGROW>
end
SessSpeed = table(outM, outDT, outP, outDT2, outP2, outDN, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end

%% ======== HELPER: AW Learned data ========
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

function nts = iAWLearnedNTS(DS, mouse)
% Get trial-level NTS data for AW Learned (for Divergence computation)
nts = table();
Tcheck = DS.TableQuery(["TrialUID"], Mouse=char(mouse), Stimulus="AudioWater", Phase="Learned");
if isempty(Tcheck) || height(Tcheck) == 0, return; end
q = struct('Mouse', char(mouse), 'Stimulus', 'AudioWater', 'Phase', 'Learned');
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
nts = ntsCell{1};
if ~istable(nts) || height(nts) == 0, nts = table(); end
end

function awActiveCells = iAWActiveCells(awUID, awNTATS, cellLayer, layerFilter, baseMask, idxTP, kSigma)
% Find cells active during AW Learned at this timepoint in this layer
awActiveCells = uint64.empty(0,1);
if isempty(awUID) || isempty(awNTATS), return; end
[layerAWUID, layerAWIdx] = iLayerCells(awUID, cellLayer, layerFilter);
if isempty(layerAWIdx), return; end
base = awNTATS(layerAWIdx, baseMask);
resp = awNTATS(layerAWIdx, idxTP);
thresh = mean(base, 2, 'omitnan') + kSigma * std(base, 0, 2, 'omitnan');
active = resp > thresh;
awActiveCells = layerAWUID(active);
end

function [awAF, awMN, awSD_val] = iAWCharacteristics(awUID, awNTATS, cellLayer, layerFilter, baseMask, idxTP, kSigma)
awAF = NaN; awMN = NaN; awSD_val = NaN;
if isempty(awUID) || isempty(awNTATS), return; end
[~, layerIdx] = iLayerCells(awUID, cellLayer, layerFilter);
if isempty(layerIdx), return; end
base = awNTATS(layerIdx, baseMask);
resp = awNTATS(layerIdx, idxTP);
thresh = mean(base, 2, 'omitnan') + kSigma * std(base, 0, 2, 'omitnan');
awAF = mean(double(resp > thresh), 'omitnan');
vals = double(resp); vals = vals(isfinite(vals));
if numel(vals) >= 3
	awMN = mean(vals);
	awSD_val = std(vals);
end
end

function [ablUID, ablIdx] = iExcludeCells(layerUID, layerIdx, excludeUID)
keep = ~ismember(layerUID, excludeUID);
ablUID = layerUID(keep);
ablIdx = layerIdx(keep);
end

%% ======== HELPER: Session NTATS ========
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

%% ======== HELPER: Cell layer ========
function cellLayer = iCellLayerLookup(C, mouse)
idx = C.Mouse == string(mouse);
cellLayer = containers.Map('KeyType','uint64','ValueType','char');
uids = uint64(C.CellUID(idx)); zls = string(C.ZLayer(idx));
for i = 1:numel(uids), cellLayer(uids(i)) = char(zls(i)); end
end

function [uids, idx] = iLayerCells(allUID, cellLayer, layerFilter)
zl = strings(numel(allUID), 1);
for i = 1:numel(allUID)
	if cellLayer.isKey(allUID(i)), zl(i) = string(cellLayer(allUID(i))); end
end
keep = layerFilter(zl); uids = allUID(keep); idx = find(keep);
end

%% ======== HELPER: Feature computation ========
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

function div = iDivergenceExclude(nts, uidAll, cellLayer, layerFilter, idxTP, excludeUID)
div = NaN;
if isempty(nts) || ~istable(nts) || isempty(uidAll), return; end
if ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames))), return; end
[~, layerIdx] = iLayerCells(uidAll, cellLayer, layerFilter);
if isempty(layerIdx), return; end
layerUID = uidAll(layerIdx);
keep = ~ismember(layerUID, excludeUID);
layerUID = layerUID(keep);
if numel(layerUID) < 3, return; end
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

%% ======== HELPER: Partial Spearman ========
function [rho, p] = iPartialSpearman(x, y, z)
rx = tiedrank(x); ry = tiedrank(y); rz = tiedrank(z);
rx_res = rx - rz * (rz \ rx);
ry_res = ry - rz * (rz \ ry);
[rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end

%% ======== HELPER: ternary ========
function v = ternary(condition, valTrue, valFalse)
if condition, v = valTrue; else, v = valFalse; end
end
