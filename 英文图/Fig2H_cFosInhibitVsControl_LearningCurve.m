% English Fig2H: cFos activity-dependent inhibition vs Control
%
% v6 Panel K: cFos-MOp 精准抑制（学习曲线 + 首 block 命中率柱图）
% Shared behavior-session helpers: TransferLearning.BehaviorSessions
% 2026-11-15：改用最新配色（Catppuccin）——Control = 中性灰 #8C8C8C，cFos = ColorcFos #B4BEFE
% Outputs (SVG):
%   - English_Fig2H_cFos_LearningCurve.svg        （90×80 mm，排版 45×40 mm、6 pt）
%   - English_Fig2H_cFos_FirstSessionHitRate.svg  （44×80 mm，排版 22×40 mm、6 pt）
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.


% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- 1) Load cFos database
matPath = "\\Data-Server-2\个人数据\张天夫\202611\cFos合集.v3.mat";
DS = UniExp.DataSet(matPath);

% --- 2) Build group table (Mouse -> Group)
S = DS.Mice;
if isempty(S)
		error('English_Fig2H:EmptyMiceTable', 'DS.Mice is empty.');
end

if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
			error('English_Fig2H:MissingMouse', 'DS.Mice has no Mouse column or RowNames.');
	end
end
S.Mouse = string(S.Mouse);

needVars = ["ExpressedBrain","MarkTimes"];
for k = 1:numel(needVars)
	if ~ismember(needVars(k), string(S.Properties.VariableNames))
		error('English_Fig2H:MissingMiceVar', 'DS.Mice lacks required var: %s', needVars(k));
	end
end

S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";

% Remove weird labels with >1 spaces (match reference behavior)
try
	bad = arrayfun(@(g) nnz(char(g) == ' ') > 1, S.Group);
	S = S(~bad, :);
catch
end

% Keep only MOp vs Control
S = S(ismember(S.Group, ["Control","MOp"]), :);
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);
if isempty(S)
	error('English_Fig2H:EmptyGroups', 'No mice left after filtering to Control/MOp.');
end

% --- 3) Query LightWater behavior blocks
B = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS, false);
if isempty(B)
	error('English_Fig2H:EmptyBehavior', 'No LightWater behavior rows found.');
end
B.Mouse = string(B.Mouse);
B.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(B.DateTime);

% Join group labels
J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);

% --- 4) Sessionize and add session index
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
Sess = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);
nControlMice = numel(unique(string(Sess.Mouse(Sess.Group == "Control"))));
nInhibitedMice = numel(unique(string(Sess.Mouse(Sess.Group == "MOp"))));

% --- 5) Learning curve summary (UniExp.LearningSummarize)
sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);

PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

grpOrder = ["Control","MOp"]; % data group keys
grpLabels = ["Control","cFos"]; % figure labels

SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end

meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells  = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve,  'UniformOutput', false);

% n per group is intentionally NOT shown in legend (match request)

%% 
% --- 6) Plot learning curve (like English Fig1B)
f = figure('Color','w', 'Name', 'English Fig2H cFos Learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8]; % 90mm x 80mm (match English Fig1B)
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax,'on');
title(ax, 'cFos-specific inhibition', 'FontSize', 12, 'FontWeight', 'normal');

%最新配色（Catppuccin）：Control 用中性灰，cFos 用专属 Lavender
%柱图用浅色（同 Fig1 柱图口径），曲线/阴影带用向黑混 35% 的压暗版（白底可读，同 Curve* 口径）
colorCtrl = [140, 140, 140] / 255;                        %#8C8C8C 中性灰：Control
colorCFos = TransferLearning.ColorcFos / 255;             %#B4BEFE Lavender：cFos（浅）
edgeColors = [colorCtrl; round(TransferLearning.ColorcFos * 0.65) / 255];   %曲线用色

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));

groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(Sess, 'Performance', 'Session', 'Group', 'Mouse');
sessions7 = Sess(Sess.Session <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Session', 'Group', 'Mouse');
max7Ctrl = max(meanCells{1}(1:min(7, end)), [], 'omitnan');
max7CFos = max(meanCells{2}(1:min(7, end)), [], 'omitnan');
yTop7 = max(max7Ctrl, max7CFos);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
starStr = TransferLearning.Style.iFormatPStars(groupP7);
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

fprintf('Fig334C mice: Control n = %d, cFos n = %d\n', nControlMice, nInhibitedMice);
fprintf('Two-way ANOVA Group P (all blocks) = %.4g\n', groupP);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);

labels = {char(grpLabels(1)), char(grpLabels(2))};
try
	if numel(Patches) >= 2
		lg = legend(ax, Patches(1:2), labels, 'Location', 'southeast');
	else
		lg = legend(ax, labels, 'Location', 'southeast');
	end
	lg.FontSize = 12;
	lg.Box = 'off';
%emoji 无法在矢量 SVG 中保留，改为文字
	lg.Title.String = 'Light water';
	lg.Title.FontSize = 12;
catch
end

ax.FontSize = 12;
xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
box(ax, 'off');
grid(ax, 'off');

% Export learning curve
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgLC = 'English_Fig2H_cFos_LearningCurve.svg';
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
	svgLC = TransferLearning.ExportStandardFigure(f, 2, svgLC);
	fprintf('Wrote: %s\n', svgLC);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%%
% 2026-11-15：恢复首 block 命中率柱图，并统一到最新配色（Control = 中性灰，cFos = ColorcFos）。
% 用户 2026-09-17 曾因「首 block 差异不显著」删除该柱，现按要求重新输出。
perMouse = TransferLearning.BehaviorSessions.iPerMouseTable(Sess);
perMouse = TransferLearning.BehaviorSessions.iAddFirstTransferPerf(perMouse, Sess);
xCtrl = double(perMouse.TransferFirstPerf(perMouse.Group == "Control"));
xCFos = double(perMouse.TransferFirstPerf(perMouse.Group == "MOp"));
if ~any(isfinite(xCtrl)) || ~any(isfinite(xCFos))
	%Phase/Transfer 缺失时退回首会话
	xCtrl = NaN(height(perMouse), 1);
	xCFos = NaN(height(perMouse), 1);
	for i = 1:height(perMouse)
		S1 = sortrows(Sess(Sess.Mouse == perMouse.Mouse(i), :), 'Session');
		p1 = double(S1.Performance(find(S1.Session == 1, 1, 'first')));
		if perMouse.Group(i) == "Control"
			xCtrl(i) = p1;
		else
			xCFos(i) = p1;
		end
	end
