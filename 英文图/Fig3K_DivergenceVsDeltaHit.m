% 英文图3K：Reactivation vs ΔHit（2/5层细胞合并，所有会话对）
%
% Data scope:
% - All pure-LightWater sessions in AudioLightBaseline (Transfer → Final).
% - Exclude sessions with hit rate ≥ 100% and all subsequent sessions.
% - One point = one adjacent session pair (session k → session k+1).
% - ΔHit = Hit(k+1) - Hit(k), where Hit = session-level LightWater hit rate.
% - Reactivation = mean(Reuse_k, Reuse_k+1) — 前后session均值.
%   Reuse = P(TransferActive@1s | LearnedActive@1s), L2/3+L5 cells merged.
%
% Style: scatter + fit line + partial Spearman annotation.

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

% --- Load dataset
DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx1s] = min(abs(xsSec - 1));

% --- Session table: pure LightWater, ceiling excluded, adjacent pairs
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLightWater(DS, Sess);
Sess = iExcludeCeiling(Sess);
SessPairs = iSessionPairsTable(Sess);

% --- Learned active (pooled from Learned-phase AudioWater)
learnedCell = iLearnedActiveByCell(DS, baseMask, idx1s);

% --- Collect ALL unique sessions needed for reuse calculation
allSessKeys = unique([SessPairs(:, {'Mouse','DateTime'}); ...
	table(SessPairs.Mouse, SessPairs.DateTimeNext, 'VariableNames', {'Mouse','DateTime'})], 'rows');

% --- Per-session reuse rate (L2/3+L5 merged)
ReuseSess = iSessionReuse_LayersMerged25(DS, allSessKeys, learnedCell, baseMask, idx1s);

% --- Join reuse to session pairs
ReuseK = ReuseSess;
ReuseK.Properties.VariableNames{'Reuse'} = 'Reuse_K';
ReuseKp1 = ReuseSess;
ReuseKp1.Properties.VariableNames{'DateTime'} = 'DateTimeNext';
ReuseKp1.Properties.VariableNames{'Reuse'} = 'Reuse_Kp1';

K = SessPairs(:, {'Mouse','DateTime','DateTimeNext','Performance','PerformanceNext','DeltaHit'});
K = outerjoin(K, ReuseK(:, {'Mouse','DateTime','Reuse_K'}), 'Keys', {'Mouse','DateTime'}, 'Type', 'left', 'MergeKeys', true);
K = outerjoin(K, ReuseKp1(:, {'Mouse','DateTimeNext','Reuse_Kp1'}), 'Keys', {'Mouse','DateTimeNext'}, 'Type', 'left', 'MergeKeys', true);
K.Reactivation = (K.Reuse_K + K.Reuse_Kp1) / 2;

x = double(K.Reactivation);
y = double(K.DeltaHit);
z = double(K.Performance);  % Hit_K for partial correlation
mask = isfinite(x) & isfinite(y) & isfinite(z);

fprintf('\n=== Panel K: Reactivation vs ΔHit (all session pairs) ===\n');
fprintf('Valid pairs: %d\n', nnz(mask));

% --- Partial Spearman correlation (controlling for Hit_K)
rho = NaN; p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[rho, p] = iPartialSpearmanWithPerm(x(mask), y(mask), z(mask), 10000);
end
fprintf('Partial Spearman ρ=%.3f p=%.4g n=%d\n', rho, p, nnz(mask));

% --- Plot
svgName = "English_Fig3K_ReactivationVsDeltaHit.svg";
f = figure('Color','w', 'Name', 'English Fig3K Reactivation vs ΔHit');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

palette2 = TransferLearning.FigurePalette(2);
scatter(ax, x(mask), y(mask), 5, palette2(2,:), 'LineWidth', 0.2);

if nnz(mask) >= 2 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xFit = [min(x(mask)) max(x(mask))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', palette2(1,:));
end

xlabel(ax, 'Reactivation');
ylabel(ax, '\DeltaHit');

if isfinite(p)
	if p < 0.001
		sigLabel = '***';
	elseif p < 0.01
		sigLabel = '**';
	elseif p < 0.05
		sigLabel = '*';
	else
		sigLabel = 'n.s.';
	end
	text(ax, 0.95, 0.95, sigLabel, ...
		'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','top', 'FontSize', 8, 'FontWeight', 'bold');
end

% --- Export SVG
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'EnglishFig3K_Data', K);

%% ===== Local Functions =====

function Sess = iLightWaterSessions(DS)
vars = ["Mouse","DateTime","BlockUID","Phase"];
Tblk = DS.TableQuery(vars);
if isempty(Tblk)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end

