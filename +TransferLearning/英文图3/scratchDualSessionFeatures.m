% scratchDualSessionFeatures.m
% 探索：要求必须同时使用 session K 和 K+1 数据的钙信号特征，
% 能否预测相邻会话对的行为增量 ΔHit？
%
% 包含已有双会话特征 (CorrKK1, DeltaSD, DeltaActFrac, DeltaMeanNTATS, DeltaDiv)
% 以及新设计的双会话特征 (~25 种)。
%
% 三方筛选：
%   ① Transfer Partial Spearman p < 0.05 (控制 Hit_K)
%   ② Naive Partial Spearman p < 0.05
%   ③ Rank-sum T vs N p < 0.05 且方向一致

fprintf('=== Dual-Session Feature Exploration ===\n');
fprintf('Constraint: every feature MUST use data from BOTH session K and K+1.\n\n');

%% ---- 1. Load datasets ------------------------------------------------
fprintf('Loading datasets...\n');
ALB = TransferLearning.AudioLightBaseline();   % Transfer
LAB = TransferLearning.LightAudioBaseline();   % Naive source 1
LAI = TransferLearning.LAInterspersed();       % Naive source 2

%% ---- 2. Time axis setup -----------------------------------------------
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
layerNames  = ["All","MOp23","MOp5"];
layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};
nTP = numel(timePoints); nLayers = numel(layerNames);

%% ---- 3. Build Transfer session pairs ----------------------------------
fprintf('Building Transfer session pairs (ALB)...\n');
SessT = iLightWaterSessions(ALB);
SessT = iKeepPureLW(ALB, SessT);
SessT = iExcludeCeiling(SessT);
SessSpeedT = iSessionDeltaNext(SessT);
SessSpeedT.Source = repmat("ALB", height(SessSpeedT), 1);
fprintf('  Transfer pairs: %d\n', height(SessSpeedT));

%% ---- 4. Build Naive session pairs -------------------------------------
fprintf('Building Naive session pairs (LAB + LAI)...\n');
SessN = iGatherNaiveSessions(LAB, LAI);
SessN = iExcludeAudioWaterSessions(SessN, LAB, LAI);
SessN = iExcludeCeilingNaive(SessN);
SessSpeedN = iSessionDeltaNextNaive(SessN);
fprintf('  Naive pairs: %d\n', height(SessSpeedN));

%% ---- 5. Define feature names ------------------------------------------
% Per timepoint × layer features (25 per combo):
perTPFeatureBase = { ...
	'CorrKK1', 'RankCorrKK1', ...               % correlation-based (2)
	'DeltaSD', 'DeltaActFrac', 'DeltaMeanNTATS', ...  % existing deltas (3)
	'CrossSD', 'MeanAbsDelta', 'IQRDelta', 'SkewDelta', ... % change heterogeneity (4)
	'SD_ratio', 'SD_geometric', 'SD_harmonic', 'SD_max', 'SD_min', ... % SD combinations (5)
	'RecruitFrac', 'DropoutFrac', 'TurnoverFrac', 'NetRecruitFrac', 'StableActFrac', ... % turnover (5)
	'EuclidDist', 'CosSim', ...                  % pop vector geometry (2)
	'NovelSD', ...                                % interaction (1)
	'SD_K1_among_K_active', 'SD_K1_among_K_inactive', ... % conditioned SD (2)
	'ProfileCorr'};                               % full profile (1)
nPerTP = numel(perTPFeatureBase);

featureNames = {};
for iTP = 1:nTP
	tpStr = strrep(sprintf('%.1fs', timePoints(iTP)), '.', 'p');
	for iL = 1:nLayers
		prefix = [tpStr '_' char(layerNames(iL)) '_'];
		for iF = 1:nPerTP
			featureNames{end+1} = [prefix perTPFeatureBase{iF}]; %#ok<AGROW>
		end
	end
end
% Divergence dual-session features per layer (3 per layer)
for iL = 1:nLayers
	ln = char(layerNames(iL));
	featureNames = [featureNames, {['DeltaDiv1s_' ln], ['DivRatio1s_' ln], ['DivGeometric1s_' ln]}]; %#ok<AGROW>
end

