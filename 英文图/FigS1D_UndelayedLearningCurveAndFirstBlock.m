%[text] `图3.1b：学习曲线（以会话序号为横轴，均值±SEM；两 cohort 非配对）。`
%
% LightWater learning curve: Naive vs Transfer
% - Naive 组：LightAudioBaseline(成像行为) + LAInterspersed(穿插，成像行为) + LAPureBehavior(纯行为)
% - Transfer 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
%
% 口径：
% - 每只鼠内按 DateTime 排序，将 LightWater 的每个 DateTime 视为一个“会话”；
%   若同一 DateTime 有多个 block，则对该会话内 block 的 Performance 取均值。
% - 之后按每鼠会话序号对齐，计算组均值±SEM。
% - 作图采用中文图31B 样式：errorbar 均值±SEM + 组水平 sigmoid 拟合曲线 +
%   横跨 block 1–7 的 LME 组效应 p 线（用户 2026-09-13 指定）。
% - 显示只取前 10 个 block（用户 2026-10-04 指定）。
%
% 执行方式（硬性要求，不要忘）：
% - 本文件必须保持为脚本（严禁改写成 function）。
% - 不要使用 run。
% - 在 MATLAB Editor 里打开后直接 Run/F5 执行。


% --- 0) Ensure project loaded (for UniExp)
if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

% --- 1) Load datasets
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（LightWater 是 Naive）
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（LightWater 是 Transfer）
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（LightWater 是 Naive）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（LightWater 是 Transfer）
LAI  = TransferLearning.LAInterspersed();       % 交替任务：含 Naive LightWater（需排除混入 AudioWater 的鼠）

% --- 2) Query and blockize (one row per mouse per block)
% 注意：在这些数据库里 Phase 往往表示训练阶段：
%   - Naive 组的后续 LightWater 会话通常标为 Learned
%   - Transfer 组的后续 LightWater 会话通常标为 Final
% 若只筛 Phase="Naive"/"Transfer" 会导致每鼠只剩首会话，曲线退化成 1 个点。
% 重要：部分数据库会在 Naive→Learned / Transfer→Final 之间存在未标注 Phase 的 LightWater 会话。
% 为了与“学习曲线”一致，这里以 Phase 作为锚点，纳入两锚点之间所有 LightWater 会话（无论 Phase 是否缺失/其他值）。
naiveAnchors = ["Naive","Learned"];      % Naive LightWater 轨迹锚点
tranAnchors  = ["Transfer","Final"];     % Transfer LightWater 轨迹锚点

naiveA = iLightWaterBlocksByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterBlocksByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterBlocksByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2)); %[output:2a2e2127]

tranA  = iLightWaterBlocksByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iLightWaterBlocksByMouse(ALPB, "ALPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

% 不同数据库之间理论上不应有重复鼠名；若发生则直接报错
iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");

allBlocks = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allBlocks);
if isempty(allBlocks)
	warning('FigS1D:EmptyData', '%s', 'No LightWater blocks found.');
	SummaryCurve = table();
	assignin('base', 'FigS1D_LearningCurve_Raw', allBlocks);
	assignin('base', 'FigS1D_LearningCurve_Summary', SummaryCurve);
	return;
end

allBlocks = sortrows(allBlocks, ["Group","Mouse","DateTime"]);
allBlocks = iAddBlockIndex(allBlocks);

% --- 3) Build curves via UniExp.LearningSummarize (required)
blockForSummary = allBlocks(:, ["Mouse","DateTime","Performance","Group"]);
blockForSummary.Group = string(blockForSummary.Group);
blockForSummary = sortrows(blockForSummary, ["Group","Mouse","DateTime"]);

[~, SummaryL] = evalc('UniExp.LearningSummarize(blockForSummary)');

[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);

% --- 3a) 显示只取前 10 个 block ---
nBlocksShow = 10;
nBlocksPlot = min(nBlocksShow, height(meanMat));
meanMat = meanMat(1:nBlocksPlot, :);
semMat  = semMat(1:nBlocksPlot, :);
x       = (1:nBlocksPlot).';
nMat = iComputeNByBlock(allBlocks, x, ["Naive","Transfer"]);

% --- 3b) Group-level sigmoid fits (lower fixed at 0, same spec as Fig1B) ---
displayNaive = iFilterToDisplayedMice(allBlocks(string(allBlocks.Group) == "Naive", :));
displayTransfer = iFilterToDisplayedMice(allBlocks(string(allBlocks.Group) == "Transfer", :));
fitNaive = iFitSigmoidCurve(displayNaive, "Naive");
fitTransfer = iFitSigmoidCurve(displayTransfer, "Transfer");

% --- 3c) LME group effect over blocks 1-7 (for the p-line, as in Chinese Fig31B) ---
blocks7 = allBlocks(allBlocks.Block <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(blocks7, 'Performance', 'Block', 'Group', 'Mouse');
%%

% --- 4) Plot（中文图31B 样式：errorbar 均值±SEM + 组水平 sigmoid + 1–7 block LME p 线）
f = figure('Color','w', 'Name', 'FigS1D Undelayed learning curve (LightWater)'); %[output:5c266b7f]
f.Units = 'centimeters';
f.Position(3:4) = [12, 8]; %[output:5c266b7f]
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';
ax = axes(f); %[output:5c266b7f]
ax.FontSize = 12; %[output:5c266b7f]
ax.LineWidth = 2; %[output:5c266b7f]
ax.Color = 'none'; %[output:5c266b7f]
hold(ax,'on'); %[output:5c266b7f]
axes(ax); %[output:5c266b7f]

% Group colors: Naive vs Transfer (current named palette)
colorNaive = TransferLearning.NaiveColor;
colorTransfer = TransferLearning.TransferColor;

xSummary = x;
xFit = linspace(1, nBlocksPlot, 200).';
hNaiveMean = errorbar(ax, xSummary, meanMat(:, 1), semMat(:, 1), 'o', ... %[output:5c266b7f]
	'Color', colorNaive, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorNaive, ... %[output:5c266b7f]
	'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none'); %[output:5c266b7f]
hTransferMean = errorbar(ax, xSummary, meanMat(:, 2), semMat(:, 2), 'o', ... %[output:5c266b7f]
	'Color', colorTransfer, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorTransfer, ... %[output:5c266b7f]
	'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none'); %[output:5c266b7f]
hNaiveFit = plot(ax, xFit, iSigmoidFromParams(fitNaive.ParamRaw, xFit), '-', ... %[output:5c266b7f]
	'Color', colorNaive, 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine'); %[output:5c266b7f]
hTransferFit = plot(ax, xFit, iSigmoidFromParams(fitTransfer.ParamRaw, xFit), '-', ... %[output:5c266b7f]
	'Color', colorTransfer, 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine'); %[output:5c266b7f]

% --- 4b) LME p-line spanning blocks 1-7（同中文图31B；曲线本身画全部 block） ---
max7 = min(7, nBlocksPlot);
max7Naive = max(meanMat(1:max7, 1), [], 'omitnan');
max7Transfer = max(meanMat(1:max7, 2), [], 'omitnan');
yTop7 = max(max7Naive, max7Transfer);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off'); %[output:5c266b7f]
% 与 Fig1B 一致：p<0.001 用四星，其余用 iFormatPText
if groupP7 < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP7); end
text(ax, 4, textY, starStr, ... %[output:5c266b7f]
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12, 'HandleVisibility', 'off'); %[output:5c266b7f]
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6)); %[output:5c266b7f]

% 扩展 y 上限避免 P 值标注遮挡
yl_ = ylim(ax);
ylim(ax, [yl_(1), yl_(2) + 0.12 * (yl_(2) - yl_(1))]); %[output:5c266b7f]

% 图例与 Fig1B 一致：内置 southeast、Transfer 在前（用户 2026-09-16 口径）
lg = legend(ax, [hTransferFit, hNaiveFit], {'Transfer', 'Naive'}, ...
	'Location', 'southeast'); %[output:5c266b7f]
lg.Box = 'off'; %[output:5c266b7f]
lg.FontSize = 10; %[output:5c266b7f]
lg.AutoUpdate = 'off'; %[output:5c266b7f]

xlabel(ax, 'Block', 'FontSize', 12); %[output:5c266b7f]
ylabel(ax, 'Hit rate', 'FontSize', 12); %[output:5c266b7f]
xlim(ax, [0.5, nBlocksPlot + 0.5]); %[output:5c266b7f]
box(ax, 'off'); %[output:5c266b7f]
grid(ax, 'off'); %[output:5c266b7f]
title(ax, ''); %[output:5c266b7f]

% --- 5) Export (SVG only)
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = 'English_FigS1D_UndelayedLearningCurve.svg';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar) %[output:5c266b7f]
	ax.Toolbar.Visible = 'off'; %[output:5c266b7f]
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath); %[output:5c266b7f]
fprintf('Wrote: %s\n', svgPath); %[output:85d28524]
%%
fprintf('\n=== FigS1D sigmoid (group level) ===\n'); %[output:6ab8c284]
fprintf('Naive  : slope=%.4f midpoint=%.4f R^2=%.4f (n=%d mice)\n', ... %[output:group:28ba9223] %[output:41184eed]
	fitNaive.Slope, fitNaive.Midpoint, fitNaive.RSquared, numel(unique(string(displayNaive.Mouse)))); %[output:group:28ba9223] %[output:41184eed]
fprintf('Transfer: slope=%.4f midpoint=%.4f R^2=%.4f (n=%d mice)\n', ... %[output:group:7d768d28] %[output:13792177]
	fitTransfer.Slope, fitTransfer.Midpoint, fitTransfer.RSquared, numel(unique(string(displayTransfer.Mouse)))); %[output:group:7d768d28] %[output:13792177]
fprintf('LME Group P (blocks 1-7) = %.6g\n', groupP7); %[output:1a19636a]
%%

SummaryCurve = table;
SummaryCurve.Block = x(:);
SummaryCurve.NaiveMean = meanMat(:,1);
SummaryCurve.TransferMean = meanMat(:,2);
SummaryCurve.NaiveSem = semMat(:,1);
SummaryCurve.TransferSem = semMat(:,2);
SummaryCurve.NaiveN = nMat(:,1);
SummaryCurve.TransferN = nMat(:,2);

assignin('base', 'FigS1D_LearningCurve_Raw', allBlocks);
assignin('base', 'FigS1D_LearningCurve_Summary', SummaryCurve);

%% --- 6) First-block performance bar comparison (computed from allBlocks)
firstSess = allBlocks(allBlocks.Block == 1, :);
naiveFirst = double(firstSess.Performance(string(firstSess.Group) == "Naive"));
tranFirst  = double(firstSess.Performance(string(firstSess.Group) == "Transfer"));
naiveFirst = naiveFirst(isfinite(naiveFirst));
tranFirst  = tranFirst(isfinite(tranFirst));
%%

