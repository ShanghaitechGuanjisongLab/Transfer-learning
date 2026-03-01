% 英文图3B：代表性会话对的热图 + 细胞间 1s z-score 分布
%
% Pair A: 前后会话平均 inter-cell SD@1s（[-2,2] 细胞）尽可能大
% Pair B: 前后会话平均 inter-cell SD@1s（[-2,2] 细胞）尽可能小
% 约束: ΔHit(A) > ΔHit(B)
%
% 布局: 2×4 tiledlayout（2 行 = Pair A/B，每行：热图k|直方图k|热图k+1|直方图k+1）
%   热图：per-cell median z-score 按 @1s 排序，模仿 2B 风格
%   直方图：横向 (z-score on Y axis)，范围 [-2,2]
%   右侧标注 Moderates / Extremists
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.B_RepresentativeSD_NTATSDistribution

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

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

%% ===== 2) Compute SD@1s per session pair (cells in [-2,2]) =====
sd1sMean = nan(nPairs, 1);
sd1sK    = nan(nPairs, 1);
sd1sK1   = nan(nPairs, 1);
nCellMin = nan(nPairs, 1);

for iP = 1:nPairs
	dtK  = SessSpeed.DateTime(iP);
	dtK1 = SessSpeed.DateTimeNext(iP);
	[~, ntatsK]  = iSessionNTATS(DS, dtK);
	[~, ntatsK1] = iSessionNTATS(DS, dtK1);
	if isempty(ntatsK) || isempty(ntatsK1), continue; end
	vK  = double(ntatsK(:, idx1s));
	vK1 = double(ntatsK1(:, idx1s));
	vK  = vK(isfinite(vK) & vK >= -2 & vK <= 2);
	vK1 = vK1(isfinite(vK1) & vK1 >= -2 & vK1 <= 2);
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
		'Cannot find Pair A & B satisfying all constraints.');
end

pairsIdx = [bestA; bestB];

%% ===== 4) Fetch full NTATS + per-cell 1s values for 4 sessions =====
vals = cell(2, 2);       % vals{pair, session}: per-cell z-score@1s (filtered [-2,2])
sdVals = nan(2, 2);
heatData = cell(2, 2);   % heatData{pair, session}: (cells×time) sorted by @1s

xMask = (xsSec >= 0) & (xsSec <= 2); % 0~2s for heatmap

for iP = 1:2
	idx = pairsIdx(iP);
	dtK  = SessSpeed.DateTime(idx);
	dtK1 = SessSpeed.DateTimeNext(idx);

	for iS = 1:2
		if iS == 1, dt = dtK; else, dt = dtK1; end
		[~, ntats] = iSessionNTATS(DS, dt);
		v1s = double(ntats(:, idx1s));

		% Filter to cells in [-2,2]
		keepMask = isfinite(v1s) & v1s >= -2 & v1s <= 2;
		v1s_filt = v1s(keepMask);
		ntats_filt = double(ntats(keepMask, :));

		% Sort by z-score@1s ascending
		[~, sortIdx] = sort(v1s_filt, 'ascend');
		v1s_sorted = v1s_filt(sortIdx);
		ntats_sorted = ntats_filt(sortIdx, xMask);

		vals{iP, iS} = v1s_sorted;
		sdVals(iP, iS) = std(v1s_sorted);
		heatData{iP, iS} = ntats_sorted;
	end

	pLabel = char('A' + iP - 1);
	fprintf('Pair %s: Mouse=%s, k=%s, k+1=%s, ΔHit=%+.1f%%, meanSD=%.3f\n', ...
		pLabel, string(SessSpeed.Mouse(idx)), ...
		datestr(dtK, 'yyyy-mm-dd HH:MM'), datestr(dtK1, 'yyyy-mm-dd HH:MM'), ...
		100 * deltaHit(idx), sd1sMean(idx));
	fprintf('  Session k:   n=%d cells, SD=%.3f\n', numel(vals{iP,1}), sdVals(iP,1));
	fprintf('  Session k+1: n=%d cells, SD=%.3f\n', numel(vals{iP,2}), sdVals(iP,2));
end

