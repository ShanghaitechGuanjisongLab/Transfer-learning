% FigALvsL_ScatterFit: AL Light vs LA Light — 特指鼠 yqn2351, yqn2312
% scatter + sigmoid fits, Nature 风格
%
% AL Light (A2L_L.mat): Audio→Light with Light water  → 鼠 yqn2351
% LA Light (L2A_L.mat): Light→Audio with Light water  → 鼠 yqn2312
%
% 仿 Fig33A_ExtremeMouseScatterFit 结构，改用指定数据集与鼠

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
DataSetA2L = UniExp.DataSet(fullfile(dataRoot, 'A2L_L.mat'));
DataSetL   = UniExp.DataSet(fullfile(dataRoot, 'L2A_L.mat'));

%% --- 2. 合并 DateTime（含鼠名）与 Blocks（含 Performance） ---
SessA = iMergeMouseAndBlocks(DataSetA2L);
SessL = iMergeMouseAndBlocks(DataSetL);

SessA.Group(:) = "AL_Light";
SessL.Group(:) = "LA_Light";

% 过滤到目标鼠
SessA = SessA(ismember(string(SessA.Mouse), "yqn2351"), :);
SessL = SessL(ismember(string(SessL.Mouse), "yqn2312"), :);

fprintf('AL Light (A2L, yqn2351): %d blocks\n', height(SessA));
fprintf('LA Light (L2A, yqn2312): %d blocks\n',  height(SessL));

if isempty(SessA) || isempty(SessL)
	error('FigALvsL:EmptyData', 'One or both target mice have no data.');
end

%% --- 3. 按鼠排序 + Session索引（每 DateTime 为一次 session）---
SessA = sortrows(SessA, {'Mouse','DateTime'});
SessL = sortrows(SessL,  {'Mouse','DateTime'});

SessA = iAddSessionIndex(SessA);
SessL = iAddSessionIndex(SessL);

% 截断至首次达 100%
SessA = iTruncateAt100(SessA);
SessL = iTruncateAt100(SessL);

SessA = iAddSessionIndex(SessA);
SessL = iAddSessionIndex(SessL);

%% --- 4. 每鼠 sigmoid 拟合（lower=0, upper=1 固定） ---
fitA = iFitSigmoidPerMouse(SessA, "yqn2351");
fitL = iFitSigmoidPerMouse(SessL, "yqn2312");

%% --- 5. 统计输出 ---
fprintf('\n=== Sigmoid 拟合参数 ===\n');
fprintf('yqn2351 AL Light: slope=%.4f, midpoint=%.2f, R²=%.4f\n', ...
	fitA.Slope, fitA.Midpoint, fitA.RSquared);
fprintf('yqn2312 LA Light: slope=%.4f, midpoint=%.2f, R²=%.4f\n', ...
	fitL.Slope, fitL.Midpoint, fitL.RSquared);

%% --- 6. 绘图 (Nature 风格) ---
% 图幅: 12 cm × 8 cm（Nature 单栏宽幅）
f = figure('Color', 'w', 'Name', 'FigALvsL Specific mice');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';

% 使用项目统一色板
colorAL = TransferLearning.NaiveColor;      % 紫 — AL Light (A2L)
colorL  = TransferLearning.ContinualColor;  % 橙 — LA Light (L2A)

ax = axes(f);
hold(ax, 'on');

% — AL Light: yqn2351 (紫色圆圈) —
xA = double(SessA.Session); yA = double(SessA.Performance);
hA = scatter(ax, xA, yA, 55, colorAL, 'o', ...
	'MarkerFaceColor', colorAL, 'MarkerEdgeColor', 'none');

% — LA Light: yqn2311 (橙色方块) —
xL = double(SessL.Session); yL = double(SessL.Performance);
hL = scatter(ax, xL, yL, 55, colorL, 's', ...
	'MarkerFaceColor', colorL, 'MarkerEdgeColor', 'none');

