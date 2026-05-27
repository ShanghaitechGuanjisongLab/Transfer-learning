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
ax.FontSize = 12; %[output:5c266b7f]
hold(ax,'on'); %[output:5c266b7f]
axes(ax); %[output:5c266b7f]

% Reference palette from 范例 SVGs: Naive=#e60012 (red), Transfer=#0070c0 (blue)
EdgeColors = TransferLearning.FigurePalette(2);

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
    	lg = legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2))); %[output:5c266b7f]
		lg.FontSize = 12; %[output:5c266b7f]
    else
    	lg = legend(ax, labels, 'Location', 'best');
		lg.FontSize = 12;
    end

% Set legend title to emoji (remove figure main title)
lg.Title.String = '💡💧'; %[output:5c266b7f]

xlabel(ax, 'Block', 'FontSize', 12); %[output:5c266b7f]
ylabel(ax, 'Hit rate', 'FontSize', 12); %[output:5c266b7f]
ylim(ax, [0 1]); %[output:5c266b7f]
box(ax, 'off'); %[output:5c266b7f]
% title removed per user request

% --- 5) Export (SVG only)
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = 'English_Fig1B_LearningCurve.svg';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar) %[output:5c266b7f]
	ax.Toolbar.Visible = 'off'; %[output:5c266b7f]
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath); %[output:5c266b7f]
fprintf('Wrote: %s\n', svgPath); %[output:85d28524]
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
	f2 = figure('Color','none', 'Name', 'English Fig1B First-session performance'); %[output:30387fc7]
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

	% Bar styling – reference palette from 范例 SVGs
	palette2 = TransferLearning.FigurePalette(2);
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
	svgPath2 = 'English_Fig1B_FirstSessionPerformance.svg';
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
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAVQAAAEuCAYAAADRK+oSAAAQAElEQVR4AeydDcxc1Znfn3kNJHEgeD9iGhx2C\/IGaSm46obUrVX8bgsSVeV6ZSlSbVlCpZKxs66cKi7CXSEuQtpoWVLFkiUTVLkbyYurJkJlo7SoWJtrq966S7a7xmVXZFmTxR+JnS9jiAME\/Pb+xn7G5z3vvTN35p07c2fu3\/Lznu+v\/53zn+c559wzM3P6JwSEgBAQAkNBYMb0TwgIASEgBIaCgAh1KDCqEiEgBISA2TxCFSBCQAgIASEwOAIi1MGxU0khIASEwDwERKjz4FBACAgBITA4AsWEOnidKikEhIAQaCQCItRGPnYNWggIgSoQEKFWgarqFAJCoJEIlCTURmKjQQsBISAE+kJAhNoXXMosBISAEChGQIRajI1ShIAQEAJ9ITAIofbVgDILASEgBJqCgAi1KU9a4xQCQqByBESolUOsBoSAEGgKAosm1KYApXEKASEgBHohUGtCPX78uK1bt87OnTvXaxxKFwJCQAiMHYHaEiokun37drtw4cLYQVIHhIAQEAJlEBguoZZpsUSegwcP2urVq+3kyZMlciuLEBACQqAeCNSOUCHTLVu22MMPP9yWesCkXggBISAEeiNQO0K999577cSJE7Z169bevVcOISAEhECNEKiQUGs0SnVlUQgcOmTmsqiKVFgITDkCItQpf8BFw3v8cTPkN3\/TLJRWyyyW2Vmz2Vmz2dnLxGr6JwSEQC4CU0OomzZtsttuu812796dO9CmR0KeiJNlkpgliVmamqWpWZqapWnTURrx+N9+2wz53vfMXL7zHTPkz\/7MzIVwWfF6+nHL1u39oc8jhmpSmhsVoVaOx9GjR9trrzt27Ki8rTo2wGc8nEMHDpg99NBlgUSTxCxJuvd8dtZsdtZsdtZsdtYsScySxCxJzJLELEnM1q7tXodSIwT8oThpOSnhvvqqGXLmjJlLmpp96UtXyZR8aWqWpmZpapamZmlqlqZmaWqWpmZpapamZml6tR6vr5f7jW+YpalZmpqlqVmamqWpWZqapalZmpqlqVmaXu1TNEQFryIwNYR6dUjN8flcZc4xL5PELEnMbr7ZLFPY7ZlnrC0xIkliliRmc3Pz5VvfMgvlscfMYonrUjhAwL\/VIE8eCuKE9tZbZml6mZT8weD6t96nP22GEA7jCfcj1NGPDNIW4wqGLe9VBESoV7GYCJ\/PWT7TPleZb8wh5gYSD2R21ixJzNLUDBJ97LHLRBnnU7gPBPxB8K3mBMq3Gg8F8qQqHgbCw0F4UAhxLjxIhPzjkHG2PY7xVtzmWAi14jFNZfXMWz77PmcZJHOSeUo84VC2bDFLkssWIFonJLp2bZhD\/lIIhMTJQ4jJMyRQKuRh+IPBRYjvJb\/xG2Y8NJevfMUsTzx9lG7cD\/raazwNTa81oXIW9dChQ7Z8+fJGPp5w\/jJvHQTmKESK63G4zDE+++TFhUQ\/8QlSJIUIQJgIYCMQJgIxIv4NBqiIa59hheTjYfBQXAMN0\/FDQjwghIeDfPvbZi6ESXOZnTWbnTWbnTWjrIunj9L1tmdnzWZnGY2kAIFaE2pBn6c+mnnNHM2bv8xbJASBucW8TJLLSo5INESnwO8gQ5gIYCMQJlJQrBPNA+JBdCNRHgxEycPBJYxAULOzZjfcYO0Fbxa9kdtvv0qen\/qUmQv5ywjl+5Uy9Xoe78\/113dgkGc+AuMn1Pn9aXwI5Yh5HQPhcxfX05ibzNUkuTwPRaSOTBfXiTQP5C7F2keYAB9BC0Xwx2V4KAgPBhcygiwRyI4w4uTEQ3NZLFFRvl+J+6\/wohAQoS4KvuEVxupE6YmVI+YsShCut8Z8ZK4izFPmo6fJLUCgDJHyAADaBdIEfAS\/x5MvbIYHgTiJ4iedh8PD4gEhkB3xkqlFQIRag0fLXMfqDLvCnPX5G8YzV916ZL4yT8N0+SMEABcwY42UOEgSgTAR\/A46Lnmi6jpBHgQSkygZeDBOpIQljUGgZoTaGNw7A2W+x3Oduexz2zOGc5c4rEeRKUgUCMBCiDG4ZHeASUeIKxKIEfBDKSJREWkRio2JF6GO8VEz58P5ztxGUWK+e7eYx66REsc+BnNc1iNo5AigAmQIbJgNcBGPA0wEoBHAhjBdCBMfipfFhUQRvt0Q4iSNRUCEOqZHz7yP5zw8EHbH5zDznXjmLXsZ+CURAr4IHYPq2SDRom+rkDQdbC9X5PIw3EwQkRah1Lj4OhPq1D6MvJ18yJQ574P2Oe5h5q\/mraOR4xYRKVkBFsGPQJoxwMR3E0wDHgJCeR6GzIRuiDUyTYQ6wsfuSlS8kw+ZsmbqXWGuM2c9zBxm\/npYboQA6n4MKlkg0SKtNASYvBAmAtgI2idCPgTTgIeAkF8iBHIQEKHmgFJFFHM+3sn3dpj37sfMZ\/56mDmtOexo5Lh8S+Vpp4CKeBFA5ZsKgD0O4iQegTARwEbQPhHPK1cIlEBgYgi1xFhqmwUyzZvzdJg5j4aKn3nt8x1libDmNMh0kfhbCkDLaKWQKcTZpWolCYF+ERCh9otYn\/m7kSlEyvz3KlGg8EOmKEv4JV0QYDE6TAZMJIwDVP+W8nip\/Y6E3CEjIEIdMqBhdb3INF439bIoT+6vncugIDIEPya3yyg7S9u+bgqJ5mmlHH1Czfd+8U0FmUrtd0TkDhmBySTUIYNQRXXM9yIzn\/bgAFwEBcrnPWRa2\/nug4LIEAaIye2Cyo1Ati6UgXAZ6LCE+mjb66NN9+MCKILfBTJF7a8tuN5RuZOMgAi1gqcHh4TzPW4CMnUOgEh97jPna7usF5NYPKgwDNm6AASECyhhnsX4qdPLAyRCGDDRSh1Q4hC+pSBT\/BIhUCECItQhg4tiFs73uHrIFCGe+c8SH36EeY9bS+k2qDIdpvwwSBWAIWtv08EkHBMpcYBa228pOiiZJgSmgFDr8zjiuR73DEWqaP6jndbWGoUIQxKLB1Y2DKkCUtn8cb64HwCKkI9vJwS\/i8jUkZA7IgREqEMCGp7oxTkxmYbzn7k\/pK4Mt5p+TP0yLQMSJEi9ZfJ7HvJDyB7GjQElzgVApZk6GnJHhIAIdQhAlyFTdvThEZqDSEPrtNbaaUxiDGAY0u+6atwPwEToC4Ai+BF28kWmICEZMQLTRqgjhs+sDJmiSIVzP1w3pcMoU7i1k9jEHnYHIUna6FUvedBsw3yA6mH\/duKbCWKt7dqJd1jutCIgQh3wyWKBliFTiDRv7nuzkGkt5z8DhPC8o1W5tAGQRfVDpuQJ0wEVIQ4CRSBT7eSDiGSMCIhQBwAfrsFijZWmvKpiMmXuh\/lqa5nGJBZ2eth+gIQgATasm3BeP2JQKQOh4kqEwBgRmGpCrQJX5jhkWqbucN0UqxQJy6GdhuHa+NEKIbm4QxAZxBdKnGcxYYClba8jj0y9bfLw7YTgF6GCgmTMCIhQ+3gAg5Ipcz4mU+Z\/LbVTBplHZOAEofItEQqvfIYSpuGnDEL5MkLbkCpSROpej4MKmLVcN\/GOym0KAiLUIT9pFCj4Bder9nnvYdzaaqcQGh2MpSwpMvBQKOcS11kUpg9InO71Es+3FIK\/tmDSOUmTEGgOoQ7hqebN8bBa5jtKmccx33kTEtfjcGurUBVphQwMUqTzCN8QLgwuFvLEQnkkju8nHJanfcrWFkw6J2kaAiLUIT1x5npIpsz3+HiUN1VLhaqXqe+dZ2ChMMhY+BZxIc3LAhLi4X5cykHslKF9SBx\/LcGkY5ImIiBC7eOp5y3pUZy5juBHmO8I\/lhqq1AVqd+QGMJAILGigZGeJ5QZBqnGAHtbWjt1JOTWAIGGEmr\/yKPA5ZViniOeBt8gHo7dWipUDK7bt4UPotvAPE+eu1hSjQH2Nvh2cr9cIVADBESoi3gIzHPEq4BvEA\/HLmRaS4WK40pxZwmjmSL4IUUE\/yBC2UE11Rhkbx9A3S9XCNQAARFqyYcQW8TMccSLQ6SIh2MXZaqWx6S6vaUUDzAeVL\/hQUg17ENIyABay2+nfkFR\/mlCQIRq1vfzZI4jXhAiRTyc59ZSmepm6qOZIgwGIkTwL1aoJyRGgETy6qV9T6Mc4vlqCah3Tm5TERChlnzyvsTI\/Ea8GNzQi0xrq0wVmfoMLhxkrwGSvx+BGAHOy9AW4mF3w7i4D9JOHSW5NUJAhFriYaDIkY1jUeEchxPgBtK6SS2VqV6mPtohg2KACP5hCnUCoNcJsIiHaR8hTF4EP8I3FK5ECNQMARFq9EDygminkKnPb\/LABeEcJy5PINPaKVNFB\/h9ACGxxZqh5xmGC4AA6XXRLkLYXfxxHwCVeIkQqBkClRPq008\/bbfddltbVq1aZcePH+8JQViGsgcPHuxZpsoMEGpYP2fW4YIwLs\/PvK\/dRhTqdrzDFnY+JrJ4oGiHLmG5Qf3UH5Nq+O1FOuL103btvqG8c3KbjkClhAoxHjhwwI4ePWonTpywbdu22fbt2+3cuXOFuEOee\/futeeff75d5plsgm\/JNBTiCwtVnAChunYazu1uzdaSTOlwNzJlkBneZGtLhnvbDf9w56gLYHQTbs5HACOsI\/ZTR0iq9MPzxH3oVZeXkysExoBAZYQKaUKmGzdutOXLl7eHtnnzZluxYoU999xz7XD85+1Me9q3b5\/dd999duedd7aT7733XtuwYYO98MIL7fBI\/2SNZV2ycH5nUT3\/M+drp5nS635M\/ZDgKIswMNyygiaJAEavsjGp0gZxCH4X6nO\/XCFQMwQqI9SzZ8\/a3NycrVmzpjPk67PJcM8999jhw4cN8uwkTJAnVpjirqOQwR9x\/NjDfDP00k79mwMSQ+JOL2ZglMVcj+sMw7QJkeMSH4Pdi5QpIxECY0SgUkJttVp20003LRje6dOn7eLFiwviIdwHH3zQXnzxxc5aK6Y+Gu3999+\/IP8oIuAg55le7UGm2XdGr2zjSWcg3VruZeoPg8xYKujWB9IgU0gVwU+cSy9C9nxyhcCYEKiMUAcdDyb+\/v37jeUBNqS+8IUvtNdTiR+0zsWWu0yol2uJ5zixzHPia0umvUx9BogwGAaC4A+FQYbhQf1865QpG\/eB9msLcJkBKU8TEKgdoe7cubO9cYWWykaWkysbXL0eCAS8e\/fuXtn6Su+1IcU8L6N49dXoMDP3MvVpq5d2yiCHRWbUM4i2O0gZxiYRAiNEoFaEypEqiPTRRx\/tbGSxOcXpADa42Ojqhg0EvGPHjm5Z+kqDi1xxyyvIHK81mdLpXqY+A0TIi1aI4A+FgYbhxfpZT+2nzmES+mL7rvJCoAsClREqa6dsSrE5FbfPTv\/SpUvj6Hb4xhtvXLDuunLlSjt\/\/rzl1dUuNKI\/wR6JwQfwwoiaHqyZXqY+tY5SO6U9F8ADRA93cyHUbulKEwI1QaBSQm21WnbkyJHOUNnZZ4efnX42oDoJgefNN9\/MJc5ly5YtINqgWCVelLuQb7wReAA+8HAtXdRrBtCtcwzOtVO+LUahsRXaLAAAEABJREFUnYb9AcQyZEm+sJz8QqCmCFRGqJw95Qwqh\/Qx5Rk\/66Hs8HOulHAsmPecQX3iiSc6h\/8py8YUdVFnXGaUYfhmIsgUULpdfEI6AqHiIhAqbiiQHWueYdyw\/b3WTOjDsNtUfUKgIgQqI1T6u3Xr1vbbUevXr2+\/egq57tmzp7M+Sh42oRD8yFNPPWWQ5+rVq9tlKMsaKnWRPkqJN6SY23nK0ij7VKqtbhefeAW9yJR8fHvgVi3ddv5H1Yeqx6j6G4FApYQKghAhm0XIsWPHOm9AkYZAoAh+l7AM5Qh72qhcLGa3hr1NCNX9tXXLrJsyMCdU1O5xaacOIlpwHnECOGmeT64QqDkClRNqzcdf2D200zARzmF+h3G18\/Mt0GvdlE5z+QguwsBwY8kjuDjPMMOo\/nGbcXiY7akuIVABAiLUAlAhVFfiPEspZckzj8MdhEzRUOO+8s0xjsHGpDqOPsRYKCwE+kBAhFoSrNnZkhnHla2Mqc83BOY+fYRI66Kd0h8XSBVCRzxOrhCYEAREqAUPCg015J6CbPWILmPqMxgI1XtcRKYQ2bg1Q3b+Ze77k5I7QQiIUHMeFvwE\/3gSyhw84+Hy7ohyljH1YzJlUHndqwuRjZvU87BRnBDogYAINQcgtNMwGu6pLaEO09RnkCKy8NHLLwT6QkCEmgMXhBoqdGSpJc+gSvfSTlG1w8EUmfoMsi7aKX2RCIEJRECEmvPQIFSPRjudnfXQotzhF+73bai8O0a9V9JOHQm5QmBgBESoEXQofUSh2OHWVsq+DeUDQTPl26FoQNJOi5BRvBAojYAINQcq5yCS4CCUN\/y1kTLrpgzCTX0GAaF2G0At1zS6dVhpQqB+CIhQo2cSL0nCRVUQatRs+SAqdNzJvNJl3obyctJOHQm5QmBRCIhQc+BzxY4kCLVWytsgZMogGEyRcJi+KE3xQkAIlEZAhBpBFW9I1Uo7LWPq822Auc+4INJepr60U5CSCIGhICBCDWDEmibofIR\/JFKmETrXSzul4xCq19eLTMkn7RQUJEJgKAiIUCMY4SSPQsGrjYbai0zpdEymDID4IqnN4Io6qHghMFkIiFCD5xVzFnxUC86pwtRn3LwzjysRAkJgKAiIUCMYQyUPQvUNqUOHDtnjjz\/elqjIkINRdf2a+nSaA\/xRNQuC3W7JX5BZEUJACJRBQIQaoNRtQypNU0uSpC1Bkeq9sdqc12I\/R6Qoz0aUf1MQlggBITAUBESoV2BEEcQbrqESHquUNfW9k2xCoaF6OM9lDUMbUXnIKE4ILBoBEeoVCNFOQzKFm+CeK8mjd2D4M2e6t0uHfY0CIqXT3UuYoZ32yqN0ISAEBkJAhHoFtphQiR4rofZ78UlZMpWpz6OVCIFKEBChBrCi8HkQhW9s3NPvxSd0FvHO57l8O8jUz0NGcUJgaAiIUDMosa7RUDNv+z\/cBP+0A6P+E3cmaL\/jhfnd1Ceyl3bKYHRECqQkQqBSBESoAbzwVBAcj3cQU59vgG691bppN3SUJgSGhoAINYMS7TQkUxQ+lLosabT\/y5j6dBShZxApncVfJJDp2NYuijqleCEwnQiIULPnGhNqFmUjJ9Qypj4dc1Mffy8yZRBaNwUpiRAYCQIi1AzmmFBR\/Eau1JU19V07hUzpaNb\/wv9op4WJShACQmDYCDSeUFEMAdV5Co5CsSNuZFLW1O9HO4VMR\/6tMDLE1JAQqCUCjSdUnoqTKf6RC4yOityr4ZBMF7yrHxWGTGXqR6AoKASqR6DxhBq\/Ko8lPVINtV9THxUaKfps0HmRaRE6ihcClSLQeEIF3VhDhZOIr1yqMvUr77gaEAJCIA+BxhMq1nZIqCh\/I1l6HMTUR32mg3lPkjhM\/euvxycRAkJgDAg0mlDhNDB3QoWrRqadxmsNdCQWOoYQT+cgVPx5Qsdl6uchozghMDIEGk2ooOx8hR\/Owq1cylzLRyfCjahuZEpetFNciRAQAmNDoHJCffrpp+22225ry6pVq+z48eM9B3vw4MF2fi9HHT0LDZAhVhIh1Mp5CbU4bjiv75Cpsz0dQ\/LyEYd2WrBOQbJECAiB0SBQKaFChAcOHLCjR4\/aiRMnbNu2bbZ9+3Y7d+5c4egg0y2ZNvZMRiiUef75523v3r1GXYWFFpGQNbOI0gMULUOmEGnYsV7HpHTxyQAPQkWEwPARqIxQIU3IdOPGjbZ8+fJ2zzdv3mwrVqyw5557rh2O\/7ydaW\/79u2zhx9+2O6999528p133tkm4sOHDxvp7cgh\/WFDKqwKJbBSRW8QU78XmVauUocIyS8EhEA3BCoj1LNnz9rc3JytWbOm0\/71GVvdc889VkSOr7\/+up06dWpeGQpv3brVnn32WaM84WFIxt3talAG8UCmWM74KxEaLKOdopmGnaJjRR2iw\/1sRBXVo3ghIASGgkClhNpqteymm25a0NHTp0\/bxYsXF8RDwq1Wy1qtlq1du7azjlqVue+8RUe68Rbpi5YyZEqHIFRvLFv6cG+uK+00FxZFCoFxIVAZoQ4yoNdee81Onjxpv\/3bv21f+9rX2uuuVa+hej8h1H75ifXeTZs29V6KGMTUh0zplHcwdtFOM40\/jlZYCAiB8SGQS6isf7qG6ISxc+fOyjaGwuHfkBHFnj17OuuuvobKeiz9CvMu1h8qg924K24HIuUEwrFjx+zmjIXZRAOfOF87XNbURztFKERnIFT8RZK1W5RULl65hIAQGDYCCwgVsrjvvvsMUmNzyBvED6lVZX57O8uWLVuwTLBy5Uo7f\/68sSTg+fJcSG737t15SV3j4C8ylFX42DDjBML3Ms3zxRdftF27drU30nI3zcqY+jQesnsvMs2+dLIFZUpJhIAQqBEC8wgVQmCXneNNaIZhP9mpZ8ceUi2jKbJ2yqZUHgmy07906dKw+rYf4mx7BvwDye3YsaN0aVcIKQBH4ZYVvnheeukl+63f+i376le\/2taoB940g0y9M5CpM7wV\/JN2WgCMooXAeBGYR6hsFLFhVERsRfF5Q4BQW62WHTlypJMMYbPDz05\/Hvncdddd7bwvv\/xy2\/U\/rK3maa6ePojr\/EXZXvxFnlheeOEF4wuG9d5XX321+IWF+GxWXBEdgVCJpyMQKv4igUzLqtJFdSyMV4wQEAJDQGAeoaI1oj1CYHl1QyKkky8vPYxzjZZD+f521P79+w3C3rBhQ5i14\/cyTzzxROfwP5rgk08+2SYv0juZh+iBx+Cpfqp86qmnjONc9Okb3\/iGxRp9uy7WT9ueLn+cTMnSi0zJo2NSoCARArVEYB6hojU++OCD7TeTnAS916ydciCfdPJ5fDcXwmH5YP369e0jUJAra7OQkJdjMwfxMGUeffRRW716dbsMGz68NUW85xmGmyRXa4FQr4aG6Ou1fgqZoqHSJJ1A8BfJ7bcXpSheCAiBGiAwj1DpDxsubLTwiiiaIa+NYopDhhxhIp18ZQUiZG0TYVc81uTQ9JCwPtogvwvhMH2YfuewkVvRECmE6oPp9UYUi7wj6qR3Sa4QEAL9IbCAUCmOBnno0KH2OVAntTwyJO+kSppe7TlcdTU0JB\/mfrf1037IlC71uyZBGYkQEAIjRSCXUEfagzE0ln1XdFots2zZyTwsD2SKhkp9qMgI\/iKB8aWdFqGjeCFQGwTmESrHodatW1e4Y80GEQf+yVebEQzQkbVrzbJ9JHMeq0T5K1o\/hUghVO93GUavpIPegR6ukoWAECiNwDxC7VWqaPe\/V7k6ps\/OmrFs6aQ6sj7GZNqrA9JOR\/Zo1JAQWCwCbUJll523jNhZf+WVV8x35YkLhU0qzl6yxrrYhutUfujWdNH6KdopwuAh0jLaqe46BS2JEJgIBNqEyi47m0\/s6N9xxx3Gbj7hPGHXfiJGVrKTKIAlsy4+20MPXa2jDJnWztS\/2n35hIAQWIhAm1A9Gs2z8JC6Z5LbG4G89dOYTNFQu9UE0+sQfzeElCYEaofAPEKld2w4sfEUmvqhnzTykHcapBIlMD4uhZmPABhEKu0UJCRCYOoQWECorJPyeinv03PDFK+JYvqzDMDVerzFhCY7dUgMa0Csn8Z1xRtRcXocRjsd+sJu3Miiw6pACAiBCIF5hIrmyQ1KfnkJl6GcycxXLjXhDSdeI+U2KsJRPRMbHDpvxdopZOraKZopGmovtCpRm3s1qnQhIAQWi8A8QvXKIFL83Bj1VkYQ3EJFmN+HCsPETbKgCA69\/xlenTohUgiVCIgUQsXfTSDTobN8twaVJgSEwLAQmEeo3CKFue\/nTSFUGsq705R4SQ4CIaE6mZKtDJnC8BO6EcUQJUKg6QjMI1RukcLc90ukWSu9\/fbbO3eacrcp66gQ7zQAhzI41HHE66doqDSAdorg7yZD71C3xpQmBITAsBGYR6hUzjnTu+++29icIszGFATLTj\/ul7\/8ZYN4SZNECGTrzZ0YJ9NORA8P2qlM\/R4gKVkI1BuBBYRKdznoj+BHS\/Wbp3AJEz8NUil\/hYRaxtyfJu10Gj4cGoMQGACBeYTK7v2mTZuMy6QHqGuiilRCpuH6aUiovcx9yLSSDk3UI1FnhcDEIzCPUNnN5ydKfJd\/4kc3ygF0Wz\/t1g9MfW1EdUNIaUJgYhCYR6iY8xzcD3\/TaWJGMu6OFq2f9jL30U7H3fdK21flQqA5CMwjVA72Q6YnT57s\/KYTm1GhTNurp5U86vC4VLcGIFOZ+t0QUpoQmCgE5hEqGiobT7xqWiSkk2+iRll1ZzH3w\/VTb4+1U8TDoStTP0RDfiEwFQjMI9SpGNG4B8FmFNKrH2invfJMX7pGJASmGgER6jAeb7h+GtZXtH6KdipTP0RKfiEwFQiIUIf9GMP10yJzX7fwDxt11ScEaoGACHWxjyFeP3Vzv4hMZep3EJdHCEwbAiLUYT5RJ1PqzCNUTH2dOQUdiRCYSgTmESrHptatW2fHjx\/PHezBgwdNx6YiaML1017mvrTTCDwFhcB0ITCPUHsNza\/165WvUel5x6UAINZQIVNtRIFMvihWCEwBAm1C3blzp3F4f\/Xq1fbKK6\/Y+vXr22HiQuEGqo0bN5rOoV558qyfXvG2HTf5YzKVqd+GR3+EwLQj0CZUbpbiIP\/Ro0ftjjvuMH4\/inCecL3ftINSNL7Z2VmbzSQ33cmUxPi4FNop8RIhIASmGoE2ofoI0Tz1M9KOxnz3scces29961tt6aQUrZ92MmQetFOZ+hkQ\/fxXXiEwmQjMsBHFRhNX9rk\/NPNjP3nJN5nDHXKvw\/VT11Ax9xFvStqpIyFXCEw9AjNopbyfjynv\/jxT3+PIS76pR6bXAMP1UyfTXmWULgSEwFQjMM\/kn+qRDntwoXYa1h2un8rcD5EZ1K9yQmBiEOiY\/LFpXxSWyX\/l2YaEWnT+FEK9kl2OEBAC049Ax+R3kx6X3f5bbrnFnsmIgnAoMvmvfChCQnWTP1w7JZsIFcDN1mkAABAASURBVBQkQqAxCFRu8rPZ5druqlWrCt\/CKkKcM7KbNm0yfu+qKM\/I44vWT0Nzn05pdx8UhiqqTAjUGYFKCRUyPXDggKHxouVu27bNtm\/fbmVPCfCq63PPPVc\/\/Moel6pfz9UjISAEKkSgMkKFNCHT8M2qzZs324oVK6wMSVKen2OpcOzDrRpzH\/FadVzKkZArBBqDQGWEevbsWZubm7M1a9Z0wLw+M4HvueceO3z4cE8Tntdc7777btuwYUOnfG08vn7K2imS17FsrHnRihsiAqpKCNQMgUoJtdVq2U033bRgyKdPn7aLFy8uiPcITP0XX3zRHnjgAY+qjxuun4a9CtdPtRkVIiO\/EGgMApUR6qAIsvm0b98+Y731zjvvHLSa6soVrZ\/K3K8Oc9UsBCYEgdoR6v79+9vQsd7a9vTxh9MEu3fv7qPEIrO6uR+S6SKrVPFBEVA5ITB+BGbY\/OGwPmTkwjV+J0+etC2ZGetx7pKXMlV0nYutn332Wdu1a5ex3tpvG5wk2LFjR7\/FyufH3A\/XT\/NKYu5r\/TQPGcUJgalHIPdgP8RUJGUP9rN2yqYUm1Mxiuz0L126NI62I0eO2KlTp+bdx8qJAI5dsbkF4S4oNMoIJ1PadO0Uf\/bFgyMRAkKg2QhUZvJDqK1Wq02SDjHro+zws9Ofp4FyQUtM5OzyozFDtmNfUy0i1NDk13Epf9zjdNW2EBgLApURKjdScQZ17969nbejWB9lhx+SHMtoF9NoaO5Tj2uoIZkSL3MfFCRCoJEIVEaooInGyW69\/6QK5Lpnz555P6HCq6UI+Wst4e6+kykdDs191k+JkwgBIdBIBColVBCFVN2MP3bsmMVmOz+\/gpA3T0hjoypviSAvf2Vxobn\/zDP5zcjcz8dlzLFqXgiMCoHKCXVUA6m0Hcz9vAYw95G8NMUJASHQOAREqGUeeWzuhya\/l8fc1\/qpoyFXCDQSARFqr8eOdhqa+2H+cP00jJe\/vgioZ0KgQgREqL3ADbVT8obrp6G5r\/VT0JEIgUYjIELt9fhj7dTN\/ZBMqUPmPihIhECjERChdnv8mPthupMpcSGhsn5KnGTCEFB3hcBwERChdsNT5n43dJQmBIRAhIAINQKkE0Q7jc39TmLmCTXULKj\/QkAICAERatFnINZOMfcR8odkirmv9VNQmXRR\/4XAohEQoQ4CoY5LDYKaygiBqUdAhJr3iPPM\/fC4VFhGx6VCNOQXAo1GQISa9\/h7mfuhyS9zPw\/BiY\/TAITAIAiIUPNQizejQu00NPdZP80rrzghIAQaiYAINX7smPtxXLgZFWqnMvdjpBQWAo1GQIQaP\/7Y3C\/STuNyCk8vAhqZECiJgAg1BArtNDb3XTslX6idYu5r\/RRUJEJACFxBQIR6BYi2E2unkClCYkimhCFUXIkQEAJC4AoCItQrQLSdWDvtZu6LUNuQNe+PRiwEihEQoTo2mPvux0UzRfCjnSL4XWTuOxJyhYAQuIKACPUKEBab+9JOHRm5QkAIlERAhApQaKexud9NO9VxKVCTmA0fg\/cvmH33WbO\/\/o+Z+5\/MfvDHQ23jd7\/5HfvPf3F+qHWqsqsIiFDBoh\/tlPwy90FBMmwEfvLnZoc+a\/bGH5hdeMns2hmzd182O\/V7Zpd+uujWfv9\/vmY\/vPHj9lfXfMz++PTcoutTBQsRyJ7YwsjGxRRppwARr51qMwpUJMNG4Oc\/MvuL\/2B2zQdmS28w+\/idmfwzs09+3uwXP2P2k\/+6qBZ\/cvHndvrdli25Yalds3TG\/uRN078KEJipoM7JqhJzP+wxpj5CXEymxMncBwVJDgKLivp\/v2s2967Zhz5idsONZq2fmL2TaayX3jJb8otm9n2zt7+duYP9\/4P\/fcZav\/ALtuRD19o1S8zev75l\/\/3kpcEqU6lCBESo\/Zr7hVAqQQgsAoE3XzW7ZsYsIzxbcq1Za4nZz\/\/K7GdHM8nM\/0uZ5nrxuA3y78yFd+1vf5qZ+B\/5qM3NzFgrq2Qmq\/7\/\/qxlb\/88C+j\/0BCYGVpNk1gR2mlo7qOZIowF7RTB74K5r\/VTR0PuMBGYe89sSTYdYbozF82+e87sr06Y\/c3\/MHvve5m8bcaywABt7v+T02bLbrS5a68zy3i5lSmmMxm\/XrquZc9\/N\/MMUKeK5COQPcH8hEbGdjsqBSAQKq5ECPRCoN\/065aZtVpm72aMd01Gcjd\/2OxXsrXUN7Md+Z9m66vvZLv\/loWtv3+vff9n7bXTues+mhXM6s+qnskcBNP\/xKWW\/eBnWZL+DwWBZhPqmTPzQeymnZLzE5\/gr0QIDB+B5f8oW0PN2O69981m3smINdNI33kz82fhn7KemhHrDXf33e5\/+V\/nrHVDtgY7c521suqZ8HNoqJln5hqzVsbbX\/+bLMH0bxgIZLAOo5oJrCM293tpp9qMmsCHPEFd\/rV\/Z\/ahW8yuzQj0rYzx3s3IFCK9mJErZ1M\/8vfNPvYP+hrQyR+9Zz9657qMlD\/SNvXtCm\/OZLVAqq3Mc03L7CdLWnYy2\/vKovV\/kQhkkC6yhmkpHhJqvHbKGKWdgoJkIARKFlr1pNnS28w+mpn9b2Xslymmtiyzx29cY\/Z3d5Ss5Gq254+8ba2ZG81+ep3NZVXOZVzN3tb7+DPOtszN+LS90nD41NVy8g2OgAgV7NzUxx\/eyE8YkXYKCpKqEbj2ly4T50y29f7eErNLGamykfSrnzOb+VDfrb\/19rXWejcrl+1xtd41Y9\/rg8xF3s94GvkgU4AvZf4fv5m11XcLKhAjIEIFEWmnoCCpAwI3\/JpdWrLM7P3LBPfB9Z\/OyHTpQD27bkm2QPrOEmtlpDmT7Wm13ja7lBHq+z81ey8j0Z9nRPtetjT73o\/nbC6LG6gRFZqHgAgV7RQBFkx9BL+LtFNHQu5wEOhZy387epf9+fm77Lut++w7Z\/+Jvf9+Zqtb\/\/8+9ckrZJoRp0GoSLaMcClz3\/9RxtnnzD74wZy9\/8NLdusNlwm8\/1ZUIkRAhBpqp3nmvtZOw8+L\/BUj8MZfv2bvfLDM3r72n9qJ73\/avv0nb9vP32XBs\/+G162ZsY8syRTcjFBnMg10JtvnmoNQf2g2lxHqpR9lZPqjSzaTbUit+4yooH+EF5aoHMWnn37abrvttrasWrXKjh\/v\/rbH29nu+6ZNm9r5vdzBgwcX9nwYMWimCHWhmSL4XXTu1JGQOyIEfunv3GTvvvu+vfnj79vyX7nO7vnnv26tubmBW9\/2r8w+fIVUWxlxQqqtH1\/WTD84l9X7kzn7F\/+4choYuP+TVrBSJCHTAwcO2NGjR+3EiRO2bds22759u507dy4XJ8h0yxUt8eWXX26XeSbTIImrhFSdTOnNlXbxdkTmfgcKeapBIK71h987bx\/68K\/YD85+1P7P4b+173\/vgn34+mxjKc5YMnzzcrN\/\/6DZL30s01TRUrN1VHtrzpZcmLOlGVFvvP8aW\/3rrZK1KVsvBCojVEgTMt24caMtX5491awnmzdvthUrVthzzz2XhRb+f\/311+3UqVO2a9cuu\/7KK5733nuvbdiwwfbt22cQ7sJSi4jJyLpTOk87vdKHTh55hEDFCPzqp26xTTv+pf3r31ln\/+Z31ts\/vO\/vLbrFj11v9sgWsyd\/J5NHzH7\/kZb93iMz9ti\/XWJ33b7o6lVBgEBlhHr27Fmby74B16xZ02kOkrznnnvs8OHDueR45513ttNwO4Uyz8qVK7O\/Q\/4v7XTIgKo6ISAEKiXUVqtlN9100wKUT58+bRcvXlwQnxeBVgoB35yZ3xByXp6B4pLkajFpp1exkG98CKjliUegMkIdFjKsvyL333\/\/sKo0O3TILE0v1weZIpdDl\/9m5H3Zo79CQAgIgfII1JpQORHwhS98ob2Gylpq+WH1yLl2rRnX9rERhYTZ2dnX2mmIiPxCQAiURKC2hAqZsol133332VNPPVVqOByz2r17d6m87UyQqbTTNhT6UzcE1J9JRKAyQmXtlE0pNqdiYNjpX7p0aRzdCQ9CphTmaNaOHTvwDibSTgfDbdJKseTz+ONmkyCThm3D+1spobZaLTty5EgHYt9gYqe\/aINpUDLtNLIYj9ZOF4PeZJVNErMkMUsSsyQxSxKzJDFLErMkMUsSsyQxSxKzJDFLErMkMUsSsyQxSxKzJDFLErMkMUsSsyQxSxKzJDFLErMkMUsSsyQxSxKzJDFLErMkMUsSsyQxSxKzJDFLErMkMUsSsyQxSxKzJLH2ev8VZHfu3GlFL8cwb0jr57w2eddmy18ccbzShJxFIlAZoXL2lDOoe\/fu7bwdtX\/\/fmOHn3Olef3mwXLwvx8zP6+egeKknQ4EmwqNBIFOI29la\/9f\/OIXc48ddjKV9LAvcSjT1pmrJYsoWw8EKiNU2t26dWv77aj169e3XyWFXPfs2dM56E8evnUR\/Bz4P3nyZPvgP+uhoVT+TSrtlEfQPGEd\/StfMauT0KcuT4JTLygnXbIoaUwIVEqojAlSZW0TOXbsmMWH9tlwQuK85A+l0m9SaafA30xhU7KOUvA0Vq9ebVhwvIWIRVeQrR3tywChYoKZ307M\/uB3RQWlhjs0WJbLkjr\/iUc8gtfJi+rzPE12KyfUiQBX2ulEPCZ18jICjzzySNvz5JNPtt28P5App2S+9KUvmSsmDz\/8sHEMkbS4DOe8X3nlFeP1b0+DsF966SUjjTjIFCvz+eefb9eJS33Eky4xE6FKO9U8mDAEPv7xjxv7EyyRoWXmdZ\/N4DvuuMNWZxqtp\/tr4Hknb+666y5btmzZvE1k6qcsaZArWjEXHLmViUuYeNLJ23QRoUo7bfocmMjxo31Clk888UTu7W0stT377LPtS4bQIDHT2ctgUytvwGxM3X333e27NDD7EV75Jo40bn87f\/68OSl7HYSLjkd6nia5zSZUaadN+qxP1Vg5dsitbOczkssz\/THrOUYFkZLONZiY6DfwmS9AAtPezX5Mf\/zEeXbIGFKmThfCb775pmdpvNtsQpV22vgJMMkAuMn94osvGhpkOJavfvWrhslPPGuoHJEK0\/P8mPZu9rNkgJ84zwsZQ8rUF0reZrOXaZrbXELlfX2kaU9c450qBDD9Ic5HH33U0CAZHOb6mTNnLH6BBpL0POSLBdOetdlvfvObhri5Tz7efMSN119Zw\/WTAqQ3XZpLqE1\/8hr\/VCDgpj\/ao9nlIRHHdZfhZhFLAOzQk+O1117DyRXWRN944w2LzX3XhtnVpy4KsxHFGi4kDBkT13QRoTb9E6DxTzwCkB1nU8OBJEnS\/nUMNq5Y70ST5QjVLbfcYt0I9dZbb20vFZAvNPepm40udvVZN6VO6oZMiSddomNT+gw0HQF+Buehh8zqJPQp57nwAozv3MfJpLGu6WulaKnkJQ5hnZO0Q4cOdW5v83CoXXo58oXx3h7kSX0uhD1NrghVn4GmI8BP4dRRFv9cVMMYEJDJPwb3y5AhAAANFklEQVTQ1aQQEALTiYAIdTqfq0bVDYG1a83m5iZD6Gu3sSitVgiIUGv1ONQZIVANAqp1NAiIUEeDs1qpEQLZvoy1WjYRQl9N\/yYGARHqxDwqdbTJCHCFHkeVugnv7I8bI\/rgfeTQ\/7j7M+r2RaijRlzt1QqBOl6FSp9ikPxYFMeVeJ2UM6D88gVhl9JHmOLKhxTmwD8vD3BvAH3iWNaQqp6YakSoE\/Oo1NEqEOBy\/Dpd1k9f6FMVY1Wd1SMgQq0eY7UgBEaGACb3Qw89ZNy+j+nNUgGNoz367VPEI6FJjp938v\/wD\/+w\/XNFpCPEUx7hjgCvlzTE03F5g4q7ArZk3wjkIz\/l6AN5EfpAX4hHeH113bp1xltceenkmSQRoU7S01JfhUAJBLh9iotRMLtZKoDA\/NVT4pCrt\/cf79TI77lxKQpLCuRhSYF39SE9yBGi5I4A0hBMe3+3H\/Oem6i4U4B43tLirSvIlFv\/+R0sykCcEC8E7A1fuHDB\/uiP\/sjIwxtdvErraZPmilAn7Ympv0KgBwK8hw8ZejZumeJGKtZdPY5LUPCHt0dBhtyxChGS9sADD9j58+fbVwNevHjRTp8+bStXriSpLZBoNwKEyCF3bsLy11gpQ9\/27ds375dbuRPA87Qrn9A\/ItQJfXDqthAoQmDFihW2dOnSTjKbVa4xsiSAaY2WiHneyZR5uP\/Ur+nLgvP+Q3Zc58dl1aE5Py9TFIDIqTO+ZIVLqyFnSNqLhETtcZPoilAn8ampz0KgDwTQFFm7hEghRExyN8+jaroGWT5gqQDTHJKkPkz6boVYRkAzJq8LSwfdykxymgh1kp+e+i4ESiAwyO39RdWi7bIWikCu\/JAfWm9RfpYfIGDyh1J0m1VRPZMSL0KdlCelfgqBARBgM2mQ2\/vLNAW5sh5adL8qZjxrsOE6LfVCwGWXDcg\/SSJCnaSnpb4KgT4RYIOJnflBbu8Pm2Knn2NVkKHHs5TAphNroh4XumxAcfH19u3bjfKkUYbD\/w8++KDRN+KmSUSo0\/Q0NZa+EeAu57oJ17P2PZAuBQa9vT+skk2pr33tawYx+1ooG1vc4A9xhnlDP+uubGb5OiplODrVrUxYftL8ItRJe2Lq71ARgLzqRqj0p9sg0ezYtYes4nyY4aSRx9PwE+drmBx1gtBYx\/Q6PAxxejnOg3pe4kijjNeDS3ukIXF+4hDaIK8LbRGPeJ1hHPGTKiLUSX1y6rcQGCUCaqsUAiLUUjAp0zQhwJ3NaWqWpmZpapamZmlqlqZmaWqWpmZpapamZmlqlqZmaWqWpmZpapamZmlqlqZmaWqWpmZpapamZmlqlqZmaWqWpmZpapamZmlqlqZmaWqWpmZpapamZmlqlqZmaWqWpmZpapamZmlqlqZm9HWasJ\/2sYhQp\/0Ja3y5CEBUkyC5nVdkbREQodb20ahjQqCuCKhfRQiIUIuQUbwQEAJCoE8ERKh9AqbsQkAICIEiBESoRcgoXggIgTIIKE+AgAg1AENeISAEhMBiEKgloXL5rL+NgUt4MYNUWSEgBITAKBCoHaFCntwCzvVivFnBVWOEeQd4FICoDSEgBAZHoOkla0Wo3IzDTd5cqMBrbDwcXkkjzBVkhCVCQAgIgboiUCtC5QZvbvKOb68hzO\/S+I01dQVT\/RICQqDZCNSKULk3cW5uzvJ+hiHvXsVmP7r5o9+9e\/f8iIaFmj5+HnftMKBTI5Q6jL9WhDpC7KeuqTp8mMYJatPHD\/ZNx6AO458aQvX7FjkV0ERhQjVx3D7mpo8fHJqOARwABuOUqSHU8L5HTgdITpgwEAb1+QxU\/yzggHGSKW3XilBZO221WsZaKp0LZdmyZblrq2Ee+YWAEBAC40SgVoS6dOlSW7Fihb3wwgvzMCHMzyhwu\/e8BAWEgBAQAjVCoFaEyk818ONd\/DQtB\/zBCZcfAnvggQcISoSAEJh8BKZ2BLUiVFDmID9vR23ZssVYaMflR738oD95JEJACAiBOiJQO0IFJEg1XEwnTLxECAgBIVBnBGpJqHUGTH0TAkJguAhMU20TTai8+79p06b20gDLA\/iJm6YH1G0sTz\/9dGfsjB9Zu3atNeEVXS7LWbduXe5YWXcHCxfC3XCc1LQiDHj+fA58\/O7yeZnUsXq\/md\/Mcx8Tbt7zJY40F8JeR5XuxBIqwLK+evPNN7fPW7788sttnJIkabtN+PPaa6\/Zhg0b2uP3JZJDhw7ZtJ+GgDC2b99uFy5cWPCYmTjcTjbtt5V1w4Bjh7zC7Rj4Z2Pr1q0L8JqkCJ\/z9Jn5zrh8v4XnTjyCf1yfgYkl1KNHj9orr7xivvvPCYFdu3bZn\/7pnxrf3AA7zcKH68yZM7Zy5cppHuaCsTFZeCPm5MmTC9LApAm3lXXDAFAg1FarNZnnthlAgbz++ut26tQpY54z38nG\/gpKBc+d54\/g54Y638gmD+FR3Fg3sYSKdnbHHXfYrbfeCq5twf\/JT37Sjhw50g5P8x9u5nrrrbdszZo10zzMeWODSLBKHn74YUPmJWYBMJn228p6YZDBYMyNaTy3DUEePnzYcBmnS6hUjPszMNGEirnv31QOLi4fKNxpFkweNPT169d31lFZN8MUnNZxo2lg5hWZrmhmmLq8cRdjMC23lfXCAA0N0uEst68f4k7D+mn8TAn7eJ0Lxv0ZmFhCBcwmi39psIYEySBoJZ\/97GdzN2qajFWTxu4aGssifOnyuWAtde\/evTZ5pNr7ybH0h3Bncu\/c1ecQoVaPcSUtoKUxWdBYvAE3g9FOPE5usxBgQ5KNSS4KcesNE3nbtm124MCBqfqyZa+EzSfWUMN5MM4nLkIdJ\/pDbtvvQnDtdcjVq7oJRoB1xmlZ9uAxQKabN282NpueeuopomohE0uofEDY5WYNJUaStDhO4elHgLXTVqul28qm81F3RtWNTMf9GZhoQmVThqMUjjR+jlU0Yed7586dxgHn8AvF18\/qsp7kz2VUrmvo3E4WtkmY9WXM4TB+Gv2QzapVq4zTAOH4sFriUzFh+qT4GV83zXTcn4GJJVQW3fmAfPGLXzRIBcH\/mc98ZsGxikn5sPTTT87f8oWyf\/\/+djHG\/\/nPf759\/SHYtCMb9oc1w6bfVsZ6KWbwE0880VkvhVyffPJJAxswmtSPBSdYeKGD8RWZ+YyPcbKPwLgZK+6obqybWEIFOHa4Aeyuu+4yBH9T3pRi4kCm7N5yLMbHDyZgAxZNFDYnwIDzquCC27TbyiAbNHK+WB0DMAGbSf5MQJK80IHLuEIJjwwyTsbLsycP7qg+AxNLqHwwIA52M9ntRvATR1oTBFI9duxY59XTJo2fUw7sZueZ8UwoPg8uhKfx89ANA0jVx487DRgwXsaSJ\/FngfGG+QiP4jMw0YQ6CoDUhhAQAkKgLAIi1LJIKZ8QEAL1RKBGvRKh1uhhqCtCQAhMNgIi1Ml+fuq9EBACNUJAhFqjh6GuCAEhsFgExltehDpe\/BvfOge1OYjO8ZZYwss8OGfLiwxh3GLBo67wuM1i61N5ISBC1WegFghwbjA85jLNNyTVAnB1ohIERKiVwKpKF4sAZ2x5I4ZXJhdbl8o3FoGRD1yEOnLI1eAwEeBOg3CpgNcMw\/p5XRGz3vPgJy7M437iSUfwe7xcIVAWARFqWaSUb6QIsLb66quv5v7UCR3xNdWXXnrJuGCY5QKWDXjN0EmVOtByN27c2HmbDH\/eJdwQKPG8shm\/dUN7EiFQBgERahmUlKdyBCBC1yJx+WmXN954I\/cqPjoDiXI5zJ49ezq\/8srrhVw2zI+0Qbj8thgX6HA7EWUQXl+MCdPJdMWKFdaUuyDAomkyivGKUEeBstroiQDaJVqmC4S5bNky4wYxyDGugLVV0rn\/Mkzj6kKI9i\/\/8i+N31by3xoK84R+Ll3+3Oc+14768pe\/bE26C6I9aP0ZKgIi1KHCqcqGhQCXnjz66KMGOXLPbV69aJTcf5mX5nG9Lhvnl2PJC7FyxR1+iRAYFAER6qDIqdzYEeAno7lUO+4ImiuETDyaLG6R3HLLLfb1r3\/duN6Na+F8\/bUov+KnBIGKhiFCrQhYVTscBCDH2KynZjRPtMqzZ88S7Ai386O5\/vIv\/7Jh7hf9TE6nwBUPd4civv56JVqOEOgLARFqX3Ap86gQYKOIW+fZlXdtM2wb8mPDiRvcyUsa2iVaJje2sxYa\/6qB5+HNLE4AEHYh\/65du9pLDFzc7fFyhUA\/CIhQ+0FLeStDIN7lhzAhU3bl8xqFALlQm2NO5OVkAD8pzBtW7PZThpcD+OkLfj6ZdIQ8ECZp5AmFOI5Z8SsIMeGG+eSfNgSGNx4R6vCwVE0DIACJhb864Lv8uCGZOoGGcTQX3kxPPdRHvAvaLcekqA8J81AXaeTx\/NQX5vF4uUKgDAIi1DIoKY8QEAJCoAQCItQSICmLEBACjUFgUQMVoS4KPhUWAkJACFxF4P8DAAD\/\/8od6qYAAAAGSURBVAMAKdHO\/AZhkCoAAAAASUVORK5CYII=","height":302,"width":340}}
%---
%[output:85d28524]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202605\\English_Fig1B_LearningCurve.svg\n","truncated":false}}
%---
%[output:30387fc7]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJcAAACXCAYAAAAYn8l5AAAM1ElEQVR4Aeyd+27UuhbGo3JpS7lMC4i2qEg8yTlvdva\/+8\/9Rmc\/CRIIaAUUcWlpuXTv\/KJZI3dIJontSeLkk2aNb8vL9udvbMeTOBtZlv0jEQbr4ADkyu3qIwTiIyByxcdUFucIiFxzIOTER0Dkio+pLM4RELnmQMiJj4DIFR\/Tfi0OqHSRa0CdMbaqiFxj69EBtUfkGlBnjK0qItfYenRA7RG5BtQZY6uKyDW2Hh1QeyZNrtu3b2dHR0fZ8+fPS+X+\/ftFV+E+efKk8Jd\/NYvd3d3NKLNM+8aNG9nTp08zyipLtzjqUadjuk1cbFEu5TfRb6MzaXIZUMfHx9mLFy9+k8+fPxcquCcnJ4Xf92t7ezu7e\/eub\/Yk84lcSXZbGpUWuRr0E1MH05Gp4meKsymVUYk04t0p1uLJv7+\/n928ebN26mN6YpoyO+TFdpUs65OXOFefMPFmEz9xro75iScdwW\/xPq7I5YNanocpjqmS6fTbt28ZxPr169diamWqffToUbHGYlol\/PPnz+z169cZ4dxE6Wc2m2Wnp6eFHXQfPHhQuQ5j\/XZ4eJhdXl4W+tQFP0Q2YpjOly9fFjr4XR2rCHmIxwZl0x5L83FFLh\/U8jwQ6vv377kvy+gURiULE0n6q1evMjeO+Dqh48mLHnk\/ffqU3bt3ryiDOFcY1dB5\/\/79Ivrjx4+Ff2dnp3C3traKOriExr9MHtoAsfgBuPYKI55fIlcOHKDalGEuo06eVPmhUy2RXzi\/9ocPHxYjmMX7uGdnZ9eyXVxcFGE6v\/A4X8RRthOVEaYuNiXjEufqLPs3Njayx48fF9GxiIWxlMlF\/aMIUxZTiittQUb\/w4cP2Z07dxbbGnUEjVF5l+RV9up0GHXJC8lYS+KPISJXDBTnNphujKAQjemMqWue7OUwOtHpVZlZU5WluaNVlY7lg3z8wPiBUGdGO0sLcUWuEPRW5IVorJ\/qOnbZxK1bt65FEb66uiqmu2sJeQACQb7cu\/gQ3tzcLNZZRJbpEF8mrPXOz88rLyDK8qyKE7lWodMwjQ7l0t0dpSAVI8DyGqrOJOs28qGHDa4WISkkIc4VCIyOO\/3atGblmo5bN+yzjUJe1x5+LgiId\/WJ9xGRywe1pTx0PNMKU4pdEEA2rvQYDVDHZfoh3iUDaa4wNe3t7RXrNnQJQxBXx\/zYe\/PmTcZIZeVCdPdK0HTculE+2yikmS1ziaOukBqSWbyPu+GTaYh5AOLg4KD0kr2qvgDJdgFgVukQT+fSGfgR\/MThN4FgdKqtuXCXdchHPISxfOZafkYp185y3bDh2rV82EVIN5vmLuvQZtpOOrYoDx3CCPVzdYjzkVGQi18rl9KrFr4+4ChPGAKtyRVWXPzcrB+ePXtW7ITHty6LIQgkTS6IxQYol\/1ICBDKGx+BpMnFeoR1BuuG+NDIYigCSZMrtPHKv14ERK714jtp65Mkl200TrrnO2j8JMk1m806gDaVItZXz0mSa31wyrKLgMjloiF\/VARErqhwypiLwGjIxV7X8n9kbkPl7x6B0ZCre+hUYh0CIlcdQkr3RkDk8oYuKOMkMotck+jmfhopcvWD+yRKFbkm0c39NFLk6gf3SZQqck2im\/tppMjVD+6TKHVS5JpEjw6okSLXQDqD5wE4hmkg1YlSDZErCoz+RiAVD7Ry1BHPDkIwHlr1tzicnCJXz31hD5nw7CVE43F6pOdqRSle5IoCY5gRSMUj+V+\/fi0OAWEEC7M4jNwi1wD6gVMAeYyf24Y41YajCQZQreAqiFzBEIYb4GwGiMWI9fbt28XxR+GW+7WwfnL12z6V3iMCIleP4I+9aJFr7D3cY\/uCycUlNIeUsVfDHg1tYZ8mxsl02JKki0AQubiE5pD9d+\/eZe4pM+zTcJKdCJYuMWLUPIhckIejGe2UOqsQVz1cWkMwRjaLlzstBLzJBWk4v\/zHjx+liFXFlyorMiUEGtfVm1yMTrzKg02\/stLYGCQdvbJ0xY0fAW9yAQ0bf2Wn\/jJdMiWSjp5kmggEkYs\/XTmqmsNuOT\/dXk0C4Xj6mfRpwqpWg0AQuTDAtAeROD7SJMYx09iWpI1AMLnSbr5qv04EvMnF1SIvFaj6B589MDZX0VtnA2R7uAh4k6uuSVVXkXX5lF6OQIqxrcnFXzv81cOLBbg1l9GJ8LKwwGcjlTVZisCozuEItCYX9x6xcH\/58mV2cXGRLS\/mSTPRVkR4B9Vb+G+u8v8Ggl6u1uGnNbmsboxIY7qxzdqVpvufvNp1kqt0\/PEmF\/VksV41LTJNkoYOupJ1IvB3btyVPFh8yuKKhE6+gsjFee78xcM0yF0RrLHwM1USf3p6WvqG005aNplCmBKZ8kz+cFqO3+LRc5I68HqTixGJJ1ZsF54\/qomjztwlwd0S\/A1EWDJNBLzJZXBBKvyswXjfoRGMxb4bRic5UYWDEPAmF2Ri6rP9LMLUxMiFv60w0rFWQ46OjmrfoUhZrOvQdwU7bctOR59pjumuSki31lTpWLyra3niud7kogpMidz9QCdDLkYx9r5Iw726umq85oIQ2GKLg3Ub0yp\/iGMbe2ViaazxyGMy7i0QCPG\/HI5VkicXH64gV+lhq1Bcy1cQuejEy8vLjIU9tbPbmxlFIAp7YsTXCSRBnwsCSIo+thkZuS+McJmQj3jLg18yHASCyEUzIBCCn062UQSXMPF1YiRhnebqMjLyH6Ub5\/qZkiF303LcvPKvH4EgcvG0D9NZaDWNXGUk4VZqS18uB+Ix4jFSmsSoz3I5Cvsh4E0uOpyOZ53lV3RYLiv\/\/Pw8s7UWoyU3KopgYdjGyu1NLkYZNkn39vYyOjpWhbKsmSXKh0wnJyeLDLa\/xmjWR50WFZGnQMCbXHQexOJ+Lu6QsGnJddkmQK8oqaMvRlLtr3UEdk0x3uSykcOmpDKXkQW9mjostivKiMgVYxMbdWUovXsEvMkVs6pGHvbGXLss2LlidOPMz4jJRis6FofLFSTTI0JY0h8CgyEXe1wsxiENcLAo54Lh7OyM4G8CeSAeU7ONeBCNmxTZI\/stgyI6R2AQ5KLVEIJdedZprNsgGmdQ2KiGDnfBIvgR9tfY57I13\/7+fnZ8fJxBOtIl\/SIwGHIBAwSztVvZ42mQCUHXhLDlwRWxDJn+XSNX\/zVRDUaHgDe5WOfo0bLR8SFqg7zJVVcLrtrqdJQ+bgRak4sFNQtuFtFsHdgCnDhXuGrjCtBdkI8bSrVuGYHW5LIFNPddcRcDG6UspMuEBfpygQpPB4HW5DJoGJH0aJmhIbcMgVbkYhHPNMgGp\/ndqXDZjy56ZQUrbs0IDMB8K3IxWjENMt2Zv2w6tDh00RtAO1WFHhBoRa4e6qciE0agFbmY4pjqlqe\/qjC65EkYH1U9AIFW5GKKY6qzaQ+Xq0b+ROY\/PcKuoEuegPopa8IItCJXwu1U1XtAQOTqAfSpFClyRe1pGXMRELlcNOSPioDIFRVOGXMRELlcNOSPioDI1RBOjuzg+LQ6Qa+hydGrtSIXG6JsjLqbptx6w0MV3L\/uxuNHlzxjQZEzY+pkLG2N0Y5W5GJDlI1Rd6N0lR9d8sSo6BBsuCeM4rc64TexOLlZ1opcAwWsk2oxHTLlmfzhlIrf4tFzkibtFbkm3f3rbbzItV58J21d5KrofqY5prsqId2yVulYvKtreabgilwVvQwhVp0mSppl5QqScJVgy3Sn5IpcU+rtjtsqcnUM+JSK8ybXlEBSW\/0QELn8cFOuBgiIXA1AkoofAiKXH27K1QABkasBSFLxQ0Dk8sNNuRogIHI1AGkaKvFbKXLFx1QW5wiIXHMg5MRHQOSKj6kszhFInlycPc8t1SaE522T0zMCSZMLInGMJrdTc7s151UQ5p7+nnFV8TkCSZOLQ+g4d56DUPK2FC83IEw8YUm\/CCRLLp4qKnt9C69z2dzc7OU1fR5dOeosSZOLnil7ukivxAOZ\/iVZcvUPnWpQh8BkycXbP1bJbHe3DrvG6Vvb29mqstqk7e7OGpdbp7i9vdWoXnV2qtInSS7Oz68CxOL\/3NrKDg8Ooshfs5mZDXa3tv7MCXEYRWazv4Lrs8pAsuSytRYL++UGXl1dLd4+u5xGmPPzJW+zphiAmY8kTS5eUbyzs3Ot3YR5B6OR71qiAp0ikCy5QInz8HkT\/3a+piGMixBPuEoU3w0CSZOLDVN25e2EHVzeTWSbqt1AqFKqEEiaXDQKgvHXjwlh4iX9I5A8ufqHUDWoQkDkqkJG8cEIiFzBEMpAFQIiVxUyig9GoDtyBVdVBlJDQORKrccSqq\/IlVBnpVZVkSu1HkuoviJXQp2VWlVFrtR6LKH6ilwJddbAqlpbHZGrFiIp+CIgcvkip3y1CPwLAAD\/\/\/XCYIAAAAAGSURBVAMAj+e48tBavKYAAAAASUVORK5CYII=","height":151,"width":151}}
%---
%[output:5fd930fe]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202605\\English_Fig1B_FirstSessionPerformance.svg\n","truncated":false}}
%---
