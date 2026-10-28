%% FigS4F_DecodeLickFromPreCueState.m
% English FigS4F: decoding learned lick pattern from pre-cue population state。
% 仅复刻 Fig.3d 右侧四组 box-and-whisker 样式：median/IQR、whisker、均值 +；
% 不画文献没有的逐鼠散点，也不复刻与本实验流程不同的左侧解码示意图。
% 科学量按确认保留本工程版本：train=80% Learned 的线索前 PC 均值，test=20%
% Learned+Transfer，目标=每 trial 舔水模板相关；文献则是神经/运动时间轨迹残差，
% 两者不是同义检验。λ 由训练集内 5 折 CV 选，shuffle=测试目标置换 200 次。
%
% Outputs (SVG): English_FigS4F_DecodeLickFromPreCueState.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

ok = isfinite([M.decR]) | isfinite([M.decRheld]);
g1 = [M(ok).decRheld]; g2 = [M(ok).decRheldSh]; g3 = [M(ok).decR]; g4 = [M(ok).decRsh];
g2(isnan(g2)) = 0; g4(isnan(g4)) = 0;
kk = isfinite(g1) & isfinite(g3);          % 剔除解码失败（全零系数）的鼠
g1 = g1(kk); g2 = g2(kk); g3 = g3(kk); g4 = g4(kk);
G = [g1(:), g2(:), g3(:), g4(:)];
[pH, hH] = signrank(g1, g2);
[pT, hT] = signrank(g3, g4);
[p0, h0] = signrank(g3);
fprintf('解码（保留本工程跨情境科学量；Fig.3d 仅作样式参考）：%d 鼠\n', numel(g1));
fprintf('  held-out Learned: 中位 r=%+.3f vs shuffle p=%.4g %s\n', median(g1,'omitnan'), pH, iifS(hH==1,'(显著)','(不显著)'));
fprintf('  Transfer:         中位 r=%+.3f vs shuffle p=%.4g %s；vs 0 p=%.4g %s\n', median(g3,'omitnan'), pT, iifS(hT==1,'(显著)','(不显著)'), p0, iifS(h0==1,'(显著)','(不显著)'));

% ---- figure（仿 Fig.3d 右：四组 box-and-whisker，mean 用 +，不画逐鼠散点）----
groupColor = [0.55, 0.55, 0.55; 0.72, 0.72, 0.72; ...
	0.66, 0.32, 0.50; 0.80, 0.63, 0.72];
f = figure('Color', 'w', 'Name', 'English FigS4F DecodeLickFromPreCueState');
f.Units = 'centimeters';
f.Position(3:4) = [5, 4];
ax = axes(f);
hold(ax, 'on');
for g = 1:4
	bp = boxplot(ax, G(:, g), 'Positions', g, 'Colors', groupColor(g,:), 'Symbol', '', 'Widths', 0.45);
	set(bp, 'LineWidth', 0.6);
	plot(ax, g, mean(G(:, g), 'omitnan'), '+', 'Color', groupColor(g,:), ...
		'MarkerSize', 5, 'LineWidth', 0.75);
end
xlim(ax, [0.4, 4.6]);
set(ax, 'XTick', 1:4, 'XTickLabel', ["Learned"; "shuffled"; "Transfer"; "shuffled"]);
ylabel(ax, 'Prediction accuracy (r)');
iStyleAxes(ax);

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS4F_DecodeLickFromPreCueState.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4F_Stats', struct('held', g1, 'heldSh', g2, 'tr', g3, 'trSh', g4, ...
	'pHeldVsShuf', pH, 'pTrVsShuf', pT, 'pTrVsZero', p0));

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