nFeatures = numel(featureNames);
fprintf('Total dual-session features: %d\n', nFeatures);

%% ---- 6. Compute features for Transfer ---------------------------------
nT = height(SessSpeedT);
featT = nan(nT, nFeatures);
hitK_T = nan(nT, 1);
deltaHit_T = nan(nT, 1);

fprintf('\nComputing Transfer features (%d pairs)...\n', nT);
C_ALB = ALB.Cells;
C_ALB.CellUID = uint64(C_ALB.CellUID); C_ALB.Mouse = string(C_ALB.Mouse); C_ALB.ZLayer = string(C_ALB.ZLayer);

for iPair = 1:nT
	m = SessSpeedT.Mouse(iPair);
	dtK  = SessSpeedT.DateTime(iPair);
	dtK1 = SessSpeedT.DateTimeNext(iPair);
	hitK_T(iPair) = SessSpeedT.Performance(iPair);
	deltaHit_T(iPair) = SessSpeedT.Speed_DeltaNext(iPair);

	[uidK, ntatsK]   = iSessionNTATS(ALB, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(ALB, m, dtK1);
	trialsK  = iSessionTrials(ALB, m, dtK);
	trialsK1 = iSessionTrials(ALB, m, dtK1);
	cellLayer = iCellLayerLookup(C_ALB, m);

	featT(iPair, :) = iComputeAllDualFeatures( ...
		uidK, ntatsK, uidK1, ntatsK1, trialsK, trialsK1, ...
		cellLayer, layerFilters, idxTP, baseMask, kSigma, nPerTP, nLayers, nTP, xsSec);

	if mod(iPair, 5) == 0 || iPair == nT
		fprintf('  Transfer %d/%d\n', iPair, nT);
	end
end

%% ---- 7. Compute features for Naive ------------------------------------
nN = height(SessSpeedN);
featN = nan(nN, nFeatures);
hitK_N = nan(nN, 1);
deltaHit_N = nan(nN, 1);

fprintf('\nComputing Naive features (%d pairs)...\n', nN);
C_LAB = LAB.Cells;
C_LAB.CellUID = uint64(C_LAB.CellUID); C_LAB.Mouse = string(C_LAB.Mouse); C_LAB.ZLayer = string(C_LAB.ZLayer);
C_LAI = LAI.Cells;
C_LAI.CellUID = uint64(C_LAI.CellUID); C_LAI.Mouse = string(C_LAI.Mouse); C_LAI.ZLayer = string(C_LAI.ZLayer);

for iPair = 1:nN
	m = SessSpeedN.Mouse(iPair);
	dtK  = SessSpeedN.DateTime(iPair);
	dtK1 = SessSpeedN.DateTimeNext(iPair);
	src  = SessSpeedN.Source(iPair);
	hitK_N(iPair) = SessSpeedN.Performance(iPair);
	deltaHit_N(iPair) = SessSpeedN.Speed_DeltaNext(iPair);

	if src == "LAB", DS = LAB; C_ds = C_LAB; else, DS = LAI; C_ds = C_LAI; end

	[uidK, ntatsK]   = iSessionNTATS(DS, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(DS, m, dtK1);
	trialsK  = iSessionTrials(DS, m, dtK);
	trialsK1 = iSessionTrials(DS, m, dtK1);
	cellLayer = iCellLayerLookup(C_ds, m);

	featN(iPair, :) = iComputeAllDualFeatures( ...
		uidK, ntatsK, uidK1, ntatsK1, trialsK, trialsK1, ...
		cellLayer, layerFilters, idxTP, baseMask, kSigma, nPerTP, nLayers, nTP, xsSec);

	if mod(iPair, 10) == 0 || iPair == nN
		fprintf('  Naive %d/%d\n', iPair, nN);
	end
end

%% ---- 8. Three-way screening -------------------------------------------
fprintf('\n');
fprintf('============================================================\n');
fprintf('   THREE-WAY SCREENING: Dual-Session Features\n');
fprintf('============================================================\n');

% ① Transfer Partial Spearman
rhoT = nan(nFeatures,1); pT = nan(nFeatures,1);
for iF = 1:nFeatures
	x = featT(:,iF); y = deltaHit_T; z = hitK_T;
	ok = isfinite(x) & isfinite(y) & isfinite(z);
	if sum(ok) >= 6 && std(x(ok))>0 && std(y(ok))>0 && std(z(ok))>0
		[rhoT(iF), pT(iF)] = iPartialSpearman(x(ok), y(ok), z(ok));
	end
end

% ② Naive Partial Spearman
rhoN = nan(nFeatures,1); pN = nan(nFeatures,1);
for iF = 1:nFeatures
	x = featN(:,iF); y = deltaHit_N; z = hitK_N;
	ok = isfinite(x) & isfinite(y) & isfinite(z);
	if sum(ok) >= 6 && std(x(ok))>0 && std(y(ok))>0 && std(z(ok))>0
		[rhoN(iF), pN(iF)] = iPartialSpearman(x(ok), y(ok), z(ok));
	end
end

% ③ Rank-sum Transfer vs Naive
pRS = nan(nFeatures,1); medT = nan(nFeatures,1); medN = nan(nFeatures,1);
dirStr = strings(nFeatures,1);
for iF = 1:nFeatures
	tV = featT(:,iF); nV = featN(:,iF);
	tVf = tV(isfinite(tV)); nVf = nV(isfinite(nV));
	medT(iF) = median(tVf); medN(iF) = median(nVf);
	if medT(iF) >= medN(iF), dirStr(iF) = "T>N"; else, dirStr(iF) = "T<N"; end
	if numel(tVf)>=2 && numel(nVf)>=2
		pRS(iF) = ranksum(tVf, nVf);
	end
end

% Combine results
R = table(string(featureNames)', rhoT, pT, rhoN, pN, pRS, medT, medN, dirStr, ...
	'VariableNames', {'Feature','rhoT','pT','rhoN','pN','pRS','medT','medN','Dir'});

% Direction consistency
dirOK = false(nFeatures,1);
for iF = 1:nFeatures
	if isfinite(rhoT(iF)) && isfinite(pRS(iF))
		if (rhoT(iF)>0 && dirStr(iF)=="T>N") || (rhoT(iF)<0 && dirStr(iF)=="T<N")
			dirOK(iF) = true;
		end
	end
end

% Verdict
pass1 = isfinite(pT) & pT < 0.05;
pass2 = isfinite(pN) & pN < 0.05;
pass3 = isfinite(pRS) & pRS < 0.05 & dirOK;
passAll = pass1 & pass2 & pass3;

%% ---- 9. Print results sorted by combined evidence ---------------------
% Sort by geometric mean of p-values (all 3 tests)
geoP = (pT .* pN .* pRS).^(1/3);
geoP(~isfinite(geoP)) = 1;
[~, sortIdx] = sort(geoP);

% Print features that pass ①
fprintf('\n===== Features passing ① Transfer Partial Spearman p<0.05 =====\n');
fprintf('%-55s %7s %8s  %7s %8s  %8s %5s %5s  %s\n', ...
	'Feature','rhoT','pT','rhoN','pN','pRS','Dir','DirOK','Verdict');
fprintf('%s\n', repmat('-',1,130));
nShown = 0;
for i = sortIdx'
	if ~pass1(i), continue; end
	nShown = nShown + 1;
	v = "FAIL";
	if passAll(i), v = "** PASS **"; end
	dOK = "N"; if dirOK(i), dOK = "Y"; end
	fprintf('%-55s %+7.3f %8.4f  %+7.3f %8.4f  %8.4f %5s %5s  %s\n', ...
		R.Feature(i), rhoT(i), pT(i), rhoN(i), pN(i), pRS(i), dirStr(i), dOK, v);
end
fprintf('Total passing ①: %d\n', nShown);

% Print features that pass ①②
fprintf('\n===== Features passing ①② (both Partial Spearman p<0.05) =====\n');
fprintf('%-55s %7s %8s  %7s %8s  %8s %5s %5s  %s\n', ...
	'Feature','rhoT','pT','rhoN','pN','pRS','Dir','DirOK','Verdict');
fprintf('%s\n', repmat('-',1,130));
nShown12 = 0;
for i = sortIdx'
	if ~pass1(i) || ~pass2(i), continue; end
	nShown12 = nShown12 + 1;
	v = "FAIL ③";
	if passAll(i), v = "** PASS **"; end
	dOK = "N"; if dirOK(i), dOK = "Y"; end
	fprintf('%-55s %+7.3f %8.4f  %+7.3f %8.4f  %8.4f %5s %5s  %s\n', ...
		R.Feature(i), rhoT(i), pT(i), rhoN(i), pN(i), pRS(i), dirStr(i), dOK, v);
end
fprintf('Total passing ①②: %d\n', nShown12);

% Print PASS features
fprintf('\n===== *** FEATURES PASSING ALL THREE TESTS *** =====\n');
nPass = 0;
for i = sortIdx'
	if ~passAll(i), continue; end
	nPass = nPass + 1;
	fprintf('%d. %-55s  T: rho=%+.3f p=%.4f  N: rho=%+.3f p=%.4f  RS: p=%.4f %s\n', ...
		nPass, R.Feature(i), rhoT(i), pT(i), rhoN(i), pN(i), pRS(i), dirStr(i));
end
if nPass == 0
	fprintf('  (None)\n');
	
	% Show top-10 by combined p-value as consolation
	fprintf('\n===== Top-10 by combined evidence (geometric mean of p-values) =====\n');
	fprintf('%-55s %7s %8s  %7s %8s  %8s %5s  %8s\n', ...
		'Feature','rhoT','pT','rhoN','pN','pRS','Dir','geoP');
	fprintf('%s\n', repmat('-',1,120));
	for rank = 1:min(10, nFeatures)
		i = sortIdx(rank);
		fprintf('%-55s %+7.3f %8.4f  %+7.3f %8.4f  %8.4f %5s  %8.4f\n', ...
			R.Feature(i), rhoT(i), pT(i), rhoN(i), pN(i), pRS(i), dirStr(i), geoP(i));
	end
end
fprintf('\nTotal passing all 3 tests: %d / %d\n', nPass, nFeatures);

% Save to workspace
assignin('base', 'DualFeat_Results', R);
assignin('base', 'DualFeat_FeatT', featT);
assignin('base', 'DualFeat_FeatN', featN);
assignin('base', 'DualFeat_PassAll', passAll);
fprintf('\nDone. Results saved to workspace.\n');

%% ======== MASTER FEATURE COMPUTATION ==================================
function allVals = iComputeAllDualFeatures(uidK, ntatsK, uidK1, ntatsK1, ...
	trialsK, trialsK1, cellLayer, layerFilters, idxTP, baseMask, kSigma, ...
	nPerTP, nLayers, nTP, xsSec)

nDivPerLayer = 3;
nFeat = nPerTP * nTP * nLayers + nDivPerLayer * nLayers;
allVals = nan(1, nFeat);

col = 0;
for iTP = 1:nTP
	idx = idxTP(iTP);
	if ~isfinite(idx)
		col = col + nPerTP * nLayers;
		continue;
	end

	for iL = 1:nLayers
		lFilt = layerFilters{iL};

		% Common cells between K and K+1 (for paired features)
		[~, iK_kk1, iK1_kk1] = iCommonCells(uidK, uidK1, cellLayer, lFilt);
		% All layer cells per session (for SD, ActFrac, etc.)
		[~, iaK]  = iLayerCells(uidK,  cellLayer, lFilt);
		[~, iaK1] = iLayerCells(uidK1, cellLayer, lFilt);

		nCommon = numel(iK_kk1);

		% ---- Basic quantities ----
		% Response vectors at time t for common cells
		if nCommon >= 3
			vK  = double(ntatsK(iK_kk1, idx));
			vK1 = double(ntatsK1(iK1_kk1, idx));
			delta = vK1 - vK;
		else
			vK = []; vK1 = []; delta = [];
		end

		% SD per session (all layer cells, not just common)
		sdK  = iInterCellSD(ntatsK,  iaK,  idx);
		sdK1 = iInterCellSD(ntatsK1, iaK1, idx);

		% ActFrac per session
		afK  = iActiveFrac(ntatsK,  iaK,  baseMask, idx, kSigma);
		afK1 = iActiveFrac(ntatsK1, iaK1, baseMask, idx, kSigma);

		% Mean NTATS per session
		mnK  = iMeanNTATS(ntatsK,  iaK,  idx);
		mnK1 = iMeanNTATS(ntatsK1, iaK1, idx);

		% ---- 1. CorrKK1 (Pearson) ----
		corrKK1 = iVecCorr(ntatsK, iK_kk1, ntatsK1, iK1_kk1, idx);

		% ---- 2. RankCorrKK1 (Spearman) ----
		rankCorrKK1 = NaN;
		if nCommon >= 5
			okR = isfinite(vK) & isfinite(vK1);
			if nnz(okR) >= 5 && std(vK(okR))>0 && std(vK1(okR))>0
				rankCorrKK1 = corr(vK(okR), vK1(okR), 'Type', 'Spearman');
			end
		end

		% ---- 3-5. Existing deltas ----
		deltaSD  = sdK1 - sdK;
		deltaAF  = afK1 - afK;
		deltaMN  = mnK1 - mnK;

		% ---- 6. CrossSD = std of per-cell delta ----
		crossSD = NaN;
		if ~isempty(delta) && nnz(isfinite(delta)) >= 3
			crossSD = std(delta(isfinite(delta)), 0, 1);
		end

		% ---- 7. MeanAbsDelta ----
		meanAbsDelta = NaN;
		if ~isempty(delta) && nnz(isfinite(delta)) >= 3
			meanAbsDelta = mean(abs(delta(isfinite(delta))), 'omitnan');
		end

		% ---- 8. IQRDelta ----
		iqrDelta = NaN;
		if ~isempty(delta) && nnz(isfinite(delta)) >= 5
			iqrDelta = iqr(delta(isfinite(delta)));
		end

		% ---- 9. SkewDelta ----
		skewDelta = NaN;
		if ~isempty(delta) && nnz(isfinite(delta)) >= 5
			skewDelta = skewness(delta(isfinite(delta)));
		end

		% ---- 10-14. SD combinations ----
		sdRatio = NaN; sdGeo = NaN; sdHarm = NaN; sdMax = NaN; sdMin = NaN;
		if isfinite(sdK) && isfinite(sdK1)
			if sdK > 0
				sdRatio = sdK1 / sdK;
			end
			sdGeo = sqrt(sdK * sdK1);
			if (sdK + sdK1) > 0
				sdHarm = 2 * sdK * sdK1 / (sdK + sdK1);
			end
			sdMax = max(sdK, sdK1);
			sdMin = min(sdK, sdK1);
		end

		% ---- 15-19. Cell turnover ----
		recruitFrac = NaN; dropoutFrac = NaN; turnoverFrac = NaN;
		netRecruitFrac = NaN; stableActFrac = NaN;
		if nCommon >= 5
			% Active/inactive status for common cells
			baseK  = ntatsK(iK_kk1, baseMask);
			baseK1 = ntatsK1(iK1_kk1, baseMask);
			threshK  = mean(baseK,  2, 'omitnan') + kSigma * std(baseK,  0, 2, 'omitnan');
			threshK1 = mean(baseK1, 2, 'omitnan') + kSigma * std(baseK1, 0, 2, 'omitnan');
			actK  = double(ntatsK(iK_kk1, idx))  > threshK;
			actK1 = double(ntatsK1(iK1_kk1, idx)) > threshK1;

			recruitFrac    = mean(~actK & actK1, 'omitnan');  % inactive→active
			dropoutFrac    = mean(actK & ~actK1, 'omitnan');  % active→inactive
			turnoverFrac   = recruitFrac + dropoutFrac;
			netRecruitFrac = recruitFrac - dropoutFrac;
			stableActFrac  = mean(actK & actK1, 'omitnan');   % active in both
		end

		% ---- 20. EuclidDist (normalized) ----
		euclidDist = NaN;
		if nCommon >= 3 && ~isempty(delta)
			fd = delta(isfinite(delta));
			if numel(fd) >= 3
				euclidDist = sqrt(mean(fd.^2));
			end
		end

		% ---- 21. CosSim ----
		cosSim = NaN;
		if nCommon >= 5 && ~isempty(vK) && ~isempty(vK1)
			okC = isfinite(vK) & isfinite(vK1);
			if nnz(okC) >= 5
				nK = norm(vK(okC)); nK1 = norm(vK1(okC));
				if nK > 0 && nK1 > 0
					cosSim = dot(vK(okC), vK1(okC)) / (nK * nK1);
				end
			end
		end

		% ---- 22. NovelSD = (1 - CorrKK1) * SD_geometric ----
		novelSD = NaN;
		if isfinite(corrKK1) && isfinite(sdGeo)
			novelSD = (1 - corrKK1) * sdGeo;
		end

		% ---- 23-24. SD_K1 among K-active / K-inactive cells ----
		sdK1_Kact = NaN;
		sdK1_Kinact = NaN;
		if nCommon >= 5
			baseK_  = ntatsK(iK_kk1, baseMask);
			threshK_ = mean(baseK_, 2, 'omitnan') + kSigma * std(baseK_, 0, 2, 'omitnan');
			actK_ = double(ntatsK(iK_kk1, idx)) > threshK_;
			% K-active → K+1 SD
			if nnz(actK_) >= 3
				vals_K1act = double(ntatsK1(iK1_kk1(actK_), idx));
				vals_K1act = vals_K1act(isfinite(vals_K1act));
				if numel(vals_K1act) >= 3
					sdK1_Kact = std(vals_K1act, 0, 1);
				end
			end
			% K-inactive → K+1 SD
			inactK_ = ~actK_;
			if nnz(inactK_) >= 3
				vals_K1inact = double(ntatsK1(iK1_kk1(inactK_), idx));
				vals_K1inact = vals_K1inact(isfinite(vals_K1inact));
				if numel(vals_K1inact) >= 3
					sdK1_Kinact = std(vals_K1inact, 0, 1);
				end
			end
		end

		% ---- 25. ProfileCorr: mean per-cell temporal profile correlation ----
		profileCorr = NaN;
		if nCommon >= 5
			% Use response window (0 to 2s)
			respMask = (xsSec >= 0) & (xsSec <= 2);
			nTimeResp = nnz(respMask);
			if nTimeResp >= 4
				profCorrs = nan(nCommon, 1);
				for iC = 1:nCommon
					pK  = double(ntatsK(iK_kk1(iC), respMask));
					pK1 = double(ntatsK1(iK1_kk1(iC), respMask));
					if all(isfinite(pK)) && all(isfinite(pK1)) && std(pK)>0 && std(pK1)>0
						profCorrs(iC) = corr(pK(:), pK1(:), 'Type', 'Pearson');
					end
				end
				if nnz(isfinite(profCorrs)) >= 3
					profileCorr = mean(profCorrs, 'omitnan');
				end
			end
		end

		% ---- Pack into output vector ----
		vals = [corrKK1, rankCorrKK1, ...                  % 1-2
			deltaSD, deltaAF, deltaMN, ...                 % 3-5
			crossSD, meanAbsDelta, iqrDelta, skewDelta, ... % 6-9
			sdRatio, sdGeo, sdHarm, sdMax, sdMin, ...      % 10-14
			recruitFrac, dropoutFrac, turnoverFrac, netRecruitFrac, stableActFrac, ... % 15-19
			euclidDist, cosSim, ...                         % 20-21
			novelSD, ...                                   % 22
			sdK1_Kact, sdK1_Kinact, ...                    % 23-24
			profileCorr];                                  % 25

		allVals(col+1 : col+nPerTP) = vals;
		col = col + nPerTP;
	end
end

% ---- Divergence features @ 1s ----
idxDiv = idxTP(3); % 1.0s
for iL = 1:nLayers
	lFilt = layerFilters{iL};
	divK  = iDivergence(trialsK,  uidK,  cellLayer, lFilt, idxDiv);
	divK1 = iDivergence(trialsK1, uidK1, cellLayer, lFilt, idxDiv);

	deltaDiv = divK1 - divK;
	divRatio = NaN;
	if isfinite(divK) && divK > 0
		divRatio = divK1 / divK;
	end
	divGeo = NaN;
	if isfinite(divK) && isfinite(divK1) && divK >= 0 && divK1 >= 0
		divGeo = sqrt(divK * divK1);
	end

	allVals(col+1 : col+3) = [deltaDiv, divRatio, divGeo];
	col = col + 3;
end
end

%% ======== SESSION PAIR BUILDING (Transfer) ============================
function Sess = iLightWaterSessions(DS)
Tblk = DS.TableQuery(["Mouse","DateTime","BlockUID","Phase"]);
Tr = DS.Trials;
TrLW = Tr(string(Tr.Stimulus)=="LightWater", {'BlockUID','Behavior'});
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});
Tblk.Mouse = string(Tblk.Mouse);
Tblk.DateTime = datetime(Tblk.DateTime); Tblk.DateTime.TimeZone = '';
[tf, loc] = ismember(uint64(Tblk.BlockUID), perfByBlock.BlockUID64);
Tblk = Tblk(tf,:); Tblk.LWPerf = perfByBlock.LWPerf(loc(tf));
[G2, mouse, dt] = findgroups(string(Tblk.Mouse), Tblk.DateTime);
perf = splitapply(@(x) mean(double(x),'omitnan'), Tblk.LWPerf, G2);
Sess = table(mouse, dt, perf, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW(DS, SessIn)
SessOut = SessIn; SessOut.Mouse = string(SessOut.Mouse);
keep = true(height(SessOut),1);
for i = 1:height(SessOut)
	Ta = DS.TableQuery("Stimulus", Mouse=SessOut.Mouse(i), DateTime=SessOut.DateTime(i), Stimulus="AudioWater");
	if ~isempty(Ta), keep(i) = false; end
end
SessOut = SessOut(keep,:);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn; SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut),1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
SessOut(remove,:) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end

