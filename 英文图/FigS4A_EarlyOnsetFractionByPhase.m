%% FigS4A_EarlyOnsetFractionByPhase.m
% English FigS4A: early-onset 细胞的直观展示与占比，Learned vs Transfer。
% 经 PDF 原图核对：Fig.1c 是黑红热图，右侧为 3 个上下排列、无常规坐标轴的
% 示例细胞子图，每个子图仅一条跨 movement 平均曲线及其 SEM 阴影；Fig.2a
% 是黑白饼图而非比例条。本图按这些实际元素绘制，不混入其它面板样式。
% onset = 基线([-1,-0.5]s)+1SD 且持续 200 ms；onset<0 为 early，onset≥0
% 为 late，无 onset 为 no onset。两阶段各含热图、3 个示例细胞及 early 饼图。
% 示例细胞按 Learned onset 的 25/50/75% 位置客观选取，两阶段显示同一细胞。
% 饼图比例 = 每鼠 early/全部记录细胞比例的跨鼠均值；mean±SEM 在命令行报告。
%
% Outputs (SVG): English_FigS4A_EarlyOnsetFractionByPhase.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
matPath = fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat');
genScript = fullfile(thisDir, 'FigS4_PreCueStatePCA_Analysis.m');
if ~isfile(matPath) || ~iCacheHasPerCellPsth(matPath)
	% 入口脚本自给自足：缓存缺失，或为旧版（无逐细胞 PSTH，画不了热图）时重跑生成器。
if ~isfile(matPath)
		fprintf('Results cache missing (%s)\n', matPath);
	else
		fprintf('Cache 为旧版（缺逐细胞 PSTH），无法画热图：%s\n', matPath);
	end
	fprintf('Generating via %s ...\n', genScript);
	iRunGeneratorScript(genScript);
end
S = load(matPath);
M = S.M;

nM = numel(M);
frac = nan(nM, 3, 2);       % mouse x {early,late,none} x {Learned,Transfer}
for i = 1:nM
	nTotL = M(i).nEarly + M(i).nLate + M(i).nNone;
	nTotT = M(i).nEarlyT + M(i).nLateT + M(i).nNoneT;
	frac(i, :, 1) = [M(i).nEarly, M(i).nLate, M(i).nNone] / nTotL * 100;
	frac(i, :, 2) = [M(i).nEarlyT, M(i).nLateT, M(i).nNoneT] / nTotT * 100;
end
[pE, hE] = signrank(frac(:,1,1), frac(:,1,2));
[pL, ~] = signrank(frac(:,2,1), frac(:,2,2));
fprintf('early%% Learned med=%.2f Transfer med=%.2f，Wilcoxon p=%.4g（%d/%d 鼠上升）\n', ...
	median(frac(:,1,1)), median(frac(:,1,2)), pE, sum(frac(:,1,2)>frac(:,1,1)), nM);
fprintf('late%%  Learned med=%.2f Transfer med=%.2f，Wilcoxon p=%.4g\n', ...
	median(frac(:,2,1)), median(frac(:,2,2)), pL);

% ---- figure：Fig.1c 黑红热图/独立示例曲线 + Fig.2a 黑白饼图 ----
cEarly = [0.478, 0.204, 0.012];
cLate  = [0.45, 0.45, 0.45];
cNone  = [0.35, 0.35, 0.35];
cCells = [0.93, 0.39, 0.10; 0.95, 0.82, 0.08; 0.48, 0.20, 0.03];
phaseColor = [0.55, 0.55, 0.55; 0.66, 0.32, 0.50];
phaseName = ["Learned", "Transfer"];

f = figure('Color', 'w', 'Name', 'English FigS4A EarlyOnsetFractionByPhase');
f.Units = 'centimeters';
f.Position(3:4) = [18.2, 12];
heatPos = [1.35, 4.65, 4.0, 5.35; 9.95, 4.65, 4.0, 5.35];
traceX = [6.35, 14.95];
traceY = [9.25, 7.40, 5.55];
traceW = 2.15; traceH = 1.10;
traceAx = gobjects(2, 3);
piePos = [2.75, 0.55, 2.7, 2.7; 11.35, 0.55, 2.7, 2.7];

