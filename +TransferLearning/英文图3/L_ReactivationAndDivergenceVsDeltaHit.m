% English Fig3L: Reactivation and Divergence vs DeltaHit

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS = TransferLearning.AudioLightBaseline();

Sess = iLightWaterSessions(DS);
Sess = iKeepPureLightWater(DS, Sess);
Sess = iExcludeCeiling(Sess);

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig3L:BadBaseline', 'Baseline(-3~0s) has no samples.');
end
[dtMin1, idx1sReuse] = min(abs(xsSec - 1));
if isempty(idx1sReuse) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig3L:No1sSample', 'Cannot find a sample close to 1s.');
end

SessReuse = iSessionDeltaNextTable(Sess);
learnedCell = iLearnedActiveByCell(DS, baseMask, idx1sReuse);
allSessKeys = unique([SessReuse(:, {'Mouse','DateTime'}); ...
	table(SessReuse.Mouse, SessReuse.DateTimeNext, 'VariableNames', {'Mouse','DateTime'})], 'rows');
ReuseSess = iSessionReuse_SessionVsLearned_LayersMerged25(DS, allSessKeys, learnedCell, baseMask, idx1sReuse);

ReuseK = ReuseSess;
ReuseK.Properties.VariableNames{'Reuse_1s_L25_Merged'} = 'Reuse_K';
ReuseK.Properties.VariableNames{'NCellsLearnedActive_L25'} = 'NCells_K';
ReuseKp1 = ReuseSess;
ReuseKp1.Properties.VariableNames{'DateTime'} = 'DateTimeNext';
ReuseKp1.Properties.VariableNames{'Reuse_1s_L25_Merged'} = 'Reuse_Kp1';
ReuseKp1.Properties.VariableNames{'NCellsLearnedActive_L25'} = 'NCells_Kp1';

ReuseData = SessReuse(:, {'Mouse','DateTime','DateTimeNext','Performance','PerformanceNext','Speed_DeltaNext'});
ReuseData = outerjoin(ReuseData, ReuseK(:, {'Mouse','DateTime','Reuse_K','NCells_K'}), 'Keys', {'Mouse','DateTime'}, 'Type', 'left', 'MergeKeys', true);
ReuseData = outerjoin(ReuseData, ReuseKp1(:, {'Mouse','DateTimeNext','Reuse_Kp1','NCells_Kp1'}), 'Keys', {'Mouse','DateTimeNext'}, 'Type', 'left', 'MergeKeys', true);
ReuseData.Reuse_Mean = (ReuseData.Reuse_K + ReuseData.Reuse_Kp1) / 2;
ReuseData.Mouse = string(ReuseData.Mouse);
ReuseData = sortrows(ReuseData, {'Mouse', 'DateTime'});
uMice = unique(ReuseData.Mouse, 'stable');
firstPair = false(height(ReuseData), 1);
for iMouse = 1:numel(uMice)
	rows = find(ReuseData.Mouse == uMice(iMouse));
	if ~isempty(rows)
		firstPair(rows(1)) = true;
	end
end
ReuseData = ReuseData(firstPair, :);

xReuse = double(ReuseData.Reuse_Mean);
yReuse = double(ReuseData.Speed_DeltaNext);
zReuse = double(ReuseData.Performance);
maskReuse = isfinite(xReuse) & isfinite(yReuse) & isfinite(zReuse);
[rhoReuse, pReuse] = iPartialSpearmanSafe(xReuse(maskReuse), yReuse(maskReuse), zReuse(maskReuse), 10000);

sampleRate = 8;
idxCue = 3 * sampleRate;
idx1sDiv = idxCue + sampleRate;
CellTbl = DS.Cells;
CellTbl.ZLayer = string(CellTbl.ZLayer);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);

DivData = iSessionPairsTable(Sess);
outDiv = nan(height(DivData), 1);
for iPair = 1:height(DivData)
	m = string(DivData.Mouse(iPair));
	dt_k = DivData.DateTime(iPair);
	dt_kp1 = DivData.DateTimeNext(iPair);
	outDiv(iPair) = iComputePairDivergence(DS, CellTbl, m, dt_k, dt_kp1, sampleRate, idx1sDiv);
end
DivData.Divergence = outDiv;

xDiv = double(DivData.Divergence);
yDiv = double(DivData.DeltaHit);
zDiv = double(DivData.Performance);
maskDiv = isfinite(xDiv) & isfinite(yDiv) & isfinite(zDiv);
[rhoDiv, pDiv] = iPartialSpearmanSafe(xDiv(maskDiv), yDiv(maskDiv), zDiv(maskDiv), 10000);

