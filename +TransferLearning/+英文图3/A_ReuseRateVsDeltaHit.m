% 英文图3A：1s复用率 vs 命中率增量（2/5层细胞合并）
%
% Data definition follows Fig3.4A (TransferLearning.Fig34.A_ReuseAndCellCorrCannotPredictLearningSpeed):
% - One point = one LightWater session (Mouse×DateTime)
% - Hit-rate increment (ΔHit) = Performance(next session) - Performance(current session)
%   where Performance is LightWater-only hit rate averaged within a session.
% - Reuse rate at 1s = P(TransferActive@1s | LearnedActive@1s)
%   LearnedActive pooled from Learned(AudioWater), TransferActive computed per LightWater session.
% - Cells merged across layers: MOp2/3 + MOp5 (cell-level merge, not averaging two probabilities).
%
% Style: mimic English Fig1J (scatter + fit line + Spearman annotation).
%
% Execution (dot syntax, MATLAB command window):
%   TransferLearning.英文图3.A_ReuseRateVsDeltaHit

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3A_ReuseRateVsDeltaHit.svg";

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

% --- Session table: LightWater-only performance per session, then forward difference ΔHit
Sess = iLightWaterSessions(DS);
Sess = iFilterSessions_Keep0ExcludeCeiling(Sess);
SessSpeed = iSessionDeltaNextTable(Sess);

% --- Learned active (pooled) by cell
learnedCell = iLearnedActiveByCell(DS, baseMask, idx1s);

% --- Per-session reuse rate (2/5 layer cells merged)
ReuseSess = iSessionReuse_SessionVsLearned_LayersMerged25(DS, SessSpeed(:, {'Mouse','DateTime'}), learnedCell, baseMask, idx1s);

% Join with ΔHit
J = innerjoin(ReuseSess, SessSpeed(:, {'Mouse','DateTime','Performance','PerformanceNext','Speed_DeltaNext'}), 'Keys', {'Mouse','DateTime'});
assignin('base', 'EnglishFig3A_Joined', J);

x = double(J.Reuse_1s_L25_Merged);
y = double(J.Speed_DeltaNext);
mask = isfinite(x) & isfinite(y);

% --- Plot
f = figure('Color','w', 'Name', 'English Fig3A Reuse vs ΔHit');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0]; % 30mm x 40mm

ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

% Spearman correlation
rho = NaN; p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[rho, p] = corr(x(mask), y(mask), 'Type', 'Spearman');
end

% Scatter: hollow circle, thin edge
scatter(ax, x(mask), y(mask), 15, [0 0.4470 0.7410], 'LineWidth', 0.2);

% Fit line (linear)
if nnz(mask) >= 2 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xFit = [min(x(mask)) max(x(mask))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', [0.85 0.325 0.098]);
end

xlabel(ax, 'Reuse rate (1s, L2/3+L5 merged)');
ylabel(ax, '\DeltaHit rate');

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

function SessOut = iFilterSessions_Keep0ExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});

% Exclude ceiling segment: Perf==1 and later, plus last step into ceiling
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
	if i100 <= 1
		remove(rows(1:end)) = true;
	else
		remove(rows(i100-1:end)) = true;
	end
end
SessOut(remove,:) = [];

% Enforce 0<=Perf<1
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

	% Drop mixed sessions (also contains AudioWater blocks)
	Ta = DS.TableQuery(["Mouse","DateTime","Stimulus"], Mouse=m, DateTime=dt, Stimulus="AudioWater");
	if ~isempty(Ta)
		continue;
	end

	q = struct('Mouse', m, 'DateTime', dt, 'Stimulus', 'LightWater');
	G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
		continue;
	end

	M = iNtatsData(G.NTATS);
	uid = uint64(G.CellUID);
	tranAct = iActiveAt1s(M, baseMask, idx1s, kSigma);
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
