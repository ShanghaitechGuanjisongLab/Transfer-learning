% 英文图3D：Corr(LW session, Learned AW)@1.5s vs ΔHit，分2/3层和5层
%
% Data scope (same session pairs as Fig3B):
% - All pure-LightWater sessions in AudioLightBaseline (Transfer → Final).
% - Exclude sessions with hit rate ≥ 100% and all subsequent sessions.
% - One point = one adjacent session pair (session k → session k+1).
% - ΔHit = Hit(k+1) − Hit(k).
% - x = Pearson corr of cell activity vectors @1.5s between session k+1 (LightWater)
%   and the Learned AudioWater phase, computed per layer (MOp2/3, MOp5).
%   Cell activity = median across trials of ZScore signal at 1.5s timepoint.
%   (Uses the LATER session in each adjacent pair.)
%
% Layout: tiledlayout(1,2) — left MOp2/3, right MOp5 (ref Fig3.4D).

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3D_CorrToLearned1p5sVsDeltaHit_ByLayer.svg";

% --- Preconditions
if ~exist('UniExp.DataSet', 'class')
	error('EnglishFig3D:MissingUniExp', 'UniExp is not on path; load the project first.');
end

DS = TransferLearning.AudioLightBaseline();

% --- Time axis, baseline, 1.5s index
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('EnglishFig3D:BadBaseline', 'Baseline(-3~0s) has no samples.');
end

[dtMin, idxT] = min(abs(xsSec - 1.5));
if isempty(idxT) || ~isfinite(dtMin) || dtMin > 0.25
	error('EnglishFig3D:NoSample', 'Cannot find a sample close to 1.5s.');
end

% --- Session table: pure LightWater, ceiling excluded, adjacent pairs
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLightWater(DS, Sess);
Sess = iExcludeCeiling(Sess);
SessSpeed = iSessionDeltaNextTable(Sess);

% --- Learned AudioWater: cell activity vector @1.5s (with layer info)
learnedVec = iLearnedVecAt1p5s(DS, idxT);

% --- Per-session correlation with Learned, split by layer (compute for session k+1)
NextSessKeys = SessSpeed(:, {'Mouse','DateTimeNext'});
NextSessKeys.Properties.VariableNames{'DateTimeNext'} = 'DateTime';
CorrSess = iSessionCorrToLearned_ByLayer(DS, NextSessKeys, learnedVec, baseMask, idxT);

% Join: CorrSess.DateTime matches SessSpeed.DateTimeNext
CorrSess.Properties.VariableNames{'DateTime'} = 'DateTimeNext';
J = innerjoin(CorrSess, SessSpeed(:, {'Mouse','DateTimeNext','DateTime','Performance','PerformanceNext','Speed_DeltaNext'}), 'Keys', {'Mouse','DateTimeNext'});
assignin('base', 'EnglishFig3D_Joined', J);

% --- Plot: tiledlayout 1×2
f = figure('Color','w', 'Name', 'English Fig3D Corr(session,Learned)@1.5s vs ΔHit by layer');
f.Units = 'centimeters';
f.Position(3:4) = [6.0, 4.0]; % 60mm × 40mm

tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');
axs = gobjects(1,2);

zLabels = ["MOp2/3","MOp5"];
corrVars = ["Corr_1p5s_MOp23","Corr_1p5s_MOp5"];

