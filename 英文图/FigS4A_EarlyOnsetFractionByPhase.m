%% FigS4A_EarlyOnsetFractionByPhase.m
% English FigS4A: early-onset 细胞的直观展示与占比，Learned vs Transfer
% （仿 Nature 2026 s41586-026-11174-3 Fig.1c）
% 文献口径：movement(=舔水)锁定 PSTH，onset = 基线([-1,-0.5]s)+1SD 且持续
% 200 ms（200 Hz 上采样网格）；onset<0 → early-onset，onset≥0 → late-onset，
% 无 onset → no onset。占比 = 各类细胞数 / 全部记录细胞。
% 体例：**先直观展示原始活动热图（仿 Fig.1c 左，让读者先看到"early-onset"是什么），
% 再做统计**。数据源：FigS4_PreCueStatePCA_Analysis.m（AudioLightBaseline：每鼠
% Learned(AudioWater) 与 Transfer(LightWater) block 分别判定）。六个 panel（2 行×3 列）：
%   1/2) Learned / Transfer：全部鼠全部细胞的逐神经元 lick(movement) 锁定 PSTH 热图，
%        行序 = early-onset（onset 升序）→ late-onset（onset 升序）→ no onset（峰值降序），
%        白競线 = movement(lick) onset(t=0)，每行一个神经元，n = neurons/sessions/mice；
%        early 行在白競线左侧即开始变亮 = 直观看出“运动前就激活”（仿 Fig.1c 左）；
%   3) early-onset 细胞 lick 锁定平均 PSTH ± SEM（仿 Fig.1c 右示例轨迹）；
%   4/5) early/late/no-onset 占比堆叠条（Learned / Transfer，逐鼠）；
%   6) 逐鼠配对 early% 与 Wilcoxon p。
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

% ---- figure（3 tiles：两阶段占比堆叠条 + early 细胞 lick 锁定 PSTH，后者仿 Fig.1c 右）----
cEarly = [0.478, 0.204, 0.012];       % 文献深棕
cLate  = [255, 127, 14] ./ 255;       % 文献橙
cNone  = [0.85, 0.85, 0.85];          % 文献浅灰
phaseColor = [TransferLearning.LearnedColor; TransferLearning.TransferColor];
phaseName = ["Learned (🔊💧)", "Transfer (💡💧)"];

f = figure('Color', 'w', 'Name', 'English FigS4A EarlyOnsetFractionByPhase');
f.Units = 'centimeters';
f.Position(3:4) = [22, 15];
tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
axList = gobjects(3, 1);

% ---- tile 1/2：逐神经元 lick 锁定 PSTH 热图（仿 Fig.1c 左：直观、原始地展示 early-onset）----
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
cLimC = [prctile(vF, 1), prctile(vF, 99.3)];
for ph = 1:2
	ax = nexttile(tl, ph);
	hold(ax, 'on'); box(ax, 'off');
	nTot = sum(grp(:, ph));
	yRow = (0 : -1 : -(nTot-1))';
	imagesc(ax, tC, yRow, heat{ph});
	set(ax, 'YDir', 'normal');
	% 锁定 Y 轴限到图像数据实际范围 [-(nTot-1)-0.5, 0.5]：否则 auto 轴限会取整到“整千”
	% （如 -6000），在图像底部留出一段不覆盖数据的空白（约占高度 15%），且与 colorbar 不对齐。
	ylim(ax, [-nTot + 0.5, 0.5]);
	ax.YLimMode = 'manual';
	colormap(ax, parula);
	clim(ax, cLimC);
	xline(ax, 0, '--', 'Color', 'w', 'LineWidth', 2);
	yline(ax, -grp(1, ph) - 0.5, '-', 'Color', 'w', 'LineWidth', 1.5);
	yline(ax, -grp(1, ph) - grp(2, ph) - 0.5, '-', 'Color', 'w', 'LineWidth', 1.5);
	yb = [-grp(1, ph)-grp(2, ph)-grp(3, ph)/2, ...   % YTick 须递增；y 向下为负
		-(grp(1, ph) + grp(2, ph)/2), -grp(1, ph)/2];
	ax.YTick = yb;
	if ph == 1
		ax.YTickLabel = {'no onset', 'late', 'early'};
		ylabel(ax, 'Neuron (sorted by activity onset)');
		cb = colorbar(ax); cb.Label.String = 'z (\DeltaF/F)';
	else
		ax.YTickLabel = {};   % 行类别只标在首列，避免重复
	end
	ax.XTick = -1.5 : 0.5 : tC(end);
	xlim(ax, [tC(1), tC(end)]);
	xlabel(ax, 'Time from lick (movement) onset (s)');
	title(ax, phaseName(ph), 'Color', phaseColor(ph, :), 'FontSize', 12, 'FontWeight', 'bold');
	if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end

for ip = 1:2
	ax = nexttile(tl, ip + 3);
	axList(ip) = ax;
	hold(ax, 'on'); box(ax, 'off');
	ax.FontSize = 12; ax.LineWidth = 2; ax.FontName = 'Segoe UI Emoji';
	b = bar(ax, 1:nM, squeeze(frac(:, :, ip)), 'stacked', 'BarWidth', 0.7, 'EdgeColor', 'none');
	b(1).FaceColor = cEarly; b(2).FaceColor = cLate; b(3).FaceColor = cNone;
	ylim([0, 100]);
	ylabel(ax, '% of recorded cells');
	xlabel(ax, 'Mouse');
	title(ax, phaseName(ip), 'Color', phaseColor(ip,:), 'FontSize', 12, 'FontWeight', 'bold');
	set(ax, 'XTick', 1:nM, 'XTickLabel', string({M.Mouse})', 'FontSize', 7, ...
		'XTickLabelRotation', 90);
	if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end

