% 英文图3J：1s复用率 vs 命中率增量（2/5层细胞合并）
%
% Data scope (ref: Fig3.4D):
% - All pure-LightWater sessions in AudioLightBaseline (Transfer → Final).
% - Exclude sessions with hit rate ≥ 100% and all subsequent sessions.
% - One point = one adjacent session pair (session k → session k+1).
% - ΔHit = Hit(k+1) - Hit(k), where Hit = session-level LightWater hit rate.
% - Reuse rate = mean(Reuse_session_k, Reuse_session_k+1) — 前后session均值.
%   Reuse = P(TransferActive@1s | LearnedActive@1s).
%   LearnedActive pooled from Learned(AudioWater), TransferActive computed per LightWater session.
% - Cells merged across layers: MOp2/3 + MOp5 (cell-level merge, not averaging two probabilities).
%
% Style: mimic English Fig1J (scatter + fit line + Spearman annotation).

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

% --- Preconditions
if ~exist('UniExp.DataSet', 'class')
	error('EnglishFig3A:MissingUniExp', 'UniExp is not on path; load the project first.');
end

DS = TransferLearning.AudioLightBaseline();

% --- Time axis, baseline, 1s index
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('EnglishFig3A:BadBaseline', 'Baseline(-3~0s) has no samples.');
end

[dtMin1, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('EnglishFig3A:No1sSample', 'Cannot find a sample close to 1s.');
end

% --- Session table: pure LightWater (Transfer→Final), ceiling excluded, adjacent pairs
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLightWater(DS, Sess);
Sess = iExcludeCeiling(Sess);
SessSpeed = iSessionDeltaNextTable(Sess);

% --- Learned active (pooled) by cell
learnedCell = iLearnedActiveByCell(DS, baseMask, idx1s);

% --- Collect ALL unique sessions (both k and k+1) for reuse calculation
allSessKeys = unique([SessSpeed(:, {'Mouse','DateTime'}); ...
	table(SessSpeed.Mouse, SessSpeed.DateTimeNext, 'VariableNames', {'Mouse','DateTime'})], 'rows');

% --- Per-session reuse rate (2/5 layer cells merged)
ReuseSess = iSessionReuse_SessionVsLearned_LayersMerged25(DS, allSessKeys, learnedCell, baseMask, idx1s);

% --- Join to get reuse for session k and session k+1, then average
ReuseK = ReuseSess;
ReuseK.Properties.VariableNames{'Reuse_1s_L25_Merged'} = 'Reuse_K';
ReuseK.Properties.VariableNames{'NCellsLearnedActive_L25'} = 'NCells_K';

ReuseKp1 = ReuseSess;
ReuseKp1.Properties.VariableNames{'DateTime'} = 'DateTimeNext';
ReuseKp1.Properties.VariableNames{'Reuse_1s_L25_Merged'} = 'Reuse_Kp1';
ReuseKp1.Properties.VariableNames{'NCellsLearnedActive_L25'} = 'NCells_Kp1';

J = SessSpeed(:, {'Mouse','DateTime','DateTimeNext','Performance','PerformanceNext','Speed_DeltaNext'});
J = outerjoin(J, ReuseK(:, {'Mouse','DateTime','Reuse_K','NCells_K'}), 'Keys', {'Mouse','DateTime'}, 'Type', 'left', 'MergeKeys', true);
J = outerjoin(J, ReuseKp1(:, {'Mouse','DateTimeNext','Reuse_Kp1','NCells_Kp1'}), 'Keys', {'Mouse','DateTimeNext'}, 'Type', 'left', 'MergeKeys', true);

% Average reuse rate of session k and k+1
J.Reuse_Mean = (J.Reuse_K + J.Reuse_Kp1) / 2;
assignin('base', 'EnglishFig3J_Joined', J);

x = double(J.Reuse_Mean);
y = double(J.Speed_DeltaNext);
z = double(J.Performance);  % Hit_K for partial correlation
mask = isfinite(x) & isfinite(y) & isfinite(z);

fprintf('\n=== Panel J: Reuse vs ΔHit (mean of k and k+1) ===\n');
fprintf('Valid pairs: %d\n', nnz(mask));

% --- Plot
svgName = "English_Fig3J_ReactivationVsDeltaHit.svg";
f = figure('Color','w', 'Name', 'English Fig3J Reuse vs ΔHit');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0]; % 30mm x 40mm

ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

% Partial Spearman correlation (controlling for Hit_K)
rho = NaN; p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[rho, p] = iPartialSpearmanWithPerm(x(mask), y(mask), z(mask), 10000);
end

% Scatter: hollow circle, thin edge
scatter(ax, x(mask), y(mask), 5, [0 0.4470 0.7410], 'LineWidth', 0.2);

