% English Fig1M: Per-mouse learning slope vs mean inter-cell SD@1s
%
% Both cohorts combined:
%   - Naive   (LightAudioBaseline): slope over Naive→Learned sessions
%   - Transfer (AudioLightBaseline): slope over Transfer→Final sessions
%
% Per-mouse:
%   x = mean inter-cell SD@1s (z-score, cells in [-1,1]) across phase sessions
%   y = learning slope (hit rate / session, polyfit)
%
% Plot: scatter with cohort-specific markers + legend; sigLabel only (no r=, no n=).
%
% Execution:
%   TransferLearning.英文图1.M_SlopeVsInterCellSD

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS_Naive    = TransferLearning.LightAudioBaseline();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('SlopeVsSD:No1s', 'Cannot find sample close to 1s in time axis.');
end

% --- 1) Per-cohort: sessions + slope + SD
[slopeNaive,  sdNaive,  miceNaive,  firstHitNaive]    = iCohortData(DS_Naive,    idx1s, "Naive",    "Learned");
[slopeTransfer, sdTransfer, miceTransfer, firstHitTransfer] = iCohortData(DS_Transfer, idx1s, "Transfer", "Final");

fprintf('Naive cohort:    %d mice with valid slope+SD\n', numel(miceNaive));
fprintf('Transfer cohort: %d mice with valid slope+SD\n', numel(miceTransfer));

% --- 2) Pool
sdAll        = [sdNaive;    sdTransfer];
slopeAll     = [slopeNaive; slopeTransfer];
firstHitAll  = [firstHitNaive; firstHitTransfer];
groupAll     = [repmat("Naive", numel(miceNaive), 1); repmat("Transfer", numel(miceTransfer), 1)];

use = isfinite(sdAll) & isfinite(slopeAll);
fprintf('Combined: %d mice with both slope and SD\n', nnz(use));

% --- 3a) Simple Spearman
[rho, p] = corr(sdAll(use), slopeAll(use), 'Type', 'Spearman');
fprintf('Spearman rho=%.3f, p=%.4g, n=%d\n', rho, p, nnz(use));

% --- 3b) Partial Spearman controlling for first-session hit rate (logged only)
useP = use & isfinite(firstHitAll);
if nnz(useP) >= 4
	[rhoP, pP] = iPartialSpearman(sdAll(useP), slopeAll(useP), firstHitAll(useP));
	fprintf('Partial Spearman (ctrl first-session hitrate) rho=%.3f, p=%.4g, n=%d\n', rhoP, pP, nnz(useP));
	% Figure uses simple Spearman (rho/p not overwritten here)
end

if p < 0.001, sigLabel = '***';
elseif p < 0.01, sigLabel = '**';
elseif p < 0.05, sigLabel = '*';
else, sigLabel = 'n.s.';
end

% --- 4) Plot
f = figure('Color', 'w', 'Name', 'Fig1M Slope vs SD (Naive + Transfer)');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.5];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 6;
ax.Toolbar.Visible = 'off';
box(ax, 'off');

colorNaive    = [0.8500 0.3250 0.0980]; % orange-red
colorTransfer = [0 0.4470 0.7410];      % blue

% Scatter: Naive = circle, Transfer = square
maskN = use & (groupAll == "Naive");
maskT = use & (groupAll == "Transfer");
hN = scatter(ax, sdAll(maskN), slopeAll(maskN), 14, colorNaive,    'o', 'filled', 'LineWidth', 0.3);
hT = scatter(ax, sdAll(maskT), slopeAll(maskT), 14, colorTransfer, 's', 'filled', 'LineWidth', 0.3);

% Fit line (pooled)
if nnz(use) >= 2 && std(sdAll(use)) > 0
	b = polyfit(sdAll(use), slopeAll(use), 1);
	xFit = [min(sdAll(use)), max(sdAll(use))];
	plot(ax, xFit, polyval(b, xFit), '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
end

% Legend
legend(ax, [hN, hT], {'Naive', 'Transfer'}, 'FontSize', 5, 'Box', 'off', 'Location', 'best');

% Significance annotation only (no r=, no n=)
text(ax, 0.97, 0.97, sigLabel, ...
	'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
	'FontSize', 8, 'FontWeight', 'bold');

xlabel(ax, 'Mean inter-cell SD@1s', 'FontSize', 6);
ylabel(ax, 'Learning slope (hit rate/session)', 'FontSize', 6);

% --- 5) Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig1M_SlopeVsInterCellSD.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function [slopeVec, sdVec, mice, firstHitVec] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
% Build per-session LW hit rate, keep pure LW, keep phase range, then per-mouse slope+SD

Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);

