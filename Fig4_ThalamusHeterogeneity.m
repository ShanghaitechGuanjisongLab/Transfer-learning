% Fig4｜速率项由群体异质性与丘脑调制承载（仅生成 MATLAB 图窗）
%
% A  丘脑（thalamus）抑制示意
% B  光水学习曲线：Control（ALB）vs 丘脑抑制（THInhibit）
% C  L2/3 响应异质性：Control vs TH
% D  L5 响应异质性：Control vs TH
% E  首 block 命中率：Control vs TH（预期无差异）
% F  模型学习曲线（若有 THModel 共享数据则绘制，否则留空并提示）

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

ALB = TransferLearning.AudioLightBaseline();
TH = TransferLearning.THInhibit();

colors = [TransferLearning.TransferColor; TransferLearning.ColorB];

% 行为：Control = ALB 的 Transfer→Final（光水）；TH = THInhibit 的光水阶段
SessCtrl = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
SessCtrl = SessCtrl(SessCtrl.Group == "Transfer", :);
SessCtrl = SessCtrl(:, {'Group','Mouse','DateTime','Performance'});
SessCtrl.Group(:) = "Control";
SessTH = iTHLightWaterSessions(TH);
SessTH = SessTH(:, {'Group','Mouse','DateTime','Performance'});
AllSess = [SessCtrl; SessTH];
AllSess.Group = string(AllSess.Group);
AllSess = sortrows(AllSess, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(AllSess.Group, AllSess.Mouse);
cellIdx = splitapply(@(x) {(1:numel(x))'}, AllSess.DateTime, G);
AllSess.Session = vertcat(cellIdx{:});

groupOrder = ["Control", "THinhibited"];
PerMouse = TransferLearning.Metrics.PerMouseSessionSummary(AllSess);
s7 = AllSess(AllSess.Session <= 7, :);
pGroup7 = TransferLearning.Style.TwoWayAnovaGroupPValue(s7, 'Performance', 'Session', 'Group', 'Mouse');
firstCtrl = PerMouse.FirstPerf(PerMouse.Group == "Control");
firstTH = PerMouse.FirstPerf(PerMouse.Group == "THinhibited");
pFirst = iRanksum(firstCtrl, firstTH);

[~, summaryL] = evalc('UniExp.LearningSummarize(AllSess(:,{''Mouse'',''DateTime'',''Performance'',''Group''}))');
rowNames = string(summaryL.Properties.RowNames);
meanMat = cell(1, 2);
semMat = cell(1, 2);
for k = 1:2
	ix = find(rowNames == groupOrder(k), 1, 'first');
	mv = double(summaryL.MeanCurve{ix}(:));
	sv = double(summaryL.SemCurve{ix}(:));
	meanMat{k} = mv(1:find(isfinite(mv), 1, 'last')).';
	semMat{k} = sv(1:find(isfinite(sv), 1, 'last')).';
end
xMax = min(10, min(cellfun(@numel, meanMat)));
for k = 1:2
	meanMat{k} = meanMat{k}(1:xMax);
	semMat{k} = semMat{k}(1:xMax);
end

% 异质性
RHCtrl = TransferLearning.Metrics.ResponseHeterogeneity(ALB, ...
	iRHSessions(AllSess(AllSess.Group == "Control", :)), "LightWater");
RHTH = TransferLearning.Metrics.ResponseHeterogeneity(TH, ...
	iRHSessions(AllSess(AllSess.Group == "THinhibited", :)), "LightWater");
RHCtrl.Group(:) = "Control";
RHTH.Group(:) = "THinhibited";
RH = [RHCtrl; RHTH];
RH.Group = string(RH.Group);

rh23 = {RH.SD(RH.Group == "Control" & RH.Layer == "MOp2/3"); RH.SD(RH.Group == "THinhibited" & RH.Layer == "MOp2/3")};
rh5 = {RH.SD(RH.Group == "Control" & RH.Layer == "MOp5"); RH.SD(RH.Group == "THinhibited" & RH.Layer == "MOp5")};
pRH23 = iRanksum(rh23{1}, rh23{2});
pRH5 = iRanksum(rh5{1}, rh5{2});

%% 出图
f = figure('Color', 'w', 'Name', 'Fig4 thalamus and heterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [18, 9];
pos = struct( ...
	'A', [0.03 0.55 0.20 0.38], ...
	'B', [0.30 0.50 0.26 0.40], ...
	'C', [0.62 0.58 0.15 0.33], ...
	'D', [0.82 0.58 0.15 0.33], ...
	'E', [0.10 0.08 0.16 0.28]);

axA = axes(f, 'Position', pos.A);
iDrawTHSchematic(axA, colors);

axB = axes(f, 'Position', pos.B);
hold(axB, 'on');
MATLAB.Graphics.MultiShadowedLines(meanMat, semMat, 1 / 3, EdgeColors=colors);
for k = 1:2
	fit = iFitSigmoid(AllSess(AllSess.Group == groupOrder(k), :));
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
title(axB, 'Light-water learning curve', 'FontWeight', 'normal');
lg = legend(axB, proxy, {'Control (AW→12h→LW)', 'Thalamus inhibited'}, 'Location', 'southeast');
lg.Box = 'off';
box(axB, 'off');

axC = axes(f, 'Position', pos.C);
iBarPanel(axC, rh23, [1 2], pRH23, colors, ["Ctrl", "TH"], 'L2/3 heterogeneity (LW)', 0.05);

axD = axes(f, 'Position', pos.D);
iBarPanel(axD, rh5, [1 2], pRH5, colors, ["Ctrl", "TH"], 'L5 heterogeneity (LW)', 0.05);

axE = axes(f, 'Position', pos.E);
iBarPanel(axE, {firstCtrl, firstTH}, [1 2], pFirst, colors, ["Ctrl", "TH"], 'First light-water block', 0.05);

iPanelLetters(f, {axA, axB, axC, axD, axE});
annotation(f, 'textbox', [0.02 0.965 0.9 0.03], 'String', ...
	'Fig4  Thalamic drive sustains L5 heterogeneity and the learning-rate component', ...
	'EdgeColor', 'none', 'FontSize', 8.5, 'FontWeight', 'bold');

outDir = fileparts(TransferLearning.StandardFigureSvgPath('Fig4_ThalamusHeterogeneity.svg'));
figPath = fullfile(outDir, 'Fig4_ThalamusHeterogeneity.fig');
savefig(f, figPath);
fprintf('Saved: %s\n', figPath);

fprintf('\n=== Fig4 ===\n');
for k = 1:2
	g = groupOrder(k);
	fprintf('%-13s n=%d first=%.3f+-%.3f\n', g, ...
		numel(unique(AllSess.Mouse(AllSess.Group == g))), ...
		mean(PerMouse.FirstPerf(PerMouse.Group == g)), iSem(PerMouse.FirstPerf(PerMouse.Group == g)));
end
fprintf('Learning-curve group p (blocks 1-7) = %.4g ; first-block p = %.4g\n', pGroup7, pFirst);
fprintf('RH L2/3 control %.3f (n=%d) vs TH %.3f (n=%d), p = %.4g\n', ...
	mean(rh23{1}), numel(rh23{1}), mean(rh23{2}), numel(rh23{2}), pRH23);
fprintf('RH L5   control %.3f (n=%d) vs TH %.3f (n=%d), p = %.4g\n', ...
	mean(rh5{1}), numel(rh5{1}), mean(rh5{2}), numel(rh5{2}), pRH5);

assignin('base', 'Fig4_Data', struct('Sessions', AllSess, 'PerMouse', PerMouse, 'RH', RH, ...
	'PGroup7', pGroup7, 'PFirst', pFirst, 'PRH23', pRH23, 'PRH5', pRH5));

%% ------------------------------------------------------------------
function S = iTHLightWaterSessions(DS)
Tq = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false);
Tq.Mouse = string(Tq.Mouse);
S = TransferLearning.BehaviorSessions.iSessionizeByDateTime(Tq);
S.Phase = string(S.Phase);
S = sortrows(S, {'Mouse','DateTime'});
mice = unique(S.Mouse);
keep = false(height(S), 1);
for i = 1:numel(mice)
	idx = find(S.Mouse == mice(i));
	ph = S.Phase(idx);
	st = find(ph == "Transfer", 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == "Final" & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keep(idx(st:ed)) = true;
end
S = S(keep, :);
S.Group = repmat("THinhibited", height(S), 1);
end

function out = iRHSessions(S)
out = sortrows(S(:, {'Mouse','DateTime','Performance','Session'}), {'Mouse','Session'});
keep = false(height(out), 1);
mice = unique(out.Mouse);
for i = 1:numel(mice)
	idx = find(out.Mouse == mice(i));
	perf = double(out.Performance(idx));
	i100 = find(perf >= 1 - 1e-12, 1, 'first');
	if isempty(i100)
		use = idx;
	else
		use = idx(1:i100 - 1);
	end
	if numel(use) >= 2
		keep(use) = true;
	end
end
out = out(keep, {'Mouse','DateTime'});
end

function iDrawTHSchematic(ax, colors)
hold(ax, 'on');
axis(ax, 'off');
xlim(ax, [0, 10]);
ylim(ax, [0, 10]);
patch(ax, [2 8 8 2], [1 1 3.4 3.4], [0.85 0.85 0.85], 'EdgeColor', [0.4 0.4 0.4]);
text(ax, 5, 2.2, 'Thalamus', 'FontSize', 6, 'HorizontalAlignment', 'center');
patch(ax, [2 8 8 2], [6.4 6.4 8.6 8.6], [0.9 0.95 1.0], 'EdgeColor', [0.3 0.4 0.6]);
text(ax, 5, 7.5, 'MOp', 'FontSize', 6, 'HorizontalAlignment', 'center');
plot(ax, [5 5], [3.4 6.4], '-', 'Color', colors(1, :), 'LineWidth', 1.2);
text(ax, 5.3, 4.9, 'Thalamus \rightarrow MOp', 'FontSize', 6, 'Color', colors(1, :));
plot(ax, [5 5], [6.4 6.4], '.', 'Color', 'none');
text(ax, 5, 0.3, 'CNO during light-water training', 'FontSize', 6, 'HorizontalAlignment', 'center');
end

function iPlotModelCurves(ax, D, colors)
hold(ax, 'on');
names = fieldnames(D.Performance);
plotted = 0;
for k = 1:numel(names)
	p = D.Performance.(names{k});
	if isnumeric(p) && size(p, 1) >= 2
		m = mean(p, 1, 'omitnan');
		s = std(p, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(p), 1));
		c = colors(min(k, size(colors, 1)), :);
		errorbar(ax, 1:numel(m), m, s, '-', 'Color', c, 'LineWidth', 1);
		plotted = plotted + 1;
	end
end
xlabel(ax, 'Block');
ylabel(ax, 'Hit rate');
ylim(ax, [0, 1.05]);
title(ax, 'Model', 'FontWeight', 'normal', 'FontSize', 8);
if plotted == 0
	axis(ax, 'off');
end
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







