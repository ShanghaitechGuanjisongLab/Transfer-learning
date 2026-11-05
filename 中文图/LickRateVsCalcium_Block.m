%% LickRateVsCalcium_Block.m — Step 1：慢成分 sanity 检查（舔水率 vs 群体钙信号）
%
% 目的（**不涉及 rSLDS**）：在有舔水事件的鼠上回答两个问题
%   ① 群体钙信号有没有明显的慢成分？它是不是单调的（→ 更像光漂白而非状态）？
%   ② 这个慢成分是否与舔水率共变（→ 才值得上 rSLDS）
%
% 背景：`Blocks.EventLog` 里的"舔"事件只覆盖 3 只鼠（yqn1018 / yqn0411 四阶段齐全，yqn0133 只有 Transfer/Final）。
%       其余 8 只鼠没有任何舔水记录，且 TrialTags 的 CD1/CD2 已实测与舔数无关（不是舔水信号）。
%
% 1) 依赖
%    - MATLAB R2023b，本项目 +TransferLearning 包
%    - Statistics and Machine Learning Toolbox（corr）
%
% 2) 前置
%    - 无需其它脚本；数据源 TransferLearning.AudioLightBaseline
%
% 3) 图注
%    每只鼠一张图（行＝阶段）。左列＝群体钙信号（逐细胞 z-score 后跨细胞平均），右列＝舔水率（1 s 分箱）。
%    细线＝原始，粗线＝60 s 滑动平均。两条轨都按整条 session 的时间轴（分钟）绘制，同一时基。
%    控制台打印：corr(慢钙, 慢舔)、corr(慢钙, 时间)、以及在去除线性趋势后的对应相关系数。
%
% 4) 代码

%% 0. 参数
mice      = ["yqn1018", "yqn0411", "yqn0133"];
phases    = ["Naive", "Learned", "Transfer", "Final"];
smoothSec = 60;          % 滑动平均窗长（秒）
lickBinSec = 1;          % 舔水率分箱长度（秒）
minIliSec  = 0.05;       % 舔水事件去抖的最小间隔（秒）
% ⚠ “舔”事件不是单次舔：实测 81% 的相邻间隔 <10 ms（中位 2.4 ms）——
%   它是高频采样的“正在舔”指示（≈400 Hz）。必须以 ~50 ms 最小间隔先后去抖：
%   27044 条 → 1269 条（yqn1018 Learned），得到真实舔次量级

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
fprintf('=== Step 1：舔水率 vs 群体钙信号（慢成分 sanity 检查）===\n');
fprintf('滑动平均窗 = %g s，舔水率分箱 = %g s\n\n', smoothSec, lickBinSec);