% ---- Learned / Transfer 逐神经元 lick 锁定 PSTH 热图（Fig.1c 左）----
% 各鼠原生帧率不同 → 逐细胞 PSTH 先插值到公共 100 Hz 网格，再全局排序堆叠：
%   行序 = early（onset 升序）→ late（onset 升序）→ no onset（[-0.5,1.5] s 峰值降序）
% 与文献一致：热图为跨 movement 平均的原始活动（本图不另做归一化），
% 白色競线 = movement(lick) onset；early 行在白線左侧即开始变亮 = “运动前就激活”。
% 显示右界严格裁剪（零 NaN 结构性保证 + 硬校验，不用透明化遮掩）： lick 锁定正端
% 越靠后，绝对时间(lickT+t)越可能超出 trial 采集窗（Transfer 舔水潜伏期可达 ~1.6 s，
% 塌缩更早），只剩舔水最快的少数 movement 贡献均值 → 选择性偏差假信号。故取
% “每鼠×每阶段 movement 覆盖率均 >=90%”的最后一个时刻为公共右界（严格口径，
% 非中位数），保证窗内每一格都由 >=90% 的 movement 平均而来；插值后硬断言无 NaN，
% 若未来数据变化导致 NaN，脚本直接报错而非默默渲染错误颜色。
% onset 判定用 [-0.2,1.5] s（分析层独立于显示裁剪），统计不受影响。
minCover = 0.9;
tC = (-1.5 : 0.01 : 2)';
if isfield(M, 'mvCovL') && isfield(M, 'mvCovT')
	covAll = nan(2*numel(M), numel(tC));
	for i = 1:numel(M)
		covAll(i, :)         = interp1(M(i).tP(:), M(i).mvCovL(:), tC, 'linear', nan);
		covAll(numel(M)+i, :) = interp1(M(i).tP(:), M(i).mvCovT(:), tC, 'linear', nan);
	end
	covAll(~isfinite(covAll)) = 0;      % 超出该鼠 tP 范围 = 无覆盖，不外推
	covMin = min(covAll, [], 1);        % 最差鼠×最差阶段
	kCut = find(covMin < minCover, 1);
	if ~isempty(kCut), tC = tC(1:kCut-1); end