if ~isempty(naiveFirst) && ~isempty(tranFirst) %[output:group:9039a271]
	naiveA = naiveFirst;
	tranA  = tranFirst;

	DataCell = {tranA(:), naiveA(:)}; % {Transfer, Naive}，列向量（顺序与 Fig1B 一致）
	CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

	% --- Plot（与 Fig1B 首块柱状图同规格：4.5×4 cm，显示组名，P 线贴柱顶）
	f2 = figure('Color', 'w', 'Name', 'English FigS1D Undelayed first-block performance'); %[output:65991d64]
	f2.Units = 'centimeters';
	f2.Position(3:4) = [4.5, 4]; %[output:65991d64]
	f2.PaperUnits = 'centimeters';
	f2.PaperSize = [4.5, 4];
	f2.PaperPositionMode = 'auto';

	ax2 = axes(f2); %[output:65991d64]
	% IndividualErrorbars 旗帜：每根误差条独立对象，逐根与所属 bar 同色
	[~, optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05); %[output:65991d64]
	ax2.Color = 'none'; %[output:65991d64]
	ax2.XTick = [1, 2]; %[output:65991d64]
	ax2.XTickLabel = {'Transfer', 'Naive'}; %[output:65991d64]
	ax2.XTickLabelRotation = 45; %[output:65991d64]
	legend(ax2, 'off');

	% Bar styling：bar 与 errorbar 同色，bar 无边框（Transfer 在前）
	palette2 = [TransferLearning.TransferColor; TransferLearning.NaiveColor];
	colorTrans = palette2(1,:);
	colorNaive = palette2(2,:);
	if isscalar(Bars2)
		Bars2.FaceColor = 'flat'; %[output:65991d64]
		nBars = numel(Bars2.YData);
		reps = ceil(nBars/2);
		Bars2.CData = repmat([colorTrans; colorNaive], reps, 1); %[output:65991d64]
		Bars2.CData = Bars2.CData(1:nBars, :); %[output:65991d64]
	else
		Bars2(1).FaceColor = colorTrans;
		Bars2(2).FaceColor = colorNaive;
	end
	for kB = 1:numel(Bars2)
		Bars2(kB).BarWidth = 0.5; %[output:65991d64]
		Bars2(kB).EdgeColor = 'none';
		Bars2(kB).FaceAlpha = 1;
	end
	if istable(ErrorBars2) && ~isempty(ErrorBars2) && ismember('Object', ErrorBars2.Properties.VariableNames)
		barColors = [colorTrans; colorNaive];
		for kE = 1:height(ErrorBars2)
			eb = ErrorBars2.Object(kE);
			if isgraphics(eb) && kE <= size(barColors, 1)
				eb.Color = barColors(kE, :); %[output:65991d64]
			end
		end
	end
	ax2.XLim = [0.5, 2.5]; %[output:65991d64]

	% P 线/文本：与 Fig1B 同一处理（Tag + SetBarPValues）
	if isfield(optional2, 'MultiCompare') && ismember('PLine', optional2.MultiCompare.Properties.VariableNames)
		for pl = optional2.MultiCompare.PLine(:)'
			pl.LineWidth = 2;
			pl.Tag = 'PLine';
		end
	end
	if isfield(optional2, 'MultiCompare') && ismember('PText', optional2.MultiCompare.Properties.VariableNames)
		for pt = optional2.MultiCompare.PText(:)'
			pt.Tag = 'PText';
		end
	end
	TransferLearning.Style.SetBarPValues(optional2);

	ylabel(ax2, 'Hit rate', 'FontSize', 12); %[output:65991d64]
	title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal'); %[output:65991d64]
	box(ax2, 'off'); %[output:65991d64]
	grid(ax2, 'off'); %[output:65991d64]

	% P 线降到柱顶（mean+SEM）×1.10，YLim 固定为柱顶 ×1.5（与 Fig1B 一致）
	semTransFirst = std(tranA, 'omitnan') / sqrt(numel(tranA));
	semNaiveFirst = std(naiveA, 'omitnan') / sqrt(numel(naiveA));
	yTopBar = max(mean(tranA, 'omitnan') + semTransFirst, mean(naiveA, 'omitnan') + semNaiveFirst);
	if isfield(optional2, 'MultiCompare') && ismember('PLine', optional2.MultiCompare.Properties.VariableNames) ...
			&& ~isempty(optional2.MultiCompare.PLine)
		for pl = optional2.MultiCompare.PLine(:)'
			pl.YData(:) = yTopBar * 1.10;
		end
	end
	if isfield(optional2, 'MultiCompare') && ismember('PText', optional2.MultiCompare.Properties.VariableNames) ...
			&& ~isempty(optional2.MultiCompare.PText)
		for pt = optional2.MultiCompare.PText(:)'
			pt.Position(2) = yTopBar * 1.05;
		end
	end
	ax2.YLim = [0, yTopBar * 1.5]; %[output:65991d64]

	% Export SVG (transparent)
	svgPath2 = 'English_FigS1D_UndelayedFirstBlockBar.svg';
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar) %[output:65991d64]
		ax2.Toolbar.Visible = 'off'; %[output:65991d64]
	end
	svgPath2 = TransferLearning.ExportStandardFigureTransparent(f2, 2, svgPath2); %[output:65991d64]
	fprintf('Wrote: %s\n', svgPath2); %[output:1d92987d]
end %[output:group:9039a271]

%% --- local functions
function out = iLightWaterBlocksByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInBlock'});
		return;
	end

	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);

	T = iBlockizeByDateTime(T);
	T = iSelectBlocksBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);

	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInBlock'});
end

function out = iLightWaterBlocksByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	% 排除 Naive 阶段掺杂了 AudioWater 回合的鼠（整只鼠剔除）

	% 混入判定只针对 Naive 阶段（需求：排除 Naive 会话中掺杂 AudioWater 的鼠）
	if string(startPhase) == "Naive" || string(endPhase) == "Naive"
		badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
	else
		badMice = string.empty(0,1);
	end

	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInBlock'});
		return;
	end

	T.Mouse = string(T.Mouse);
	if ~isempty(badMice)
		keep = ~ismember(T.Mouse, badMice);
		T = T(keep, :);
		fprintf('FigS1D: LAInterspersed excluded %d mice with AudioWater mixed into Naive phase.\n', numel(badMice));
		fprintf('  Excluded mice: %s\n', char(strjoin(string(badMice), ', ')));
	end

	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iBlockizeByDateTime(T);
	T = iSelectBlocksBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInBlock'});
end

function dt = iNormalizeDateTime(dt)
	% Unify timezone to avoid vertcat errors across datasets.
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function T = iQueryLightWaterBehaviorAll(DS)
	% 必须使用 Stimulus=LightWater（不回退到 Design）。Phase 仅作为锚点，不作为过滤条件。
	% 先尝试 trial-level Behavior 列，不存在则回退到 Performance
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus="LightWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="LightWater");
	end

	if isempty(T)
		return;
	end

	if ~ismember('Stimulus', T.Properties.VariableNames)
		error('FigS1D:MissingStimulus', 'TableQuery result lacks Stimulus; cannot enforce Stimulus=LightWater for %s.', class(DS));
	end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
end

