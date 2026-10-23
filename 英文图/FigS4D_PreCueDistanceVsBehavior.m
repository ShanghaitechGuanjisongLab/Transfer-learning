%% FigS4D_PreCueDistanceVsBehavior.m
% English FigS4D: pre-cue population-state distance predicts trial outcome
% （仿 Nature 2026 s41586-026-11174-3 Fig.3e：pre-stim distance 高 → 低 hit rate；
%   及 Fig.4b 的 trial 级散点/三分位）
% 左 panel：每鼠 hit vs miss 的线索前距离（鼠内 z），bar(mean±SEM)+逐鼠点
%   （样式对应 Fig.5b 的 movement vs no-movement bar+dot）；
% 右 panel：pooled 四分位箱的 movement probability + logistic 拟合曲线
%   （样式/思路对应 Extended Data Fig.9d：初始状态分箱的实际运动概率 + 拟合曲线）。
% 文献预期：距离越大（离 learned 轨迹越远）命中率越低 → 负相关。
%
% Outputs (SVG): English_FigS4D_PreCueDistanceVsBehavior.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

hitColor = TransferLearning.ColorA;
missColor = TransferLearning.ColorB;

% ---- 每鼠 hit/miss 均值（要求两组各 >=3 trial）----
keep = [];
dH = []; dMs = [];
for i = 1:numel(M)
	h = M(i).dPreTz(M(i).YT == 1); ms = M(i).dPreTz(M(i).YT == 0);
	if numel(h) >= 3 && numel(ms) >= 3 && std([h; ms]) > 0
		keep(end+1) = i; %#ok<SAGROW>
		dH(end+1) = mean(h); dMs(end+1) = mean(ms); %#ok<SAGROW>
	end
end
[pW, hW] = signrank(dH, dMs);
nUp = sum(dH > dMs);
fprintf('hit vs miss 线索前距离：%d 鼠可用，%d/%d 鼠 hit>miss，Wilcoxon p=%.4g %s\n', ...
	numel(keep), nUp, numel(keep), pW, iifS(hW==1,'(显著)','(不显著)'));

% ---- pooled 三分位命中率 ----
Rm = [];
for i = 1:numel(M)
	d = M(i).dPreTz; y = M(i).YT;
	o = isfinite(d);
	if sum(o) < 12, continue; end
	rk = tiedrank(d(o));
	bin = ceil(rk ./ (numel(rk)/3)); bin(bin>3) = 3; bin(bin<1) = 1;
	yo = y(o);
	r = nan(1, 3);
	for k = 1:3
		mk = bin == k;
		if any(mk), r(k) = mean(yo(mk)); end
	end
	if all(isfinite(r)), Rm = [Rm; r]; end %#ok<AGROW>
end
pF = friedman(Rm, 1, 'off');
[pHL, hHL] = signrank(Rm(:,3), Rm(:,1));
fprintf('三分位命中率：low %.3f mid %.3f high %.3f；Friedman p=%.4g；high-low 中位差 %+.3f，p=%.4g %s\n', ...
	mean(Rm(:,1)), mean(Rm(:,2)), mean(Rm(:,3)), pF, median(Rm(:,3)-Rm(:,1)), pHL, iifS(hHL==1,'(显著)','(不显著)'));

