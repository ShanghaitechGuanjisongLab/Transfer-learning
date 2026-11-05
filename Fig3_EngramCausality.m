% Fig3｜印迹细胞是迁移的因果载体（仅生成 MATLAB 图窗）
%
% A  cFos-TRAP 标记 + CNO 抑制流程示意
% B  Control vs cFos 抑制组的光水学习曲线（组水平 Sigmoid）
% C  首 light-water block 命中率（逐鼠）
% D  cFos 组旧任务细胞的重激活率 —— 计划内容（现有 cFos 数据只有行为，无 tagged 细胞钙成像）
% E  印迹细胞响应强度随任务间间隔的衰减 —— 计划内容（逐细胞响应幅度，与 Fig2 的重激活比例/群体异质性不重复）
%
% 说明：重激活率的时间依赖、散度的时间依赖已放在 Fig2，本图不重复。
% 若 cFos 数据文件不可用，B/C 以"计划内容"占位，不报错。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

colors = [TransferLearning.TransferColor; TransferLearning.ColorB];

hasCFos = false;
S = table();
try
	S = TransferLearning.BehaviorSessions.CFosInhibitionSessions();
	hasCFos = ~isempty(S);
catch
	hasCFos = false;
end

pGroup7 = NaN;
pFirst = NaN;
firstCtrl = [];
firstC = [];
meanMat = {};
semMat = {};
xMax = 7;
if hasCFos
	PerMouse = TransferLearning.Metrics.PerMouseSessionSummary(S);
	s7 = S(S.Session <= 7, :);
	pGroup7 = TransferLearning.Style.TwoWayAnovaGroupPValue(s7, 'Performance', 'Session', 'Group', 'Mouse');
	firstCtrl = PerMouse.FirstPerf(PerMouse.Group == "Control");
	firstC = PerMouse.FirstPerf(PerMouse.Group == "MOp");
	pFirst = iRanksum(firstCtrl, firstC);

	[~, summaryL] = evalc('UniExp.LearningSummarize(S(:,{''Mouse'',''DateTime'',''Performance'',''Group''}))');
	rowNames = string(summaryL.Properties.RowNames);
	groupOrder = ["Control", "MOp"];
	meanMat = cell(1, 2);
	semMat = cell(1, 2);
	for k = 1:2
		ix = find(rowNames == groupOrder(k), 1, 'first');
		mv = double(summaryL.MeanCurve{ix}(:));
		sv = double(summaryL.SemCurve{ix}(:));
		meanMat{k} = mv(1:find(isfinite(mv), 1, 'last')).';
		semMat{k} = sv(1:find(isfinite(sv), 1, 'last')).';
	end
	xMax = min(12, min(cellfun(@numel, meanMat)));
	for k = 1:2
		meanMat{k} = meanMat{k}(1:xMax);
		semMat{k} = semMat{k}(1:xMax);
	end
end

% 印迹细胞强度（12 h vs 7 d）——需 AudioLightBaseline 与 Vacation7
hasStrength = false;
Str12 = table();
Str7 = table();
pStrLearned = NaN;
pStrTransfer = NaN;
try
	ALB = TransferLearning.AudioLightBaseline();
	V7 = TransferLearning.Vacation7();
	Str12 = TransferLearning.Metrics.EngramResponseStrength(ALB);
	Str7 = TransferLearning.Metrics.EngramResponseStrength(V7);
	hasStrength = ~isempty(Str12) && ~isempty(Str7);
	if hasStrength
		pStrLearned = iRanksum(Str12.AmpLearned, Str7.AmpLearned);
		pStrTransfer = iRanksum(Str12.AmpTransfer, Str7.AmpTransfer);
	end
catch
	hasStrength = false;
end

%% 出图
f = figure('Color', 'w', 'Name', 'Fig3 engram causality');
f.Units = 'centimeters';
f.Position(3:4) = [20, 9];
pos = struct( ...
	'A', [0.03 0.55 0.24 0.33], ...
	'B', [0.33 0.51 0.24 0.37], ...
	'C', [0.63 0.55 0.15 0.33], ...
	'D', [0.15 0.07 0.24 0.28], ...
	'E', [0.52 0.07 0.24 0.28]);

axA = axes(f, 'Position', pos.A);
iDrawTaggingSchematic(axA, colors);