fprintf('\n=== Fig3L Reactivation vs DeltaHit ===\n');
fprintf('Valid pairs: %d\n', nnz(maskReuse));
fprintf('Partial Spearman rho=%.3f p=%.4g\n', rhoReuse, pReuse);
fprintf('\n=== Fig3M Divergence vs DeltaHit ===\n');
fprintf('Valid pairs: %d\n', nnz(maskDiv));
fprintf('Partial Spearman rho=%.3f p=%.4g\n', rhoDiv, pDiv);

svgName = "English_Fig3L_ReactivationAndDivergenceVsDeltaHit.svg";
f = figure('Color', 'w', 'Name', 'English Fig3L Reactivation and Divergence vs DeltaHit');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 4];
f.PaperSize = [6, 4];

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
iPlotScatterPanel(ax1, xReuse(maskReuse), yReuse(maskReuse), pReuse, 'Reactivation', 'ΔHit');

ax2 = nexttile(tl, 2);
iPlotScatterPanel(ax2, xDiv(maskDiv), yDiv(maskDiv), pDiv, 'Divergence', 'ΔHit');
ax2.YAxis.Visible = 'off';

MATLAB.Graphics.UnifyAxesLims([ax1; ax2], @ylim);

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
close(f);

assignin('base', 'EnglishFig3L_Data', struct('Reactivation', ReuseData, 'Divergence', DivData));

function iPlotScatterPanel(ax, x, y, p, xLabel, yLabel)
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;
palette3 = TransferLearning.FigurePalette(3);
scatter(ax, x, y, 5, palette3(1,:), 'LineWidth', 0.2);
if numel(x) >= 2 && std(x) > 0
	pFit = polyfit(x, y, 1);
	xFit = [min(x) max(x)];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', palette3(2,:));
end
xlabel(ax, xLabel);
ylabel(ax, yLabel);
text(ax, 0.95, 0.95, iSigLabel(p), 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6, 'FontWeight', 'bold');
end

function label = iSigLabel(p)
if ~isfinite(p)
	label = 'n.s.';
elseif p < 0.001
	label = '***';
elseif p < 0.01
	label = '**';
elseif p < 0.05
	label = '*';
else
	label = 'n.s.';
end
end

function [rho, p] = iPartialSpearmanSafe(x, y, z, nPerm)
rho = NaN;
p = NaN;
if numel(x) >= 4 && std(x) > 0 && std(y) > 0
	[rho, p] = iPartialSpearmanWithPerm(x, y, z, nPerm);
end
end

function Sess = iLightWaterSessions(DS)
vars = ["Mouse","DateTime","BlockUID","Phase"];
Tblk = DS.TableQuery(vars);
if isempty(Tblk)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end

Tr = DS.Trials;
TrStim = string(Tr.Stimulus);
TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

Tblk.Mouse = string(Tblk.Mouse);
Tblk.DateTime = datetime(Tblk.DateTime);
if isdatetime(Tblk.DateTime) && ~isempty(Tblk.DateTime.TimeZone)
	Tblk.DateTime.TimeZone = '';
end

