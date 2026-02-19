% Z_AW_Mediation_PairSD.m
% AudioWater 介导分析：会话对平均 inter-cell SD (Fig3F 指标)
%
% 会话对平均 SD = mean(SD_session_k, SD_session_{k+1})
% 其中 SD = std(per-cell median ZScore) at 1s post-stimulus
%
% 分层：All / MOp2/3 / MOp5
%
% 三项测试：
%   A) 小鼠级 Spearman 相关：每只鼠各 pair 的 MeanPairSD 均值 vs AW Learned 8 项指标 (N=11)
%   B) 消融 AW Learned 活跃细胞（3σ）后重算 MeanPairSD，
%      检查是否丧失对 ΔHit 的 Partial Spearman 预测力
%   C) 消融后重算 MeanPairSD，
%      检查是否丧失与 Naive 的 rank-sum 组间差异
%
% 参考 Z_AW_Mediation_Analysis.m（SD_K1 版本）
%
% Execution:
%   TransferLearning.英文图3.Z_AW_Mediation_PairSD

fprintf('=== AudioWater Mediation Analysis (Pair-Averaged SD) ===\n');
fprintf('Feature: mean(SD_k, SD_{k+1}) per session pair\n\n');

%% 1. Setup
ALB = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);

[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('Z_PairSD:No1s', 'Cannot find a sample close to 1s.');
end

kSigma = 3;

layerNames  = ["All","MOp23","MOp5"];
layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};
nLayers = numel(layerNames);

%% 2. Build Transfer session pairs (matching Fig3F — no phase filter, ceiling excluded)
fprintf('Building Transfer session pairs from AudioLightBaseline...\n');
TransferSess = iLightWaterSessions(ALB);
fprintf('Transfer sessions (before ceiling): %d from %d mice\n', height(TransferSess), numel(unique(TransferSess.Mouse)));
TransferSess = iExcludeCeiling(TransferSess);
fprintf('Transfer sessions (after ceiling): %d\n', height(TransferSess));

PairsT = iSessionPairs(TransferSess);
nPairsT = height(PairsT);
deltaHitT = PairsT.PerformanceNext - PairsT.Performance;
hitKT     = PairsT.Performance;
fprintf('Transfer session pairs: %d from %d mice\n\n', nPairsT, numel(unique(PairsT.Mouse)));

%% 2b. First Transfer LW session per mouse (for Test A: mouse-level)
fprintf('Building first Transfer LW session per mouse...\n');
FirstTransferSess = iFirstTransferSession(ALB);
nMiceAll = height(FirstTransferSess);
fprintf('First Transfer sessions: %d mice\n', nMiceAll);
for iM = 1:nMiceAll
	fprintf('  %s: %s, perf=%.0f%%\n', FirstTransferSess.Mouse(iM), ...
		datestr(FirstTransferSess.DateTime(iM),'yyyy-mm-dd'), FirstTransferSess.Performance(iM)*100);
end
fprintf('\n');

%% 3. Get AW Learned data per mouse
fprintf('Loading AudioWater Learned data per mouse...\n');
miceAll = unique([string(PairsT.Mouse); FirstTransferSess.Mouse]);
awStore = struct();
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	mSafe = matlab.lang.makeValidName(char(m));
	[uid, ntats_aw] = iAWLearnedNTATS(ALB, m);
	nts_aw = iAWLearnedNTS(ALB, m);
	awStore.(mSafe) = struct('uid', uid, 'ntats', ntats_aw, 'nts', nts_aw);
	fprintf('  %s: %d cells (NTATS), %d NTS rows\n', m, numel(uid), height(nts_aw));
end
fprintf('\n');

%% 4. Define 3 target features (pair-averaged SD at 1.0s, 3 layers)
targets = {
	'1p0s_All_MeanPairSD',    1;
	'1p0s_MOp23_MeanPairSD',  2;
	'1p0s_MOp5_MeanPairSD',   3;
	};
nTargets = size(targets, 1);

