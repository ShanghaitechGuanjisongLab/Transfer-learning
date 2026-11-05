%% Step1c_LickCD2VsCalcium.m — Step 1 重做：用 BlockTags.CD2 作舔水轨（全 11 只鼠）
%
% 为什么重做（2026-10-10）：Step 1 / Step 1b 把 EventLog 的舔水事件打到钙信号格上时用了
%   dt = DateTimes.SeriesInterval = 0.12573 s，而**真实采样间隔是 0.125 s（8 Hz 整）**。
%   0.58% 的比率误差在 25 min 会话上累积成 **~8.7 s 的线性漂移** → 舔水序列相对钙信号错位 →
%   原“无耦合”的负结果**不可信**。
%
% 本脚本改用 **`Blocks.BlockTags.CD2`**：
%   - `Blocks.BlockTags` 是整段连续模拟通道，长度与 `BlockSignal` **完全相同**（112/114 个 block）
%   - **CD1 = cue 标记，CD2 = 舔水记录**（基线 ~512.7，舔水时跳到 ~590–746）
%   - 与钙信号**天然同格**，无需任何时间映射 → 彻底回避上述时间基陷阱
%   - 且**覆盖全部 11 只鼠 × 4 阶段**（不再受“只有 3 只鼠有舔水事件”限制）
%
% 做法
%   ① 舔水二值指示：CD2 > median(CD2) + 5
%   ② 钙：逐细胞 z 后跨细胞平均（popMean）；同时算“逐细胞线性去趋势 → z → PC1”
%   ③ 两者都降到 1 Hz 再 60 s 滑动平均；算 r 与“慢成分被线性趋势解释的份额”R²
%   ④ 扫时滞 −30~+30 s；null = 舔水轨循环平移 1/2 session
%
% 1) 依赖：MATLAB R2023b，本项目 +TransferLearning 包（corr 需 Statistics Toolbox）
% 2) 前置：数据源 TransferLearning.AudioLightBaseline
% 3) 图注：两个面板＝按阶段分组的相关系数（均值±SEM，每只鼠一个值，n＝鼠数）。
%          左＝群体平均钙 vs 舔水；右＝去趋势 PC1 vs 舔水。虚线＝null 的 95 分位。
% 4) 代码

%% 0. 参数
phases    = ["Naive", "Learned", "Transfer", "Final"];
smoothSec = 60;
thrCD2    = 5;               % CD2 高于基线多少算“正在舔”
lagList   = -30:2:30;

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
mice = unique(string(DT.Mouse))';   % ⚠ 必须转成行向量：for 按列迭代，列向量只会循环 1 次
fprintf('=== Step 1c：CD2 舔水轨 vs 群体钙（%d 只鼠 × %d 阶段）===\n', numel(mice), numel(phases));
fprintf('dt 固定 = 0.125 s（不用 SeriesInterval，它偏大 0.58%%）\n\n');