function SessSpeed = iSessionDeltaNext(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'}); Sess.Mouse = string(Sess.Mouse);
outM = strings(0,1); outDT = NaT(0,1); outP = nan(0,1);
outDT2 = NaT(0,1); outP2 = nan(0,1); outDN = nan(0,1);
for m = unique(Sess.Mouse)'
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance); dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt); perf = perf(use); dt = dt(use);
	if numel(perf)<2, continue; end
	dn = diff(perf); n = numel(dn);
	outM = [outM; repmat(m,n,1)]; outDT = [outDT; dt(1:end-1)]; outP = [outP; perf(1:end-1)]; %#ok<AGROW>
	outDT2 = [outDT2; dt(2:end)]; outP2 = [outP2; perf(2:end)]; outDN = [outDN; dn(:)]; %#ok<AGROW>
end
SessSpeed = table(outM, outDT, outP, outDT2, outP2, outDN, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end

%% ======== SESSION PAIR BUILDING (Naive) ===============================
function AllSess = iGatherNaiveSessions(LAB, LAI)
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

function SessSpeed = iSessionDeltaNextNaive(Sess)
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

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus)); st = st(~ismissing(st));
tf = any(st == string(stim));
end

%% ======== NTATS & TRIAL HELPERS =======================================
function [uid, ntats] = iSessionNTATS(DS, mouse, dt)
q = struct('Mouse', char(mouse), 'DateTime', dt, 'Stimulus', 'LightWater');
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
uid = uint64.empty(0,1); ntats = [];
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
nts = ntsCell{1};
if ~istable(nts) || height(nts)==0, return; end
if ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames))), return; end
uid = unique(uint64(nts.CellUID));
nTT = size(nts.TrialSignal, 2);
ntats = nan(numel(uid), nTT);
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

%% ======== SINGLE-SESSION FEATURE HELPERS ==============================
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

function r = iVecCorr(ntatsA, idxA, ntatsB, idxB, idxTP)
r = NaN;
if isempty(idxA) || isempty(idxB) || numel(idxA)<5, return; end
vA = double(ntatsA(idxA, idxTP)); vB = double(ntatsB(idxB, idxTP));
use = isfinite(vA) & isfinite(vB);
if nnz(use)<5 || std(vA(use))==0 || std(vB(use))==0, return; end
r = corr(vA(use), vB(use), 'Type', 'Pearson');
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

%% ======== STATISTICS ==================================================
function [rho, p] = iPartialSpearman(x, y, z)
rx = tiedrank(x); ry = tiedrank(y); rz = tiedrank(z);
rx_res = rx - rz * (rz \ rx);
ry_res = ry - rz * (rz \ ry);
[rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end