%% 5. Compute pair-level features (normal & ablated) for Transfer
featNormal  = nan(nPairsT, nTargets);
featAblated = nan(nPairsT, nTargets);
nCellsNormal  = nan(nPairsT, nTargets);
nCellsAblated = nan(nPairsT, nTargets);
pctRemoved    = nan(nPairsT, nTargets);

CAll = ALB.Cells;
CAll.CellUID = uint64(CAll.CellUID); CAll.Mouse = string(CAll.Mouse); CAll.ZLayer = string(CAll.ZLayer);

fprintf('Computing pair-averaged SD for %d Transfer pairs...\n', nPairsT);
for iPair = 1:nPairsT
	m = string(PairsT.Mouse(iPair));
	dtK  = PairsT.DateTime(iPair);
	dtK1 = PairsT.DateTimeNext(iPair);
	mSafe = matlab.lang.makeValidName(char(m));

	% Session NTATS for k and k+1
	[uidK,  ntatsK]  = iSessionNTATS(ALB, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(ALB, m, dtK1);

	cellLayer = iCellLayerLookup(CAll, m);

	% AW Learned data
	awUID   = awStore.(mSafe).uid;
	awNTATS = awStore.(mSafe).ntats;

	for iF = 1:nTargets
		lI = targets{iF, 2};
		lFilt = layerFilters{lI};

		% AW-active cells in this layer
		awActiveUIDs = iAWActiveCells(awUID, awNTATS, cellLayer, lFilt, baseMask, idx1s, kSigma);

		% Layer cells for K and K+1
		[layerUIDK,  layerIdxK]  = iLayerCells(uidK,  cellLayer, lFilt);
		[layerUIDK1, layerIdxK1] = iLayerCells(uidK1, cellLayer, lFilt);

		% Ablated versions
		[~, ablIdxK]  = iExcludeCells(layerUIDK,  layerIdxK,  awActiveUIDs);
		[~, ablIdxK1] = iExcludeCells(layerUIDK1, layerIdxK1, awActiveUIDs);

		% Cell counts (use combined unique across k and k+1)
		nOrigK  = numel(layerIdxK);  nOrigK1 = numel(layerIdxK1);
		nAblK   = numel(ablIdxK);    nAblK1  = numel(ablIdxK1);
		nCellsNormal(iPair, iF)  = round((nOrigK + nOrigK1) / 2);
		nCellsAblated(iPair, iF) = round((nAblK  + nAblK1)  / 2);
		nOrig = nOrigK + nOrigK1;
		if nOrig > 0
			pctRemoved(iPair, iF) = 100 * (1 - (nAblK + nAblK1) / nOrig);
		end

		% --- Normal pair-averaged SD ---
		sdK  = iInterCellSD(ntatsK,  layerIdxK,  idx1s);
		sdK1 = iInterCellSD(ntatsK1, layerIdxK1, idx1s);
		if isfinite(sdK) && isfinite(sdK1)
			featNormal(iPair, iF) = (sdK + sdK1) / 2;
		end

		% --- Ablated pair-averaged SD ---
		sdKa  = iInterCellSD(ntatsK,  ablIdxK,  idx1s);
		sdK1a = iInterCellSD(ntatsK1, ablIdxK1, idx1s);
		if isfinite(sdKa) && isfinite(sdK1a)
			featAblated(iPair, iF) = (sdKa + sdK1a) / 2;
		end
	end
	fprintf('  Pair %d/%d done (%s %s)\n', iPair, nPairsT, m, datestr(dtK, 'yyyy-mm-dd'));
end

%% 5b. Mouse-level feature for Test A
% For each mouse: mean of all valid pair-averaged SDs
fprintf('\nComputing mouse-level features for Test A (%d mice)...\n', nMiceAll);
nAWMetrics = 8;
awMetricLabels = {'AW_ActFrac','AW_MeanNTATS','AW_SD','AW_nCells','AW_nActive',...
	'AW_Divergence','AW_MeanBaseline','AW_PeakResp'};

featMouseA  = nan(nMiceAll, nTargets);
awMouseAll  = nan(nMiceAll, nTargets, nAWMetrics);

postMask = (xsSec >= 0) & (xsSec <= 2);

for iM = 1:nMiceAll
	m  = FirstTransferSess.Mouse(iM);
	mSafe = matlab.lang.makeValidName(char(m));

	% Mouse-level Transfer pair-averaged SD: mean across all pairs for this mouse
	pairRows = find(string(PairsT.Mouse) == m);
	for iF = 1:nTargets
		vals = featNormal(pairRows, iF);
		vals = vals(isfinite(vals));
		if ~isempty(vals)
			featMouseA(iM, iF) = mean(vals);
		end
	end

	% AW characteristics
	cellLayer = iCellLayerLookup(CAll, m);
	awUID   = awStore.(mSafe).uid;
	awNTATS = awStore.(mSafe).ntats;
	awNTS   = awStore.(mSafe).nts;

	for iF = 1:nTargets
		lI = targets{iF, 2};
		lFilt = layerFilters{lI};

		[awLayerUID, awLayerIdx] = iLayerCells(awUID, cellLayer, lFilt);
		if isempty(awLayerIdx), continue; end

		% 1. ActFrac
		base_aw = awNTATS(awLayerIdx, baseMask);
		resp_aw = awNTATS(awLayerIdx, idx1s);
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

		% 4. nCells
		awMouseAll(iM, iF, 4) = numel(awLayerIdx);

		% 5. nActive
		awMouseAll(iM, iF, 5) = nnz(activeVec);

		% 6. Divergence
		awMouseAll(iM, iF, 6) = iDivergence(awNTS, awUID, cellLayer, lFilt, idx1s);

		% 7. MeanBaseline
		baseAll = awNTATS(awLayerIdx, baseMask);
		awMouseAll(iM, iF, 7) = mean(baseAll(:), 'omitnan');

		% 8. PeakResponse
		postAll = awNTATS(awLayerIdx, postMask);
		meanPost = mean(postAll, 1, 'omitnan');
		awMouseAll(iM, iF, 8) = max(meanPost);
	end
	fprintf('  Mouse %d/%d done (%s)\n', iM, nMiceAll, m);
end
fprintf('\n');

%% 6. Compute Naive pair-averaged SD (matching Fig3F: LightAudioBaseline + LAInterspersed)
fprintf('Computing Naive pair-averaged SD...\n');
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
nPairsN = height(PairsN);
fprintf('Naive LW: %d adjacent session pairs\n', nPairsN);

naivePairSD = nan(nPairsN, nTargets);

for iP = 1:nPairsN
	m    = string(PairsN.Mouse(iP));
	dtK  = PairsN.DateTime(iP);
	dtK1 = PairsN.DateTimeNext(iP);
	srcK  = string(PairsN.Source(iP));
	srcK1 = string(PairsN.SourceNext(iP));

	DSk  = iPickDS(naiveDSList, srcK);
	DSk1 = iPickDS(naiveDSList, srcK1);
	CellsK  = DSk.Cells;  CellsK.CellUID  = uint64(CellsK.CellUID);  CellsK.Mouse  = string(CellsK.Mouse);  CellsK.ZLayer  = string(CellsK.ZLayer);
	CellsK1 = DSk1.Cells; CellsK1.CellUID = uint64(CellsK1.CellUID); CellsK1.Mouse = string(CellsK1.Mouse); CellsK1.ZLayer = string(CellsK1.ZLayer);

	[uidK,  ntatsK]  = iSessionNTATS(DSk,  m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(DSk1, m, dtK1);

	cellLayerK  = iCellLayerLookup(CellsK,  m);
	cellLayerK1 = iCellLayerLookup(CellsK1, m);

	for iF = 1:nTargets
		lI = targets{iF, 2};
		lFilt = layerFilters{lI};

		[~, idxK]  = iLayerCells(uidK,  cellLayerK,  lFilt);
		[~, idxK1] = iLayerCells(uidK1, cellLayerK1, lFilt);

		sdK  = iInterCellSD(ntatsK,  idxK,  idx1s);
		sdK1 = iInterCellSD(ntatsK1, idxK1, idx1s);

		if isfinite(sdK) && isfinite(sdK1)
			naivePairSD(iP, iF) = (sdK + sdK1) / 2;
		end
	end

	if mod(iP, 20) == 0
		fprintf('  Naive pair %d/%d done\n', iP, nPairsN);
	end
end
fprintf('  Naive pair %d/%d done\n', nPairsN, nPairsN);
fprintf('\n');

%% 7. Run Tests and Report
fprintf('\n================================================================================\n');
fprintf('  RESULTS: AudioWater Mediation (Pair-Averaged SD, 3 layers)\n');
fprintf('================================================================================\n\n');

summaryTable = cell(nTargets, 11);

for iF = 1:nTargets
	fname = targets{iF, 1};

	xT  = featNormal(:, iF);
	xTa = featAblated(:, iF);
	xN  = naivePairSD(:, iF);

	maskT  = isfinite(xT)  & isfinite(deltaHitT) & isfinite(hitKT);
	maskTa = isfinite(xTa) & isfinite(deltaHitT) & isfinite(hitKT);

	avgRemoved = mean(pctRemoved(:, iF), 'omitnan');

	fprintf('--- %s ---\n', fname);
	fprintf('  Transfer pairs: %d valid (normal), %d valid (ablated)\n', nnz(isfinite(xT)), nnz(isfinite(xTa)));
	fprintf('  Naive pairs: %d valid\n', nnz(isfinite(xN)));
	fprintf('  Cells per pair: normal≈%d, ablated≈%d (removed %.1f%%)\n', ...
		round(mean(nCellsNormal(:,iF),'omitnan')), ...
		round(mean(nCellsAblated(:,iF),'omitnan')), avgRemoved);

	% ===== A) Mouse-level Spearman with 8 AW metrics =====
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
			fprintf('  [A] Corr with %s (N=%d mice): rho=%+.3f, p=%.4f%s\n', ...
				awMetricLabels{awI}, nnz(msk), rho_aw, p_aw, sigStr);
			if isnan(bestAW_p) || p_aw < bestAW_p
				bestAW_rho = rho_aw; bestAW_p = p_aw; bestAW_label = awMetricLabels{awI};
			end
		end
	end

	% ===== B) Original vs Ablated Partial Spearman =====
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
		fprintf('  [C] Original rank-sum vs Naive: p=%.4f (Transfer n=%d, Naive n=%d)\n', ...
			pRS_orig, numel(xT_clean), numel(xN_clean));
	end
	if numel(xTa_clean) >= 3 && numel(xN_clean) >= 3
		pRS_abl = ranksum(xTa_clean, xN_clean);
		lostRS = (pRS_abl >= 0.05 && pRS_orig < 0.05);
		fprintf('  [C] Ablated rank-sum vs Naive:  p=%.4f', pRS_abl);
		if lostRS, fprintf(' <= LOST significance'); end
		fprintf('\n');
	end

	% Summary
	passA = bestAW_p < 0.05;
	passB = pAbl >= 0.05 && pOrig < 0.05;
	passC = pRS_abl >= 0.05 && pRS_orig < 0.05;

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