if isempty(Sess)
	slopeVec = []; sdVec = []; mice = string.empty(0,1); firstHitVec = []; return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
nMice = numel(mice);
slopeVec    = nan(nMice, 1);
sdVec       = nan(nMice, 1);
firstHitVec = nan(nMice, 1);

for iM = 1:nMice
	m = mice(iM);
	R = Sess(string(Sess.Mouse) == m, :);
	R = sortrows(R, 'DateTime');
	n = height(R);
	if n < 2, continue; end
	firstHitVec(iM) = double(R.Performance(1));

	% Exclude first 100% session and beyond
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;  % 第一会话就100%，无法算斜率
	end
	n = height(R);
	if n < 2, continue; end

	% Slope: polyfit performance vs session index
	xi = (1:n)';
	yi = double(R.Performance);
	ok = isfinite(yi);
	if nnz(ok) < 2, continue; end
	pFit = polyfit(xi(ok), yi(ok), 1);
	slopeVec(iM) = pFit(1);

	% Per-cell mean z-score@1s across sessions, then filter [-1,1] and SD
	allUID  = cell(n, 1);
	allVals = cell(n, 1);
	for iS = 1:n
		dt = R.DateTime(iS);
		[uid, ntats] = iSessionNTATS(DS, dt);
		if isempty(ntats), continue; end
		v = double(ntats(:, idx1s));
		ok2 = isfinite(v);
		if any(ok2)
			allUID{iS}  = uid(ok2);
			allVals{iS} = v(ok2);
		end
	end
	allUID  = vertcat(allUID{:});
	allVals = vertcat(allVals{:});
	if ~isempty(allUID)
		[~, ~, ic]   = unique(allUID);
		meanPerCell  = accumarray(ic, allVals, [], @mean);
		keep2        = isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1;
		if nnz(keep2) >= 3
			sdVec(iM) = std(meanPerCell(keep2));
		end
	end
end

keep = isfinite(slopeVec) & isfinite(sdVec);
slopeVec    = slopeVec(keep);
sdVec       = sdVec(keep);
mice        = mice(keep);
firstHitVec = firstHitVec(keep);
end

function [r, p] = iPartialSpearman(x, y, z)
% Partial Spearman rho(y,x|z) via rank-transform + residualization
n   = numel(x);
Rx  = tiedrank(x(:));
Ry  = tiedrank(y(:));
Rz  = tiedrank(z(:));
X_  = [ones(n,1), Rz];
ex  = Rx - X_ * (X_ \ Rx);
ey  = Ry - X_ * (X_ \ Ry);
r   = corr(ex, ey, 'Type', 'Pearson');
df  = n - 3;   % 1 covariate
t   = r * sqrt(df / max(1 - r^2, eps));
p   = 2 * tcdf(-abs(t), df);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		'VariableNames',{'Mouse','DateTime','Phase','Performance'}); return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks, 'Keys','BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	dtM = DT(DT.Mouse == m, :);
	phDates = dtM.DateTime(dtM.Phase == phaseStart);
	endDates = dtM.DateTime(dtM.Phase == phaseEnd);
	if isempty(phDates) || isempty(endDates), continue; end
	startDT = min(phDates);
	endDT   = max(endDates);
	if ismissing(startDT) || ismissing(endDT), continue; end
	rows = (string(SessOut.Mouse) == m) & ...
		(SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function [uid, ntats] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T), uid = uint64.empty(0,1); ntats = []; return; end
des = unique(string(T.Design));
des = des(~ismissing(des));
if numel(des) ~= 1, uid = uint64.empty(0,1); ntats = []; return; end
try
	G = DS.QueryNTATS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	uid = uint64(G.CellUID);
	if isa(G.NTATS, 'MATLAB.DataTypes.NDTable')
		ntats = double(G.NTATS.Data);
	else
		ntats = double(G.NTATS);
	end
catch
	uid = uint64.empty(0,1); ntats = [];
end
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
