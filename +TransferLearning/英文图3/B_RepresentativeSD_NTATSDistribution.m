% 英文图3G：代表性会话对的细胞间 1s NTATS 分布图
%
% Pair A: 前后会话平均 inter-cell SD@1s 尽可能大的会话对
% Pair B: 前后会话平均 inter-cell SD@1s 尽可能小的会话对
% 约束: ΔHit(A) > ΔHit(B)
%
% 布局: 2×2 tiledlayout
%   Row 1 = Pair A (session k → k+1)
%   Row 2 = Pair B (session k → k+1)
%
% 每个 tile: 细胞间 per-cell median ZScore@1s 分布直方图
%   — Pair A 直方图较宽（SD 大），Pair B 较窄（SD 小）
%
% 会话选取参考 C 图 (C_RepresentativeSessionPairs_LWHeatmaps)。
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图3.G_RepresentativeSD_NTATSDistribution

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('EnglishFig3B:No1s', 'Cannot find sample close to 1s.');
end

%% ===== 1) Build session pairs =====
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iExcludeCeiling(Sess);

SessSpeed = iSessionDeltaNext(Sess);
nPairs = height(SessSpeed);
deltaHit = double(SessSpeed.Speed_DeltaNext);

%% ===== 2) Compute SD@1s per session pair =====
sd1sMean = nan(nPairs, 1);
sd1sK    = nan(nPairs, 1);  % SD of session k
sd1sK1   = nan(nPairs, 1);  % SD of session k+1
nCellMin = nan(nPairs, 1);

for iP = 1:nPairs
	dtK  = SessSpeed.DateTime(iP);
	dtK1 = SessSpeed.DateTimeNext(iP);
	[~, ntatsK]  = iSessionNTATS(DS, dtK);
	[~, ntatsK1] = iSessionNTATS(DS, dtK1);
	if isempty(ntatsK) || isempty(ntatsK1), continue; end
	vK  = double(ntatsK(:, idx1s));
	vK1 = double(ntatsK1(:, idx1s));
	vK  = vK(isfinite(vK));
	vK1 = vK1(isfinite(vK1));
	nCellMin(iP) = min(numel(vK), numel(vK1));
	if numel(vK) >= 3 && numel(vK1) >= 3
		sd1sK(iP)  = std(vK);
		sd1sK1(iP) = std(vK1);
		sd1sMean(iP) = (sd1sK(iP) + sd1sK1(iP)) / 2;
	end
end

%% ===== 3) Select Pair A (max SD) and Pair B (min SD), ΔHit(A)>ΔHit(B) =====
valid = isfinite(deltaHit) & isfinite(sd1sMean) & (nCellMin >= 10);
validIdx = find(valid);

[~, sortDesc] = sort(sd1sMean(validIdx), 'descend');
sortedBySD = validIdx(sortDesc);

bestA = NaN;
bestB = NaN;
found = false;

for iA = 1:numel(sortedBySD)
	candA = sortedBySD(iA);
	minSD_A = min(sd1sK(candA), sd1sK1(candA));
	for iB = numel(sortedBySD):-1:1
		candB = sortedBySD(iB);
		if candB == candA, continue; end
		maxSD_B = max(sd1sK(candB), sd1sK1(candB));
		% Constraints: meanSD(A) > meanSD(B), ΔHit(A) - ΔHit(B) >= 10%,
		% and min session SD of A > max session SD of B
		if sd1sMean(candA) > sd1sMean(candB) ...
				&& (deltaHit(candA) - deltaHit(candB)) >= 0.10 ...
				&& minSD_A > maxSD_B
			bestA = candA;
			bestB = candB;
			found = true;
			break;
		end
	end
	if found, break; end
end

if ~found
	error('EnglishFig3B:NoFeasible', ...
		'Cannot find Pair A & B satisfying all constraints (meanSD, \DeltaHit, min/max SD separation).');
end

pairsIdx = [bestA; bestB];

%% ===== 4) Fetch per-cell 1s values for 4 sessions =====
vals = cell(2, 2);       % vals{pair, session}: col 1=k, 2=k+1
sdVals = nan(2, 2);

for iP = 1:2
	idx = pairsIdx(iP);
	dtK  = SessSpeed.DateTime(idx);
	dtK1 = SessSpeed.DateTimeNext(idx);

	[~, ntatsK]  = iSessionNTATS(DS, dtK);
	[~, ntatsK1] = iSessionNTATS(DS, dtK1);

	vK  = double(ntatsK(:, idx1s));
	vK  = vK(isfinite(vK));
	vK1 = double(ntatsK1(:, idx1s));
	vK1 = vK1(isfinite(vK1));

	vals{iP, 1} = vK;
	vals{iP, 2} = vK1;
	sdVals(iP, 1) = std(vK);
	sdVals(iP, 2) = std(vK1);

	pLabel = char('A' + iP - 1);
	fprintf('Pair %s: Mouse=%s, k=%s, k+1=%s, ΔHit=%+.1f%%, meanSD=%.3f\n', ...
		pLabel, string(SessSpeed.Mouse(idx)), ...
		datestr(dtK, 'yyyy-mm-dd HH:MM'), datestr(dtK1, 'yyyy-mm-dd HH:MM'), ...
		100 * deltaHit(idx), sd1sMean(idx));
	fprintf('  Session k:   n=%d cells, SD=%.3f\n', numel(vK), sdVals(iP, 1));
	fprintf('  Session k+1: n=%d cells, SD=%.3f\n', numel(vK1), sdVals(iP, 2));