% — Sigmoid 拟合曲线 —
xFit = linspace(min([xA; xL]) - 1, max([xA; xL]) + 1, 200)';
plot(ax, xFit, iSigmoidFromLowerUpperParams(fitA.ParamRaw, xFit), '-', ...
	'Color', colorAL, 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine');
plot(ax, xFit, iSigmoidFromLowerUpperParams(fitL.ParamRaw, xFit), '-', ...
	'Color', colorL, 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine');

% Nature 风格: 仅左+下 spine，无框无网格，Arial 字体
xlabel(ax, 'Session', 'FontSize', 12, 'FontName', 'Arial');
ylabel(ax, 'Hit rate',   'FontSize', 12, 'FontName', 'Arial');
ax.FontSize   = 12;
ax.FontName   = 'Arial';
ax.LineWidth  = 1.5;
ax.TickDir    = 'out';
ax.Color      = 'none';
box(ax, 'off');
grid(ax, 'off');
title(ax, '');

% YTick 仅保留 ≤1 的值
ax.YTick(ax.YTick > 1 + eps) = [];

% 图例: 颜色→条件，鼠名标注
lgd = legend(ax, [hA, hL], {'yqn2351 AL', 'yqn2312 LA'}, ...
	'Location', 'southeast', 'Box', 'off', 'FontSize', 9, 'FontName', 'Arial');
lgd.ItemTokenSize = [18, 6];

% 隐藏 axes toolbar
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

% 应用标准导出样式 + 输出 SVG（自动路径: \\Data-Server-2\个人数据\杨青宁\202607\）
svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图FigALvsL_SpecificMiceScatterFit.svg');
fprintf('\nWrote: %s\n', svgPath);

%% ===================== 本地函数 =====================

function T = iMergeMouseAndBlocks(DS)
	% 合并 DateTimes（小鼠名）与 Blocks（Performance），按 DateTime 对齐
	DT = DS.TableQuery("DateTimes");
	BL = DS.TableQuery("Blocks");
	if isempty(DT) || isempty(BL)
		T = table();
		return;
	end
	DT.Mouse = string(DT.Mouse);
	DT = DT(:, {'DateTime','Mouse'});
	BL = BL(:, {'DateTime','Performance','Design'});
	% 合并 — 每个 DateTime 唯一，各 Block 唯一
	T = innerjoin(DT, BL, 'Keys', 'DateTime');
	T = sortrows(T, {'Mouse','DateTime'});
end

function T = iAddSessionIndex(T)
	% 每鼠内按 DateTime 排序后给 Session 序号
	T.Mouse = string(T.Mouse);
	if ismember('Group', string(T.Properties.VariableNames))
		T = sortrows(T, {'Group','Mouse','DateTime'});
		[G, ~] = findgroups(T.Group, T.Mouse);
	else
		T = sortrows(T, {'Mouse','DateTime'});
		[G, ~] = findgroups(T.Mouse);
	end
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function T = iTruncateAt100(T)
	% 每鼠截断: 首次 Performance >= 1.0 之后移除，该点置为 1
	if isempty(T); return; end
	T.Mouse = string(T.Mouse);
	mice = unique(T.Mouse);
	keepRows = false(height(T), 1);
	for iM = 1:numel(mice)
		idx = find(T.Mouse == mice(iM));
		perf = double(T.Performance(idx));
		reached = find(perf >= 1.0, 1, 'first');
		if isempty(reached)
			keepRows(idx) = true;
		else
			keepRows(idx(1:reached)) = true;
			T.Performance(idx(reached)) = 1;
		end
	end
	T = T(keepRows, :);
end

function fitOut = iFitSigmoidPerMouse(T, mouseName)
	% 固定 lower=0, upper=1, 拟合 slope 和 midpoint
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use); yObs = yObs(use);
	if numel(xObs) < 2
		error('FigALvsL:NotEnoughData', '%s has <2 valid sessions.', char(mouseName));
	end

	% 多起始点搜索
	slopeStarts  = [0, 0.2, 0.8, 2, 5, 20];
	midStarts    = unique([median(xObs); min(xObs); max(xObs); ...
		min(xObs) - numel(xObs); max(xObs) + numel(xObs)]);
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	obj = @(p) sum((yObs - iSigmoidFromLowerUpperParams(p, xObs)).^2, 'omitnan');

	bestSse = inf; bestP = [sqrt(0.8); median(xObs)];
	for s = 1:numel(slopeStarts)
		for m = 1:numel(midStarts)
			pTry = fminsearch(obj, [sqrt(slopeStarts(s)); midStarts(m)], opt);
			if obj(pTry) < bestSse
				bestSse = obj(pTry);
				bestP = pTry;
			end
		end
	end

	yHat = iSigmoidFromLowerUpperParams(bestP, xObs);
	sse = sum((yObs - yHat).^2, 'omitnan');
	sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	if sst == 0, r2 = NaN; else, r2 = 1 - sse / sst; end

	[~, ~, slope, midpoint] = iDecodeLowerUpperParams(bestP);
	fitOut = struct;
	fitOut.Mouse    = string(mouseName);
	fitOut.ParamRaw = bestP;
	fitOut.Lower    = 0;
	fitOut.Upper    = 1;
	fitOut.Slope    = slope;
	fitOut.Midpoint = midpoint;
	fitOut.SSE      = sse;
	fitOut.RSquared = r2;
	fitOut.XObserved = xObs;
	fitOut.YObserved = yObs;
end

function y = iSigmoidFromLowerUpperParams(p, x)
	[~, ~, slope, midpoint] = iDecodeLowerUpperParams(p);
	y = 1 ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeLowerUpperParams(p)
	lower = 0;
	upper = 1;
	slope = p(1).^2;
	midpoint = p(2);
end
