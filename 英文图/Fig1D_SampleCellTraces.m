% Fig2 前面板：两个示例细胞的 trial 平均 z-score 轨迹（4 个条件）
%
% 样式参考 LEC 论文（管老师最近文献配色.pdf）Fig.4l：
%   . 4 个条件横向并排，共享 y 轴，段间仅留很窄的缝
%   . 每个条件 = 均值线 + 同色半透明 SEM 阴影带
%   . 事件用竖直虚线标出（cue 黑、water 红），底部注字
%   . L 形细轴（只留左/下），y 轴只标 0，顶部横排色块图例
%
% 条件与选细胞标准同前：
%   naive (audio only) / naive (audio-water) / learned (audio-water) / transfer (light-water)
%   cell a：z_learned > z_transfer > z_naiveAudioWater，且这些细胞里 z_transfer 最大
%   cell b：z_learned − z_transfer 最大

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
warning('off', 'UniExp:Exception:Block_must_warn');

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
xsSec = xsSec(:);
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx1s] = min(abs(xsSec - 1));
kSigma = 3;

D = iCollect(TransferLearning.AudioLightBaseline(), baseMask, idx1s, kSigma);
if isempty(D.uid)
	error('Fig2Sample:NoCells', 'no matched cells across the four conditions');
end

zN1 = D.M{1}(:, idx1s);
zN2 = D.M{2}(:, idx1s);
zL = D.M{3}(:, idx1s);
zT = D.M{4}(:, idx1s);

fprintf('\n=== candidate pool ===\n');
fprintf('matched learned-active cells = %d (from %d mice)\n', numel(D.uid), numel(unique(D.mouse)));
fprintf('mean z @1s : naiveAO %5.2f | naiveAW %5.2f | learned %5.2f | transfer %5.2f\n', ...
	mean(zN1, 'omitnan'), mean(zN2, 'omitnan'), mean(zL, 'omitnan'), mean(zT, 'omitnan'));

maskA = (zL > zT) & (zT > zN2) & isfinite(zL) & isfinite(zT) & isfinite(zN2);
fprintf('cells with z(learned) > z(transfer) > z(naive AW) = %d\n', nnz(maskA));
if nnz(maskA) == 0
	warning('Fig2Sample:NoMonotonic', 'no monotonic cell; fallback to max(zL - zT)');
	iA = iArgMax(zL - zT);
else
	idx = find(maskA);
	[~, k] = max(zT(idx));
	iA = idx(k);
end
iB0 = iArgMax(zL - zT);        % 未过滤时的最优（仅打印参考）
zMaxLearn = 20;                % 离群保护：z(learned) 超过此值视为基线 SD 过小/伪影
tmpB = zL - zT;
tmpB(~(isfinite(zL) & (zL <= zMaxLearn))) = -Inf;
iB = iArgMax(tmpB);
if iB ~= iB0
	fprintf('(cell b: idx %d with L-T=%.2f skipped, z(learned)=%.1f exceeds %.0f)\n', ...
		iB0, zL(iB0) - zT(iB0), zL(iB0), zMaxLearn);
end

fprintf('\n--- cell a : idx %d, mouse %s ---\n', iA, D.mouse(iA));
fprintf('   z @1s : naiveAO %6.2f | naiveAW %6.2f | learned %6.2f | transfer %6.2f\n', ...
	zN1(iA), zN2(iA), zL(iA), zT(iA));
fprintf('--- cell b : idx %d, mouse %s ---\n', iB, D.mouse(iB));
fprintf('   z @1s : naiveAO %6.2f | naiveAW %6.2f | learned %6.2f | transfer %6.2f | L-T %6.2f\n', ...
	zN1(iB), zN2(iB), zL(iB), zT(iB), zL(iB) - zT(iB));

%% ---- plot（参考 Fig.4l 的 4 段并排 + SEM 阴影）----
xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

figWCm = 7.5;
figHCm = 4.0;
f = figure('Color', 'w', 'Name', 'Fig2 sample cells');
f.Units = 'centimeters';
f.Position(3:4) = [figWCm, figHCm];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, figWCm, figHCm];
f.PaperSize = [figWCm, figHCm];

