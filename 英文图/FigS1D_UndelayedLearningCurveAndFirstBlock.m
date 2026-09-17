%[text] `图3.1b：学习曲线（以会话序号为横轴，均值±SEM；两 cohort 非配对）。`
%
% LightWater learning curve: Naive vs Transfer
% - Naive 组：LightAudioBaseline(成像行为) + LAPureBehavior(纯行为)
% - Transfer 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
%
% 口径：
% - 每只鼠内按 DateTime 排序，将 LightWater 的每个 DateTime 视为一个“会话”；
%   若同一 DateTime 有多个 block，则对该会话内 block 的 Performance 取均值。
% - 之后按每鼠会话序号对齐，计算组均值±SEM。
% - 作图采用中文图31B 样式：errorbar 均值±SEM + 组水平 sigmoid 拟合曲线 +
%   横跨 block 1–7 的 LME 组效应 p 线（用户 2026-09-13 指定）。
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

naiveA = iLightWaterBlocksByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2)); %[output:7df7ef53]
naiveB = iLightWaterBlocksByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterBlocksByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2)); %[output:2a2e2127]

tranA  = iLightWaterBlocksByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2)); %[output:53474e81]
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
nMat = iComputeNByBlock(allBlocks, x, ["Naive","Transfer"]);

% --- 3b) Group-level sigmoid fits (midpoint unconstrained, same spec as Fig1B) ---
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

nBlocksPlot = height(meanMat);
xSummary = x;
xFit = linspace(1, nBlocksPlot, 200).';
hNaiveMean = errorbar(ax, xSummary, meanMat(:, 1), semMat(:, 1), 'o', ... %[output:5c266b7f]
	'Color', colorNaive, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorNaive, ... %[output:5c266b7f]
	'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none'); %[output:5c266b7f]
hTransferMean = errorbar(ax, xSummary, meanMat(:, 2), semMat(:, 2), 'o', ... %[output:5c266b7f]
	'Color', colorTransfer, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colorTransfer, ... %[output:5c266b7f]
	'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none'); %[output:5c266b7f]
hNaiveFit = plot(ax, xFit, iSigmoidFromParams(fitNaive.ParamRaw, xFit), '-', ... %[output:5c266b7f]
	'Color', colorNaive, 'LineWidth', 2.2); %[output:5c266b7f]
hTransferFit = plot(ax, xFit, iSigmoidFromParams(fitTransfer.ParamRaw, xFit), '-', ... %[output:5c266b7f]
	'Color', colorTransfer, 'LineWidth', 2.2); %[output:5c266b7f]

% --- 4b) LME p-line spanning blocks 1-7（同中文图31B；曲线本身画全部 block） ---
max7 = min(7, nBlocksPlot);
max7Naive = max(meanMat(1:max7, 1), [], 'omitnan');
max7Transfer = max(meanMat(1:max7, 2), [], 'omitnan');
yTop7 = max(max7Naive, max7Transfer);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off'); %[output:5c266b7f]
% 用户裁定（2026-09-13）：显著性只用星号，不再显示 p 值
if groupP7 < 0.001, starStr = '＊＊＊'; elseif groupP7 < 0.01, starStr = '＊＊'; elseif groupP7 < 0.05, starStr = '＊'; else, starStr = 'n.s.'; end
text(ax, 4, textY, starStr, ... %[output:5c266b7f]
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12, 'HandleVisibility', 'off'); %[output:5c266b7f]
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6)); %[output:5c266b7f]

% 扩展 y 上限避免 P 值标注遮挡
yl_ = ylim(ax);
ylim(ax, [yl_(1), yl_(2) + 0.12 * (yl_(2) - yl_(1))]); %[output:5c266b7f]

% 图例只区分 Naive/Transfer 两组（用户 2026-09-16：不再区分散点/拟合线）
lg = legend(ax, [hNaiveFit, hTransferFit], {'Naive', 'Transfer'}, ... %[output:5c266b7f]
	'Location', 'northeastoutside'); %[output:5c266b7f]
lg.Box = 'off'; %[output:5c266b7f]
lg.FontSize = 10; %[output:5c266b7f]
lg.AutoUpdate = 'off'; %[output:5c266b7f]

xlabel(ax, 'Block', 'FontSize', 12); %[output:5c266b7f]
ylabel(ax, 'Hit rate', 'FontSize', 12); %[output:5c266b7f]
xlim(ax, [0.5, nBlocksPlot + 0.5]); %[output:5c266b7f]
box(ax, 'off'); %[output:5c266b7f]
% title removed per user request

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

	DataCell = {naiveA, tranA}; % {Naive, Transfer}
	CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

	% --- Plot (transparent background)
	f2 = figure('Color','none', 'Name', 'English FigS1D Undelayed first-block performance'); %[output:30387fc7]
		f2.Units = 'centimeters';
		pos2 = f2.Position;
		pos2(3:4) = [4,4];
		f2.Position = pos2; %[output:30387fc7]
		f2.InvertHardcopy = 'off';
		f2.PaperUnits = 'centimeters';
		f2.PaperSize = [4,4];
		f2.PaperPositionMode = 'auto';

	tiledlayout(1,1,'TileSpacing','normal','Padding','normal'); %[output:30387fc7]
	nexttile; %[output:30387fc7]
	[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, CompareGroup, 'AsteriskThreshold', 0.05); %[output:30387fc7]
	ax2 = gca;
	ax2.FontSize = 12; %[output:30387fc7]
	ax2.LineWidth = 2; %[output:30387fc7]
	ax2.Color = 'none'; %[output:30387fc7]
	ax2.XAxis.Visible = 'off'; %[output:30387fc7]
	ax2.XTick = []; %[output:30387fc7]
	legend(ax2, 'off');

	% Asterisk font size
	if isfield(Optional2, 'MultiCompare') && ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
		for pt = Optional2.MultiCompare.PText(:)'
			pt.FontSize = 12; %[output:30387fc7]
		end
	end
	if isfield(Optional2, 'MultiCompare') && ismember('PLine', Optional2.MultiCompare.Properties.VariableNames)
		for pl = Optional2.MultiCompare.PLine(:)'
			pl.LineWidth = 2; %[output:30387fc7]
		end
	end

	% Bar styling – current named palette
	palette2 = [TransferLearning.NaiveColor; TransferLearning.TransferColor];
	colorNaive = palette2(1,:);
	colorTrans = palette2(2,:);
	if numel(Bars2) == 1
		Bars2.FaceColor = 'flat'; %[output:30387fc7]
		nBars = numel(Bars2.YData);
		reps = ceil(nBars/2);
		Bars2.CData = repmat([colorNaive; colorTrans], reps, 1); %[output:30387fc7]
		Bars2.CData = Bars2.CData(1:nBars, :); %[output:30387fc7]
		Bars2.BarWidth = 0.5; %[output:30387fc7]
		Bars2.LineWidth = 2; %[output:30387fc7]
		Bars2.EdgeColor = 'none'; %[output:30387fc7]
		Bars2.FaceAlpha = 1/3; %[output:30387fc7]
	else
		if numel(Bars2) >= 2
			Bars2(1).FaceColor = colorNaive;
			Bars2(2).FaceColor = colorTrans;
			Bars2(1).LineWidth = 2;
			Bars2(2).LineWidth = 2;
			Bars2(1).EdgeColor = 'none';
			Bars2(2).EdgeColor = 'none';
			Bars2(1).FaceAlpha = 1/3;
			Bars2(2).FaceAlpha = 1/3;
		else
			Bars2.FaceColor = colorNaive;
			Bars2.LineWidth = 2;
			Bars2.EdgeColor = 'none';
			Bars2.FaceAlpha = 1/3;
		end
	end
	for eb = ErrorBars2.Object(:)'
		eb.LineWidth = 2; %[output:30387fc7]
	end
	ax2.XLim = [0.5, 2.5]; %[output:30387fc7]

	ylabel(ax2, 'Hit rate', 'FontSize', 12); %[output:30387fc7]
	title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal'); %[output:30387fc7]
	box(ax2, 'off'); %[output:30387fc7]

	% Export SVG (transparent)
	svgPath2 = 'English_FigS1D_UndelayedFirstBlockBar.svg';
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar) %[output:30387fc7]
		ax2.Toolbar.Visible = 'off'; %[output:30387fc7]
	end
	svgPath2 = TransferLearning.ExportStandardFigure(f2, 2, svgPath2); %[output:30387fc7]
	fprintf('Wrote: %s\n', svgPath2); %[output:5fd930fe]
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
	p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); max(median(xObs), 1)];
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
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
	lower = 1 ./ (1 + exp(-p(1))); upper = 1; slope = exp(p(2)); midpoint = p(3);
end

