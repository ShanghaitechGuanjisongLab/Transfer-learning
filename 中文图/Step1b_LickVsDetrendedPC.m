%% Step1b_LickVsDetrendedPC.m — Step 1b：去趋势 → PCA → 与舔水率的时滞耦合
%
% 为什么需要 1b：Step 1 只看**群体平均**（逐细胞 z 后跨细胞平均），若慢状态活在一个
% **与均值正交**的子空间里（部分细胞升、部分降 → 在均值里互相抵消），就完全看不见。
% Step 1 的结论是：群体平均的慢成分主要是单调漂移（5/9 个 block 的线性趋势解释 83–91% 方差），
% 且与舔水率无一致关系。本节把漂移先去掉，再看剩下的最大共享成分。
%
% 做法
%   ① 逐细胞**线性去趋势**（去掉光漂白/漂移）→ 重新 per-cell z-score
%   ② 对 细胞×时间 矩阵做 **PCA（SVD）**，取 PC1，报告方差解释率
%   ③ PC1 与舔水率都降到 **1 Hz** 再 **60 s 滑动平均**，做互相关并**扫时滞** −30~+30 s
%   ④ **null**：把舔水率循环平移半个 session，得到 r 的 null 分布（阴影带 = ±2 SD）
%
% 1) 依赖
%    - MATLAB R2023b，本项目 +TransferLearning 包
%    - 无需 Statistics Toolbox（用 svd + 手算相关）
%
% 2) 前置
%    - 数据源 TransferLearning.AudioLightBaseline
%    - ⚠ 舔水记录取自 **`Blocks.EventLog`（timetable）** —— 列名 `Event`，时间轴用 `Properties.RowTimes`
%    - ⚠ "舔" 事件不是单次舔（81% 相邻间隔 <10 ms），必须先按 **50 ms 最小间隔去抖**（见 Step 1）
%
% 3) 图注
%    图 A（每鼠一张）：行＝阶段。左列＝去趋势后的 PC1（1 Hz，60 s 滑动平均），
%                     右列＝舔水率（1 Hz，60 s 滑动平均）。两列同一时基。
%    图 B：PC1 × 舔水率的互相关随**时滞**的变化（正时滞＝舔水滞后于 PC1）；
%          阴影带＝循环平移 null 的 ±2 SD。
%
% 4) 代码

%% 0. 参数
mice       = ["yqn1018", "yqn0411", "yqn0133"];
phases     = ["Naive", "Learned", "Transfer", "Final"];
smoothSec  = 60;          % 1 Hz 序列上的滑动平均窗长（秒）
minIliSec  = 0.05;        % 舔水事件去抖的最小间隔（秒）
lagList    = -30:2:30;    % 时滞扫描（秒），正 = 舔水滞后于 PC1

%% 1. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile,'file'); matlab.project.loadProject(prjFile); end
end

DS = TransferLearning.AudioLightBaseline();
B = DS.Blocks; BS = DS.BlockSignals; DT = DS.DateTimes;
fprintf('=== Step 1b：去趋势 PC1 vs 舔水率（时滞耦合）===\n');
fprintf('平滑窗 = %g s（1 Hz 上），去抖间隔 = %g ms，时滞 %d~%d s\n\n', ...
	smoothSec, minIliSec*1000, min(lagList), max(lagList));