condNames = {'naive (audio only)', 'naive (audio-water)', 'learned (audio-water)', 'transfer (light-water)'};
% 顶部图例：两行显示全称（AO/AW 不用缩写）
condShort = {{'naive', 'audio only'}, {'naive', 'audio-water'}, {'learned', 'audio-water'}, {'transfer', 'light-water'}};
condCols = [0.60 0.60 0.60; 0.33 0.33 0.33; 0.16 0.52 0.85; 0.96 0.64 0.09];
colCue = [0.20 0.20 0.20];
colWater = [0.80 0.20 0.15];

pick = [iA, iB];
rowTags = {'cell a', 'cell b'};

% 布局（normalized）
axL = 0.105; axR = 0.985;
nC = 4;
gap = 0.020;
axW = (axR - axL - gap * (nC - 1)) / nC;
rowY = [0.580, 0.250];
rowH = 0.280;

% 两行共用一个 y 范围，这样右下角的比例尺对两个细胞都成立
lo = Inf; hi = -Inf;
for iR = 1:2
	for k = 1:nC
		y = D.M{k}(pick(iR), xMask); e = D.E{k}(pick(iR), xMask);
		v = [y(:) - e(:); y(:) + e(:); 0];
		v = v(isfinite(v));
		if ~isempty(v)
			lo = min(lo, min(v)); hi = max(hi, max(v));
		end
	end
end
if ~isfinite(lo) || ~isfinite(hi) || hi <= lo, lo = -1; hi = 1; end
pad = 0.08 * (hi - lo);
yl = [lo - pad, hi + pad];

for iR = 1:2
	for k = 1:nC
		x0 = axL + (k - 1) * (axW + gap);
		ax = axes(f, 'Position', [x0, rowY(iR), axW, rowH]); %#ok<LAXES>
		y = D.M{k}(pick(iR), xMask);
		e = D.E{k}(pick(iR), xMask);
		hold(ax, 'on');

		% SEM 阴影带
		iBand(ax, xsPlot, y, e, condCols(k, :));
		% 均值线
		plot(ax, xsPlot, y, '-', 'Color', condCols(k, :), 'LineWidth', 1);
		% 事件虚线
		plot(ax, [0 0], yl, '--', 'Color', colCue, 'LineWidth', 0.5);
		if k > 1    % naive (audio only) 没有水
			plot(ax, [1 1], yl, '--', 'Color', colWater, 'LineWidth', 0.5);
		end

		ylim(ax, yl);
		xlim(ax, [-1 2]);
		ax.Box = 'off';
		ax.YAxis.Visible = 'off';      % 参考图无 y 轴（幅度由右下角比例尺说明）
		ax.XAxis.TickValues = [];      % 同样不显示 x 刻度数字
		ax.LineWidth = 0.5;
		ax.FontSize = 6;
		if k == 1
			% cell a / cell b 放进第一格左上角，避免与顶部两行全称图例相撞
			text(ax, -0.34, 0.97, rowTags{iR}, 'Units', 'normalized', ...
				'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
				'FontSize', 6, 'FontWeight', 'bold', 'Color', [0.15 0.15 0.15]);
		end

		if iR == 2 && k == nC
			zU = iZUnit(yl(2) - yl(1));
			iScaleBarFig(f, 0.870, 0.087, 0.5 / 3 * axW, zU / (yl(2) - yl(1)) * rowH, '0.5 s', sprintf('%g z', zU));
		end
	end
end

