% English FigS1I: Venn/欧拉图 —— 全细胞 vs Learned 声水活跃 vs Transfer 光水活跃
%
% 外圈(最大圆) = 该队列全部被成像细胞（Learned 与 Transfer 数据集的细胞并集）
% 内圈 1(A, 蓝) = Learned 阶段对声水(AudioWater)活跃的细胞（active 判据：cue +1 s 处 z > 基线均值 + 3σ）
% 内圈 2(B, 橙) = Transfer 首个光水(LightWater)训练单元中活跃的细胞
% A∩B = 复用细胞（Learned 活跃且在 Transfer 首块重新激活）
%
% 几何：圆的**面积**严格正比于细胞数（A/B 半径 = sqrt(n/nAll)），
% 两圆圆心距 d 由「交集面积 = nAB 对应面积」数值求解，因此交集大小也是真实比例。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('FigS1I:No1s', 'Cannot find sample close to 1s.'); end
kSigma = 3;

%% --- A: Learned AudioWater active ---
qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
GLearned = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
learnedTable = iBuildActiveCellTable(GLearned, idx1s, baseMask, kSigma, 'FigS1I:BadNTATS');
learnedAllIDs = unique(uint64(learnedTable.CellUID));
learnedActiveIDs = unique(uint64(learnedTable.CellUID(logical(learnedTable.IsActive))));

%% --- B: Transfer first LightWater block active ---
firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS);
transferTables = cell(height(firstTransfer), 1);
for iMouse = 1:height(firstTransfer)
	qTransferOne = struct('Stimulus', 'LightWater', 'DateTime', firstTransfer.DateTime(iMouse));
	GTransferOne = DS.QueryNTATS(qTransferOne, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	transferTables{iMouse} = iBuildActiveCellTable(GTransferOne, idx1s, baseMask, kSigma, 'FigS1I:BadNTATS');
end
if isempty(transferTables)
	transferTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
else
	transferTable = vertcat(transferTables{:});
end
transferAllIDs = unique(uint64(transferTable.CellUID));
transferActiveIDs = unique(uint64(transferTable.CellUID(logical(transferTable.IsActive))));

%% --- counts ---
allIDs = union(learnedAllIDs, transferAllIDs);
nAll = numel(allIDs);
nA = numel(learnedActiveIDs);
nB = numel(transferActiveIDs);
nAB = numel(intersect(learnedActiveIDs, transferActiveIDs));
nAonly = nA - nAB;
nBonly = nB - nAB;
nNone = nAll - nA - nB + nAB;

fprintf('=== FigS1I Venn ===\n');
fprintf('All cells        = %d\n', nAll);
fprintf('A  learned AW active = %d (%.2f%% of all)\n', nA, 100 * nA / nAll);
fprintf('B  transfer LW active= %d (%.2f%% of all)\n', nB, 100 * nB / nAll);
fprintf('A n B (reused)   = %d (%.2f%% of all, %.1f%% of A, %.1f%% of B)\n', ...
	nAB, 100 * nAB / nAll, 100 * nAB / nA, 100 * nAB / nB);
fprintf('A only = %d | B only = %d | neither = %d\n', nAonly, nBonly, nNone);

%% --- geometry ---
% 只有内圆 A / B 及其交集严格按比例：
%   rA : rB = sqrt(nA : nB)，交集面积 / (π rB²) = nAB / nB
% 外圆仅作示意（半径 = 1），内圆整体缩放到「包围半径 = 0.78 R」，
% 这样内圆足够大、可以把文字写进去。
rB0 = 1;
rA0 = sqrt(nA / nB);
targetLens0 = (nAB / nB) * pi * rB0^2;
lo = abs(rA0 - rB0) + 1e-9;
hi = rA0 + rB0 - 1e-9;
if targetLens0 >= pi * min(rA0, rB0)^2
	d0 = lo;
else
	d0 = fzero(@(dd) iLensArea(dd, rA0, rB0) - targetLens0, [lo, hi]);
end
s = 0.90 / (d0 / 2 + rA0);      % 缩放系数（内圆外接半径 = 0.90 R）
rA = s * rA0;
rB = s * rB0;
d = s * d0;
cA = [-d / 2, 0];
cB = [d / 2, 0];
fprintf('geometry: rA=%.3f rB=%.3f d=%.3f (rA:rB=%.3f, expect %.3f)\n', ...
	rA, rB, d, rA / rB, sqrt(nA / nB));

%% --- draw ---
figWCm = 4.5;
figHCm = 4.0;
f = figure('Color', 'w', 'Name', 'English FigS1I Cell Venn');
f.Units = 'centimeters';
f.Position(3:4) = [figWCm, figHCm];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, figWCm, figHCm];
f.PaperSize = [figWCm, figHCm];

