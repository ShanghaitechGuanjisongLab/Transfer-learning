% FigALvsL_Session4_Bar: AL Light vs LA Light 第4天命中率比较
% bar + individual scatter, Nature 风格
%
% AL Light (A2L_L.mat): Audio→Light with Light water
% LA Light (L2A_L.mat): Light→Audio with Light water

%% --- 0. 项目加载 ---
if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
	end
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

%% --- 1. 加载数据 ---
dataRoot = '\\Data-Server-2\个人数据\杨青宁\202607\行为学';
DSa = UniExp.DataSet(fullfile(dataRoot, 'A2L_L.mat'));
DSl = UniExp.DataSet(fullfile(dataRoot, 'L2A_L.mat'));

%% --- 2. 提取每鼠第4天命中率 ---
perfA = iSession4Perf(DSa);
perfL = iSession4Perf(DSl);

fprintf('AL Light: n=%d, mean=%.3f, sem=%.3f\n', ...
	numel(perfA), mean(perfA,'omitnan'), std(perfA,'omitnan')/sqrt(numel(perfA)));
fprintf('LA Light: n=%d, mean=%.3f, sem=%.3f\n', ...
	numel(perfL), mean(perfL,'omitnan'), std(perfL,'omitnan')/sqrt(numel(perfL)));

% 统计
[p,~,~] = ranksum(perfA, perfL);
fprintf('Wilcoxon rank-sum P = %.4g\n', p);

%% --- 3. 绘图 (Nature 风格 bar + scatter) ---
colorA = TransferLearning.NaiveColor;      % 紫
colorL = TransferLearning.ContinualColor;  % 橙

f = figure('Color', 'w', 'Name', 'FigALvsL Session4 bar');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [6, 8];
f.PaperPositionMode = 'auto';

ax = axes(f);
hold(ax, 'on');

% Bar
barA = mean(perfA, 'omitnan');
barL = mean(perfL, 'omitnan');
semA = std(perfA, 'omitnan') / sqrt(numel(perfA));
semL = std(perfL, 'omitnan') / sqrt(numel(perfL));

hb = bar(ax, [1, 2], [barA, barL], 0.5, 'FaceColor', 'flat');
hb.CData(1, :) = colorA;
hb.CData(2, :) = colorL;
hb.EdgeColor = 'none';
hb.BaseLine.LineWidth = 1.5;

% Individual scatter points (jittered)
jitterA = -0.12 + 0.24 * rand(numel(perfA), 1);
jitterL = -0.12 + 0.24 * rand(numel(perfL), 1);
scatter(ax, 1 + jitterA, perfA, 30, 'k', 'o', ...
	'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
scatter(ax, 2 + jitterL, perfL, 30, 'k', 'o', ...
	'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);

% Error bars
errorbar(ax, 1, barA, semA, 'Color', 'k', 'LineWidth', 1.5, 'CapSize', 0);
errorbar(ax, 2, barL, semL, 'Color', 'k', 'LineWidth', 1.5, 'CapSize', 0);

% P-value line
yMax = max([perfA(:); perfL(:)]);
yl = ylim(ax); yr = yl(2) - yl(1);
yP = yMax + 0.12 * yr;
yPText = yP + 0.06 * yr;
plot(ax, [1, 2], [yP, yP], 'k-', 'LineWidth', 1);

if p < 0.001
	pStr = '***';
elseif p < 0.01
	pStr = '**';
elseif p < 0.05
	pStr = '*';
else
	pStr = sprintf('P=%.3f', p);
end
text(ax, 1.5, yPText, pStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
	'FontSize', 12, 'FontName', 'Arial');

% Axis labels
ax.XTick = [1, 2];
ax.XTickLabel = {'AL Light', 'LA Light'};
ax.XTickLabelRotation = 0;
ylabel(ax, 'Hit rate (Session 4)', 'FontSize', 12, 'FontName', 'Arial');

% Nature style
ax.FontSize   = 11;
ax.FontName   = 'Arial';
ax.LineWidth  = 1.5;
ax.TickDir    = 'out';
ax.Color      = 'none';
box(ax, 'off');
grid(ax, 'off');
title(ax, '');

% Y 轴固定在 [0, 1]
ylim(ax, [0, 1.2]);

% 隐藏 toolbar
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

%% --- 4. 导出 ---
svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图FigALvsL_Session4_Bar.svg');
fprintf('\nWrote: %s\n', svgPath);
fprintf('\n=== FigALvsL Session 4 ===\n');
fprintf('Wilcoxon rank-sum P = %.4g\n', p);

%% ===================== 本地函数 =====================

function perf = iSession4Perf(DS)
	DT = DS.TableQuery("DateTimes");
	BL = DS.TableQuery("Blocks");
	if isempty(DT) || isempty(BL)
		perf = nan(0,1); return;
	end
	DT.Mouse = string(DT.Mouse);
	DT = DT(:, {'DateTime','Mouse'});
	BL = BL(:, {'DateTime','Performance'});
	T = innerjoin(DT, BL, 'Keys', 'DateTime');
	T = sortrows(T, {'Mouse','DateTime'});

	% Session 索引
	[G,~] = findgroups(T.Mouse);
	sc = splitapply(@(x){(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sc{:});

	% 截断至首次 100%
	mice = unique(T.Mouse);
	keep = false(height(T),1);
	for i = 1:numel(mice)
		idx = find(T.Mouse == mice(i));
		perf = double(T.Performance(idx));
		reached = find(perf >= 1.0, 1, 'first');
		if isempty(reached)
			keep(idx) = true;
		else
			keep(idx(1:reached)) = true;
			T.Performance(idx(reached)) = 1;
		end
	end
	T = T(keep, :);

	% 重新编号 Session
	[G,~] = findgroups(T.Mouse);
	sc = splitapply(@(x){(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sc{:});

	% 提取 Session 4
	s4 = T(T.Session == 4, :);
	perf = double(s4.Performance);
	perf = perf(isfinite(perf));
end