%% ===== 5) Compute heatmap CLim (symmetric, sqrt-scale) =====
allHeat = cellfun(@(x) x(:), heatData, 'UniformOutput', false);
allHeat = vertcat(allHeat{:});
negV = min(allHeat); posV = max(allHeat);
if ~isfinite(negV), negV = -1; end
if ~isfinite(posV), posV = 1; end
climLowAbs  = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0, climLowAbs = 1; end
if climHighAbs <= 0, climHighAbs = 1; end
CLim = [-climLowAbs, climHighAbs];

%% ===== 6) Figure: 2 rows × (heatmap + histogram) × 2 columns =====
% Use separate figure-level positioning to achieve heatmap(wide) + histogram(narrow)
f = figure('Color', 'w', 'Name', 'English Fig3B Representative SD NTATS Distribution');
f.Units = 'centimeters';
f.Position(3:4) = [10.5, 8]; % 105mm × 80mm (15mm×7, 40mm×2)

colorA = [0.8500 0.3250 0.0980]; % orange — Pair A
colorB = [0 0.4470 0.7410];      % blue  — Pair B
pairColors = {colorA; colorB};
pairLabels = ["Pair A", "Pair B"];
colTitles = ["Previous block", "Latter block"];

nBins = 40;
binEdges = linspace(-2, 2, nBins + 1);

% Axes positioning grid (normalized)
% Columns: heatK(wide) | histK(narrow) | gap | heatK1(wide) | histK1(narrow) | gap(annotation)
leftMargin = 0.06;
rightMargin = 0.04;  % space for Moderates/Extremists labels
topMargin = 0.06;
botMargin = 0.12;
gapH = 0.06; % horizontal gap between heatmap and histogram (room for z-score ylabel)
gapHCol = 0.04; % gap between two column groups
gapV = 0.06; % vertical gap between rows
heatFrac = 0.50; % heatmap fraction of column group width
histFrac = 0.50; % histogram fraction

totalW = 1 - leftMargin - rightMargin;
colGroupW = (totalW - gapHCol) / 2;
heatW = colGroupW * heatFrac - gapH/2;
histW = colGroupW * histFrac - gapH/2;

totalH = 1 - topMargin - botMargin;
rowH = (totalH - gapV) / 2;

axHeat = gobjects(2, 2);
axHist = gobjects(2, 2);