Tr = DS.Trials;
TrStim = string(Tr.Stimulus);
TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
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
perf = splitapply(@(x) mean(double(x),'omitnan'), Tblk.LWPerf, G2);
nBlocks = splitapply(@numel, Tblk.LWPerf, G2);
Sess = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLightWater(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
keep = true(height(SessOut), 1);
for i = 1:height(SessOut)
	m = string(SessOut.Mouse(i));
	dt = SessOut.DateTime(i);
	Ta = DS.TableQuery("Stimulus", Mouse=m, DateTime=dt, Stimulus="AudioWater");
	if ~isempty(Ta), keep(i) = false; end
end
SessOut = SessOut(keep, :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
mice = unique(string(SessOut.Mouse));
for mi = 1:numel(mice)
	m = mice(mi);
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(isfinite(p) & p >= (1 - 1e-12), 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
SessOut(remove,:) = [];
perf = double(SessOut.Performance);
keep = isfinite(perf) & (perf >= -1e-12) & (perf < (1 - 1e-12));
SessOut = SessOut(keep, :);
end

function SessPairs = iSessionPairsTable(Sess)
SessPairs = table(string.empty(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','DeltaHit'});
if isempty(Sess), return; end
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(string(Sess.Mouse));
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance);
	dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	perf = perf(use); dt = dt(use);
	if numel(perf) < 2, continue; end
	dHit = diff(perf);
	nP = numel(dHit);
	newRows = table(repmat(string(m), nP, 1), dt(1:end-1), perf(1:end-1), ...
		dt(2:end), perf(2:end), dHit(:), ...
		'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','DeltaHit'});
	SessPairs = [SessPairs; newRows]; %#ok<AGROW>
end
end

function learnedCell = iLearnedActiveByCell(DS, baseMask, idx1s)
kSigma = 3;
G = DS.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
X = iNtatsData(G.NTATS);
act = iActiveAt1s(X, baseMask, idx1s, kSigma);
C = DS.Cells;
learnedCell = table(uint64(G.CellUID), logical(act), 'VariableNames', {'CellUID','LearnedActive'});
learnedCell = innerjoin(learnedCell, C(:, {'CellUID','Mouse','ZLayer'}), 'Keys', 'CellUID');
learnedCell.Mouse = string(learnedCell.Mouse);
learnedCell.ZLayer = string(learnedCell.ZLayer);
end

function Tout = iSessionReuse_LayersMerged25(DS, SessKey, learnedCell, baseMask, idx1s)
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
outReuse = nan(0,1);

for i = 1:height(SessKey)
	m = string(SessKey.Mouse(i));
	dt = SessKey.DateTime(i);

	q = struct('Mouse', m, 'DateTime', dt, 'Stimulus', 'LightWater');
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
	if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
	nts = ntsCell{1};

	[uid, tranAct] = iTransferActiveFromNtsMedian(nts, baseMask, idx1s, kSigma);
	if isempty(uid), continue; end
	tranCell = table(uid, logical(tranAct), 'VariableNames', {'CellUID','TransferActive'});

	LT = innerjoin(learnedCell(:, {'CellUID','Mouse','ZLayer','LearnedActive'}), tranCell, 'Keys', 'CellUID');
	LT.Mouse = string(LT.Mouse);
	LT.ZLayer = string(LT.ZLayer);
	LT = LT(LT.Mouse == m, :);
	LT = LT(ismember(LT.ZLayer, layerKeep), :);
	if isempty(LT), continue; end

	den = logical(LT.LearnedActive);
	if nnz(den) < 1, continue; end
	reuse = mean(double(LT.TransferActive(den)), 'omitnan');

	outMouse(end+1,1) = m; %#ok<AGROW>
	outDT(end+1,1) = dt; %#ok<AGROW>
	outReuse(end+1,1) = reuse; %#ok<AGROW>
end

Tout = table(outMouse, outDT, outReuse, 'VariableNames', {'Mouse','DateTime','Reuse'});
end

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable'), X = NT.Data; else, X = NT; end
X = squeeze(X);
end

function act = iActiveAt1s(X, baseMask, idx1s, kSigma)
base = X(:, baseMask);
mu = mean(base, 2, 'omitnan');
sd = std(base, 0, 2, 'omitnan');
thr = mu + kSigma .* sd;
v = X(:, idx1s);
act = v > thr;
end

function [cellUIDs, active] = iTransferActiveFromNtsMedian(nts, baseMask, idx1s, kSigma)
cellUIDs = unique(uint64(nts.CellUID));
active = false(numel(cellUIDs), 1);
for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	rows = (uint64(nts.CellUID) == cid);
	if nnz(rows) < 1, continue; end
	sig = double(nts.TrialSignal(rows, :));
	if isempty(sig) || ~ismatrix(sig), continue; end
	med = median(sig, 1, 'omitnan');
	if any(~isfinite(med(baseMask))), continue; end
	mu = mean(med(baseMask), 2, 'omitnan');
	sd = std(med(baseMask), 0, 2, 'omitnan');
	v1 = med(idx1s);
	if isfinite(v1) && isfinite(mu) && isfinite(sd)
		active(iC) = (v1 > (mu + kSigma * sd));
	end
end
end

function [rho, p] = iPartialSpearmanWithPerm(x, y, z, nPerm)
rx = tiedrank(x(:));
ry = tiedrank(y(:));
rz = tiedrank(z(:));
bx = [ones(numel(rz),1), rz] \ rx;
res_x = rx - [ones(numel(rz),1), rz] * bx;
by = [ones(numel(rz),1), rz] \ ry;
res_y = ry - [ones(numel(rz),1), rz] * by;
rho = corr(res_x, res_y);
rng(42);
nullDist = zeros(nPerm, 1);
for iPerm = 1:nPerm
	perm = randperm(numel(y));
	ry_perm = tiedrank(y(perm));
	by_perm = [ones(numel(rz),1), rz] \ ry_perm;
	res_y_perm = ry_perm - [ones(numel(rz),1), rz] * by_perm;
	nullDist(iPerm) = corr(res_x, res_y_perm);
end
p = mean(abs(nullDist) >= abs(rho));
end