%% 8. Final summary
fprintf('\n================================================================================\n');
fprintf('  SUMMARY (Pair-Averaged SD)\n');
fprintf('================================================================================\n');
fprintf('Criteria for AW mediation:\n');
fprintf('  A: Mouse-level mean pair-averaged SD correlates with AW Learned characteristic (N=%d, Spearman p<0.05)\n', nMiceAll);
fprintf('  B: Ablation of AW-active cells (3σ) eliminates Partial Spearman with ΔHit (p>=0.05)\n');
fprintf('  C: Ablation eliminates rank-sum difference between Transfer and Naive (p>=0.05)\n\n');

fprintf('%-30s | %%Rem | AW_corr_p | pSpear_orig → pSpear_abl | RS_orig → RS_abl | Evidence\n', 'Feature');
fprintf('%s\n', repmat('-',1,120));

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

	fullPass = passA && (passB || passC);
	if fullPass, nFullPass = nFullPass + 1; end

	fprintf('%-30s | %4.1f | %9.4f | %+.3f(%.4f) → %+.3f(%.4f) | %.4f → %.4f | %s%s\n', ...
		fname, pctR, awP, rhoO, pO, rhoA, pA, pRSo, pRSa, flags, ...
		iif(fullPass, ' *** FULL PASS', ''));