function y = iLogit(x)
	x = min(max(x, 1e-6), 1 - 1e-6); y = log(x ./ (1 - x));
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:7df7ef53]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID           MustWarn        \n    ________    _______________________\n\n       26       \"最后一回合没拍到\"        \n       65       \"2次中断拍摄，无法对齐回合\"\n"}}
%---
%[output:2a2e2127]
%   data: {"dataType":"text","outputData":{"text":"FigS1D: LAInterspersed excluded 4 mice with AudioWater mixed into Naive phase.\n  Excluded mice: vtf0045, vtf0101, yqn0051, yqn0052\n","truncated":false}}
%---
%[output:53474e81]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID        MustWarn     \n    ________    _________________\n\n       14       \"拍错Z层，舍弃信号\" \n       51       \"水滴漏了，没有拍到\"\n      111       \"2\/5层亮度反相\"   \n"}}
%---
%[output:5c266b7f]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAcYAAAEuCAYAAAAUdbLGAAAQAElEQVR4AeydD6xU133nf\/Mg2Vc6dnAUg5\/BcYxYVYqLSdoiaME4WT0q4oiSPpJqeUGy5aQEbCq1gtL4n+KKNNkarAaJLhQ1SNa+8FYyerLr4iBBNwKbFC27SYHamzZvITH\/DJs22LyyaQO8zufMO8OdO3f+vJm5M3fufCP\/5vw\/95zPJXw5f2\/PuP4nAiIgAiIgAiJQINBj+p8IiIAIiIAIiECBgISxgCIFHnVBBERABESgYQISxoYRqgIREAEREIE0EZAwpultqi9pIqC+iIAItImAhLFN4PVYERABERCBZBKQMCbzvahVIiACaSKgvnQUAQljR70uNVYEREAERCBuAhLGuAmrfhEQAREQgY4iUEUYO6ovaqwIiIAIiIAINExAwtgwQlUgAiIgAiKQJgISxjS9zSp9UbIIiIAIiEB1AhLG6oyUQwREQAREoIsISBi76GWrq2kioL6IgAjERUDCGBdZ1SsCIiACItCRBCSMHfna1GgREIE0EVBfkkVAwpis96HWiIAIiIAItJmAhLHNL0CPFwEREAERSBaBxoQxWX1Ra0RABERABESgYQISxoYRqgIREAEREIE0EZAwpultNtYXlRYBERABEcgRkDDmIOg\/ERABERABEfAEJIyehFwRSBMB9UUERKBuAqkQxnPnztn27dsNt24SKigCIiACIiACOQKpEsZcf\/SfCIiACKSNgPrTYgKpEMYWM9PjREAEREAEUkxAwpjil6uuiYAIiIAITJ5ArMI4+eaohAiIgAiIgCewadMmmz9\/vp06dcpHFVziSDt06FAhrpqHvA899JBdvny5WtauTpcwdvXrV+dFQASSTuDq1av29a9\/3cbGxhpuan9\/vx0+fNhmzJjRcF1prkDCmOa329S+qTIREIF2ETh27JgNDQ216\/Fd91wJY9e9cnVYBESgkwgsWrTIli1bZsPDw1WnQP306pw5c8wb06e+v\/j9VCrTtIODgyUjUeIxX2bXrl2FuqiTOnxaWl0JY1rfrPolAhUIKKmzCHz5y192DX7++eedG\/WDKK5Zs8ZeeOEFO336tLPNmzfbxo0bI9coly9fbm+++aadOXOmUB1rj8ePHzfSiEQUd+7caa+88oqrD5f6iCc9rSZhTOubVb9EQARKCBx44oYl2UoaPBFx55132urVq21kZMTKjdiOHj1q999\/vy3KjTAnitnixYud99KlS84N\/jzwwAM2ffp0o5yPp378pCGSjFLXr19v8+bNI9q5hIkn3UWm8EfCmMKXqi6JgAhEE3jne+OWZItudT6W0SCit2XLltCUaj593bp1tnfvXstms8aIjmnPlStXGpt38jmKf9mAs2DBAjty5IibTmVzD37iSDt58qRduXKlIK6+NGI7Pj5uUWLr83S6K2Hs9Deo9ouACHQFAQTvySefdGIVNaXKVCrHNxBE0nfv3u2mQG+77bayfJgy9dOpTKniJ84XQFQRV+r0Rvjdd9\/1WVLpShhT+VrVKREQgSgCj\/7tVEuyRbU5GMeUJlOZBw8eNEZ0wbQXX3zRTaUSzxojRzOC6VF+pkz9dCpTqviJ83kRVdYVqS9oJ06ccNOqPl\/a3HYKY9pYqj8iIAIiEDsBplRZS3z22WcL06RMg164cMGWLl3qplJ9IxA7Rn0+HHaZMmXtcv\/+\/Yb5aVTyzZw5E6dkypQ1Tr+z1WVI4Y+EMYUvVV0SARFILwE\/pcpozveSuLvvvrvoSAdTq+woJc\/o6ChOpLFm+Pbbb7sdqsFpVD86ZRcqdVGYDTescSKmiCpxaTQJYxrfajv6pGeKgAi0jACixdnG4AOfe+45mzVrltuVynogI0uObtxzzz1WSRjvu+8+NwVLvuA0KnWzoYepW9YVqZPNP4gi8aSn1SSMaX2z6pcIiEDHE9i2bVthp2m4M6Sx7ufXEhk1siuVOIx1QNIOHz5s5KW8DwdHe74c+YLx5McQQerzRpj4NJuEMc1vV30TgfoIqJQIdDUBCWNXv351XgREQAREIExAwhgmorAIiIAIpImA+jJpAhLGSSNTAREQAREQgTQTkDCm+e2qbyIgAh1LgC9csBO0knH1W7s7SBt8Gznj2O72NOP5CRbGZnRPdYiACIhAZxJgJ6nfCcptNhyVGBgYcF+58PHt3iHK+UbOSnL9HG1i12tn0i5utYSxmIdCIiACIiACXU5AwtjlfwBa1X09RwREIB4CTGV+6UtfssHBQWNKkylYnsRozl8qTjwWnOrEz9Vu3\/rWt1w50jHiKY9x1ZyvlzTMp+Ny8J8r59auXeueT37K0QbyYrSBthCPcXvOihUr3Hcjo9LJ026TMLb7Dej5IiACItAgAS4V555UpjOZgkWI\/M03xGFRHy0+e\/asuyOVqVryMFXLlW+IFyKH4HHVHGkYU6b+ijimTblgnKvpiOdyAS4LQBT52PGxY8fctC+37yCgCKnv5nvvvWd\/9Vd\/ZeThIgJu8vFpSXAljEl4C2qDCHQUATU2aQS4zg1R8+3i8nAuGmdd0sdxJyr+4HcUETU+ZYWgkfbII4+4z1ohlNeuXbPz58\/b3LlzSXKGGFYSMgQZkeaCc3+LDmVo2549e9x3H11FuR+ulvN5csFE\/SdhTNTrUGNEQATiJHDly79oSbZ6+84dqdOmTSsUZ1OOH8Ex1cqUJaM2pj0LmXIePjPlv6KRCxb9h2jxtQ2+7ch0KiPIogwRAQSZOsN3rnI5OSKL2PpiQcH1cUlxJYxJeRNqhwiIgAg0iQAjN9b2EESEjalOP+0ZfkSlMNOyTMEy5YnYUR9TpZXKMD3LSJW83piSrVQmaWkSxhjeCP+ywuqtmrJYu8rX+1yVE4GkE5g650FLsjWL34svvui+mMGUKGuDTGfWWzejT+rAEMmRkRFjFFquPqZ1EVLyB+3w4cPGKLRcuSTFSxhjeBtDQ0OG1Vs1ZbF2la\/3uSonAkknkF17wJJszeDHP6rr+WhxLc9GJFkvLPcZK6ZHr1y5UvJxY4S01unYWtoRd57OFca4yTRYP384G6mi3eUbabvKioAItI8AG2nYSTo8PGzsLqUlTK1yEB9\/OVEjLWiU5TgHoubjqYfNNawZ+rigy8iU70Ru2LCh5NmPPfaY0bZg\/qT6JYwNvhkWlL\/\/\/e\/b+Ph4UU3vvPNOIUwa25fPnDlTiPOedpf37ZArAiKQHgL1frQ4SIBpz5deeskQWL9WyAYePlyMAAbzBv2sS7Jpx68zUoYjG5XKBMsnwS9hbPAtMGXxh3\/4h\/Y7v\/M79o\/\/+I+uth\/\/+MfO5Ye4Rx991B5\/\/HH74Q9\/SFSRtbt8UWPaF9CTRUAEKhBgpMUuU0QnnI3pTdLI49PwE+fX+DhigTCxzufr8GEE0JfjPKHPSxxplPH14PI80rBwfuIwnkFebzyLeMzXGYwjPkkmYWzwbfAvo5dfftl++Zd\/2bjNAQFkVxYjRgSTuI985CP2N3\/zN\/abv\/mbJU9rd\/mSBilCBERABLqcgISxCX8A+NfZV77yFXv11Vft4sWL9t3vftcZc\/nE\/fEf\/7HdfvvtZZ\/U7vJlG6YEEaiHgMqIQIcTkDA26QWyjviTn\/zE\/umf\/qlQIyPHH\/zgB3bjxo1CXDlPu8uXa5fiRUAERKDbCEgYm\/DG2UDzxBNPGIvS3E\/48MMPG8bFvowkf+\/3fs9drVTuUe0uX65dihcBEeh6Al0JQMLY4Gvfv3+\/\/dZv\/ZZxrdLrr79u3PDA\/YO9vb32u7\/7u8bC9ezZs+23f\/u3jYOx4ce1u3y4PQqLgAiIQLcTkDA2+CfgwQcfNM71MDL064j33ntvoVbinnrqKXeD\/Sc\/+clCvPe0u7xvh1wREAEREIE8gdQKY7578f8ifB\/84AdLHsRO1GDknXfeaXfccUcwyvnbXd41Qj8iIAIiIAIFAhLGAormeqZOndpQhe0u31DjVVgEREAEOpiAhDGGl8cBWKzeqimLtat8vc+Nr5xqFgEREIHWEZAwto61niQCIiACItABBCSMHfCS1EQRSBMB9UUEkk5Awpj0N6T2iYAIiIAItJRAVwjjc889Z\/fdd58sRgYt\/VOrh4mACCSEQDqb0RXC+IlPfMI4Zyj7Smwc0vl\/D\/VKBESgGwl0jTDy6SfZo\/boo4\/GYt34fx71WQREIJ0EukIYI16dokRABERABEQgkoCEMRKLIkVABERABLqVgISxW998mvqtvoiACIhAEwlIGJsIU1WJgAiIgAh0PgEJY+e\/Q\/VABNJEQH0RgbYTSLQwnjp1ylasWGGXL19uOyg1QAREQAREoDsIJFYYEcMNGzbYe++91x1vQr0UAREQgbQR6ND+JFIYDx06ZIsWLbKzZ892KNbuaPbNn\/7Y\/u1\/D9nPDv2Jc7uj1+qlCIhA2gkkThgRxbVr19rmzZudpf0FJKF\/9QgcZcZ2f8quvfSlnDB+zbnv\/elH7frp15PQJbVBBERABOomkDhh7O\/vt9OnT1sj3yOsm0ahYPd46hE4yiCIuFNmftR6+58yXMLEdw899VQERCCNBBInjI1APnfuXCPFu66sFzJchK1Wgbv507fdyDDzi3fa++Z9xnHDJUxdTK+6yNAPaeWMkeZkjefIhtw0dhSHf\/7rIYuyqLzl4nz5cunl4usp58uc23fE\/u4vbzobuzge+lOkoAjETyBVwjg4OGjbt2+Pn1oCn4Dg8JfUZNb7qgmcr8vXS5gRIS4Ixv\/l\/7lp1J8d+ppzCRNP+MqXf9HCxlRrORvbvdwma7SlFuvWPD1vfMmibDI8fPnJlCFvPeV8mX\/+6\/9mf\/fNnDDmbOwif6JkItBaAqkSxq1bt9qqVataSzABT0MUx2pY7yPf9dwaIEKH1SJw\/CWHIXYY5aijUrd5TqV0pYlAJQLvvy1jvXfkc7zx1Rt5j35FoIUEUiWMCxcutNmzZ7cQX\/sfhQghXLjB1hAmHhvLjcYYvTFaw08cVk3ggvWV9U95n2V6P2CWc8nTc8e9NnXOg87e\/6trrJwxbVvOpn3uL6xZll17wDrRbMW37e8u77c3Tuy3\/\/X2fhvtec25hLFKfRr7tW+7cpQP5iNMWdKD8UE\/aeThmfi9ESaecDC\/9xNP+v\/8v\/m20l6e9903833A7418lezah5+0\/\/zaVJs+J2OMGEf33+SP1oTJEYH4CaRKGOPHlbwn+OlQL0zBFiKOtYzwKJN5\/zTruePDlvmF6QRz\/nsL4uT\/8rv9j94ybPp\/+Rfn9uRE0G783MZ\/9q7hEs6u\/XZBiCqJW2\/\/01bOyolpPfFepNvl\/uwXltjf\/4\/FJUZ8pTb97BcetB\/9nyV2\/YMPWv\/eT9ivfe0h5xL+yZUlubTF7h8fUXWQjk3\/jaVFeQgTj0WVI4407EP\/aalNX\/ygM+J77nnQiP\/77yy2Y3t\/ww69kLeXN\/26DX3+112Y9Avncv3N5SEf7b\/8kyWuHH5v5Ktk1\/71w+7P4Ec+mXEu4ug8+hGBFhGQMLYIdLXHIGJMxdZv6gAAEABJREFUbYaN+HBZ4sjH6A9z6TmBcm7ED4LFX24IixcrxA6Rw0gf\/7drhsiO\/\/8rThQROPJjlMXIh\/EIXMpST2\/\/U05ECRNPetqMTSB+Q0jQJb5aX\/16WdCt9pf9O9\/Lbzrx4uCf4cOVymf78rl\/MJJbp5vYxEKbCZNCOu3mGYzGMKYssdHX8qMz2rpv4IZhB564YW8fybcnX2bccLFK7eBZUcbzvd31KxnDH8xHncH2kieYLn96CCS1JxLGBL0Z1vDC5pvnxZDpUIx8FadCJ6Y2ES4ECxdRROiwoND59HoEjnp6c6M\/6vRtTauLWISNv8TL9RfxeeOreaFhzeyuj2dqXjvzYoGYIRLeCPO8SmJBGvazn1phEwvtJkxZ2uQFDz82un\/csEr9oWzQaCPGs+Z+ulTgfF7yfHZkij36t1OdfXZkqnlb\/udTnJ86fH4E17eXssE0n0euCMRJINHCyFnGw4cP24wZM+JkkOi6EUBGhV4MEUjfYEZnCBOujyu4uREk8aQX4ip4yNctAlcBQ2RSvQKHyPCXPGtlrJkt\/69Tal47m\/vpHkMQEDNEwhthxAKjXaO59TeM0R4ju30D190oj+dGdqZKJPXyXNxgVsJ5ESsVOOKXPDPFcMkXVS7bl58WDaYF\/Uue6SkZOWZzI1\/qDOaTXwRaQSDRwtgKAHU9o8mFEDs2w1At5wn\/w+InjDOBhMNrhIgdozNGf36kx7Qn8eT3Rph4H5ZbP4F6Bc6Lk5\/+9C3wYer1cVFulFj4fPsmpjkZ7WGjuREfz6tUJ0KD6DG6w6gfQ3z8iI6RXD481Qndx77QY+QhnrLZCgJHGvkoHyxHvG93OZc89ZYtV6fiRaBeAhLGesk1sRxre0yLTvnQf7Qps3\/F\/vXon5s\/E8hjEDnEkOlQxBBRJEwaRjrxpPd2wXoffW6lITg8zwsafsyHy4lRNjfiId+PvpNfn8OP+TBCQ9gbI0CeNZobBTICRPCi6o6Kow6ehyF6GIKGSIVFb0ludIcxKsVoRzZC8Ij\/2Bd7jDzUX6vVW476GylLeZkINIOAhLEZFBus4\/rpI66GGz\/5obvFxAVyP+4YRM59\/69+3m1uYbozFyz7H+m9XbLeVxZChQSEx6\/VBVwjvkKxwhSfFzSf14f5y9zHBV0EhbQrp8ftvz983Q48fsO5hH0+L4L5adAbhosgjk6MAH2+oJvNCS71BsWP9TtGXBiih\/nnZyNEL1if\/CIgAsUEJIzFPFoaYgqV3aWsIwYfzAiQUWHPB2a56KlzljpXP40T8Gt1QbdarV5gELSXP3\/DEFVcwtkJkSpXB1OKpLE2+M73xw2XMFZNBH3dUQLISDAoftQnEwERaA4BCWNzOE66FkRxbPen3FVqwcI9t99tjBD\/9ch2u3HpLXd0gpFgMI\/89RHI5kZOiEy2L18eF+HK5uLzMeV\/yUcqYoio4hJGnHDDxih0NDcl6o8\/hNPD4WyuTbRtyTM9bm3PjwAlgGFSVcJKFoEmEJAwNgGirwKxy48A\/yQneLeM+HAedpn6eEaIfs3w5nsXcmW\/5kSRMowccWWNE0CsWMPza3S4CBdx1WpHuKLy+HjqRghZG2QkyOYYPyUaLkcZpkIRW4TPi+CS3NqfH52GyygsAiLQOgISxiazZlo0bP4RCGF4lIggsnu0t\/8pn63I7bkjfwtIUWQCAggBU4phIz4BzStpAu1CqBBDjk8gSriEEbOSAqGIbG5USRlvjO6w0dxaYFgIw0KbDY0GWQdEENnYgkCGHqWgCIhAnkDbfiWMTUTfc8e9hsAhdlTrw7jXT79u4VEieRkRko4RDhvx1JVEY0oxbLW0E5EKCyph4mspX08eBBDBQgw\/860phijhEiZtNDftWa1ehBCRG3snfxh+NCeK9J96g2XJQ94lE9OiCOESjQaDiOQXgUQTkDA2+fX09j\/txNFXS5jp1bHdy32UWzfMjxKfLsThIW\/YiE+iZQMjKN8+RlPE+3AlF0EJW6X8jaZ58fJHLHx9Pow4+rigi1iP5kQzPCoM5slGjAglhEFC8otAZxGQMMbwvoJVIopMrfq43tyUKWcOkzwS9G2t5jLqwny+oN\/HRbnZCVFlVEV6NicskxFVykzWeAZl\/BEL\/JgPB6c0o8TQCytlMOqj\/UyJakQIEZkIpIeAhDHGd8maohdFhBBR7M2NKGN8ZMdUjYjOfTj\/xy+LUH4x74+rA35TC7tJOWrB1C0u4WxOmLHwyDAohqRjCHhQDIOCGlfbVa8IiEBrCcT7t1Fr+5KIpyGGrCcGG4MospYoUQxSab1\/SW7ND3FDDJnGxaUV2Zww+12kYTG861cyhSvRGBki6BJDqMlEIL0EJIxNfLeI4tjuT5m\/99RX3ZubPk3jWUQ\/5ej7ORmXsl6E8E+mbCN5\/Sg1WIdvh4\/L5kaQjAwRQkaHjDZ9mlwREIH0E5AwNukdI4oIIm6hyolPP\/np1EJ8CjyIGRtSOALhu7Nv4Lr7Tp8Pl3N9WUZt5GHjS61lyV+v8Rz\/zHAdt8Qw\/xkkRobhPAp3PgH1QARqISBhjKCEuOU3zdw6pE+Y+IjsLspfBO4CuR+mT2\/fdML4Wgbl+EpGLjoV\/yFsCCJCw3EHRle4hKudCWykbD3weJ5fO0TIg3UghsENNIhhNjetGswjvwiIQPcRkDCWeeeM8sJWJquLvj5xETgBRJE1Rdz3zfsMUYY4Ok8KfhBAph8RQ84CIii4hElDiMp1k\/R6y1InQsfGmbART7o3wuTZN3DDEHGe6dOyganSJc9Mcd899GlyRUAEOoVAfO2UMEawRdBYF8QlmQP7wTBxQUP0EFEXl5s+Ja9fU\/z5qZdddJouAvci488Aug7mfnwY8csFI\/9rpKyvkOnQsPk0BJFRK4JIHh+PGIZHhz5NrgiIgAgECUgYgzQC\/t7AsYre\/qesNxAOZHMjQTbcFOJu\/Ny4AJyp16t\/tsDdeYrAeqEs5OtgDyJD8\/0ZQPyYD1fatdlIWZ6RzU11MnXrn4FLmDSmShHE0f23vn+Y1egQNDIREIFJEJAwTgJWOCsjxeCGG0aWiCBfxWAEiUuYW24CZTveyy5NBInjDpwFZMoSlzBCRFq5TjZS1tfJ1O1dH8\/4oPE5JwTRj0ZJoB1LnukxdpaSnziZCIiACNRCQMJYC6UyedhQc\/306y4VAWRdkVttcIkkjjAu4TQZooP4IIZMWeIS5nhDtX42UjZcN2KI+XjfBgQREfbxckVABESgVgISxjKkGA36JC9+PoxLHKNC\/AhfcFSYpmlT+hdl2dyUJuITFELCxEflD8aRh7x+CpQRJmHig\/mi\/KwhMmWKGAfTg+uH1BdMi9WvykVABFJHQMIY8UoRRdYNcUlmupQvYyCGhIknDj\/GCBFxxN9phtAwFRo24mvpSyMiNJmytMdvqgmOEKkDcV6i3aW1vC7lEQERqIFA7MK4a9cumzNnjrP58+fbqVOnqjYrWIayhw4dqlqmWRm86OFyBrG3\/6nCWUQvhowUSeeZrCt2+giR0VfY6FsSDEFEtFlDDG6q8W3L9pmOW3gYchsloPIi4AjEKowI3PDwsB07dsxOnz5t69evtw0bNtjly5fdw6N+EMGdO3faK6+84srs3r3b1q5da8RH5W92nD+ojyje9gfH3W5UXMKI4dju5cbaIs9llMhoET9GOrtRfboP45KeRMvmpkSZ0sz25VvHlGQ+fGtzSz6ltb9BQUS0yz0dsdxX44075epQvAiIgAgECcQmjIgforh69WqbMWOGe+aaNWts1qxZNjIy4sLhn7GxMduzZ48tW7bM5s2b55L7+\/ttYGDADhw44MJx\/1yfOKj\/vnn5g\/n+eT58PbTZxqd7l9EkFgx7f1Jddm1mcwJJ+7hLlDD+SuaFi9Gcz4efeB8u55KHvKOv3XRZfBiXiNGJ7x8GBTGbE24Em6lT8nCZAGHcsYtmTLMSLxMBERABR6CBn9iE8dKlSzY+Pm6LFy8uNC+bzdrSpUvtyJEjhggWEhLkYRRIc\/zBfPxYOMz0KUaaN8oy9Ro24n2eNLkIF+b7FPT7uHIueUcnzhsibIRx2VjDTTX4KesFkc05iCLri4ghN+0g4LiEyT+aE1TKyERABESgEQKxCmMmk7GZM2eWtO\/8+fN27dq1kniE87HHHrODBw8W1iKZQmWEuXz58pL8cUT4NUPOIHJAn6lRXML+eQhdcArVx+P29j\/tpl+DLvFps2xuhMmILWzEV+sreYLlmL7N5kaEiCLCR3nC5EEQEUDifJq\/YYc4zIcRR8IyERABEWiEQKQwMg360EMPuQ0zg4ODbnS3adMmY82wkYfVUpap06GhIWPalY03GzdudOuNxNdSvhl5ED3EDzFkWhQ3WC\/pwXBz\/Z1TG4IVtlpb78shgAheUNQYGbLTlDzB+shL2N+wgx\/zYcoRlomACIhAIwRKhJERGmt8O3bssM2bNxfqxj88PBy7OCLAbNBh1MiGHS+StYjyuXPnCu1txIMoBg\/mE\/b1+RGlD8utjwDriYwQo6ZNEcVsbkQarpkD+4gflwlw0w7rlLiEs7kRJ2nhMgqLgAiIwGQJFAkj635sfmH3qN\/84itkAw0baRBHRpQ+vpkuRzkQxGeffbawYYd20J5ansvodvv27c1skqvL7ypFIHv7n3JxafpBpHx\/GL15fxwuz0LQ9g3cMP8sRC08bVru2Uue6THyI4asS+ISRkzLlWlnvJ4tAiLQeQSKhJF1P9b\/5s6dG9mTcvFRmVlbZPMNm3DC6exMnTZtWjjahT\/wgQ+UrEvy3CtXrlhUXa7QxM\/WrVtt1apVE6HmO+\/\/1c8b4tj8mttXI0LFyM2LFGKzL6bjDzyLESLP8D32ohaeNvXpYTebG0my7si6JGm4hIknLBMBERCBRgkUCSNihWiNjo5G1suRCdLJF5khEIkwZjIZO3r0aCGWESk7UtmZykabQkLA8+6770YK4PTp00sEM1DMeRcuXGizZ892\/kZ+GCGy6QY3WA\/TqMFwp\/u9UI1dNGNnJ6M2XMLNPP7AcyqNEusRtexd+XOW3u30d6H2dwIBtbFbCBQJI2LFrlAO2DOtGYTAGh+7Q0knXzAtyu+nXoN1sV7IiJRziVFlmDZlfXPLli2FSwBoBxtwmMalzqhyccSx6SaOepNUJwLISBEx5NgDozZcwqQ14\/gDotjoKDFJzNQWERCB9BMoEka6y+5P1vnYAPP888+7W2seeOABQ+C4jYZ08tVi69atc7fdrFy50u1wpQ429QQFjs02mK9v27ZthgguWrTIlaEsa4zU5fPE7TJdGhwdEmZtETfuZ7eyfkSR5\/njDvgxH0YcCddrzR4l1tsOlRMBERCBMIFK4RJhJDPCdfjwYXclGztDsRMnThRuoyFPrYagUR6LqgMhxIL1BctQjnAwvRX+4DQqxzN6+59uxWPregajMkQobMRXqjDbl0\/1xx3yITMfrneXJ891bflm\/mYb6ocHV50AABAASURBVOVZbJBhVEpYJgIiIAJJJRApjEltbKvaxV2n1yeufuN2G6xVz673OWxoCVu1uuI4\/sAolM08tIXnI4isXTZrg4wXXT5OTP24iDDxhGUiIAIi0CiBImHkGMaKFSsKt86EK+eMIwf\/yRdOS0uYkSLCSH+YOk3cSJGGhSzblzHEx4\/wcAkTH8paEmzW8QeECYFCFP0UbLbPLI5RIqKLANMZXML4ZSIgAiLQDAJFwlitwnK7VauV66R0RooYbWakiOFPujFFedfH8zs1cQnX0uZsTlTzo7l8bgQ1H87XlY+t\/IsoIohBgaqnnspPyafSXuoOG\/H5HPoVAREQgcYIOGFk8wvXr7Hh5c033zQ2vBAOG5tx2BjDGmRjj01m6fBoMbgBJ5ktbl6rvLAw2pxMrYzY9g3csOAo0YnWF90frclUVXNeRD9sNRdOVka1RgREIIEE3N9ebH5hkwvfTbz\/\/vvd3aSEo6wdG2FaxY2RIsbzGCli+GWlBBgl+qlTn5qNaerU1y9XBERABFpBwAmjfxAjwVdffbWu3ae+jk52g2uL3TRanOw7QxTDZxMZJU52Cnayz1V+EUg0ATUuNQSKhJFesbGGDTbhaVQfJo085E2TMVLE6BMjRQy\/rJgAosh6IlOopDBKRBSZ2iQsEwEREIFOJ1AijKwjcu3byZMn3dc1uKWGKVUO9992220WvOC70zsfbD9XwPmwRoueRLHL1Om+0HpiHLtOi5+qkAiIgAi0lkCP2a0HMhI8fvy4+btMubz7woULxh2nXNfGDTR8fYPwrVKd72OkiNETRooY\/k4yRnJj74y7JnvXBZrwQ92IYit2nTahuapCBERABBoiUDJipDYEEZeLwK9evWp8dYPw4sWLLRgmLg0WHC12wrnFMHOEi+nN0f15YcTdV+MXMiiL6OFS7+hrNy0YJp66vShq6hRKMhEQgTQTKBJGvprBNKo\/r4gw0vlqn3siT6caRzQ6ebSIcLERhuMSXP7Neh8u4Vq\/kIHokZ93iKgSxk\/diKJPQxQ1dQoZmQiIQJoJFAkjX81gGnV4eNh93YJdqr\/0S79U+HQUn5BinREBTQuU4Fc0OnO0aMZGGMSQL2OwCQaX8NhFs9H9t+4rjXpn2b6MuzUHQQ3aaG70uS9iPZH8UfUoTgREQATSQqBIGOkU5xQXLFhgbMIhvHnzZhvOCSW7UnG\/8Y1vGAJKWqcbo8XgEY1OXFtEFHkP\/osY+DEfHsuJI+FKhpgGjbx+1IgfwdRRDEi02vQ8ERCBdhAoEUYawYF\/DD+jRv+lDVzCxKfBvCjSl97+p3DaZkxbsrYXNuIrNSrbl0\/1X8TIh6yuL2TwLPf8b+ZHmdSNKCKavl65IiACIpB2AkXCyG7TwcFB46PEae84o0U\/jcpl4Uk4osEoLWzV3kOzvpCBKLKeyPN5JqI49+EekyhCQyYCjRNQDZ1DoEgY2X16\/vx587tSO6cbk2\/p9YnPSlEyCVOo2Ym1vrmfzl\/enc2NBBmtZXPxtLGSNfqFDC+Kfto1m3u2NtlUIq40ERCBNBMoEkamSTnAv2XLFrf5Js0d99OoSRktwprRGV\/GwM9l3oTxV7NsTjxZA\/SiikuY+GplEUVtsqlGSekiIALdRKBIGDngjyiePXvW+NIGG27mzJljQTcNV8IxWsR40T13fNiSMGKkLY1a9q6J0eaEW62+0f03DVH0+SYjqL6MXBEQARFIG4EiYWTEyAYbroArZ6STr5NBdPqB\/mawZ5MN5x99XUzbLnlmig\/KFQEREIGuJVAkjN1AgU03t0aL96ZmtFjjuzOmThFFv8mGcohirdO25JeJgAiIQJoJdJ0welHkpbb7iAZtaKUhiqP7x82LYrbP8of7v9h1fwxaiV3PEgER6DACXfU3IqPFJG66acWfGUSRqdOgKDJ1qpFiK+jH9AxVKwIiEAuBLhPGt82PGNOy4YY\/FYge06PvfH+coOESJp4IXM4o+ltyGClyHIOdr6TLREAEREAEbhGIXRi5LMDvap0\/f76dOnXq1tPL+A4dOlS0E5Y6ymSdVHRw000SDvSHG4+AIWrE+zOF+GsxRoJe+HAJU446EUVfnxfFbF9+Byt5ZCIgAm0noAYkiECRMHJcY8WKFWXFC8GazHENBG14eNiOHTtm7HLle44bNmyoeEaSZ6xdu9Z2797tyrzyyiu2c+fOhm\/jYRo1OFpM2ojRCxhrgPz5QNz21fjpKETObaD5Qk9+zXDCpR6JIhRkIiACIlA7gSJhrFbMf46qWj7SEVlEcfXq1eaPd6xZs8b4rNXIyAhZSowr6fgQMheX9\/f3u3T\/geQjR464Dya7yBp+EEJGiN6uvfSlQqne\/qcL\/iR4EEXW\/8YumvFVDEQOl3Ctn45irTBonEkMi2Kth\/6TwERtEAEREIF2EXDCuGnTJjd1yaH+N99801auXOnCfgrUu3xxIyh0NLqcXbp0ycbHx23x4sWFLHyVg89alRO5M2fO2Llz54rKUJgvfuzdu3fSX\/XgLlRvfrTYc0fyjmgggIwQEUM+GYXA4RImbXR\/\/lJvWNRiCO2+wCejEElEsZayyiMCIiAC3U7ACSNf0mCqkynP+++\/35i+JBxliFQt0BDGTCZjM2fOLMnOfazcyxpO8GUymYwxZesFmSnZcN5qYQSwt\/+pknOKSZtCpR+IIq7\/VBR+zIcRR8K1GCKKKPq8jD7ZferDckVABERABCoTcMLoszDl+eqrrxrTlz6ulS5TtVxH98QTT9hLL7006TVGRpvB9vbmpkwRyGBcnJtuGKmxGzRsxAfbEPZn+\/IxjX46ClFkSjZfWz1nFH1JuSIgAiLQvQR6WAtkdMaozPv9SC3KJS\/54kJ222232Y4dOwrrkog0m3aGh4crbtqhPYODg7Z9+3a8kcZoEYtMbFIku0HDVq3qZnw6CjGWKFYjrXQREAERqE6gh1Ei958yRer9UVOoPo685KtedX05pk+fXjL9ymewrly5Yky1Vqp169attmrVqrJZ4hwt8tBsX8btCmVNLx82FyaecCVb8kyPZfvMrpzO30yDS5jzhpXKkYYoIsb4MaZPWafEL+teAuq5CIhAfQSKplLrqyK6FGuLbL6JEjN2pk6bNq2kIAJYEjmJiIULF9rs2bMLJdiZivmIuIWR5yBICBN+jDBuNcvmRJUNMr4sh+8JE1+pbFAUszlhpXytz6xUr9JEQAREoFsJ9DAtyvRo1LRpVBx5KVMNGMKYyWTs6NGjhawcx2BHKjtT2aFaSJjwPPDAA8538uRJ5\/of1h6nR4wkfXqUiyCO7f5U4aYb8rz3px8tChOXNEPcaJN38ZezsCjOfbjHJIrlaCleBDqZgNreSgKFqVQ\/VYrL7tR77rmncMieOG+1TqUy3crRDg7n+9tuhoaGjB2pAwMDkX30ZbZs2VJYT+TA\/2SOiVAxosi5RdwpMz9qvf1PGS5h4snT6SZR7PQ3qPaLgAgklUBsU6l0mHVLNs74c5GIZHBjDXk4Q4nhxyjz7LPPGmcqGbH6W3CIJ70Wu\/nT\/J2oiOFtf3A8J4xPGy5hxNFfJF5LXUnLww7XsCgueWaKRopJe1FqjwiIQMcSiFUYzcwQND\/aPHHiRMlREM5QYkGC3Hrjy+ASDqZX818\/fcRled+8zzjX\/\/gw4ujjOslFFEdDn41CFFmP7KR+qK0iIAIikGQCsQtjOzrvzy7+\/NTLRY\/34alzlhbFd0JAotgJb0ltFAERSAOBVAoju085r3jj0lt29c8WGPel4hJGNEnrpJcXJYoc42j5SLGToKmtIiACIlAngVQKIyymfe4vDBFEDLkvFZdwdu23SY7NEDF\/xdvYxcYfQ33h6VNEMdunz0Y1Tlc1iIAIiEApgdQKIyJ4+x+9VbgrlVEkYeJLMTQnBhHjixbBG2j21fjpKMqyqWb0tfzHhhFVwhzcx2hhts9MoggJWRMIqAoREIEyBFIrjL6\/Xgjjnj5F2BBEBI2vYnDQHpdwrZ+OQgD9aBOXMKNF+iJRhIJMBERABOInEHnAn6MSXObNUQmOTASt1gP+8Tc9WU9AABEzxJBPRnHQHpcwaaNVPh2VzU2NIqYYV8plc6ND30P8Gil6GnJFQARKCCiiqQQiD\/hzRKKc1XrAv6mt7IDKEEWa6T8VhR\/zYcSRcCVDTBFF8mLklShCQSYCIiACrSOQ+qnUVqFEwHhWI5+O8tOxXmSpUyNFqMpEQAREoHUE2iyM8XWUQ\/wc07h++nX3EFzCxLuIJv80+ukoiWKTX4iqEwEREIE6CaRWGOHBMQ0vhFwDR5j4uGxJnZ+OkijG9UZUrwiIgAhMnkBqhZHdqFweHjbiJ4+pthLZvozxqSgEkhLZPnPhbC6ecJSlSRSj+qc4ERABEeg0AqkVRl5Eb\/\/T7gLxoEt83FbrjTQSxbjfhOoXAREQgckTSLUwTh5H60ogilwGoI02rWOuJ02GgPKKQPcSkDC24d17UdSRjDbA1yNFQAREoAoBCWMVQM1Olig2m6jqEwERqEZA6ZMjIGGcHK+GckeJIpt1Km3OaeiBKiwCIiACIjBpAhLGSSOrr0A5UayvNpUSAREQARGIi0CyhTGuXre4Xolii4HrcSIgAiLQAAEJYwPwwkURQD4VNbq\/+NNR7D4NbrRh+jRcVmEREAEREIFkEJAwNvk98KkozFeLX6LoaOhHBERABDqCgISxia+JTTR8NgrjKxnBqrMTt+AE4+QXAREQARFIHgEJY5Pfif90lD+4T\/XchKPpU0jIUkNAHRGBFBOIXRh37dplc+bMcTZ\/\/nw7derUpHBu2rTJBgcHbWxsbFLl2pWZdcbgmiIjRz4d1a726LkiIAIiIAKTIxCrMCKKw8PDduzYMePDx+vXr7cNGzbY5cuXa2rloUOHbGRkpKa8SciEKO4buGFjF\/OtQRSXPDMlH9CvCIiACCSTgFoVIhCbMCJ+wzlRXL16tc2YMcM9ds2aNTZr1qyaxI7yW7ZsceU64ceLom+rRNGTkCsCIiACnUUgNmG8dOmSjY+P2+LFiwtEstmsLV261I4cOVJ1avT555+3BQsW2MDAQKF8Uj1hUWTzjUaKSX1bapcIiIAIVCYQqzBmMhmbOXNmSQvOnz9v165dK4n3EUyhHjx40B555BEfFekmIXJ0\/01j+tS3BVFkA44PyxUBERABEegsArEJY70Y2GSzZ88eYz1y3rx59VbTknKI4htfvVl4lkSxgEIeERABEehYAokTxqGhIQeT9UjnmcTPuXPnJpG7fFamRrnBJmzE+1KkSRQ9jWa4qkMEREAEkkEgUcLIUY69e\/fak08+aaxHThYRxzq2b98+2WKR+bmxJmw+I6JImg9rpOhJyBUBERCBzicQmzCytsjmGzbhhDGxM3XatGnhaDt69Kgx6lu5cqU798j5R45rcNyDTTwIZ0mhQMTWrVtt1apVgZj6vNm+jCF22b58eXaY5sMZC4oi6cRrTTHdwFm2AAAQAElEQVTPSb8i4AnIFYFOJhCrMGYyGSd2HhDrh+xIZWdq1Ihw3bp17rwjZx69sSt10aJFrp5qa44LFy602bNn+8c15AbFzotfWBTnPtxjwXwNPVCFRUAEREAEEkEgNmHk7CJnGHfu3Fm47Yb1Q3akInaJ6H2NjRi7aCUjRYlijfCUTQREoMMJdF\/zYxNGUDICZHepnxpFJHfs2FE48E8ernzD8CfVRl+7aX5NkelTzihqpJjUt6V2iYAIiEBjBGIVRpqGOPpp0RMnTlh4OnTbtm2GkTfKSGNDTtTUa1T+OOJGJ76viChy7ymXgsfxHNUpAiIgAiLQfgKxC2Mbu9jQozmawRSqr8SLYrYv46PkioAIiIAIpJCAhDHipSKKfCHDJ2X7zBgpZiWKHolcERABEUgtAQlj6NV6UQyOFtmVKlEMgWp1UM8TAREQgRYRkDAGQI9O3HsaFEWSueFm38B1e+d74wRlIiACIiACKSYgYZx4uZxRRAAngs6ZPifjDvrjIpZvfPWGi9ePCIhAQwRUWAQSTUDCmHs9iKI\/jpELuv8Qw898a4o7wI9LGHFkVOky6EcEREAERCCVBLpaGFlPDIpits8M401\/5JPFu099GHEkXSYCIiACImBmKYTQtcKIKDJ16keKCCKbbDDe84++U7ye6MM6wwgdmQiIgAikl0BXCiOiyHEMv5kGUeQ4xtxP9xiG+F05PW4vf\/6GMaLEJUw+0tL7x0E9EwEREAER6DphRBT3DdywsYv5l4\/YIYrZwBnFJc\/0uClVxJARJW42N81Kvnwp\/YqACIiACKSVQFcJI6M\/RNG\/TD4n9dmRqTkRLF5PzOZEMh+fz8n0aj5cnC+fql8REAEREIE0EehJU2fK9YVRIqLI6M\/nQeyWPDPFByu6CGjFDEpsOwE1QAREQASaRSD1wuhE8ZvFX8dAFPV1jGb9EVI9IiACIpAuAqkXRl7XaODrGIwSJYpQkYlAUgmoXSLQXgKpF0bWC9k0k53YPKNdpe39A6eni4AIiEDSCaReGHkBiKE2z0BCJgIiIAKtJdCJT+sKYZzsi3Hrkn950\/wtN0zFsnmH+MnWpfwiIAIiIAKdRUDCWOZ9BXew4sfKZFW0CIiACIhAigikVhgZ3THKCxvx1d5fti9jH\/tCj\/uyhtvBOuEnvlpZpYuACIiACHQ2gdQKI6+FUV7YiK\/F2LkatlrKKY8IiIAIiEBnE0itMDK6Y7THxhteES5h4gnLuoqAOisCIiACNRNIrTBCgBFftg+f2dyHM+7bivmQfkVABERABEQgmkCqhTG6y4oVARHoaAJqvAjETCB2Ydy1a5fNmTPH2fz58+3UqVMVuzQ2NmaDg4Muvy936NChimWUKAIiIAIiIALNIhCrMCKKw8PDduzYMTt9+rStX7\/eNmzYYJcvX45sP6K4du1al3by5ElXZvfu3UZcPeLIDtSxi666wpnEfEi\/IiACIiACCSCQyCbEJoyI33BOFFevXm0zZsxwnV+zZo3NmjXLRkZGXDj8c+bMGTt37pw9+eSTls1mXXJ\/f78NDAzYnj17DOF0kTX8IIoHnrhh73xv3OVmd+q+geuFsIvUjwiIgAiIgAiECMQmjJcuXbLx8XFbvHhx4ZGI3dKlS+3IkSORIjdv3jyXhlsolPPMnTs391v7f4jiG1\/N31wzfU7GnUfEHcuNHt\/46o3aK1JOERABERCBriMQqzBmMhmbOXNmCdTz58\/btWvXSuKjIhglIqR33313YRQZlS8YhwAyUkQMP\/OtKW43Ki5h0kb33wxmr8uvQiIgAiIgAukkEJswNgsX65PY8uXLq1bJNCyZEEXcj3wyg1MwH0YcC5HyiIAIiIAIiECAQKKFkR2sGzdudGuMrDUG2h3pZTfr9u3bzZ9d\/NF38uuLPrMPc9jfx8kVATMxEAEREIFbBBIrjIgim3WWLVtm27Ztu9XiCr6tW7faqlWrbO6newzxu3J63F7+\/A3jvlRcwogmaRWqUZIIiIAIiEAXE4hNGFlbZPMNm3DCfNmZOm3atHB0IVyPKFJ44cKFNnv2bLy25JkeN3JEDNmRioso8tFil0E\/IiACqSSgTolAowRiFcZMJmNHjx4ttNFvpGFnKjtUCwkBT72iGKjCebN9GfvsyFQ3ciRi7qfzYeIJy0RABERABEQgikBswsjZRc4w7ty5s3DbzdDQkLEjlXOJUY3h7CMXAExm+jSqnmBcti8fuuvjxRtx8rH6FQEREAERSC6B9rQsNmGkO+vWrXO33axcudJd8YZI7tixo3DgnzybNm0yDD8H\/8+ePesuAPDXwXn3oYceKntjDmVlIiACIiACItAMArEKIw1EHLkODjtx4oSFD++zsQYL5yV\/0A4fPlwkqOSXiYAIiIAIiECzCcQujM1ucK31cfsNu1H9mcZ3vj9uhImvtY4G8qmoCIiACIhAhxJIrTDyPtiN6g\/zj+7PCeM3bxItEwEREAEREIGyBFIrjNm+jLsj9WNf6ClyiS9LQwkiEEVAcSIgAl1FILXCyFv82Bdzohgy4mUiIAIiIAIiUI5AqoWxXKcVLwIi0LUE1HERqEpAwlgVkTKIgAiIgAh0EwEJYze9bfVVBERABNJEIKa+SBhjAqtqRUAEREAEOpOAhLEz35taLQIiIAIiEBMBCWNMYCtXq1QREAEREIGkEpAwJvXNqF0iIAIiIAJtISBhbAt2PTRNBNQXERCBdBGQMKbrfao3IiACIiACDRKQMDYIUMVFQATSREB9EQEzCaP+FIiACIiACIhAgICEMQBDXhEQAREQgfQQqLcnEsZ6yamcCIiACIhAKglIGFP5WtUpERABERCBeglIGOslF2c51S0CIiACItA2AhLGtqHXg0VABERABJJIQMKYxLeiNqWJgPoiAiLQYQQkjB32wtRcERABERCBeAkkUhgPHTpkc+bMKRjheDGodhEQARGogYCydAWBxAkjIrhx40Z75ZVX7PTp07Z7924jfOrUqa54IeqkCIiACIhAewkkShjHxsZsz549tmzZMps3b54j09\/f78IvvviiC+tHBERABERABJpAoGwViRLGa9eu2fnz52358uVFDSZ8\/Phxu3z5clG8AiIgAiIgAiLQbAKJEsZLly7Z+Pi4zZw5s6SfV65cMdJLEhRRIHDu3Dnbvn274RYi5SkhAB9xKsFSEiFOJUgU0SUEEiWMjTLn\/8jdYJX66P\/Cr5RHabf+ASEW59w\/pMpxSNqfp0b\/jlB5EaiFQCqEcfbs2bZw4UIbHBy0pUuXdq3Rf146bjdzqNZ3+IhT9f+fJJETQs27k4lAnARSI4xbt261vXv3ysSgw\/4M6M\/sZP5\/u2rVqjj\/PlTdIuAIJEoYWVvMZDKRa4nTp0+PXHt0vcj9MGpctGiRycRAfwbS+2eA\/5\/n\/u+u\/0QgVgKJEsZp06bZrFmz7MCBA0WdJrxgwQKbMWNGUbwCIiACIpAkAmpLOggkShiz2aw99thjNjIyYhz0BzHuwYMH7ZFHHiEoEwEREAEREIFYCSRKGOkpB\/q57Wbt2rXuSjjcF154oXDgnzwyERABERABEYiLQF4Y46q9znoRR66D80a4zqpUTAREQAREQAQmRSCRwjipHiizCIiACIiACDSRgISxiTDbVdWuXbvctPPEF0mc\/6GHHtIVehMvhAvoV6xYEcmDNewgN8ITxbrOKceJqxj58xTkhJ8\/d10HSR3uCgISxhS85tHRURsYGHBfI\/HTz4cPH9Yu3ty75S\/1DRs22HvvvZcLFf+HCPLlFn3Jxdw\/Gspx4ipGrmr0nPyfsXXr1hUDVUgEUkJAwtjhL5Ivkly4cMHmzp3b4T1pfvMRPs40nj17tqRyuHXEl1xKWt78iEqceBrCmMlkKp4jJp9MBNJCQMLY4W+SL5JcvXrVFi9e3OE9aW7z+cueHc2bN282LFw73PQlF3PHoipxghszEjpHDAlZtxCQMHb4mz558qS9+eabtnLlSre2yNoP60FMIXZ41xpqPjuZmfIrN93HKIjpQW5bCj+om77kUo0TI+sjR464s8X82fKm9cXwn5qawsrUIQQkjB3yoso1k3\/Nk8bZT4QA41\/3n\/vc59y6EWkyEaiXgB9ZMyXNP8L488Va486dO03iWC9VlUs6AQlj0t9QlfYxIuIvK\/7l77P6qUNuEPJxckWgHgJcw8hGLi765mYq6pg3b56tX7\/ehoeH9Y8vgMhSR6AmYUxdr1PeIX\/nrB9Npry76l4bCLDZq5umnNuAWI9sIwEJYxvh69HtI8DaYiaTqetLLu1rtZ4sAiLQCgISxlZQjvEZmzZtch9oZpOEf4xfF1q+fLmPCrjyQsCPqvlyC2FvhFmjZQrRx3Wzy6H\/+fPnu92rQQ7MRtx\/\/\/123333BaPlF4FUEJAwdvhr5Ksj7EodGhpyPUEgf\/\/3f999vosNEy5SPyUEWC\/Tl1xKsJREsJ64bNky27JlS2E9kaMwzz\/\/vPsSDhxLCilCBDqcgISxw18gf3EhiuwSZCv9Aw884HrELlX9peVQlP1hwxKcOMcHO9xO+5JL2c41MWHbtm3GKJp\/aHlOcINfEx+jqkQgMQQkjIl5FfU3BHE8ceJE4Uq44A7C+mtNT0l27rKzMmp6lL\/c2dXrjXB6ej65nlTihDh6RrjdzGlyVJW7EwlIGDvxranNIiACKSSgLiWFgIQxKW9C7RABERABEUgEAQljIl6DGiECIiACIpAUAs0QxqT0Re0QAREQAREQgYYJSBgbRqgKREAEREAE0kRAwpimt9mMvrSgDn9onK3\/YQteTM2ZzMHBwaZeVk39+vpIC16yHiECHUxAwtjBL6\/Tm85ZOLb+e9NXGzr9jar9IpAOAhLGdLzHVPSC85jcssJ1Y6noUPs7oRaIgAjUQUDCWAc0FWkvAe6HDU7BckVZsEWXL182pkt9HvzEBfN4P\/GkY\/h9vFwREIHuJSBh7N53n7ies\/b4D\/\/wD+a\/JxluoF9zPH78uB07dszd9MN0LFe5eXGkDkadq1evdulM0+KP+nAzQkg8152Vuxkn3AaFRaBtBPTglhGQMLYMtR4UJoCg+VEd7sqVK+3tt9+O\/BQUZRFDLkzfsWOH+evduJpsYGDA9uzZYwjn0aNHja8+rFmzhiLOoq4686I4a9Yse+6551w+\/YiACIgABCSMUJC1hQCjPUZ03hC+6dOn29e\/\/nUncuFGsfZIOt9SDKbxeS0E86233rIjR47Y3XffbZUuUOcDu48\/\/rir4hvf+EbFvC6TfkRABLqKQAuEsat4qrMNEGAU+Oyzzxoid+bMmciaGOHxLcXIxInIuXPnTviinatXr7oEBJLPJ7mAfkRABERggoCEcQKEnM4gcP78ebt27VpJYxlJIqwkMLLELWf33HOP7du3z\/jE1MjISMlHeMuVU7wIiEB3EJAwdsd7blovW1ERIheeLuW5jAQZ5V26dIlgwQ4cOGCMJD\/0oQ+5adQLn9TFdgAAAS9JREFUFy5ETsUWCkx4+L4g5tcnJ6LliIAIdDkBCWOX\/wFIUvfZELNlyxZjF6kf\/QXbh4ixsWbDhg1GXtLYjcqo77HHHnNrhY888oibih0aGiLZGXnmz59v7Fh1ERM\/rEM++eSTJfknkuWIgAh0KQEJY5e++CR0O7wrFeFDFNlFGtU+hIyPMHO8grzsZN24caNxYw67UynDJQEHDx604eFhIx0jD0JJGnmCRhzHO3bu3FkinMF86fSrVyIgAlEEJIxRVBQXKwHE6MSJE4Vzhn5XKm5QFL0QBuNo2LZt2wplqYf6iPfGaJNzidSHBfNQF2nk8fmpL5jHx8sVARHoTgISxu587+q1CIhAygioO80jIGFsHkvVJAIiIAIikAICEsYUvER1QQREQAREoHkE\/h0AAP\/\/N\/yf5QAAAAZJREFUAwC66aQGQZbyZwAAAABJRU5ErkJggg==","height":302,"width":454}}
%---
%[output:85d28524]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202609\\English_FigS1D_UndelayedLearningCurve.svg\n","truncated":false}}
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
%[output:30387fc7]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJcAAACXCAYAAAAYn8l5AAAM3ElEQVR4AeydW1PcuBaFdQgJBEICCeROqvJ2av7+eTj\/Y96mpqZSucPknhBCbmT6c\/XuEh4Zt2V127JXFRvdtrakpdWSLNvyinPul0QYLIIDkGtiV39CID0CIld6TGVxioDINQVCTnoERK70mMriFAGRawqEnPQIiFzpMe3WYo9KF7l61BlDq4rINbQe7VF7RK4edcbQqiJyDa1He9QekatHnTG0qohcQ+vRHrVn1OS6dOmS29\/fdw8fPgzK1atXi67CvXXrVuEP\/5svdmdnx1FmSPvChQvu3r17jrJC6RZHPep0THceF1uUS\/nz6DfRGTW5DKiDgwP36NGjf8nHjx8LFdzDw8PCH\/vv8uXL7sqVK7HZs8wncmXZbXlUWuSao5+YOpiOTBU\/U5xNqYxKpBHvT7EWT\/7bt2+71dXV2qmP6YlpyuyQF9tVUtYnL3G+PmHizSZ+4nwd8xNPOoLf4mNckSsGtUkepjimSqbTL1++OIj18+fP2dTKVLu7u1ussZhWCf\/48cM9f\/7cEZ6YCP5tb2+7t2\/fFnbQvXbtWuU6jPXb3bt33devXwt96oIfIhsxTOfTp08zHfy+jlWEPMRjg7Jpj6XFuCJXDGqTPBDq27dvE59zdAqjkoWJJP3p06fOjyO+Tuh48qJH3g8fPritra2iDOJ8YVRD5\/Xr17Pod+\/eFf7Nzc3CXV9fL+rgExp\/mTy0AWLxA\/DtFUYi\/4lcE+AA1aYMcxl1JkmVf3SqJfIL59d+48aNYgSz+Bj38+fPZ7KdnJwUYTq\/8Hj\/iKNsL8oRpi42JeMS5+uU\/SsrK25vb6+ITkUsjOVMLuqfRJiymFJ8aQoy+m\/evHEbGxuzbY06gqaovE\/yKnt1Ooy65IVkrCXxpxCRKwWKUxtMN0ZQiMZ0xtQ1TY5yGJ3o9KrMrKlCaf5oVaVj+SAfPzB+INSZ0c7S2rgiVxv0zskL0Vg\/1XVs2cTFixfPRBE+PT0tprszCZMABIJ8E+\/sj\/Da2lqxziIypEN8SFjrHR8fV15AhPKcFydynYfOnGl0KJfu\/igFqRgBymuoOpOs28iHHja4WoSkkIQ4XyAwOv70a9OalWs6ft2wzzYKeX17+LkgIN7XJz5GRK4Y1Ep56HimFaYUuyCAbFzpMRqgjsv0Q7xPBtJ8YWq6fv16sW5DlzAE8XXMj70XL144RiorF6L7V4Km49eN8tlGIc1smUscdYXUkMziY9yVmEx9zAMQd+7cCV6yV9UXINkuAMwqHeLpXDoDP4KfOPwmEIxOtTUXblmHfMRDGMtnruVnlPLtlOuGDd+u5cMuQrrZNLesQ5tpO+nYojx0CCPUz9chLkYGQS5+rVxKn7fwjQFHedoh0Jhc7YpLn5v1w4MHD4qd8PTWZbENAlmTC2KxAcplP9IGCOVNj0DW5GI9wjqDdUN6aGSxLQJZk6tt45V\/sQiIXIvFd9TWR0cu7qNtb28Xz1aNuueX0PhRkst2sZeAbwZFLK6KoyPX4qCU5TICIlcZEYWTISByJYNShsoIDIZc7HWV75GVG6vwchEYDLmWC5tKmwcBkWselKQThYDIFQVb60yjMCByjaKbu2mkyNUN7qMoVeQaRTd300iRqxvcR1GqyDWKbu6mkSJXN7iPotRRkWsUPdqjRopcPeqMoVVF5OpJj\/KGM9KT6iSphsiVBMY0Rnj\/Mo2lflgRuTroBx615hX8ctFlcvEWOQeRlPVyCYtcHfQUb4Zz4AjHD0A0qgCRcBHiOAaTdzLxE5ejiFwd9BrnNHCACCcA3r9\/3928ebN4YQQiQTrOOUXnyZMnjnczO6hikiIXT64k1RymEQ7WffbsmWMk4+1xhGkQ4nGUUe6tFrk67kFGK3+txfQYWo91XM2o4kWuKNjaZ2K0YjpkbXV0dOQ4rA3hTC\/O5yINnfYldWehNbn41XFIGYePARRN4XCxoe3Z0K5UwvTHWotjuR8\/fuwgFEdTIvjtbCzWXpx3n6rcZdtpRS5AAoBXr145\/5QZ1gucZCeChbuTRTprLdZcpsEC3vy479+\/Lz6IwGhGOEdpRS7Iwy+tDAyn1HFCHgRjZMsRmEXXmVGqXEYZx1+\/fjmkrJdLOJpckIbF6Pfv34NtrYoPKisyJwTmrms0uRidWDNw6Rwqjc+DkI5eKF1xZxHgvUvkbGzeoWhy0WzACJ36y3TJlEg6epJxItCKXCxM2fDjsFt2lu3TJBCOt59JHyesajUItCIXBpj2IBLHR5rYpTTpkvEi0Jpc44VOLa9DIJpcXC1yV5\/bFaFC2ANjcxW9ULriho9ANLnqoKm6iqzLp\/QwAjnGNiYXt3a41cOHBdbX1x2jE+GysMBnI5U1WY7AqM7tEWhMLr4Lw8KdZ41OTk6KWxSEQ6KtiPYdlLOFxuSyxjIivXz5cvZdP4uXKwQMgWhyYYDFetW0yDRJGjroSsaHQCtyceQ2t3iYEnkqgjUWfva9iOeuPyPc+GBVi0EgmlyMSDwxabvw3KgmDqPc3edpCW4DEZaME4FochlckAo\/IxRPThrBWOz7YXSyE1W4FQLR5IJMTH22n0WYmhi58DcVRjrWasj+\/n7tNxQpi3Ud+r5gp2nZuejvbvzH\/Xc3jWBrke2OJheVYkrk6Qc6GXIxirH3RRouD8QRT7hOIAS22OJg3ca0yg1xbFfltTTWeOQxGfIWyO6Gm5BrJYlgqwrbFPGtyEUn8u4dC3sqY483M4pAFPbEiK8TSII+FwRGRmwzMvJcWFV+8pFmefBL+oNAK3LRDAiE4KeTbRTBJUx8nRhJWKf5uoyM3KP043w\/UzLknrccP6\/8i0egFbl424fprG01jVwhkvAotaWXy4F4jHiMlCYp6lMuR+E4BKLJRYfT8ayz4opul8vKPz4+drbWYrTkQUURrB22qXJHk4tRhk1SXuCko1NVyLn5LFE+ZDo8PJxlsP01RrMu6jSriDwFAtHkovMgFs9z8YSETUu+yzYBekVJS\/rHSKr9tSWBXVNMNLls5LApKeQysqBXUwdnOiEicsVo6XV2lN4vBKLJlbIZRh72xny7LNi5YvTjzM+IyUYrOhaHyxUk0yNCWNIdAr0hF3tcLMYhDXCwKOeCoep1dsgD8ZiabcSDaDykyB4ZNiTdItALcgEBhGBXnnUa6zaIxhkUNqqhw1OwCH6E\/TX2uWzNx0l8BwcHWR+YRruGIr0hF4BCMFu7hV5Pg0wIuiaELQ8uo5mlye0WASNXt7VQ6YNEIJpcrHP0atkgOZGsUdHkqqsBV211OkofNgKNycWCmgU3i2i2DmwBTpwvXLVxBegvyIcNpVpXRqAxuWwBzXNXPMXARikL6ZCwQC8XqPB4EGhMLoOGEUmvlhkackMINCIXi3imQTY4ze9PhWU\/uuiFClbcghHogflG5GK0YhpkujN\/aDq0OHTR60E7VYUOEGhErg7qpyIzRqARuZjimOrK019VGF3yZIyPqt4CgUbkYopjqrNpD5erRm4ic0+PsC\/okqdF\/ZQ1YwQakSvjdqrqHSAgcnUA+liKFLmS9rSM+QiIXD4a8idFQORKCqeM+QiIXD4a8idFQORKCqeM+Qg0IhcbomyM+pumPHrDSxU8v+7H40eXPH6B8o8HgUbkYkOUjVF\/o\/Q8P7rkGQ+caqmPQCNy+Rl75FdVeoqAyNXTjhlCtUSuIfRiT9sgclV0zNbFPXf38m9JBFsVxQw6WuSq6N6t1T13b+O3JIKtimIGHS1yDbp7u22cyNUt\/oMuPZpcg0ZFjUuCgMiVBEYZCSEgcoVQUVwSBESuJDDKSAgBkSuEiuKSICByJYFRRkIIiFwhVEYZl77RIld6TGVxioDINQVCTnoERK70mMriFIHsycXZ8zxSbUJ42jY5HSOQNbkgEsdo8jg1j1tzXgVhnunvGFcVP0Ega3JxCB3nznMQyqQtxccNCBNPWNItAtmSi7eKQp9v4XMua2trjvRuoZ2r9EErZU0ueib0dpE+iQcy3Uu25OoeOtWgDoHRkYvvNwLKzs6O29vbq5SdnW3H2i2F8GW188pqkra9vbP0eoFXjIySXEdHR7VY\/f39T\/f70f+SyOG3P2rLm1fhrw8X3P8frSaRP98ttvsXa31exCL0bK0VWrifnp7Ovj4bMs2n9iSv3LwYhDCcJy5rcjHFbW5unmknYb7BaOQ7k6jAUhHIllygxHn4fImfzVTCuAjxhKtE8ctBIGtysWHKrrydsIPLt4lsU3U5EKqUKgSyJheNgmDc+jEhTLykewSyJ1f3EKoGVQiIXFXIKL41AiJXawhloAoBkasKGcW3RmB55GpdVRnIDQGRK7cey6i+IldGnZVbVUWu3Hoso\/qKXBl1Vm5VFbly67GM6ityZdRZPatqbXVErlqIpBCLgMgVi5zy1SLwDwAAAP\/\/Z6dUdQAAAAZJREFUAwDwwhoBZQX1qgAAAABJRU5ErkJggg==","height":151,"width":151}}
%---
%[output:5fd930fe]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202609\\English_FigS1D_UndelayedFirstBlockBar.svg\n","truncated":false}}
%---
