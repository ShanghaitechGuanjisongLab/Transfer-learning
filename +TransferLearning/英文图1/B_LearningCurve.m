%`图3.1b：学习曲线（以会话序号为横轴，均值±SEM；两 cohort 非配对）。`
%
% LightWater learning curve: Naive vs Transfer
% - Naive 组：LightAudioBaseline(成像行为) + LAPureBehavior(纯行为)
% - Transfer 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
%
% 口径：
% - 每只鼠内按 DateTime 排序，将 LightWater 的每个 DateTime 视为一个“会话”；
%   若同一 DateTime 有多个 block，则对该会话内 block 的 Performance 取均值。
% - 之后按每鼠会话序号对齐，计算组均值±SEM。
% - 作图禁止 plot：使用 MATLAB.Graphics.MultiShadowedLines。
%
% 执行方式（硬性要求，不要忘）：
% - 本文件必须保持为脚本（严禁改写成 function）。
% - 不要使用 run。
% - 在 MATLAB Editor 里打开后直接 Run/F5 执行。

outDirUNC = '\\Data-Server-2\个人数据\张天夫\202601';

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

% --- 1) Load datasets
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（LightWater 是 Naive）
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（LightWater 是 Transfer）
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（LightWater 是 Naive）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（LightWater 是 Transfer）
LAI  = TransferLearning.LAInterspersed();       % 交替任务：含 Naive LightWater（需排除混入 AudioWater 的鼠）

% --- 2) Query and sessionize (one row per mouse per session)
% 注意：在这些数据库里 Phase 往往表示训练阶段：
%   - Naive 组的后续 LightWater 会话通常标为 Learned
%   - Transfer 组的后续 LightWater 会话通常标为 Final
% 若只筛 Phase="Naive"/"Transfer" 会导致每鼠只剩首会话，曲线退化成 1 个点。
% 重要：部分数据库会在 Naive→Learned / Transfer→Final 之间存在未标注 Phase 的 LightWater 会话。
% 为了与“学习曲线”一致，这里以 Phase 作为锚点，纳入两锚点之间所有 LightWater 会话（无论 Phase 是否缺失/其他值）。
naiveAnchors = ["Naive","Learned"];      % Naive LightWater 轨迹锚点
tranAnchors  = ["Transfer","Final"];     % Transfer LightWater 轨迹锚点

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2)); %[output:2a2e2127]

tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

% 不同数据库之间理论上不应有重复鼠名；若发生则直接报错
iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");

allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	warning('Fig3_1b:EmptyData', '%s', 'No LightWater blocks found.');
	SummaryCurve = table();
	assignin('base', 'Fig3_1b_LearningCurve_Raw', allSessions);
	assignin('base', 'Fig3_1b_LearningCurve_Summary', SummaryCurve);
	return;
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

% --- 3) Build curves via UniExp.LearningSummarize (required)
sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);

PValueLS = nan;
try
	[~, SummaryL, PValueLS] = evalc('UniExp.LearningSummarize(sessionForSummary)');
catch
	[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
end

[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);
%%

% --- 4) Plot
f = figure('Color','w', 'Name', 'Fig3.1b Learning curve (LightWater)'); %[output:5c266b7f]
f.Units = 'centimeters';
f.Position(3:4) = [9, 8]; % 90mm x 80mm %[output:5c266b7f]
ax = axes(f); %[output:5c266b7f]
ax.FontSize = 12; %[output:5c266b7f]
hold(ax,'on'); %[output:5c266b7f]
axes(ax); %[output:5c266b7f]

% Avoid white lines on white background
EdgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);

% MultiShadowedLines 要求：若 Y 为矩阵则 X/Shadow 尺寸必须与 Y 相同。
% 这里使用 cell 输入以适配不同组的有效长度（避免 NaN padding 影响绘图）。
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
Patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=EdgeColors(1:2,:)); %[output:5c266b7f]

% --- 4b) Stats: draw significance bar at X=2 (在legend之前画，避免被包含在图例中)
y1_at2 = meanMat(2, 1); % Naive at block 2
y2_at2 = meanMat(2, 2); % Transfer at block 2
yMid = (y1_at2 + y2_at2) / 2;
yHalfLen = abs(y1_at2 - y2_at2) / 4; % 竖线长度减半
plot(ax, [2 2], [yMid - yHalfLen, yMid + yHalfLen], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off'); %[output:5c266b7f]
text(ax, 2.1, yMid, '*', 'FontSize', 12, ... %[output:5c266b7f]
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'HandleVisibility', 'off'); %[output:5c266b7f]

labels = {'Naive', 'Transfer'};
if numel(Patches) >= 2
	lg = legend(ax, Patches(1:2), labels, 'Location', 'south'); %[output:5c266b7f]
	lg.FontSize = 12; %[output:5c266b7f]
else
	lg = legend(ax, labels, 'Location', 'best');
	lg.FontSize = 12;
end

% Set legend title to emoji (remove figure main title)
try
	lg.Title.String = '💡💧'; %[output:5c266b7f]
	
catch
	% older MATLAB may not support lg.Title
end

xlabel(ax, 'Block', 'FontSize', 12); %[output:5c266b7f]
ylabel(ax, 'Hit rate', 'FontSize', 12); %[output:5c266b7f]
ylim(ax, [0 1]); %[output:5c266b7f]
box(ax, 'off'); %[output:5c266b7f]
% title removed per user request

% --- 5) Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, 'English_Fig1B_LearningCurve.svg');