%% 2. 逐鼠逐阶段：出图 + 统计
statRows = {};
for mouse = mice
	% 该鼠有舔水事件的阶段（按 phases 顺序）
	avail = strings(0,1); idxB = [];
	for phase = phases
		iB = iFindBlock(B, DT, mouse, phase);
		if isempty(iB); continue; end
		el = B.EventLog{iB};
		if ~istimetable(el) || sum(string(el.Event) == "舔") == 0; continue; end
		avail(end+1, 1) = phase; %#ok<SAGROW>
		idxB(end+1, 1) = iB; %#ok<SAGROW>
	end
	if isempty(avail); continue; end

	f = iNewFigure(char(mouse + "：慢成分 sanity"), [9, 2 * numel(avail)]);
	tlo = tiledlayout(f, numel(avail), 2, 'TileSpacing', 'compact', 'Padding', 'compact');

	for r = 1:numel(avail)
		iB = idxB(r); phase = avail(r);
		uid = B.BlockUID(iB);

		% ---- 时基与两条轨道 ----
		dt = iSeriesInterval(DT, B.DateTime(iB));
		rowIdx = find(BS.BlockUID == uid);
		[calZ, nCell, nSamp] = iPopCalcium(BS, rowIdx);
		tMin = (0:nSamp-1) * dt / 60;

		% ---- 舔水率（唯一来源：Blocks.EventLog 的 timetable）----
		el = iCheckEventLog(B, iB);
		ev = string(el.Event);
		lickT = seconds(el.Properties.RowTimes(ev == "舔"));
		lickT = iDebounce(lickT, minIliSec);
		lickRate = iRate(lickT, nSamp, dt, lickBinSec);

		w = max(3, round(smoothSec / dt));
		calSlow = movmean(calZ, w, 'omitnan');
		lickSlow = movmean(lickRate, w, 'omitnan');

		% ---- 左：群体钙 ----
		ax1 = nexttile(tlo, (r-1)*2 + 1);
		hold(ax1, 'on');
		plot(ax1, tMin, calZ, 'Color', [0.70 0.70 0.70]);
		plot(ax1, tMin, calSlow, 'k');
		yline(ax1, 0, '-', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
		hold(ax1, 'off');
		box(ax1, 'off');
		ylabel(ax1, sprintf('%s\n(z)', phase));
		if r == 1; title(ax1, '群体钙信号（逐细胞 z）', 'FontWeight', 'normal'); end
		xlim(ax1, [0, tMin(end)]);

		% ---- 右：舔水率 ----
		ax2 = nexttile(tlo, (r-1)*2 + 2);
		hold(ax2, 'on');
		plot(ax2, tMin, lickRate, 'Color', [0.70 0.85 0.95]);
		plot(ax2, tMin, lickSlow, 'Color', [0.00 0.45 0.74]);
		hold(ax2, 'off');
		box(ax2, 'off');
		ylabel(ax2, sprintf('%s\n(次/s)', phase));
		if r == 1; title(ax2, '舔水率（1 s 分箱）', 'FontWeight', 'normal'); end
		xlim(ax2, [0, tMin(end)]);

		% ---- 统计（同一 ok 子集；corr 要求列向量）----
		ok = isfinite(calSlow) & isfinite(lickSlow);
		calOk = calSlow(ok)'; lickOk = lickSlow(ok)'; tOk = tMin(ok)';
		statRows(end+1, :) = {char(mouse), char(phase), nCell, tMin(end), ...
			corr(calOk, lickOk, 'Type', 'Spearman'), ...
			corr(calOk, tOk, 'Type', 'Spearman'), ...
			corr(calOk, tOk, 'Type', 'Pearson')^2, ...
			corr(iDetrend(calOk), iDetrend(lickOk), 'Type', 'Spearman'), ...
			corr(iDetrend(calOk), tOk, 'Type', 'Spearman')}; %#ok<SAGROW>
	end
	xlabel(tlo, 'session 内时间（min）');
	TransferLearning.ExportStandardFigure(f, 1, sprintf('Step1_LickVsCalcium_%s.svg', mouse));
end

if isempty(statRows)
	fprintf('\n没有可用数据。\n');
else
	stat = cell2table(statRows, 'VariableNames', {'Mouse','Phase','nCell','durMin', ...
		'r_慢钙_慢舔', 'r_慢钙_时间', 'R2_线性趋势', 'r_去趋势后', 'r_去趋势钙_时间'});
	fprintf('\n=== 相关系数汇总（Spearman，R2_线性趋势为 Pearson）===\n');
	disp(stat);
end
fprintf('\nDone.\n');

%% ===== Local functions =====
function iB = iFindBlock(B, DT, mouse, phase)
% 用 DateTime 把 DateTimes 的 (mouse, phase) 行对应到 Blocks 的行
iB = [];
k = find(string(DT.Mouse) == mouse & string(DT.Phase) == phase, 1);
if isempty(k); return; end
iB = find(B.DateTime == DT.DateTime(k), 1);
end

function el = iCheckEventLog(B, iB)
% 舔水记录的唯一来源：Blocks.EventLog，且必须是含 Event 列的 timetable
% （时间轴取 el.Properties.RowTimes；实测 112/114 个 block 如此，剩 2 个为空 double）
el = B.EventLog{iB};
assert(istimetable(el) && ismember('Event', el.Properties.VariableNames), ...
	'Blocks.EventLog{%d} 不是含 Event 列的 timetable', iB);
end

function [calZ, nCell, nSamp] = iPopCalcium(BS, rowIdx)
% 取一个 block 的细胞×时间矩阵 → 逐细胞 z-score → 跟细胞平均
sig = BS.BlockSignal(rowIdx);
nSamp = numel(sig{1});
M = nan(numel(sig), nSamp);
for i = 1:numel(sig)
	v = double(sig{i});
	if numel(v) ~= nSamp; continue; end
	M(i, :) = (v(:)' - mean(v, 'omitnan')) / std(v, 0, 'omitnan');
end
calZ = mean(M, 1, 'omitnan');
nCell = sum(isfinite(M(:, 1)));
end

function dt = iSeriesInterval(DT, dtm)
% 该 block 的重采样间隔（秒）
k = find(DT.DateTime == dtm, 1);
if isempty(k) || ~isduration(DT.SeriesInterval(k))
	error('SeriesInterval 缺失：%s', string(dtm));
end
dt = seconds(DT.SeriesInterval(k));
end

function rate = iRate(lickT, nSamp, dt, binSec)
% 把（已去抖的）舔水事件时间转成与钙信号同格的瞬时率（次/秒）
edges = (0:nSamp) * dt;
cnt = histcounts(lickT, edges);
rate = cnt / ((edges(2) - edges(1)) * binSec);
end

function t = iDebounce(t, minIli)
% 去抖：保留与上一个保留事件间隔 > minIli 的事件
t = sort(t(:));
if isempty(t); return; end
keep = [true; diff(t) > minIli];
t = t(keep);
end

function y = iDetrend(y)
% 去除线性趋势（输入/输出均为列向量）
t = (1:numel(y))';
p = polyfit(t, y(:), 1);
y = y(:) - polyval(p, t);
end

function f = iNewFigure(figName, sizeCm)
% 统一创建图窗（作图规范：基础高 4 cm，宽为 1.5 cm 的整数倍）
f = figure('Color', 'w', 'Name', figName);
f.Units = 'centimeters';
f.Position(3:4) = sizeCm;
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, sizeCm];
f.PaperSize = sizeCm;
end
