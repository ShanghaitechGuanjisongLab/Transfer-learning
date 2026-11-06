% FigS1H (English, merged from Chinese Fig43F/G/H): active-cell fraction pies
%
% 左: Learned AudioWater 活跃细胞占所有记录细胞比例（中文图43F）
% 中: Transfer LightWater 首个训练单元活跃细胞占所有记录细胞比例（中文图43G）
% 右: Learned 活跃细胞在 Transfer 首个训练单元中被重新激活的比例（中文图43H）
%
% 活跃判定：线索后 1 s 处 z-score > 基线(-3~0 s)均值 + 3σ
% 输出单个 SVG，横向三个饼图
%
% 声/光/水 三个小图标用 patch/plot 手绘矢量图形（替代彩色 emoji）：
% emoji 在矢量 SVG 中会退化成单色剪影、且依赖系统 Segoe UI Emoji 字体，不能用于投稿。

% --- 0) Ensure project loaded
if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('FigS1H:No1s', 'Cannot find sample close to 1s.');
end

kSigma = 3;

%% --- F: Learned AudioWater active fraction ---
qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
GLearned = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
learnedTable = iBuildActiveCellTable(GLearned, idx1s, baseMask, kSigma, 'FigS1H:BadNTATS');
[learnedActiveN, learnedTotalN] = iUniqueCounts(learnedTable);