%% 2. 逐鼠逐阶段：计算 + 出图 A
statRows = {}; lagRows = {}; figs = struct();
for mouse = mice
	avail = strings(0,1); idxB = [];
	for phase = phases
		iB = iFindBlock(B, DT, mouse, phase);
		if isempty(iB); continue; end
		el = iCheckEventLog(B, iB);
		if sum(string(el.Event) == "舔") == 0; continue; end
		avail(end+1, 1) = phase; %#ok<SAGROW>
		idxB(end+1, 1) = iB; %#ok<SAGROW>
	end
	if isempty(avail); continue; end

	f = iNewFigure(char(mouse + "：去趋势 PC1 vs 舔水率"), [9, 2 * numel(avail)]);
	tlo = tiledlayout(f, numel(avail), 2, 'TileSpacing', 'compact', 'Padding', 'compact');

	for r = 1:numel(avail)
		iB = idxB(r); phase = avail(r); uid = B.BlockUID(iB);

		% ---- 钙：逐细胞去趋势 → z → PCA ----
		dt = iSeriesInterval(DT, B.DateTime(iB));
		rowIdx = find(BS.BlockUID == uid);
		[M, nSamp] = iCalciumMatrix(BS, rowIdx);
		[M, nCell] = iDetrendRowsZS(M);
		[pc1, varExp1] = iPca1Time(M);

		% ---- 舔水率（Blocks.EventLog 是 timetable）----
		el = B.EventLog{iB};
		lickT = seconds(el.Properties.RowTimes(string(el.Event) == "舔"));
		lickT = iDebounce(lickT, minIliSec);

		% ---- 都降到 1 Hz，再 60 s 滑动平均 ----
		nBin = floor(nSamp * dt);                       % 秒数
		tSec = (0:nSamp-1) * dt;
		binIdx = min(floor(tSec) + 1, nBin);            % 1..nBin
		pc1s = accumarray(binIdx(:), pc1(:), [nBin 1], @mean, NaN)';
		lickS = histcounts(lickT, 0:nBin) / 1;          % 次/s
		w = max(3, smoothSec);
		pc1Slow = movmean(pc1s, w, 'omitnan');
		lickSlow = movmean(lickS, w, 'omitnan');

		% ---- 出图 ----
		ax1 = nexttile(tlo, (r-1)*2 + 1);
		plot(ax1, (1:nBin)/60, pc1s, 'Color', [0.75 0.75 0.75]); hold(ax1, 'on');
		plot(ax1, (1:nBin)/60, pc1Slow, 'k'); hold(ax1, 'off');
		yline(ax1, 0, '-', 'Color', [0.9 0.9 0.9], 'HandleVisibility', 'off');
		box(ax1, 'off'); xlim(ax1, [0, nBin/60]);
		ylabel(ax1, sprintf('%s\n(PC1, a.u.)', phase));
		if r == 1; title(ax1, sprintf('去趋势 PC1（解释 %.1f%% 方差）', varExp1*100), 'FontWeight', 'normal'); end

		ax2 = nexttile(tlo, (r-1)*2 + 2);
		plot(ax2, (1:nBin)/60, lickS, 'Color', [0.70 0.85 0.95]); hold(ax2, 'on');
		plot(ax2, (1:nBin)/60, lickSlow, 'Color', [0 0.45 0.74]); hold(ax2, 'off');
		box(ax2, 'off'); xlim(ax2, [0, nBin/60]);
		ylabel(ax2, sprintf('%s\n(次/s)', phase));
		if r == 1; title(ax2, '舔水率（1 Hz）', 'FontWeight', 'normal'); end

		% ---- 时滞互相关（平滑 + 未平滑两套）+ null（循环平移半个 session）----
		rLag = nan(size(lagList)); rRaw = nan(size(lagList)); rNull = nan(size(lagList));
		for iL = 1:numel(lagList)
			[a, b] = iLagPair(pc1Slow, lickSlow, lagList(iL));
			rLag(iL) = iCorr(a, b);
			[a2, b2] = iLagPair(pc1s, lickS, lagList(iL));
			rRaw(iL) = iCorr(a2, b2);
			[c, d] = iLagPair(pc1Slow, lickSlow, lagList(iL) + round(nBin/2));
			rNull(iL) = iCorr(c, d);
		end
		lagRows(end+1, :) = {char(mouse), char(phase), lagList, rLag, rNull, rRaw}; %#ok<SAGROW>
		ok0 = lagList == 0;
		[rBest, iBest] = max(abs(rLag));
		[rRawBest, iRawBest] = max(abs(rRaw));
		statRows(end+1, :) = {char(mouse), char(phase), nCell, nBin/60, varExp1, ...
			rLag(ok0), rNull(ok0), lagList(iBest), rBest, ...
			rRaw(ok0), lagList(iRawBest), rRawBest, max(abs(rNull))}; %#ok<SAGROW>
	end
	xlabel(tlo, 'session 内时间（min）');
	TransferLearning.ExportStandardFigure(f, 1, sprintf('Step1b_DetrendedPC_%s.svg', mouse));
	figs.(matlab.lang.makeValidName(char(mouse))) = f;
end

%% 3. 图 B：时滞互相关曲线 + null 带
f2 = iNewFigure('Step1b lag coupling', [6, 4]);
ax = axes(f2);
hold(ax, 'on');
R = vertcat(lagRows{:, 4});
Rnull = vertcat(lagRows{:, 5});
nB = size(R, 1);
for i = 1:nB
	plot(ax, lagList, R(i, :), '-', 'Color', [0.80 0.80 0.80]);
end
muNull = mean(Rnull, 1, 'omitnan');
sdNull = std(Rnull, 0, 1, 'omitnan');
fill(ax, [lagList, fliplr(lagList)], [muNull - 2*sdNull, fliplr(muNull + 2*sdNull)], ...
	[0.85 0.90 0.95], 'EdgeColor', 'none', 'FaceAlpha', 0.7);
