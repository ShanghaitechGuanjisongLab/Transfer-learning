% Sup4C_cFos_MetricBars.m —— Sup Fig 4C/4D：cFos 组 first block 与 sigmoid slope（主图柱图样式）
%
% 样式与主图一致（同 英文图/Fig4G_THInhibit_MetricBars.m、Fig2H 指标柱图）：
%   两柱、无散点、无边框、单向误差棒（手绘，按物理 mm 定宽）、PLine 星号。
%   两张图分开导出（各 22 × 40 mm，Scale 2 → 排版 11 × 20 mm）。
%
% 数据与口径沿用 英文图/Fig2H_cFos_First7CurveAndMetricBars.m：
%   DS = cFos合集.v3.mat；Control = 未标记鼠，MOp = cFos 标记鼠；
%   LightWater block → session；首 block = PerMouseSessionSummary.FirstPerf；
%   slope = 逐 trial 惩罚 sigmoid（FixLowerZero）。
%
% 输出：
%   English_Sup4C_cFos_FirstBlock.svg
%   English_Sup4D_cFos_SigmoidSlope.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

matPath = "\\Data-Server-2\个人数据\张天夫\202611\cFos合集.v3.mat";
DS = UniExp.DataSet(matPath);

grpOrder = ["Control", "MOp"];
grpLabel = ["Ctrl", "cFos"];
barColor = [140 140 140; TransferLearning.ColorcFos] / 255;

%% 1) 分组 + 行为 session
S = DS.Mice;
if ~ismember('Mouse', S.Properties.VariableNames)
	S.Mouse = string(S.Properties.RowNames);
end
S.Mouse = string(S.Mouse);
S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";
S = S(ismember(S.Group, ["Control", "MOp"]), :);
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);

B = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false);
B.Mouse = string(B.Mouse);
B.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(B.DateTime);
J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
Sess = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);

%% 2) 逐鼠指标
PerMouse = TransferLearning.Metrics.PerMouseSessionSummary(Sess);
SlopeT   = iTrialLevelSlope(DS, Sess);

vFirst = cell(1, 2);  vSlope = cell(1, 2);
for g = 1:2
	vFirst{g} = double(PerMouse.FirstPerf(PerMouse.Group == grpOrder(g)));
	vFirst{g} = vFirst{g}(isfinite(vFirst{g}));
	vSlope{g} = double(SlopeT.Slope(SlopeT.Group == grpOrder(g)));
	vSlope{g} = vSlope{g}(isfinite(vSlope{g}));
end
pFirst = iRanksum(vFirst{1}, vFirst{2});
pSlope = iRanksum(vSlope{1}, vSlope{2});
fprintf('\n=== cFos 抑制 vs Control ===\n');
fprintf('First block  : Ctrl %.3f±%.3f (n=%d) | cFos %.3f±%.3f (n=%d) | p=%.4g\n', ...
	mean(vFirst{1}), iSEM(vFirst{1}), numel(vFirst{1}), mean(vFirst{2}), iSEM(vFirst{2}), numel(vFirst{2}), pFirst);
fprintf('Sigmoid slope: Ctrl %.3f±%.3f (n=%d) | cFos %.3f±%.3f (n=%d) | p=%.4g\n', ...
	mean(vSlope{1}), iSEM(vSlope{1}), numel(vSlope{1}), mean(vSlope{2}), iSEM(vSlope{2}), numel(vSlope{2}), pSlope);

%% 3) 两张指标柱图（主图样式）
iMetricBar(vFirst, barColor, grpLabel, 'First block hit rate', pFirst, ...
	'English_Sup4C_cFos_FirstBlock.svg');
iMetricBar(vSlope, barColor, grpLabel, 'Sigmoid slope', pSlope, ...
	'English_Sup4D_cFos_SigmoidSlope.svg');

%% ================= 局部函数 =================
function iMetricBar(vals, barColor, grpLabels, ylab, pVal, outName)
% 22×35 mm、Scale 2 → 排版 11×17.5 mm？不，按排版 22×35 mm：这里给 2.2×3.5 cm × Scale 2
% 与 Sup4A（TH recall，24×34 mm）高度一致；柱宽 3 mm，无散点、单向误差棒
barScale = 2;  barWcm = 2.2;  barHcm = 3.5;
fb = figure('Color', 'w', 'Name', outName);
fb.Units = 'centimeters';
fb.Position(3:4) = [barWcm barHcm] * barScale;
axb = axes(fb, 'Position', [0.44 0.13 0.52 0.82]);
hold(axb, 'on');

y = [mean(vals{1}), mean(vals{2})];
e = [iSEM(vals{1}), iSEM(vals{2})];
h = bar(axb, 1:2, y, 0.5, 'FaceColor', 'flat');
h.CData = barColor;
h.EdgeColor = 'none';
h.LineWidth = 0.5;
setappdata(axb, 'BarPairData', struct('y', y, 'e', e, 'cols', barColor));