function S = iSelectBlocksBetweenPhases(S, startPhase, endPhase)
	% 在每只鼠内，找到第一次 startPhase 会话作为锚点，然后纳入直到第一次 endPhase（含）为止的所有会话。
	% endPhase 不存在时：纳入 startPhase 之后所有可用会话。
	startPhase = string(startPhase);
	endPhase = string(endPhase);
	if isempty(S)
		return;
	end

	S.Mouse = string(S.Mouse);
	S.Phase = string(S.Phase);
	S = sortrows(S, {'Mouse','DateTime'});

	mice = unique(S.Mouse);
	keepRows = false(height(S),1);
	for i = 1:numel(mice)
		m = mice(i);
		idx = find(S.Mouse == m);
		ph = S.Phase(idx);
		st = find(ph == startPhase, 1, 'first');
		if isempty(st)
			continue;
		end
		ed = find(ph == endPhase & (1:numel(ph))' >= st, 1, 'first');
		if isempty(ed)
			ed = numel(ph);
		end
		keepRows(idx(st:ed)) = true;
	end
	S = S(keepRows, :);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	% 在给定 Phase 内，只要出现过 AudioWater（Stimulus 或 Design），就判定该鼠混入并剔除
	badMice = string.empty(0,1);
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = unique(string(Ta.Mouse));
	end
end


function S = iBlockizeByDateTime(T)
	% Collapse within-block rows (trials/blocks) into one block.
	% 如果存在 Behavior（trial-level 0/1），优先用它来计算会话内 LightWater 表现。
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	% 保留 Phase（用于锚点定位）；若没有 Phase，则置为空字符串。
	if ~ismember('Phase', T.Properties.VariableNames)
		T.Phase = repmat(missing, height(T), 1);
	end

	if useBehavior
		T = T(:, {'Mouse','DateTime','Behavior','Phase'});
	else
		T = T(:, {'Mouse','DateTime','Performance','Phase'});
	end
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Mouse','DateTime'});
	% 重要：必须在 sortrows 之后再取 val，避免 val 与表行错位。
	if useBehavior
		val = double(T.Behavior);
	else
		val = double(T.Performance);
	end

	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
	nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
	phaseBlock = splitapply(@(x) iPickBlockPhase(x), string(T.Phase), G);

	S = table(mouseKeys, dtKeys, perf, nBlocks, phaseBlock, ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInBlock','Phase'});
end

function ph = iPickBlockPhase(phases)
	% phases: string array for blocks/trials within one block.
	phases = string(phases);
	phases = phases(~ismissing(phases) & phases ~= "");
	if isempty(phases)
		ph = "";
		return;
	end
	[u,~,ic] = unique(phases);
	counts = accumarray(ic, 1);
	[~,ix] = max(counts);
	ph = u(ix);
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	[G, mice] = findgroups(T.Mouse);
	nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
	dup = mice(nSrc > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup),1);
		for i = 1:numel(dup)
			m = dup(i);
			srcs = unique(T.Source(T.Mouse == m));
			msgLines(i) = m + ": " + strjoin(srcs, ",");
		end
		error('FigS1D:DuplicateMouseAcrossSources', ...
			'Group %s has duplicated mice across sources (should not happen).\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
	end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	[G, mice] = findgroups(T.Mouse);
	nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
	dup = mice(nG > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup),1);
		for i = 1:numel(dup)
			m = dup(i);
			gs = unique(T.Group(T.Mouse == m));
			msgLines(i) = m + ": " + strjoin(gs, ",");
		end
		error('FigS1D:MouseInMultipleGroups', 'Some mice appear in multiple groups (Naive/Transfer):\n%s', char(strjoin(msgLines, newline)));
	end
end

function T = iAddBlockIndex(T)
	% Add per-mouse block index based on DateTime ordering.
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	% splitapply 要求每组返回标量；这里返回 cell(1) 再拼接。
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Block = vertcat(sessCell{:});
end

function [meanMat, semMat, x, nMat] = iComputeMeanSemByBlock(T)
	% Compute mean±SEM per block index across mice, separately for Naive/Transfer.
	groups = ["Naive","Transfer"];
	T.Group = string(T.Group);
	T.Block = double(T.Block);

	maxN = 0;
	for g = 1:numel(groups)
		maxN = max(maxN, max(T.Block(T.Group == groups(g)), [], 'omitnan'));
	end
	if ~isfinite(maxN) || isempty(maxN)
		maxN = 0;
	end

	meanMat = nan(maxN, 2);
	semMat  = nan(maxN, 2);
	nMat    = zeros(maxN, 2);

	for g = 1:numel(groups)
		rowsG = (T.Group == groups(g));
		for s = 1:maxN
			xv = double(T.Performance(rowsG & T.Block == s));
			xv = xv(isfinite(xv));
			nMat(s,g) = numel(xv);
			if isempty(xv)
				continue;
			end
			meanMat(s,g) = mean(xv, 'omitnan');
			if numel(xv) <= 1
				semMat(s,g) = 0;
			else
				semMat(s,g) = std(xv, 'omitnan') / sqrt(numel(xv));
			end
		end
	end

	x = (1:maxN).';
	if isempty(semMat)
		semMat = zeros(size(meanMat));
	end
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, groupOrder)
	% UniExp.LearningSummarize 输出在不同版本里可能是 table/struct；这里做兼容解包。
	if nargin < 2 || isempty(groupOrder)
		groupOrder = ["Naive","Transfer"];
	end
	groupOrder = string(groupOrder);

	if ~istable(SummaryL)
		if isstruct(SummaryL)
			SummaryL = struct2table(SummaryL);
		else
			error('FigS1D:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
		end
	end

	if ~ismember('MeanCurve', SummaryL.Properties.VariableNames) || ~ismember('SemCurve', SummaryL.Properties.VariableNames)
		error('FigS1D:MissingLearningSummarizeFields', 'LearningSummarize output lacks MeanCurve/SemCurve.');
	end

	meanCurve = SummaryL.MeanCurve;
	semCurve = SummaryL.SemCurve;
	if iscell(meanCurve) && numel(meanCurve) == 1, meanCurve = meanCurve{1}; end
	if iscell(semCurve) && numel(semCurve) == 1, semCurve = semCurve{1}; end

	% 常见形式：SummaryL 为 table，行名=组名；MeanCurve/SemCurve 为 cell 列，每行一个向量
	if iscell(meanCurve)
		% 若 meanCurve 不是按行存储（例如 1xN），也先转为列向量便于处理
		meanCells = meanCurve(:);
		semCells = semCurve(:);
		if numel(semCells) ~= numel(meanCells)
			error('FigS1D:LearningSummarizeCellMismatch', 'MeanCurve/SemCurve cell sizes mismatch.');
		end

		if ~isempty(SummaryL.Properties.RowNames)
			rn = string(SummaryL.Properties.RowNames);
		else
			rn = strings(numel(meanCells),1);
		end

		idx = nan(1, numel(groupOrder));
		for k = 1:numel(groupOrder)
			if all(rn == "")
				% 无行名：假定输出顺序已与 groupOrder 对齐（或只有一组）
				if k <= numel(meanCells)
					idx(k) = k;
				end
			else
				ix = find(rn == groupOrder(k), 1, 'first');
				if ~isempty(ix)
					idx(k) = ix;
				end
			end
		end

		% pad 到最长曲线
		maxLen = 0;
		for k = 1:numel(groupOrder)
			if ~isfinite(idx(k))
				continue;
			end
			mv = meanCells{idx(k)};
			sv = semCells{idx(k)};
			if iscell(mv) && numel(mv) == 1, mv = mv{1}; end
			if iscell(sv) && numel(sv) == 1, sv = sv{1}; end
			maxLen = max(maxLen, numel(mv));
			maxLen = max(maxLen, numel(sv));
		end
		meanMat = nan(maxLen, numel(groupOrder));
		semMat  = nan(maxLen, numel(groupOrder));
		for k = 1:numel(groupOrder)
			if ~isfinite(idx(k))
				continue;
			end
			mv = meanCells{idx(k)};
			sv = semCells{idx(k)};
			if iscell(mv) && numel(mv) == 1, mv = mv{1}; end
			if iscell(sv) && numel(sv) == 1, sv = sv{1}; end
			mv = double(mv(:));
			sv = double(sv(:));
			meanMat(1:numel(mv), k) = mv;
			if isempty(sv)
				semMat(:, k) = 0;
			else
				semMat(1:numel(sv), k) = sv;
			end
		end
		x = (1:maxLen).';
		return;
	end

	% 若按组返回（RowNames=Group），则按 groupOrder 重排。
	if istable(SummaryL) && ~isempty(SummaryL.Properties.RowNames)
		rn = string(SummaryL.Properties.RowNames);
		idx = nan(1, numel(groupOrder));
		for k = 1:numel(groupOrder)
			ix = find(rn == groupOrder(k), 1, 'first');
			if isempty(ix)
				% 允许缺组：用 NaN 列补齐
				idx(k) = NaN;
			else
				idx(k) = ix;
			end
		end

		if isnumeric(meanCurve) && isnumeric(semCurve) && size(meanCurve,2) == numel(rn)
			% 形如 (block x group)
			M = nan(size(meanCurve,1), numel(groupOrder));
			S = nan(size(semCurve,1), numel(groupOrder));
			for k = 1:numel(groupOrder)
				if isfinite(idx(k))
					M(:,k) = meanCurve(:, idx(k));
					S(:,k) = semCurve(:, idx(k));
				end
			end
			meanMat = double(M);
			semMat = double(S);
		else
			% 若不是矩阵形式，直接尝试转 numeric
			meanMat = double(meanCurve);
			semMat = double(semCurve);
		end
	else
		meanMat = double(meanCurve);
		semMat = double(semCurve);
	end

	if isempty(semMat)
		semMat = zeros(size(meanMat));
	end
	if size(meanMat,2) == 1 && numel(groupOrder) == 2
		% 极端情况：只返回一列，按 Naive/Transfer 习惯补齐
		meanMat(:,2) = nan(size(meanMat,1),1);
		semMat(:,2) = nan(size(semMat,1),1);
	end

	x = (1:size(meanMat,1)).';
end

function nMat = iComputeNByBlock(T, x, groups)
	% 每组每个 Block 的样本量（以“该 block 有数据的鼠数”为准）
	groups = string(groups);
	x = double(x(:));
	maxN = numel(x);
	nMat = zeros(maxN, numel(groups));
	T.Group = string(T.Group);
	T.Block = double(T.Block);

	for g = 1:numel(groups)
		rowsG = (T.Group == groups(g));
		for s = 1:maxN
			rowsS = rowsG & (T.Block == s) & isfinite(double(T.Performance));
			if ~any(rowsS)
				nMat(s,g) = 0;
			else
				nMat(s,g) = numel(unique(string(T.Mouse(rowsS))));
			end
		end
	end
end

function out = iFitMixedEffectPValue(T)
	% Fit LME: Performance ~ Block*Group + (1+Block|Mouse)
	out = struct('PGroup', nan, 'PInteraction', nan);
	if isempty(T)
		return;
	end
	use = isfinite(double(T.Performance)) & isfinite(double(T.Block));
	if nnz(use) < 10
		return;
	end
	Tbl = table;
	Tbl.Performance = double(T.Performance(use));
	Tbl.Block = double(T.Block(use));
	Tbl.Group = categorical(string(T.Group(use)), ["Naive","Transfer"]);
	Tbl.Mouse = categorical(string(T.Mouse(use)));

	% 更稳健：避免随机斜率导致奇异/不收敛，从而 p=NaN
	lme = fitlme(Tbl, 'Performance ~ Block*Group + (1|Mouse)');
	A = anova(lme);
	% Terms might be named "Group" and "Block:Group"
	if istable(A) && ismember('Term', A.Properties.VariableNames)
		rowG = find(string(A.Term) == "Group", 1, 'first');
		rowI = find(string(A.Term) == "Block:Group", 1, 'first');
		if ~isempty(rowG) && ismember('pValue', A.Properties.VariableNames)
			out.PGroup = A.pValue(rowG);
		end
		if ~isempty(rowI) && ismember('pValue', A.Properties.VariableNames)
			out.PInteraction = A.pValue(rowI);
		end
	end
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
	% Convert padded matrices into per-line column vectors.
	if ~isnumeric(meanMat) || ~isnumeric(semMat)
		error('FigS1D:InvalidCurveType', 'meanMat/semMat must be numeric matrices.');
	end
	if ~isequal(size(meanMat), size(semMat))
		error('FigS1D:CurveSizeMismatch', 'meanMat and semMat must have the same size.');
	end

	nLines = size(meanMat, 2);
	yCells = cell(1, nLines);
	sCells = cell(1, nLines);
	xCells = cell(1, nLines);

	for j = 1:nLines
		y = meanMat(:, j);
		s = semMat(:, j);
		last = find(isfinite(y) & isfinite(s), 1, 'last');
		if isempty(last)
			yCells{j} = nan(0,1);
			sCells{j} = nan(0,1);
			xCells{j} = nan(0,1);
		else
			yCells{j} = y(1:last);
			sCells{j} = s(1:last);
			xCells{j} = (1:last).';
		end
	end
end

function T = iFilterToDisplayedMice(T)
	% 纳入条件（与 Fig1B 相同）：每鼠 ≥2 个 block 且 ≥2 个不同 Performance 值
	T.Mouse = string(T.Mouse);
	mice = unique(T.Mouse, 'stable');
	keep = false(height(T), 1);
	for i = 1:numel(mice)
		r = T.Mouse == mice(i);
		y = double(T.Performance(r));
		y = y(isfinite(y));
		if numel(y) >= 2 && numel(unique(y)) >= 2
			keep(r) = true;
		end
	end
	T = T(keep, :);
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Block(:)); yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs); xObs = xObs(use); yObs = yObs(use);
	if isempty(xObs), error('FigS1D:NoDataForGroup', 'No data for %s.', char(groupName)); end
	% lower 固定为 0（与 Fig1B 一致）；参数 p = [log(slope); midpoint]
	p0 = [log(0.8); max(median(xObs), 1)];
	obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	p = fminsearch(obj, p0, opt);
	yHat = iSigmoidFromParams(p, xObs);
	SSE = sum((yObs - yHat).^2, 'omitnan'); SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	rSquared = NaN; if SST > 0, rSquared = 1 - SSE / SST; end
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	fitOut = struct; fitOut.Group = string(groupName); fitOut.ParamRaw = p;
	fitOut.Lower = lower; fitOut.Upper = upper; fitOut.Slope = slope; fitOut.Midpoint = midpoint;
	fitOut.SSE = SSE; fitOut.RSquared = rSquared; fitOut.XObserved = xObs; fitOut.YObserved = yObs;
end

function y = iSigmoidFromParams(p, x)
	[~, ~, slope, midpoint] = iDecodeSigmoidParams(p);
	y = 1 ./ (1 + exp(-slope .* (x - midpoint)));
end

% 参数 p = [log(slope); midpoint]；下渐近线固定 0、上渐近线固定 1
function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
	lower = 0; upper = 1; slope = exp(p(1)); midpoint = p(2);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:2a2e2127]