blkUID64 = uint64(Tblk.BlockUID);
[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
Tblk = Tblk(tf, :);
Tblk.LWPerf = perfByBlock.LWPerf(loc(tf));

[G2, mouse, dt] = findgroups(string(Tblk.Mouse), Tblk.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), Tblk.LWPerf, G2);
nBlocks = splitapply(@numel, Tblk.LWPerf, G2);
Sess = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLightWater(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
SessOut.Mouse = string(SessOut.Mouse);
keep = true(height(SessOut), 1);
for i = 1:height(SessOut)
	m = string(SessOut.Mouse(i));
	dt = SessOut.DateTime(i);
	Ta = DS.TableQuery("Stimulus", Mouse=m, DateTime=dt, Stimulus="AudioWater");
	if ~isempty(Ta)
		keep(i) = false;
	end
end
SessOut = SessOut(keep, :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
mice = unique(string(SessOut.Mouse));
for mi = 1:numel(mice)
	m = mice(mi);
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(isfinite(p) & p >= (1 - 1e-12), 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove,:) = [];
perf = double(SessOut.Performance);
keep = isfinite(perf) & (perf >= -1e-12) & (perf < (1 - 1e-12));
SessOut = SessOut(keep, :);
end

function SessSpeed = iSessionDeltaNextTable(Sess)
SessSpeed = table(string.empty(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
if isempty(Sess)
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(string(Sess.Mouse));
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance);
	dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	perf = perf(use);
	dt = dt(use);
	if numel(perf) < 2
		continue;
	end
	dn = diff(perf);
	newRows = table(repmat(string(m), numel(dn), 1), dt(1:end-1), perf(1:end-1), dt(2:end), perf(2:end), dn(:), 'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
	SessSpeed = [SessSpeed; newRows]; %#ok<AGROW>
	end
end

function learnedCell = iLearnedActiveByCell(DS, baseMask, idx1s)
kSigma = 3;
G = DS.QueryNTATS(struct('Stimulus', 'AudioWater', 'Phase', 'Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
	error('Fig3L:LearnedEmpty', 'QueryNTATS Learned(AudioWater) is empty.');
end
X = iNtatsData(G.NTATS);
act = iActiveAt1s(X, baseMask, idx1s, kSigma);
C = DS.Cells;
learnedCell = table(uint64(G.CellUID), logical(act), 'VariableNames', {'CellUID','LearnedActive'});
learnedCell = innerjoin(learnedCell, C(:, {'CellUID','Mouse','ZLayer'}), 'Keys', 'CellUID');
learnedCell.Mouse = string(learnedCell.Mouse);
learnedCell.ZLayer = string(learnedCell.ZLayer);
end

function Tout = iSessionReuse_SessionVsLearned_LayersMerged25(DS, SessKey, learnedCell, baseMask, idx1s)
layerKeep = ["MOp2/3", "MOp5"];
kSigma = 3;
SessKey.Mouse = string(SessKey.Mouse);
SessKey.DateTime = datetime(SessKey.DateTime);
if isdatetime(SessKey.DateTime) && ~isempty(SessKey.DateTime.TimeZone)
	SessKey.DateTime.TimeZone = '';
end
SessKey = unique(SessKey(:, {'Mouse','DateTime'}), 'rows');

outMouse = strings(0,1);
outDT = NaT(0,1);
outN = nan(0,1);
outReuse = nan(0,1);
for i = 1:height(SessKey)
	m = string(SessKey.Mouse(i));
	dt = SessKey.DateTime(i);
	ntsCell = DS.QueryNTS(struct('Mouse', m, 'DateTime', dt, 'Stimulus', 'LightWater'), UniExp.Flags.ZScore, 1:24);
	if isempty(ntsCell) || isempty(ntsCell{1})
		continue;
	end
	nts = ntsCell{1};
	if ~istable(nts) || height(nts) == 0 || ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames)))
		continue;
	end
	[uid, tranAct] = iTransferActiveFromNtsMedian(nts, baseMask, idx1s, kSigma);
	if isempty(uid)
		continue;
	end
	tranCell = table(uid, logical(tranAct), 'VariableNames', {'CellUID','TransferActive'});
	LT = innerjoin(learnedCell(:, {'CellUID','Mouse','ZLayer','LearnedActive'}), tranCell, 'Keys', 'CellUID');
	LT.Mouse = string(LT.Mouse);
	LT.ZLayer = string(LT.ZLayer);
	LT = LT(LT.Mouse == m, :);
	LT = LT(ismember(LT.ZLayer, layerKeep), :);
	if isempty(LT)
		continue;
	end
	den = logical(LT.LearnedActive);
	if nnz(den) < 1
		continue;
	end
	outMouse(end+1,1) = m; %#ok<AGROW>
	outDT(end+1,1) = dt; %#ok<AGROW>
	outN(end+1,1) = nnz(den); %#ok<AGROW>
	outReuse(end+1,1) = mean(double(LT.TransferActive(den)), 'omitnan'); %#ok<AGROW>
	end
	Tout = table(outMouse, outDT, outN, outReuse, 'VariableNames', {'Mouse','DateTime','NCellsLearnedActive_L25','Reuse_1s_L25_Merged'});
end

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable')
	X = NT.Data;
else
	X = NT;
end
X = squeeze(X);
end

function act = iActiveAt1s(X, baseMask, idx1s, kSigma)
base = X(:, baseMask);
mu = mean(base, 2, 'omitnan');
sd = std(base, 0, 2, 'omitnan');
thr = mu + kSigma .* sd;
act = X(:, idx1s) > thr;
end

function [cellUIDs, active] = iTransferActiveFromNtsMedian(nts, baseMask, idx1s, kSigma)
cellUIDs = unique(uint64(nts.CellUID));
active = false(numel(cellUIDs), 1);
for iCell = 1:numel(cellUIDs)
	cid = cellUIDs(iCell);
	rows = uint64(nts.CellUID) == cid;
	if nnz(rows) < 1
		continue;
	end
	sig = double(nts.TrialSignal(rows, :));
	if isempty(sig) || ~ismatrix(sig)
		continue;
	end
	med = median(sig, 1, 'omitnan');
	if any(~isfinite(med(baseMask)))
		continue;
	end
	mu = mean(med(baseMask), 2, 'omitnan');
	sd = std(med(baseMask), 0, 2, 'omitnan');
	v1 = med(idx1s);
	if isfinite(v1) && isfinite(mu) && isfinite(sd)
		active(iCell) = v1 > (mu + kSigma * sd);
	end
	end
end

function SessPairs = iSessionPairsTable(Sess)
SessPairs = table(string.empty(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','DeltaHit'});
if isempty(Sess)
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(string(Sess.Mouse));
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance);
	dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	perf = perf(use);
	dt = dt(use);
	if numel(perf) < 2
		continue;
	end
	dHit = diff(perf);
	newRows = table(repmat(string(m), numel(dHit), 1), dt(1:end-1), perf(1:end-1), dt(2:end), perf(2:end), dHit(:), 'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','DeltaHit'});
	SessPairs = [SessPairs; newRows]; %#ok<AGROW>
	end
end

function div = iComputePairDivergence(DS, CellTbl, m, dt_k, dt_kp1, sampleRate, idx1s)
div = NaN;
ntsK = DS.QueryNTS(struct('Stimulus', 'LightWater', 'Mouse', m, 'DateTime', dt_k), UniExp.Flags.DeltaF, 1:24);
if iscell(ntsK)
	ntsK = ntsK{1};
end
ntsKp1 = DS.QueryNTS(struct('Stimulus', 'LightWater', 'Mouse', m, 'DateTime', dt_kp1), UniExp.Flags.DeltaF, 1:24);
if iscell(ntsKp1)
	ntsKp1 = ntsKp1{1};
end
if isempty(ntsK) || isempty(ntsKp1)
	return;
end
TtblK = DS.TableQuery(["TrialUID","Stimulus"], Mouse=m, DateTime=dt_k, Stimulus="LightWater");
TtblKp1 = DS.TableQuery(["TrialUID","Stimulus"], Mouse=m, DateTime=dt_kp1, Stimulus="LightWater");
if isempty(TtblK) || isempty(TtblKp1)
	return;
end
allTrialUIDs = unique([uint64(TtblK.TrialUID); uint64(TtblKp1.TrialUID)]);
if numel(allTrialUIDs) < 3
	return;
end
ntsAll = [ntsK; ntsKp1];
[CTT, cellUIDs] = iLocalBuildCTT(ntsAll, allTrialUIDs, sampleRate);
if isempty(CTT) || size(CTT, 1) < 3
	return;
end
mCell = CellTbl(CellTbl.Mouse == m, :);
[~, loc] = ismember(cellUIDs, mCell.CellUID);
cLayers = strings(numel(cellUIDs), 1);
cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));
maskL25 = (cLayers == "MOp2/3") | (cLayers == "MOp5");
if sum(maskL25) < 3
	return;
end
X = CTT(maskL25, :, idx1s);
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
end
end

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate)
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs) < 2
	return;