for iZ = 1:2
	ax = nexttile(tl, iZ);
	axs(iZ) = ax;
	hold(ax, 'on');
	box(ax, 'off');
	grid(ax, 'off');
	ax.FontSize = 6;

	x = double(J.(corrVars(iZ)));
	y = double(J.Speed_DeltaNext);
	mask = isfinite(x) & isfinite(y);

	% Scatter
	scatter(ax, x(mask), y(mask), 15, [0 0.4470 0.7410], 'LineWidth', 0.2);

	% Fit line
	if nnz(mask) >= 2 && std(x(mask)) > 0
		pFit = polyfit(x(mask), y(mask), 1);
		xFit = [min(x(mask)) max(x(mask))];
		yFit = polyval(pFit, xFit);
		plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', [0.85 0.325 0.098]);
	end

	% Spearman
	rho = NaN; p = NaN;
	if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rho, p] = corr(x(mask), y(mask), 'Type', 'Spearman');
	end

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
		text(ax, 0.02, 0.98, sprintf('r=%.2f%s n=%d', rho, pText, nnz(mask)), ...
			'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 6);
	end

	title(ax, zLabels(iZ), 'FontSize', 6);
end

xlabel(tl, 'Corr(session, Learned AW) @1.5s');
ylabel(tl, '\DeltaHit');

% Unify Y axes
try
	MATLAB.Graphics.UnifyAxesLims(axs, 'y');
catch
	yl = cell2mat(arrayfun(@(a) ylim(a), axs, 'UniformOutput', false)');
	ylAll = [min(yl(:,1)) max(yl(:,2))];
	for k = 1:2, ylim(axs(k), ylAll); end
end

% Hide right-panel Y tick labels
axs(2).YTickLabel = [];

% --- Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ---- local helpers

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
% Exclude sessions that also contain AudioWater blocks.
% StartMonitor/StopMonitor are monitoring markers, not behavioral stimuli; keep those.
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

function learnedVec = iLearnedVecAt1p5s(DS, idxT)
% Get per-cell NTATS value @1.5s for Learned AudioWater, with layer info.
G = DS.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
	error('EnglishFig3D:LearnedEmpty', 'QueryNTATS Learned(AudioWater) is empty.');
end
X = iNtatsData(G.NTATS);
v = double(X(:, idxT));
C = DS.Cells;
learnedVec = table(uint64(G.CellUID), v, 'VariableNames', {'CellUID','LearnedVal'});
learnedVec = innerjoin(learnedVec, C(:, {'CellUID','Mouse','ZLayer'}), 'Keys', 'CellUID');
learnedVec.Mouse = string(learnedVec.Mouse);
learnedVec.ZLayer = string(learnedVec.ZLayer);
end

function Tout = iSessionCorrToLearned_ByLayer(DS, SessKey, learnedVec, baseMask, idxT)
% One row per session: Pearson corr of cell vectors @1.5s vs Learned, per layer.
% Uses NTS (trial-level): median across trials for per-cell value.
minCells = 5;

SessKey.Mouse = string(SessKey.Mouse);
SessKey.DateTime = datetime(SessKey.DateTime);
if isdatetime(SessKey.DateTime) && ~isempty(SessKey.DateTime.TimeZone)
	SessKey.DateTime.TimeZone = '';
end
SessKey = unique(SessKey(:, {'Mouse','DateTime'}), 'rows');

outMouse = strings(0,1);
outDT = NaT(0,1);
outCorr23 = nan(0,1);
outCorr5 = nan(0,1);
outN23 = nan(0,1);
outN5 = nan(0,1);

for i = 1:height(SessKey)
	m = string(SessKey.Mouse(i));
	dt = SessKey.DateTime(i);

	q = struct('Mouse', m, 'DateTime', dt, 'Stimulus', 'LightWater');
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
	if isempty(ntsCell) || isempty(ntsCell{1})
		continue;
	end
	nts = ntsCell{1};
	if ~istable(nts) || height(nts) == 0 || ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames)))
		continue;
	end

	% Per-cell median signal, take value at idxT
	[uid, sessVal] = iSessionVecFromNtsMedian(nts, idxT);
	if isempty(uid)
		continue;
	end
	sessCell = table(uid, sessVal, 'VariableNames', {'CellUID','SessVal'});

	% Join with learnedVec (common cells)
	LJ = innerjoin(learnedVec(learnedVec.Mouse == m, :), sessCell, 'Keys', 'CellUID');
	if isempty(LJ)
		continue;
	end

	% MOp2/3
	L23 = LJ(LJ.ZLayer == "MOp2/3", :);
	use23 = isfinite(L23.LearnedVal) & isfinite(L23.SessVal);
	r23 = NaN; n23 = nnz(use23);
	if n23 >= minCells && std(L23.LearnedVal(use23)) > 0 && std(L23.SessVal(use23)) > 0
		r23 = corr(L23.LearnedVal(use23), L23.SessVal(use23), 'Type', 'Pearson');
	end

	% MOp5
	L5 = LJ(LJ.ZLayer == "MOp5", :);
	use5 = isfinite(L5.LearnedVal) & isfinite(L5.SessVal);
	r5 = NaN; n5 = nnz(use5);
	if n5 >= minCells && std(L5.LearnedVal(use5)) > 0 && std(L5.SessVal(use5)) > 0
		r5 = corr(L5.LearnedVal(use5), L5.SessVal(use5), 'Type', 'Pearson');
	end

	if ~isfinite(r23) && ~isfinite(r5)
		continue;
	end

	outMouse(end+1,1) = m; %#ok<AGROW>
	outDT(end+1,1) = dt; %#ok<AGROW>
	outCorr23(end+1,1) = r23; %#ok<AGROW>
	outCorr5(end+1,1) = r5; %#ok<AGROW>
	outN23(end+1,1) = n23; %#ok<AGROW>
	outN5(end+1,1) = n5; %#ok<AGROW>
end

Tout = table(outMouse, outDT, outN23, outCorr23, outN5, outCorr5, ...
	'VariableNames', {'Mouse','DateTime','NCells_MOp23','Corr_1p5s_MOp23','NCells_MOp5','Corr_1p5s_MOp5'});
end

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable')
	X = NT.Data;
else
	X = NT;
end
X = squeeze(X);
end

function [cellUIDs, vals] = iSessionVecFromNtsMedian(nts, idxT)
% Per-cell value @idxT from trial-level signals, median across trials.
cellUIDs = unique(uint64(nts.CellUID));
vals = nan(numel(cellUIDs), 1);

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
	if size(med, 2) >= idxT
		vals(iC) = med(idxT);
	end
end
end