%   data: {"dataType":"text","outputData":{"text":"FigS1D: LAInterspersed excluded 4 mice with AudioWater mixed into Naive phase.\n  Excluded mice: vtf0045, vtf0101, yqn0051, yqn0052\n","truncated":false}}
%---
%[output:5c266b7f]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAcYAAAEuCAYAAAAUdbLGAAAQAElEQVR4AeydC6xV13nnvwMkukOOE8jEEAyuG4ZRq7iYtJFVZiB2M7pUxCmlvSRVuUZy6qYEYiq1gtDYsVVX5DEFogaJDgSlqJYwd0YGFNdDYgk6EcS0MEzrALWVxx2wzcOGScfYvqWZBLhzfuvc73jffV73vPfZ5x\/5O2uv91q\/TfiznnvSqP4nAiIgAiIgAiJQIDDJ9D8REAEREAEREIECAQljAUUKHtQFERABERCBhglIGBtGqAJEQAREQATSREDCmKa3qb6kiYD6IgIi0CECEsYOgVe1IiACIiACySQgYUzme1GrREAE0kRAfekqAhLGrnpdaqwIiIAIiECrCUgYW01Y5YuACIiACHQVgSrC2FV9UWNFQAREQAREoGECEsaGEaoAERABERCBNBGQMKbpbVbpi6JFQAREQASqE5AwVmekFCIgAiIgAj1EQMLYQy9bXU0TAfVFBESgVQQkjK0iq3JFQAREQAS6koCEsStfmxotAiKQJgLqS7IISBiT9T7UGhEQAREQgQ4TkDB2+AWoehEQAREQgWQRaEwYk9UXtUYEREAEREAEGiYgYWwYoQoQAREQARFIEwEJY5reZmN9UW4REAEREIEcAQljDoL+EwEREAEREAEnkAphvHDhgm3bts1wvWNyRaCnCajzIiACdROQMNaNThlFQAREQATSSCAVwpjGF6M+iYAIiMAYATltJiBhbDNwVScCIiACIpBsAhLGZL8ftU4EREAERKDNBFoqjG3ui6oTAREQgdQQ2LBhgy1YsMDOnDlT1CfCiDt8+HBRXLkA0t5777125cqVckkUPkZAwjgGQo4IiIAIJI3AW2+9ZV\/5yldsZGSk4ab19\/fbkSNHbMaMGQ2XlfYCJIxpf8NN658KEgER6ASB48eP2549ezpRdc\/WKWHs2VevjouACCSdwMKFC23JkiU2NDRUdQrUp1fnzp1rbkyfeh959qlUpmkHBweLRqKEY55n586dhbIokzI8Ls2uhDHNb1d9E4EyBBTcPQQ+\/\/nPh8Zu3rw5uKV+EMVVq1bZV7\/6VTt79mywjRs32vr160uuUS5dutReeOEFO3fuXKE41h5PnjxpxBGIKO7YscOefvrpUB4u5RFOfJpNwpjmt6u+iYAIFAgMH7xpz33xRmLttX8cLbQ1+nDrrbfaypUr7cCBA1ZuxHbs2DG78847bWFuhOl5Fy1aFB4vX74c3OjPXXfdZdOmTTPyeTjl80wcIskode3atTZ\/\/nyCg4ufcOJDYEp\/JIwpfbHqlgiIwHgCrz0\/asMHk2vlhJFeMBpE9DZt2lRiStVszZo1tnfvXstms8aIjmnP5cuXG5t3yB83NuDcfffddvTo0TCdyuYengkj7vTp03b16lVzcfX8+EdHR62U2HqaNLgSxjS8RfVBBEQg1QQQvIcffjiIVakpVaZSOb6BIBK\/a9euMAV6yy23lOXClKlPpzKlyjNhngFRRVwp0w3\/G2+84UlS60oYU\/tq1TEREIEogcWPTrZP\/f2UxNqHPl35r2OmNJnKPHTokDGii\/btiSeeCFOphLPGyNGMaHypZ6ZMfTqVKVWeCfO0iCrripQXtVOnToVpVU+XRrfym2htj1W6CIiACIhADQSYUmUt8bHHHitMkzINeunSJbvnnnvCVKoXh9gx6nN\/3GXKlLXLgwcPGubTqKSbOXMmTtGUKWucvrM1JEjpj4QxpS9W3RIBEUgfAZ9SZTTnvSPstttuG3ekg6lVdpSSZnh4GKeksWb4yiuvhB2q0WlUH52yC5WyyMyGG9Y4EVNElbC0moQxrW+23f1SfSIgAm0hgGhxtjFa2eOPP26zZ88Ou1JZD2RkydGN22+\/3SoJ4wc+8IEwBUu66DQqZbOhh6lb1hUpk80\/iCLhxKfZJIxpfrvqmwiIQNcS2Lp1a2GnabwTxLHu52uJjBrZlUoYxjogcUeOHDHSkt\/90dGe5yNdNJz0GCJIeW74CU+7SRjT\/obVPxGonYByiEBPE5Aw9vTrV+dFQAREQATiBCSMcSLyi4AIiECaCKgvNROQMNaMTBlEQAREQATSTEDCmOa3q76JgAiIgAjUTCDBwlhzX5RBBERABFJBgE8\/cUSiknEnaqc7Sxu8jRz+73R7mlW\/hLFZJFWOCIiACDSJAEcs\/IgE17xxhnBgYCB8\/snDO310goP\/XCLAvay0ieMgTep+x4uRMHb8FfRGA9RLERABEegWAhLGbnlTaqcIiIAIxAgwlfmZz3zGBgcHjSlNpmBJwmjOv7ZBOBad6uSZO0+ffPLJkI94jHDyY9zB6uUSh3k8LjficBfr6tWrQ\/2kJx9tIC1GG2gL4RjXyi1btix8ULlUPGmSYBLGJLwFtUEEuoqAGpskAnxtgwvEmc5kChYh8ivhCMM2btxo0XtPaf\/58+fD5eFM1ZKGqVruQkW8EDkEjztYicOYMvUymDblyxvc2Uo4t+5wiw6iePLkSTt+\/HiY9uVaOgQUIaVO7M0337S\/+Zu\/CWm4oYcr7ghPkkkYk\/Q21BYREAERqJEA95wiap6Nr2rwBQ7WJT2My8J5jn5gGFHjG48IGnEPPPBA+N4jQnnt2jW7ePGizZs3j6hgiGElIUOQEWm+\/OHXy5GHtu3evTt8EDkUlPvhzlVPk\/Mm7j8JYwteCf\/awuotmrxYp\/LXW6\/yiUCSCVx76jN29fPvSqz95PCX6sLH5eFTp04t5GVTjo\/gmGplypJRG9OehUS5B76\/yOelco9F\/yFafIZq8+bN46ZJixJGAhBkyoxfRs5XOxBZxNaTRwXXw5LkShhb8Db27NljWL1FkxfrVP5661U+ERCBzhNg5MbaHoKIsDHV6dOetbSOaVmmYJkWRewoj6nSSmUwPctIlbRuTMlWypPEOAlji95KIyM+mtTp\/LRBJgJpIjBl7kfsnR9elVibNP2OpuB+4oknwqekmBJlbZDpzHoLZvRJGRgieeDAAWMUWq48pnURUtJH7ciRI8YotFy+pIV3rzAmhCRTBM8\/\/7yNjo6Oa9Frr71W8BPHgvS5c+cKYf7Q6fzeDrkikHYCiOLUT37dkmq0r9F3wD+oL126ZGzG8bVDymSaMz6VSngthkiyXlju+45Mj169etWi65iUj5Cyu5W24e8GkzA2+Jb4Q\/i5z33Ofud3fsd++MMfhtJefvnl4PJD2Kc+9Sn77Gc\/az\/60Y8IGmedzj+uMfKIgAh0NQHEkJ2kQ0NDxu5SOsPUKgfxeS4nasRFjbwc50DUPJxy2FzDmqGHRV1GpnxAed26dUV1P\/jgg0bboumT\/CxhbPDtsED9zW9+037pl37JOJ+DADLPzogRwSTs53\/+5+1v\/\/Zv7dd\/\/deLaut0\/qIGdSZAtYqACDSJwOOPP25syPG1Pj+6wTTnRIWRac+nnnrKEFhfK2QDz9q1aw0BLNdU1iX5O83rJg9HNirlKVdWJ8MljE2gz7+E\/vRP\/9SeeeYZe\/XVV+3v\/u7vgvGHkLA\/+7M\/s3e\/+91la+p0\/rINU4QIiEDHCfD3A7tMEZ14Y5jeJI40HsczYb7GxxELhIl1Pi\/D\/Qig5+M8oacljDjyeDm41EccFk9PGEYdpHWjLsIxLzMaRnjSTMLYpDfCOuKPf\/xj++d\/\/udCiYwcv\/\/979uNGzcKYeUeOp2\/XLsULgI1E1AGEehyAhLGJrxANtA89NBDxjQD0xb33XefYVzVxEjyD\/\/wD8Nh2XJVdTp\/uXYpXAREQAR6kYCEscG3fvDgQfvN3\/xN46Dsd7\/7XePMDjdK9PX12R\/8wR8YUxFz5syx3\/7t3za2Oser63T+eHvkFwEREIEIgZ58lDA2+No\/8pGPGDu1GBn6OuIdd9xRKJWwRx55JNxJ+NGPfrQQ7g+dzu\/tkCsCIiACIpAnIGHMc6j7F+F773vfW5SfnajRwFtvvdWmT58eDQrPnc4fGqEfERABERCBAoHUCmOhhx16mDJlSkM1dzp\/Q41XZhEQARHoYgISxha8PLY0Y\/UWTV6sU\/nrrVf5REAERCANBCSMaXiLqe+DOigCIiAC7SMgYWwfa9UkAiIgAiLQBQQkjF3wktREEUgTAfVFBJJOoGeE8fd+7\/dM1joGL730UtL\/rKt9IiACIjAhAj0jjPzFLXvJXnrppZbZhP7EKZEIiECKCKSzKz0jjN\/5zndM1joGv\/Zrv5bO\/4eoVyIgAj1HoGeEseferDosAiIgAiJQF4FeFca6YCmTCIiACIhA+glIGNP\/jtVDERABERCBGghIGGuApaQJJaBmiYAIiEATCUgYmwhTRYmACIiACHQ\/gUQK45kzZ2zZsmV25cqV7iesHoiACNRCQGlFoOMEEieMiOG6devszTff7DgcNUAEREAERKD3CCRKGA8fPmwLFy608+fP996bUI9FQAREIG0EurQ\/iRFGRHH16tW2cePGYF3KsyubffP1l+2n\/7DHfnL4S8GtpRON5K2lHqUVAREQgXYRSIww9vf329mzZ62R7xC2C1qa6kHYRnZ9zK499ZmcMH45uG\/++Qft+tnvVu1mI3mrFq4EIiACItAhAokRxg71v0y1vRGMsCGIuJNnftD6+h8xXPyEV6LgaXDJU0veauVSZiOGqMu+G\/5xc\/XYUbuw76jh1sKE9PXko45G837vGzdt+ODNSn9MFCcCLSWQKmE8ceKEHT9+3C5cuNBSaEksHCGpdTr05uuvhL88M++61d4x\/7dCt3DxUx5Tq7j8ZYdRPkb4Tw5\/OZ\/330yzyXN+xSgr865\/a5l3Ts09v2yMOkvZ1c+\/yypZqTy1ho3sWmqyPAN75mOW\/V8fM9xamJC+nnzU0WjeC\/uP2nNfvGn7Bq7ba\/84Gv5c6kcE2kkgVcK4bds2GxwctP3797eTYcfrQrxGJjgdSlrMhY7Gj\/7L\/wnTqIgdhp9wnhGlkTGhYRSJEY5Akmb0X6+GdUn8lDn602sEB3GknriFyDb\/qLruJDDyquUE8kZ3Nl6t7moCqRLGLVu22N69e23FihVd\/VJqaTzCg1jhRvPhJxzBwkXcGKkhdBh+4qJ5mvI8+R2hmEnT7zC3KXM\/YqXsnR9eZRMxpmnbYVM\/+XVLit1c\/HX74Rs77B9\/UNoqtfPNf7cz5Hvxyg6jHDf8lEd8qfyEE086z4OLn3DiS+UjjDjS\/NPFHcYzdmnqTvve\/94R2kJfMNJUs9v+0x32od+fZH3TzRBHTauG\/0vpp40EUiWMs2fPDsc95syZ00aEna2KKUxGakxhIkTR1kTFkTTRuKLnnKBl\/s17wlQocZSFaCFI\/MXnll39rGHv\/pMXg9iRNrrGaDd+FgSReDfSlzIvs5rb1\/+F3Ppn643+Ntt+etv99uLzg0VGeKW6iH\/xe4N25f8N2ns\/vqpg+F95bdCwcvn\/b+b+ED\/1P+by\/cbbhp98xJfKSzjxpHvvWL53fvh+m3LXqlAe7SGe\/vzPb6807H\/sXmluxA0PDxb8xL90Id9W8mKkqWbv8asq6AAAEABJREFU\/uAd9qFPT7JfHMj\/9YQ48ucsb\/oVgdYTyP\/Ja309qmECBBCy\/Prdl3JTm28b4dHs+BE60jIaJI4pTMJ5LmUIHaM2\/kLs638kjIxcrIhD0Eb\/9Q2jHPzZ1d8OafpyokQeN8rASIOg4d64\/GKuvV82XPzkLdWGbg4beXXU2BQSN8Kr9et7f3XT4lbtL3tfW0McEAk3\/NRXKX92FinMvn8gV+833jb8xLz\/VzK5kdhoMOphREa\/Xnt+lGj7pyfz63t\/\/R+u59b5btiL\/y2\/EYa0rP3Rl+GDo4YRhoWMNf7QTiyejXbQnmh742nkF4FWEpAwtpJuHWWzfhc3ikH0mPpECH0qlHSEE1\/OEK9p\/\/lfjNEbQojfxQ6Bwzyub0ww8SNw5cr0cNKQlnJrzetldJOLIMStkkAhmggJfWRa8P2\/nAnTg\/if+2LltTMXDMQBkXDDT37EDbeUzfv4JCP+J6\/bOEHGT\/pnH7oRBG\/fwA3jmTbSLxe46z\/JT2GStprRToz6cEulJ3zpX0427BMHJtun\/n5KsE8cmGIYfvJ7XgSX9tBe8kbjPI3cdBBIai8SKYycZTxy5IjNmDEjqdza2i4EEDFEFBHHaOWIExYN82fCGem5v5KLQPaNjQ4rpSsV10jeUuUlLaxegUM0EZvpczP2u9+aYkv\/y+Tg4iduuMKRhEri5mJBuyifchBaDKFjpEd4szhS3+JHJxmGuGEucAgbRhhG2mi9+AlH3LDsrEw0uvBM2dmxka4H4iev++WKQLsIJFIY29X5JNXDyA\/ho02T3\/fv7R0f\/I3Cel8pMUTwGKnlR2zfDut65HVDFNM4pen9a6eLiCE0CFotAkce2nnHR8eLgfspl\/hyVkosPC3iFx3xDUemNj1N3EVoMARq3sczxgYX6kB8MBc7RnD4PR7hQ6gx8mLZEgJHGGnjeQmPtyXuJ029eeNlyS8CjRKQMNZDsAV5fBPNpHffZqM3fmo\/e\/G\/h\/U+rwqh68tNdboYMiXKSI144vIC+ayRhjj8hBMva4xAvQKXnZWv9+Xv5Nfu8j4z9yMwHobLCBAbzo0kGf0xxVlKPEuFkR+jTsqNCx+ih\/BgCNfiRyeHDS7lxI4yWNcknnJrsU7lraWNSisClQhIGCvRaWOcjwpvvnkpnAH0qifPuis8sjuwLzfV6WIYAmM\/xJGG0WQsSt4cAUTH1+qiLuG56LL\/ITZEuqDxjLkfIcAfN0SFuNfPjtp\/ve+6PfvZG8HFT5mYiyBToIwAMQRxODcCdEGOl0s+ykX8FkemOBnplRO+bIkRXrxc+UVABPIEJIx5Dh37ZQp1ZNfScEjeG8FID3Fj1Gc3r4fgKXPvCa5+GiPApo6YVS0wKnBP33\/DEFVcFzhEqlwhTEcSx0YSdlvi4mfUV00Es7kRJ+YCyEjPR348L86N+mgbVqkN1CcTARGYOAEJ48RZNTUlgshxCzbVXI9d2J2Z\/M7cmuHP2b\/89ScKRyAYDTa1AT1YWDY3akJksjnBofu4CFc2F46\/kpGOeMQQYcXFjzjhxo1R6HBuSnT4W\/mjDvH4uD+baxPiRvsW50aBCB+jP2zxmAASn51AW+Nlyy8CIlAbAQljbbyqpnbBQ\/SiRrhn5nlk18fC2T8PY5TI+iHujR\/\/KMSl+Vyg97udLmLF9CSjNerFRbgIw1\/JsjnhKhXv4ZSNELI26NOiPiUaz0ceLC6CiGFUBOP55J8AASURgSYQkDA2AWK8CI5XxM3TIJaMEhFHwhDCvv5HwjnDSdN\/zlhLJBybNP2OcX7CkmSIAdOKcSM8Se2kLbQJoUIM2V3KCBAXP2JGmkqWzY3UyBM1hG04txYYF8K40GZzokraxRVGgpXqVpwIiEB7CUgYm8wbMUPofOoTFz\/VIIoIJs8YcRyp6Ov\/At5g0XjEM+oPCRL2w7Ri3Ko1EZGKiyl+wqvlrTceAUSwEMPlT+Z3ZOLiJ244N+1ZrWzEDZEbeW3UGGkO50SRvlNuNC9pSBsVwsWR6dBoWj2LgAiUJdCxCAljC9AjdAgkRbOJBotOnRLXlxsl+tQp6TAPJy5qhBOfNMuOjaKyuRERbUMMGFFlc+H4KxmCErdK6RuNc\/HyM4RenvsRRw+Luoj1cE40GVVGN8tE02dz\/Wf9j74zHRpfF4yWp2cREIHkE5AwtvgdMepDFHGpCpGLjxIJd+vLjR7j5nFJdDnrlh0Twnn3TQpn46q1k\/SICOZpeSbc\/c12sznxokw\/YsEz5n6EDT9WTgyJc6M8\/iGwODc9ihAiiLCIluNp5YqACHQXAQljC95XtEimQuOiiDhG0\/TiMyKCed+jzx7WTNePNLCblKMWTN3i4kfksFIjw2gbSIOAI4KI4eKx6dFoGj2LgAh0PwEJYwveIUKIRYtmOpVziRLFKJX2Pi\/Oje4QN8SQaVxcWsAoLzpNSpgb6RFDPz+IgJPe4+WKgAikj4CEscnvFEFk6jR+NhFhbHJViSiOaUdviK\/jub+SSz5GaJXStCKO6d54ucMHx1\/ZNl4Mp4Tp4ezYdHE8r\/wiIALpIyBhbOI7RRS5CBzXi82869bwSHh4SNEP4sZRBRdERmH7Bq6b+8t11fNxfMLTTCSfp23EpY2l8mdza5CMDH2alJFhVmJYCpXCRCD1BCSMJV4xwpY\/WvH2x4LxE14ieSHILwL3AEaJ73nsJZs884Ph\/lO\/D9Xju9lF3BA2dmdy5AFRwcXPDs5yfas3X7nyqoVT3\/DBm4aA7xsY\/w3EbE4M2UATFUNNk1Yj2t3xar0ITISAhLEMJTbNxK1M0hCMaCKewZP7QRT5ykXu0d4x\/7dwgjiGhxT8IICMDBFDzgMywsLFTxxiVKqbxNWTz8tC6Ng4EzfCPQ0uftIghgg4dRKOIYgIuW+gkRhCRSYCIuAEJIxOIuKyQaav\/xFD3Ah2Py7+uOVF8ctWWFec\/A5zUbTc\/3525pu5X7M0XQTuQuPnAEMHcz\/uRwBz3qL\/6s0XLYjp0Lh5PILIiBVBJI2HI4bx0aHHyRUBEehGAq1r86TWFd3dJff1fyEijD9n+Mv1iClSrBB\/42f21l\/cbYwgcf3OU266KaTp8geEhi74OUCeMfeXG4XVm4+ysWxu3Y\/RHiKX95vh59kFcTiymSabmy4lnunSxY9OtnLtIr9MBERABCAgYYRCA4YgMuVKEYwo\/TYbxJBw3Hz4t0mSGqt2LrCcANWbLwqOadv3\/3ImBGVzQsnnnBghlhJEpktJT7qQQT8iIAIiUIWAhLEKoErRTKFGd5v25aZfGRVyXhGXvEzH4kcc8ZtZapzFJc4FZnMjNEZnlTpZb75SZTI1i3kc9VO+C6KHyxUBERCBiRKQMJYhhehdP3s0xLLbNDxEfoiPiyIi6ElcCF0gPTxNbjY3WkOAsjkxpF9MWeb9+dEcYaUsO5YvKqATyUdZrCGyw5QNNfjdsrk2UB7lMCr1cLkiIAIiUCsBCWMJYogeh\/SZCiUaP5+Kuh75oDBTqO5HBPtya5Kk7TZDaNi9GTfCJ9qXbE7oSFtu+pS4UlZLetrja4jxEaILYi3llWpPXWHKJAIikDoCLRPGnTt32ty5c4MtWLDAzpw5UxVeNA95Dx8+XDVPsxMggowEcTl\/2JebHsXFTzj18eyiiShyKTjhWD7uS4Udqognm3AIJz6Jxu7NuCWlnQgioh1fQ\/T2IcoSRKchVwREoBkEWiKMCNzQ0JAdP37czp49a2vXrrV169bZlStXyrYZEdyxY4c9\/fTTIc+uXbts9erVRnjZTC2IYNoUMUMMb\/njk2E3Ki5+xA2Rc4GkeoQTceTZDdEkLX5Glvh5TqIhLEyBurjg4ie8WntdtHBJyzcKETH3E1avUQZlIYiIdrlyGD3um8BtO+XyK1wEIgT0KAKBQNOFEfFDFFeuXGkzZswIlaxatcpmz55tBw4cCP74z8jIiO3evduWLFli8+fPD9H9\/f02MDBgzz77bPC36+f62LriO+bnD+V7ve7\/6T88WRgNsqaIeRpcRBKxjBvhxCfR2LXpuzxx8U+0nYjWyKv51OwKxZ\/3lf910UP4PBXPhOMfHrupJlpWdlb+WAbCTZrpczPhmAYu9TPNSrhMBERABBol0HRhvHz5so2OjtqiRYsKbctms3bPPffY0aNHDREsRCTwwQXMD+V7E93vI0HSIX4eH3X7cuuNcYvGp+U5m1tbZHQZN8Kr9RHRwzwdzwicb6zhmbjsrLwgsqkGUWSEiBhyyw4Cjouf9AgqeWQiIAIiYA0gaIkwZjIZmzlzZlGzLl68aNeuXSsKRzgffPBBO3ToUGEtkilURphLly4tSt\/KAEaA7CTl\/CGH85k6xcUfrbcvt\/aIOEbDevEZcYpbNQ7ZmKByWD+bE0BEEeEjP34EF0GkfMI8zm\/XIQxzP+KIXyYCIiACjRAoK4xMid57773GJpjBwcEw0tuwYYOxfthIheXyMnW6Z88eY9qVOtevXx\/WGwkvl6dV4VznhughhqwP4kbrQjgR0GiYnmsjgNhhCCCCFxU1wthpSny0VMLx++06PGPuZ0SJXyYCIiACjRAoKYyM1ljv2759u23cuLFQPs9DQ0MtEUdElw06jBrZsOMiWYsQnzhxImz4uXDhQqHN9TwgihzKZ1RIfvyYP\/flpkp5bo31RqmsJzJC5DziyNgaJcLno8RsblQZJ8H5RMTv9bOj9vT9N4x1SVz82dyIk7h4HvlFQAREoFYCRcLIGiAbYdhJ6hthvFA207CpZignjowoPbxRl6McCOJjjz1W2LBD3bShlrq2bdtmjG7379\/faJNCfr\/0m3VFjEBGixjPaTFEauS10dAdd4OnBT\/UhaDtG7hR+G4jouaCGB8lxpvArTakRwxZl8TFzwgznlZ+ERABEaiHQJEwsgbIWuC8efNKllcu3BOztsjmGzbheJi77EydOnWqe8e573nPe4rWJanr6tWrVqqscZnHPFu2bLG9e\/faihUrxkKa6zBqZJq1uaV2tjSEipHb8NjF27j7WnT8gboYISJo3msXtWqC+Hb6jIV1x9\/P\/9FllIg\/W2KE6Xk66apuERCB7iOQ\/9sl0m6ECwEbHh6OhL79yPEJ4kn3dujbTwhjJpOxY8eOFQIZhbIjlZ2pbLQpREQe3njjjZICOG3atCLBjGQb90i7Fi5caHPmzBkXXquH0SGbbn76D3vGZe3rf2Scv9s9LlQjuanM6S08\/kA9lUaJ9YhaNjd1Cn93eZaJgAiIQDMIFAkjwsUOUQ7bM8UZrYT1PnaKEk+6aJw\/+3RrND\/rhYxCOZfo6aIu06asaW7atKlwCQB1swGHqVvKjKZvxzObbuLCmL4pVAvTmYgixx4YteHiRyyHD95sGDWi2OgoseFGqAARaAoBFdIrBIqEkY6zE5Q1PzbDbN68OWxoueuuuwyx42Ya4klXztasWRNuu1m+fLmxw5R8bOSJChybbTAvY+vWrYYIMuIjD3lZY6QsT8jw7u8AABAASURBVNMulylTRoe4Xie7UKN+D+9ml92gtN+PO\/CMuR9xxF+vNXuUWG87lE8EREAEaiFQUhgpABE7cuRIuJ6NXaLYqVOnCjfTkKaSIWjkwUrlQwixaBnRPOTDH41v5zMbb5hSpU5GikleW2RUhgjFjXDaX858GtKPO3g697N+52G1uNQb2vJXb484qYsNMoxKaylLaUVABESgFQQqlVlWGCtlSnscgsgaI\/1klNjXBccz2NASN9pfyVpx\/IFRKJt5aAt1I4i+4zTbhA0yLrrD3xrbRZtbH0WECac+mQiIgAg0SqBIGDmGsWzZssINNPEKOOPIwX\/SxePS4r9+9ruF+1AZLWJJ7huCg\/hwgwztzM6ycI9odgJC1KzjDwgTAoUo+hRsNteOVowSEV0EmL7i4udZJgIiIALNIFAkjNUKLbdbtVq+bolntOibbhgtsraYqLaXaQxTlIijR+P350puNieeHHdwUcXFT3ilfNE4RBFBjAoUbam1nGiZ5Z5pF2XHjfByeRQuAiIgArUQKAgjG2HY9MLmlxdeeMHY\/II\/bmzGYZMMa5C1VNQtabtttNgsrtn3Z0JR7gbPBH4Yse0buGHRUWIQrU8X\/mhNoJTakiD6cautBKUWAREQgfIECn97sRGGDS98Q\/HOO+8M95TiL2Wd3BRTviuNx3TraLHxntdeAqNEnzr13NkWTZ16+Sl01SUREIEEEigIo7eNkeAzzzwz4d2nni8Nbq+OFmt9d4hidOoUQWSU2Iqp01rbpvQiIAIi0CiBImGkQDbWsMEmPo3qfuJIQ9o0WTeuLbabv4tiO6dO291H1ScCdRFQptQQKCmMrCNyvdrp06fD1zW4sYYpVQ7333LLLRa97DstJLp9tIhgsd7H+3DR4rmZxtTpvth6IrtOOfbRzHpUlgiIgAh0kkCRMDISPHnypPm9plzkfenSpfA9Rq5u4zYavr7B\/aedbHiz6\/Zzi5TbLTtRaSuGKDK1ydVr+LF9E7wInLwI3mvP588F4uInnHIwnglrx65T6pOJgAiIQCcJTDIrXT2CSAyXgr\/11lvGVzfwL1q0yKJ+wrrdunm0iGghiIwSp9d5ETiC56NNXPz+Tikf0fUwX09kV6inkSsCIiACaSJQNGLkqxlMo\/p5RYSRDk\/000+k7TaLjha74ZabKF8EETFDFLkAHMHCxU9ctYvAs7My4TIANs9EjXAXRcqhzuwsM6ZOqQO\/TAREQATSSKBIGPlqBtOoQ2MfI2aX6i\/8wi8UPiPF56RYZ0RA0wCEIxqMGOkLN9xgPHeLIYq01S\/+5hlz\/8ir+CobQhc3pk73lVhPzOaEtHJpihUBERCB7iZQJIx0h3OKd999t7EJB\/\/GjRttKCeU7ErF\/drXvmYIKHHdbnxeyvvQbaNF2p3NjeJw\/eJvnjH313oROKNERNGnTimLkaSOYkBCJgIi0AsESgojHefAP8Yzo0b\/0gYufsK73RgtRo9odHq0WBClb9y0IE5jLuHlWLMjFPF7\/eyoPX3\/jZAPFz+iSVy5vPFw6hk+OGouiuRHFBlNxtPK3w4CqkMERKATBIqEkd2mg4ODtnPnzk60p611+hQqlfb1P4LTcUOU4latUc24CBxRjG+ymXffJJMoVqOveBEQgbQRKBJGdp9evHjRfFdq2jrs\/YmPFpNwRCObW79jhJYdmx7lQu+8P3+Pqbc97mZz+ZjqRCCJy+by48\/mwvFXMxfFkbH1yGwuvzbZVKOmeBGojYBSdw+BImFkmpQD\/Js2bTLONHZPV2pr6c3XXxn3aanacrcudXSEhihG\/dVqrWXa1MtCFLXJxmnIFQEREAGzImFEDBHF8+fPG1\/aYMNN3NJwJVz0iEYSRoud+MPIOiai6HUzQq1lpOn55IqACIhAmggUCSMjRjbYcAVcsLNnLe4ST7puBcE0qq8vsuEG69a+1NtuRJG1TM\/P6HTxo5PdK1cEREAEepZAkTD2AoluP6LRyDti6jQqiqwnIoq1TNk2Ur\/yioAIiEDSCfScMDJaTNIRjXb+ARl5ddTixzG087Sdb0B1iYAIdAOBnhNGn0Ll5bzzw\/fj9IQxUuROVZ8+ZaTI1KlGij3x+tVJERCBGgi0TBg5B+mbdhYsWGBnzpyp2qzDhw+b58GljKqZakwQHS329X+hxtzJTI7oMT3KaJAWcuwCP+F5\/6hxRtGvj0MUOY5Rzy5WypMlhICaIQIi0BICLRFGBG1oaMiOHz8eNu7wqap169ZVPP6BKK5evdp27doV8vDtxx07djT1ogFGixgkk7rhxsWMNrqQ8VzNGAlins6fKQ9RHImdUcxO8IyjlydXBERABHqFQJEwclxj2bJlZUd4CFil4xrkH8qJ4sqVK813rq5atcr4YseBAwdKcuW2Hb7xyJ2s\/f39IY1\/+\/Ho0aPhW5AhsMGfpB\/RiIsYU5\/7JvBdRUQubKD5\/UnjvpQBrrgo6jgGVGQikDgCalCCCBQJY7W2+eeoyqXj81Sjo6PGdxs9DReO88WOciJ37tw5u3Dhwrg85OUy871799Z9YTkbbRBDNx8tTpp+hyVtxIgoIoQjuZHd9Dq+q8haYdQ4k7gv8nUM\/IgiXGUiIAIiIALlCRSEccOGDca6Hof6X3jhBVu+fHnwExY1vrgRHQ3Gi0YYM5mM+Xcco\/FcNceVc9Ewnj1PJpMxRqNeH1OyxDdiHM1w83L6EnIvqrcHF0Fk6nR6ThT5niIih4ufuOGDN0k2ISMtouiJGU2y0cb9ckVABERABMoTKAgjX9LgID\/rgnfeeaexxoe\/lDGS8yKb4TIK5aadhx56yJ566qmmrTEyMoyLIGGtvOmGkR8bX+JGeCVWiCLx\/h1FnjH3I474qxmiyMjT0yGKiKz75YqACIiACFQmUBBGT8a64DPPPGOs8XlYO9xbbrnFtm\/fXliXpH427Qzl1itZt5xIG06cOBE2\/DAt6+n7YjtP2zGFysaXuHl7yrnZWfkY\/45i3mfm\/onsIEWMJYpOTq4IiIAI1EcgCCPCwxQmU5f+7NOZpVzSkq6+KkvnmjZtWtH0K1\/4uHr1qjHVWjrX+NBt27YZn8zav3\/\/+IiIr5WjRarJzsqEDTAuZLiM2ggnvpw1+l1FRBEx9vKps\/aRoueWKwIiIAK9SyAII6NE7j9litSfS02hehhpSVcKG2uLbL4pJWbsTJ06dWpRNgSwKLCOgC1bthibdVasWFHIzQYc9zCN2o4RI4KUnZWvdd59mQl\/03Dxo5OMfK+fHTVEDhc\/Zw7zpZX+jYoi6SWKpTkpVAREQAQmQiAI40QSTjQNwpjJZOzYsWOFLBzHYEcqO1PZoVqIGHu46667wtPp06eD6z+sPZYaSXp83EV42Tw0Z86ceFTwt0MUQ0V1\/mRzo012jmZn5QtA4PL+TD6gxG9cFHXFWwlIPRqkbouACNRHIAgj06JMj5aaNi0VRlrylKqSkSS7Vjmc77fd7Nmzx9iROjAwUCpLWFckD5+78nI5L1ltB2zJwiKBjBZHdn2sEMKtN2\/++QcL32EsRCT0gSMW5ZrGZh6JYjk6ChcBERCB+gkEYUTMmB71qVJcdqfefvvthZtoCHMjLXnKVcuULBtn\/MgHIhndWEM+jodgPGPk4QPJjPgQY78Fh3DiazVE8dpTnzHcyTM\/aH39jxgufsJrLS9J6RHF4YP56VbaxQhz8aOTJzxlSx6ZCIhANxFQW9tJIAhjKypE0FxIT506VbTLleMhWLRubr3xPLj4o\/G1PN98\/ZUwMkQMb\/njkzlh\/ILh4kccGT3WUl5S0pYTRTb5JKWNaocIiIAIdDOBlgljp6FcP3s0NOEd838ruP7jfsTRw7rFLSWKbMyRKHbLG1Q7RUAEuoFAq4WxYwzYgUrlPzvzTZyCuX\/K3HsKYd3wgCiyUxWjvUyfIorZWeU35pBOJgIiIAIiUBuB1Aoj5xXZhXrj8ov21l\/cbdyXiosf0SSuNlSdS40ocnCfdUVakZ1lJlGEhEwEREAEmk8gtcIIqqmf\/Lohgogh96Xi4s+u\/jbRLTOEbOTVfPHu5n21\/1IWouhXxnVUFGtvvnKIgAiIQNcRSLUwIoLv\/pMXCy8FocRPeCGwyQ8IGZ96ciFj6nPfBD4dRTPIyxEMF1NGiNGyJIpQkomACIhAawmkWhjj6JhejYc104+wMbpD2PgqBgf0cfE\/98UbE6oKIfWEPJMXv0QRCrImElBRIiACZQgEYeRQPYf2OT\/oxnlCvnjBeUIPc5e05ClTZs8GI2KMFBFDPhnF1XC4+IkbrvLpqOysTLhnNX6wPztLa4o9+4dKHRcBEWg7gSCMHNbn0D5nBydipCVP21ub8AoRRZron4riGXM\/4oi\/kiGKXg7pJIpQkImACFQkoMimEgjC2NQSE1QYZxXZjepN4hkj3MOa6SJilOefiuIZc3+184ZMxbKm6AJKedp9CkGZCIiACLSPQKqFEYzsRsXFeMZ4boU18umoUqJY7QLxVvRBZYqACIhArxPosDC2Fj+7T7kjNW6Et6rmxXV8OqqcKLaqjSpXBERABESgPIFUCyPd7uv\/QrgnNeoS3irLzsoYIz2fNmXNED\/hpeqUKJaiojAREAER6ByB1Atjp9BmZ+Vrfv8vl7+yLW2imO+xfkVABESguwlIGDv0\/iSKHQKvakVABESgCgEJYxVArYiWKLaCqspsLgGVJgK9S0DC2OZ3HxdFX4NsczNUnQiIgAiIQBkCEsYyYFoRXEoUFz86uRVVqUwREAERKBDQQ20EJIy18ao7tUSxbnTKKAIiIAJtJSBhbANuRHHfwA3zG22YPtVIsQ3gVYUIiIAI1EEg2cJYR4c6nQUR5NNRft\/pa8+PGqLo7ZIoOgm5IiACIpBMAhLGFryX6Oeihg+OFmrgM1QaKRZw6EEEREAEEklAwtjk15KdlSn56ShEkc9QNbm6bipObRUBERCBriDQMmHcuXOn+fcbFyxYYGfOnKkJyIYNG2xwcNBGRkZqypeExNlZZvGRokQxCW9GbRABERCB6gRaIoyI4tDQkB0\/ftz4vuPatWtt3bp1NtGPGx8+fNgOHDhQvfUJTDF88KY998WbhZZppFhAoYc0EVBfRCDFBJoujIgforhy5UqbMWNGQLdq1SqbPXv2hMSO\/Js2bQr5uu1Hothtb0ztFQEREIFiAk0XxsuXL9vo6KgtWrSoUFs2m7V77rnHjh49WnVqdPPmzXb33XfbwMBAIX83PLATVSPFbnhTaqMIiECMgLwxAi0RxkwmYzNnzoxVZXbx4kW7du1aUbgHMIV66NAhe+CBBzyoK1xEkZ2o3lhNnzoJuSIgAiLQfQSaLoz1ImCTze7du431yPnz59dbTNvzRUWRTTcSxba\/AlUoAiIgAk0lkBhh3LNnT+gY65HhYQI\/8SQnTpwIG34uXLgQj2qJPy6K8+6bZNp92hLUKlQEREAE2kYgEcLIUY69e\/faww8\/bKxH1tv7bdu2hSPgs4pkAAAQAElEQVQe+\/fvr7eIkM9vrwnC942b5i7hJMANYX+V333KSFGiCBmZCIiACHQ\/gaYLI2uLbL5hE04cDztTp06dGg+2Y8eOGaO85cuXF84+clyD4x5s4kE4izKVCNiyZYshsCtWrCgRW1sQa4ZxowREcfjgqBGHH1HkNhuNFKHRiCmvCIiACCSDQEuEMZPJBLHzLrJ+yI5UdqaWGhGuWbMmnHfkzKMbu1IXLlwYypnomiPCS545c+Z41XW52djtNdlZFm6zobBSovj+X8kQJRMBERABEUgBgaYLI2cXOcO4Y8eOwm03rB+yIxWx6xZmjACZHqW92ZxQcvk3xzGiI8WlfznZJIoQkonAeALyiUA3E2i6MAKDESC7S31qFJHcvn174cA\/abjyDeM56cb06bMP3TD\/YkY2N4JEFLM5wUx629U+ERABERCB2gi0RBhpAuLo06KnTp2y+HTo1q1bDSNtKSOO9cJSU6+l0rcybORVK3xLMStRbCVqlS0CIpA4Ar3XoJYJYxpRIoqfODDFshoppvH1qk8iIAIiEAhMCr\/6KSLAtCnTpx7BGiOi6H65IiACIiAC6SSQZmGs+41xRjEqitnc9ClHMuouUBlFQAREQAS6hoCEMfaqEEXfeepRrDHuG7he2Hzj4XJFQAREQATSR0DCOPZO2XkaF8W+6fnzi9PnZsLmm+e+eGMstZy2E1CFIiACItAmAhLGHGhEMXpwPxdkiOLvfmtKuPt0+ZOTzcVx+OBNomUiIAIiIAIpJdDzwogosp4Ynz79xYHxaO74aP52G6ZVU\/pnQd0SgXYRUD0ikGgC4\/\/2T3RTm984F0UXOzbZ8Nkoanr5O6M4BXO\/bropINGDCIiACKSSQM8KI8cx9g3cCGuHvFlEkdtsuAoO8Xv97Kg9ff8NY90RFz9piCO9TAREQAREwMxSCKEnhRGxY\/rU36efUcyOHdxf\/Ogky84yQwyZYsXFj3B6HrkiIAIiIALpJNBTwsjUKaKI2PnrZOp08aOT3RvcbE4gOcxPHAGMEvETjl8mAiIgAiKQXgI9I4yI4vivY+SPYjB1Wu71Iojl4hQuAiIgAiKQTgI9IYyIIlOnrCvyGrO5aVKmRSuJIulkIiACIiACvUegJ4Rx+OBo0SabbG66tPded3p7rJ6JgAiIQLMI9IQwMjJkWpQ1Q60VNuuPjsoRAREQgXQS6Alh5NVp6hQKMhHoBgJqowh0lkDPCGNnMat2ERABERCBbiEgYSzxptisw7GO4W\/l70V1P26J5AoSAREQAREoQ6Abg1MtjAgZAhc3wqu9LM46smmHdFwZh59nmQiIgAiIQLoJpFoYeXUIWtwIr2TsWGWjTtwIr5RPcSIgAiIgAt1PINXCiJAhbv6aeMYI97By7oc+PSl8coodrW7l0ipcBERABEQgPQRSLYy8JkQNF+MZ41kmAiIgAiIgAqUIpF4YS3VaYT1HQB0WAREQgQkTaJkw7ty50+bOnRtswYIFdubMmYqNGhkZscHBwZDe8x0+fLhiHkWKgAiIgAiIQLMJtEQYEcWhoSE7fvy4nT171tauXWvr1q2zK1eulGw\/orh69eoQd\/r06ZBn165dRlij4hjdgTp8MH\/8IlSkHxEQge4koFaLQIsJNF0YET9EceXKlTZjxozQ\/FWrVtns2bPtwIEDwR\/\/OXfunF24cMEefvhhy2azIbq\/v98GBgZs9+7dhnCGwBp\/EEUuD\/dsfF1j38B188vEPVyuCIiACIiACDiBpgvj5cuXbXR01BYtWuR1BLG755577OjRoyVFbv78+SEOt5Ap9zBv3rzcb33\/IYoI4cirZtPnZozdqLj4n\/vijfoKVS4REAEREIFmEkhkWS0RxkwmYzNnzizq8MWLF+3atWtF4aUCGCUipLfddlsQ1lJpKoUhgIwMEcPlT04ORy9w8ROnadVK9BQnAiIgAr1LoOnC2CyUrE9iS5cunXCRJ06cCOuaTMsiimS846MZnIK5H3EsBOpBBERABERABMYIJFIY2cG6fv36sMbIWuNYW6s627ZtCztb9+\/fb9lZ+eQvf2c0\/zD2634+QzUWVJejTCIgAiIgAukkkDhhRBTZrLNkyRLbunVrTdS3bNlie\/futRUrVti8j08yxO\/1s6P29P03jPtScfEjmsTVVLgSi4AIiIAI9ASBpgsja4tsvmETTpwgO1OnTp0aDy74GxFFCqH8hQsX2pw5c\/Da4kcnhZEjYsh9qbiIIt9mDAn0IwKBgH5EQARE4G0CLRHGTCZjx44dK9TiG2nYmerHMQqRYw+NiuJYMeOc7KyMfeLAlEIYQomf8EKgHkRABERABEQgQqDpwsjZRc4w7tixo3DbzZ49e4wdqZxLjNRdeOTsIxcA1DN9WihkAg9Mr04gmZKIgAh0MQE1XQQaJdB0YaRBa9asCbfdLF++3LjeDZHcvn174cA\/aTZs2GAYzxz8P3\/+fLgAgPRRu\/fee8vemENemQiIgAiIgAg0k0BLhJEGIo5cB4edOnXK4of32ViDxdOSPmpHjhwZJ6ikl4mACIiACPQCgc70sWXC2JnujK+V22\/YjeqhPGOEe5hcERABERABEYgSSLUw0lF2o+JiPGM8y0RABERABESgFIFUCyO7T7kjNW6El4LRxDAVJQIiIAIi0KUEUi2MvJMPfXpSuCc16hIuEwEREAEREIFSBFIvjKU6rTARqImAEouACPQUAQljT71udVYEREAERKAaAQljNUKKFwERSBMB9UUEqhKQMFZFpAQiIAIiIAK9REDC2EtvW30VAREQgTQRaFFfJIwtAqtiRUAEREAEupOAhLE735taLQIiIAIi0CICEsYWga1crGJFQAREQASSSkDCmNQ3o3aJgAiIgAh0hICEsSPYVWmaCKgvIiAC6SIgYUzX+1RvREAEREAEGiQgYWwQoLKLgAikiYD6IgJmEkb9KRABERABERCBCAEJYwSGHkVABERABNJDoN6eSBjrJad8IiACIiACqSQgYUzla1WnREAEREAE6iUgYayXXCvzqWwREAEREIGOEZAwdgy9KhYBERABEUgigUQJ4+HDh23u3LkFw59EaGqTCNRAQElFQAS6jEBihBERXL9+vT399NN29uxZ27Vrl+E\/c+ZMlyFVc0VABERABLqZQCKEcWRkxHbv3m1Lliyx+fPnB579\/f3B\/8QTTwS\/fkRABESg4wTUgJ4gkAhhvHbtml28eNGWLl06Djr+kydP2pUrV8aFyyMCIiACIiACrSKQCGG8fPmyjY6O2syZM4v6efXqVSO+KEIBRQQuXLhg27ZtM9yiSAUUCMBHnAo4Sj6IUUksCkwXgbK9SYQwlm1djREnTpyw48eP96zRf\/7C379\/f88ymMj7F6fq\/x9JKiMEu8a\/FpRcBGomkAphnDNnjv3qr\/5qGC0NDg5ar9rnPve58AcAcexVBhPptzhV\/\/9IUhnxj77wh1w\/ItBCAqkRxi1bttjevXt7wtRPvede\/TOwYsWKFv51qKJFIE8gEcLI2mImkym5ljht2rSSa4\/55r\/9y6hx4cKFJhMD\/RlI758B\/n\/+9v\/r9SQCrSGQCGGcOnWqzZ4925599tlxvcR\/991324wZM8aFyyMC6SGgnoiACCSNQCKEMZvN2oMPPmgHDhwwDvoDCffQoUP2wAMP4JWJgAiIgAiIQFsIJEIY6SkH+rntZvXq1eFKONyvfvWrhQP\/pJGJgAiIQJIJqG3pIJAYYQQn4sh1cG74CZeJgAiIgAiIQLsIJEoY29Vp1SMCIiACIiAC5QjkhbFcrMJFQAREQAREoMcISBh77IWruyIgAiIgApUJSBgr8+ma2J07d4ZNS3Pnzi249957ry5gz71BPl22bNmykizY\/Tx37twCM\/y5LD35XzlOXOLPn6UoJ575M9eToNTp1BOQMKbkFQ8PD9vAwED4lqVvXjpy5EjPnwHlL\/V169bZm2++WfSmEUG++alvgFr4R0M5TlzizyX\/zsn\/fK1Zs6aIqQJEIA0EJIwpeIt8z\/LSpUs2b968FPSmeV1A+LgF5\/z580WFwqwrvgFa1PLmB1TiRG0IYyaTmdANVKSXiUC3E5AwdvsbzLWf71m+9dZbtmjRopxP\/0GAv+w5C7tx40bDCIsazPQNUAsXalTiBDNmI3QDFSRkvUJAwpiCN3369Gl74YUXbPny5YW1MtaEmEZMQffq6gJnYJnyKzfdxyiI6UHu6Y1X0EvfAK3GiZH10aNHw61UrCu6aX0x\/qdmQn4l6hICEsYueVGVmsm\/6Inn5iDEAONf+J\/85CfD2hFxMhGoh4CPrJmS5h9g\/NlirXHHjh0mcayHqPJ0AwEJYze8pSptZFTEX1j869+T+vQh9896mFwRqJUAF\/iziYvPXHGnMfnnz59va9eutaGhIf3DCyCy1BGYkDCmrtc90CH\/YomPJnugy+piGwmw0auXppzbiFZVJYCAhDEBL0FNaD8B1hYzmUxD3wBtf6tVowiIQDsISBjbQbnFdWzYsMEGBweNjRJela8NLV261IPGXDkQ8BH1s88+i7dg+FmfZQqxENjDDxz6X7BgQdi9GsXATMSdd95pH\/jAB6LBehaBVBCQMKbgNfLNSnal7tmzJ\/QGgfyjP\/ojmz17trFpIgTqZxwB1sv0DdBxSEp6WE9csmSJbdq0qbCeyFGYzZs3h2+owrFkRgWKQBcTkDB28cvzpvOXF6LITkG20991110hil2q+osroCj5w2YlGHGOD2643fYN0JIda3Lg1q1bjVE0\/8hyTnCDX5OrUnEikAgCEsZEvIbGG4E4njp1qnAlXHQXYeOld3cJ7NplZ2Wp6VH+cmdHrxv+7u5t\/a2vxAlxdEa4vcypfsLK2S0EJIzd8qbUThEQgZQTUPeSQkDCmJQ3oXaIgAiIgAgkgoCEMRGvQY0QAREQARFICoFmCGNS+qJ2iIAIiIAIiEDDBCSMDSNUAbUS8LNx7HCMW\/T+TY6dcD4zGlZrXfH0lNXrF6zHmcgvAiIwnoCEcTwP+dpIgC3\/7HB00+XUbYSvqkRABMoSkDCWRaOIdhPgyAmHyblVpd11qz4REAERcAISRicht2sIcAVedAqWm1iijec7lEyXehqeCYum8WfCicd49vCUuOqGCIhAHQQkjHVAU5bWEGDt8Qc\/+IH5J7Pitfia48mTJ+348ePhMgOmY7mxxsWRMhh1rly5MsQzTctzqW9TIoSEc6tLuQsA4m2QXwREIP0EJIzpf8eJ7SGC5qM63OXLl9srr7xS8osXdAIx5E7Y7du3m99iww0sAwMDtnv37nCJ+rFjx4zLrVetWkWWYKVudHFR5D7Zxx9\/PKTTjwgkmoAa1zYCEsa2oVZFcQKM9hjRuSF806ZNs6985StB5OLpWXsknk9GReP4ggiC+eKLL9rRo0fttttus0p3xPIdwc9+9rOhiK997WsV04ZE+hEBEegpAhLGnnrdye4so8DHHnvMELlz586VDV\/fywAAAbxJREFUbCwjPD4ZVTJyLJCP6I49lnTeeuutEI5A8pWI4NGPCIiACIwRaIMwjtUkRwSaQODixYt27dq1opIYSSKsRDCyxC1nt99+u+3bt8\/4ksaBAweKvjVYLp\/CRUAEeoOAhLE33nNX9RKRi0+X0gFGgozyLl++jLdgfFyYkeT73ve+MI166dKlklOxhQxjD3xGCfP1ybFgOSIgAj1OQMLY438Aau1+K9OzIWbTpk3GLlIf\/UXrQ8TYWLNu3TojLXHsRmXU9+CDD4a1wgceeCBMxe7Zs4foYKRZsGCBsWM1BIz9sA758MMPF6Ufi5YjAiLQowQkjD364pPQ7fiuVIQPUWQXaan2IWR8Z5LjFaRlJ+v69euNG3PYnUoeLgk4dOiQDQ0NGfEYaRBK4kgTNcI43rFjx44i4Yym07MIiEDvEJAw9s67TkxPEaPoR5V9VypuVBRdCKNhdCL60VzKoTzC3Rhtci6R8rBoGsoijjSenvKiaTw8\/a56KAIiUIqAhLEUFYWJgAiIgAj0LAEJY8++enVcBEQgTQTUl+YRkDA2j6VKEgEREAERSAEBCWMKXqK6IAIiIAIi0DwC\/x8AAP\/\/KUshhAAAAAZJREFUAwAQKuEV+RnZgQAAAABJRU5ErkJggg==","height":302,"width":454}}
%---
%[output:85d28524]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\杨青宁\\202610\\English_FigS1D_UndelayedLearningCurve.svg\n","truncated":false}}
%---
%[output:6ab8c284]
%   data: {"dataType":"text","outputData":{"text":"\n=== FigS1D sigmoid (group level) ===\n","truncated":false}}
%---
%[output:41184eed]
%   data: {"dataType":"text","outputData":{"text":"Naive  : slope=0.3288 midpoint=3.7556 R^2=0.3241 (n=27 mice)\n","truncated":false}}
%---
%[output:13792177]
%   data: {"dataType":"text","outputData":{"text":"Transfer: slope=0.8858 midpoint=0.5995 R^2=0.2904 (n=22 mice)\n","truncated":false}}
%---
%[output:1a19636a]
%   data: {"dataType":"text","outputData":{"text":"LME Group P (blocks 1-7) = 3.17211e-07\n","truncated":false}}
%---
%[output:65991d64]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJcAAACXCAYAAAAYn8l5AAAPB0lEQVR4AeydS4hdSRnHazqPm046SedF5zFpCboQN+J6Bty4GhDdCu4GQZi1jBtFdCWuB93MQjciuBFhFiLowtm4cBBEEEaDHfMiL\/LO7SQ99u9Mf3cq51bdc+553VP3\/CFfV9VXX31V53\/+qapTp07dFefcJxJh0AYHINeuX\/0TAs0jIHI1j6k87iEwCHIdPHjQXbx40V26dCkox44dy+Ag3NjYyOJ1\/pw4ccJRZ8jHvn373IULFxx1hfJNRzuKbMy2TIgv6qX+MvZN2AyCXAbUjRs33OXLl6fkwYMHmQnhzZs3s3jVP6urq25tba1q8aUqNyhyLdWdS+BiRC7vJjF0MByZijhDnA2p9ErkofeHWNNT\/uzZs27\/\/v2FQx\/DE8OU+aEsvmOSt6csOt+e9IXdIdd8hmzM3mxn2Zht1VDkKkCOIY6hkuH06dOnDmK9fPlyMrQy1J4+fTqbYzGskn7x4oW7evWqIx1zv76+7u7evZv5wfb48ePReRjzt\/Pnz7vxeJzZ0xbiEBmSUIfZPHz4cGJD3LfBDqEMenxQN9eDvmkRuQoQhVDb29uZFTeFXsnSKMm\/cuWK83Xoi4QbT1nsKHv\/\/n139OhRRx3ofKFXw+b27dsT9b1797L4kSNHsvDQoUNZG3xCE8+TB\/8Qi\/8Avr\/MScN\/BkUuQLUhw0J6nVmYclMtn\/\/h\/G8\/depU1oOZvkr4+PHjV4o9e\/YsS3Pzs4j3Bx11eypHmrbYkEyIzrfJx1dWVtyZM2cyddvEopJBkYshiyHFl3lBxv7OnTvu8OHDk2WNIoICdF3xSR7zVWRDr0tZSMZcknibMihyNQUkw40RFKIxnDF01fFP78RNj\/lgThXK83urmI2Vg3z8B+M\/CG2mt7O8NkKRqyaqEI35U9GNzVdz4MCBV1Skd3Z2suHulYzdBASCfLvRyT\/So9Eom2ehDNmgDwlzvSdPnkQfIEJlquhErjlQ44by6O73UpBqdXXV5edQRW6Zt1nPgQ+eFiEpJMmXhcDY+MOvDWtWr9n4bcM\/yyiUzfvkgQC9b5+3qZsWueZAkBvPsMKQYg8EkI0nPXoDXBEy\/KD3yUCeLwxNJ0+ezOZt2JKGIL6NxfF37do1R09l9UJ0\/0nQbPy2UT\/LKOSZLwvR0VZIDclM32S40qSzvvoCSJYLAHNWG7m53AyzIY7O0oQQjJtqcy7CvA3l0EMYyvhi5emlfD\/5tuHD92vl8IuQ7\/slnrfhmrl28vBFfdiQRmifb4OuSRkEuZoETL7KIyBylcdKlnMiIHLNCZjMyyMgcpXHSpZzIpAyuea8VJl3jcBSkIvXGuvr69lWl64BVH1xBJaGXCwqQrL4pSqnawSWglxdg6b6yiEgcpXDSVYVEBC5KoCmIuUQELnK4dSYFS+KeefXmMMeO5qbXD2+lmSaZu\/7kmlwxYaKXBWBm7cYH3awo4E972y3IY5uXj8p2YtcHd0tdjGwm4ENgWzUI46uo+oXUo3I1SHszLXY8sL2GuIdVr2QqkSujmBnQx5bmdkByu5R4ug6qn4h1YhcHcHOJP769evZHnl6L+LoOqp+IdWIXAuBvU+VttcWkas9bAfvWeQaPAXaA0Dkag\/bwXsWuQZPgfYAELnaw3bwnkWuwVOgPQBErvawneV5EHmtkYutJbycRWLnFeQR5mwD7E3wkbdROh0EWiEXpODMgq2trewIRc5S4NAxzjeIQQOxOJyNsxh4qcun55xjgK9YGen7jUDj5IJAEIuzEHjNweVzTgHHJLLdhHRIIBFnXfFSl3xejUBKSEdakh4CrZALGOwYRuIIpIkRhRe4fLmTLwMpl31bCtjMK++9ddD9\/burhYLdvL6btG+NXNZr+Y2FQPRsvo64r+M4Ic25QCUum8dfc2Ul7qX9nMbJVaXJtv2EeVmdORfkrVJ\/amW27n\/ifPHbH9P7Nl3Fe0EuLpY52a1bt7ItKaRtzsX8ze\/ZyItJEbli5VLTv\/PBtvvyL55OhLRdwzsfjCf6r\/96bOqFhL0hF9t\/80Pp8+fPHYfQliVXfs62EERV6QSBxsllBAkRgt7J8ict2I1Aot1A\/5YMgdbIxS86+FjxpMgTo6+zOEMgcZ4aCU2Yi4V6NMtX2G8EWiEXa1wsgBpZWMNiPsTe8RAc9GaU4QBa6\/EgI59goSc\/VE66fiPQOLm4XNanWAC1ZQWI5k\/WseHrF4Q4Qhl+aGlzczM74dhW69GTP1R5c3PFFcnFY69N4Hnj4r5Ce5YxJgVajETJRQ9i5LCPNyEDvVCZ9kAKXuMgoRODOUkY8X0xbGJvQtrPH2L8vbdG7vffOjRTvv\/mZz+YQLzI\/t03PrNvE9MguRiS+Ak2ehteyVgD+CyKpYGyBMvK6c9gEQiSC\/IwrNlE29Bh7sMcCILRs5leoRAIITBFLkjD5Du2PBDTh5xLN2wEpshF78R6FMsAIWjY2UA+dqF86YSAITBFLjKYjPOEZ0sJ6BCGS4ZE8klLhMAsBILk4imNHzLiRTJrTfbDlRCOTXzkz3KqPCEAAkFykcGwB5FsWYAwtKSArWRQCJS+2Ci5SnuQoRCIIDBFLp4Wz5075\/LzLSvPGhiLq9iZTqEQCCEwRa6Qka+LPUX6NooLARCYkItXO2wv5t0eOxronUjnhQk+C6nMyXAgEQIxBCbk4j0fk3Y+B2PTXX4yT56JliJicErvIzAhlynpkYZw6p1dr8L2EJgiF1UxWY8NiwyT5GGDraQbBFKsJUgufgGMVzwMg+yKYI5FnKESPfuu6OFSvGC1uTsEpshFjzQajZytwvOiGh1NYpcEuyV4DURaIgRmITBFLjOGVMTpofwvcJjs+2lsQgIBGUKRsgeR+H54erVNir5e8XQQmCIXZGLos\/Us0lyO9V7EiwRi8YKbJ0+GU3o73lOW9cFCLeWL6lF+vxGYIhfNZUjk5kIGyEUvxtoXeYSzvsihDGWZp1GWMixdQFi265CeJZTnQ41ZNspLA4EguSDDeDx2TOy5DNvezBAHcVgTQx8SyIGe4ZPQBMLSI1k6FlIndUPOmI30aSAQJBdNh0AIcXognhQZ4ghJow+JkStkww5Xyw+VhXwI5A7ld65ThbUQCJKLiTTzplqeKxSmTuZnPJVWKO4gb5VyKtMOAlPkomfhJjHPaqfKsFeIRU6dXot240PSDwSmyMVwxiIpk2qI1kUz2d7DXI65XZ368vO8Or5Utj4CU+SCUBCLG84OCSbxeZn1+gdy0iz8EPrCE6Pl+3qeQKkPv1YXZGN7dZU1Mt+34otDYIpc3Hwm7UzeY0I+dqFmmx7C+PlM1Hli9HUWZyjM18XTIr+oqq3VhlJ64RS56l4C5IIYfMxBb4Q\/5lPMh2IHkWAjWT4EGicXENET8dRnwxxE42gAiEc+wusdhPirotSyINAKuQAHgtlQFxraWENDsA0JeTrJOYRMOrrWyJUOBGppWwiIXG0hK79uilwsIejTMjGjCQSmyFXk1LbiFNkpXwhMyMWTGwuYLJyyRmVPeuh80adlIk1ZBIxcjqcznu7Y4MdrFBZKSYeEJ8GyFchuuAhMyGUQsBalT8sMDYV1EMjIxSSeYZCVdIv7Q2E+ji12dSpW2eVHICMXvRXDIMOdxUPDoemwxW754dEV1kEgI1cdByorBGIIZORiiGOoyw9\/sTS2lIk5lV4IgEBGLoY4hjob9gh5amS7sf3+IToTbCmDA0lPEehBszJy9aAdasISIiByeTf17c+\/7372lY8LBTuvmKIRBEQuD5jTo8+5suIVUzSCQGvkYs3MHgjK7oPnkzYrQ8jW6Ei7W1HfHv\/XmfgVmM5CP0\/xOAKtkAti8YEFDwU8BLArteisCIhFM7FHeJDgZ\/G6JNj7\/37bfe+jL2RCnPYgv\/vfjzOd5f30n19DLSlAoHFysUQBsdhHb0+ULM7y5U\/srAj22rPH3v+0jI858AFRC65B2T1FoBVyca28\/CY0gSyxXoglD5Y3CM2eMJ9G129R63wEMnLR27AwyjzHhK039CgMTaazEFvK+I4sbnrrtUxPSO9k+aSLBDKG\/BSVU34\/EMjIxQ2k52CuU0awpUyblwCx+ChWn6O1iXK7vjNytVvF\/N7pMdm8yJyL4bSsB3rGMrZfPPZVVySndpclzBfxInuWMMxe4acI9I5cEGtjYyM7k5UNjJ82s9zfsuT6xus\/cO9+6Y8z5Zuv\/3BSKfEiey2sTuCaRBonlw2XobkVT4yWP2mBF6lDLNzkHyLQSRaHQGvkYh++f1nMoWYNcXWJ5deleD8QaIVczJX4hB\/CcJmsVTFkxSbn9HIsskK+eYdC5xxVSHqIQOPk4hpZNGVVniULli8g2qyzIlhchYgsvmLvCz4gH34laSHQCrmAAILZskbRWRG+rZWxsItlD9oraR6B1sjVfFPlMTUERK7U7lhC7RW5ErpZqTVV5ErtjiXU3srkSuga1dQFISByLQj4IVQrcg3hLi\/oGkWuBQE\/hGpFriHc5QVdo8i1IOCHUK3INYS7XOoamzcSuZrHVB73EBC59oBQ0DwCIlfzmMrjHgIi1x4QCppHQORqHlN53EOgV+Rin72\/C5X0XjsVJIhAb8gFkfhWkZ2n7ELlIBLSbH9OENeyTV5qu96Qi484+EDDzocgjqBf6juwxBfXC3LxAUbo6yC+FhqNRo78Jb4HS3tpvSEXCIc+mF1ZWRG5ACdB6QW5EsRNTS6BwFKRi+8e19bWXJGUwGVuE4b1onqr5M\/dkBIF5mkrtiVcBk2WglycQcE5Edw8vtwukj9s\/8j98t63G5UPxz93RfVWyf\/J30667\/zpRKPyq\/+cLt3W\/LEMQRZFlL0gl821QhP3nZ0dZ\/mRa3CQiy+6+fiWZYwi+ejjv7g\/\/+s3jUtRvVXyf\/vXq65p+fAfW65sWx49ehSDvVDfG3JBED7r91tMejweF5KLMpRHiEv6gUAvyAUUfNLPnInFVNKECHrSkvQQ6A25WDBlVd7OYCXkxBtbVE0PWrW4N+TiVkAwfy5AGr0kTQR6Ra40IVSrYwiIXDFkpK+NQHfkqt1UOUgNAZErtTuWUHtFroRuVmpNFblSu2MJtVfkSuhmpdZUkSu1O5ZQe0WuhG5Wz5pa2ByRqxAiGVRFQOSqipzKFSLwfwAAAP\/\/d6YksgAAAAZJREFUAwCgbbkQk7YvjQAAAABJRU5ErkJggg==","height":151,"width":151}}
%---
%[output:1d92987d]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\杨青宁\\202610\\English_FigS1D_UndelayedFirstBlockBar.svg\n","truncated":false}}
%---