end
xCtrl = xCtrl(isfinite(xCtrl));
xCFos = xCFos(isfinite(xCFos));
[pFS, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(xCtrl, xCFos);
fprintf('首 block 命中率：Control %.3f±%.3f (n=%d) | cFos %.3f±%.3f (n=%d) | ranksum p=%.4g\n', ...
	mean(xCtrl), iSEM(xCtrl), numel(xCtrl), mean(xCFos), iSEM(xCFos), numel(xCFos), pFS);

%排版 22×40 mm、6 pt → 导出 44×80 mm、12 pt（与 Fig1 柱图同一高度口径）
barScale = 2;
barWcm = 2.2;
barHcm = 4.0;
fb = figure('Color', 'w', 'Name', 'English Fig2H cFos first block hit rate');
fb.Units = 'centimeters';
fb.Position(3:4) = [barWcm barHcm] * barScale;
axb = axes(fb, 'Position', [0.44 0.13 0.52 0.82]);
iBarPair(axb, xCtrl, xCFos, [colorCtrl; colorCFos], ["Ctrl", "cFos"], pFS, 'Hit rate');
iExactPaper(fb, barWcm * barScale, barHcm * barScale);
TransferLearning.ApplyStandardExportStyle(fb, barScale);
iFixBarWidths(fb, barWcm * 10, 1 * barScale);
svgBar = TransferLearning.StandardFigureSvgPath('English_Fig2H_cFos_FirstSessionHitRate.svg');
print(fb, svgBar, '-dsvg');
fprintf('Wrote: %s\n', svgBar);

assignin('base', 'English_Fig2H_Sessions', Sess);
assignin('base', 'English_Fig2H_LearningSummarizeP', PValueLS);
assignin('base', 'English_Fig2H_FirstBlockP', pFS);

%% ===== 局部函数 =====
function iBarPair(ax, va, vb, cols, grpLabels, pVal, ylab)
hold(ax, 'on');
y = [mean(va), mean(vb)];
e = [iSEM(va), iSEM(vb)];
h = bar(ax, 1:2, y, 0.5, 'FaceColor', 'flat');   %宽度先给占位值，最后由 iFixBarWidths 统一校正
h.CData = cols;
h.EdgeColor = 'none';
h.LineWidth = 0.5;
setappdata(ax, 'BarPairData', struct('y', y, 'e', e, 'cols', cols));
ax.XTick = 1:2;
ax.XTickLabel = cellstr(grpLabels);
ax.XTickLabelRotation = 0;
ax.FontSize = 6;
ax.LineWidth = 0.5;
xlim(ax, [0.5 2.5]);
ylabel(ax, ylab);
yTop = min(1.05, max([y + e, 0.30]) * 1.35);
ax.YLim = [0, yTop];
%DONE 误差棒先按占位宽度画，打印前由 iFixBarWidths 重绘
iDrawErrorBars(ax, y, e, cols, 0.16);
%用一个不可见的两点 errorbar 作为定位对象，PLine 按误差条顶端放线
EB = errorbar(ax, 1:2, y, [0 0], e, 'LineStyle', 'none', 'Color', 'none', 'CapSize', 0.01);
D = table(repmat(EB, 1, 1), repmat(EB, 1, 1), 1, 2, ...
	string(TransferLearning.Style.iFormatPStars(pVal)), ...
	'VariableNames', ["ObjectA", "ObjectB", "IndexA", "IndexB", "Text"]);
MATLAB.Graphics.PLine(D);
tx = findall(ax, 'Type', 'text');
if ~isempty(tx)
	set(tx, 'VerticalAlignment', 'bottom');
end
%PLine 会按需抬高 YLim，刻度最后再定
ax.YTick = 0:0.2:floor(ax.YLim(2) / 0.2) * 0.2;
box(ax, 'off');
end

function iFixBarWidths(f, figWmm, lw)
%柱宽/横帽按【物理 mm】固定，而不是数据单位（同 Fig1 柱图口径）
iAxesLeft = 0.44;
iAxesWidth = 0.52;
drawnow;
fpx = getpixelposition(f);
xSpan = 2;
barWmm = 3.0;
capHalfMm = 0.95;
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
	D = getappdata(ax, 'BarPairData');
	iDrawErrorBars(ax, D.y, D.e, D.cols, capHalfMm * xSpan / axesWmm, lw);
end
drawnow;
end

function iDrawErrorBars(ax, y, e, cols, capHalf, lw)
%单向误差棒（只向上）。不用 errorbar：下误差给 0 时会在柱顶多画一条横帽，
%且 CapSize 以点为单位、不随字号/画布缩放。
if nargin < 6
	lw = 1;
end
for k = 1:2
	yTopBar = y(k) + e(k);
	plot(ax, [k k k], [y(k) yTopBar yTopBar], '-', 'Color', cols(k, :), ...
		'LineWidth', lw, 'Tag', 'barWhisker');
	plot(ax, [k - capHalf, k, k + capHalf], [yTopBar yTopBar yTopBar], '-', ...
		'Color', cols(k, :), 'LineWidth', lw, 'Tag', 'barCap');
end
end

function iExactPaper(f, wCm, hCm)
%固定画布尺寸：PaperPositionMode='auto' 会在小图上额外加边距
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end

function s = iSEM(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end