%% --- G: Transfer LightWater first-block active fraction ---
firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS);
transferTables = cell(height(firstTransfer), 1);
for iMouse = 1:height(firstTransfer)
	qTransferOne = struct('Stimulus', 'LightWater', 'DateTime', firstTransfer.DateTime(iMouse));
	GTransferOne = DS.QueryNTATS(qTransferOne, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	transferTables{iMouse} = iBuildActiveCellTable(GTransferOne, idx1s, baseMask, kSigma, 'FigS1H:BadNTATS');
end
if isempty(transferTables)
	transferTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
else
	transferTable = vertcat(transferTables{:});
end
[transferActiveN, transferTotalN] = iUniqueCounts(transferTable);

%% --- H: reuse fraction (per-mouse mean of P[Reactivated | Learned-active]) ---
% 口径说明：
%   pooled  = (所有鼠 Learned 活跃细胞中在 Transfer 首块也被激活的个数) / (所有 Learned 活跃细胞数)
%   per-mouse = 先算每只鼠的复用比例，再对鼠取平均（与旧图 43H 的 84.6 / 15.4 一致）
% 绘图用 per-mouse 平均，pooled 一并打印供核对。
learnedActiveIDs = unique(uint64(learnedTable.CellUID(logical(learnedTable.IsActive))));
transferActiveIDs = unique(uint64(transferTable.CellUID(logical(transferTable.IsActive))));
nReusePooled = numel(intersect(learnedActiveIDs, transferActiveIDs));
[learnedActiveNDedup, ~] = iUniqueCounts(learnedTable(learnedTable.IsActive, :));
nLearnedActiveDenom = learnedActiveNDedup;

fracPerMouse = nan(height(firstTransfer), 1);
for iMouse = 1:height(firstTransfer)
	qLearnedOne = struct('Mouse', firstTransfer.Mouse(iMouse), 'Phase', 'Learned', 'Stimulus', 'AudioWater');
	GLearnedOne = DS.QueryNTATS(qLearnedOne, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	learnedOne = iBuildActiveCellTable(GLearnedOne, idx1s, baseMask, kSigma, 'FigS1H:BadNTATS');
	Lids = unique(uint64(learnedOne.CellUID(logical(learnedOne.IsActive))));
	Tids = unique(uint64(transferTables{iMouse}.CellUID(logical(transferTables{iMouse}.IsActive))));
	if ~isempty(Lids)
		fracPerMouse(iMouse) = numel(intersect(Lids, Tids)) / numel(Lids);
	end
end
fracReuse = mean(fracPerMouse, 'omitnan');
fracReuseSem = std(fracPerMouse, 'omitnan') / sqrt(sum(isfinite(fracPerMouse)));
nReuse = 100 * fracReuse;          % 传入饼图时用 0~100 作分子，分母 100
nReuseDenom = 100;

%% --- Plot: 3 pies side by side ---
% 样式参照 Guan-lab Nat Commun 2026 Fig.5g/k：
%   普通饼图（非环形）、灰底 + 单一强调色、扇区间白色细缝、无图例/边框，
%   强调扇区 = 彩色粗体名称（上）+ 黑色百分比（下），灰扇区 = 灰色粗体名称（上）+ 黑色百分比（下）。
% 每个饼上方保留一行 6 pt 小字标题，用于区分 Learned / Transfer / Reactivation。
% 尺寸遵循英文图规范：宽为 1.5 cm 的整倍数（12.0 = 8×1.5，≤182 mm）；基础高 4 cm；字号 6 pt。
slotCm = 4.0;      % 每饼槽宽（三槽合计 12.0 cm）
axWCm = 3.8;       % 轴宽（子图间距 0.2 cm）
figWCm = 3 * slotCm;
figHCm = 4.0;

f = figure('Color', 'w', 'Name', 'English FigS1H Active Fraction Pies');
f.Units = 'centimeters';
f.Position(3:4) = [figWCm, figHCm];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, figWCm, figHCm];
f.PaperSize = [figWCm, figHCm];

specs = { ...
	learnedActiveN,  learnedTotalN,  'Learned',      {},                   'Active',      {{'speaker', 'drop'}}, 'Inactive'; ...
	transferActiveN, transferTotalN, 'Transfer',     {},                   'Active',      {{'bulb', 'drop'}},    'Inactive'; ...
	nReuse,          nReuseDenom,    'Active cells', {{'speaker', 'drop'}}, 'Reactivated', {{'bulb', 'drop'}},    'Not reactivated'};
for iP = 1:3
	axLeftCm = (iP - 1) * slotCm + (slotCm - axWCm) / 2;
	ax = axes(f, 'Units', 'normalized', ...
		'Position', [axLeftCm / figWCm, 0.16, axWCm / figWCm, 0.68]);
	ttlIcons = iPeelIconCell(specs{iP, 4});
	actIcons = iPeelIconCell(specs{iP, 6});
	iPlotOnePie(ax, specs{iP, 1}, specs{iP, 2}, specs{iP, 3}, ttlIcons, ...
		specs{iP, 5}, actIcons, specs{iP, 7});
end

set(findobj(f, 'Type', 'text'), 'FontSize', 6);

%% --- Export ---
svgName = "English_FigS1H_ActiveFractionPies.svg";
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('Learned AudioWater active = %d / %d (%.4f)\n', learnedActiveN, learnedTotalN, learnedActiveN / learnedTotalN);
fprintf('Transfer first-block active = %d / %d (%.4f)\n', transferActiveN, transferTotalN, transferActiveN / transferTotalN);
fprintf('Reuse per-mouse mean = %.4f +- %.4f (n=%d)  -> %.1f%% reactivated / %.1f%% not\n', ...
	fracReuse, fracReuseSem, sum(isfinite(fracPerMouse)), 100 * fracReuse, 100 * (1 - fracReuse));
fprintf('Reuse pooled (for reference) = %d / %d (%.4f)\n', nReusePooled, nLearnedActiveDenom, ...
	nReusePooled / nLearnedActiveDenom);

summary = table(learnedActiveN, learnedTotalN, transferActiveN, transferTotalN, ...
	fracReuse, fracReuseSem, nReusePooled, nLearnedActiveDenom, ...
	'VariableNames', {'LearnedActiveN', 'LearnedTotalN', 'TransferFirstActiveN', 'TransferFirstTotalN', ...
	'ReusePerMouseMean', 'ReusePerMouseSem', 'ReusePooledN', 'ReusePooledDenominatorN'});
assignin('base', 'FigS1H_ActiveFractionSummary', summary);

%% ========== Local helpers ==========

function iconKinds = iPeelIconCell(c)
% specs 中的图标列可能是 {}、{{'a','b'}} 两种写法，统一取出为 {'a','b'}
if isempty(c)
	iconKinds = {};
else
	iconKinds = c{1};
end
end

function firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);

T = T(T.Phase == "Transfer" & T.Stimulus == "LightWater", {'Mouse', 'DateTime'});
if isempty(T)
	firstTransfer = table(string.empty(0, 1), NaT(0, 1), 'VariableNames', {'Mouse', 'DateTime'});
	return;
end

T = sortrows(T, {'Mouse', 'DateTime'});
[groupId, mouseName] = findgroups(T.Mouse);
firstDate = splitapply(@(x) x(1), T.DateTime, groupId);
firstTransfer = table(mouseName, firstDate, 'VariableNames', {'Mouse', 'DateTime'});
end

function activeTable = iBuildActiveCellTable(G, idx1s, baseMask, kSigma, errId)
if isempty(G)
	activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
	return;
end
S = UniExp.NtatsCellStrip(struct('Q', G));
X = iGetNtats3D(S, errId);
if isempty(X)
	activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
	return;
