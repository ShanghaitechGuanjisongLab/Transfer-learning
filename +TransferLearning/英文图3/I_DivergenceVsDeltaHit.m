% 英文图3I：回合间散度 vs ΔHit（2/5层细胞合并）
%
% Data scope:
% - All pure-LightWater sessions in AudioLightBaseline (Transfer → Final).
% - Exclude sessions with hit rate ≥ 100% and all subsequent sessions.
% - One point = one adjacent session pair (session k → session k+1).
% - ΔHit = Hit(k+1) - Hit(k), where Hit = session-level LightWater hit rate.
% - Divergence = mean(Div_session_k, Div_session_k+1) — 前后session均值 (L2/3 + L5 cells merged).
%
% Style: mimic English Fig3H (scatter + fit line + Spearman annotation).

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3I_DivergenceVsDeltaHit.svg";

% --- Constants
sampleRate = 8;
idxCue = 3 * sampleRate;  % cue at 3s
idx1s  = idxCue + sampleRate;  % 1s after cue

% --- Load dataset
DS = TransferLearning.AudioLightBaseline();

CellTbl = DS.Cells;
CellTbl.ZLayer = string(CellTbl.ZLayer);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);

% --- Session table: pure LightWater, ceiling excluded, adjacent pairs
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLightWater(DS, Sess);
Sess = iExcludeCeiling(Sess);
SessPairs = iSessionPairsTable(Sess);

% --- Compute divergence for BOTH session k and session k+1, then average
nPairs = height(SessPairs);
outDivK = nan(nPairs, 1);
outDivKp1 = nan(nPairs, 1);

for i = 1:nPairs
	m = string(SessPairs.Mouse(i));
	
	% --- Session k ---
	dt_k = SessPairs.DateTime(i);
	div_k = iComputeSessionDivergence(DS, CellTbl, m, dt_k, sampleRate, idx1s);
	outDivK(i) = div_k;
	
	% --- Session k+1 ---
	dt_kp1 = SessPairs.DateTimeNext(i);
	div_kp1 = iComputeSessionDivergence(DS, CellTbl, m, dt_kp1, sampleRate, idx1s);
	outDivKp1(i) = div_kp1;
end

% --- Join with ΔHit
J = SessPairs;
J.Divergence_K = outDivK;
J.Divergence_Kp1 = outDivKp1;
J.Divergence = (outDivK + outDivKp1) / 2;  % mean of both sessions

x = double(J.Divergence);
y = double(J.DeltaHit);
z = double(J.Performance);  % Hit_K for partial correlation
mask = isfinite(x) & isfinite(y) & isfinite(z);

fprintf('\n=== Panel I: Divergence vs ΔHit (L2/3+L5 merged) ===\n');
fprintf('Valid pairs: %d\n', nnz(mask));

% --- Partial Spearman correlation (controlling for Hit_K)
rho = NaN; p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[rho, p] = iPartialSpearmanWithPerm(x(mask), y(mask), z(mask), 10000);
end
fprintf('Partial Spearman ρ=%.3f p=%.4g n=%d\n', rho, p, nnz(mask));

% --- Plot
f = figure('Color','w', 'Name', 'English Fig3I Divergence vs ΔHit');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0]; % 30mm x 40mm

ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

% Scatter: hollow circle, thin edge
scatter(ax, x(mask), y(mask), 5, [0 0.4470 0.7410], 'LineWidth', 0.2);

% Fit line (linear)
if nnz(mask) >= 2 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xFit = [min(x(mask)) max(x(mask))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', [0.85 0.325 0.098]);
end

xlabel(ax, 'Divergence');
ylabel(ax, 'ΔHit');

if isfinite(p)
	if p < 0.001
		pText = "***";
	elseif p < 0.01
		pText = "**";
	elseif p < 0.05
		pText = "*";
	else
		pText = "";
	end
	text(ax, 0.02, 0.98, sprintf('\\rho=%.2f%s', rho, pText), ...
		'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 6);
end

% --- Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

% --- Save to workspace
assignin('base', 'EnglishFig3I_Data', J);

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
	if isempty(i100)
		continue;
	end
	remove(rows(i100:end)) = true;
end
SessOut(remove,:) = [];

perf = double(SessOut.Performance);
keep = isfinite(perf) & (perf >= -1e-12) & (perf < (1 - 1e-12));
SessOut = SessOut(keep, :);
end

function SessPairs = iSessionPairsTable(Sess)
% Create table of adjacent session pairs with ΔHit = Perf(k+1) - Perf(k)
SessPairs = table(string.empty(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','DeltaHit'});
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
	nP = numel(dHit);
	newRows = table(repmat(string(m), nP, 1), dt(1:end-1), perf(1:end-1), ...
		dt(2:end), perf(2:end), dHit(:), ...
		'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','DeltaHit'});
	SessPairs = [SessPairs; newRows]; %#ok<AGROW>
end
end

function div = iDivFromX(X)
% Divergence = sqrt(totalNoise / totalSignal)
% X: cells × trials
totalSignal = sum(mean(X, 2).^2);
totalNoise  = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate)
% Build Cell × Trial × Time tensor from NTS table
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs) < 2
	return;
end

inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial, :);
if isempty(nts2)
	return;
end

uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2
	return;
end

allC = unique(uint64(nts2.CellUID));
nAllC = numel(allC);
traces = cell(nAllC, 1);
keepU = zeros(nAllC, 1, 'uint64');
nKeep = 0;

for ci = 1:nAllC
	cid = allC(ci);
	rows = (uint64(nts2.CellUID) == cid);
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

% Baseline subtract: cue at 3s
idx0 = 3 * sampleRate;
CTT = CTT - CTT(:, :, idx0);
cellUIDs = keepU;
end

function div = iComputeSessionDivergence(DS, CellTbl, m, dt, sampleRate, idx1s)
% Compute divergence for a single session (L2/3 + L5 merged)
div = NaN;

% Query trial table for this session
Ttbl = DS.TableQuery(["TrialUID","TrialIndex","Behavior","Stimulus"], Mouse=m, DateTime=dt, Stimulus="LightWater");
if isempty(Ttbl)
	return;
end
Ttbl = sortrows(Ttbl, "TrialIndex");
allUID = unique(uint64(Ttbl.TrialUID), 'stable');
if numel(allUID) < 2
	return;
end

% Get NTS for this session
ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m, 'DateTime', dt), UniExp.Flags.DeltaF, 1:24);
if iscell(ntsLW), ntsLW = ntsLW{1}; end
if isempty(ntsLW)
	return;
end

% Build CTT (Cell × Trial × Time)
[CTT, cellUIDs] = iLocalBuildCTT(ntsLW, allUID, sampleRate);
if isempty(CTT) || size(CTT, 1) < 3
	return;
end

% Layer mask: L2/3 + L5 merged
mCell = CellTbl(CellTbl.Mouse == m, :);
[~, loc] = ismember(cellUIDs, mCell.CellUID);
cLayers = strings(numel(cellUIDs), 1);
cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

maskL25 = (cLayers == "MOp2/3") | (cLayers == "MOp5");
if sum(maskL25) < 3
	return;
end

X = CTT(maskL25, :, idx1s);  % cells × trials at 1s
div = iDivFromX(X);
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