axb.XTick = 1:2;
axb.XTickLabel = cellstr(grpLabels);
axb.XTickLabelRotation = 0;
axb.FontSize = 6;
axb.LineWidth = 0.5;
xlim(axb, [0.5 2.5]);
ylabel(axb, ylab);
yTop = max([y + e, eps]) * 1.45;
axb.YLim = [0, yTop];

iDrawErrorBars(axb, y, e, barColor, 0.16);
EB = errorbar(axb, 1:2, y, [0 0], e, 'LineStyle', 'none', 'Color', 'none', 'CapSize', 0.01);
D = table(repmat(EB, 1, 1), repmat(EB, 1, 1), 1, 2, ...
	string(TransferLearning.Style.iFormatPStars(pVal)), ...
	'VariableNames', ["ObjectA", "ObjectB", "IndexA", "IndexB", "Text"]);
MATLAB.Graphics.PLine(D);
tx = findall(axb, 'Type', 'text');
if ~isempty(tx), set(tx, 'VerticalAlignment', 'bottom'); end
box(axb, 'off');

iExactPaper(fb, barWcm * barScale, barHcm * barScale);
TransferLearning.ApplyStandardExportStyle(fb, barScale);
axb.YLim = [0, yTop];   % 标准格式会重置范围，需在其后重新固定
axb.XTick = 1:2;
axb.XTickLabel = cellstr(grpLabels);
ylabel(axb, ylab);
iFixBarWidths(fb, barWcm * 10, 1 * barScale);
svgPath = TransferLearning.StandardFigureSvgPath(outName);
print(fb, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);
end

function iFixBarWidths(f, figWmm, lw)
iAxesLeft = 0.44;  iAxesWidth = 0.52;
drawnow;
fpx = getpixelposition(f);
xSpan = 2;  barWmm = 3.0;  capHalfMm = 0.95;
for ax = findall(f, 'Type', 'axes').'
	p = ax.Position;
	ax.Position = [iAxesLeft, p(2), iAxesWidth, p(4)];
end
drawnow;
for ax = findall(f, 'Type', 'axes').'
	apx = getpixelposition(ax);
	axesWmm = apx(3) / fpx(3) * figWmm;
	set(findall(ax, 'Type', 'bar'), 'BarWidth', barWmm * xSpan / axesWmm);
	delete(findall(ax, 'Type', 'line', '-regexp', 'Tag', '^barWhisker|^barCap'));
	Dl = getappdata(ax, 'BarPairData');
	iDrawErrorBars(ax, Dl.y, Dl.e, Dl.cols, capHalfMm * xSpan / axesWmm, lw);
end
drawnow;
end

function iDrawErrorBars(ax, y, e, cols, capHalf, lw)
if nargin < 6, lw = 1; end
for k = 1:2
	yTopBar = y(k) + e(k);
	plot(ax, [k k k], [y(k) yTopBar yTopBar], '-', 'Color', cols(k, :), ...
		'LineWidth', lw, 'Tag', 'barWhisker');
	plot(ax, [k - capHalf, k, k + capHalf], [yTopBar yTopBar yTopBar], '-', ...
		'Color', cols(k, :), 'LineWidth', lw, 'Tag', 'barCap');
end
end

function iExactPaper(f, wCm, hCm)
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end

function p = iRanksum(a, b)
[p, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function s = iSEM(x)
x = double(x(:)); x = x(isfinite(x));
if isempty(x), s = NaN; else, s = std(x) / sqrt(numel(x)); end
end

function T = iTrialLevelSlope(DS, Sess)
T = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), false(0,1), ...
	'VariableNames', {'Group','Mouse','NTrials','Slope','AtSlopeBoundary'});
mice = unique(string(Sess.Mouse), 'stable');
for m = mice.'
	Sm = Sess(string(Sess.Mouse) == m, :);
	dt = datetime(Sm.DateTime);
	if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
	blk = double(Sm.Session);
	Tq = DS.TableQuery(["Mouse","DateTime","Stimulus","Behavior"], ...
		Mouse = m, Stimulus = "LightWater");
	if isempty(Tq), continue; end
	tDT = datetime(Tq.DateTime);
	if ~isempty(tDT.TimeZone), tDT.TimeZone = ''; end
	y = double(Tq.Behavior);
	[~, loc] = ismember(tDT, dt);
	ok = isfinite(y) & loc > 0;
	if nnz(ok) < 2 || numel(unique(blk(loc(ok)))) < 2, continue; end
	fit = TransferLearning.FitPenalizedSigmoid(blk(loc(ok)), y(ok), FixLowerZero = true);
	T = [T; table(string(Sm.Group(1)), m, nnz(ok), fit.Slope, fit.AtSlopeBoundary, ...
		'VariableNames', {'Group','Mouse','NTrials','Slope','AtSlopeBoundary'})]; %#ok<AGROW>
end
end