end
nts2 = nts(ismember(uint64(nts.TrialUID), trialUIDs), :);
if isempty(nts2)
	return;
end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2
	return;
end
allC = unique(uint64(nts2.CellUID));
traces = cell(numel(allC), 1);
keepU = zeros(numel(allC), 1, 'uint64');
nKeep = 0;
for ci = 1:numel(allC)
	cid = allC(ci);
	rows = uint64(nts2.CellUID) == cid;
	if sum(rows) < numel(trialUIDs)
		continue;
	end
	uid = uint64(nts2.TrialUID(rows));
	sig = double(nts2.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	so = sig(loc, :);
	if any(~isfinite(so), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepU(nKeep) = cid;
	end
	if nKeep < 1
		return;
	end
	traces = traces(1:nKeep);
	keepU = keepU(1:nKeep);
	nTr = size(traces{1}, 1);
	nTi = size(traces{1}, 2);
	CTT = nan(nKeep, nTr, nTi);
	for ci = 1:nKeep
		CTT(ci, :, :) = traces{ci};
	end
	idx0 = 3 * sampleRate;
	CTT = CTT - CTT(:, :, idx0);
	cellUIDs = keepU;
end

function [rho, p] = iPartialSpearmanWithPerm(x, y, z, nPerm)
rx = tiedrank(x(:));
ry = tiedrank(y(:));
rz = tiedrank(z(:));
bx = [ones(numel(rz), 1), rz] \ rx;
res_x = rx - [ones(numel(rz), 1), rz] * bx;
by = [ones(numel(rz), 1), rz] \ ry;
res_y = ry - [ones(numel(rz), 1), rz] * by;
rho = corr(res_x, res_y);
rng(42);
nullDist = zeros(nPerm, 1);
for iPerm = 1:nPerm
	perm = randperm(numel(y));
	ry_perm = tiedrank(y(perm));
	by_perm = [ones(numel(rz), 1), rz] \ ry_perm;
	res_y_perm = ry_perm - [ones(numel(rz), 1), rz] * by_perm;
	nullDist(iPerm) = corr(res_x, res_y_perm);
	end
	p = mean(abs(nullDist) >= abs(rho));
end