% Fit line (linear)
if nnz(mask) >= 2 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xFit = [min(x(mask)) max(x(mask))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', [0.85 0.325 0.098]);
end

xlabel(ax, 'Reactivation');
ylabel(ax, 'ΔHit');

if isfinite(p)
	text(ax, 0.95, 0.95, sprintf('p=%.2g', p), ...
		'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','top', 'FontSize', 6);
end

% --- Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ---- local helpers (no try-catch)

function Sess = iLightWaterSessions(DS)
vars = ["Mouse","DateTime","BlockUID","Phase"];
Tblk = DS.TableQuery(vars);
if isempty(Tblk)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end

if ~isprop(DS, 'Trials')
	error('EnglishFig3A:MissingTrials', 'DataSet has no Trials table.');
end
Tr = DS.Trials;
need = {'BlockUID','Stimulus','Behavior'};
if ~all(ismember(need, Tr.Properties.VariableNames))
	error('EnglishFig3A:TrialsMissingFields', 'Trials table lacks required fields.');
end

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

% sessionize by Mouse×DateTime
[G2, mouse, dt] = findgroups(string(Tblk.Mouse), Tblk.DateTime);
perf = splitapply(@(x) mean(double(x),'omitnan'), Tblk.LWPerf, G2);
nBlocks = splitapply(@numel, Tblk.LWPerf, G2);
Sess = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLightWater(DS, SessIn)
% Exclude sessions that also contain AudioWater blocks (mixed Transfer sessions).
% Note: StartMonitor/StopMonitor are monitoring markers, not behavioral stimuli; keep those.
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
% Remove sessions where Performance >= 100% and all subsequent sessions per mouse.
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
	if isempty(i100)
		continue;
	end
	remove(rows(i100:end)) = true;
end
SessOut(remove,:) = [];

% Safety: enforce 0<=Perf<1
perf = double(SessOut.Performance);
keep = isfinite(perf) & (perf >= -1e-12) & (perf < (1 - 1e-12));
SessOut = SessOut(keep, :);
end

function SessSpeed = iSessionDeltaNextTable(Sess)
SessSpeed = table(string.empty(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
if isempty(Sess)
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);

mice = unique(string(Sess.Mouse));
outMouse = strings(0,1);
outDT = NaT(0,1);
outPerf = nan(0,1);
outDT2 = NaT(0,1);
outPerf2 = nan(0,1);
outDN = nan(0,1);

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
	outMouse = [outMouse; repmat(string(m), numel(dn), 1)]; %#ok<AGROW>
	outDT = [outDT; dt(1:end-1)]; %#ok<AGROW>
	outPerf = [outPerf; perf(1:end-1)]; %#ok<AGROW>
	outDT2 = [outDT2; dt(2:end)]; %#ok<AGROW>
	outPerf2 = [outPerf2; perf(2:end)]; %#ok<AGROW>
	outDN = [outDN; dn(:)]; %#ok<AGROW>
end

SessSpeed = table(outMouse, outDT, outPerf, outDT2, outPerf2, outDN, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end

function learnedCell = iLearnedActiveByCell(DS, baseMask, idx1s)
kSigma = 3;
G = DS.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
	error('EnglishFig3A:LearnedEmpty', 'QueryNTATS Learned(AudioWater) is empty.');
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
% One row per session: reuse rate merged across L2/3+L5 cells.
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

	% Use NTS (trial-level) to avoid QueryNTATS empty-group errors for some sessions.
	q = struct('Mouse', m, 'DateTime', dt, 'Stimulus', 'LightWater');
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
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
	reuse = mean(double(LT.TransferActive(den)), 'omitnan');

	outMouse(end+1,1) = m; %#ok<AGROW>
	outDT(end+1,1) = dt; %#ok<AGROW>
	outN(end+1,1) = nnz(den); %#ok<AGROW>
	outReuse(end+1,1) = reuse; %#ok<AGROW>
end

Tout = table(outMouse, outDT, outN, outReuse, ...
	'VariableNames', {'Mouse','DateTime','NCellsLearnedActive_L25','Reuse_1s_L25_Merged'});
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
v = X(:, idx1s);
act = v > thr;
end

function [cellUIDs, active] = iTransferActiveFromNtsMedian(nts, baseMask, idx1s, kSigma)
% Compute per-cell active@1s from trial-level signals by taking the median across trials.
% nts table must contain: CellUID, TrialSignal (nTrial x nTime)
cellUIDs = unique(uint64(nts.CellUID));
active = false(numel(cellUIDs), 1);

for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	rows = (uint64(nts.CellUID) == cid);
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
		active(iC) = (v1 > (mu + kSigma * sd));
	end
end
end

function [rho, p] = iPartialSpearmanWithPerm(x, y, z, nPerm)
% Partial Spearman correlation controlling for z, with permutation test
% rho: partial Spearman coefficient
% p: two-tailed permutation p-value

rx = tiedrank(x(:));
ry = tiedrank(y(:));
rz = tiedrank(z(:));

% Residuals of rx ~ rz
bx = [ones(numel(rz),1), rz] \ rx;
res_x = rx - [ones(numel(rz),1), rz] * bx;

% Residuals of ry ~ rz
by = [ones(numel(rz),1), rz] \ ry;
res_y = ry - [ones(numel(rz),1), rz] * by;

% Observed partial correlation
rho = corr(res_x, res_y);

% Permutation test
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
