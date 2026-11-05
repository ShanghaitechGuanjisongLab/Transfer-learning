% Fig1 分离版｜学习曲线 4 张 + bar 图 4 张
%
% 曲线：
%   1  Audio–water（任务 A）：transfer 组学 AW 的过程（与 2 同一批鼠）
%   2  Light–water after 12 h：同一批鼠迁移到光水
%   3  Naive vs Transfer（12 h）的光水学习曲线
%   4  Transfer（12 h）vs 7 d 的光水学习曲线
%
% bar（两两比较 × 两个指标）：
%   1  Naive vs Transfer  — 首个光水 block 命中率
%   2  Naive vs Transfer  — 达 50% 所需 block
%   3  Transfer vs 7 d    — 首个光水 block 命中率
%   4  Transfer vs 7 d    — 达 50% 所需 block
%
% 规范：基础高 4 cm、宽 1.5 cm 整倍数、字号 6 pt（Scale 1）、
%       轴线 0.5 pt、线/errorbar 1 pt、bar 无边框、errorbar 单向、无散点。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet','class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off','UniExp:Exception:Block_must_warn');

groupOrder = ["Naive","Transfer","7dayTransfer"];
groupLabels = ["Naive","12 h","7 d"];
colors = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
Summ = TransferLearning.Metrics.PerMouseSessionSummary(Sess);

% ---------- 任务 A（声水）的学习曲线：取 transfer 组（ALB） ----------
AWC = iAudioWaterCurve();

% ---------- 统计 ----------
pairIdx = [1 2; 2 3];
pFirst = [iRS(Summ.FirstPerf(Summ.Group=="Naive"), Summ.FirstPerf(Summ.Group=="Transfer")); ...
	      iRS(Summ.FirstPerf(Summ.Group=="Transfer"), Summ.FirstPerf(Summ.Group=="7dayTransfer"))];
pHalf  = [iRS(Summ.BlocksToHalf(Summ.Group=="Naive"), Summ.BlocksToHalf(Summ.Group=="Transfer")); ...
	      iRS(Summ.BlocksToHalf(Summ.Group=="Transfer"), Summ.BlocksToHalf(Summ.Group=="7dayTransfer"))];

outDir = '';
names = strings(0,1);

%% ===== 曲线 1：Audio–water（transfer 组）=====
f1 = iCurveFigure(AWC, ["Transfer"], 'Audio–water (task A)', colors(2,:), false);
names(end+1) = string(TransferLearning.ExportStandardFigure(f1, 1, 'Fig1_Curve1_AudioWater.svg'));

%% ===== 曲线 2：Light–water after 12 h（同一批鼠）=====
f2 = iCurveFigure(Sess, ["Transfer"], 'Light–water after 12 h', colors(2,:), false);
names(end+1) = string(TransferLearning.ExportStandardFigure(f2, 1, 'Fig1_Curve2_TransferLW.svg'));

%% ===== 曲线 3：Naive vs Transfer =====
f3 = iCurveFigure(Sess, ["Naive","Transfer"], 'Naive vs 12 h', colors([1 2],:), true, ["Naive","12 h"]);
names(end+1) = string(TransferLearning.ExportStandardFigure(f3, 1, 'Fig1_Curve3_NaiveVsTransfer.svg'));

%% ===== 曲线 4：Transfer vs 7 d =====
f4 = iCurveFigure(Sess, ["Transfer","7dayTransfer"], '12 h vs 7 d', colors([2 3],:), true, ["12 h","7 d"]);
names(end+1) = string(TransferLearning.ExportStandardFigure(f4, 1, 'Fig1_Curve4_TransferVs7d.svg'));

%% ===== bar 1：首块 Naive vs Transfer =====
b1 = iBarFigure(Summ.FirstPerf(Summ.Group=="Naive"), Summ.FirstPerf(Summ.Group=="Transfer"), ...
	["Naive","12 h"], colors(1:2,:), pFirst(1), 'First block', 'Hit rate');