% ---- figure（左仿 Fig.5b bar+dot；右仿 ED Fig.9d 分箱概率 + 拟合曲线）----
f = figure('Color', 'w', 'Name', 'English FigS4D PreCueDistanceVsBehavior');
f.Units = 'centimeters';
f.Position(3:4) = [15, 8];
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% 左：Hit vs Miss 线索前距离（bar = 鼠均±SEM，dot = 每鼠）
ax = nexttile(tl);
hold(ax, 'on'); box(ax, 'off');
ax.FontSize = 12; ax.LineWidth = 2;
muG = [mean(dH), mean(dMs)];
seG = [std(dH)/sqrt(numel(dH)), std(dMs)/sqrt(numel(dMs))];
bar(ax, 1, muG(1), 0.55, 'EdgeColor', 'none', 'FaceColor', hitColor);
bar(ax, 2, muG(2), 0.55, 'EdgeColor', 'none', 'FaceColor', missColor);
errorbar(ax, [1, 2], muG, seG, 'k.', 'LineWidth', 1.5, 'CapSize', 8);
for i = 1:numel(dH)
	scatter(ax, 1 + 0.18*(rand-0.5), dH(i), 14, hitColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', 'k');
	scatter(ax, 2 + 0.18*(rand-0.5), dMs(i), 14, missColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', 'k');
end
xlim([0.4, 2.6]);
set(ax, 'XTick', [1,2], 'XTickLabel', ["Hit", "Miss"]);
ylabel(ax, 'Pre-cue distance (within-mouse z)');
title(ax, sprintf('Wilcoxon p = %.3g', pW), 'FontSize', 12, 'FontWeight', 'normal');
ax.Toolbar.Visible = 'off';

% 右：movement probability vs initial state 四分位箱（ED Fig.9d 样式）
% 注意：dPreTz 以 pre+post 距离联合标准化，pre 系统性偏负；此面板改用仅 pre 距离的鼠内 z
ax2 = nexttile(tl);
hold(ax2, 'on'); box(ax2, 'off');
ax2.FontSize = 12; ax2.LineWidth = 2;
Xp = []; Yp = []; Xm = [];
for i = 1:numel(M)
	d0 = M(i).dPreT;
	o = isfinite(d0) & std(d0, 'omitnan') > 0;
	if sum(o) < 8, continue; end
	zz = (d0(o) - mean(d0(o))) / std(d0(o));
	Xp = [Xp; zz]; Yp = [Yp; M(i).YT(o)]; Xm = [Xm; i*ones(sum(o),1)]; %#ok<AGROW>
end
qs = quantile(Xp, [0.25, 0.5, 0.75]);
binI = 1 + sum(Xp(:) > qs, 2);
nBin = 4;
rateM = nan(numel(M), nBin); xC = nan(nBin, 1);
for kb = 1:nBin
	selB = binI == kb;
	xC(kb) = mean(Xp(selB));
	for i = 1:numel(M)
		si = selB & Xm == i;
		if any(si), rateM(i, kb) = mean(Yp(si)); end
	end
end
muR = mean(rateM, 1, 'omitnan');
seR = std(rateM, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(rateM), 1));
errorbar(ax2, xC, muR, seR, 'o-', 'Color', TransferLearning.TransferColor, ...
	'LineWidth', 1.6, 'MarkerSize', 6, 'MarkerFaceColor', TransferLearning.TransferColor, 'CapSize', 6);
pGlm = NaN;
try
	glm = fitglm(table(Xp, Yp), 'Yp ~ Xp', 'Distribution', 'binomial');
	pGlm = glm.Coefficients.pValue(2);
	xf = linspace(min(Xp), max(Xp), 100)';
	plot(ax2, xf, predict(glm, table(xf, 'VariableNames', {'Xp'})), '-', 'Color', TransferLearning.ColorA, 'LineWidth', 2);
catch
	fprintf('  [提示] pooled logistic 拟合失败，略曲线。\n');
end
xlabel(ax2, 'Initial state (pre-cue distance, z)');
ylabel(ax2, 'Movement probability');
title(ax2, sprintf('logistic slope p = %.3g', pGlm), 'FontSize', 12, 'FontWeight', 'normal');
ax2.Toolbar.Visible = 'off';

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS4D_PreCueDistanceVsBehavior.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4D_Stats', struct('pWilcoxon', pW, 'pFriedman', pF, 'pHighLow', pHL, 'Rm', Rm, 'dH', dH, 'dMs', dMs));

function s = iifS(c, a, b)
if c, s = a; else, s = b; end
end