end

fprintf('\n==> Features with FULL AW mediation (A + B|C): %d / %d\n', nFullPass, nTargets);
fprintf('Done.\n');

% Save to workspace
assignin('base', 'AW_PairSD_Summary', summaryTable);
assignin('base', 'AW_PairSD_FeatNormal', featNormal);
assignin('base', 'AW_PairSD_FeatAblated', featAblated);
assignin('base', 'AW_PairSD_NaivePairSD', naivePairSD);
assignin('base', 'AW_PairSD_FeatMouseA', featMouseA);

%% ======== HELPERS ========

function Sess = iLightWaterSessions(DS)
% Build per-session LW performance (all sessions, no phase filter).
% Matches Fig3F approach.
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
outMouse = strings(nTotal, 1); outDT = NaT(nTotal, 1); outPerf = nan(nTotal, 1);
outDT2 = NaT(nTotal, 1); outPerf2 = nan(nTotal, 1);
if ismember('Source', Sess.Properties.VariableNames)
	outSrc = strings(nTotal, 1); outSrc2 = strings(nTotal, 1); hasSrc = true;
else, hasSrc = false;
end
pos = 0;
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance); dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	R = R(use, :); perf = perf(use); dt = dt(use);
	if numel(perf) < 2, continue; end
	n = numel(perf) - 1; idx = (pos + 1):(pos + n);
	outMouse(idx) = repmat(m, n, 1); outDT(idx) = dt(1:end-1); outPerf(idx) = perf(1:end-1);
	outDT2(idx) = dt(2:end); outPerf2(idx) = perf(2:end);
	if hasSrc, src = string(R.Source); outSrc(idx) = src(1:end-1); outSrc2(idx) = src(2:end); end
	pos = pos + n;