%% 2. 逐 block 计算
% ⚠ 采样率必须逐 block 估：`DateTimes.SeriesInterval` 不可靠（8 Hz 与 30 Hz 的 block 存同一个值）。
%   实测 100 个 block ≈8 Hz，12 个 ≈30 Hz（yqn0020 全部 + yqn0240 两块）。
rBlk = iBlockRate(DS, B, DT);
statRows = {}; lagRows = {};
for mouse = mice
	for phase = phases
		iB = iFindBlock(B, DT, mouse, phase);
		if isempty(iB); continue; end
		uid = B.BlockUID(iB);
		rowIdx = find(BS.BlockUID == uid, 1, 'first');
		if isempty(rowIdx); continue; end
		nSamp = numel(BS.BlockSignal{rowIdx});
		bt = B.BlockTags{iB};
		if ~istable(bt) || height(bt) ~= nSamp; continue; end
		cd2 = bt.CD2(:)';

		% 舔水指示
		base = median(cd2);
		lickBin = double(cd2 > base + thrCD2);
		if mean(lickBin) == 0; continue; end

		% 钙：popMean 与去趋势 PC1
		[M, ~] = iCalciumMatrix(BS, uid, nSamp);
		Z = iRowsZS(M);
		popMean = mean(Z, 1, 'omitnan');
		[M2, nCell] = iDetrendRowsZS(M);
		[pc1, varExp1] = iPca1Time(M2);

		% 降到 1 Hz + 60 s 平滑
		dt = 1/rBlk(iB);
		nBin = floor(nSamp * dt);
		binIdx = min(floor((0:nSamp-1) * dt) + 1, nBin);
		to1Hz = @(x) movmean(accumarray(binIdx(:), x(:), [nBin 1], @mean, NaN)', max(3, smoothSec), 'omitnan');
		pmS = to1Hz(popMean); pcS = to1Hz(pc1); lkS = to1Hz(lickBin);
		tMin = (1:nBin)/60;

		% 统计
		ok = isfinite(pmS) & isfinite(pcS) & isfinite(lkS);
		pm = pmS(ok)'; pc = pcS(ok)'; lk = lkS(ok)'; tt = tMin(ok)';
		rNull = iLagScan(pm, iCircShift(lk, round(sum(ok)/2)), lagList);
		statRows(end+1, :) = {char(mouse), char(phase), nCell, nBin/60, varExp1, ...
			iCorr(pm, lk), iCorr(pc, lk), iCorr(iDetrend(pm), iDetrend(lk)), ...
			iCorr(pm, tt)^2, max(abs(rNull))}; %#ok<SAGROW>
		lagRows(end+1, :) = {char(mouse), char(phase), iLagScan(pm, lk, lagList), iLagScan(pc, lk, lagList)}; %#ok<SAGROW>
		fprintf('  %-9s %-9s cells=%3d  %.0f min  PC1var=%.1f%%  r(popMean,lick)=%+.2f  r(PC1,lick)=%+.2f\n', ...
			mouse, phase, nCell, nBin/60, varExp1*100, iCorr(pm, lk), iCorr(pc, lk));
	end
end

%% 3. 汇总
stat = cell2table(statRows, 'VariableNames', ...
	{'Mouse','Phase','nCell','durMin','PC1方差解释','r_popMean_lick','r_PC1_lick', ...
	'r_去趋势_popMean_lick','R2_漂移','null最大|r|'});
fprintf('\n=== 汇总 ===\n'); disp(stat);
fprintf('r_popMean_lick        ：中位 %+.2f，范围 %+.2f ~ %+.2f\n', ...
	median(stat.('r_popMean_lick'),'omitnan'), min(stat.('r_popMean_lick')), max(stat.('r_popMean_lick')));
fprintf('r_去趋势_popMean_lick ：中位 %+.2f，范围 %+.2f ~ %+.2f\n', ...
	median(stat.('r_去趋势_popMean_lick'),'omitnan'), min(stat.('r_去趋势_popMean_lick')), max(stat.('r_去趋势_popMean_lick')));

f = iNewFigure('Step1c summary', [7.5, 4]);
tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
iSummaryPanel(tlo, 1, stat, phases, 'r_popMean_lick', '群体平均钙 × 舔水（未去趋势）');
iSummaryPanel(tlo, 2, stat, phases, 'r_去趋势_popMean_lick', '去趋势后 × 舔水');
TransferLearning.ExportStandardFigure(f, 1, 'Step1c_CD2_vs_Calcium_Summary.svg');

fprintf('\nnull 最大 |r| 中位 = %.3f（逐 block 比较用）\n', median(stat.('null最大|r|'), 'omitnan'));
fprintf('Done.\n');

%% ===== Local functions =====
function iB = iFindBlock(B, DT, mouse, phase)
iB = [];
k = find(string(DT.Mouse) == mouse & string(DT.Phase) == phase, 1);
if isempty(k); return; end
iB = find(B.DateTime == DT.DateTime(k), 1);
end

function r = iBlockRate(DS, B, DT)
% 逐 block 估计真实采样率（Hz）。`DateTimes.SeriesInterval` 不可靠。
% ⚠ `Blocks` 与 `DateTimes` 行序不同，鼠标签必须按 DateTime 对齐后取。
r = nan(height(B), 1);
bMouse = strings(height(B), 1);
for i = 1:height(B)
	k = find(DT.DateTime == B.DateTime(i), 1);
	if ~isempty(k); bMouse(i) = string(DT.Mouse(k)); end
	tt = DS.Trials.Time(DS.Trials.BlockUID == B.BlockUID(i));
	sr = DS.Trials.SampleRange(DS.Trials.BlockUID == B.BlockUID(i), :);
	if numel(tt) < 5 || ~istable(sr); continue; end
	n = min(numel(tt), height(sr));
	dR = diff(double(sr.Tag(1:n))); dT = seconds(diff(tt(1:n)));
	ok = dT > 0 & dR > 0;
	if sum(ok) < 4; continue; end
	r(i) = median(dR(ok) ./ dT(ok));
end
for m = reshape(unique(bMouse), 1, [])
	if m == ""; continue; end
	sel = find(bMouse == m & isfinite(r));
	if isempty(sel); continue; end
	for g = [false, true]
		s = sel((r(sel) >= 15) == g);
		if ~isempty(s); v = median(r(s)); r(s) = v; end
	end
end
r(isnan(r)) = 8;
end

function [M, nSamp] = iCalciumMatrix(BS, uid, nSamp)
rowIdx = find(BS.BlockUID == uid);
sig = BS.BlockSignal(rowIdx);
M = nan(numel(sig), nSamp);
for i = 1:numel(sig)
	v = double(sig{i});
	if numel(v) ~= nSamp; continue; end
	M(i, :) = v(:)';
end
end

function Z = iRowsZS(M)
mu = mean(M, 2, 'omitnan'); sd = std(M, 0, 2, 'omitnan');
Z = (M - mu) ./ sd;
end

function [Z, nCell] = iDetrendRowsZS(M)
t = (1:size(M,2))' - (size(M,2)+1)/2;
bad = all(~isfinite(M), 2); M(bad, :) = [];
slope = sum(M .* t', 2) / sum(t.^2);
M = M - slope .* t';
mu = mean(M, 2, 'omitnan'); sd = std(M, 0, 2, 'omitnan');
Z = (M - mu) ./ sd;
nCell = size(Z, 1);
end

function [pc1, varExp1] = iPca1Time(Z)
Zc = Z - mean(Z, 2, 'omitnan');
[U, S, V] = svd(Zc, 'econ');
latent = diag(S).^2;
varExp1 = latent(1) / sum(latent);
pc1 = V(:, 1);
load1 = U(:, 1) * S(1, 1);
[~, iMax] = max(abs(load1));
if load1(iMax) < 0; pc1 = -pc1; end
end

function y = iCircShift(x, k)
y = circshift(x, k);
end

function r = iLagScan(a, b, lagList)
r = nan(size(lagList));
for i = 1:numel(lagList)
	L = lagList(i); n = numel(a);
	if L >= 0; u = a(1:n-L); v = b(1+L:n); else; u = a(1-L:n); v = b(1:n+L); end
	r(i) = iCorr(u, v);
end
end

function r = iCorr(a, b)
% 向量方向无关（内部统一转列向量）
a = a(:); b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 5; r = NaN; return; end
a = a(ok) - mean(a(ok)); b = b(ok) - mean(b(ok));
r = (a' * b) / sqrt((a' * a) * (b' * b));
end

function iSummaryPanel(tlo, tileIdx, stat, phases, varName, ttl)
ax = nexttile(tlo, tileIdx);
DataCell = cell(1, numel(phases));
for p = 1:numel(phases)
	DataCell{p} = stat.(varName)(string(stat.Phase) == phases(p));
	DataCell{p} = DataCell{p}(isfinite(DataCell{p}));
end
UniExp.BarScatterCompare(DataCell);
yline(ax, 0, '--k', 'HandleVisibility', 'off');
set(ax, 'XTick', 1:numel(phases), 'XTickLabel', cellstr(phases));
xtickangle(ax, 30);
ylabel(ax, 'r（与舔水率）');
title(ax, ttl, 'FontWeight', 'normal');
box(ax, 'off');
for p = 1:numel(phases)
	n = numel(DataCell{p});
	if n > 0
		text(ax, p, max(DataCell{p}) + 0.04, sprintf('n=%d', n), ...
			'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
	end
end
end

function y = iDetrend(y)
% 去线性趋势（列向量进、列向量出）
t = (1:numel(y))';
q = polyfit(t, y(:), 1);
y = y(:) - polyval(q, t);
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