try %[output:group:21999fd3]
	% Hide axes toolbar in SVG if present
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off'; %[output:5c266b7f]
	end
	TransferLearning.PrintFigure(f, svgPath); %[output:5c266b7f] %[output:552ba8f8]
	fprintf('Wrote: %s\n', svgPath); %[output:724137e8]
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end %[output:group:21999fd3]

SummaryCurve = table;
SummaryCurve.Block = x(:);
SummaryCurve.NaiveMean = meanMat(:,1);
SummaryCurve.TransferMean = meanMat(:,2);
SummaryCurve.NaiveSem = semMat(:,1);
SummaryCurve.TransferSem = semMat(:,2);
SummaryCurve.NaiveN = nMat(:,1);
SummaryCurve.TransferN = nMat(:,2);
SummaryCurve.PLearningSummarize(:) = PValueLS;

assignin('base', 'Fig3_1b_LearningCurve_Raw', allSessions);
assignin('base', 'Fig3_1b_LearningCurve_Summary', SummaryCurve);

%% --- 6) Additional output: First-session performance (English Fig1C) as B-panel
% Keep B plot unchanged; generate a second SVG using BarScatterCompare.
% IMPORTANT: do NOT call other scripts here, otherwise they may export extra (scatter-only) figures.

% Extract per-mouse first-session performance (LightWater) directly from allSessions.
naiveA = double(allSessions.Performance(allSessions.Group=="Naive" & allSessions.Session==1));
tranA  = double(allSessions.Performance(allSessions.Group=="Transfer" & allSessions.Session==1));
naiveA = naiveA(isfinite(naiveA));
tranA  = tranA(isfinite(tranA));

DataCell = {naiveA, tranA}; % {Naive, Transfer}
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
%%

% --- Plot (transparent background, 30mm x 15mm)
f2 = figure('Color','none', 'Name', 'English Fig1B First-session performance');
try
	f2.Units = 'centimeters';
	f2.Position(3:4) = [4, 3];
	try
		f2.PaperPositionMode = 'auto';
	catch
	end
	try
		f2.InvertHardcopy = 'off';
	catch
	end
catch
end

[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
ax2.FontSize = 12/1.2;
ax2.Color = 'none';
ax2.XAxis.Visible=false;
legend(ax2, 'off');

% Bar styling (match B curve colors)
colorNaive = [1 0 0];
colorTrans = [0 0 1];
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	nBars = numel(Bars2.YData);
	reps = ceil(nBars/2);
	Bars2.CData = repmat([colorNaive; colorTrans], reps, 1);
	Bars2.CData = Bars2.CData(1:nBars, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 0.5;
	Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorNaive;
		Bars2(2).FaceColor = colorTrans;
		Bars2(1).LineWidth = 0.5;
		Bars2(2).LineWidth = 0.5;
		Bars2(1).FaceAlpha = 1/3;
		Bars2(2).FaceAlpha = 1/3;
	else
		Bars2.FaceColor = colorNaive;
		Bars2.LineWidth = 0.5;
		Bars2.FaceAlpha = 1/3;
	end
end
for eb = ErrorBars2.Object(:)'
	eb.LineWidth = 0.5;
end
ax2.XLim = [0.5, 2.5];

ylabel(ax2, 'Hit rate');
title(ax2, 'Block#1');
box(ax2, 'off');

% Export SVG (transparent)
svgPath2 = fullfile(outDirUNC, 'English_Fig1B_FirstSessionPerformance.svg');
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end
try
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
		ax2.Toolbar.Visible = 'off';
	end
	TransferLearning.PrintFigure(f2, svgPath2);
	fprintf('Wrote: %s\n', svgPath2);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local functions
function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
T = iQueryLightWaterBehaviorAll(DS);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
	return;
end

T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);

T = iSessionizeByDateTime(T);
T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
T.Source = repmat(string(sourceName), height(T), 1);
T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);

out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
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
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
	return;
end

T.Mouse = string(T.Mouse);
if ~isempty(badMice)
	keep = ~ismember(T.Mouse, badMice);
	T = T(keep, :);
	fprintf('Fig3.1b: LAInterspersed excluded %d mice with AudioWater mixed into Naive phase.\n', numel(badMice));
	fprintf('  Excluded mice: %s\n', char(strjoin(string(badMice), ', ')));
end

T.DateTime = iNormalizeDateTime(T.DateTime);
T = iSessionizeByDateTime(T);
T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
T.Source = repmat(string(sourceName), height(T), 1);
T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function dt = iNormalizeDateTime(dt)
% Unify timezone to avoid vertcat errors across datasets.
try
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
	% If conversion fails, keep as-is and let downstream throw
end
end

