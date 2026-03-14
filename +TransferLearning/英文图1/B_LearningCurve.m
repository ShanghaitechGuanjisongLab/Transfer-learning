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
% - 作图禁止 plot：使用 MATLAB.Graphics.MultiShadowedLines。
%
% 执行方式（硬性要求，不要忘）：
% - 本文件必须保持为脚本（严禁改写成 function）。
% - 不要使用 run。
% - 在 MATLAB Editor 里打开后直接 Run/F5 执行。

outDirUNC = '\\Data-Server-2\个人数据\张天夫\202601';

% --- 0) Ensure project loaded (for UniExp)
if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
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

% --- 2) Query and sessionize (one row per mouse per session)
% 注意：在这些数据库里 Phase 往往表示训练阶段：
%   - Naive 组的后续 LightWater 会话通常标为 Learned
%   - Transfer 组的后续 LightWater 会话通常标为 Final
% 若只筛 Phase="Naive"/"Transfer" 会导致每鼠只剩首会话，曲线退化成 1 个点。
% 重要：部分数据库会在 Naive→Learned / Transfer→Final 之间存在未标注 Phase 的 LightWater 会话。
% 为了与“学习曲线”一致，这里以 Phase 作为锚点，纳入两锚点之间所有 LightWater 会话（无论 Phase 是否缺失/其他值）。
naiveAnchors = ["Naive","Learned"];      % Naive LightWater 轨迹锚点
tranAnchors  = ["Transfer","Final"];     % Transfer LightWater 轨迹锚点

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2)); %[output:7df7ef53]
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2)); %[output:2a2e2127]

tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2)); %[output:53474e81]
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
[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');

[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);
%%

% --- 4) Plot
f = figure('Color','w', 'Name', 'Fig3.1b Learning curve (LightWater)'); %[output:5c266b7f]
f.Units = 'centimeters';
f.Position(3:4) = [9, 8]; % 90mm x 80mm %[output:5c266b7f]
ax = axes(f); %[output:5c266b7f]
ax.FontSize = 6; %[output:5c266b7f]
hold(ax,'on'); %[output:5c266b7f]
axes(ax); %[output:5c266b7f]

% Reference palette from 范例 SVGs: Naive=#e60012 (red), Transfer=#0070c0 (blue)
EdgeColors = [230/255, 0, 18/255; 0, 112/255, 192/255];

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
	text(ax, 2.1, yMid, '*', 'FontSize', 6, ... %[output:5c266b7f]
		'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'HandleVisibility', 'off'); %[output:5c266b7f]

labels = {'Naive', 'Transfer'};
    if numel(Patches) >= 2
    	lg = legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2))); %[output:5c266b7f]
		lg.FontSize = 6; %[output:5c266b7f]
    else
    	lg = legend(ax, labels, 'Location', 'best');
		lg.FontSize = 6;
    end

% Set legend title to emoji (remove figure main title)
lg.Title.String = '💡💧'; %[output:5c266b7f]

xlabel(ax, 'Block', 'FontSize', 6); %[output:5c266b7f]
ylabel(ax, 'Hit rate', 'FontSize', 6); %[output:5c266b7f]
ylim(ax, [0 1]); %[output:5c266b7f]
box(ax, 'off'); %[output:5c266b7f]
% title removed per user request

% --- 5) Export (SVG only)
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = fullfile(outDirUNC, 'English_Fig1B_LearningCurve.svg');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off'; %[output:5c266b7f]
end
TransferLearning.PrintFigure(f, svgPath); %[output:5c266b7f] %[output:552ba8f8]
fprintf('Wrote: %s\n', svgPath); %[output:724137e8]
%%

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

%% --- 6) First-session performance bar comparison (computed from allSessions)
firstSess = allSessions(allSessions.Session == 1, :);
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
	f2 = figure('Color','none', 'Name', 'English Fig1B First-session performance'); %[output:4cd90a67]
		f2.Units = 'centimeters';
		f2.InvertHardcopy = 'off';
		f2.PaperUnits = 'centimeters';
		f2.PaperSize = [4,3];
		f2.PaperPositionMode = 'auto';

	tiledlayout(1,1,'TileSpacing','compact','Padding','compact'); %[output:4cd90a67]
	nexttile; %[output:4cd90a67]
	[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05); %[output:4cd90a67]
	ax2 = gca;
	ax2.FontSize = 6; %[output:4cd90a67]
	ax2.Color = 'none'; %[output:4cd90a67]

	ax2.XTick = [1, 2]; %[output:4cd90a67]
	ax2.XTickLabel = {'Naive', 'Transfer'}; %[output:4cd90a67]
	legend(ax2, 'off');

	% Asterisk font size
	if isfield(Optional2, 'MultiCompare') && ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
		for pt = Optional2.MultiCompare.PText(:)'
			pt.FontSize = 6; %[output:4cd90a67]
		end
	end

	% Bar styling – reference palette from 范例 SVGs
	colorNaive = [230/255, 0, 18/255];    % #e60012
	colorTrans = [0, 112/255, 192/255];   % #0070c0
	if numel(Bars2) == 1
		Bars2.FaceColor = 'flat'; %[output:4cd90a67]
		nBars = numel(Bars2.YData);
		reps = ceil(nBars/2);
		Bars2.CData = repmat([colorNaive; colorTrans], reps, 1); %[output:4cd90a67]
		Bars2.CData = Bars2.CData(1:nBars, :); %[output:4cd90a67]
		Bars2.BarWidth = 0.5; %[output:4cd90a67]
		Bars2.LineWidth = 0.5; %[output:4cd90a67]
		Bars2.FaceAlpha = 1/3; %[output:4cd90a67]
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
		eb.LineWidth = 0.5; %[output:4cd90a67]
	end
	ax2.XLim = [0.5, 2.5]; %[output:4cd90a67]

	ylabel(ax2, 'Hit rate', 'FontSize', 6); %[output:4cd90a67]
	title(ax2, 'First block', 'FontSize', 6, 'FontWeight', 'normal'); %[output:4cd90a67]
	box(ax2, 'off'); %[output:4cd90a67]

	% Export SVG (transparent)
	svgPath2 = fullfile(outDirUNC, 'English_Fig1B_FirstSessionPerformance.svg');
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
		ax2.Toolbar.Visible = 'off'; %[output:4cd90a67]
	end
	TransferLearning.PrintFigure(f2, svgPath2); %[output:4cd90a67] %[output:68fbb553]
	fprintf('Wrote: %s\n', svgPath2); %[output:5cb3c136]