plot(ax, lagList, mean(R, 1, 'omitnan'), '-o', 'Color', [0 0 0]);
yline(ax, 0, '-', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
hold(ax, 'off');
box(ax, 'off');
xlabel(ax, '时滞（s；正 = 舔水滞后于 PC1）');
ylabel(ax, sprintf('r(PC1, 舔水率)（%d 个 block）', nB));
TransferLearning.ExportStandardFigure(f2, 1, 'Step1b_LagCoupling.svg');

fprintf('\n=== 汇总（r 为 Pearson；null = 舔水率循环平移 1/2 session）===\n');
stat = cell2table(statRows, 'VariableNames', ...
	{'Mouse','Phase','nCell','durMin','PC1方差解释','r_平滑_lag0','r_null','平滑最佳时滞s','r_平滑_best', ...
	'r_未平滑_lag0','未平滑最佳时滞s','r_未平滑_best','null最大|r|'});
disp(stat);
fprintf('\n单侧阈值（|r| 需超过）：null 的 95 分位 = %.3f，最大值 = %.3f\n', ...
	prctile(abs(Rnull(:)), 95), max(abs(Rnull(:))));
fprintf('Done.\n');

%% ===== Local functions =====
function iB = iFindBlock(B, DT, mouse, phase)
iB = [];
k = find(string(DT.Mouse) == mouse & string(DT.Phase) == phase, 1);
if isempty(k); return; end
iB = find(B.DateTime == DT.DateTime(k), 1);
end

function el = iCheckEventLog(B, iB)
% 舔水记录来自 Blocks.EventLog，且它必须是 timetable
el = B.EventLog{iB};
assert(istimetable(el) && ismember('Event', el.Properties.VariableNames), ...
	'Blocks.EventLog{%d} 不是含 Event 列的 timetable', iB);
end

function [M, nSamp] = iCalciumMatrix(BS, rowIdx)
% 细胞×时间矩阵（含 NaN 行保留，后续按列取 nanmean）
sig = BS.BlockSignal(rowIdx);
nSamp = numel(sig{1});
M = nan(numel(sig), nSamp);
for i = 1:numel(sig)
	v = double(sig{i});
	if numel(v) ~= nSamp; continue; end
	M(i, :) = v(:)';
end
end

function [Z, nCell] = iDetrendRowsZS(M)
% 逐行线性去趋势 → 逐行 z-score；全 NaN 的行剔除
t = (1:size(M,2))' - (size(M,2)+1)/2;
bad = all(~isfinite(M), 2);
M(bad, :) = [];
slope = nansum(M .* t', 2) / nansum(t.^2);
M = M - slope .* t';
mu = mean(M, 2, 'omitnan'); sd = std(M, 0, 2, 'omitnan');
Z = (M - mu) ./ sd;
nCell = size(Z, 1);
end

function [pc1, varExp1, load1] = iPca1Time(Z)
% 对 细胞×时间 矩阵做 SVD，返回 PC1 的时间过程、方差解释率、载荷
% 方向约定：使 |载荷| 最大的那个细胞载荷为正（否则 PC 符号任意）
Zc = Z - mean(Z, 2, 'omitnan');
[U, S, V] = svd(Zc, 'econ');
latent = diag(S).^2;
varExp1 = latent(1) / sum(latent);
pc1 = V(:, 1);
load1 = U(:, 1) * S(1, 1);
[~, iMax] = max(abs(load1));
if load1(iMax) < 0
	pc1 = -pc1; load1 = -load1;
end
end

function t = iDebounce(t, minIli)
t = sort(t(:));
if isempty(t); return; end
t = t([true; diff(t) > minIli]);
end

function [a, b] = iLagPair(x, y, lag)
% 取 x(t) 与 y(t+lag) 的重叠区；lag>0 表示 y 滞后
n = numel(x);
if lag >= 0
	a = x(1:n-lag); b = y(1+lag:n);
else
	a = x(1-lag:n); b = y(1:n+lag);
end
end

function r = iCorr(a, b)
ok = isfinite(a) & isfinite(b);
if sum(ok) < 5; r = NaN; return; end
a = a(ok); b = b(ok);
a = a - mean(a); b = b - mean(b);
r = (a * b') / sqrt((a * a') * (b * b'));
end

function dt = iSeriesInterval(DT, dtm)
k = find(DT.DateTime == dtm, 1);
if isempty(k) || ~isduration(DT.SeriesInterval(k))
	error('SeriesInterval 缺失：%s', string(dtm));
end
dt = seconds(DT.SeriesInterval(k));
end

function f = iNewFigure(figName, sizeCm)
f = figure('Color', 'w', 'Name', figName);
f.Units = 'centimeters';
f.Position(3:4) = sizeCm;
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, sizeCm];
f.PaperSize = sizeCm;
end