end

% --- Shared bin edges (display range: -2 to 3)
nBins = 50;
binEdges = linspace(-2, 3, nBins + 1);

%% ===== 5) Plot: 2×2 tiledlayout =====
f = figure('Color', 'w', 'Name', 'English Fig3B Representative SD NTATS Distribution');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4];

Layout = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

colorA = [0.8500 0.3250 0.0980]; % orange — Pair A
colorB = [0 0.4470 0.7410];      % blue  — Pair B
pairColors = {colorA; colorB};
pairLabels = ["Pair A", "Pair B"];
colTitles = ["Previous block", "Latter block"];

axH = gobjects(2, 2);

for iR = 1:2
	for iC = 1:2
		axH(iR, iC) = nexttile(Layout, (iR - 1) * 2 + iC);
		ax = axH(iR, iC);
		hold(ax, 'on');

		v = vals{iR, iC};
		histogram(ax, v, binEdges, 'Normalization', 'probability', ...
			'FaceColor', pairColors{iR}, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
		xline(ax, mean(v), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

		ax.FontSize = 6;
		box(ax, 'off');
		grid(ax, 'off');
		ax.Toolbar.Visible = 'off';
		xlim(ax, [-2, 3]);

		% SD annotation
		text(ax, 0.95, 0.95, sprintf('SD=%.2f', sdVals(iR, iC)), ...
			'Units', 'normalized', 'HorizontalAlignment', 'right', ...
			'VerticalAlignment', 'top', 'FontSize', 6);

		% Column title (top row only)
		if iR == 1
			title(ax, colTitles(iC), 'FontSize', 6, 'FontWeight', 'normal');
		end

		% Row label (left column only)
		if iC == 1
			ylabel(ax, pairLabels(iR), 'FontSize', 6);
		end

		% Hide top row x-axis
		if iR == 1
			ax.XTickLabel = [];
			ax.XAxis.Visible = 'off';
		end

		% Hide right column y-axis
		if iC == 2
			ax.YTickLabel = [];
			ax.YAxis.Visible = 'off';
		end
	end
end

% Layout-level x label
xl = xlabel(Layout, 'z-score');
ylabel(Layout,'Cell proportion',FontSize=6);
xl.FontSize = 6;

% Unify Y limits
yMax = max(arrayfun(@(a) a.YLim(2), axH(:)));
for a = axH(:)'
	ylim(a, [0, yMax]);
end

% ===== 6) Export =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgName = "English_Fig3B_RepresentativeSD_NTATSDistribution.svg";
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'EnglishFig3B_PairsIdx', pairsIdx);
assignin('base', 'EnglishFig3B_SessSpeed', SessSpeed);
assignin('base', 'EnglishFig3B_SD', sdVals);
assignin('base', 'EnglishFig3B_SD1sMean', sd1sMean);

%% ===== Local functions =====

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
Stim = string(Tr.Stimulus);

TrLW = Tr(Stim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Phase','Performance','NBlocksInSession'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});

T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');

[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perfSess = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
nBlocks = splitapply(@numel, T.LWPerf, G2);
phase = splitapply(@(x) string(x(1)), T.Phase, G2);

Sess = table(mouse, dt, phase, perfSess, nBlocks, ...
	'VariableNames', {'Mouse','DateTime','Phase','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end

Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
Stim = string(Tr.Stimulus);

TrAW = Tr(Stim == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end

blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end

function SessSpeed = iSessionDeltaNext(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(Sess.Mouse);

nTotal = 0;
for mi = 1:numel(mice)
	R = Sess(Sess.Mouse == mice(mi), :);
	perf = double(R.Performance);
	use = isfinite(perf) & ~ismissing(R.DateTime);
	nTotal = nTotal + max(0, nnz(use) - 1);
end

outM = strings(nTotal, 1);
outDT = NaT(nTotal, 1);
outP = nan(nTotal, 1);
outDT2 = NaT(nTotal, 1);
outP2 = nan(nTotal, 1);
outDN = nan(nTotal, 1);

pos = 0;
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance);
	dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	perf = perf(use);
	dt = dt(use);
	if numel(perf) < 2, continue; end
	dn = diff(perf);
	n = numel(dn);
	idx = (pos + 1):(pos + n);
	outM(idx) = repmat(m, n, 1);
	outDT(idx) = dt(1:end-1);
	outP(idx) = perf(1:end-1);
	outDT2(idx) = dt(2:end);
	outP2(idx) = perf(2:end);
	outDN(idx) = dn(:);
	pos = pos + n;
end

if pos < nTotal
	outM(pos+1:end) = [];
	outDT(pos+1:end) = [];
	outP(pos+1:end) = [];
	outDT2(pos+1:end) = [];
	outP2(pos+1:end) = [];
	outDN(pos+1:end) = [];
end

SessSpeed = table(outM, outDT, outP, outDT2, outP2, outDN, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end

function [uid, ntats] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T)
	uid = uint64.empty(0,1); ntats = []; return;
end

des = unique(string(T.Design));
des = des(~ismissing(des));
if numel(des) ~= 1
	error('EnglishFig3B:AmbiguousDesign', ...
		'Expected 1 LightWater Design in DateTime %s, got %d.', datestr(dt), numel(des));
end

G = DS.QueryNTATS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

uid = uint64(G.CellUID);
if isa(G.NTATS, 'MATLAB.DataTypes.NDTable')
	ntats = double(G.NTATS.Data);
else
	ntats = double(G.NTATS);
end
end