end
fprintf('热图/示例PSTH 显示时窗 [-1.5, %+.2f] s（每鼠每阶段 movement 覆盖率均>=%.0f%%）\n', tC(end), 100*minCover);
wPk = tC >= -0.5 & tC <= 1.5;
heat = cell(1, 2); grp = zeros(3, 2);
for ph = 1:2
	Pc = []; ons = []; isE = []; isL = []; hasO = [];
	for i = 1:nM
		if ph == 1
			C = M(i).psthCellL; O = M(i).onsetCellL; E = M(i).isEarlyL;
			Lg = M(i).isLateL;  H = M(i).hasOnsetL;
		else
			C = M(i).psthCellT; O = M(i).onsetCellT; E = M(i).isEarlyT;
			Lg = M(i).isLateT;  H = M(i).hasOnsetT;
		end
		Pi = interp1(M(i).tP(:), C.', tC, 'linear', nan).';   % nC x numel(tC)
		Pc   = [Pc; Pi]; %#ok<AGROW>
		ons  = [ons; O(:)]; %#ok<AGROW>
		isE  = [isE; E(:)]; %#ok<AGROW>
		isL  = [isL; Lg(:)]; %#ok<AGROW>
		hasO = [hasO; H(:)]; %#ok<AGROW>
	end
	pk = max(Pc(:, wPk), [], 2, 'omitnan'); pk(~isfinite(pk)) = -inf;
	eI = find(isE); [~, eO] = sort(ons(eI)); eR = eI(eO);
	lI = find(isL); [~, lO] = sort(ons(lI)); lR = lI(lO);
	nI = find(~hasO); [~, nO] = sort(pk(nI), 'descend'); nR = nI(nO);
	heat{ph} = Pc([eR; lR; nR], :);
	grp(:, ph) = [numel(eR); numel(lR); numel(nR)];
end
% 硬校验：严格窗口下热图矩阵必须零 NaN；若命中此处，说明覆盖率裁剪或数据提取出了
% 新问题，应修数据而不是在渲染层用透明度遮掩。
for ph = 1:2
	if ~all(isfinite(heat{ph}(:)))
		error('FigS4A:NaNInHeatmap', '热图矩阵(phase%d)含 %d 个 NaN：严格覆盖率窗口未能消灭缺失数据。', ...
			ph, sum(~isfinite(heat{ph}(:))));
	end
end
vF = cat(1, heat{1}, heat{2}); vF = vF(isfinite(vF));
cLimC = [0, max(2, ceil(prctile(vF, 99.3)))];
redMap = [linspace(0, 1, 256)', zeros(256, 2)];
for ph = 1:2
	ax = axes(f, 'Units', 'centimeters', 'Position', heatPos(ph, :));
	hold(ax, 'on');
	nTot = sum(grp(:, ph));
	imagesc(ax, tC, 1:nTot, heat{ph});
	set(ax, 'YDir', 'reverse', 'YLim', [0.5, nTot*1.075], 'XLim', [tC(1), tC(end)]);
	colormap(ax, redMap);
	clim(ax, cLimC);
	xline(ax, 0, ':', 'Color', [0.45, 0.45, 0.45], 'LineWidth', 0.5);
	yb = [grp(1, ph)/2, grp(1, ph)+grp(2, ph)/2, ...
		grp(1, ph)+grp(2, ph)+grp(3, ph)/2];
	axis(ax, 'off');
	title(ax, phaseName(ph), 'Color', phaseColor(ph, :), 'FontName', 'Arial', ...
		'FontSize', 6, 'FontWeight', 'normal');
	lab = ["early-onset", "late-onset", "no onset"];
	labColor = [cEarly; cLate; cNone];
	for j = 1:3
		text(ax, -0.035, 1-yb(j)/nTot, lab(j), 'Units', 'normalized', ...
			'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
			'FontName', 'Arial', 'FontSize', 6, 'Color', labColor(j, :));
	end
	cb = colorbar(ax, 'eastoutside');
	cb.Box = 'off'; cb.FontName = 'Arial'; cb.FontSize = 6; cb.LineWidth = 0.5;
	cb.TickDirection = 'out'; cb.Ticks = cLimC; cb.Label.String = 'z (\DeltaF/F)';
	cb.Units = 'centimeters';
	cb.Position = [heatPos(ph,1)+heatPos(ph,3)+0.22, heatPos(ph,2)+0.45, ...
		0.13, heatPos(ph,4)-0.9];
	ax.Units = 'centimeters'; ax.Position = heatPos(ph, :);
	% Fig.1c 用比例尺而非直角坐标框；不添加文献没有的白色分组线。
	yScale = nTot + 0.5 + 0.022*nTot;
	x0 = tC(1) + 0.06*range(tC);
	plot(ax, [x0, x0+0.5], [yScale, yScale], 'k-', 'LineWidth', 1, 'Clipping', 'off');
	text(ax, x0, yScale+0.022*nTot, '0.5 s', 'HorizontalAlignment', 'left', ...
		'VerticalAlignment', 'top', 'FontName', 'Arial', 'FontSize', 6, 'Clipping', 'off');
	text(ax, 0.5, -0.10, 'Time from movement onset', 'Units', 'normalized', ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
		'FontName', 'Arial', 'FontSize', 6, 'Color', 'k');
end

% ---- 每阶段 3 个示例细胞：与 FigS4B 同一示例鼠，按 Learned onset 的 25/50/75% 选取 ----
cand = [];
for i = 1:nM
	if sum(M(i).YT == 1) >= 5 && sum(M(i).YT == 0) >= 5 && M(i).k >= 2
		cand(end+1) = i; %#ok<SAGROW>
	end
end
if isempty(cand), error('FigS4A:NoExampleMouse', '无与 FigS4B 兼容的示例鼠。'); end
[~, q] = max([M(cand).nC]); iS = cand(q);
if M(iS).nEarly < 3
	cand = find([M.nEarly] >= 3);
	if isempty(cand), error('FigS4A:TooFewEarly', '无至少 3 个 Learned early 细胞的鼠。'); end
	[~, q] = max([M(cand).nC]); iS = cand(q);
end
m = M(iS);
eI = find(m.isEarlyL);
[~, o] = sort(m.onsetCellL(eI)); eI = eI(o);
ranks = floor((numel(eI)+1) * [0.25, 0.50, 0.75]);
selCell = eI(ranks);
assert(numel(selCell) == 3 && numel(unique(selCell)) == 3, 'FigS4A:ExampleSelection', '示例细胞选择失败。');
fprintf('示例细胞：%s，按 Learned onset 百分位取细胞索引 %s（两阶段同一细胞）\n', ...
	m.Mouse, mat2str(selCell));

% ---- 每阶段 3 个独立示例子图：每图一条细胞均值曲线 + 跨 movement SEM ----
pieMean = mean(frac(:, 1, :), 1);
pieSem = std(frac(:, 1, :), 0, 1) / sqrt(nM);
for ip = 1:2
	if ip == 1
		Pc = m.psthCellL; Sc = m.psthCellSemL;
	else
		Pc = m.psthCellT; Sc = m.psthCellSemT;
	end
	for j = 1:3
		pos = [traceX(ip), traceY(j), traceW, traceH];
		ax = axes(f, 'Units', 'centimeters', 'Position', pos);
		traceAx(ip, j) = ax;
		hold(ax, 'on');
		tr = interp1(m.tP(:), Pc(selCell(j), :).', tC, 'linear', nan);
		se = interp1(m.tP(:), Sc(selCell(j), :).', tC, 'linear', nan);
		if ~all(isfinite(tr)) || ~all(isfinite(se))
			error('FigS4A:NaNInTrace', '示例细胞 PSTH/SEM 在严格显示窗内含 NaN。');
		end
		patch(ax, [tC; flipud(tC)], [tr+se; flipud(tr-se)], cCells(j, :), ...
			'EdgeColor', 'none', 'FaceAlpha', 0.22, 'Clipping', 'off');
		plot(ax, tC, tr, '-', 'Color', cCells(j, :), 'LineWidth', 0.75, 'Clipping', 'off');
		xlim(ax, [tC(1), tC(end)]);
		yl = [min(tr-se), max(tr+se)];
		if range(yl) <= 0, yl = yl + [-0.5, 0.5]; end
		yl = yl + [-0.18, 0.10] * range(yl);
		if j == 3
			yl(1) = yl(1) - 0.25 * range(yl);
			yScale = yl(1) + 0.08 * range(yl);
			yl(2) = max(yl(2), yScale + 0.5 + 0.08 * range(yl));
		end
		ylim(ax, yl);
		% 仅隐藏坐标尺；axis off 在本版 SVG 导出中会连同曲线一起裁掉。
		ax.Color = 'none'; box(ax, 'off');
		ax.XAxis.Visible = 'off'; ax.YAxis.Visible = 'off'; ax.Visible = 'on';
		if j == 1
			text(ax, -0.16, 0.5, 'Example early-onset', 'Units', 'normalized', ...
				'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
				'FontName', 'Arial', 'FontSize', 6, 'Color', cCells(1, :));
		elseif j == 3
			% 文献仅有比例尺，没有常规 x/y 坐标轴或逐子图轴标签。
			y0 = yl(1) + 0.08 * range(yl);
			x0 = tC(1) + 0.15;
			plot(ax, [x0, x0+1], [y0, y0], 'k-', 'LineWidth', 1, 'Clipping', 'off');
			text(ax, x0+0.5, y0-0.04*range(yl), '1 s', 'HorizontalAlignment', 'center', ...
				'VerticalAlignment', 'top', 'FontName', 'Arial', 'FontSize', 6, 'Clipping', 'off');
			x1 = tC(end) - 0.12;
			plot(ax, [x1, x1], [y0, y0+0.5], '-', 'Color', [0.35, 0.35, 0.35], ...
				'LineWidth', 0.75, 'Clipping', 'off');
			text(ax, x1+0.08, y0+0.25, '0.5 z', 'Rotation', 90, ...
				'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
				'FontName', 'Arial', 'FontSize', 6, 'Color', [0.35, 0.35, 0.35], 'Clipping', 'off');
		end
	end
	axPie = axes(f, 'Units', 'centimeters', 'Position', piePos(ip, :));
	iDrawEarlyPie(axPie, pieMean(1, 1, ip));
	fprintf('%s early-onset = %.2f%% ± %.2f%%（逐鼠 mean±SEM，分母为每鼠全部记录细胞）\n', ...
		phaseName(ip), pieMean(1, 1, ip), pieSem(1, 1, ip));
end

% print -dsvg 在本图隐藏坐标尺的 axes 中会漏掉示例曲线；exportgraphics 已验证可完整保留。
TransferLearning.ApplyStandardExportStyle(f, 1);
svgPath = TransferLearning.StandardFigureSvgPath('English_FigS4A_EarlyOnsetFractionByPhase.svg');
exportgraphics(f, svgPath, 'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4A_Frac', frac);
assignin('base', 'FigS4A_P', struct('pEarly', pE, 'pLate', pL));
assignin('base', 'FigS4A_Example', struct('Mouse', m.Mouse, 'CellIndex', selCell));
assignin('base', 'FigS4A_Pie', struct('MeanPercent', pieMean, 'SemPercent', pieSem));

%% ========== local functions ==========
function iDrawEarlyPie(ax, pct)
% Fig.2a 的黑白饼图：early 为黑，其余记录细胞为浅灰；标签置于灰区。
hold(ax, 'on');
aAll = linspace(0, 2*pi, 361);
patch(ax, cos(aAll), sin(aAll), [0.82, 0.82, 0.82], 'EdgeColor', 'none');
a = linspace(pi/2, pi/2 - 2*pi*pct/100, max(12, ceil(3.6*pct)));
patch(ax, [0, cos(a), 0], [0, sin(a), 0], [0.05, 0.05, 0.05], 'EdgeColor', 'none');
aText = pi/2 - 2*pi*pct/100 - deg2rad(14);
rText = 0.58;
text(ax, rText*cos(aText), rText*sin(aText), sprintf('%.1f%%\nEarly-onset', pct), ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
	'FontName', 'Arial', 'FontSize', 6, 'Color', 'k');
axis(ax, 'equal'); axis(ax, 'off');
xlim(ax, [-1.05, 1.05]); ylim(ax, [-1.05, 1.05]);
end

function tf = iCacheHasPerCellPsth(matPath)
% 热图需逐细胞 PSTH，示例阴影需逐细胞跨 movement SEM，且需覆盖率向量。
tf = false;
if ~isfile(matPath), return; end
S = load(matPath, 'M');
if ~isfield(S, 'M') || isempty(S.M), return; end
M = S.M;
if ~isfield(M, 'psthCellL') || ~isfield(M, 'psthCellT'), return; end
if ~isfield(M, 'psthCellSemL') || ~isfield(M, 'psthCellSemT'), return; end
if ~isfield(M, 'mvCovL') || ~isfield(M, 'mvCovT'), return; end
if ~isfield(M, 'psthAllL'), return; end
tf = ~isempty(M(1).psthCellL) && ~isempty(M(1).psthCellT) && ...
	~isempty(M(1).psthCellSemL) && ~isempty(M(1).psthCellSemT) && ~isempty(M(1).mvCovL);
end

function iRunGeneratorScript(genScript)
if ~isfile(genScript)
	error('FigS4A:NoGenerator', 'Generator script not found: %s', genScript);
end
oldDir = pwd;
try
	cd(fileparts(genScript));
	run(genScript);
catch ME
	cd(oldDir);
	rethrow(ME);
end
cd(oldDir);
end
