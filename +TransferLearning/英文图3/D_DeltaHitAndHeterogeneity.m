% English Fig3D: Naive vs Transfer — ΔHit and Response heterogeneity
%
% Two bar tiles comparing Naive and Transfer cohorts:
%   Top:    ΔHit per session pair (one point = one adjacent pair)
%   Bottom: Response heterogeneity per session (one point = one session)
%
% Naive:    LightAudioBaseline (Naive→Learned)
% Transfer: AudioLightBaseline (Transfer→Final)
%
% Execution:
%   TransferLearning.英文图3.D_DeltaHitAndHeterogeneity

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS_Naive    = TransferLearning.LightAudioBaseline();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('Fig3D:No1s', 'Cannot find sample close to 1s.'); end

% --- Per-cohort: session-pair ΔHit, session-level SD
[dhN, sdN] = iCohortData(DS_Naive,    idx1s, "Naive",    "Learned");
[dhT, sdT] = iCohortData(DS_Transfer, idx1s, "Transfer", "Final");

fprintf('Naive:    %d pairs (ΔHit), %d sessions (SD)\n', numel(dhN), numel(sdN));
fprintf('Transfer: %d pairs (ΔHit), %d sessions (SD)\n', numel(dhT), numel(sdT));

pDH = ranksum(dhN, dhT);
pSD = ranksum(sdN, sdT);
fprintf('ΔHit ranksum p=%.4g\n', pDH);
fprintf('Response heterogeneity ranksum p=%.4g\n', pSD);

% --- Figure: 2×1 tiledlayout
f = figure('Color', 'w', 'Name', 'Fig3D ΔHit & Heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

colorNaive    = [0.8500 0.3250 0.0980];
colorTransfer = [0      0.4470 0.7410];

% --- Tile 1: ΔHit ---
nexttile(Layout, 1);
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Opt1, Bars1, EB1] = UniExp.BarScatterCompare( ...
	{dhN, dhT}, false, CompareGroup, 'AsteriskThreshold', 0.05);
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end
ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {};
ylabel(ax1, '\DeltaHit', 'FontSize', 6);
legend(ax1, 'off');
box(ax1, 'off');
if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	nB = numel(Bars1.YData);
	Bars1.CData = repmat([colorNaive; colorTransfer], ceil(nB/2), 1);
	Bars1.CData = Bars1.CData(1:nB, :);
	Bars1.BarWidth = 0.5; Bars1.LineWidth = 0.5; Bars1.FaceAlpha = 1/3;
end
if isfield(Opt1, 'MultiCompare') && ismember('PText', Opt1.MultiCompare.Properties.VariableNames)
	for pt = Opt1.MultiCompare.PText(:)'
		pt.FontSize = 6;
		if pDH < 0.001, pt.String = '***';
		elseif pDH < 0.01, pt.String = '**';
		elseif pDH < 0.05, pt.String = '*';
		else, pt.String = sprintf('p=%.2g', pDH); end
	end
end

% --- Tile 2: Response heterogeneity ---
nexttile(Layout, 2);
[~, Opt2, Bars2, EB2] = UniExp.BarScatterCompare( ...
	{sdN, sdT}, false, CompareGroup, 'AsteriskThreshold', 0.05);
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end
ax2 = gca;
ax2.FontSize = 6;
ax2.XTick = [1 2];
ax2.XTickLabel = {'Naive', 'Transfer'};
ylabel(ax2, 'Response heterogeneity', 'FontSize', 6);
legend(ax2, 'off');
box(ax2, 'off');
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nB = numel(Bars2.YData);
	Bars2.CData = repmat([colorNaive; colorTransfer], ceil(nB/2), 1);
	Bars2.CData = Bars2.CData(1:nB, :);
	Bars2.BarWidth = 0.5; Bars2.LineWidth = 0.5; Bars2.FaceAlpha = 1/3;
end
if isfield(Opt2, 'MultiCompare') && ismember('PText', Opt2.MultiCompare.Properties.VariableNames)
	for pt = Opt2.MultiCompare.PText(:)', pt.FontSize = 6; end
end

% --- Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3D_DeltaHitAndHeterogeneity.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function [dhVec, sdVec] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
% Returns:
%   dhVec: ΔHit per session pair (one element per adjacent pair)
%   sdVec: Response heterogeneity per session (one element per session)

Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);

if isempty(Sess)
	dhVec = []; sdVec = []; return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

% --- Session-pair ΔHit (ceiling-excluded) ---
mice = unique(string(Sess.Mouse));
dhVec = [];
allUsedDTs = datetime.empty(0,1);
for iM = 1:numel(mice)
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2, continue; end
	perf = double(R.Performance);
	dhVec = [dhVec; diff(perf)]; %#ok<AGROW>
	allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
end

% --- Session-level SD (per session, not averaged across mouse) ---
allUsedDTs = unique(allUsedDTs);
sdVec = [];
if isempty(allUsedDTs), return; end

q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
rawTbl = ntsCell{1};
rawTbl.CellUID  = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

% Per-cell per-session median
[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

% Compute SD per session
uDTs = unique(dtU1);
sdVec = nan(numel(uDTs), 1);
for iDT = 1:numel(uDTs)
	vals = med1s(dtU1 == uDTs(iDT));
	vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
	if numel(vals) >= 3, sdVec(iDT) = std(vals); end
end
sdVec = sdVec(isfinite(sdVec));
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
	rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
