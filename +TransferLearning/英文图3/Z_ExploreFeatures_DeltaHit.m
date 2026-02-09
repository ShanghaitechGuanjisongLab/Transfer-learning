% 探索：哪些特征能显著预测相邻会话对的行为增量 ΔHit？
%
% 统计单位：相邻会话对 (session k → session k+1)
% 候选特征来源：session k / k+1 的钙信号, Learned AudioWater 钙信号
%
% 候选特征（多时间点 × 多指标 × 分层/合并）：
%   Reuse rate, Corr, SD, ActiveFrac, MeanNTATS, Divergence,
%   及其 Δ（k+1 − k）版本, Hit_k 等
%
% 时间点：0.3s, 0.5s, 1.0s, 1.5s
% 层分组：合并L2/3+L5, 仅L2/3, 仅L5

DS = TransferLearning.AudioLightBaseline();

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

% --- Session pairs ---
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW(DS, Sess);
Sess = iExcludeCeiling(Sess);
SessSpeed = iSessionDeltaNext(Sess);
nPairs = height(SessSpeed);
fprintf('Session pairs: %d\n', nPairs);

% --- Learned AudioWater NTATS (per cell) ---
LearnedG = DS.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
LearnedX = iNtatsData(LearnedG.NTATS);
LearnedUID = uint64(LearnedG.CellUID);

% --- Cell info ---
C = DS.Cells;
C.CellUID = uint64(C.CellUID);
C.Mouse = string(C.Mouse);
C.ZLayer = string(C.ZLayer);

% --- Build feature name list (pre-enumerated) ---
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
% Non-timepoint features
featureNames = [featureNames, {'Hit_K'}];
for iL = 1:nLayers
	ln = char(layerNames(iL));
	featureNames = [featureNames, {['Div1s_' ln '_K'], ['Div1s_' ln '_K1'], ['DeltaDiv1s_' ln]}]; %#ok<AGROW>
end

nFeatures = numel(featureNames);
featureValues = nan(nPairs, nFeatures);

% --- Layer filter functions ---
layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};

% --- Compute features ---
fprintf('Computing %d features for %d session pairs...\n', nFeatures, nPairs);
for iPair = 1:nPairs
	m = SessSpeed.Mouse(iPair);
	dtK = SessSpeed.DateTime(iPair);
	dtK1 = SessSpeed.DateTimeNext(iPair);

	% Per-cell NTATS for session k and k+1
	[uidK, ntatsK] = iSessionNTATS(DS, m, dtK);
	[uidK1, ntatsK1] = iSessionNTATS(DS, m, dtK1);

	% Learned for this mouse
	learnedMask = ismember(LearnedUID, C.CellUID(C.Mouse == m));
	learnedMouseUID = LearnedUID(learnedMask);
	learnedMouseX = LearnedX(learnedMask, :);

	% Cell layer lookup
	cellLayer = iCellLayerLookup(C, m);

	% Trial-level data for divergence
	trialsK = iSessionTrials(DS, m, dtK);
	trialsK1 = iSessionTrials(DS, m, dtK1);

	col = 0; % column counter

	for iTP = 1:nTP
		idx = idxTP(iTP);
		if ~isfinite(idx), col = col + 16*nLayers; continue; end

		for iL = 1:nLayers
			lFilt = layerFilters{iL};

			% Common cells: k↔Learned, k+1↔Learned, k↔k+1
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
	idxDiv = idxTP(3); % 1.0s
	for iL = 1:nLayers
		lFilt = layerFilters{iL};
		divK  = iDivergence(trialsK,  uidK,  cellLayer, lFilt, idxDiv);
		divK1 = iDivergence(trialsK1, uidK1, cellLayer, lFilt, idxDiv);
		featureValues(iPair, col+1) = divK;
		featureValues(iPair, col+2) = divK1;
		featureValues(iPair, col+3) = divK1 - divK;
		col = col + 3;
	end

	fprintf('  Pair %d/%d done (%s %s)\n', iPair, nPairs, m, datestr(dtK,'yyyy-mm-dd'));
end