% 顶部图例：彩色全称居中于各段（两行）
yLg = 0.945;
for k = 1:nC
	xc = axL + (k - 0.5) * axW + (k - 1) * gap;
	annotation(f, 'textbox', [xc - 0.13, yLg - 0.055, 0.26, 0.095], 'String', condShort{k}, ...
		'EdgeColor', 'none', 'FontSize', 6, 'Color', condCols(k, :), 'FontWeight', 'bold', ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FitBoxToText', 'off');
end

% 事件图标：cue 按条件的模态（声/光）+ 水，用与其他图一致的 emoji
axOv = axes(f, 'Position', [0 0 1 1], 'Visible', 'off', ...
	'XLim', [0 1], 'YLim', [0 1], 'Clipping', 'off'); %#ok<LAXES>
hold(axOv, 'on');
yEvt = 0.226;
cueEmoji = {'🔊', '🔊', '🔊', '💡'};
for k = 1:nC
	x0 = axL + (k - 1) * (axW + gap);
	iEmoji(axOv, cueEmoji{k}, x0 + axW / 3, yEvt);
	if k > 1    % naive (audio only) 没有水，不画水滴
		iEmoji(axOv, '💧', x0 + 2 * axW / 3, yEvt);
	end
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_Fig1D_SampleCellTraces.svg');
fprintf('\nWrote: %s\n', svgPath);

assignin('base', 'Fig1D_SampleCells', struct('iA', iA, 'iB', iB, 'uid', D.uid, ...
	'zN_AO', zN1, 'zN_AW', zN2, 'zL', zL, 'zT', zT, 'mouse', D.mouse));

%% ========== helpers ==========
function iDrawIcon(ax, kind, cx, cy, s, sxRatio)
% 手绘矢量小图标（声/光/水），s = 半高；sxRatio 用于补偿非等比例坐标系的横向拉伸
if nargin < 6, sxRatio = 1; end
switch kind
	case 'speaker'
		colBody = [0.18 0.18 0.18];
		q = s / 0.74;
		patch(ax, cx + [-0.95 -0.44 -0.44 -0.95] * q * sxRatio, cy + [-0.28 -0.28 0.28 0.28] * q, ...
			colBody, 'EdgeColor', 'none');
		patch(ax, cx + [-0.44 0.10 0.10 -0.44] * q * sxRatio, cy + [-0.28 -0.74 0.74 0.28] * q, ...
			colBody, 'EdgeColor', 'none');
		th = linspace(-0.85, 0.85, 24);
		for rr = [0.55 0.92]
			plot(ax, cx + (0.14 + rr * cos(th)) * q * sxRatio, cy + rr * sin(th) * q, '-', ...
				'Color', colBody, 'LineWidth', 0.5);
		end
	case 'bulb'
		colBulb = [0.96 0.64 0.09];
		colBase = [0.38 0.38 0.38];
		q = s / 0.80;
		th = linspace(0, 2 * pi, 48);
		patch(ax, cx + 0.46 * q * sxRatio * cos(th), cy + 0.16 * q + 0.46 * q * sin(th), ...
			colBulb, 'EdgeColor', 'none');
		patch(ax, cx + [-0.22 -0.18 0.18 0.22] * q * sxRatio, cy + [-0.98 -0.62 -0.62 -0.98] * q, ...
			colBase, 'EdgeColor', 'none');
		for ang = [90 45 135 18 162]
			plot(ax, cx + [0.68 0.94] * q * sxRatio * cosd(ang), ...
				cy + 0.16 * q + [0.68 0.94] * q * sind(ang), '-', ...
				'Color', colBulb, 'LineWidth', 0.5);
		end
	case 'drop'
		colDrop = [0.16 0.52 0.85];
		q = s;
		xd = [0 0.24 0.44 0.48 0.36 0.18 0 -0.18 -0.36 -0.48 -0.44 -0.24];
		yd = [1.00 0.52 0.10 -0.34 -0.72 -0.92 -1.00 -0.92 -0.72 -0.34 0.10 0.52];
		patch(ax, cx + xd * q * sxRatio, cy + yd * q, colDrop, 'EdgeColor', 'none');
end
end

function iEmoji(ax, s, cx, cy)
% 与其它图一致的 emoji 标注（声/光/水）
text(ax, cx, cy, s, 'FontName', 'Segoe UI Emoji', 'FontSize', 6, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

function iBand(ax, x, y, e, col)
% 同色半透明 SEM 阴影带
x = x(:); y = y(:); e = e(:);
ok = isfinite(y) & isfinite(e);
if nnz(ok) < 2, return; end
xg = [x(ok); flipud(x(ok))];
yg = [y(ok) + e(ok); flipud(y(ok) - e(ok))];
h = patch(ax, xg, yg, col, 'EdgeColor', 'none', 'FaceAlpha', 0.25);
if isprop(h, 'HandleVisibility'), h.HandleVisibility = 'off'; end
end

function zUnit = iZUnit(span)
% 选一个「好看」的信号强度刻度（1/2/5×10^n），大约占纵轴 20%
cand = [1 2 5 10 20 50 100 200];
ok = cand <= 0.22 * span;
if any(ok)
	zUnit = cand(find(ok, 1, 'last'));
else
	zUnit = span / 5;
end
end

function iScaleBar(ax, tUnit, zUnit)
% 右下角的 L 形比例尺：横 = 时间，纵 = 信号强度（z）
yl = ylim(ax);
span = yl(2) - yl(1);
xc = 1.95 - tUnit;               % 横线终点贴右侧
yc = yl(1) + 0.06 * span;
col = [0.20 0.20 0.20];
plot(ax, [xc, 1.95], [yc, yc], '-', 'Color', col, 'LineWidth', 0.75);
plot(ax, [xc, xc], [yc, yc + zUnit], '-', 'Color', col, 'LineWidth', 0.75);
text(ax, xc + tUnit / 2, yc - 0.03 * span, sprintf('%g s', tUnit), 'FontSize', 6, ...
	'Color', col, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
text(ax, xc - 0.03, yc + zUnit / 2, sprintf('%g z', zUnit), 'FontSize', 6, ...
	'Color', col, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end

function iScaleBarFig(f, x0, y0, w, h, tLabel, zLabel)
% 图右下角的「反 L」比例尺：横线在底部，竖线在右端向上
%   形状：      │ 5 z
%               │
%              ─┴─────
%               0.5 s
col = [0.20 0.20 0.20];
annotation(f, 'line', [x0, x0 + w], [y0, y0], 'LineWidth', 0.75, 'Color', col);
annotation(f, 'line', [x0 + w, x0 + w], [y0, y0 + h], 'LineWidth', 0.75, 'Color', col);
% 时间：横线下方居中（下移，避免贴着横线）
annotation(f, 'textbox', [x0 + w / 2 - 0.055, y0 - 0.058, 0.110, 0.030], 'String', tLabel, ...
	'EdgeColor', 'none', 'FontSize', 6, 'Color', col, 'Margin', 0, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
% 信号强度：放在竖线右侧
annotation(f, 'textbox', [x0 + w + 0.006, y0 + h - 0.016, 0.080, 0.030], 'String', zLabel, ...
	'EdgeColor', 'none', 'FontSize', 6, 'Color', col, 'Margin', 0, ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

function i = iArgMax(v)
v(~isfinite(v)) = -Inf;
[~, i] = max(v);
end

function D = iCollect(DS, baseMask, idx1s, kSigma)
D = struct('M', {{zeros(0,48), zeros(0,48), zeros(0,48), zeros(0,48)}}, ...
	'E', {{zeros(0,48), zeros(0,48), zeros(0,48), zeros(0,48)}}, ...
	'uid', uint64.empty(0,1), 'mouse', strings(0,1));

TL = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
TT = DS.TableQuery(["Mouse","DateTime"], Phase="Transfer", Stimulus="LightWater", Design="LightWater");
TNO = DS.TableQuery(["Mouse","DateTime"], Phase="Naive", Stimulus="AudioOnly");
TNW = DS.TableQuery(["Mouse","DateTime"], Phase="Naive", Stimulus="AudioWater");
if isempty(TL) || isempty(TT) || isempty(TNO) || isempty(TNW), return; end

S = innerjoin(renamevars(groupsummary(TL, "Mouse", "max", "DateTime"), 'max_DateTime', 'LastLearned'), ...
	renamevars(groupsummary(TT, "Mouse", "min", "DateTime"), 'min_DateTime', 'FirstTransfer'), 'Keys', 'Mouse');
S = innerjoin(S, renamevars(groupsummary(TNO, "Mouse", "max", "DateTime"), 'max_DateTime', 'LastNaiveAO'), 'Keys', 'Mouse');
S = innerjoin(S, renamevars(groupsummary(TNW, "Mouse", "max", "DateTime"), 'max_DateTime', 'LastNaiveAW'), 'Keys', 'Mouse');
fprintf('mice with all four sessions = %d\n', height(S));

% 试次计数用一张全表，避免逐条件重新查询
Tall = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus"]);
Tall.Mouse = string(Tall.Mouse);
Tall.Phase = string(Tall.Phase);
Tall.Stimulus = string(Tall.Stimulus);
Tall.DateTime = datetime(Tall.DateTime);
if ~isempty(Tall.DateTime.TimeZone), Tall.DateTime.TimeZone = ''; end

for i = 1:height(S)
	m = string(S.Mouse(i));
	dts = [S.LastNaiveAO(i), S.LastNaiveAW(i), S.LastLearned(i), S.FirstTransfer(i)];
	ph = ["Naive", "Naive", "Learned", "Transfer"];
	st = ["AudioOnly", "AudioWater", "AudioWater", "LightWater"];

	M = cell(1, 4); E = cell(1, 4); U = cell(1, 4);
	MED = [];
	ok = true;
	for k = 1:4
		q = struct('Mouse', m, 'Phase', ph(k), 'Stimulus', st(k), 'DateTime', dts(k));
		GM = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Mean);
		GS = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Std);
		if isempty(GM) || isempty(GS), ok = false; break; end
		[Xm, u, Xs] = iUniqPair(GM, GS);
		if isempty(Xm), ok = false; break; end
		if k == 3
			% 与 Fig2 热图一致：learned-active 用 Median 聚合的 1 s 值判定
			GMed = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
			[Xmed, umed] = iUniq(GMed);
			if ~isequal(u, umed), ok = false; break; end
			MED = Xmed;
		end
		nt = nnz(Tall.Mouse == m & Tall.Phase == ph(k) & Tall.Stimulus == st(k) ...
			& Tall.DateTime == dts(k));
		M{k} = Xm; E{k} = Xs ./ sqrt(max(nt, 1)); U{k} = u;
	end
	if ~ok, continue; end

	common = U{1};
	for k = 2:4, common = intersect(common, U{k}, 'stable'); end
	if numel(common) < 3, continue; end
	idx = cell(1, 4);
	for k = 1:4
		[~, idx{k}] = ismember(common, U{k});
	end

	Xm3 = M{3}(idx{3}, :);
	Xmed3 = MED(idx{3}, :);
	bMu = mean(Xmed3(:, baseMask), 2, 'omitnan');
	bSd = std(Xmed3(:, baseMask), 0, 2, 'omitnan');
	v1 = Xmed3(:, idx1s);
	keep = isfinite(v1) & isfinite(bMu) & isfinite(bSd) & (v1 > bMu + kSigma * bSd);
	if ~any(keep), continue; end

	for k = 1:4
		D.M{k} = [D.M{k}; M{k}(idx{k}(keep), :)];
		D.E{k} = [D.E{k}; E{k}(idx{k}(keep), :)];
	end
	D.uid = [D.uid; common(keep)];
	D.mouse = [D.mouse; repmat(m, nnz(keep), 1)];
end
end

function [Xm, u, Xs] = iUniqPair(GM, GS)
Xm = iMat(GM.NTATS);
u = uint64(GM.CellUID);
[u, iu] = unique(u, 'stable');
Xm = Xm(iu, :);
Xs = iMat(GS.NTATS);
us = uint64(GS.CellUID);
[us, ius] = unique(us, 'stable');
Xs = Xs(ius, :);
if ~isequal(u, us)
	Xm = zeros(0, 48); u = uint64.empty(0, 1); Xs = zeros(0, 48);
end
end

function [X, uid] = iUniq(G)
X = iMat(G.NTATS);
uid = uint64(G.CellUID);
[u, iu] = unique(uid, 'stable');
uid = u;
X = X(iu, :);
end

function X = iMat(X)
if isa(X, 'MATLAB.DataTypes.NDTable'), X = X.Data; end
X = double(X);
if ndims(X) == 3, X = squeeze(X(:, :, 1)); end
end
