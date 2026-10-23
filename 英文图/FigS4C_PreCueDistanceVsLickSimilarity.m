%% FigS4C_PreCueDistanceVsLickSimilarity.m
% English FigS4C: pre-cue population-state distance vs lick-pattern similarity
% （仿 Nature 2026 s41586-026-11174-3 Fig.3d：pre-activity distance 与 learned
%   movement 相似度的负相关散点）
% 文献口径：相似度 = movement trace 与 learned movement 模板的相关/投影；距离 =
% 线索前 [-0.5,0] s 窗内 PC 空间到 learned trajectory 的平均距离。预期负相关：
% 群体状态越接近 learned 轨迹，movement 越像 learned movement。
% 本工程：相似度 = 舔水率 trace（CD2>阈 + 200 ms movmean）在 Learned hit 模板上的
% 投影（LOO）；距离同 FigS4B。散点 = Transfer trial（鼠内 z 后 pooled），
% 标注 pooled Pearson r / Spearman rho 与逐鼠中位 rho + Wilcoxon p。
%
% Outputs (SVG): English_FigS4C_PreCueDistanceVsLickSimilarity.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

% ---- 逐鼠 Spearman rho ----
rhoM = nan(numel(M), 1);
for i = 1:numel(M)
	o = isfinite(M(i).simT) & isfinite(M(i).dPreTz) & isfinite(M(i).corrT);
	if sum(o) < 12 || std(M(i).simT(o)) == 0 || std(M(i).dPreTz(o)) == 0, continue; end
	rhoM(i) = corr(M(i).simT(o), M(i).dPreTz(o), 'Type', 'Spearman');
end
okR = isfinite(rhoM);
[pR, hR] = signrank(rhoM(okR));
fprintf('逐鼠 rho(simT, dPreT)：中位 %+.3f，%d/%d 鼠为负，Wilcoxon p=%.4g %s\n', ...
	median(rhoM(okR)), sum(rhoM(okR) < 0), sum(okR), pR, iifS(hR==1,'(显著)','(不显著)'));

% ---- pooled 散点（鼠内 z：simT 也 z 化）----
X = []; Yb = [];
for i = 1:numel(M)
	s = M(i).simT; d = M(i).dPreTz;
	o = isfinite(s) & isfinite(d) & std(s, 'omitnan') > 0;
	if sum(o) < 5, continue; end
	sz = (s(o) - mean(s(o))) / std(s(o));
	X = [X; sz(:)]; Yb = [Yb; d(o)]; %#ok<AGROW>
end
[rP, pP] = corr(X, Yb);
[rS, pS] = corr(X, Yb, 'Type', 'Spearman');
fprintf('pooled（%d trial）：Pearson r=%+.3f p=%.3g；Spearman rho=%+.3f p=%.3g\n', ...
	numel(X), rP, pP, rS, pS);

% ---- figure ----
colorP = TransferLearning.TransferColor;
colorFit = TransferLearning.ColorA;
f = figure('Color', 'w', 'Name', 'English FigS4C PreCueDistanceVsLickSimilarity');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
ax = axes(f);
hold(ax, 'on'); box(ax, 'off');
ax.FontSize = 12; ax.LineWidth = 2;
scatter(ax, X, Yb, 6, colorP, 'o', 'filled', 'LineWidth', 0.2, 'MarkerFaceAlpha', 0.35);
b = polyfit(X, Yb, 1);
xF = [min(X); max(X)];
plot(ax, xF, polyval(b, xF), '-', 'Color', colorFit, 'LineWidth', 2);
text(ax, 0.96, 0.96, sprintf('r = %+.2f, p = %.3g\nn = %d trials, %d mice', rP, pP, numel(X), sum(okR)), ...
	'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 10);
xlabel(ax, 'Lick-similarity to learned template (z)');
ylabel(ax, 'Pre-cue distance (z)');
ax.Toolbar.Visible = 'off';

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS4C_PreCueDistanceVsLickSimilarity.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4C_Rho', struct('perMouse', rhoM, 'pWilcoxon', pR, 'pooledR', rP, 'pooledP', pP));

function s = iifS(c, a, b)
if c, s = a; else, s = b; end
end