axB = axes(f, 'Position', pos.B);
if hasCFos
	hold(axB, 'on');
	MATLAB.Graphics.MultiShadowedLines(meanMat, semMat, 1 / 3, EdgeColors=colors);
	for k = 1:2
		fit = iFitSigmoid(S(S.Group == groupOrder(k), :));
		plot(axB, (1:xMax).', iSigmoid(fit.ParamRaw, (1:xMax).'), '--', 'Color', colors(k, :), ...
			'LineWidth', 1, 'HandleVisibility', 'off');
	end
	proxy = gobjects(2, 1);
	for k = 1:2
		proxy(k) = plot(axB, nan, nan, '-', 'Color', colors(k, :), 'LineWidth', 2);
	end
	xlabel(axB, 'Block');
	ylabel(axB, 'Hit rate');
	xlim(axB, [1, xMax]);
	ylim(axB, [0, 1.18]);
	plot(axB, [1, 7], [1.02, 1.02], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
	text(axB, 4, 1.04, TransferLearning.Style.iFormatPText(pGroup7), 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
	yticks(axB, 0:0.2:1);
	lg = legend(axB, proxy, {'Control', 'cFos inhibited'}, 'Location', 'southeast');
	lg.Box = 'off';
	box(axB, 'off');
else
	iPlaceholder(axB, 'Learning curve', {'control vs cFos-inhibited'}, 'pending: cFos dataset unavailable');
end
title(axB, 'Light-water learning curve', 'FontWeight', 'normal');

axC = axes(f, 'Position', pos.C);
if hasCFos
	iBarPanel(axC, {firstCtrl, firstC}, [1 2], pFirst, colors, ["Ctrl", "cFos"], 'First light-water block', 0.05);
else
	iPlaceholder(axC, 'First block', {'per-mouse hit rate'}, 'pending: cFos dataset');
	title(axC, 'First light-water block', 'FontWeight', 'normal', 'FontSize', 8);
end

axD = axes(f, 'Position', pos.D);
iPlaceholder(axD, '', ...
	{'fraction of tagged cells reactivated in', 'the first light-water block, cFos vs control'}, ...
	'data not available: cFos dataset holds behaviour only (no Cells)');
title(axD, 'Engram reactivation (planned)', 'FontWeight', 'normal', 'FontSize', 8);

% E 印迹细胞响应强度 12 h vs 7 d（旧任务学会时等价，迁移块衰减）
axE = axes(f, 'Position', pos.E);
if hasStrength
	iBarPanel(axE, {Str12.AmpTransfer, Str7.AmpTransfer}, [1 2], pStrTransfer, colors, ...
		["12 h", "7 d"], 'Engram z, first LW', 0.05);
	text(axE, 0.03, 0.93, sprintf('identified: %.2f vs %.2f, p = %.2f', ...
		mean(Str12.AmpLearned), mean(Str7.AmpLearned), pStrLearned), ...
		'Units', 'normalized', 'FontSize', 6, 'Color', [0.45 0.45 0.45]);
else
	iPlaceholder(axE, 'Engram response strength (planned)', ...
		{'per-cell response amplitude at cue +1 s,', 'learned-active cells: 12 h vs 7 d'}, ...
		'pending: AudioLightBaseline / Vacation7 not available');
	title(axE, 'Engram strength decay', 'FontWeight', 'normal', 'FontSize', 8);
end

iPanelLetters(f, {axA, axB, axC, axD, axE});
annotation(f, 'textbox', [0.02 0.978 0.9 0.03], 'String', ...
	'Fig3  Engram cells causally carry the cross-modal transfer', ...
	'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold');

outDir = fileparts(TransferLearning.StandardFigureSvgPath('Fig3_EngramCausality.svg'));
figPath = fullfile(outDir, 'Fig3_EngramCausality.fig');
savefig(f, figPath);
fprintf('Saved: %s\n', figPath);

fprintf('\n=== Fig3 ===\n');
if hasCFos
	fprintf('Control n=%d first=%.3f+-%.3f | cFos n=%d first=%.3f+-%.3f | p=%.4g\n', ...
		numel(firstCtrl), mean(firstCtrl), iSem(firstCtrl), numel(firstC), mean(firstC), iSem(firstC), pFirst);
	fprintf('Learning curve group p (blocks 1-7) = %.4g\n', pGroup7);
else
	fprintf('cFos dataset unavailable: panels B/C left as placeholders.\n');
end

assignin('base', 'Fig3_Data', struct('Sessions', S, 'HasCFos', hasCFos, 'PGroup7', pGroup7, ...
	'PFirst', pFirst, 'FirstCtrl', firstCtrl, 'FirstCFos', firstC));

%% ------------------------------------------------------------------
function iDrawTaggingSchematic(ax, colors)
hold(ax, 'on');
axis(ax, 'off');
xlim(ax, [0, 10]);
ylim(ax, [1.2, 10.6]);
steps = ["AAV-DIO-hM4D into MOp"; "learn audio-water"; "TM + 24 h recall"; "1-2 wk expression"; "CNO before light"];
yStep = [8.4, 6.8, 5.2, 3.6, 2.0];
for k = 1:5
	patch(ax, [0.4 8.4 8.4 0.4], yStep(k) + [0 0 1.5 1.5], colors(2, :), ...
		'FaceAlpha', 0.12, 'EdgeColor', colors(2, :), 'LineWidth', 0.6);
	text(ax, 4.4, yStep(k) + 0.75, steps(k), 'FontSize', 6, 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle');
end
end

function iPlaceholder(ax, ttl, lines, note)
axis(ax, 'off');
text(ax, 0.5, 0.82, ttl, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
	'FontSize', 8, 'FontWeight', 'bold');
text(ax, 0.5, 0.48, lines, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
	'FontSize', 7, 'Color', [0.4 0.4 0.4]);
text(ax, 0.5, 0.15, note, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
	'FontSize', 7, 'Color', [0.6 0.6 0.6], 'Interpreter', 'none');
box(ax, 'off');
end

function iPanelLetters(f, axList)
letters = ["A", "B", "C", "D", "E", "F"];
for k = 1:numel(axList)
	p = axList{k}.Position;
	annotation(f, 'textbox', [p(1) - 0.008, p(2) + p(4) + 0.005, 0.04, 0.03], ...
		'String', letters(k), 'FontSize', 10, 'FontWeight', 'bold', 'EdgeColor', 'none', ...
		'VerticalAlignment', 'bottom');
end
end

function iBarPanel(ax, data, pairs, pVals, cols, labels, ttl, thr)
data = reshape(data, 1, []);
axes(ax);
CompareGroup = table(pairs, 'VariableNames', {'GroupPair'});
[~, Opt, Bars, EB] = UniExp.BarScatterCompare(data, UniExp.Flags.empty, CompareGroup, ...
	UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', thr);
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = cols;
else
	for k = 1:numel(Bars)
		Bars(k).FaceColor = cols(k, :);
	end
end
for k = 1:numel(Bars)
	Bars(k).BarWidth = 0.5;
	Bars(k).EdgeColor = 'none';
	Bars(k).FaceAlpha = 1;
end
if istable(EB) && ~isempty(EB) && ismember('Object', EB.Properties.VariableNames)
	for k = 1:height(EB)
		eb = EB.Object(k);
		if isgraphics(eb) && k <= size(cols, 1)
			eb.Color = cols(k, :);
		end
	end
end
yTop = 0;
if isfield(Opt, 'MultiCompare') && istable(Opt.MultiCompare) && ismember('PText', Opt.MultiCompare.Properties.VariableNames)
	pairStr = string(num2str(pairs));
	for k = 1:height(Opt.MultiCompare)
		gp = string(num2str(Opt.MultiCompare.GroupPair(k, :)));
		pick = find(ismember(pairStr, gp), 1, 'first');
		pt = Opt.MultiCompare.PText(k);
		pl = Opt.MultiCompare.PLine(k);
		if isgraphics(pt) && ~isempty(pick)
			pt.String = TransferLearning.Style.iFormatPText(pVals(pick));
		end
		if isgraphics(pl)
			yTop = max(yTop, max(pl.YData));
		end
	end
end
ax.XTick = 1:numel(labels);
ax.XTickLabel = cellstr(labels);
title(ax, ttl, 'FontWeight', 'normal', 'FontSize', 8);
if yTop > 0
	ylim(ax, [0, yTop * 1.12]);
end
box(ax, 'off');
end

function p = iRanksum(x, y)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(x, y);
end

function s = iSem(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end

function fitOut = iFitSigmoid(T)
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
p0 = [log(0.8); max(median(xObs), 1)];
p = fminsearch(@(q) sum((yObs - iSigmoid(q, xObs)).^2, 'omitnan'), p0, ...
	optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000));
fitOut = struct('ParamRaw', p);
end

function y = iSigmoid(p, x)
y = 1 ./ (1 + exp(-exp(p(1)) .* (x - p(2))));
end