% tile 3：early-onset 细胞 lick(=movement) 锁定平均 PSTH（仿 Fig.1c 右示例轨迹）
% 各鼠原生帧率不同（8/30 Hz）→ 用与热图相同的公共 100 Hz 网格跨鼠平均
ax = nexttile(tl, 3);
axList(3) = ax;
hold(ax, 'on'); box(ax, 'off');
ax.FontSize = 12; ax.FontName = 'Segoe UI Emoji'; ax.LineWidth = 2;
PL = nan(numel(tC), nM); PT = nan(numel(tC), nM);
for i = 1:nM
	PL(:, i) = interp1(M(i).tP(:), M(i).psthEL(:), tC, 'linear', nan);
	PT(:, i) = interp1(M(i).tP(:), M(i).psthET(:), tC, 'linear', nan);
end
mL = mean(PL, 2, 'omitnan'); sL = std(PL, 0, 2, 'omitnan') ./ sqrt(sum(isfinite(PL), 2));
mT = mean(PT, 2, 'omitnan'); sT = std(PT, 0, 2, 'omitnan') ./ sqrt(sum(isfinite(PT), 2));
% 单鼠无 early 细胞时该鼠列为 NaN（omitnan 均値合法跳过）；但显示曲线本身必须处处有限
if ~all(isfinite(mL)) || ~all(isfinite(mT)) || ~all(isfinite(sL)) || ~all(isfinite(sT))
	error('FigS4A:NaNInTrace', 'early 细胞平均 PSTH 曲线含 NaN：无鼠可平均的时间点落在显示窗内。');
end
patch(ax, [tC; flipud(tC)], [mL+sL; flipud(mL-sL)], phaseColor(1,:), 'EdgeColor', 'none', 'FaceAlpha', 0.2);
patch(ax, [tC; flipud(tC)], [mT+sT; flipud(mT-sT)], phaseColor(2,:), 'EdgeColor', 'none', 'FaceAlpha', 0.2);
hL = plot(ax, tC, mL, '-', 'Color', phaseColor(1,:), 'LineWidth', 2);
hT = plot(ax, tC, mT, '-', 'Color', phaseColor(2,:), 'LineWidth', 2);
xline(ax, 0, ':k', 'LineWidth', 2);
xlim(ax, [tC(1), tC(end)]);
xlabel(ax, 'Time from lick onset (s)');
ylabel(ax, 'z-score');
title(ax, 'Early-onset cells', 'FontSize', 12, 'FontWeight', 'normal');
lg0 = legend(ax, [hL, hT], {'Learned', 'Transfer'}, 'Location', 'northwest', 'Box', 'off');
lg0.FontSize = 10;
ax.Toolbar.Visible = 'off';

% tile 6：逐鼠配对 early-onset 占比（Learned → Transfer）与 Wilcoxon p
ax = nexttile(tl, 6);
hold(ax, 'on'); box(ax, 'off');
ax.FontSize = 12; ax.FontName = 'Segoe UI Emoji'; ax.LineWidth = 2;
eL = frac(:, 1, 1); eT = frac(:, 1, 2);
for i = 1:nM
	plot(ax, [1, 2], [eL(i), eT(i)], '-o', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, ...
		'MarkerSize', 4, 'MarkerFaceColor', [0.6 0.6 0.6], 'HandleVisibility', 'off');
end
plot(ax, [1, 2], [median(eL), median(eT)], '-s', 'Color', [0.1 0.1 0.1], 'LineWidth', 2.5, ...
	'MarkerSize', 8, 'MarkerFaceColor', [0.1 0.1 0.1]);
set(ax, 'XTick', 1:2, 'XTickLabel', {'Learned', 'Transfer'});
ylabel(ax, sprintf('%% early-onset cells (%d/%d up)', sum(eT > eL), nM));
title(ax, sprintf('Wilcoxon p = %.3f', pE), 'FontSize', 12, 'FontWeight', 'normal');
if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end

lg = legend(axList(1), {"early-onset", "late-onset", "no onset"}, 'Location', 'southoutside', ...
	'Orientation', 'horizontal', 'Box', 'off');
lg.FontSize = 12;
ttl = title(tl, {'rows sorted by activity onset; white dashed line = movement (lick) onset', ...
	sprintf('n = %d / %d neurons (Learned / Transfer), %d sessions, %d mice', ...
	sum(grp(:, 1)), sum(grp(:, 2)), 2*nM, nM)});
ttl.FontSize = 12;

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS4A_EarlyOnsetFractionByPhase.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4A_Frac', frac);
assignin('base', 'FigS4A_P', struct('pEarly', pE, 'pLate', pL));

%% ========== local functions ==========
function tf = iCacheHasPerCellPsth(matPath)
% 旧版缓存只存了跨细胞平均 PSTH，画不了逐神经元热图 → 需重跑生成器
% 且需含 movement 覆盖率向量 mvCovL（用于右端裁剪）
tf = false;
if ~isfile(matPath), return; end
S = load(matPath, 'M');
if ~isfield(S, 'M') || isempty(S.M), return; end
M = S.M;
if ~isfield(M, 'psthCellL') || ~isfield(M, 'psthCellT'), return; end
if ~isfield(M, 'mvCovL') || ~isfield(M, 'mvCovT'), return; end
if ~isfield(M, 'psthAllL'), return; end   % 旧版 psthEL 为全细胞均值（误标），新版才是 early-only
tf = ~isempty(M(1).psthCellL) && ~isempty(M(1).psthCellT) && ~isempty(M(1).mvCovL);
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