end %[output:group:9039a271]

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
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = unique(string(Ta.Mouse));
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

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:7df7ef53]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID           MustWarn        \n    ________    _______________________\n\n       26       \"最后一回合没拍到\"        \n       65       \"2次中断拍摄，无法对齐回合\"\n"}}
%---
%[output:2a2e2127]
%   data: {"dataType":"text","outputData":{"text":"Fig3.1b: LAInterspersed excluded 4 mice with AudioWater mixed into Naive phase.\n  Excluded mice: vtf0045, vtf0101, yqn0051, yqn0052\n","truncated":false}}
%---
%[output:53474e81]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID        MustWarn     \n    ________    _________________\n\n       14       \"拍错Z层，舍弃信号\" \n       51       \"水滴漏了，没有拍到\"\n      111       \"2\/5层亮度反相\"   \n"}}
%---
%[output:5c266b7f]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAVQAAAEuCAYAAADRK+oSAAAAAXNSR0IArs4c6QAAIABJREFUeF7tnW2MVcd5x5+7azteG1Jnqd+2juOiLomaqtSyE6FNFbBSy6pk1CofsnT7oaIr21JltJFY7QuSBY4rWFZQKSZqSpItn0J2P9SVIFUjJZFtRVkhhTilbtLCtmtKnXVqbJoYbELN7m2fu8zN3Nk5Z2bO68w5\/yshG+6cefk9M\/\/7PPN2Gs1ms0n4gAAIgAAIpCbQgKCmZogMQAAEQKBFAIKKjgACIAACGRGAoGYEEtmAAAiAAAQVfQAEQAAEMiIAQc0IJLIBARAAAQgq+gAIgAAIZEQAgpoRSGQDAiAAAhBU9AEQAAEQyIgABDUjkMgGBEAABCCo6AMgAAIgkBEBCGpGIJENCIAACEBQ0QdAAARAICMCENSMQCIbEAABEICgog+AAAiAQEYEIKgZgUQ2IAACIOC1oC4sLND+\/fvp8OHD1NvbC2uBAAiAgNcEvBXUS5cu0fDwcAvezMwMBNXrboTKgQAIMAEvBfXUqVM0NDTUstDmzZshqOirIAACQRDwTlCFmB44cKAFcHZ2FoIaRFdCJUEABLwTVNkkc3NzEFT0URAAgWAIQFCDMRUqCgIg4DsBCKrvFiqpfi+\/3FnwSy+t\/n3v3pIqhGJBIAAClRFUXsTi+deRkZHWH3w6CVy5svr3y5eJfvjD1T9CJMV\/5Se2bet8Xvyd\/7t1K+hmQkA2isiQDSQMJf5t\/Xr74lzSqmWaShF1++hHidatM6Wu5feVEdSNGzfS4uJiLY3IjeaxKfq7GI\/y37\/ylVU0\/N+HHiLavp1IiCQEMsdu88YbnQIpGyXHYnPNGoIaiReCmmvPyzdzMVaXltaWIwsof\/vkk6tp9u0juvfefOtV29zFrxqLZhLh5LCBP+K\/cSD5VzGLD+ejlmcq\/\/BheKgR7CGoWXTKAvMQY1YVURHGCy9UCCiPF\/ZEORKEkGZoKDkksBFQnViq\/yZE0kYsTaKXpqmm8nmPOMIaLWEIapqOV+Cz7I3qPFEhoOyRChEV\/+3rW60ghDSFoUxzKXFZizBBFj9ZrPj\/TeKVouq5PYqQPxKt14Lq0iGqOIfKIhrn\/PB4FUIqRJSZsZBCRC17j7owpFsUssyqlUyea1F\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\/Zkx8fH218dPHiw9f\/yv6m08hJU4dC5LHh7K6Y2oX7cIlGahtmULYzKdeAPb6FQPy6CXsqQQqF1JpCboC4sLNDY2BhNT093hPjspc7Pz9PU1BT19PR0sPdZUG3nT711oGxCfdOvRloxM3nHppGYRtBNeeN7EMiAQG6CyqE6e5Yi3Bd1NYX9voX8LvOn3oqpTajPaYp4v71pq1Zcp\/YacAajEVkET8A7QWWi7N3u3LmTlpaWrBey8gr5bQTV+108NuG2yTvNSsxsPGXdsPIecvBagAZkQMA7QWWvlr1U4dkKcd21a5d23lUwYEHlz8jISOtPVh\/TgpT349xWwOK806wbaSPwqgGzEvSsOgbyAQENAa8EVYjnoUOHOrZJmaYJuF15eKimBakgpvRs5i1NE8R5iJmLqGYt6JACEMiJQG6CmmRRKuoZdV5VxyJPQdXdHBeEmNqKVtwm\/jzFzLZ+QcDOaYQi26AI5CaoSbZNRXmoUQtcMuk8BDVq\/jSI8W0b6se9lpUB5+Gdyoaz8aDT7i4IakiisiETyE1QGQqH6keOHGlv0rcJ3dPMoWZ9UkqMddmBC0JMGb7NarppE3+e3qk8auLqWlQdQh7FqLs3BHIVVCGqcUdPdZv21aOnBw4ciF2QymsOlce5rDnBjG0br4+hmW56yts7FcMgzpsuqg7eDElUJGQCuQtqUXCyDvl1C1JBeKe285KmbVJF\/3ro6l10HYrqrCinsgQgqBGmlW+Y4iR8rNx7Z8l23lR4p3HviSqjsaqollGHyg51NKwIAhDUCMq6BSnv10ayCvXL9AxlUfUeeBFDFGWERACCahBUccNUmRpj1aGyCvW5sLI9Q\/5h4M+mTVZNRyIQ8IUABDXCEmJBSrzw02tBtQ31xQpb3IuwfGkot2ndOl\/GCeoBAlYEIKgaTMEtSGUV6vvgnVp1WyQCAT8JQFA1dhHRs7yrqOwoOLL72Ib6puOlXIAv3qmfYwW1AgEjAQiqBlEwC1JZhvrwTo2DBQlAwEQAgqohpN4w5a3jZnMaittn8zIsbxtp6sL4HgT8IQBBVWyhmz\/1Umts501NZ\/VF+72d0\/BnsKAmIGAiAEG1EFTvTkjZzpuaTkPJbceeT9NYwfcgYCQAQVUQ6eZPvXLesp435fZ794th7LdIAAJeEoCgWgiqV86bbahvuvgE3qmXAxKVCpsABFWxn9cLUrahvs0WKdFueKdhj2DU3isCEFTJHF4vSOUR6nPbvXK\/vRobqAwIOBOAoBoE1RsHLo9Q38vtC859GA+AgDcEIKiSKbxdkMoj1Id36s0gREWqQwCCahBUOSJ+9tlnadu2bbR169bieoBrqH\/6tF3dvNq6YFdlpAIB3wlAUCULmRakGo0G7du3j\/bu3VucXW1D\/bg3l6q19WYeoziMKAkEiiAAQb1B2WZBqnBBdQn1uR18A7\/pg3lTEyF8DwKJCUBQb6AT2iUfLlIduUIFFaF+4k6NB0GgLAIQ1BvkbRakChXULC8+Eb0LoX5Z4wzl1oQABDVGUNUtmoUJqu28qcsGfoT6NRnSaGaZBCCoRCRH13HvkCpEUF1D\/bjXmYieBTEtc4yh7BoRgKBKgirPn+o0qBBBdQn12YW2WYjCFqkaDWk0tUwCENT\/v39ZLEjJEbRuujF3QbUN9V2u5cO8aZnjC2XXjAAElYhsFqS4X+QqqLahPlfEds8pQv2aDWc0t2wCEFQiElG2\/KYQ3Z0huQqqbahvewM\/9yyE+mWPL5RfMwK1F1TbBalcPVSXUJ9V3+Z4KUL9mg1lNNcHAhDUK0Rnz656qez88aJ5VKSci4fqEurbvGyPexXE1IexhTrUkEDtBVU4h3IkHaVHuQiqS6jPaVnx4z6YN63hMEaTfSEAQT1HdPly55uWo6YeMxdU11DfZs8p5k19GVuoRw0J1F5QbRekMp9DdQ31bfacItSv4RBGk30iUGtBlW+YEms9cRFzph6qi3cqJncR6vs0dlAXEFhDAIJquSCVqYdqey0fF2q7EIVQH8MbBEonkLugzs3N0eTkZKuhfX19dOzYMerv749t+KlTp2hoaKid5sCBAzQ4OBj7zMaNG2lxcdEJqG5BKk6XMvFQXUJ928tPsBDlZHckBoG8COQqqCyms7OzNDMzQ729vaT+XdcoIabHjx+nLVu20MLCAu3cuZN27doVK6ppBFV2AnMXVJdQ33bPKd5cmtf4QL4g4EQgN0G9dOkSDQ8P044dO9pCePXqVZqYmKCBgQGtOEZ9z0I8Pz9PU1NT1NPTo21gEkFVX3nCGcdpU2oPNY9QHwtRTh0eiUEgTwK5CSp7lmNjYzQ9Pd0R4seJY9QzNgBcBdXmlSdquakEFaG+jRmRBgSCJpCboHLofvDgwXa4LyjFhf3imUOHDtHo6CidOXOm9Vgec6iFC6prqI89p0EPLFS+ngS8ElSxgLV58+a2EOc1hyoEVT4hZVooVz1U\/gH4xje+ETsV0epWrqG+zZ5TLETVc8Si1V4T0AqqmP9kD3H79u0twXj++efpgQceMK62i9Ym8VBZUI8cObJmJ4DNYlbSkN92QYrbJQT1sccea+1CeOaZZ+jNN9+kpaWl1g6G8fHxtcZ2CfVd7jk1qb\/X3Q6VA4FqElgjqCyEHG7z9qZXXnmlvRjEC0bqIlMckqSCKu8KkMVZ1ClqyxULKn9GRkZaf0wfoXPilSec3rRYrnqoPKVx8uTJFqsNGza0FszWLJrZhvpcAdxzajIbvgcBrwl0CKq6yq4uINl4iqK1SRalokRYFvk4QXXZh8qCevy4+YYp2XqyoIq6fuYzn6F3331X753yw7aCyq6yTajPecI79XpQoXL1JdAhqCLU59CV94CqgholeDp8SbZNqeWLfG2EPEnIn0ZQ2TvlKZBHH32Udu\/eTXv27NEfWLC5Tcol1Mc2qfqOVrTcewJOHiqLCM8Xxu0HlVuszonaCKOaRmz0N630JxHUbdtW33HHjqGN0+e8bcp2\/tT2eKnNvIT3XQ4VBIHqErCeQz1x4kTrCKk4wWSLxHT0lEWaP\/KCjnr01KZMLwXVJty3PV6KUN+2yyEdCJRGwLjKL2pmew6\/rJYkEVTeeSTeJmJakOJ2OXuoJkHlUN\/2eCm2SZXVtVAuCFgTyG0fqnUNMkroKqgvv0y0e3f8K0\/UqjkJqk247xLq28xJZMQS2YAACCQjAEGNeYdUroLqEurDO03Wu\/EUCBRMYM0qf9yKtcsqf8HtIFcP9ZvfJFpasl+Qcg7548J9EerbHC\/F3GnRXQnlgUBiAk6CarNKn7gmKR90FVQ5IreNpp1C\/jhBddlzCu80Zc\/A4yBQHIGWoPJK+1HT2zRv1Mm0fam4qneWlEZQbRaknDzUuPlTl1CfC7WtXFngUS4IgECbgJOH6jO3pILq4gBae6hRguoa6mMTv89dDnUDgTUEarsoJTQvF0GNCvcR6mMIgkClCawRVPmmKV3L5av1fCKT1EO1nT91Cvl1x01djpdiIcqnroW6gIA1gTWCKh8v5dNR58+fb51iEveS8uXPfM7ft483ghoV7tveJMVgXdxm3wyB+oBAjQloL0cR74FSL1C2ebdTWSyTCqrLmo\/VHKruMmmXUB\/eaVldCOWCQGoCsbdNsVe6f\/9+Onz4cOutperfU5eeYQZJBJX3oW7aZF8JK0FV509djpdyVbAQZW8QpAQBzwjE3jbF86nyRn8IaoP27dtHe\/fujTajOn\/qcrwUob5nwwPVAQE3AmvmUNXN++Lez8HBwTX3o7oVlW\/qJB4q12jdOvt6GT1Udf7U1Tt1WSGzrzZSggAIFERAu21KvlJPXvX3dYWfWXkhqLpwnzfy2xyagHdaUJdHMSCQH4Fa70N18U7ZBEYPVRVUl3Af3ml+vRw5g0BBBGLnUAuqQybFuHqoSQo1Cqo6f2q7VQoLUUnMgWdAwDsCsav83tU2pkKlC6pu\/tQm3EeoH1I3Q11BIJaA9hUoPIc6MzPT2ioVyqd0QVXDfdtLUBDqh9LFUE8QMBLQeqhnzpyJfNDXhSnvBNVm\/hShvrGDIgEIhESgtotSSYwUOYeqO27K86fihVW6whDqJzEBngEBrwlAUB3MYy2oNhehINR3II+kIBAGAQiqg50iBVW3XYovCXjySX3u8E4dqCMpCIRDAILqYCsnQWUxjbp5xeVGFof6ISkIgEC5BCCoDvy1gup63BQLUQ7EkRQEwiIAQXWwl7WgRu0\/RajvQBtJQSA8Ak7vlKrSa6STmEorqC7HTbEQlQQ7ngGBYAg4CWqVXiOdxEJaQbU9bopQPwlyPAMCQRGo7Wukk1hpjaDaHjdFqJ8EN54BgeAIOHmoPreuiJNSjzzySOuC6a1bt66iUAWVT0fxR72uD6G+z10HdQOBzAhgUSoNSpv5U3inaQjjWRAIikDj7bffbg4PDxO\/mO\/RRx8l\/n+c5be0oW7+VD1uCu\/UEiaSgUD4BOChJrWh7fwpBDUpYTwHAsERgKAmNZn6umjd7VII95PSxXMgECSBdsgfF+bLLavz9X0dFraZP8VWqSAHBSoNAkkJaD1U8WK+8fFx2rJlS9K8C32uiFX+jgbJ86dRt0sh3C+0D6AwECibQO6CyocBJicnW+3s6+ujY8eOUX9\/v3W7+e0BS0tLNDU1RT09PZHPFSqotvOnuATF2s5ICAJVIJCroKonq1xPWvFR16GhIdq+fbtfgmoT7mP+tArjA20AAScCuQmqmDbg7ViDg4OtSl29epUmJiZoYGCg\/W9RtRXP89yu94Kqu50f4b5TR0RiEKgCgdwEdWFhgcbGxmh6erojxGcvdX5+3uhxcqgvPt6F\/Dbzpwj3qzA+0AYQcCKQm6BG3UxlE\/bzs6Ojo6351hdeeMGvOVTdcVP1dn6E+06dEIlBoCoEvBNUdVrAu0Upm\/lThPtVGR9oBwg4EfBOUNUpARdB5ZaPjIy0\/uT2kQWVQ3\/e0I\/jprnhRsYgEBKB3Db2Jwn5dfOuLoK6uLiYL3ub7VII9\/O1AXIHAY8J5Hb0NMmilLxnVWVm2sNayD5UHDf1uCujaiBQPoHcBDXttimBxisPVZ0\/5e1SfPepvKKP+dPyezVqAAIlEchNULk97HEeOXKkfTrKZoVf5eCNoNqE+1x5bJcqqSujWBAon0CugipENe7oqdhvyvcG6D7eCKrqnfKbTXlRSr6dH\/On5fdo1AAESiSQu6AW1bbc51DVy6R11\/Uh3C\/K3CgHBLwkAEG1MYsa7vMzOG5qQw5pQKBWBCCoNuZWw33ddX0I921IIg0IVJoABNVkXp13yuE+jpuayOF7EKgdAQiqyeSqd8rpMX9qoobvQaCWBCCoJrOri1FRx02xXcpEEt+DQOUJQFDjTKwL9zF\/WvlBgQaCQFICENQ4cgj3k\/YrPAcCtSQAQY0yu8475bQ4blrLgYJGg4ANAQhqFCWdd4pw36ZPIQ0I1JYABNVFUHHctLYDBQ0HARsCEFQdpahwn7dLyWf3+VkcN7XpZ0gDArUgAEHVmdk23OdnsV2qFgMFjQQBGwIQVB0lde8pp9Ft5sdxU5s+hjQgUBsCEFTV1FF7T\/HuqNoMCjQUBJISgKCq5KL2nqpn9zF\/mrTP4TkQqCwBCKpsWpe9pwj3Kzso0DAQSEoAgiqTc1mM6usjuvfepNzxHAiAQAUJQFBlo9ouRiHcr+BQQJNAID0BCKpgaHsRikiP7VLpex9yAIGKEYCgCoPaXoTC6TF\/GuQwGBoaolOnTgVZ9zpXesuWLXT8+PEgEEBQ2UwuW6UQ7gfRsXWVzP1FjlmQWX6HmldeIbr+BlFXDzVv+Qh13f5gFjnTtSbR1\/+7Sbc0iP707gY1Msk1\/0yCsNsNDBBUBuGyVYrTI9zPfxTlUIL3A\/O9n9DyhTGilSvUWH8PNXp+jej9X9LK8t3U3feXRF23pKJy9KdN+qufrrTyeO6BBn3urq5U+RX1sPd2k0BAUBmGbjFKd00fwv2ixlAu5Xg9MN+\/SMuLw0TL71Dj1g9S190fbzNovvNTai73U9d9zyTmcnmZaOs\/LdO7y6tZ9HYTvfRgN30gAE312m6KRSCounBfd6uUAIfLUBIP6rIf9Hlgrrz+HDXf+W4LUdeHPkKND\/b9SlDfu0QrF89S4yOHqOv2hxNhPHxhmb7ys85HRz\/cRU\/c63\/g77PdVGNAUF0Wo5geBDXRgPbhIX8HZpOWf\/KHRPTLFqbGul+nrg39bWQrby1Q8923qPGhP6auez\/vjPLi+0SP\/GiZ3leevL2b6OXf66b13c5ZFvqAv3Zbi6Heguq6VQqr+4UOpKwL83Zgrlyh5X97\/EZzm9T1xrvUeOC3iD6wjlb+Z4ma3e+tfrd+gLo\/vN8Zy7PnV+j4m03tc0\/eQ7T7fr8V1Vu7aYhCUM+e7cSiu1VKpMDpKOfB7NMDPg\/M5X99nKh5hRpX\/pea3Q2inptXw\/+L79HKnbetYuz9HHXf8xdOSN+4RvQH\/7xM1\/V6SlzKiw92052rxXn58dluKrB6C6oa7utecSITw+q+lwPOtlI+D8yVpUPU\/Pk3qXH5GjVv7iK69YagvvUurWy4jajRoO4H\/prott+2bW4r3cR\/rNDfvx2hpjdyGryrQV94wN\/VKZ\/tBkEVBHThPnunulul+Bl4p04D2cfEXg\/M5St0\/bWnqHHt9VWv9K7biK5ep8a1ZWrecSvRhj+h7rufcsLKc6e\/\/6Mby\/oxT3Y3ib7zYDf1pduV5VQ3l8Re201pSH09VJ2g8lap06f1toZ36jIGvEzr\/cB8\/y1aPv80NX7xX0TNJjXeu94K9xt3PE5dfaPOTP\/2Z006eGF136npM35\/F\/35PX6u+HtvNwkuBFXAiNsqBe\/UNB6D+D6Egbny8+9Q8\/UvUOPn16ix3KSVu++i7o\/+HVHjA86MJxdX6IW34sN9kenQnQ3a+5t+hv0h2E1whKAKEnGLUfBOnQezjw+EMTCXiReout64SNTdRc1Ng9R17+5EOL9wfoW+HrG6r2Y4fA\/RmKer\/WHYbZUoBJUpxC1GwTtNNJh9fCiEgXn9+nU6\/d19dN\/1f6H3um6n9+\/8I\/r4w59LhPMfLzXp8\/9uF\/L\/zaYueuQOhPyJQCPkVy5EgXeath8F8XwIgvrOO+\/QD37wA7rpppuIxfXWW2+lT33qU4n4Xl8heuzVZXr9WvzjG29t0j\/87k3kZ8BPFILdCgv55+bmaHJyslVeX18fHTt2jPr7f3UKRDX11atXaWJigk6ePNn+iq\/u4iu84j7O0MWiVJx3io38iQayrw8595ESGnLlyhX6\/ve\/T93d3XTLLbe0BPWTn\/xk4pr86DLRn51dpmsRjiov7M\/+Tjd9\/MZW18QF5fhgCHYrRFBZTGdnZ2lmZoZ6e3tJ\/XuUmPK\/T01NUU9PT+v+Sr7H0iSqztCFoMZtlcIx0xyHSfFZO\/eR4qvY8kq\/973v0WuvvUY333wzfeITn6CPfexjqWqycJWIz\/K\/+ItfZXNbg2jgDqLP\/0Y39XssplzjEOyWu6BeunSJhoeHaceOHTQ4ONgqT3ifAwMD7X+Te8rCwgKNjY3R9PR0hxd78OBBWlpaaousrnc5QxeCGrVVCt5pqkHs48POfaTERrCnyg4Fe6pZff7zGtHPrq3QHTd30aYewn2oWYGV8sltUSpKHNlLnZ+fjxVHtZ02zzgPFhbU3btXF6SOHl2LFt5pDt2t3Cyd+0i51UXpNwiEZLe7nkuEAAANJ0lEQVTcBJVDdfYsRbgveocp7I+aBuD51\/Hx8chO5gydBXXbNqInn1x7YTS800oOZuc+UkkK4TUqJLt5L6i5zaG+\/PKqhwrvNLwRlrDGPDDxCZPA4uJiEBX3WlB52mDnzp20ffv2WO800cS17ugpZwTvNIiOm6SSIXk6SdpX1WdCspu3guoipkJQ+b8jIyOtP8ZPlKBi7tSILtQEIQ3MUBnnUe+Q7JaboKZZlHIV08w8VHineYwHb\/IMaWB6A82DioRkt9wENcm2KbZdEjHNTFDhnXowfPKrQsfAfOQRopdeyq+wtDnzgumLL3bkwou8fOBFdzhGjJtDhw4ZD8GITKMWjtNWPevnIag3iPKK\/pEjR9odwLTCL0SYT0XFrejrDOYMXQ354Z1mPQ68y6+jjzQa0Vc1+lBz3h\/d7LwpigX16NGjrTUFcfBFVDWJoPrQTJs6OI9tm0xzSpObhyrqazp6yp2EPyygclq1vZs3b16zBUtO4wxdFVR4pzl1MX+yrYqgMtEDBw50HI6BoPrRz3IX1KKamUpQ4Z0WZaZSy6mCoPKJwfXr19OPf\/zjDgdDJ6ji3\/gZ8ZGPcMsh\/1e\/+lXtaUTZ4eE8VKfHdCQ8C4M7j+0sCk2YBwSVwcE7Tdh9wnqsKoLKx7Offvrp1lypmBpTBVUnsOoUnCyo586do9HR0Y75WTEFx2VwWerzooxdu3Zpj5Jn1TsgqFmRdMjHGboI+eGdOlAOO2lVBJXnT0+cONG6xU14iKqA6o5rq2lkQWXLqndvyGseuu+FxypfgJRHD3Ee23lUwjJPeKjwTi27SvjJqiSobA2+5vLChQut0P\/tt99uHYLRrfJHhenqKr98CZHIXxz55rSqB8tporZHZtlbIKhZ0rTMyxk6e6g8t7Rpk2UJSBY6gSoJKt9EJW8x\/OxnP9shqOr8KXuyGzZs6EijCqosmmxrWaDFEXBdH7C55zhN33Ee22kKS\/lsvT1UhrduXUqEeDwUAlUTVBFy89bEPXv20P79+9sequ7Ky7iQn+8rlveOc95yKB\/loRZhewhqEZSVMkKCXgIeFKleVBzoPlT1XmD1DRfsifIWQ54OUO8dFqG\/mHfVbeznNN\/61rda\/YUvto5a9BIdqojDASGN7fp6qJCY2hGooocq5jE5PGexFWLJHiqLnbg+U54CEHtYdWIop1O3RKmr\/LrTkHl0KghqHlQNeYYEvQQ8KLKiHqowrDhFJURQ9Vx5npMXrDid2G6lE1TxnFjs4qkA+aMucKkHDPLoaCGNbXioefQA5OklgdA9VC+hFlApCGoBkNUiQoJeAh4UqXqoAV6OUlcjhjS24aHWtZfWsN0hDcwamieyySHZDYKKnlsbAiENzNoYxaKhIdkNgmphUCSpBoGQBmY1iGfTipDsBkHNxubIJQACIQ3MAHAWVsWQ7AZBLaxboKCyCcgDM7Q1KbEtKo5hEVuYTDaUt1VldbUfBNVEPYfvQ4KeQ\/ORpQUBuY8EeFCq3UKxV1RcXGLR9EKS5HXJdUhjGx5qIV0NhfhAAIKarxUgqEQQ1Hz7GHL3iEAdBJVD7ldffZUuX77ceqHfU0891TqPb3t7\/xNPPNG6vFp85LBdPX3FaeR7AYaGhtrPye+9kqcr1Jup+Pjq7t276dOf\/jQ999xzpLu5Ch5qCYMoJOgl4EGRysb+qob8Yg5Tnk+1vb2fBVEVQnEfAF8XyBeuyNMM6g1UunLUOwXENYBCiMV9ANxBxb0DamcNaWzDQ4XU1IZAXTxU9QZ929v71QukZYHctGnTmhv91Y5j8xoWfka+WpC9XvVNARBUD4ZkSL9iHuCqZRXqIqjz8\/NrXjMtDG57ez+nVwUy7jXWuvRRr43XvXpFvLdK1zFDGtvwUGspLfVsdF0FNcnt\/TqB5H9TBVnM0UYJKr\/3SvcRr4Xn79hDhaB6NiZD+hXzDF1tqlNXQU1ye3+UoMqdRZ2v1b0o0PQCP\/XNqvBQPRmOEFRPDOFxNeooqGJlPsnt\/TbboFis+SPvJBAvCox6bYo8pyvmUOGhejZwIKieGcTD6tRRUMUiUJrb+1kgdYtSNotQUW8OEKILD9XDgcJVgqB6ahiPqlVXQU16e78qmEL8zpw507aqaXuWEPSjR4+2n5H3tkJQPRogclUgqJ4axqNqhXSW\/6GHiE6f9gheiVUJaWxjlb\/EjoKiiyUQ0sAslozfpYVkNwiq330JtcuQQEgDM8NmB59VSHaDoAbf3dAAWwIhDUzbNtUhXUh2g6DWoUeijS0CfFadV7vxCYsAv\/aaF7JC+EBQQ7AS6ggCIBAEAQhqEGZCJUEABEIgAEENwUqoIwiAQBAEIKhBmAmVBAEQCIGAl4IqLqEVAG1e9hXSSmAIHQN1BAEQcCfgnaCqFypEXbCgNhWC6m58PAECIJAtAa8ENeptjvKNNlHNh6Bm2zGQGwiAgDsBrwQ16qIE+Ybv3t5ebSshqO7GxxMgAALZEvBKUPl2m7GxMZqenqb+\/v52S23C\/roL6he\/+EUaGRnJtncElFvd28+mqjsDH9oPQQ1INOKqWvcflLq3n\/tG3Rn40P7KCCqOFVbklwHNAIGEBHw4oloZQU1oAzwGAiAAApkR8EpQ0yxKZUYEGYEACIBAQgJeCWqabVMJ24\/HQAAEQCAzAl4JKrdKnJISp6NsVvgzo4GMQAAEQCAFAe8EVRZV0S6bo6cpGOBREAABEMiEgJeCmknLkAkIgAAIFEwAglowcBQHAiBQXQJBC6r6vvHt27fT1NQU9fT0VNdiUsvm5uZocnKyo62bN2+mmZkZijqiWxUwfKpu\/\/79dPjw4TVtTXJbWYhcohiI3TJnzpzpaNaBAwdocHAwxKa266yOef5CNyVYVh8IVlDVHQFROwSC7j2GyttcGlPF9gvB4LapPx5JbysLjVMcg6gj3KG1Ua2vGOP878JxUhex+bsy+0Cwgqpb\/a9qR9INBNG5BgYGgvc6XAa67Hmo3nhdtt3FMRCCwj+2VYtUosY3t3VpaaklsvyZmJigvr4+Gh8fb3etopyPYAWVw935+fmOEL9OIsMeyu7du2nPnj0dF8m4iFNoaYWQcOjKn9nZ2Q7RqMPBEBMD5sJj4\/z58x2CEpqtXeorawFrwPDwcKvtfBRVfGxurHMpMyptsIKq+8WpU9ivzhGxgesyfypEQxXUNLeVZTGYis6DhURloJtj5HpVYf40LlITHmnZfQCCWvQoyKg8sSAlT8jzjwwLbdVCPR0ynZiUPZgyMq11NjoGwku\/\/\/7729Ebc9m5cyft2rWrctND6hxq2X0Agmrdff1PKAbTjh07KjdwVPoQ1NXQXvVQo3qpS1r\/e\/pqDcUPBe\/uEfOlENSE1qt7yG8T\/iREG8RjEFQ3Qa3aEW6dmAqRTXpJfRYdP1gPte6LUhDUtd5ZHRalZLu7eJ1VEtQoMWU2ZfeBYAW17tum5K0i4iBDVGfK4pfXtzziFmTK2jJTNKMoL53nSw8dOtSxyq1zQIqubxblxYkp51\/21rlgBVXd5MswdfvPsjCij3moCw26Tc8+1jurOkV5Z3W6rSyKgbo4qdv8npUdisxHOAy8HUreY6rWocw+EKygyr9GJ0+ebDGt29FTIaq8qblu7Y8Ld8s6dlikuHBZcQxYVI8ePdquUhVubNMdtRYNVLcMltUHghbUojswygMBEACBOAIQVPQPEAABEMiIAAQ1I5DIBgRAAAQgqOgDIAACIJARAQhqRiCRDQiAAAhAUNEHQAAEQCAjAhDUjEAim2QE1K1fci7yDUl5XM3octIoWevwVN0IQFDrZnHP2isEVT3ZE3VwIcsLtSGonnWGClQHgloBI4bchChB5TbJF+DAQw3ZyvWpOwS1Prb2sqVpBdV0Ikh9YZ18okb1UOPe0+QlPFTKOwIQVO9MUq8KxYX88ltNVQ9V\/P3ChQvtC7V1lw2rFyvLIvrtb3+7fZ8oU+dXZ5jOidfLOmitKwEIqisxpM+UQNyiFN8adezYsdY7s1RBjbqOTr6F68SJE2veOyZXXogrz9+Ojo6SfMt9po1EZrUhAEGtjan9bGiUh6q+yoNrz7eJiUWpuNumWBy\/\/OUv09e+9rU1b79UBfXIkSN05513tv65Dq+O8bMXVKdWENTq2DLIlsTNocpe6H333bdGUNW33jIA8YwQ1LhdAeL2Ip5XvXjxYuu2srhr4YIEjEoXSgCCWihuFKYSSCOouvcpidcFf+lLX6Lp6WmjhyryOHfuHA0NDVEVrrlDLyuPAAS1PPYoWXrRmroPVXibPCfKoTi\/lUAO+W3mUJ9\/\/nniu2KnpqZaz6sfedpA5M9potLDYCBgIgBBNRHC97kSMM2hije4ZrXKLwvxK6+80vHW0Cq\/bjlXIyLzNgEIKjpDqQTSHj2V96HKuwJEo9R9qHIa3cIW58dvgBC7C0qFg8KDIwBBDc5kqDAIgICvBCCovloG9QIBEAiOAAQ1OJOhwiAAAr4SgKD6ahnUCwRAIDgC\/wdcBJ+EQfiPdAAAAABJRU5ErkJggg==","height":302,"width":340}}
%---
%[output:552ba8f8]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\English_Fig1B_LearningCurve.svg\n","truncated":false}}
%---
%[output:724137e8]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\English_Fig1B_LearningCurve.svg\n","truncated":false}}
%---
%[output:4cd90a67]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJcAAABxCAYAAADYgjHmAAAAAXNSR0IArs4c6QAACv9JREFUeF7tne1W1ToQQIOIKCqogKj\/eAff\/wnuO\/hPBRQVP\/ALvWvXO+eG2J4kTdKm7XQtl0DTNJnZmZlM22TDGPPb6KESKCCBDYWrgFS1ykYCCpeCUEwCClcx0WrFCpcyUEwCClcx0WrFCpcyUEwCClcx0WrFi4dre3vbPHv2rJWEr1+\/mpOTE3Pnzp3m39u3b83v3\/FpwY2NDXPz5k3z48eP1vs8fPiw+fu7d+96nQ\/F+MaNG+bo6Micn5+bb9++hV7Wu5zCtb1tHj161ED069ev3oLsuhCw9vf3zeXlpfn8+XMveHzwhTZa4QqVVKZyWC6FK5MwnWrUcgXAdffu3ZVb3NzcbGDEZWKRPn782LjLnZ0d8\/jx45V4T09PzZcvX5oy9+\/fb\/4uZV3XimXCwmFZpOz79+9XbtK1XLjYJ0+emK2traZeuyy\/i4W6fft2c17cOz\/bblHK0afXr1+bnz9\/ZqVM4eoBF4rFxUmM5Fo\/lA9oAHZ1dRXkFh88eGBevnzZxEKi9IuLi+Y+NlwSI7plAYj2yLXyO7RwPQARawlcxH\/8bJfLSpY+\/jGmK6BH+DKaXcsFXGdnZ6ugmPO7u7utcVvfmMsGdm9vbxXwt8VfdlmsWZebt6GlvSXBosFquXpYLrFK4kZcN4TFkuA9FK7v379fC\/ht62e7yrbJAfc\/ODhoLBOgdc1s17Uzt9VSuMwfy+UL6F3L5cJlK4ayEnvZcZdvtpgClw1iCFxYLOLBw8PDIrGWyEMtV2a4RLAC5Js3bxqr4oPLzXOVdItYOGDGCnL0zd\/5rJ3ClQEuN+ZyXaEvT8X53AG9TAYAwAbVni3KrJOJQFcOzgfQuvMKVwa4ZEYGIHLY6QGZNEhKwE3WtqUi7LitVCqCtoobl9lnCkzutYuHK6cwta7rEpgEXIxcN+BVRdYvgerhknjEdhP1i1VbWHUqQnIyZLg5CDhLBJ2KQTkJVGu5gItHFiQqfW8VlBOP1pwigWrhWiXiAl5ZSRGAXltOArOBi9is62W7cuLTmied5wp5NkcHj4+PzYsXL1TbFUlgNpZL4aqIqv+aonDVp5PZtEjhmo0q6+tI9XCFikzdYqikhiuncA0n68XdSeFanMqH67DCNZysF3enaLjs13h5B4gXzlK+Rs4lcY25ckkyXz1RcMknSmTCeU\/cfl2WB8xjZsinCBcvETI45\/pAPhgu+1Nw+eZN1hwI+cgh33hor2lKcMlTBwYkP\/PxKq8U5f4otbTMffUrXD4JFTwvnqDUBxIFmx5UdTBc1CZftNhuUayY\/UFA0J0zF5qS5RJZ3rp1q\/nEi6UAxgwpMqtiVV0UXFzV9oVyDW+JTg2uUgqtqd5ouGpqvN0Whas+zQTDtW5tJw3o61NsDS1SuGrQwkzb4IXLTpquk4G7RtTQ8lK3OLTE\/ffzwiVVDL3kob\/p10soXLESK18+GK7yTUm7g8KVJr8SV0fB5S6XaDeoax2EEo1uq1PhGkrS4fcJhsv+UELW+mSNT\/dRUPit85ZUuPLKM0dtwXC5MZe9fgOpCFa\/G\/MxhsKVA4e8dfSGi1kkjy94bKF5rrxKmUttwXDRYXdVYVnuMXWHiRzCVMuVQ4p564iCq23FPBY8s1c+9jXPXTO0610muZcsNku963JpS4Hr6dOnzSs6IQfyshek813DpOzVq1e+YsHno+AKrrWjoL0wLEXWLVxrr1Ac8p7TUuD608\/nqapovf74+J+sX60HwyWWhBli302J7FWR2UVi3aJugIjbZcHakD15FK503kaDK0eG3l3bc91CtLGTBIVrwnDRdNfyxHbHtVT2jNOty32m6UvSKlyx2vi7\/OiWqyuY9ClfZpv22qbr4HJfAfa9EqxwTRiu9KZfT2W4qQ1f\/fZkoC3AV7h8EvSfH81y+ZvmL+FaqphVmn0BvsLll7+vxKThCk1FuPk0+1Osrg8ZFC4fOv7zk4ZLJgX2xkvu7l6S6nCTqF0bYYrIFC4\/PL4Sk4fL18G+5xWuvpL7\/7rR4NIPNNKVl6OGWWboFa4caKTXMSu49AONdCBy1jAruEQwOR7\/5BSyW5fGXOnSHS3mSm962RoUrnT5DgpX27JJKY9\/0rvfXYPClS7dQeFKb+5wNShc6bJWuDpkqHBNDC5xiyGv1Ya8FZHefXWLs5wtilpT3+kqBZharnTJju4WFa50JabUoJYrRXo9r1XL1VNw1mVquTIE9DGfZ3G7mE+0cn+e1Z4sntnXP3OKubByzwtt\/PlP4U1F1S2mW+joGmLcosLVLl51ixncosJVAVxzzXMpXBXAFe2bRrxA3WK68Ed3i+ldKFODwpUuV4VLY675LUSSPi7iawhdboma1XLFy\/fvHNpIq9ykNz2uhtBvHKVWhStOvm2lF+MWY5ZbUsuVDtYfGS7EcsUst6RwKVxREohZbomKY58XRjVGC\/8lgZDteIJXFhxavrFwDd0+vZ9fAlXDRfNl4ZF1qxD6u6klxpBAtXClLLc0hiD1nn9LoFq4YlMRqtz6JFAtXIgqJolan2i1RVXDpeqZtgQUrmnrr+rWK1xVq2fajVO4pq2\/qluvcFWtnnyN463ikG1u8t3RGIXLI02UsrW1Za6urkzIBlc5lZOrLhLQLMlwdnY2aB8UrjUaJBXClnJsu8zGpQDGRldTORgUbM6FxaLdbOY15KFwdUgbxTDiZdc0LNjh4aG5vLw0FxcXQ+oo6l4ssc4\/cYHAtbm52VitoQ+Fy5E4ULE5Kbvf4kp4tonVAjTAYj38oS2ACwVPL6Q9nz59ak4DP39jtzcOXDhAUZZBwSBh36Uhj0XCxchuA0Q2EAUo+VkUwt9Q2N7eXvN\/1w63QygPV037P3z4sLodFoq2CmyUASyg2t3dbeJGNrgf8lgcXMRRWKTz8\/NWwFAS4KAodvrgf3kzAygPDg4aBWLFxjru3bvXWFOxorjA\/f39VVzFeYCij6xdgVvEevEOFr8PdSwOLgSLsAnOGc3AghJk91v21EZZAIaLQSnEWEC2s7PTWLSxg3raf3R01AwOrBFunN+ZeODOJS6kf\/SHwcGA4ufT09Oh2FpmKgJ3gXtDMQDEqMfFAJQda6EFKQtUWIohR34XBUACOEBGHxgMWFz6AvjAxkFf+Mfg4egKB0rRtkjLJZtWYY2wSgCEBWPkY8FQHkobO3C3lY4bxPoQ79FOYGdQ8DODAtiwsrhsBoFMQrBaffckT4VuEXChCIBhZGOhEDbCRzm4CVwkZWTajlCZaQ2d0e5SJrNABoBYVmIn2uzuAw5gBPK4b1wj5YaeIdp9mBVcBLEI03Zd4vawUABEsHtyctIoB0VwoAQ5qIMywCXuJXUEp1xP+2lP10yPAUFf7Jljyv1yXjsruFACoxYwcGniOiQuIUbB\/WG5AEoCY86P5TralAlQgI3lFOsEPPzMbBcLhRWjnzITpA9jWqm2fswKLjcOkWQjQS5KYJTjLsQSoIyaFhAWV00\/iAuBR2JA2knbibGwVLh0rLG4eGKxWty4gDZJuBC+uECEbR+MbmIUYikRNkoDLGZNAMV5YJOUgmTlc7qEmLroD7M62k4wLk8IiBPFCtv1SXyINavBdXf1dZJwiStAIZLktCGTh7W4PpkZ4kYk8cl5gGLkj5kMXY3wjY0mYYv1kdiKdtNO4KGdpE5oM\/Ek0AGhZONjQB6y7CThQkC4CdwbAiYwRxlMu4FInqdJghEXIo9GsHgocWzFSGqBQUF7SDNgUZls2BbXntECFQcDYgqv\/\/wL9oy2iLbfTCMAAAAASUVORK5CYII=","height":113,"width":151}}
%---
%[output:68fbb553]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\English_Fig1B_FirstSessionPerformance.svg\n","truncated":false}}
%---
%[output:5cb3c136]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\English_Fig1B_FirstSessionPerformance.svg\n","truncated":false}}
%---