ax = axes(f, 'Units', 'normalized', 'Position', [0.05, 0.02, 0.90, 0.94]);hold(ax, 'on');
ax.Visible = 'off';
ax.DataAspectRatio = [1 1 1];

colA = [0.16 0.52 0.85];
colB = [0.96 0.64 0.09];
colAB = [0.42 0.24 0.55];
fillA = [0.84 0.91 0.97];
fillB = [0.99 0.91 0.80];
edgeAll = [0.25 0.25 0.25];

th = linspace(0, 2 * pi, 400);

% 外圈：全部细胞（无填充）
plot(ax, cos(th), sin(th), '-', 'Color', edgeAll, 'LineWidth', 1);

% A / B
patch(ax, cA(1) + rA * cos(th), cA(2) + rA * sin(th), fillA, ...
	'EdgeColor', colA, 'LineWidth', 0.75);
patch(ax, cB(1) + rB * cos(th), cB(2) + rB * sin(th), fillB, ...
	'EdgeColor', colB, 'LineWidth', 0.75);

% 交集（lens）
[Xl, Yl] = iLensPolygon(cA, rA, cB, rB);
patch(ax, Xl, Yl, colAB, 'EdgeColor', colAB, 'LineWidth', 0.75);

% ---- 文字标注 ----
fs = 6;
% 外圈总数：放在圈外，不写 100%
text(ax, 0, 1.20, 'all cells', 'FontSize', fs, 'Color', [0.25 0.25 0.25], ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');

% 各区域水平中心：按「文字所在高度」处的月牙区中心算，避免文字压到圆边
yRef = 0.17;
hA = sqrt(max(rA^2 - yRef^2, 0));
hB = sqrt(max(rB^2 - yRef^2, 0));
xAonly = 0.5 * ((cA(1) - rA) + (cB(1) - hB));
xBonly = 0.5 * ((cA(1) + hA) + (cB(1) + rB)) - 0.015;   % 稍向左留白
xLensL = max(cA(1) - rA, cB(1) - rB);
xLensR = min(cA(1) + rA, cB(1) + rB);
xLens = 0.5 * (xLensL + xLensR);

% A only / B only：直接写在内圆��牙区里
iZoneLabel(ax, xAonly, sprintf('%.1f%%', 100 * nAonly / nAll), {'speaker', 'drop'}, colA);
iZoneLabel(ax, xBonly, sprintf('%.1f%%', 100 * nBonly / nAll), {'bulb', 'drop'}, colB);

% 交集太小（仅 0.1 R 宽），引线引到圆外
plot(ax, [xLens, xLens + 0.045], [0.02, 0.44], '-', 'Color', colAB, 'LineWidth', 0.5);
text(ax, xLens + 0.05, 0.48, sprintf('%.1f%%', 100 * nAB / nAll), 'FontSize', fs, 'Color', colAB, ...
	'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

% neither
text(ax, 0, -0.72, sprintf('%.1f%%', 100 * nNone / nAll), 'FontSize', fs, 'Color', [0.45 0.45 0.45], ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

xlim(ax, [-1.05, 1.05]);
ylim(ax, [-1.05, 1.05]);

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS1I_CellVenn.svg');
fprintf('Wrote: %s\n', svgPath);

summary = table(nAll, nA, nB, nAB, nAonly, nBonly, nNone, ...
	'VariableNames', {'AllCells', 'LearnedActive', 'TransferActive', 'Reused', 'LearnedOnly', 'TransferOnly', 'Neither'});
assignin('base', 'FigS1I_VennSummary', summary);

%% ========== Local helpers ==========

function iLeader(ax, x0, y0, x1, y1)
% 从区域中心引一条 0.5 pt 细线到标注位置
plot(ax, [x0 x1], [y0 y1], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.5);
end

function iZoneLabel(ax, cx, pctTxt, iconKinds, col)
% 三行标注：百分比 / 图标组 / active，垂直居中于 (cx, 0)
fs = 6;
lineH = 0.17;
s = 0.065;
iOffsets = linspace(-0.09, 0.09, numel(iconKinds));
text(ax, cx, lineH, pctTxt, 'FontSize', fs, 'Color', col, 'FontWeight', 'bold', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
text(ax, cx, -lineH, 'active', 'FontSize', fs, 'Color', col, 'FontWeight', 'bold', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
for k = 1:numel(iconKinds)
	iDrawIcon(ax, iconKinds{k}, cx + iOffsets(k), 0, s);
end
end

function iDrawIcon(ax, kind, cx, cy, s)
% 手绘矢量小图标（声/光/水），s = 半高，坐标为 data 单位
switch kind
	case 'speaker'
		colBody = [0.18 0.18 0.18];
		q = s / 0.74;
		patch(ax, cx + [-0.95 -0.44 -0.44 -0.95] * q, cy + [-0.28 -0.28 0.28 0.28] * q, ...
			colBody, 'EdgeColor', 'none');
		patch(ax, cx + [-0.44 0.10 0.10 -0.44] * q, cy + [-0.28 -0.74 0.74 0.28] * q, ...
			colBody, 'EdgeColor', 'none');
		th = linspace(-0.85, 0.85, 24);
		for rr = [0.55 0.92]
			plot(ax, cx + (0.14 + rr * cos(th)) * q, cy + rr * sin(th) * q, '-', ...
				'Color', colBody, 'LineWidth', 0.5);
		end
	case 'bulb'
		colBulb = [0.96 0.64 0.09];
		colBase = [0.38 0.38 0.38];
		q = s / 0.80;
		th = linspace(0, 2 * pi, 48);
		patch(ax, cx + 0.46 * q * cos(th), cy + 0.16 * q + 0.46 * q * sin(th), ...
			colBulb, 'EdgeColor', 'none');
		patch(ax, cx + [-0.22 -0.18 0.18 0.22] * q, cy + [-0.98 -0.62 -0.62 -0.98] * q, ...
			colBase, 'EdgeColor', 'none');
		for ang = [90 45 135 18 162]
			plot(ax, cx + [0.68 0.94] * q * cosd(ang), ...
				cy + 0.16 * q + [0.68 0.94] * q * sind(ang), '-', ...
				'Color', colBulb, 'LineWidth', 0.5);
		end
	case 'drop'
		colDrop = [0.16 0.52 0.85];
		q = s;
		xd = [0 0.24 0.44 0.48 0.36 0.18 0 -0.18 -0.36 -0.48 -0.44 -0.24];
		yd = [1.00 0.52 0.10 -0.34 -0.72 -0.92 -1.00 -0.92 -0.72 -0.34 0.10 0.52];
		patch(ax, cx + xd * q, cy + yd * q, colDrop, 'EdgeColor', 'none');
end
end

function area = iLensArea(d, r1, r2)
% 两圆（半径 r1,r2，圆心距 d）交叠面积
if d <= 0
	area = pi * min(r1, r2)^2;
	return;
end
if d >= r1 + r2
	area = 0;
	return;
end
a1 = (d^2 + r1^2 - r2^2) / (2 * d);
a1 = min(max(a1 / r1, -1), 1);
a2 = (d^2 + r2^2 - r1^2) / (2 * d);
a2 = min(max(a2 / r2, -1), 1);
area = r1^2 * acos(a1) + r2^2 * acos(a2) ...
	- 0.5 * sqrt(max((-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2), 0));
end

function [X, Y] = iLensPolygon(c1, r1, c2, r2)
% 交集透镜轮廓：A 圆上落在 B 内的弧 + B 圆上落在 A 内的弧
d = norm(c2 - c1);
a = (d^2 + r1^2 - r2^2) / (2 * d);
h = sqrt(max(r1^2 - a^2, 0));
u = (c2 - c1) / d;
nv = [-u(2), u(1)];
Pm = c1 + a * u;
P1 = Pm + h * nv;
P2 = Pm - h * nv;

angA1 = atan2(P1(2) - c1(2), P1(1) - c1(1));
angA2 = atan2(P2(2) - c1(2), P2(1) - c1(1));
tA = iArcDir(c1, r1, c2, r2, angA1, angA2);

angB1 = atan2(P2(2) - c2(2), P2(1) - c2(1));
angB2 = atan2(P1(2) - c2(2), P1(1) - c2(1));
tB = iArcDir(c2, r2, c1, r1, angB1, angB2);

X = [c1(1) + r1 * cos(tA), c2(1) + r2 * cos(tB)];
Y = [c1(2) + r1 * sin(tA), c2(2) + r2 * sin(tB)];
end

function t = iArcDir(cSelf, rSelf, cOther, rOther, a1, a2)
% 从角 a1 到 a2，选择落在 cOther 圆内的那一侧弧
dAng = mod(a2 - a1, 2 * pi);
mid = a1 + dAng / 2;
if hypot(cSelf(1) + rSelf * cos(mid) - cOther(1), cSelf(2) + rSelf * sin(mid) - cOther(2)) > rOther
	dAng = dAng - 2 * pi;
end
t = a1 + linspace(0, dAng, 240);
end

function firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone), T.DateTime.TimeZone = ''; end
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

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