end
Pairs = table(outMouse(1:pos), outDT(1:pos), outPerf(1:pos), outDT2(1:pos), outPerf2(1:pos), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext'});
if hasSrc
	Pairs.Source = outSrc(1:pos); Pairs.SourceNext = outSrc2(1:pos);
end
end

function FirstSess = iFirstTransferSession(ALB)
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

function DS = iPickDS(dsList, name)
for i = 1:numel(dsList)
	if string(dsList{i}.Name) == name, DS = dsList{i}.DS; return; end
end
error('Z_PairSD:DSNotFound', 'Dataset "%s" not found.', name);
end

%% ======== Session NTATS ========
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

%% ======== AW Learned data ========
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

function [ablUID, ablIdx] = iExcludeCells(layerUID, layerIdx, excludeUID)
keep = ~ismember(layerUID, excludeUID);
ablUID = layerUID(keep); ablIdx = layerIdx(keep);
end

%% ======== Cell layer ========
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

%% ======== Feature computation ========
function sd = iInterCellSD(ntats, idx, idxTP)
sd = NaN; if isempty(idx), return; end
v = double(ntats(idx, idxTP)); v = v(isfinite(v));
if numel(v)<3, return; end
sd = std(v,0,1);
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

%% ======== Partial Spearman ========
function [rho, p] = iPartialSpearman(x, y, z)
rx = tiedrank(x); ry = tiedrank(y); rz = tiedrank(z);
rx_res = rx - rz * (rz \ rx);
ry_res = ry - rz * (rz \ ry);
[rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end

%% ======== Utility ========
function v = iif(cond, t, f)
if cond, v = t; else, v = f; end
end