for iR = 1:2
	yBot = botMargin + (2 - iR) * (rowH + gapV);
	for iC = 1:2
		xBase = leftMargin + (iC - 1) * (colGroupW + gapHCol);

		% --- Heatmap ---
		hd = heatData{iR, iC};
		nCells = size(hd, 1);

		heatPos = [xBase, yBot, heatW, rowH];
		axH = axes(f, 'Units', 'normalized', 'Position', heatPos); %#ok<LAXES>
		axHeat(iR, iC) = axH;

		imagesc(axH, 'XData', [0, 2], 'YData', [1, nCells], 'CData', hd);
		axH.YDir = 'normal';
		ylim(axH, [0.5, nCells + 0.5]); % tight fit, no blank at top/bottom
		clim(axH, CLim);

		% Blue-white-red colormap, 0-centered (asymmetric CLim support)
		nMap = 256;
		aFrac = climLowAbs / (climLowAbs + climHighAbs);
		nBelow = max(round(nMap * aFrac), 1);
		nAbove = max(nMap - nBelow, 1);
		cmapBelow = [linspace(0,1,nBelow)', linspace(0,1,nBelow)', ones(nBelow,1)];
		cmapAbove = [ones(nAbove,1), linspace(1,0,nAbove)', linspace(1,0,nAbove)'];
		colormap(axH, [cmapBelow; cmapAbove]);

		axH.FontSize = 6;
		axH.FontName = 'Segoe UI Emoji';
		axH.TickDir = 'in';
		box(axH, 'on');
		axH.Toolbar.Visible = 'off';

		% X ticks: 0 (light onset) and 1 (water)
		axH.XTick = [0, 1];
		axH.XTickLabel = {'💡', '💧'};

		% xline markers
		xline(axH, 0, ':k', 'LineWidth', 0.5);
		xline(axH, 1, '-k', 'LineWidth', 0.5);

		% Column title (top row only)
		if iR == 1
			title(axH, colTitles(iC), 'FontSize', 6, 'FontWeight', 'bold');
		end

		% Row label + cell count (left column only)
		if iC == 1
			ylabel(axH, sprintf('%s\n%d cells', pairLabels(iR), nCells), 'FontSize', 6);
			axH.YAxis.Visible = 'on';
			axH.YTick = [];
		else
			axH.YAxis.Visible = 'off';
		end

		% Bottom row: xlabel
		if iR == 1
			axH.XTickLabel = [];
		else
			xlabel(axH, 'Time (s)', 'FontSize', 6);
		end

		% --- Histogram (horizontal) ---
		histPos = [xBase + heatW + gapH, yBot, histW, rowH];
		axHist(iR, iC) = axes(f, 'Units', 'normalized', 'Position', histPos); %#ok<LAXES>
		ax = axHist(iR, iC);
		hold(ax, 'on');

		v = vals{iR, iC};
		histogram(ax, v, binEdges, 'Normalization', 'probability', ...
			'Orientation', 'horizontal', ...
			'FaceColor', pairColors{iR}, 'FaceAlpha', 0.7, 'EdgeColor', 'none');
		yline(ax, mean(v), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

		ax.FontSize = 6;
		box(ax, 'off');
		grid(ax, 'off');
		ax.Toolbar.Visible = 'off';
		ylim(ax, [-2, 2]);
		ax.YTick = [-2, -1, 0, 1, 2];
		% Show y-axis tick labels on left-column histograms
		if iC == 1
			ax.YTickLabel = {'-2','-1',  '0', '1', '2'};
			ylabel(ax, 'z-score', 'FontSize', 6);
		else
			ax.YTickLabel = [];
		end

		% ±1 boundary lines
		yline(ax, -1, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
		yline(ax, 1, ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);

		% SD annotation (top-left to avoid overlap with right-side labels)
		text(ax, 0.05, 0.97, sprintf('SD=%.2f', sdVals(iR, iC)), ...
			'Units', 'normalized', 'HorizontalAlignment', 'left', ...
			'VerticalAlignment', 'top', 'FontSize', 6, 'FontWeight', 'bold');

		% Hide x-axis labels for top row; show "Cell proportion" for bottom
		if iR == 1
			ax.XTickLabel = [];
		else
			xlabel(ax, 'Cell proportion', 'FontSize', 6);
		end
	end
end

% --- Unify histogram X limits ---
xMax = max(arrayfun(@(a) a.XLim(2), axHist(:)));
for a = axHist(:)'
	xlim(a, [0, xMax]);
end

% --- Moderates / Extremists annotation (right of right-column histograms) ---
% Normalized Y coords: [-2,2]→20[0,1]; y=-1→0.25, y=0→0.5, y=1→0.75
% Moderates ([-1,1] zone): rotated 90°, centered at y=0.5
% Extremists ([1,2] and [-2,-1] zones): horizontal, centered in each quarter
for iR = 1:2
	axR = axHist(iR, 2);
	text(axR, 1.06, 0.5, 'Moderates', 'Units', 'normalized', ...
		'FontSize', 6, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
		'FontWeight', 'bold', 'Rotation', 90, 'Clipping', 'off');
	% Top extremists zone: y in [0.75, 1.0], center at 0.875
	text(axR, 0.95, 0.815, 'Extremists', 'Units', 'normalized', ...
		'FontSize', 6, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
		'Color', [0.5 0.5 0.5], 'Clipping', 'off');
	% Bottom extremists zone: y in [0, 0.25], center at 0.125
	text(axR, 0.95, 0.185, 'Extremists', 'Units', 'normalized', ...
		'FontSize', 6, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
		'Color', [0.5 0.5 0.5], 'Clipping', 'off');
end

% ===== 7) Export =====
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

function y = iNiceLimit(x)
if ~isfinite(x) || x <= 0
	y = 1; return;
end
e = floor(log10(x));
f = x / (10^e);
if f <= 1, n = 1;
elseif f <= 2, n = 2;
elseif f <= 5, n = 5;
else, n = 10;
end
y = n * (10^e);
if y < x, y = 10 * (10^e); end
end