end
if size(X, 3) > 1
	XLane = squeeze(X(:, :, 1));
else
	XLane = squeeze(X);
end
if ~istable(S) || ~ismember('CellUID', S.Properties.VariableNames)
	error(errId, 'NtatsCellStrip result does not contain CellUID.');
end

baseMu = mean(XLane(:, baseMask), 2, 'omitnan');
baseSd = std(XLane(:, baseMask), 0, 2, 'omitnan');
v1 = XLane(:, idx1s);
isActive = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
activeTable = table(uint64(S.CellUID), logical(isActive), 'VariableNames', {'CellUID', 'IsActive'});
end

function X = iGetNtats3D(S, errId)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end

if isnumeric(nt)
	if ndims(nt) ~= 3
		error(errId, 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error(errId, 'Unsupported NTATS container type: %s', class(nt));
end

function [activeN, totalN] = iUniqueCounts(activeTable)
if isempty(activeTable)
	activeN = 0;
	totalN = 0;
	return;
end
[cellUID, idx] = unique(uint64(activeTable.CellUID), 'stable');
isActive = logical(activeTable.IsActive(idx));
activeN = nnz(isActive);
totalN = numel(cellUID);
end

function iPlotOnePie(ax, numN, denN, ttlText, ttlIcons, activeLabel, activeIcons, inactiveLabel)
% 普通饼图：灰底 + 单一强调色（参考 Guan-lab Nat Commun 2026 Fig.5k）
%   - 强调扇区 = 彩色粗体名称 + 黑色百分比
%   - 其余扇区 = 灰色粗体名称 + 黑色百分比
%   - 扇区间 1 pt 白色细缝，无图例、无边框、无刻度
%   - 标题与强调扇区标签均可带手绘矢量小图标（不用 emoji）
hold(ax, 'on');
if denN > 0
	vals = [numN, max(denN - numN, 0)];
else
	vals = [NaN, NaN];
end
if ~all(isfinite(vals)) || sum(vals) <= 0
	vals = [0, 1];
end

accentColor = [0, 0.6275, 0.9137];
grayFillColor = [0.80, 0.80, 0.80];
grayTextColor = [0.45, 0.45, 0.45];
cols = [accentColor; grayFillColor];
labelCols = [accentColor; grayTextColor];
names = {activeLabel, inactiveLabel};
iconKinds = activeIcons;

hP = pie(ax, vals);
if numel(hP) >= 4
	delete(hP(2:2:end));   % 去掉 pie 的自动外标签（导出时会被裁切）
end
for k = 1:numel(vals)
	hP(2 * k - 1).FaceColor = cols(k, :);
	hP(2 * k - 1).EdgeColor = 'w';
	hP(2 * k - 1).LineWidth = 1;
end
ax.Visible = 'off';
ax.DataAspectRatio = [1 1 1];

frac = vals(:) / sum(vals);

% --- 强调扇区（第 1 块，自 90° 顺时针起算）：标在饼右侧，图标修饰 Active/Reused 而不是阶段标题 ---
angMid1 = 90 - 0.5 * frac(1) * 360;
yMark = 1.02 * sind(angMid1);
yMark = min(max(yMark, -0.55), 0.75);
xMark = 0.95;

tActive = text(ax, xMark, yMark + 0.09, names{1}, 'Color', labelCols(1, :), 'FontWeight', 'bold', ...
	'FontSize', 6, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Clipping', 'off');
drawnow;
extA = tActive.Extent;

iconS = 0.11;      % 单图标半高（data 单位）
iconGap = 0.045;    % 图标间距
textGap = 0.05;     % 图标组与文字的间距
nIcon = numel(iconKinds);
iconW = nIcon * 2 * iconS + (nIcon - 1) * iconGap;
tActive.Position(1) = xMark + iconW + textGap;
cyIcon = tActive.Position(2) + extA(4) / 2;
for k = 1:nIcon
	cx = xMark + iconS + (k - 1) * (2 * iconS + iconGap);
	iDrawIcon(ax, iconKinds{k}, cx, cyIcon, iconS);
end
text(ax, xMark, yMark - 0.05, sprintf('%.1f%%', 100 * frac(1)), 'Color', 'k', ...
	'FontSize', 6, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'Clipping', 'off');

% --- 灰扇区：标在饼正下方居中 ---
if frac(2) > 0
	text(ax, 0, -1.35, names{2}, 'Color', labelCols(2, :), 'FontWeight', 'bold', ...
		'FontSize', 6, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Clipping', 'off');
	text(ax, 0, -1.43, sprintf('%.1f%%', 100 * frac(2)), 'Color', 'k', ...
		'FontSize', 6, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Clipping', 'off');
end

xlim(ax, [-1.60, 3.30]);
ylim(ax, [-1.83, 1.68]);

% --- 阶段标题：可带图标（第 3 个饼的分母就是 Learned 声水活跃细胞）---
if isempty(ttlIcons)
	text(ax, 0, 1.22, ttlText, 'Color', [0.25 0.25 0.25], 'FontSize', 6, ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Clipping', 'off');
else
	iDrawTitleWithIcons(ax, ttlText, ttlIcons, iconS, iconGap, textGap);
end
end

function iDrawTitleWithIcons(ax, ttlText, iconKinds, iconS, iconGap, textGap)
% 标题行：手绘矢量小图标 + 文字，整体水平居中于 x = 0
tTitle = text(ax, 0, 1.22, ttlText, 'Color', [0.25 0.25 0.25], 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Clipping', 'off');
drawnow;
ext = tTitle.Extent;
textW = ext(3);
textH = ext(4);

nIcon = numel(iconKinds);
iconW = nIcon * 2 * iconS + (nIcon - 1) * iconGap;
totalW = iconW + textGap + textW;
xStart = -totalW / 2;
tTitle.Position(1) = xStart + iconW + textGap + textW / 2;

cy = 1.22 + textH / 2;
for k = 1:nIcon
	cx = xStart + iconS + (k - 1) * (2 * iconS + iconGap);
	iDrawIcon(ax, iconKinds{k}, cx, cy, iconS);
end
end

function iDrawIcon(ax, kind, cx, cy, s)
% 手绘矢量小图标（替代 emoji），s = 半高，坐标为 data 单位
% 每个图标先按自身原始高度归一化到总高 2s，保证三者视觉尺寸一致
switch kind
	case 'speaker'
		colBody = [0.18 0.18 0.18];
		q = s / 0.74;   % 原始高 1.48 → 半高 0.74
		% 箱体
		patch(ax, cx + [-0.95 -0.44 -0.44 -0.95] * q, cy + [-0.28 -0.28 0.28 0.28] * q, ...
			colBody, 'EdgeColor', 'none');
		% 喇叭口
		patch(ax, cx + [-0.44 0.10 0.10 -0.44] * q, cy + [-0.28 -0.74 0.74 0.28] * q, ...
			colBody, 'EdgeColor', 'none');
		% 声波（两段弧）
		th = linspace(-0.85, 0.85, 30);
		for rr = [0.55 0.92]
			plot(ax, cx + (0.14 + rr * cos(th)) * q, cy + rr * sin(th) * q, '-', ...
				'Color', colBody, 'LineWidth', 1);
		end
	case 'bulb'
		colBulb = [0.96 0.64 0.09];
		colBase = [0.38 0.38 0.38];
		q = s / 0.80;   % 原始高 1.60 → 半高 0.80
		% 玻璃壳
		th = linspace(0, 2 * pi, 60);
		patch(ax, cx + 0.46 * q * cos(th), cy + 0.16 * q + 0.46 * q * sin(th), ...
			colBulb, 'EdgeColor', 'none');
		% 灯座
		patch(ax, cx + [-0.22 -0.18 0.18 0.22] * q, cy + [-0.98 -0.62 -0.62 -0.98] * q, ...
			colBase, 'EdgeColor', 'none');
		% 光线
		for ang = [90 45 135 18 162]
			x1 = cx + 0.68 * q * cosd(ang);
			y1 = cy + 0.16 * q + 0.68 * q * sind(ang);
			x2 = cx + 0.94 * q * cosd(ang);
			y2 = cy + 0.16 * q + 0.94 * q * sind(ang);
			plot(ax, [x1 x2], [y1 y2], '-', 'Color', colBulb, 'LineWidth', 1);
		end
	case 'drop'
		colDrop = [0.16 0.52 0.85];
		q = s;          % 原始高 2.00 → 半高 1.00
		xd = [0 0.24 0.44 0.48 0.36 0.18 0 -0.18 -0.36 -0.48 -0.44 -0.24];
		yd = [1.00 0.52 0.10 -0.34 -0.72 -0.92 -1.00 -0.92 -0.72 -0.34 0.10 0.52];
		patch(ax, cx + xd * q, cy + yd * q, colDrop, 'EdgeColor', 'none');
end
end

function outText = iCapitalizeLeadingLetter(inText)
outText = string(inText);
chars = char(outText);
idx = regexp(chars, '[A-Za-z]', 'once');
if isempty(idx)
	return;
end
chars(idx) = upper(chars(idx));
outText = string(chars);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