names(end+1) = string(TransferLearning.ExportStandardFigure(b1, 1, 'Fig1_Bar1_FirstBlock_NaiveVsTransfer.svg'));

%% ===== bar 2：达 50% Naive vs Transfer =====
b2 = iBarFigure(Summ.BlocksToHalf(Summ.Group=="Naive"), Summ.BlocksToHalf(Summ.Group=="Transfer"), ...
	["Naive","12 h"], colors(1:2,:), pHalf(1), 'Blocks to 50%', 'Blocks');
names(end+1) = string(TransferLearning.ExportStandardFigure(b2, 1, 'Fig1_Bar2_Half_NaiveVsTransfer.svg'));

%% ===== bar 3：首块 Transfer vs 7 d =====
b3 = iBarFigure(Summ.FirstPerf(Summ.Group=="Transfer"), Summ.FirstPerf(Summ.Group=="7dayTransfer"), ...
	["12 h","7 d"], colors(2:3,:), pFirst(2), 'First block', 'Hit rate');
names(end+1) = string(TransferLearning.ExportStandardFigure(b3, 1, 'Fig1_Bar3_FirstBlock_TransferVs7d.svg'));

%% ===== bar 4：达 50% Transfer vs 7 d =====
b4 = iBarFigure(Summ.BlocksToHalf(Summ.Group=="Transfer"), Summ.BlocksToHalf(Summ.Group=="7dayTransfer"), ...
	["12 h","7 d"], colors(2:3,:), pHalf(2), 'Blocks to 50%', 'Blocks');
names(end+1) = string(TransferLearning.ExportStandardFigure(b4, 1, 'Fig1_Bar4_Half_TransferVs7d.svg'));

fprintf('\n=== 导出 ===\n');
for k = 1:numel(names), fprintf('  %s\n', names(k)); end
fprintf('\n=== 数值 ===\n');
for k = 1:3
	S = Summ(Summ.Group == groupOrder(k), :);
	fprintf('%-13s n=%2d  first %.3f+-%.3f  half %.2f+-%.2f\n', groupOrder(k), height(S), ...
		mean(S.FirstPerf), iSEM(S.FirstPerf), mean(S.BlocksToHalf), iSEM(S.BlocksToHalf));
end
fprintf('AW (transfer 组) 前 3 个 session: %s\n', mat2str(round(AWC.mean(1:3),2)));

%% ---------------------------------------------------------------
function f = iCurveFigure(S, gsel, ttl, cols, withLegend, legLabels)
if nargin < 6, legLabels = gsel; end
f = figure('Color','w');
f.Units = 'centimeters';
if withLegend, f.Position(3:4) = [6 4]; else, f.Position(3:4) = [4.5 4]; end
ax = axes(f,'Position',[0.185 0.185 0.765 0.70]); hold(ax,'on');
proxy = gobjects(numel(gsel),1);
for k = 1:numel(gsel)
	g = gsel(k);
	[x, mu, se] = iCurveFor(S, g);
	ok = isfinite(mu);
	plot(ax, x(ok), mu(ok), '-', 'Color', cols(k,:), 'LineWidth', 1, 'HandleVisibility','off');
	errorbar(ax, x(ok), mu(ok), se(ok), 'o', 'Color', cols(k,:), 'LineWidth', 1, ...
		'MarkerSize', 3, 'MarkerFaceColor', cols(k,:), 'MarkerEdgeColor', cols(k,:), ...
		'CapSize', 2, 'HandleVisibility','off');
	proxy(k) = plot(ax, nan, nan, '-o', 'Color', cols(k,:), 'MarkerFaceColor', cols(k,:), ...
		'MarkerSize', 3, 'LineWidth', 1);
