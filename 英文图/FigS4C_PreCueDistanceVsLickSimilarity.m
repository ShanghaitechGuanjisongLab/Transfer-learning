%% FigS4C_PreCueDistanceVsLickSimilarity.m
% English FigS4C: pre-cue population-state distance vs lick-pattern correlation。
% 样式对应文献 Fig.4a/b 右：x=线索前 [-0.5,0] s 的平均轨迹距离，y=运动相关。
% 本工程纵轴为 corrT，即舔水率 trace（CD2>阈 + 200 ms 平滑）与 Learned hit
% 舔水模板的 Pearson r；不是投影系数 simT。散点为 Transfer trial，距离鼠内 z
% 后 pooled；统计只在命令行报告，图内保留文献式散点、拟合线和阶段标签。
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

% ---- 逐鼠 Spearman rho：文献 Fig.4a/b 右的 x=距离、y=运动相关 ----
rhoM = nan(numel(M), 1);
for i = 1:numel(M)
	cr = M(i).corrT; d = M(i).dPreTz;
	o = isfinite(cr) & isfinite(d);
	if sum(o) < 12 || std(cr(o)) == 0 || std(d(o)) == 0, continue; end
	rhoM(i) = corr(d(o), cr(o), 'Type', 'Spearman');
end
okR = isfinite(rhoM);
[pR, hR] = signrank(rhoM(okR));
fprintf('逐鼠 rho(dPreT, corrT)：中位 %+.3f，%d/%d 鼠为负，Wilcoxon p=%.4g %s\n', ...
	median(rhoM(okR)), sum(rhoM(okR) < 0), sum(okR), pR, iifS(hR==1,'(显著)','(不显著)'));

% ---- pooled 散点：距离沿用原鼠内 z，纵轴保留真实 Pearson 相关系数 ----
X = []; Yb = [];
for i = 1:numel(M)
	d = M(i).dPreTz; cr = M(i).corrT;
	o = isfinite(d) & isfinite(cr);
	if sum(o) < 5 || std(d(o)) == 0, continue; end
	X = [X; d(o)]; Yb = [Yb; cr(o)]; %#ok<AGROW>
end
[rP, pP] = corr(X, Yb);
[rS, pS] = corr(X, Yb, 'Type', 'Spearman');
fprintf('pooled（%d trial）：Pearson r=%+.3f p=%.3g；Spearman rho=%+.3f p=%.3g\n', ...
	numel(X), rP, pP, rS, pS);

% ---- figure ----
colorFit = [0.66, 0.32, 0.50];
colorPoint = 0.65*colorFit + 0.35;
f = figure('Color', 'w', 'Name', 'English FigS4C PreCueDistanceVsLickSimilarity');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4];
ax = axes(f);
hold(ax, 'on');
scatter(ax, X, Yb, 6, colorPoint, 'o', 'filled', 'MarkerEdgeColor', 'none');
b = polyfit(X, Yb, 1);
xF = linspace(min(X), max(X), 100);
plot(ax, xF, polyval(b, xF), '-', 'Color', colorFit, 'LineWidth', 0.75);
text(ax, 0.04, 0.06, 'Transfer', 'Units', 'normalized', 'VerticalAlignment', 'bottom', ...
	'FontName', 'Arial', 'FontSize', 6, 'Color', colorFit);
xlabel(ax, {'Population activity distance', 'before cue onset (z)'});
ylabel(ax, {'Correlation with', 'learned movement'});
ylim(ax, [-0.2, 1.05]); set(ax, 'YTick', 0:0.5:1);
iStyleAxes(ax);

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS4C_PreCueDistanceVsLickSimilarity.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4C_Rho', struct('perMouse', rhoM, 'pWilcoxon', pR, 'pooledR', rP, 'pooledP', pP));

function iStyleAxes(ax)
box(ax, 'off');
ax.FontName = 'Arial'; ax.FontSize = 6; ax.LineWidth = 0.5;
ax.XColor = 'k'; ax.YColor = 'k'; ax.TickDir = 'out'; ax.TickLength = [0.025, 0.025];
ax.LabelFontSizeMultiplier = 1; ax.TitleFontSizeMultiplier = 1;
if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end

function s = iifS(c, a, b)
if c, s = a; else, s = b; end
end
