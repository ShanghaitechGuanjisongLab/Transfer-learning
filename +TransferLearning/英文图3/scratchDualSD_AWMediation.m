% scratchDualSD_AWMediation.m
% 双会话对称 SD 指标的 AW 中介分析
%
% 目标特征：SD_geometric (= sqrt(SD_K * SD_K1)) @ 1.0s, 3 层
% 检验：
%   Test A: 第一 Transfer LW 会话的 SD_geometric 与 AW Learned 钙特征的 Spearman 相关
%   Test B: 消融 AW 活跃细胞后, SD_geometric 是否丧失对 ΔHit 的 Partial Spearman 预测力
%   Test C: 消融 AW 活跃细胞后, Transfer vs Naive 的 rank-sum 差异是否消失

fprintf('=== Dual-Session Symmetric SD: AW Mediation Analysis ===\n\n');

%% 1. Load datasets
ALB = TransferLearning.AudioLightBaseline();   % Transfer
LAB = TransferLearning.LightAudioBaseline();   % Naive
LAI = TransferLearning.LAInterspersed();       % Naive

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);

idx1s = []; [~, idx1s] = min(abs(xsSec - 1.0));
kSigma = 3;

layerNames  = ["All","MOp23","MOp5"];
layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};
nLayers = 3;

C_ALB = ALB.Cells;
C_ALB.CellUID = uint64(C_ALB.CellUID); C_ALB.Mouse = string(C_ALB.Mouse); C_ALB.ZLayer = string(C_ALB.ZLayer);

%% 2. Transfer session pairs
fprintf('Building Transfer session pairs...\n');
SessT = iLightWaterSessions(ALB);
SessT = iKeepPureLW(ALB, SessT);
SessT = iExcludeCeiling(SessT);
SessSpeedT = iSessionDeltaNext(SessT);
nPairsT = height(SessSpeedT);
deltaHitT = double(SessSpeedT.Speed_DeltaNext);
hitKT     = double(SessSpeedT.Performance);
fprintf('  Transfer pairs: %d from %d mice\n', nPairsT, numel(unique(SessSpeedT.Mouse)));

%% 3. Naive session pairs
fprintf('Building Naive session pairs...\n');
SessN = iGatherNaiveSessions(LAB, LAI);
SessN = iExcludeAudioWaterSessions(SessN, LAB, LAI);
SessN = iExcludeCeilingNaive(SessN);
SessSpeedN = iSessionDeltaNextNaive(SessN);
nPairsN = height(SessSpeedN);
deltaHitN = double(SessSpeedN.Speed_DeltaNext);
hitKN     = double(SessSpeedN.Performance);
fprintf('  Naive pairs: %d from %d mice\n\n', nPairsN, numel(unique(SessSpeedN.Mouse)));

C_LAB = LAB.Cells; C_LAB.CellUID = uint64(C_LAB.CellUID); C_LAB.Mouse = string(C_LAB.Mouse); C_LAB.ZLayer = string(C_LAB.ZLayer);
C_LAI = LAI.Cells; C_LAI.CellUID = uint64(C_LAI.CellUID); C_LAI.Mouse = string(C_LAI.Mouse); C_LAI.ZLayer = string(C_LAI.ZLayer);

%% 4. Load AW Learned data per Transfer mouse
fprintf('Loading AW Learned data per Transfer mouse...\n');
miceT = unique(string(SessSpeedT.Mouse));
awStore = struct();
for iM = 1:numel(miceT)
	m = miceT(iM);
	mSafe = matlab.lang.makeValidName(char(m));
	[uid, ntats_aw] = iAWLearnedNTATS(ALB, m);
	awStore.(mSafe) = struct('uid', uid, 'ntats', ntats_aw);
	fprintf('  %s: %d AW cells\n', m, numel(uid));
end
fprintf('\n');

%% 5. Compute SD_geometric for Transfer (normal + ablated)
fprintf('Computing Transfer features (normal + ablated)...\n');
sdGeoT_norm = nan(nPairsT, nLayers);
sdGeoT_abl  = nan(nPairsT, nLayers);
nCellsOrig  = nan(nPairsT, nLayers);
nCellsAbl   = nan(nPairsT, nLayers);