end
xLast = max(x(isfinite(mu)));
if isempty(xLast), xLast = numel(x); end
xlim(ax, [0.5, xLast + 0.5]);
ax.XTick = 1:xLast;
ax.XTickLabel = arrayfun(@(v) sprintf('%d',v), 1:xLast, 'UniformOutput', false);
xlabel(ax,'Block');
ylabel(ax,'Hit rate');
ax.FontSize = 6; ax.LineWidth = 0.5;
ylim(ax,[0 1]);
title(ax, ttl, 'FontWeight','normal');
if withLegend
	lg = legend(ax, proxy, cellstr(legLabels), 'Location','southeast');
	lg.Box = 'off'; lg.FontSize = 6;
end
box(ax,'off');
end

function [x, mu, se] = iCurveFor(S, g)
	nMax = 7;
	x = (1:nMax)';
	mu = nan(nMax,1); se = nan(nMax,1);
	if istable(S)                   % 会话表（LW）
		sel = S.Group == g;
		for k = 1:nMax
			v = S.Performance(sel & S.Session == k);
			v = v(isfinite(v));
			if isempty(v), continue; end
			mu(k) = mean(v); se(k) = std(v)/sqrt(numel(v));
		end
	else                            % 预计算好的 AW 曲线
		mu = S.mean(:); se = S.sem(:);
		x = (1:numel(mu))';
	end
end

function f = iBarFigure(v1, v2, labels, cols, pval, ttl, ylab)
f = figure('Color','w');
f.Units = 'centimeters'; f.Position(3:4) = [3 4];
ax = axes(f,'Position',[0.30 0.185 0.62 0.70]); hold(ax,'on');
y = [mean(v1(isfinite(v1))), mean(v2(isfinite(v2)))];
e = [iSEM(v1), iSEM(v2)];
h = bar(ax, 1:2, y, 0.45, 'FaceColor','flat');
h.CData = cols; h.EdgeColor = 'none'; h.LineWidth = 0.5;
for k = 1:2
	errorbar(ax, k, y(k), 0, e(k), 'Color', cols(k,:), 'LineWidth', 1, 'CapSize', 2);
end
ax.XTick = 1:2; ax.XTickLabel = cellstr(labels);
ax.FontSize = 6; ax.LineWidth = 0.5;
xlim(ax,[0.4 2.6]);
ylabel(ax, ylab);
title(ax, ttl, 'FontWeight','normal');
rng = max(y + e);
ax.YLim = [0, rng*1.55];
yy = rng*1.20;
plot(ax, [1 2], [yy yy], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5);
text(ax, 1.5, yy + rng*0.03, TransferLearning.Style.iFormatPText(pval), ...
	'FontSize', 6, 'HorizontalAlignment','center', 'VerticalAlignment','bottom');
box(ax,'off');
end

function C = iAudioWaterCurve()
% transfer 组（AudioLightBaseline）在学光水之前的声水学习曲线
DS = TransferLearning.AudioLightBaseline();
T = DS.TableQuery(["Mouse","DateTime","Stimulus","Behavior"], Stimulus="AudioWater");
T.Mouse = string(T.Mouse);
T = T(~isnan(T.Behavior), :);
mice = unique(T.Mouse);
nMax = 7;
M = nan(numel(mice), nMax);
for i = 1:numel(mice)
	dts = sort(unique(T.DateTime(T.Mouse == mice(i))));
	for k = 1:min(nMax, numel(dts))
		v = T.Behavior(T.Mouse == mice(i) & T.DateTime == dts(k));
		M(i,k) = mean(v);
	end
end
C = struct('mean', mean(M,1,'omitnan'), 'sem', std(M,0,1,'omitnan')./sqrt(sum(isfinite(M),1)));
fprintf('AW 曲线：%d 只鼠，前 3 个 session 均值 %s\n', numel(mice), mat2str(round(C.mean(1:3),3)));
end

function p = iRS(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function s = iSEM(x)
x = double(x(:)); x = x(isfinite(x));
if isempty(x), s = NaN; else, s = std(x)/sqrt(numel(x)); end
end