function T = iQueryLightWaterBehaviorAll(DS)
% 必须使用 Stimulus=LightWater（不回退到 Design）。Phase 仅作为锚点，不作为过滤条件。
try
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"]; % trial-level if available
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"]; % fallback
	try
		T = DS.TableQuery(varsTry, Stimulus="LightWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="LightWater");
	end
catch ME
	error('Fig3_1b:QueryFailed', ...
		'LightWater query failed for %s. Required query is Stimulus=LightWater.\n%s', ...
		class(DS), ME.message);
end

if isempty(T)
	return;
end

if ~ismember('Stimulus', T.Properties.VariableNames)
	error('Fig3_1b:MissingStimulus', 'TableQuery result lacks Stimulus; cannot enforce Stimulus=LightWater for %s.', class(DS));
end
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "LightWater", :);
end

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
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
try
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = unique(string(Ta.Mouse));
		return;
	end
catch
end
end


function S = iSessionizeByDateTime(T)
% Collapse within-session rows (trials/blocks) into one session.
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
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);

S = table(mouseKeys, dtKeys, perf, nBlocks, phaseSession, ...
	'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
end

function ph = iPickSessionPhase(phases)
% phases: string array for blocks/trials within one session.
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
	error('Fig3_1b:DuplicateMouseAcrossSources', ...
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
	error('Fig3_1b:MouseInMultipleGroups', 'Some mice appear in multiple groups (Naive/Transfer):\n%s', char(strjoin(msgLines, newline)));
end
end

function T = iAddSessionIndex(T)
% Add per-mouse session index based on DateTime ordering.
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
% splitapply 要求每组返回标量；这里返回 cell(1) 再拼接。
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

function [meanMat, semMat, x, nMat] = iComputeMeanSemBySession(T)
% Compute mean±SEM per session index across mice, separately for Naive/Transfer.
groups = ["Naive","Transfer"];
T.Group = string(T.Group);
T.Session = double(T.Session);

maxN = 0;
for g = 1:numel(groups)
	maxN = max(maxN, max(T.Session(T.Group == groups(g)), [], 'omitnan'));
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
		xv = double(T.Performance(rowsG & T.Session == s));
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
		error('Fig3_1b:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
	end
end

if ~ismember('MeanCurve', SummaryL.Properties.VariableNames) || ~ismember('SemCurve', SummaryL.Properties.VariableNames)
	error('Fig3_1b:MissingLearningSummarizeFields', 'LearningSummarize output lacks MeanCurve/SemCurve.');
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
		error('Fig3_1b:LearningSummarizeCellMismatch', 'MeanCurve/SemCurve cell sizes mismatch.');
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
		% 形如 (session x group)
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

function nMat = iComputeNBySession(T, x, groups)
% 每组每个 Session 的样本量（以“该 session 有数据的鼠数”为准）
groups = string(groups);
x = double(x(:));
maxN = numel(x);
nMat = zeros(maxN, numel(groups));
T.Group = string(T.Group);
T.Session = double(T.Session);

for g = 1:numel(groups)
	rowsG = (T.Group == groups(g));
	for s = 1:maxN
		rowsS = rowsG & (T.Session == s) & isfinite(double(T.Performance));
		if ~any(rowsS)
			nMat(s,g) = 0;
		else
			nMat(s,g) = numel(unique(string(T.Mouse(rowsS))));
		end
	end
end
end

function out = iFitMixedEffectPValue(T)
% Fit LME: Performance ~ Session*Group + (1+Session|Mouse)
out = struct('PGroup', nan, 'PInteraction', nan);
try
	if isempty(T)
		return;
	end
	use = isfinite(double(T.Performance)) & isfinite(double(T.Session));
	if nnz(use) < 10
		return;
	end
	Tbl = table;
	Tbl.Performance = double(T.Performance(use));
	Tbl.Session = double(T.Session(use));
	Tbl.Group = categorical(string(T.Group(use)), ["Naive","Transfer"]);
	Tbl.Mouse = categorical(string(T.Mouse(use)));
	
	% 更稳健：避免随机斜率导致奇异/不收敛，从而 p=NaN
	lme = fitlme(Tbl, 'Performance ~ Session*Group + (1|Mouse)');
	A = anova(lme);
	% Terms might be named "Group" and "Session:Group"
	if istable(A) && ismember('Term', A.Properties.VariableNames)
		rowG = find(string(A.Term) == "Group", 1, 'first');
		rowI = find(string(A.Term) == "Session:Group", 1, 'first');
		if ~isempty(rowG) && ismember('pValue', A.Properties.VariableNames)
			out.PGroup = A.pValue(rowG);
		end
		if ~isempty(rowI) && ismember('pValue', A.Properties.VariableNames)
			out.PInteraction = A.pValue(rowI);
		end
	end
catch
	% keep NaN
end
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
% Convert padded matrices into per-line column vectors.
if ~isnumeric(meanMat) || ~isnumeric(semMat)
	error('Fig3_1b:InvalidCurveType', 'meanMat/semMat must be numeric matrices.');
end
if ~isequal(size(meanMat), size(semMat))
	error('Fig3_1b:CurveSizeMismatch', 'meanMat and semMat must have the same size.');
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