for iPair = 1:nPairsT
	m = SessSpeedT.Mouse(iPair);
	dtK  = SessSpeedT.DateTime(iPair);
	dtK1 = SessSpeedT.DateTimeNext(iPair);
	mSafe = matlab.lang.makeValidName(char(m));

	[uidK,  ntatsK]  = iSessionNTATS(ALB, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(ALB, m, dtK1);
	cellLayer = iCellLayerLookup(C_ALB, m);

	awUID   = awStore.(mSafe).uid;
	awNTATS = awStore.(mSafe).ntats;

	for iL = 1:nLayers
		lFilt = layerFilters{iL};

		% Normal SD_K, SD_K1
		[~, iaK]  = iLayerCells(uidK,  cellLayer, lFilt);
		[~, iaK1] = iLayerCells(uidK1, cellLayer, lFilt);

		sdK  = iInterCellSD(ntatsK,  iaK,  idx1s);
		sdK1 = iInterCellSD(ntatsK1, iaK1, idx1s);

		if isfinite(sdK) && isfinite(sdK1) && sdK >= 0 && sdK1 >= 0
			sdGeoT_norm(iPair, iL) = sqrt(sdK * sdK1);
		end
		nCellsOrig(iPair, iL) = numel(iaK1);

		% Ablated: remove AW-active cells
		awActUIDs = iAWActiveCells(awUID, awNTATS, cellLayer, lFilt, baseMask, idx1s, kSigma);

		[layerUIDK,  lidxK]  = iLayerCells(uidK,  cellLayer, lFilt);
		[layerUIDK1, lidxK1] = iLayerCells(uidK1, cellLayer, lFilt);

		keepK  = ~ismember(layerUIDK,  awActUIDs);
		keepK1 = ~ismember(layerUIDK1, awActUIDs);

		ablIdxK  = lidxK(keepK);
		ablIdxK1 = lidxK1(keepK1);

		sdK_a  = iInterCellSD(ntatsK,  ablIdxK,  idx1s);
		sdK1_a = iInterCellSD(ntatsK1, ablIdxK1, idx1s);

		if isfinite(sdK_a) && isfinite(sdK1_a) && sdK_a >= 0 && sdK1_a >= 0
			sdGeoT_abl(iPair, iL) = sqrt(sdK_a * sdK1_a);
		end
		nCellsAbl(iPair, iL) = numel(ablIdxK1);
	end
	if mod(iPair, 5)==0 || iPair==nPairsT
		fprintf('  Transfer %d/%d\n', iPair, nPairsT);
	end
end

%% 6. Compute SD_geometric for Naive (normal only, no AW cells to ablate)
fprintf('\nComputing Naive features...\n');
sdGeoN_norm = nan(nPairsN, nLayers);

for iPair = 1:nPairsN
	m = SessSpeedN.Mouse(iPair);
	dtK  = SessSpeedN.DateTime(iPair);
	dtK1 = SessSpeedN.DateTimeNext(iPair);
	src  = SessSpeedN.Source(iPair);

	if src == "LAB", DS = LAB; C_ds = C_LAB; else, DS = LAI; C_ds = C_LAI; end

	[uidK,  ntatsK]  = iSessionNTATS(DS, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(DS, m, dtK1);
	cellLayer = iCellLayerLookup(C_ds, m);

	for iL = 1:nLayers
		lFilt = layerFilters{iL};
		[~, iaK]  = iLayerCells(uidK,  cellLayer, lFilt);
		[~, iaK1] = iLayerCells(uidK1, cellLayer, lFilt);

		sdK  = iInterCellSD(ntatsK,  iaK,  idx1s);
		sdK1 = iInterCellSD(ntatsK1, iaK1, idx1s);

		if isfinite(sdK) && isfinite(sdK1) && sdK >= 0 && sdK1 >= 0
			sdGeoN_norm(iPair, iL) = sqrt(sdK * sdK1);
		end
	end
	if mod(iPair, 20)==0 || iPair==nPairsN
		fprintf('  Naive %d/%d\n', iPair, nPairsN);
	end
end

%% 7. Test A: Mouse-level Spearman of SD_geometric with AW Learned features
fprintf('\n========== Test A: AW Learned 特征相关 ==========\n');
% Use mouse-level median of SD_geometric across pairs
miceT_all = unique(string(SessSpeedT.Mouse));
nMiceT = numel(miceT_all);

% AW metrics per mouse per layer: ActFrac, MeanNTATS, SD, nCells, nActive, PeakResp, MeanPost, Div
awMetricLabels = {'AW_ActFrac','AW_MeanNTATS','AW_SD','AW_nCells','AW_nActive',...
	'AW_PeakResp','AW_MeanPost','AW_Divergence'};
nAWMetrics = numel(awMetricLabels);

postMask = (xsSec >= 0) & (xsSec <= 2);

mouseSDGeo = nan(nMiceT, nLayers);
mouseAW    = nan(nMiceT, nLayers, nAWMetrics);

for iM = 1:nMiceT
	m = miceT_all(iM);
	mSafe = matlab.lang.makeValidName(char(m));
	rows = find(string(SessSpeedT.Mouse) == m);

	for iL = 1:nLayers
		mouseSDGeo(iM, iL) = median(sdGeoT_norm(rows, iL), 'omitnan');
	end

	awUID   = awStore.(mSafe).uid;
	awNTATS = awStore.(mSafe).ntats;
	cellLayer = iCellLayerLookup(C_ALB, m);

	% Trial-level for divergence
	nts_aw = iAWLearnedNTS(ALB, m);

	for iL = 1:nLayers
		lFilt = layerFilters{iL};
		[awLayerUID, awLayerIdx] = iLayerCells(awUID, cellLayer, lFilt);
		if isempty(awLayerIdx), continue; end

		base_aw = awNTATS(awLayerIdx, baseMask);
		resp_aw = double(awNTATS(awLayerIdx, idx1s));
		thresh_aw = mean(base_aw, 2, 'omitnan') + kSigma * std(base_aw, 0, 2, 'omitnan');
		activeVec = resp_aw > thresh_aw;

		mouseAW(iM, iL, 1) = mean(double(activeVec), 'omitnan');    % ActFrac
		mouseAW(iM, iL, 2) = mean(resp_aw, 'omitnan');              % MeanNTATS
		vals_aw = resp_aw(isfinite(resp_aw));
		if numel(vals_aw) >= 3, mouseAW(iM, iL, 3) = std(vals_aw); end  % SD
		mouseAW(iM, iL, 4) = numel(awLayerIdx);                     % nCells
		mouseAW(iM, iL, 5) = nnz(activeVec);                        % nActive
		postAll = awNTATS(awLayerIdx, postMask);
		meanPost = mean(postAll, 1, 'omitnan');
		mouseAW(iM, iL, 6) = max(meanPost);                         % PeakResp
		mouseAW(iM, iL, 7) = mean(meanPost, 'omitnan');             % MeanPost
		mouseAW(iM, iL, 8) = iDivergence(nts_aw, awUID, cellLayer, lFilt, idx1s); % Div
	end
end

for iL = 1:nLayers
	fprintf('\n--- Layer: %s ---\n', layerNames(iL));
	fprintf('  SD_geometric mouse-level (N=%d): median=%.3f\n', ...
		nnz(isfinite(mouseSDGeo(:,iL))), median(mouseSDGeo(:,iL), 'omitnan'));

	bestP = NaN; bestLabel = "";
	for awI = 1:nAWMetrics
		xSD = mouseSDGeo(:, iL);
		yAW = squeeze(mouseAW(:, iL, awI));
		msk = isfinite(xSD) & isfinite(yAW);
		if nnz(msk) >= 5 && std(xSD(msk))>0 && std(yAW(msk))>0
			[rho, p] = corr(xSD(msk), yAW(msk), 'Type', 'Spearman');
			sig = ""; if p<0.01, sig="**"; elseif p<0.05, sig="*"; elseif p<0.1, sig="."; end
			fprintf('  %s (N=%d): rho=%+.3f p=%.4f %s\n', awMetricLabels{awI}, nnz(msk), rho, p, sig);
			if isnan(bestP) || p < bestP, bestP = p; bestLabel = awMetricLabels{awI}; end
		end
	end
	fprintf('  Best AW predictor: %s (p=%.4f) %s\n', bestLabel, bestP, ...
		ternary(bestP < 0.05, "SIGNIFICANT", "n.s."));
end

%% 8. Test B & C: Ablation analysis
fprintf('\n========== Test B: 消融后 Partial Spearman (Transfer 内预测力) ==========\n');
for iL = 1:nLayers
	xOrig = sdGeoT_norm(:, iL);
	xAbl  = sdGeoT_abl(:, iL);

	mskO = isfinite(xOrig) & isfinite(deltaHitT) & isfinite(hitKT);
	mskA = isfinite(xAbl)  & isfinite(deltaHitT) & isfinite(hitKT);

	avgPctRem = mean(100 * (1 - nCellsAbl(:,iL) ./ nCellsOrig(:,iL)), 'omitnan');

	[rhoO, pO] = iPartialSpearman(xOrig(mskO), deltaHitT(mskO), hitKT(mskO));
	[rhoA, pA] = iPartialSpearman(xAbl(mskA),  deltaHitT(mskA),  hitKT(mskA));

	lost = pO < 0.05 && pA >= 0.05;
	fprintf('  %s (%.1f%% cells removed):\n', layerNames(iL), avgPctRem);
	fprintf('    Original: rho=%+.3f p=%.4f\n', rhoO, pO);
	fprintf('    Ablated:  rho=%+.3f p=%.4f %s\n', rhoA, pA, ternary(lost, "<= LOST", ""));
end

fprintf('\n========== Test C: 消融后 Rank-sum (Transfer vs Naive 组间差异) ==========\n');
for iL = 1:nLayers
	xT_orig = sdGeoT_norm(:, iL);
	xT_abl  = sdGeoT_abl(:, iL);
	xN      = sdGeoN_norm(:, iL);

	tO = xT_orig(isfinite(xT_orig)); nO = xN(isfinite(xN));
	tA = xT_abl(isfinite(xT_abl));

	pOrig = NaN; pAbl = NaN;
	if numel(tO) >= 3 && numel(nO) >= 3
		pOrig = ranksum(tO, nO);
	end
	if numel(tA) >= 3 && numel(nO) >= 3
		pAbl = ranksum(tA, nO);
	end

	lost = pOrig < 0.05 && pAbl >= 0.05;
	fprintf('  %s:\n', layerNames(iL));
	fprintf('    Original: T median=%.3f, N median=%.3f, RS p=%.4f\n', median(tO), median(nO), pOrig);
	fprintf('    Ablated:  T median=%.3f, RS p=%.4f %s\n', median(tA), pAbl, ternary(lost, "<= LOST", ""));
end

%% 9. Summary
fprintf('\n========== 综合结论 ==========\n');
fprintf('%-15s | Test A (AW相关) | Test B (预测力消融) | Test C (组间差异消融)\n', 'Layer');
fprintf('%s\n', repmat('-', 1, 80));

for iL = 1:nLayers
	% Test A
	bestP_A = NaN;
	for awI = 1:nAWMetrics
		xSD = mouseSDGeo(:, iL);
		yAW = squeeze(mouseAW(:, iL, awI));
		msk = isfinite(xSD) & isfinite(yAW);
		if nnz(msk) >= 5 && std(xSD(msk))>0 && std(yAW(msk))>0
			[~, p] = corr(xSD(msk), yAW(msk), 'Type', 'Spearman');
			if isnan(bestP_A) || p < bestP_A, bestP_A = p; end
		end
	end

	% Test B
	xO_B = sdGeoT_norm(:, iL); xA_B = sdGeoT_abl(:, iL);
	mO = isfinite(xO_B) & isfinite(deltaHitT) & isfinite(hitKT);
	mA = isfinite(xA_B) & isfinite(deltaHitT) & isfinite(hitKT);
	[~, pO_B] = iPartialSpearman(xO_B(mO), deltaHitT(mO), hitKT(mO));
	[~, pA_B] = iPartialSpearman(xA_B(mA), deltaHitT(mA), hitKT(mA));

	% Test C
	tO_C = sdGeoT_norm(isfinite(sdGeoT_norm(:,iL)), iL);
	tA_C = sdGeoT_abl(isfinite(sdGeoT_abl(:,iL)),   iL);
	nO_C = sdGeoN_norm(isfinite(sdGeoN_norm(:,iL)),  iL);
	pO_C = ranksum(tO_C, nO_C);
	pA_C = ranksum(tA_C, nO_C);

	passA = bestP_A < 0.05;
	passB = pO_B < 0.05 && pA_B >= 0.05;
	passC = pO_C < 0.05 && pA_C >= 0.05;

	fprintf('%-15s | p=%.3f %-4s    | %.4f->%.4f %-4s  | %.4f->%.4f %-4s\n', ...
		layerNames(iL), bestP_A, ternary(passA,"PASS","FAIL"), ...
		pO_B, pA_B, ternary(passB,"PASS","FAIL"), ...
		pO_C, pA_C, ternary(passC,"PASS","FAIL"));
end

fprintf('\nDone.\n');

%% ======== LOCAL FUNCTIONS ========

function [rho, p] = iPartialSpearman(x, y, z)
rx = tiedrank(x); ry = tiedrank(y); rz = tiedrank(z);
rx_res = rx - rz * (rz \ rx);
ry_res = ry - rz * (rz \ ry);
[rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end

function r = ternary(cond, a, b)
if cond, r = a; else, r = b; end
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

function sd = iInterCellSD(ntats, idx, idxTP)
sd = NaN; if isempty(idx), return; end
v = double(ntats(idx, idxTP)); v = v(isfinite(v));
if numel(v)<3, return; end
sd = std(v,0,1);
end

function [uid, ntats] = iAWLearnedNTATS(DS, mouse)
uid = uint64.empty(0,1); ntats = [];
G = DS.QueryNTATS(struct('Mouse',char(mouse),'Stimulus','AudioWater','Phase','Learned'), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
if isempty(G) || height(G)==0, return; end
uid = uint64(G.CellUID);
X = G.NTATS;
if isa(X, 'MATLAB.DataTypes.NDTable'), X = X.Data; end
ntats = squeeze(double(X));
end

function nts = iAWLearnedNTS(DS, mouse)
nts = table();
ntsCell = DS.QueryNTS(struct('Mouse',char(mouse),'Stimulus','AudioWater','Phase','Learned'), ...
	UniExp.Flags.ZScore, 1:24);
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
nts = ntsCell{1};
if ~istable(nts), nts = table(); end
end

function awActiveUIDs = iAWActiveCells(awUID, awNTATS, cellLayer, layerFilter, baseMask, idx, kSigma)
awActiveUIDs = uint64.empty(0,1);
if isempty(awUID) || isempty(awNTATS), return; end
[awLayerUID, awLayerIdx] = iLayerCells(awUID, cellLayer, layerFilter);
if isempty(awLayerIdx), return; end
base_aw = awNTATS(awLayerIdx, baseMask);
resp_aw = double(awNTATS(awLayerIdx, idx));
thresh = mean(base_aw, 2, 'omitnan') + kSigma * std(base_aw, 0, 2, 'omitnan');
active = resp_aw > thresh;
awActiveUIDs = awLayerUID(active);
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

%% ======== SESSION PAIRS ========
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

function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});
for iDS = 1:2
	if iDS == 1, DS = LAB; srcName = "LAB"; else, DS = LAI; srcName = "LAI"; end
	if iDS == 2, badMice = iFindBadMiceLAI(DS); else, badMice = string.empty; end
	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
	T.Phase = string(T.Phase); Tr = DS.Trials; mice = unique(T.Mouse);
	for iM = 1:numel(mice)
		m = mice(iM);
		if iDS == 2 && any(m == badMice), continue; end
		Tm = T(T.Mouse == m, :); phases = unique(Tm.Phase);
		if ~any(phases == "Naive"), continue; end
		hasLearned = any(phases == "Learned"); hasTransfer = any(phases == "Transfer");
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
		if hasLearned, idxEnd = find(sessPhase == "Learned", 1, 'last');
		elseif hasTransfer, idxEnd = find(sessPhase == "Transfer", 1, 'first') - 1;
		else, idxEnd = numel(sessDTs); end
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
			AllSess = [AllSess; table(m, dt, perf, srcName, 'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
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
T.Phase = string(T.Phase); mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM); Tm = T(T.Mouse == m, :); dts = unique(Tm.DateTime);
	for iDT = 1:numel(dts)
		ph = Tm.Phase(Tm.DateTime == dts(iDT));
		if any(ph == "Naive" | ph == "Learned")
			if iHasStimulus(DS, m, dts(iDT), "AudioWater")
				badMice = [badMice; m]; break; %#ok<AGROW>
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
	if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater"), keep(i) = false; end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
	rows = find(AllSess.Mouse == m); p = double(AllSess.Performance(rows));
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