% --- Target ---
deltaHit = double(SessSpeed.Speed_DeltaNext);

% --- Spearman correlation sweep ---
fprintf('\n========== Spearman correlation with ΔHit (sorted by p) ==========\n');
fprintf('%-48s %5s %8s %8s\n', 'Feature', 'n', 'rho', 'p');
fprintf('%s\n', repmat('-', 1, 75));

rhoVec = nan(nFeatures,1);
pVec = nan(nFeatures,1);
nVec = nan(nFeatures,1);
for iF = 1:nFeatures
	x = featureValues(:, iF);
	y = deltaHit;
	mask = isfinite(x) & isfinite(y);
	n = nnz(mask);
	nVec(iF) = n;
	if n >= 5 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rhoVec(iF), pVec(iF)] = corr(x(mask), y(mask), 'Type', 'Spearman');
	end
end

results = table(string(featureNames)', nVec, rhoVec, pVec, ...
	'VariableNames', {'Feature','n','rho','p'});
results = sortrows(results, 'p');

nShow = min(50, height(results));
for iR = 1:nShow
	if isnan(results.p(iR)), continue; end
	sig = "";
	if results.p(iR) < 0.001,     sig = "***";
	elseif results.p(iR) < 0.01,  sig = "**";
	elseif results.p(iR) < 0.05,  sig = "*";
	elseif results.p(iR) < 0.1,   sig = ".";
	end
	fprintf('%-48s %5d %+8.3f %8.4f %s\n', results.Feature(iR), results.n(iR), results.rho(iR), results.p(iR), sig);
end

% --- Also do partial Spearman controlling for Hit_K ---
fprintf('\n========== Partial Spearman (control Hit_K) ==========\n');
fprintf('%-48s %5s %8s %8s\n', 'Feature', 'n', 'rho_p', 'p');
fprintf('%s\n', repmat('-', 1, 75));

hitK_col = find(strcmp(featureNames, 'Hit_K'));
hitK_vals = featureValues(:, hitK_col);

rhoP = nan(nFeatures,1); pP = nan(nFeatures,1); nP = nan(nFeatures,1);
for iF = 1:nFeatures
	if iF == hitK_col, continue; end
	x = featureValues(:, iF);
	y = deltaHit;
	z = hitK_vals;
	mask = isfinite(x) & isfinite(y) & isfinite(z);
	n = nnz(mask);
	nP(iF) = n;
	if n >= 7 && std(x(mask))>0 && std(y(mask))>0 && std(z(mask))>0
		[rhoP(iF), pP(iF)] = iPartialSpearman(x(mask), y(mask), z(mask));
	end
end

resultsP = table(string(featureNames)', nP, rhoP, pP, ...
	'VariableNames', {'Feature','n','rho_partial','p_partial'});
resultsP = sortrows(resultsP, 'p_partial');

for iR = 1:min(50, height(resultsP))
	if isnan(resultsP.p_partial(iR)), continue; end
	sig = "";
	if resultsP.p_partial(iR) < 0.001,     sig = "***";
	elseif resultsP.p_partial(iR) < 0.01,  sig = "**";
	elseif resultsP.p_partial(iR) < 0.05,  sig = "*";
	elseif resultsP.p_partial(iR) < 0.1,   sig = ".";
	end
	fprintf('%-48s %5d %+8.3f %8.4f %s\n', resultsP.Feature(iR), resultsP.n(iR), resultsP.rho_partial(iR), resultsP.p_partial(iR), sig);
end

assignin('base', 'ExploreFeatures_Results', results);
assignin('base', 'ExploreFeatures_Partial', resultsP);
assignin('base', 'ExploreFeatures_Values', featureValues);
assignin('base', 'ExploreFeatures_DeltaHit', deltaHit);
fprintf('\nDone. Saved to workspace: ExploreFeatures_Results, ExploreFeatures_Partial\n');

%% ======== LOCAL FUNCTIONS ========

function [rho, p] = iPartialSpearman(x, y, z)
% Partial Spearman: rank-transform, regress out z, Pearson on residuals
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

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable'), X = NT.Data; else, X = NT; end
X = squeeze(X);
end

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
