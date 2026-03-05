% English Fig1 scratch: Per-mouse learning slope vs mean inter-cell SD@1s
%
% For Transfer cohort (AudioLightBaseline), compute for each mouse:
%   x = learning slope (hit rate / session, polyfit over Transfer→Final sessions)
%   y = mean inter-cell SD@1s across those same sessions (z-score, cells in [-1,1])
%
% Then plot scatter + Spearman correlation.
%
% Execution:
%   TransferLearning.英文图1.Z_SlopeVsInterCellSD

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('SlopeVsSD:No1s', 'Cannot find sample close to 1s in time axis.');
end

% --- 1) Build per-session LightWater hit rate
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);

% Keep only Transfer→Final phase sessions
Sess = iKeepTransferToFinal(DS, Sess);
if isempty(Sess)
	error('SlopeVsSD:NoSessions', 'No Transfer-phase LW sessions found.');
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

% --- 2) For each mouse: compute slope + session-level SD
mice = unique(string(Sess.Mouse));
nMice = numel(mice);
slopeVec = nan(nMice, 1);
meanSdVec = nan(nMice, 1);
nSessVec = nan(nMice, 1);

for iM = 1:nMice
	m = mice(iM);
	R = Sess(string(Sess.Mouse) == m, :);
	R = sortrows(R, 'DateTime');
	n = height(R);
	if n < 2, continue; end
	nSessVec(iM) = n;

	% Slope: polyfit performance vs session index
	x = (1:n)';
	y = double(R.Performance);
	ok = isfinite(y);
	if nnz(ok) < 2, continue; end
	p = polyfit(x(ok), y(ok), 1);
	slopeVec(iM) = p(1);

	% Mean SD@1s across those sessions
	sdPerSess = nan(n, 1);
	for iS = 1:n
		dt = R.DateTime(iS);
		[~, ntats] = iSessionNTATS(DS, dt);
		if isempty(ntats), continue; end
		v = double(ntats(:, idx1s));
		v = v(isfinite(v) & v >= -1 & v <= 1);
		if numel(v) >= 3
			sdPerSess(iS) = std(v);
		end
	end
	ok2 = isfinite(sdPerSess);
	if any(ok2)
		meanSdVec(iM) = mean(sdPerSess(ok2));
	end
end

use = isfinite(slopeVec) & isfinite(meanSdVec);
fprintf('Mice with both slope and SD: %d / %d\n', nnz(use), nMice);

% --- 3) Spearman correlation
[rho, p] = corr(slopeVec(use), meanSdVec(use), 'Type', 'Spearman');
fprintf('Spearman rho=%.3f, p=%.4g, n=%d\n', rho, p, nnz(use));

if p < 0.001, sigLabel = '***';
elseif p < 0.01, sigLabel = '**';
elseif p < 0.05, sigLabel = '*';
else, sigLabel = 'n.s.';
end

% --- 4) Plot
f = figure('Color', 'w', 'Name', 'Fig1 Slope vs SD');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.5];

ax = axes(f);
hold(ax, 'on');
ax.FontSize = 6;
ax.Toolbar.Visible = 'off';
box(ax, 'off');

scatter(ax, slopeVec(use), meanSdVec(use), 12, [0 0.4470 0.7410], ...
	's', 'filled', 'LineWidth', 0.3);

% Fit line
b = polyfit(slopeVec(use), meanSdVec(use), 1);
xFit = [min(slopeVec(use)), max(slopeVec(use))];
yFit = polyval(b, xFit);
plot(ax, xFit, yFit, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1);

text(ax, 0.97, 0.97, sprintf('r=%.2f %s\nn=%d', rho, sigLabel, nnz(use)), ...
	'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
	'FontSize', 6);

xlabel(ax, 'Learning slope (hit rate/session)', 'FontSize', 6);
ylabel(ax, 'Mean inter-cell SD@1s', 'FontSize', 6);
title(ax, 'Transfer cohort', 'FontSize', 6, 'FontWeight', 'normal');

% --- 5) Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig1Z_SlopeVsInterCellSD.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

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

function SessOut = iKeepTransferToFinal(DS, SessIn)
% Keep only sessions within each mouse's Transfer→Final span
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
	startDT = min(dtM.DateTime(dtM.Phase == "Transfer"));
	endDT   = max(dtM.DateTime(dtM.Phase == "Final"));
	if isempty(startDT) || isempty(endDT) || any(ismissing([startDT, endDT]))
		continue;
	end
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
G = DS.QueryNTATS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
uid = uint64(G.CellUID);
if isa(G.NTATS, 'MATLAB.DataTypes.NDTable')
	ntats = double(G.NTATS.Data);
else
	ntats = double(G.NTATS);
end
end

function dt = iNormDT(dt)
try
	if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch; end
end
