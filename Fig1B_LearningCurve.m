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
	f2 = figure('Color','none', 'Name', 'English Fig1B First-session performance'); %[output:4cd90a67]
		f2.Units = 'centimeters';
		pos2 = f2.Position;
		pos2(3:4) = [4,4];
		f2.Position = pos2; %[output:4cd90a67]
		f2.InvertHardcopy = 'off';
		f2.PaperUnits = 'centimeters';
		f2.PaperSize = [4,4];
		f2.PaperPositionMode = 'auto';

	tiledlayout(1,1,'TileSpacing','normal','Padding','normal'); %[output:4cd90a67]
	nexttile; %[output:4cd90a67]
	[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, CompareGroup, 'AsteriskThreshold', 0.05); %[output:3235e23b] %[output:4cd90a67]
	ax2 = gca;
	ax2.FontSize = 12; %[output:4cd90a67]
	ax2.LineWidth = 2; %[output:4cd90a67]
	ax2.Color = 'none'; %[output:4cd90a67]
	ax2.XAxis.Visible = 'off'; %[output:4cd90a67]
	ax2.XTick = []; %[output:4cd90a67]
	legend(ax2, 'off');

	% Asterisk font size
	if isfield(Optional2, 'MultiCompare') && ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
		for pt = Optional2.MultiCompare.PText(:)'
			pt.FontSize = 12; %[output:4cd90a67]
		end
	end
	if isfield(Optional2, 'MultiCompare') && ismember('PLine', Optional2.MultiCompare.Properties.VariableNames)
		for pl = Optional2.MultiCompare.PLine(:)'
			pl.LineWidth = 2; %[output:4cd90a67]
		end
	end

	% Bar styling – reference palette from 范例 SVGs
	palette2 = TransferLearning.FigurePalette(2);
	colorNaive = palette2(1,:);
	colorTrans = palette2(2,:);
	if numel(Bars2) == 1
		Bars2.FaceColor = 'flat'; %[output:4cd90a67]
		nBars = numel(Bars2.YData);
		reps = ceil(nBars/2);
		Bars2.CData = repmat([colorNaive; colorTrans], reps, 1); %[output:4cd90a67]
		Bars2.CData = Bars2.CData(1:nBars, :); %[output:4cd90a67]
		Bars2.BarWidth = 0.5; %[output:4cd90a67]
		Bars2.LineWidth = 2; %[output:4cd90a67]
		Bars2.EdgeColor = 'none'; %[output:4cd90a67]
		Bars2.FaceAlpha = 1/3; %[output:4cd90a67]
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
		eb.LineWidth = 2; %[output:4cd90a67]
	end
	ax2.XLim = [0.5, 2.5]; %[output:4cd90a67]

	ylabel(ax2, 'Hit rate', 'FontSize', 12); %[output:4cd90a67]
	title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal'); %[output:4cd90a67]
	box(ax2, 'off'); %[output:4cd90a67]

	% Export SVG (transparent)
	svgPath2 = 'English_Fig1B_FirstSessionPerformance.svg';
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
	if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar) %[output:4cd90a67]
		ax2.Toolbar.Visible = 'off'; %[output:4cd90a67]
	end
	svgPath2 = TransferLearning.ExportStandardFigure(f2, 2, svgPath2); %[output:4cd90a67]
	fprintf('Wrote: %s\n', svgPath2); %[output:68fbb553]
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
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAqgAAAJcCAYAAAA1u1ZTAAAQAElEQVR4AeydB7wU5b33f8OhKxoEu0ZBKSoqRGPQoCxiQdRokBvFXFHva4+9xB7X3IiNV2PMNba8GkwQvWg02OuiaBALYgWk2AsI2CjSzju\/B+a4Z87M7szu7O7M7I8P\/ynPPPOU7zPnzO\/8nzKtGvVPBERABERABERABERABGJEoBX0TwREQAREoAIElKQIiIAIiECpBCRQSyWn+0RABERABERABERABCpCoKBArUiOSlQEREAEREAEREAEREAEChCQQC0AR5dEQAREoEIElKwIiIAIiEABAhKoBeDokgiIgAiIgAiIgAiIQPUJlC5Qq19W5SgCIiACIiACIiACIlAHBCRQ66CRVUUREIFkEVBpRUAERKDeCUig1vsToPqLgAiIgAiIgAiIQMwIVEigxqyWKo4IiIAIiIAIiIAIiEBiCEigJqapVFAREAERACAIIiACIlAHBCRQ66CRVUUREAEREAEREAERSBKBWgjUJPFRWUVABERABERABERABKpMQAK1ysCVnQiIgAhUjoBSFgEREIF0EJBATUc7qhYiIAIiIAIiIAIikBoCsROoqSGrioiACIiACIiACIiACJREQAK1JGy6SQREQAQSR0AFFgEREIHEEJBATUxTqaAiIAIiIAIiIAIiUB8EkiVQ66NNVEsREAEREAEREAERqGsCEqh13fyqvAiIgAisIaCtCIiACMSJgARqnFpDZREBERABERABERABEUCKBKpaUwREQAREQAREQAREIA0EJFDT0IqqgwiIgAhUkoDSFgEREIEqE5BArTJwZScCIiACIiACIiACIlCYQL0I1MIUdFUEREAEREAEREAERCA2BCRQY9MUKogIiIAIJJGAyiwCIiAC0ROQQI2eqVIUAREQAREQAREQAREog4AEKoAy+OlWERABERABERABERCBiAlIoEYMVMmJgAiIgAg0EdCBCIiACJREQAK1JGy6SQREQAREQAREQAREoFIEJFCLkdV1ERABERABERABERCBqhKQQK0qbmUmAiIgAiLgENBeBERABPwISKD6kVG4CIiACIiACIiACIhATQhIoJaFXTeLgAiIgAiIgAiIgAhETUACNWqidnrffvstjjjiCHTv3h1PPfWUHaL\/IiACIiACoQgosgiIQF0TkECNuPm\/++47XHbZZZgyZUrEKSs5ERABERABERABEagPAhKoEbbz\/Pnzccopp+CBBx5gqjIREAEREAEREAEREIESCEiglgDNfUtjY6Ppyj\/ggAMwadIk92Wdi4AIiIAIREpAiYmACKSdgARqGS28atUqvPzyyxg2bBhOOOEELFy4sIzUdKsIiIAIiIAIiIAIiAAJSKCSQon2zjvv4LjjjsO0adOaUhgwYACOPvropnO\/A4WLgAiIgAiIgAiIgAh4E5BA9eYSOrRbt264+eabcccdd2DjjTcOfb9uEAEREAERiISAEhEBEUgBAQnUMhrRsiz07dsXt99+O5544gnst99+aGhoKCNF3SoCIiACIiACIiACIiCBWsYz0KdPH\/ztb3\/D3nvvHa0wLaNMulUEREAEREAEREAEkk5AAjXpLajyi0ANCEycCOTb5ZcDflaD4ilLEfAloAsiIALJICCBmox2UilFIDICQYTloEFAvlkWkG+ZDJDJAJkMkMkA2SyQzQLZLJDNAtkskM1C\/0RABERABESgJAISqCVhq8xNN9xwA4488sgWxvAfctSRCJRGgB5OisxMBshkgEwGyGaBbBbIZoFsFshmgWwWyOWAXA7I5YBcrrT8dJcIiIAIiIAIlEpAArVUchW476WXXsLkyZMrkLKSrEcCFKQ0ilJaNluPFFRnEQhBwIn63XcA7bPPAMdmzgRKMef+IHvmWSsLUj53nKA8eJ\/DVnsRCEhAAjUgqGpF69+\/P8aOHdvMzjjjjGplr3wSTIBd9xSk7Jp3BGk2W9sK5XK1zV+5i0ALAhSAFEz5RqH16quAYzNmALRPPwUc+\/ZboBRz7g+yZ561siDlc8cJyqNFIyhABIoTkEAtzihJMVTWlBJwv1P5PqWdeCJAoyDNZIBsFsjlag8hkwEyGSCTqX1ZVII6IcAfEppbePIHxRGe3FMAegmtOsGkaopAUghIoCalpVTOuiDAdyvfpzS+Sx1z3qkTJgDZLHDkkUCvXsCtt66xqOBkMkAmA2QyQCYDZLNANgtks0A2C2SzQC4H5HJALgfkckBjY0t79lmAdtllUZVM6YiAiwB\/WGjODwt\/SGj54tPx8LluDXzKH0Dnh+zEtX8N8i\/CQubEL7Zn2nG3YnXIv16MSWDoiigCawhIoK7hoK0I1IwA37E0vqv4bnW\/U513wK67rvGW8pxxSy1wNgtks0AhYUlxSbvsMsBtAwcC+VZqOXSfCAQmkO8Z5cNP4w8LjT8wgRPKi8g0+MPkmCOw+IPmGMOc64wfxJz4xfZMO+5WrA751wuxycOuQxEISkACNSipFMRTFeJDgIKUxt\/pfMfSnNIxjL\/3+e7ie5LHNOd62H02C2SzgCNIL7sMoIVNR\/FFoCoE8sVovneUPyS0IIXgDxGNPziOOT9Q\/KGi8dy5xj3j04KkrzgiIAIVJyCBWnHEykAE1hCgIKXxHcj3LG3NlTXd9HxH5r83Gc+5HmafyQDZLJDLARSll10mQRqGn+JWmQB\/KGheYrSYd5Q\/JBSajvEHiOac84fKMcatXNWUciECuVyhq7omAp4EJFA9sShQBKIh4DiD+G6kIKW5U3ben9y7rwU9P+EEIJsFKEidrvmBA4PerXgiUCUCzg8EBSl\/KGj8oaAVE6P5ReQPC41ClGk4lh9HxyIgAokmIIGa6OaLsPBKKlICfP\/SIeTM2fBKnO9Xx7yuFwrbZReAonTs2DWr4NxyC3DZZYXu0DURqCKBfCHq\/DBQRDo\/EBSkYYvj\/LDQQ+och02j1Pj8gaPxhy7fGBbGSs0\/LveFqaubU1zqoHIkhoAEamKaSgWNOwG+h2l8D\/P9W8gh5LxfuQ9aL+f3\/SuvAM5s\/hEjgE03DZqC4olAhAT8RCh\/APKFaLEfhkJF4g8IrdKilMLL+QHjnn\/x0fjDRuMxjdfyjWEBDE4cplXInHjV3Bcqj\/tamHLlczrnnEKtrGsi4ElAAtUTiwJFIBgBClIa38l8D9MK3Zn\/ri0Uj9ecdybfCXxP8Pd9NgswnKKUxngyEagIAQpQGh9wGrsEaHzYaVGJUHfhmXb+DwqP3XHCnPMHhj88jvEHisYfKsd47lznnvfQwuQTRVzmWW2LotxKQwQqQEACtQJQTzrpJMyZM8fYPvvsU4Ecqp2k8ssnwHc1je9RClJa\/nWvY75jHSeQ1\/X8ML4f+d503pl8X2222Q\/CND+ujkWgLAL5ApQPtVuA5otQdgnQysrQ52b+MDk\/JBxXymOfqL7B\/MGh8QeHP0CO8ZzhjvEHiuabkM+FTp2AsOaTVGqCw\/BITaVVkWoRkECtFmnlk3gCfH\/zPUpBSgtaIb5racXi8\/3Jdyr3TlwJU4eE9pEScB7mfAHKh7pSAtSr8Pxh4g8G\/3IrV5Q6Pzj84SlFfLJ8jtjiDx2NX8KgMT1az55AWON9xYzXmU+cjGUKYkF5rLsuCctEIBQBCdRQuBS5XgnQscT3d5j6O+9e7gvdx\/cA36s0xuO7kcZwdeOTiCwyAo4wDfswR1YAOyH+QEQtSu1ki\/4PKkD5Q0ejqKIVTTiCCMwnThZBlZSECJRLQAK1XIK6P9UE2ANKR08Yx5Lz\/uW+GByKUqcHknEpTPlupPFcJgKREKi1MOUPA72kFKY8Dlsp\/qDQ8j2l7jTiLEDdZdW5CIhAUQISqEURKUK9EuA7nT2gYerPdy+t2D3571onLnv4JEwdGtpHQoAPMf\/CqobHlPnw4XfMEaSOKOX1MJXiDwmtkChlevyrjuZ0N\/OHiOZ4JBknsaaCi0D9EpBArd+2V80LEOB7Pcw7ne9k5z1cIFmzdmm+x5Rx6fhhdz7fpzyXiUDZBPgAUxCGeYiDZMo0+bDTKEBpfPBpPGa4Y4wbJM38OBSktGKilPdQlPIHh2KUxjCZCIhAaghIoKamKeNZkSSWiu\/2oO91vov5bua+WF353qXxnerE5TuWjh\/nXHsRKIsAH14Kw6APsDsz3kvjA02j6OQD7hjPGU5jPJo7jbDn\/KGgBRGlTJs\/NPwhkiglDZkIpJaABGpqm1YVK4VA0MlQfD877+pi+eS\/e\/Pj8j2rd2w+ER2XTCCMMKWo5APsGB\/kfAHKc+ca45ZcqAI38oeCFlSUMin+wEiYkoRj2otAqglIoKa6eVW5oAQ4GYriNMhkqKDv7vz3r7scfNdKnLqp6Dw0gTDC1Ek8X4DyYa6UCHXyc\/YUl\/k\/FDx2rhXa84eF9+oHphAlXROB1BGQQE1dkyaoQjEpKt\/xnAxVTJzyXU5HE\/fFis53L80dj+NNNRnKTUXnoQnwoaWwDNOVz\/gUp6EzK+EGCkrH+INAT6l78HWxZCVMixHSdRFINQEJ1FQ3rypXjADf88Xe8RSkYYQp38V8J7vz5vuW4001GcpNRueBCfCBpdAs9tC6E+RDTHHKe93XSjnPF5982Ck++eA7xnPHeD1oHvwhoTF9eUyDUvOMp0ARSDoBCdSkt6DKXzIBvuuLvef5XqcVy4TvYL6bufeKy3eu3rdeZBQWiAAfVorLYg+sV2J8gGle1wqFUSTygXaMgpMPOY3HNOca4xZKq9g1\/oDQ+ENCKxZf10VABFJPQAI19U2c1ApWttx83wd51xd7r\/O97Lyj\/UrsvHf9ritcBHwJ8EEtR5gGcf07DzD3FJ0UoDQeM8wxPuy+BS3xAn84nDEvEqYlQtRtIpBOAhKo6WxX1aoAAU6GCiJO2SNaIBnPNU3d8Z13rztc5yJQkEA5wpQJ8y8rGo\/9jMKTQpR7xyohQr3ypzBlXhSlGvPiRaiyYUpdBBJAQAI1AY2kIkZDgDP16YwqNhmKufHdzrg8dhvf5c573X3NOedkKL5\/9e51iGgfmADFaZC\/oLwS5IMbxmvqlUYlw\/KFaSXzUdoiIAKJJyCBmvgmrMsKhK403\/mcqR\/kRgpTvue94lKc0ryuOWF8B3MylHOuvQgEJsC\/osoRp34PrlMAPrzF\/rpy4ka55w8F\/2KjxzTKdJWWCIhAaglIoKa2aVUxhwDFaZh3vl\/XPt+vfL876Xrt+R7WO9iLjMICEQjzoDoJUpTGwWvKbgP+ANA4toXGHxqafiic1krAXkUUgXgQkECNRzuoFBUiEJU4ZfE4Z4R7P+N7We9hPzoKL0qAg6ODjD\/JT4jilJYf5j7mX1VReE0pQGl80Gn5ApQilN0G\/AGgcWwLzV0WnYuACIhAQAISqAFBKVpyCDgl5fs+jEOK73l27zv35+8LiVO+s\/mu5ns5\/x4di0BgAvxLKow45cNaCa8pH2aKT8f4YFN80ihAaXzQaRKggZtXEUVABMITkEANz0x3xJwAeFqn2wAAEABJREFUh\/FRaIZ53zM+3\/leVaMDiu9nr2t8j\/OdrXe1Fx2FBSLABzbsX1J+D6uTIR\/aYl5TPrw0twil+HRMD7ZDVPs1BLQVgaoRkECtGmplVA0CdEQFnQzllIfitJRxp3y38z3upKO9CJREIKg4pSiNymvqPLx8gCVCS2o23SQCIlBZAhKoleWr1KtIgOK06Lveozx873sEg15Tv6595\/3udZ\/CRCAwAT60QVz9fEhphRIO4jXl\/Xp4SUEmAiIQcwISqDFvIBUvGAG+50sVp\/SgeuXC971XOHtE6XjyuqYwEQhMIMhDS1EaldeUBZM4JQVZhQgoWRGIkoAEapQ0lVZNCAR5z3sVjMKU73+vaxSn9KDmX+P8EYapRzSfio5LIhBk3CkfTlqhDPigFhtr6tyvv6wcEtqLgAgkgIAEagIaSUX0JxB2pr6TEsVpy3Gna67ynU9bc7ZmS3HKyVBrzrQVgTIJFHL3Ow9nEHHqflC9isWHV39ZeZFRmAiIQIwJSKDGuHFUtMIEKE6DDN\/zSsXv3c\/3uNc7nz2jXukorAgBurfZUDQe03PoWJFbU3uZHPweXD6Y\/MuJItUPAB9SDo72elDd9\/DB1V9Wbio6rwUB5SkCIQlIoIYEpujxIEC94\/eOL1ZCagC\/97\/XO58OKHXrF6PqcZ1ClJ5CNhSNx1xiwTE2Ao2N6RjFG+9zzCPZRAexXuTgrgQ5UJjy4XRfyz\/nA0pxSpGaH+51THGqwdJeZBQmAiKQAAISqAloJBWxOQFqGeqd5qHBzvj+p3nF5rvf673P9zwAr1sUVoiAlxDzis\/GdIz3OAKWewo3GhvdsaSKWIpT1smLAetI87rGMD6YFKZ8SHlezPjQSpwWo6TrIiACMSYggRrjxlHRWhKgRqGWaXmleAjf\/4XEqde7X97T4lw9Y1BEltpQXgkyLce8RCwfDApAr3vjEsZyl1IWPpgUpxSpQe7XZKgglBQnVgRUGBFoSUACtSUThcSQALUHNQg1SqnF8xOnfO9TA3ilS0eUV7jCChBgY5UqxgokW\/ASHwx6J5l3wYg1ulhMsPs9nBSmfg+nuyr8a4riVONR3GR0LgIikEACEqgJbLR6KzI1B7UHNUipdef7nx5Ur\/v93v8Up0Hf9V7p1m1YtcVpPmg+KBSD+WG1PuYDXIgJH06vMvLB5F9PXtfcYRSnnAylB9ZNRuciIAIJJSCBmtCGq5di891OzVFOffn+p3mlQQeVnwbQED4vYkXCKA7L+UuiSPKBLlMMshyBIlc4UpAH2O\/hpEANUjz+JUVxGiSu4ohA8gioxHVKQAK1Ths+CdUO8m4vVg96TQu9\/\/3EKd\/5xdLWdRcBNhjFoSu4JqcsB8eEsEw1KcDaTFmOtYeeO87c97oQRpzqLykvggoTARFIOAEJ1IQ3YFqLT11RrueUbPzEKYWpnwZgb2mk73wWpB6smBirNgN6cvkQ8WGqdt7Mj15cloHHXsa\/nmhe1\/wezvy4\/CtKD2o+ER2LgAikiIAEaooaMy1VoZ6grii3PnRO+b3\/2bXvlz7f+37XFO5DoJgY87mtKsF8mFi+qmS2NhM+xMUEu99fT0HEKSdDSZyuha1dPRNQ3dNLQAI1vW2byJpRR1BPlFt4vvtLEaf0nmqeSUj6QcRYyCQjj06xyIcr8oR9Eiz2EPPhpLlvL+TaZ1w+oIyjh5Q0ZCIgAikmIIGa4sZNWtWoH6gjyi033\/sUqF7p0DnF97vXNYZV33vKXBNuUTRaNRCwnByXWum8guRR6AH1Kx8fTk2G8qOjcBEQgZQRkEBNWYMmtTpRiVPWn1373LuNwpQC1R3unNM5JceUQyPgnt7TQuMsAyZTtWgsK\/+CYbkrkSkfZOZRKG3mT3PH4QNKc4fznOJUXfokIROB4AQUM9EEJFAT3XzpKDzf6XRuRVEbP3HKtAuNO+V1agDuZSEIFOvKDpFUVaOy3HzwosyUojfIgxzWe8oHU+I0ypZSWiIgAgkgIIGagEZKcxGpEYK804Mw4HvfyzHFe4OI0xh6T1n0+FqQruz4lh7gg8cHMKoyMr1iafEBpbnj0XNKc4dLnLqJ6FwERKBOCEig1klDx7Ga1AZB3ulBys53PgWqV1x263u9+\/PjykGVTyPAMb2FxbqyAyRT8yh8AKMQ2kwjCI9CD6kbhmbqu4noXAQiJKCk4k5AAjXuLZTS8kUtTv269ilMKVALYaQOKHRd1zwIUNh5BCcyiMKSf+FQdJdSAT7MTKPYvcyD5o7Hh5SWH85zufTziehYBESgzghIoNZZg8ehunyfR6lv\/JxSfMcX69pP8sSomrUlGzCIIKtZAUvMuJRxqRS1QR9mvwfV\/RcUH8oSq6DbREAERCAtBCRQ09KSCakHtU3Q93mQKvGd7+WU4r3u9z7D3MYhfu4wnRcgEEaQFUgmtpf4cPIhDVpAxg8Slw8pzR2Xf0XR8sP1UObT0LEI1IKA8owBAQnUGDRCvRSB7\/2g7\/MgTPi+p0D1iktx6n7vu+PRUaVeVDeVIudRNmCRrGp2mXXkmNJiBWCcoJ7kQg9qfj56KPNp6FgERKCOCUig1nHjV7PqUYtTvu\/9xp1SnNKK1S\/VjqpilS\/lOhsxqCArJf043cN68i8geoy9yhWGBR9WpuVOh39B0fLD9VDm09CxCIhAHROQQK3jxq9W1fkup1Mqqvz4vqd5pcf3fRBxKkeVF70CYRRqYRqRfz24jY3mGAVbvhXIuqaXvMalhmXBOntVwv2g6qH0oqQwEYgdARWoOgQkUKvDuW5zqaY4JWT3O59hXqYvRnpRKRAWRpwymXzx6RxTqDnmFq+77go45r7m3MO9k5azd\/LiPTyuhLHufJCdtHnuHBfbs8xecfig8q+p\/GsUqPnnOhYBERCBOiYggVrHjV\/pqvOdHuZdXqw8fNfT\/OJ5vfO94qoX1YtKgTA2JLu8C0RpdonisVlAyBPen29sdMcoRPONopbnjM99yKwCR+eDzDGnYVmw3F6Z8GF1h0uguonoXAREoI4JSKDWceNXuuphNE2xsvA9T\/OLx\/c9ze+6E04NoEX5HRoB9mG7s5lkoYbi9UpZpUUqH2gK1aDl9+Pg9aDywdSMvaBkFU8E4ktAJYuMgARqZCiVUKUI8D1P80uf73ua3\/X8cHlP82kEOA4jyJgcRSKNx7Uw5l1JT2rQOrEcfg+t18OqBzMoWcUTARGoEwISqHXS0LWoJh1O5ebLdzzNLx0uxO\/1vveKLyeVF5UWYT8EhO3O5p1+jcXxljTGqbRRHNZapPpx8HpY9WBW+olQ+iIgAgkkIIGawEZLQpHZM1xuOakx\/N7zTJviNIzmkZOK1AIaGzAq7ykbiY1Fe+UVIN8Ylm8UcI7xvnwLWHQTrZYilXnTTEHyNqwL65YXZA71YBoM2ohA+gmohmEISKCGoaW4gQmU6z2lOPV6x7MAfM9T43DP8yAmJ1UQSnlxwopT3ur314SXKGN8Ghsx3xjXsXzhymM2umM8d4zxmZbb+ADxQXKHV\/o8LAeNPa10iyh9ERCBBBKQQE1goyWhyOUIVGoKaguvelLLUJd4XSsUJidVITqua\/Se+jSgK+YPpxRlXo3GBqP9EDOaI6bpGAUqzStllokPlNe1SoQxP5o7baes7nD+5eQO07kIiIAIiAAkUPUQVIRAWH3DQvC9zlWDuOe52\/iOL1WcyknlplngnIvTF7jseYkC1etCKQ3mlU6xMApUmlc8PlDVEql+HPzKpr+cvFpMYSJQjwRUZxcBCVQXEJ2WT4AOuLCpFNMQfL+XqnW0rFSI1uBanyGim6h+4o+NZiJUacP8aF7ZFXvAvO4JG8Y8aO77+JcVzR1O76n+cnJT0bkIiIAIGAISqAaDNrUkQKeTn8Zhuag5aDwOa3JQhSDGvyzCur4pyGjMxm2lNpo7nTDnzJPmdQ\/LWehB87onTBgfZK\/4fuXRw+lFS2EiIAIiYAhIoBoM2kRJIMz8Gr7TaX75891O87teKJwOKnlPCxFyXUti176rCuaUDwzNnLg2lRKpTJfmyg70nNLc4TyX95QUZCIgAgEI1GMUCdR6bPWY1JnClOZXHGoMmt\/1YuFyUBUjlHe9lK59CjJaXjLmkIKMZk5qtOGDQ\/PKnmWO2pPq9yD7lYF\/PXmVTWEiIAIiIAKGgASqwaBNlASC9BLzfU7zy5fvdZrf9WLhfP\/LQVWM0trrpXTt81a\/BvRsON5QZWM5aF7ZRilSmRbNnQ9FOs0dznP99UQKMhEQARHwJSCB6otGF0ohQK1T7D7qGppfPGoKmt\/1IOF6\/wehtDZOmDEZa28BBRnNOXf2FGQ057zWez5INK9ysPxReFL9Hma\/fPXXk1drKEwERKBUAim9TwI1pQ0b12rxXU7zKx9n6vu91\/3ucYfr\/e8mUuC8lM+ZMjm\/Riy38Zh21MYy0bzSLVek8n6aO22KdJo7nOf664kUZCIgAiJQkIAEakE8uhiWQCFnHDUNzS9NilO\/d7rfPV7hev97UfEIo7u7UIN53GKC2IhhRZm50XdT+QsUqDSvnFiXUj2pfvf55cX8NfaEFGQiIAIiUJCABGpBPLoYFQG+x6lr\/NKLUpzq\/e9H2RVeijhlEn4NWUiU8b5aG8tH8ypHKSLVjwP\/yqJ55UP3vle4wkRABESgIgSSm6gEanLbLpYl95ogRXHK979Xgfkef+UVmNV4vK6HCeO7X8tKBSRWia59NmbA7GsWjQKV5lUAPqR8WL2ueYX5CVS\/9JmG3PukIBMBERCBogQkUIsiUoSgBNhj7I7L9z3f++5wnlPP0HPK4yhM7\/6AFNlQpXhP2ZCliLKAxfKLFnk4BSTNK2HWkQ+t17X8sEIc+GDnx3WO+ReU3PsODe1FQAREoCABCdSCeHQxDIF87ynf87vuCjPZ2ysNvsOjFKd693tR9gkrRZwyqUKijNeTZBSoNK8y8+EtJFJ5vRQW+gvKi7bCREAEakcg1jlLoMa6eZJVOEeg8v1d6P1OXRClOCUlvftJIYCV2rXPRqW5s+BfGmxQd3gSzllumldZWVe\/h7gUcaq\/oLwoK0wEREAEfAlIoPqi0YVSCPDd7fdeZ3rUAzQeR2V69wckWWrXPpNnw3Lvtqgb051+sfNyr7P8NK90vEQqw2he8f3SYVw+pNzLREAEREAEAhGQQA2ESZGCEKAH1U\/H8H6+v2k8jsr43u\/ZM6rUUp7OjBmlVZCCjOa+m95Tmjs8aed8KGle5Wa98\/\/i8nvAi3UJ8EH1Sl9hIiACIhBTArUulgRqrVsgJfnTOceq+L3nGU5jnKiM3foSpwFpzpwZMKJHND9RFnWDemRdtSDWheaVoSNSuae541Ck09zhzjnFqSZHOTS0FwEREIFABFIrUL+zFdOYMWMwdOhQ9OjRA927d8eOO+6I448\/HlOnTkVjY2MgQEEizZkzBxdffDH22GMPkw\/z6tevX0XyClKeWsSh99QvX767\/d79fjvnpMIAABAASURBVPcUC6c41ZJSxSitvV7quFPeTkFG43G+sVFp+WF+xxRofuZ3TyThIRPhQ0rzuo0M8j2p+XH87nHi8GF1jrUXAREQAREIRKBVoFgJi\/Tee+9h+PDhyGazmD59OlatWmVqsHjxYjz99NPm2iWXXIKlS5ea8FI3TPdW27u0\/\/774+6778bnn3\/elNTXX3\/dlNcZZ5yBbwspuKa7knvgVI\/v8UrXgu97idOAlO0\/1FDqrH1mYT\/f3LWwYqLMuaFXL4Bubj+jyA1qTMvP+FA4eZazZ71oQdNwyu4Xn8Jc3lM\/OgoXARFIKoEqlDt1AvWTTz7BKaecgplruzR79+5thOoNN9yAYcOGoW3btsZ7SkF57bXXmuNSOY8bNw5XX321EcCWZRkP6pVXXgnmdcQRR2CdddYx6T\/00ENg+IoVK0rNKvb3FRKofIdHVQHqEInTEDTLFadef3GwQWnFihG1OKPQ8zM+FHw4ipUpyHUKVFrQuIXiRVWmQnnomgiIgAikkECqBOrKlSvxl7\/8BbNnz4ZlWTjuuOPw4IMPYuTIkTj44IMxevRoTJgwAd26dTNNOX78eEyZMsUch9189NFHuPnmm40Apej94x\/\/iLvuuguHH364yWvUqFG4\/\/77m\/K677778OKLL4bNJhHx6aRjQb20DMODaBnGK2Z811OHFIun62sJlNO1zyTK9Z6ywZhOtYwPB0VxsPwKx6JApRWKxQebVigOBXWh67omAiIgAiLgSSBVApXC9PHHHzcV3WmnnXDyySejTZs25tzZcDwqu\/4pKjlOdezYsaCwda4H3c+aNcvuOf3URKe39KCDDjKi2ASs3TCvM88804TTe\/rYY4+tvVJfu2Lv8CA02LNL\/REkruLYBPhXQ7neUzuZFv8p2oI0KIViLcQZhxK0KHSJAawrze\/2Qtd4DxlwLxMBERCBuiIQTWVTJVBfeeUVLFiwwJD55S9\/ic6dO5tj92bXXXdF\/\/79TTDv+bSEF\/mMGTOM95SJbLLJJkaE8thtW2+9NdZd+6L+4IMPQFHsjpP0cwefl8MtiJYpVH++45nGWoSFoupaPgGnUfLDgh7TFe7VmLy\/mChjHFq1vafM0zH+NeMcl7vnw+eVBsNpXtecsFoycMqgvQiIgAgklEBqBCq9oP\/+979NM3SyVQ1n0ZsTj02HDh3Qp08fc4UTm+h5NSchNltttVVT7EKic\/Xq1U1CdoMNNkD79u2b7tNBYQJ2M5r5NYVj6WoLArXu2mfD1fIvCuZdpjhsYkoRyjVOuW8KtA+KCfVaM7CLqP8iIAIikGQCqRGonKHPCVJsjB\/96EfYeOONeehrO+ywg7nG5aboDTUnITa9bC8NPae8hcMKnLx57hi79e+5554mr+luu+2G1q1bO5dTs6\/EBCnqiyh7a1MDu1hFyu3ap\/eU5s6HAq2YKHPuYeM5x7XaczxIVOVg3SlSaTx2rFDdosq7UB66JgIiIALJIxC4xKkRqN9\/\/z0WLlxoKr755pujY8eO5thv07Vr1yZvJseT+sXzC+dEq2OOOcZ07dMDy4lYEydOBEUpRe\/HH3+M3\/72t6BAZRoDBgwAhx3wOE1GPcT6eGkahvNdzn0Y47ud+iLMPYq7lsCMEr8WtfZ2lNu1HyfPIR8iPkxO3crd82GmSKUVS4te3GJxdF0EREAERMCXQGoE6hdffIGvvvrKt6LuC+xqd0+gcscpdG5ZllmI\/49\/\/CPYdT937lwce+yxoGd1m222wV577WVWEGjVqhWOOuoo\/PnPfwaHHhRKM43X+E4PUy\/qCeqKMPco7loCa5dWW3sWfse\/MmjuO9mINHe41zkb0Cu8VmF8mCiao8y\/WFrVzq9YeXRdBERABBJIIDUCNZ\/9ZvZL0pmYlB\/ud0xhSw+s3\/VC4RxKQG9qQ0ODZzSWhV37XBPVM0LCA525OF6Ot6CaxkFgNxuoJ5xz7UMQKHfcKbPyakSGB+3aZ9w4eg6rPVaEDzJZyERABERABEIRyI+cSoGaX8Egx0uWLDFd80HiOnHYlc\/F90eMGIFX13qd9ttvP7MgPxfqZzhFMtdLPe200\/Bf\/\/VfWLRokXO7737y5MlmoX+m4dhLL73kGz8tF\/hOlzgtsTU5zsL5S6HEJOyHGMbc9\/OvDJo73OucjegVHoewXr2qUwp6T+Mo0qtTe+UiAiIgApERkEC1UXK8atju\/nvvvRd\/\/etfzQx9elAfeeQRs3C\/s1D\/FVdcgUmTJuHQQw+1cwCef\/55\/O53vwskhB1hmr83icRwU2iCVFDHG7WDxGkZjVuuOGXWpX5nnvc6FudGpGishoDebDOHhvYiIAIiIAJlEEilQOW6poWWfnLz4qz\/du3auYN9z+fPn2++GsXJUBxXyi9UcVF+9w3rrbceLr\/8crCLn9eefPJJ20n1Kg99jeuzzpkzB\/nGjwn43lDDC3TcMfu1DmQehjI6m+ico3YIdaMi\/0Cg0l37bKAfcvM\/qob488892BUK6EqXUw9zsLZQLBEQAREoQqCFQC0SP7aXORaUQjNoAZctW9bkzQzrPX3\/\/ffx4Ycfmqz23HNP7LjjjubYa0MByy9N8dry5cuNV5XHaTDHe+pXl0LahuK02kMD\/cqZ2HD+hVCu95R\/XUQx9pTiLwkgWc5KidRKpZsEriqjCIiACERMIDUClR5QzqYnH87oX7p0KQ997csvvwRFKiPkL7rP82L29ddfN93bu3fvomubclY\/hSrT5YcBuE+DOQLVS98UEqd8j0ucRvAElCtOWQSvxmN40PEZjMu\/NrhPilGkVqLMxdNMCiGVUwREQARqTiA1ApWz5Ln+KYlyVj674XnsZ2+\/\/ba5ZFmWWRrKnGhTcQIUp9QHFc8o7RlE0bVP7ynNzYp\/XYQRqGxUdxpxP4\/6LySKU3Xvx73VVT4REIEEEQgnUGNcMX6haffddzcl5Gz5mQXWhOT41Ndee83E5deg6OE0JwE366+\/ftMi\/6+88gqKeWu5kP+3a92Njic1YFaxjra2SvDSOF76hjpG4jSCJo2ia5\/FiMp7mlRhxtl55BCF8eGOIh2lIQIiIAIiYAikRqCyNrvuuiu6dOnCQ4wbNw6OKDQBeZupU6fCEai8h2uV5l0uekhBu\/XWW5t4TOeNN94wx14bloFl4TWOdc1kMjxMvFEjsRJe4pThbuP7W+LUTaXE83K\/FsVs2XA0Hucbvae0\/LBCx2zYQtfjfI3COoryR+Q9jTMqlU0EREAEqk0gVQKVwnGfffYxDKdMmYJRo0a18G6+9957yGaz4IQlrlN65JFHFh1DahLM23Cs669\/\/WvzmVN6Yy+66CK8++67eTHWHNKzyjKwLAzhDP1dwrz8eVNMzfGe+hUvv5p0VEmc+pEKGV6gZyBUSvXuPXVg8cEsV6SWe79TFu1FQAREQASaCEQoUJvSrNkBu\/lPPfVUUKiyEPfccw+GDBmCm266CRMmTACF5LBhwzB37lxexvDhw5uWgDIBazcUnRSu3bt3B+3mm29ee+WHHdNx1jhler\/4xS8wcuRIME\/m9fvf\/x6DBg0y57xrww03xNlnnw2KYp4n3RyB6qVz3OKUjqqk1zcW5Y9i3CkrQs8pjcf5xoaj5YcVOk6LMCtXpOoBL\/SU6JoIiIAIlEQgVQKVBDhR6vrrrwcXz+c5v+TEdUrPOOMM0+2\/ePFi4\/nkl57OO+88c8x4Ya1Dhw5mjdPDDjvMpLFq1SqzhNSFF14I5nXnnXdi3rx5JtmePXvi73\/\/O3beeWdznoaNI1AL1YX6Re\/uQoRCXOOYiihm7TNLr78qGO41cJjhXpa2bm2KVNbJq66Fwkq5p1B6ftcULgIiIAJ1RiB1ApXt16dPHzz44IOmK5\/LQDU0NDAYnOk\/ePBgjB8\/Hn\/4wx9AkWkulLihN\/Saa67Bo48+CgpeTrhykmJeXKD\/VlsM0KPqtZC\/Ezdpe2olp8xejjhH5+jd7VCKYB+lOPVqNHpOaUGLyr8+gsZNSjz7D8nQRU0jh9AQdIMIiIAIRE+gWgI1+pIXSZHikV3ujzzyCDjulF9mevPNN3HbbbehX79+xuvplwTv5debeA\/tpJNO8otq0qGH9IorrsCLL77Y9AUo5sXJURwTy8lRvgkk+IKXzsmvjryn+TTKOI6ya9\/+g8mzJM5fFZ4XXYH8yyOtjcsB067q+p6mmYNvpXVBBERABKpDILUCtTr46jMXx5nnJ1DpiOO7uz7pRFxruqsd4OUmXUicstGCpp9mryGFd9D6BY0XlGvJ8XSjCIiACKSPgARq+tq0ajXyEqhhdE7VCprkjKIUp14NRjbynpLCD8bxqEHEJ8XsD3fpSAREQAREIEICsRCoEdZHSVWBQJAJUvKgRtAQcevaZ5WCCDfGS7oVE6l6wJPewiq\/CIhAzAlIoMa8geJWPPY4O2Xycsg5zji9vx1KJe4JOkrvqVcx2Fg0r2teYWzUevIaUqSyzl4skiPUvUqvMBEQARGIPQEJ1Ng3UTwL6CVO80taTzomv96RHUclTk88EZ7fouVYjDDilBWrR1HmNbOfolUPOJ8ImQiIgAhUjED8BWrFqq6ESyHg6CY\/gUrdw\/d3KWnrnrUE+LWoIOMo1kb33XFSlF9DhRWnbNR6FWXumf31KNR9HzJdEAEREIHKEJBArQzX1KfqpXsoTlNf8UpXkF37UYhTNhAFqld5KU7DNlY9izIK8\/z689yLawLDVGQREAERiCsBCdS4tkxMy+VoJ+ofdxEdzUNnm\/uazgMQoDidMSNAxABR\/MQpG4kCNUASzaLUuyjjeFSKVD3czR4LnYiACIhApQgkXKBWCovS9SJA\/cRwL3HKcGof7vUOJ4USzBk\/UcKtzW6hOPVrpFLEKYVZswzq9IQi1WtMap3iULVFQAREoJIEJFArSTdlaTve02LVqndnWzE+ntersaTULbcAzl8RnoXwCaQw87mk4BQTUNVEQAREoIYEJFBrCD9pWTsC1c85R+0j72kJrUrXdJTeU68i0HPKBvK6VihM3tNCdHRNBERABESgQgTSLFArhEzJegnUUrSPSK4lEKU49WscCtS12YXayXsaCpcii4AIiIAIRENAAjUajnWRSiEPqiNQ5UEN+ShUo2u\/VHGqxgzZmPUUXXUVAREQgcoSkECtLN\/UpM5eaFbGy0HHcAlUUghphBqF95SNwgX5vbKnOHUax+t6oTB17xeio2siIAIiIAIVJFC3ArWCTFOZtOM99auco4E0QcqPkEd4FOKUyXLWPvduY6NQoLrDg5zTe6rGDEJKcURABERABCpAQAK1AlDTmKQjUL20EHUQ60xNw70sAIGouvbZIPSgemVZqjhlWvKekoKsNAK6SwREQATKJiCBWjbC+kjAEaj1UdsK1zLKrn0KVK\/iUpw6fzl4XS8Uxr805D0tREjXREAEREAEKkxAAtULsMKaEaCecgK8nHWODqKuceJpX4BAXL8W5RRZ3lOHhPYiIAKUiEC6AAAQAElEQVQiIAI1IiCBWiPwSczWS5yyHhKopBDQZs4MGLFINHpOvRqEjcEF+Yvc7nuZf2XIe+qLRxfKJ6AUREAERCAIAQnUIJTqPE6xuTzUREQkXUMKBSyqcacUphSoXlmxa98rPGiYvKdBSSmeCIiACIhABQlIoIaGW783eGkiR5zS8Va\/ZALUnOMkiin9AMmYKJVYUooJsxH1VwZJyERABERABGpMQAK1xg2QhOw1QSqCVqq0OOVfCvKeRtBQSqKmBJS5CIiACKwlIIG6FoR23gTo+HOusGfZOXb2jiai880J095FIKqufbqwvRqB2TkNweNSjA0o72kp5HSPCIiACIhABQhIoEYLNbWp+ekip8LUN86x9nkEqPCj8J6yAShQ85JuOqQ4pQe1KaCEA409LQGabhEBERABEagUAQnUSpFNSbrFtJWji+R882nwYgB9bmsR7CdO2QAUqC1uCBHAvy7UgCGAKWptCChXERCBeiIggVpPrV1GXb30EbURk6S+4V7mIlCNrv1ylpRyiivvqUNCexEQAREQgZgQkECtYkMkMStNkCqx1arRtR+FOOVfF\/KeltjIuk0EREAERKBSBCRQK0U2BelSYznV4BBI59jZOz3L1DhOmPZrCVT6a1GE77iw12ZZ0k7e05Kw6abYEVCBREAEUkZAAjVlDRpldRzvqZc4zc9HAjWfhn0c1deiuN6pF3wKUwpUO6uy\/8t7WjZCJSACIiACIhA9AQnU6JmWlmIM73IEql\/RqJN4TRqHFNZaNcadRiVO5T1d22jaiYAIiIAIxI2ABGrcWiSG5dEEqYCNwjERUczap9fUCzqLQXHq\/GXA83Js003LuVv3ikBiCKigIiACySMggZq8NqtaiYt5UKtWkKRkFIU4ZV39xCmFKQUq45Rr8p6WS1D3i4AIiIAIVJCABGoF4UaXdPVTojPQyZUOPefY2Ts6SeNP1xJJUtc+G03e07UNp50IiIAIiEAcCUigxrFVYlAmx3vqJU7zi0etk3\/O44kTJ8JtDE+tUc1H4T0lbD\/vKZeUoge1XIhssJ49y01F94tAegioJiIgArEkIIEay2apfaGKCVRHK3lNkMpkMsi4jIK19rWqUAmiEKcsmp84pbvaAc545Zi69suhp3tFQAREQASqREACtUqgK5hNRZIuJFAdrURnXEUyT1Kile7aJ2wK1CiYUJx6\/UURRdpKQwREQAREQAQiJCCBGiHMtCTFHuu01KWi9SCoKLynhbr2oxKn\/GtC404r+jgo8TQSUJ1EQARqRUACtVbkE5IvtZO7qI5mouZxX6ur8yjEKYGpa58UZCIgAiIgAiLQREACtQlFOg9KqZWju7zEaX56dS1Qk9S136sXoK79\/EdXxyIgAiIgAjEnIIEa8waqZfH8BCqHRbJcdat5ktS1r3GnfFRlIlAJAkpTBESgggQkUCsIN6lJa4JUkZabMaNIhICXK921Txe3xp0GbAxFEwEREAERiBMBCdQ4tUa1y+KRH52DHsEKcgjMnOkclbene5rmlYozyNfrWpgwek\/DxFdcERABERABEYgJAQnUmDRE3IpB7URzl8vRTnTOua+l\/jyqcacE5ec95YL8vF6uUZzW7RiMcuHpfhEon4BSEAERKI+ABGp5\/FJ3tzNBqljF6k6g0rUcFE4xeBSnXuqfg3tpxe4vdp2No679YpR0XQREQAREIMYEJFBj3Di1LNqrr3rn7uinunPORSVOKUwpUL3wOu5pr2thwnr2DBNbcUVABERABEQgdgQkUGPXJLUtkCZIefCvRtc+xamj\/j2KEDiIS0oFjqyIIiACNSGgTEVABIoSkEAtiqh+IrAX26ktHX3OsbOPQj85aSVmTyhReU\/pOfUDS4FaLhSNOy2XoO4XAREQARGICQEJ1Jg0RByKUch7yvI5ArVTJ\/C0PiwqcUpaFKjcuy0Kcapxp26qOhcBERABEUgwAQnUBDde1EV3BGqxdKmFisVJxfUou\/ZPPNEbCcWpo\/y9YwQLpfc0WEzFEgERiDUBFU4ERIAEJFBJQdaMgFcvNCM4OqouJkhF2bVPoDRCdBsFqjss7DnFaV00Slgwii8CIiACIpBUAhKoSW25CpTb8aB6aSlHnAbxnlagaNVPshpd+1GsecoG0ZJS1X8+lKMIiIAIiEBFCUigVhRvchKnw9ApbSGB6sRJ9Z4wHLVebkU57tQPqKP6y8lDS0qVQ0\/3ikDSCKi8IlA3BCRQ66apC1fU0WNeWop3OlqKvck8T7XNmBFN9QiTAtUrtSi69rWklBdZhYmACIiACKSAgARqChoxiio4AtUvLUeg+l0PHB73iDNnRlfCQuK0XKD8S0HjTqNrK6UkAiIgAiIQKwISqLFqjtoVxhGoXpoqX0ulWhNVq2u\/XO+pxp3W7gdFOYtAjAmoaCKQJgISqGlqzRLrQl0W5FbqoiDxEhsnqq59AvBS+gwvV5wyDXpPuZeJgAiIgAiIQEoJSKCmtGFLrRaHTbrvzfeguq9Fe17D1KLs2vdb85QgaeVUk+I01W7scuDoXhEQAREQgbQQkEBNS0uWUQ9nRSUvccpkHU1FbcTz1BldyM4Yh3IrR4g0r3TKXVaKLmwtKeVFVmEiIALFCOi6CCSMgARqwhqsFsV1BGot8q5KntXo2i9XnBKElpQiBZkIiIAIiEAdEJBArYNGLlZFx3noNWwyX5zWuGe5WDVKux5l1z4BenlPCZFWWgnX3KUlpdZw0FYEREAERKAuCEig1kUz+1eSvdv+V3+4wt7lH85ScsTKO+q83CpRmFKgeqVT7sQojq1I5V8HXrAUJgIiUH0CylEE4kdAAjV+bVKzElFjuTMvV1u504vVuTP4NopCFRKn5XhP+ZeBxp1G0UJKQwREQAREIEEEJFAT1FiVKKqj0bzEaX5+dOLln8ftOHR5PvsMiNJ76gWQwrRchZ868KFbSjeIgAiIgAjUIQEJ1Dps9DBVpsYKEz8Rcdm17yjzKArst6xUFOJUXftRtJDSEAERKJ2A7hSBmhCQQK0J9vhk6jgRvXqo88VpqnRSNcQp4dFKbWp17ZdKTveJgAiIgAikgIAEagoasdQq0JEY5F5qpSDxYhsnv2DV6NpnfuUsK0XgWlKKFGUiIAIiIAJ1SkACtU4bntV2vKc89hpCWW4PNdONlVGRR+k99XI7s8LliFPer3GnpCATARFIAAEVUQQqRUACtVJkE5CuI1C9xGl+8VOjl6IWp17g2K1PywcY5pje01SNpwhTecUVAREQAREQgTUEJFDXcNDWg0A5OssjudoG+Xbtl1AsClM\/72m5bmd17ZfQILpFBERABEQgbQQkUNPWoiHq43hQvbRWvjhNvEOvWl37FKf54EK0hYmaGle1qY02IiAC9U5A9ReBMghIoJYBL8m3UrMFKT97nIPEi3WcKLv26T2luStMYUqB6g4Pek7QWpA\/KC3FEwEREAERSDmB1ArU72wFNmbMGAwdOhQ9evRA9+7dseOOO+L444\/H1KlT0djYGFnTrlq1Cs888wyOOeYYkwfzYp6DBw\/GrbZ78ptvvoksr6gScrynTM9Lb5WjtZhmbKy8rv2W1ajkmqctc1OICIiACIiACNQlgVZprPV7772H4cOHI5vNYvr06aCAZD0XL16Mp59+2ly75JJLsHTpUgaXZfPnz8exxx6L4447Ds899xyYBxNknnPnzsVVV12Fgw46CG+99RaDY2OOQPUSp\/mFTHSvs\/1HCqL0nvqJU3pPafngwhzTe5r4cRRhKqy4IiACIiACIlCYQOoE6ieffIJTTjkFM2fONDXv3bu3Eao33HADhg0bhrZt2xrv6d13341rr73WHJuIJWyY19FHH41JkyaZuzfaaCOcaIuYG2+8Eeeeey623HJLE\/7xxx\/jrLPOAuObgBhsignUcvRWDKq3pghRilMqedqalJtvtaxUcx46EwEREAEREIEyCaRKoK5cuRJ\/+ctfMHv2bFiWZbyaDz74IEaOHImDDz4Yo0ePxoQJE9CtWzeDbfz48ZgyZYo5Drtx8qKHlvcecMABePTRR3H++efjwAMPNCL54YcfxqGHHsrLpky33XZbWYLYJBTBho5FJxkvzZUvThPr2Iu6a\/\/WWx1kTXtzUO5YCHlPDUZtREAEREAERCCfQKoEKoXp448\/buq300474eSTT0abNm3MubPh2FB2\/dOTynGqY8eOBcWmcz3oftq0afjXv\/5lou+2226mK79z587m3Nmsa6s7ek4333xzEzRx4kR8\/vnn5jgJG2qnJJSzRRmpwKP0nlKc+in5cgVqosdQtCCvABEQARGIgoDSEAGkSqC+8sorWLBggWnWX\/7yl3ALRnPB3uy6667o37+\/fQTwnk9LEDPPPvssKHApgCmEO\/mouS222MLktc4666Bjx4746quvEKd\/XrqrXM1V8\/qV0J6+ZSYgClSvCOWCoji1\/4jxSlphIiACIiACIlDPBFIjUOkF\/fe\/\/23akmKxX79+5thr06FDB\/Tp08dcokeTnldzEnDz9ddf44UXXjCxt99+e\/Tt29cce20syzJjXd98802wy3+77bbzilaTMGqvQhlTPxW6Hstr1ezazx8L4YYR5FzLSgWhpDgiIAIiIAJ1SCA1ApWz551JSD\/60Y+w8cYbF2zOHXbYwVznclMzZswwx0E38+bNa5rwxElY66+\/ftBbYxXPT6CWq7tqVkl17dcMvTIWAREQgWoRUD71QSA1AvX777\/HwoULTatxzCe7082Jz6Zr165o3769uTpr1iyzD7r54osvQC8q42+11VbcgaJ11KhR2GOPPcyaq9tssw0GDRqEO+64wwwFMJFitvESqPniNHG9z0np2udwEHlPY\/bToOKIgAiIgAjEiUBZApXeR4pCijOuB8q1P53KscvdOa7GnqIxzPhOilOOHy2lbMuWLcOKFSvMrRSojzzyCLgo\/+233940CYpsPvjgA\/z3f\/83DjnkkNitg8rCFxKo1FCMkxirVtc+FTytHDCbbVbO3bpXBERABERABFJPoCSBOmfOHJx33nngTHlnwhEXxncmKNGbybVITzvttKau8GqS3GyzzcAZ9EHzpLBlmYPGp\/B04nJpqbPPPhtLliwxX5HiCgFcB5XroXJdVMbjgv085wcEeB4H8xKnLFe52otpBDH+UTNw4EDQ08wJZ0Hu8Y0Tddc+4dC8Mix3YhSVf+Jc014gFCYCIiACMSSgIqWGQCiBSq\/gmDFjMHToUNx3331NX01y06B3kTPcOSmIa5DGSZi5y8pzikuWmcdBLD\/uQw89ZG65+uqr8cADD5g1V7kOKtdDfeqpp3DooYea65\/ZHj5+GCDI16teeukluM0kUsWNrfErmlu7du2wwQYbmD8kONyirMyi7NpnQU48kduWxgX5y1XwlQbbstQKEQEREAEREIHEEQglUDmekl3Wy5cvNxXl5CAvcUERxi5\/RqL38NJLL8W3zqeLGBgzj1lPFAAAEABJREFU43jVUrv7WZUzzjgDhx12mPk4AM8doxeXdd95551N0OTJk\/HOO++YY78N44wYMQL5xq9g+cUvNdzPQViu\/ipUnn\/84x\/gJ2bpPW1oaABXU6BQ5XALPjN\/+9vfzBe3eFwonRbXony2\/MQpwdBaZB4iIJj3NESCiioCIiACIiAC6SQQWKDy06G32B4kjjPl2p5\/\/\/vf8dprr4ETg9xoNtxwQ9x77734+c9\/bi69\/PLLyOVy5rgaG65rSg9u0Lw4659CKWh8LmPlxOWErIMOOqiFOHWucy1WrsnKc5bp9ddf56GvcX1WDqHIN35MwPeGEi94CdR8\/RV1LzSHUDz55JNgXThe96677sJ6660HcufXvDih7PLLLzefjf3www+D14rd+8FjF45JKDSvWOV27TPNnj25lYmACIiACNSEgDJNEoHAApUTgegVpTijR4+z1S3L8q0rhdmVV16Jbt26gUMDnnvuObP3vaHMC1xWikIzaDL5E53Cek+Zl5PPlltu6ftBACdO9+7dm75o9e677zrBNd176TBHoNLRF3Xh+OUuDnvguFOy53CHJ554woxRppeZXlV2+Z966qn48Y9\/HDz7KL2nhRbkd+AEL1nzmOrab85DZyIgAiIgAiJQgEAggco1RuktZTqZTMZMBuJxMaOnda+99jLRuJTTN998Y44rsaEnjgKHaXNGf7Fu4i+\/\/BIUSozPmfjcBzUObWC3dKXiB0231Hhe4pRplavBmIafWZYFfqSAw0ToMT366KObovKjCuze54cWGM6u\/6aLxQ6iEqgUp15gCKVc7ykVf0TLShXDoesiIAIiIAIikAYCgQWqM3OdM\/dbt24duO4UqYzM5ajYzcvjShg\/JcrudqbNWfn09vLYz95++21zybIs9OrVyxwH3dCDSg8x41MIc9gDj\/2MYpjd+7y+ySabcBdrq7Szj5PSJk2aBHpV6ZFnW5BPWE+2gRiFQKUwpUA1Cbo25YpTJldpoMxDJgIiIAIiUA4B3RszAoEEan6Zu3Tpkn9a9DiMp7FoYgUiUDTvvvvuJsaiRYvAMbPmxGNDMeR4hCkYudSRRzTfIApUegMZYfbs2aB3mMd+Nm3atKbhDdtuu61ftKqFZ7PeWdFZ6H0lulBOlrvwwgtBbkceeSSuuuoqw+Z3v\/sdio3PbVGKqMafFhKn5UKh9zTqAb0tQChABERABERABNJFIJBApfijh5JVLybGGCffnPjsfmc3fP61qI+5JqsjoMeNG+e7csDUqVPNBC\/mz3u4biqPgxrr4QxdoNhlXvlLT+Wnw8+vOktR0cO7S7mCJz\/xCI\/zi1VJPXXTTTeZiVBkftRRR2GfffbBfvvtB66hyxn+xTzfzaochfeU4pQe1GYJ2ycEkjTvqV1s\/RcBERABERCBNBAIJFA525oTfVjhF154AfRQ8riYffzxx+DkKMajOHNELs8rYfSEUvAwbY5z5AoD7ILnuWNckzWbzYJLZXEZKHrxKMCd60H3BxxwAHr37m2i33\/\/\/fjzn\/8Md17kdNFFF4Ez8hlx3333hTPkgee1slyuZc7UYwylw4\/7Stnpp58OfrSAk6E4gY7d+vygw5AhQ3DzzTeDK0AEzrtcgUphSoHqlWEU4pQwK6n2vcqtMBEQAREQgcgJKMHqEwgkUCng9t9\/f7OU0htvvAF6DIuNu2RXLrtvuQ6qZVng\/UynklVk+hQ+FKrM55577gGFD712EyZMAMXisGHDwDLxOr9+tdtuu\/GwmdErSuFKUU6jcGoWwT6hkKIApseWqxTw61FOXvxAARfupyB9\/vnn7dgwX906+eSTDUMTUKPNxIneGTsC1ftqdKGcAMXZ\/EcccURToj179gTbKLR4L1egFhKnUQDR2NOmNtaBCIiACIiACIQhEEigMkHO3v\/pT39qxguOHj0aFFtcMmn16tW83GScCMXPf\/ILSlyaihc4sWrAgAE8rLjRU3v99deb5a2Y2UcffQSWl4vpU1hzRQLLssxC+Pxcq2X5L5XF+wtZ3759cfvtt7fIix5BrhnLiWG8n9wowChqeR5Hc\/RYYjRVueNPKU7pQXU3BkFE4T0lyFh5T90V1bkIiIAIiIAIxJdAYIHK2dYcI0gvFz2G\/IwnP+l50kknmdpxcfw999zTLCX0m9\/8pslLSQ\/jZZddVnStUJNIRJs+ffrgwQcfRNbuymc3PL9axKQ5xICLxI8fPx5\/+MMfzJeMGF6O8StRHGNKEcyJU5yZzvS4pzClgOXi9BxzyfBaWzbbsgTUZC1DYx5SzudNKUwpUL2qGIU4ZbpaVooUZCIgAiKQfgKqYUUIBBaozJ3Cj2KLwovn+cYuf\/dEIXbdMj49jflxq3HM8aUjR44Evbgcd8pxoG+++SZuu+02cN1Ny\/L3nPJelpv30BwR7ldudltz6AC79qdPn27GnHLPIQZ77703HIHsd3+cwuvC6ecnTqnUaeU2SMhly8rNTveLgAiIgAiIQNoIhBKorDw9qBRvFF\/8xOdGG23UbFwlF7HnDPdbbRHAcZ89evTgbbKYEMjlWhbE0WSc09PyagxD2L1f6vhTek9pXtW65Rav0HBhhJg8lR+ujootAiIgAiIgAhUmEFqgsjz0CNKL+qc\/\/QmTJ082a1rS00jjEk533nmnWT6IM7QZXxYPArWeIBULCiee6F2MKMQpU+bYU+5lIiACIiACIgAhKJVAIIHK7nuuTzlv3jxwElSYzDhRiJ7UP\/7xj\/jmm2\/C3Kq4VSLgeFATo61KHX9qe\/U9kRIAzfNiiEB5T0PAUlQREAEREAER8CcQSKByEXUuydS\/f384yyb5J9n8Cr\/YxBn0\/\/znP7Fs2bLmF3VWVQLZbMvsotBlLVONYQi79f0EalQToxKj8MO1j2KLgAiIgAiIQLUJBBKo5RTK+ZJUOWno3mgIZLNAJuOfViKGTpY6\/rSQOI1CpVOcJgKgf\/vrigiIgAiIQFUJKLMCBJoJVHbfT5w4EZyNnm\/PPPMMlixZYpJ51fZE5V8rdMyvK3GZJd7IJZ64kD6PZbUhMHAg8OyzAOcXccglzXEesne6NqWqQq4Up\/Zz2yInClMHQIuLIQO0rFRIYIouAiIgAiIgAv4EmgnUdu3agZ8n5ecoudi8Y\/wCE7v5mQwXoHfCi+2vu+46cAwq7+Nsfn4ylcey2hOgNnOs9qUJUYKw408pTClQvbKISpzSe+qVfj2EqY4iIAIiIAIiUAECzQQq0z\/kkEMQ9VefuFj+b3\/7W8iDSsLxtMRoLLp\/wyAsJE6p0MOk5RWXrmd5T73IKEwEREAERKAMAvV+awuBykXqR40ahRtvvLHJeM4vQhHWiSee2BSeH8fr+G9\/+5tZhoqz+DfffHPeLhOB0glw\/GmYuylO6UF130NhKu+pm4rORUAEREAERCA2BFoIVJaMYpKfMXWMX0Pq2LEjL2EX++XuhBfb89OnXMif66aam7WJLYHUze+hMKVA9SIelTil9zR14LyAlRqm+0RABERABESgNAKeAtWdVCf7RZzNZo3ndIcddnBf1nnCCdjNm4wahBl\/Wkic2n9kRVLhxIyLiKS2SkQEREAERCAuBOqgHIEEaocOHTBo0CDQY7qpxtvVwWMR0yoGHX9K7ynNqxrynnpRUZgIiIAIiIAIxIpAIIEaRYk\/\/\/xzLF26NIqklEbEBBLhCAwz\/vTECn\/OlPwTAY0Fja2pYCIgAiIgAiLgSyC0QOVaqZMnT8atdhcql58qZlyKao899sDhhx+Ob4N6wHyLqwt1SyDos+MnTtmtT4sCIMWpxp5GQVJpiIAIiIAIRE4gHQmGEqjPPvssfv7zn+PII4\/EVVddhXHjxhU1LuRP72k6cKWzFonQWkEEKrv1aV7NxK8SeIWXEqZhLqVQ0z0iIAIiIAIiEJhAYIE6d+5cXHrppU0L7wfOwY7Ir0jtvPPOaN++vX2m\/3EikJgJUkEEqu3V92Qb1bhTJt6rF7eyChNQ8iIgAiIgAvVNILBAffDBB\/Hp2lnUFJv8jOm\/\/vUvbLvttobgWWedhUcffdTM9OdaqRtssIEJ79mzJx5\/\/HH86U9\/gr4kZZBoE5ZAkPGnFKde3lN260clUKnmE+FuDgtY8UVABERABOqEQGKqGUigLl68GK+99pqpFAUnx58OHToUffr0MV3+vDBt2jRsvfXWZqb\/+eefb8TqbrvthpkzZ+Kmm27CypUrGU0WMwIcThmzIrUszto\/jFpeWBtCYUqBuva02S4qccpEEwGLBZWJgAiIgAiIQLIJBBKoS5YswSeffGJquvvuu2PDDTc0x9zQm8o9hwB88803PDTGOBdffDG4hio9rRSw5oI2IhA1gULilB7UKPKT9zQKitGkoVREQAREQARSTyCQQG1sbGzygG6xxRbNoHTr1g38POqXX34J92So7bbbDvya1Hd2F+1DDz3U7D6dxINAInqsC40\/pTilB9WNk8I0Su9pz57uHHQuAiIgAiIgAqkiEKfKBBKo+QXezNXNSU\/p+uuvb5aQ+uKLL\/KjonXr1mYYAANnzJgBClUey+JBgE7BeJSkQCnsP258r1KYUqB6RYhSnGpilBdhhYmACIiACIhAxQgEEqjt2rWDM+npgw8+aFYYztDv2rWrCXNfY+CWW27JnRkiwKEC5kQbEQhKoND400LilB7UoHkUikcVnwg3c6FK1NM11VUEREAERCANBAIJVIrQzTff3NSXi\/TnfxGKS0d16dLFXJs1a5bZ528++uij\/FMdx4iAyxkeo5IFKArFKT2o7qgUplF6TxMNyQ1H5yIgAiIgAiJQIoEq3xZIoLKrfv\/994dlWXj++edx5513YtWqVaao9K46XtKpU6di\/vz5JpwbClkKWh7TA8u4PJaJQCAC7N73Gn9KYUqB6pVI1OJU3lMvygoTAREQAREQgYoSCCRQWYL+\/fujV69e4ISpa6+91iwvddttt4EiNJPJoE2bNmZJqQsvvBDvvPMOOKufn0GloOX9XC9V66CSRHwssdqLXlKaGyXDaO7wUs7Zta8vRpVCLs73qGwiIAIiIAIJIRBYoHIy1KhRo+B058+bNw9PP\/208aTuYosCCljW+ZlnnsFBBx2EwYMHg4v7U9C2bdsWv\/jFL4wHlnFktSdA\/VX7UhQpQaHxp\/SiFrm9rMvq2i8Ln24WAREQARGoJwLR1zWwQGXWffv2xf\/+7\/9iyJAhaGhoACdHcQwql5mieO3duzejNTPLsnD22WdjwIABzcJ1IgJFCXh17\/MmP3EaVfc+1Xti3csEJBMBERABERCBZBMIJVBZ1a233tp8GYrjTc855xyzlBTDOYlq3LhxuOCCC8znT7le6l577YW7774bxx9\/vLynhBQji72DkONP\/Xj5jT+1Pfl+t4QK15qnoXClJbLqIQIiIAIiEB8CgQUqJz85X5Ni8ek15SL9PHaMY0xPsL1YTzzxBJ577jkzmYqfO7Usy4mivQhUhkBU4rRXrwhC7bUAABAASURBVMqUT6mKgAiIgAiIQH0SKKnWgQQqx5Fec801oEf0pJNO0oL7JaGO102x78H2G3\/K7n2aG6f9h5E7KPS5uvZDI9MNIiACIiACIlAJAoEE6qJFi\/D222+bGfycjU\/vaSUKozSrQyD24pQY\/Maf8lqlLPbjHipVcaVblIAiiIAIiIAIVJVAIIG6cuVKLF682BRsu+22M3ttRKBiBMKOP2X3Pq2cAlGcJkK5l1NJ3SsCIiACIiAC8SLgV5pAArVjx47gJCgm8tZbbxlPKo9lIlARAoW8p17d++UWgl37WvO0XIq6XwREQAREQAQiIxBIoLJL\/6ijjgLXMx07dqxZ\/5TjUiMrhRISgXwCfgLVT5yWO\/6U3tP8\/HUsAqEIKLIIiIAIiEDUBAIJVGbKtU\/\/\/Oc\/my9GnXjiieCnT0ePHo2HH34Yr7\/+OrhwfyHjKgDO51GZnkwEfAn4CdRKLC9F76m69n2bQhdEQAREQAREoBYEjEAtljGFZyaTAZeQWrhwoeninzVrllkP9bTTTsOwYcPQv3\/\/gjZ8+HAsWLCgWFa6Xu8ECo0\/9WJT7thTrXnqRVVhIiACIiACIlBTAoEEak1LqMzri4Df8lKk4NXFX45A1ZqnpCqrLAGlLgIiIAIiUAKBQAKVnzMdOnQojjjiiJKN9zOdEsqoW0QA8BKn5FKqQFXXPunJREAEREAERCCWBIoLVLvY\/ELU+eefj1GjRpVsvJ\/p2Mnpvwj4E6jW+FNNjPJvA10RAREQAREQgRoTCCRQa1xGZV8vBAqNP\/XyoJbqPaU41cSoenmqYl1PFU4EREAERMCbgASqNxeF1oKA3\/hTL3HK8pWyvBS79rXmKenJREAEREAERCC2BMoUqLGtlwomAt4E6D31vqJQERABERABERCBmBCQQI1JQ9R9Mdi9H2b8Kbv3aWHA0Xuqrv0wxBS3lgSUtwiIgAjUMQEJ1Dpu\/MRU3a+LP2wFtOZpWGKKLwIiIAIiIAI1IVBJgVqTCinThBKo9PhTrXma0AdDxRYBERABEahHAhKo9djqSapzFJ83Vdd+klpcZQ1EQJFEQAREIN0EJFDT3b7JqF2h8adeNQg79lQTo7woKkwEREAEREAEYkugZgI1tkRUsPgQ4NhTmrtEYZaXojjVxCg3QZ2LgAiIgAiIQKwJVFygrlixAp988gkmTZqEpUuXxhqGClcjAn7jT8stDrv2teZpuRR1f\/IIqMQiIAIikHgCgQTqvHnzMHDgQHTv3h1PPfVUqEpPnDgRe+65Jy6++GJ867eMEPSvrgn4PRde40\/ZvU8LAoze0yDxFEcEREAEREAERCBWBFpVujRffPFF+Cx0R\/0Q4PhTv9p6de\/7xXWH03uqrn03FZ2LgAiIgAiIQCIINBOoq1atwvz580GPab59+eWX4DXW6JtvvmlxPT9u\/vFLL72Ef\/zjH7wNrVu3hmVZ5lgbEWgi4Oc99ROnQcefas3TJsQ6EIF8AjoWAREQgSQQaCZQW7VqhTFjxqB\/\/\/7N7KCDDsKna8cJnnvuuc2uuePmn48YMQLTp083HLp164b11lvPHGsjAk0EwgrUIN37WvO0Ca8OREAEREAERCCJBJoJVMuyMHLkSPTu3TvSunTp0gWnnnoq2rVrF0G6SiJVBMII1CDiVF37qXo8VBkREAEREIH6JNBMoBLBhhtuiGw2iyOOOKLJDj30UKy7djwfJzzlXyt0fILdHXvTTTfhiSeeQN++fZm8TAR+IBB2\/GkQgaqJUT\/w1ZEIhCWg+CIgAiIQEwItBCrLtdtuu2HUqFFNdsEFF6Bz5868hKOOOqopPD+O1zHvGzJkSNO9JgFtRMAhEMZ7ynuKCVSK07V\/SDG6TAREQAREQAREIJkEPAWquyrt27fH0KFDjUd1k002cV+O07nKkiQCfgLVa3kp1quQQGXXvtY8JSWZCIiACIiACCSeQCCByslN559\/vvGc9unTJ\/GVVgUqSyCXyyHnMq6j2yJXP4HaIqIdUEic2pdB7yn3MhEQgQoRULIiIAIiUD0CgQRq9YqjnNJAgGLUbS3q5Tf+lMtL0dw3nHCCO+SHc4pTde3\/wENHIiACIiACIpBwAs0EKj9F+uyzz+Lhhx8G9zxn\/bjnOcNLNd7PdJherUz5xojA2mXLIikRu\/cjSUiJiIAIiIAIiIAIxIFAM4HKT5Fms1mcdtpp4J7nLCT3PGd4qcb7mQ7Tk4mALwGv8afs3qd53URxKu+pFxmFiUA1CSgvERABEYiUQDOBGmnKSkwE\/Aiwe99v\/KlX975fOgoXAREQAREQARFIJYFmArWT7Y2ip\/PGG280HlSes9bcO+G8VorxfqbD9GJpKlTtCfiJ02LjT2tfcpVABERABERABEQgQgLNBGqHDh0waNAgHHjggWbPc+bFvRPOa6UY72c6TE9W5wT8xp96de8TlV\/3Pq+pe58UZCIQawIqnAiIgAiEJdBMoIa9WfFFoOIEColT2+Nf8fyVgQiIgAiIgAiIQNUJSKAGQq5IkRHwG3\/K7n2aOyN177uJ6FwEREAEREAEUk9AAjX1TawKioAIiECMCahoIiACIuBBoJlAnTdvHrjAevfu3RG1MV2m71EGBdUTgajGn7J7X+NP6+nJUV1FQAREQATqiEAzgVpH9Y6yqkorDIEwy0sVGn8aJk\/FFQEREAEREAERSBQBCdRENVfCC8vxp15V8Bp7yngaf0oKMhGoYwKqugiIQL0SaCZQu3TpgvHjx2Py5Mm+9tBDD2GzzTYzvIYOHeobz50G02X65kZtRCCfgJ9AzY\/jPlb3vpuIzkVABERABEQgNQSaCdSGhgZsuOGG2GijjXyta9euYDwSaN++vW88dxpM17mP99aLqZ55BPzGn3oJVHbv0\/Jubzrk+NOmEx2IgAiIgAiIgAikjUAzgZqmyn1ndyePGTMG9PL26NHDTPracccdcfzxx2Pq1KlobGysaHVff\/11\/PSnPzX53nzzzRXNKzGJhxl\/WqhSaz34haLomgiIQOoJqIIiIAIpJtAqjXV77733MHz4cGSzWUyfPh2rVq0y1Vy8eDGefvppc+2SSy7B0qVLTXjUm29tIXbddddhwYIFUSed3PTsPxg8C+\/lPWXEQuNPeV0mAiIgAiIgAiKQWgKpE6iffPIJTjnlFMycOdM0Wu\/evY1QveGGGzBs2DC0bdvWeE\/vvvtuXHvttebYRIxoQ8\/s3\/\/+d0yaNKl4ivUUwxbtntW99VbPYBTq3tf4U29mChUBERABERCBlBBIlUBduXIl\/vKXv2D27NmwLAvHHXccHnzwQYwcORIHH3wwRo8ejQkTJqBbt26m+Thxa8qUKeY4qg3TYxmiSi816fgJVK8K+olTr7gKEwEREAEPAgoSARFINoFUCVQK08cff9y0yE477YSTTz4Zbdq0MefOhuNR2fVPTyrHqY4dOxYUts71cvbz58\/H5ZdfDqa7\/vrrl5NU+u71Eqjs3qe5a1uoe1\/jT920dC4CIiACIiACqSOQKoH6yiuvNI37\/OUvf4nOnTt7Ntiuu+6K\/v37m2u851O\/2eUmRrDNihUrcP3115sxr\/TQnnbaacFu9I2Vogt+409LqaK690uhpntEQAREQAREIFEEUiNQ6QX997\/\/beB36tQJ\/fr1M8demw4dOqBPnz7m0ueff26GBJiTMjZPPfUU7r\/\/fjPG9dxzz8WPf\/zjMlJL2a1+fwB4jT9l9z7NC4Hdrl7BChMBERCBUAQUWQREIPYEUiNQOUOfE6RI\/Ec\/+hE23nhjHvraDjvsYK5xUtOMGTPMcambjz\/+2IxvXb58uZmItc8++5SaVH3d59W9X4iAuvcL0dE1ERABERABEUgNgdQI1O+\/\/x4LFy40DbP55pujY8eO5thvww8O8EMDvD5r1izuSjJ27V999dWYO3cuevbsiVNPPbXFuNeSEi58U7Ku+o0\/9apFofGnXvEVJgIiIAIiIAIikDoCqRGoX3zxBb766qvADURx6p5AFfjmvIj33nsvHnnkkaaufeczsHlR6vvQb\/ypn\/e0UPe+xp\/W97Ok2otAVQgoExEQgTgQaCZQ582bh4EDB5qvH3Xv3t1zz8lFH330kSk7x1z6xXOHM12mb26s8IYicd0QYobClh7YsMV666238Mc\/\/tGspXrkkUdi8ODBYZNIf3y\/8adeAtVPnKafkmooAiIgAiIgAiKQR6CZQM0Lr6vDJUuWgF31YSrNr0Vdc801ZtWAnXfeGZy1b1lWmCQ8406ePLnFHwYUv56RfQITERxWoGr8aSKaVYUUAREQAREQgSgISKDaFDleNUx3PydW8UtUL7zwAuipveCCC3yXtLKTD\/WfHmqmnW9nnHFGqDRiE5nd+2HGnxbyoIbwiMem\/iqICIhA2gioPiIgAlUi0EygbrTRRpg4cSLmzJkTuTFdpl+NenFdUy6WHzQvzvpv165d0Oh4\/fXX8T\/\/8z+ma58fA9htt90C3xsk4s9+9jO4Lch9iYnjtbwUC+8nULW8FOnIREAEREAERKBuCDQTqEmuNZeVotAMWodly5Y1deuH8Z4uWrQIv\/\/978Eu\/gEDBuA\/\/\/M\/zWdVg+Zb83jVLIDf+FOvMviJU8ZV9z4pyERABERABESgbgikRqDSA7rBBhuYhuOM\/qVLl5pjv82XX34JilRe32qrrbgLZK+++iqmTZtm4k6aNAkcf+qeEMbzE\/KWS+JYVYbRuIi\/uTntm0Ld+zbDFtXP49Ximrr3WyBRgAiIQPwIqEQiIALREUiNQF1nnXXA9U+JhrPy58+fz0Nfe\/vtt801y7LQq1cvc6xNhATCeE8LZavu\/UJ0dE0EREAEREAEUkkgNQK1devW2H333U0jsRt+5syZ5thrw\/Gpr732mrm0ySabYJtttjHHQTb8AtWNN96IYnbiiSc2JXfooYc2xf\/1r3\/dFB6\/gwhL5DU5isl7jT9l9z6N190mgeomonMREAEREAERSD2B1AhUttSuu+6KLl268BDjxo0z40TNiWszdepUOAKV93DdVFcU39NNN90UBx54YFHbJU9w8QtTzj39+vXzTTs1F9i971cZr+59v7gMl0AlBZkIiEDSCaj8IiACoQikSqDSE7rPPvsYAFOmTMGoUaPgHov63nvvIZvNYvny5WaJKK4xSu+ruUmbaAj4de\/7iVO\/8acUpxp\/Gk2bKBUREAEREAERSBCBVAlUCs1TTz21qcv+nnvuwZAhQ3DTTTdhwoQJuOiiizBs2DDMnTvXNNHw4cPhtUQUhwBQuHJSE+3mm2828et8E6z69J6G6d5nqnneZp7KREAEREAEREAE6ptAqgQqm5ITpa6\/\/np069aNp+BnWUePHg0uds9u\/8WLF5tloUaMGIHzzjvPHJuI2kRDwE+c+qVeSJxqeSk\/agoXARFIFQFVRgREwE0gdQKVFezTpw8efPBB05Xfu3dvNDQ0MBic6T948GCMHz8ef\/jDH9ChQwcTrk2TILlzAAAQAElEQVSEBPwEKrv3ae6s\/Lr3GU\/d+6QgEwEREAEREIG6I5BKgcpW5CdIR44ciUceeQQcd8qvY7355pu47bbbwIlKlmUxmqfx3rFjxzZ9Teukk07yjFcokGNhmSetlPsLpR3Ha6ZMhbr3TYQQG44\/DRFdUUVABERABERABNJDILUCNT1NlKCa+E2OYhXCLi+l7n1Sk4mACIiACIhAXRKQQK3LZq9Qpf2695mdV\/c+w2UiIAIiIAIiIAIi4CIggeoCotMSCbB73+9WP3HqN\/6U3fsaf+pHU+EiIAIiIAIikHoCEqipb+IqVbBQ976fQC00g79KxVY2IiACIpBkAiq7CKSVgARqWlu2mvWi9zRs934hcarxp9VsPeUlAiIgAiIgArEjIIEauyZJYIEKeU9ZHT8PKq\/BY6PufQ8oChIBERABERCB+iEggVo\/bV25mob1nrIkhcaf8rpMBERABESgPAK6WwQSTEACNcGNF4uis3u\/UEG8lpdifL8ufnXvk45MBERABERABOqagARqXTd\/BJUv1r3vlYWfOG0ZVyEiIAIiIAIiIAJ1SEACtQ4bPbIq03tarHvfa\/xpoe59jT+NrHmUkAiIgAj4E9AVEYg3AQnUeLdPvEtXSJzGu+QqnQiIgAiIgAiIQIwJSKDGuHFiX7RiAtVr\/Cm792lelQs5\/tQrCYWJgAiIgAiIgAgkn4AEavLbsDY1KNa9z1J5de8z3M\/Uve9HRuEiIAIiUE0CyksEak5AArXmTZDQAhSbHOUnTguNP00oChVbBERABERABEQgWgISqNHyrJ\/USuneJ51qde8zL5kIiIAIiIAIiEAiCUigJrLZalxodu+XUgQ\/cVpKWrpHBERABESgJgSUqQhUg4AEajUopy2PYt37rK9XF7+fQO3UCdD4U1KTiYAIiIAIiIAI2AQkUG0I+h+CAL2nxbr3vcQps\/ATqLxWVVNmIiACIiACIiACcSYggRrn1olj2YJ4T72Wl2Jd\/ASqlpciHZkIiIAIJJ+AaiACERGQQI0IZN0kU8x7ShBeHlQ\/ccr46t4nBZkIiIAIiIAIiMBaAhKoa0FoF4AAu\/eLRfMSp7wnOctLsbQyERABERABERCBGhKQQK0h\/MRlXU73vl9l1b3vR0bhIiACIpAyAqqOCAQnIIEanFV9x6T3tFj3Pr2nNDcpdu\/T3OE8V\/c+KchEQAREQAREQATyCEig5sHQYQECxcQpbw07OYrLS\/G+BJmKKgIiIAIiIAIiUHkCEqiVZ5yOHIIIVD\/vqcafpuMZUC1EQAREoHIElLIINCMggdoMh048CQTp3vfznvqJU2YkDyopyERABERABERABFwEJFBdQHTqQSDI5Cgv7ymT8ht7ymtpG3\/KOslEQAREQAREQATKJiCBWjbCOkigWPc+xSnNjULeUzcRnYuACIiACJRAQLfUHwEJ1Ppr83A1Zvd+sTv8uvcLeU+1vFQxqrouAiIgAiIgAnVLQAK1bps+YMWLde\/Tc0pzJ0dxSnOHO+d1173vVFx7ERABERABERCBYgQkUIsRqufr9J4W6973856qe7+enxzVXQREQASqR0A5pZKABGoqmzWiShXznjKbUryn6t4nOZkIiIAIiIAIiIAPAQlUHzAKtglUwntqJ6v\/LQgoQAREQAREQAREII+ABGoeDB3mEWD3ft6p52Ep3lOufarxp544FSgCIiACIhA1AaWXVAISqEltuUqXu1j3PsUpzV2OQhOj3HF1LgIiIAIiIAIiIAIeBCRQPaDUfRC9p5Xq3tf409CPl24QAREQAREQgXojIIFaby0epL6V9J6qez9ICyiOCIiACIhA5QkohxgTkECNcePEtmilLC3FynD8KfcyERABERABERABEShAQAK1AJy6vBSke99v7Gmx8afq3o\/+kVKKIiACIiACIpBCAhKoKWzUsqpUrHu\/VO9pWYXSzSIgAiIgAiJQXQLKrbYEJFBryz9+uRebHFWq95Td+xp\/Gr\/2VolEQAREQAREIIYEJFBj2Cg1KxK79wtlTnFKc8cp1rXvjq\/zKhFQNiIgAiIgAiKQTAISqMlst8qUupLd+xp\/Wpk2U6oiIAIiIALVJ6AcK05AArXiiBOSAb2nhbr36TmluasT1Huq7n03OZ2LgAgkicCc24CXjwde\/A9g0oHAS8OBaScDc64DFk2OZU1ee\/8rnHPvmzh7wns458nPMfqlb2NZThVKBLwISKB6UanHsEp6Tzn+tB6ZxrvOKp0IiEAQAh\/eDTx9ADB3LLDkA6BxCdC2LdBuXaDjxsDyj4DP\/wrMuco+\/jhIilWLM+61z7Da\/v1rdd0Qrbp2xryGjvjX3NVVy18ZiUA5BCRQy6GXpntL9Z4G8aButlmaSKkuIiAC9UJg8n8BM262a\/s90KaNbe1sYdoB2HBPYCc7vEcW6H098GPbk9rmK+CLG4FvJtnxa\/\/\/yRkLsNKygI7roFX7drDaNaBVxwZMWWgXcUXty5fuEqh2URBoFUUiSiPhBNi9X6gKXl37jH\/CCdzKREAERCB9BF74NfDtbKBVA9Datjb0mrYH1tkQWLeb7S21PadOrdf5CdDV7vJvb3tVlz4FLH3buVKz\/ZNvf47V7TsacdqqTWu0suvQpp3tAG5nYcIHjTUrlzIWgaAEWgWNqHgpJlBK9z49p7RiWOzuJWj8aTFKsbuuAolAXRN4z\/aOfmcL0Fb2K7LBNnpP29rqrq0tUFvb4m7158DKT2377AdMHXYFWncBGtoCXz8ArKrdeM9\/vTEf3zdaaNWhAywOR7Dr0Kq1hUZbZzd0tDB9CfDlMrse0D8RiC+BVvEtmkpWFQL0nhbr3vcqiLynXlQUJgIikAYCH9xnC0379UiB2tpWdRSojgeVbkiK0xW2OF1p2+pFP9S4te1dtXjfauC7Z34Ir\/LRxBmfweqwDhrbt0ejXf5WthfYLhVaWUBDa6CVrbX\/ZevvKhdL2a0hoG1AAnxmA0ZVtFQSKMV7ShBBvKeMp\/GnpCATARFICoH37wFWL7dVnIU1is4WqFR1rW1V19DGDrPPrVXAKnpRPwMoVBuXrqndqq\/W7C17t3gK0LjSPqju\/7Evf4qVrdqisWMHmK59I5gBDkelQIVdtlZ2N\/8H3wNzvrGFNPRPBOJJQAI1nu0Sj1Jx7CnNXZqg4pT3qXufFNJlqo0IpJnAF08BjpqjomtlC9LWttvR9kSacNgKj6Kv8TuAHlR6U7lf8SGwagHMv0Zb+NGWvmNOq7VZtmIVXn5vHtCxo+0lbY\/VVgOshgaTvV1qsNit7Le+ZVfHsvX2Ix8z1FzWRgRiR8B+VGNXJhWoWgSKde\/feqt3SYJ273P8qXcKChUBERCBeBJYZotMClPLFm\/cN9j7BtersrHR9o7atupLGJH6\/dvAt\/9cU5\/Vq4DVtue00d4vt72sa0Krsv3bvz8x3fro0AFo3RYWxbWds2VXwd4BdpG55ynHpM6zdfS0vBEKvCarLQHl\/gOBVj8c6qjuCBTq3qfnlOaGQu8pzR3uda7ufS8qChMBEYgzgdV2dz0VHd2N3MN+TfKY6u5L+xo9lFPnAlNnAO+8ByyYDlCgspufwnTVcmDVijW28uuq1fSrpavw7se2uO6wDqw27QGKU9uopVl0FsSyBalli1SLJ3a1WrWx8MTHdgDPZSIQMwL2IxqzEqk41SFQzHvqJU5ZsjDeU3Xvk1idmaorAgknYHseTQ2o4ihQqejYXf\/598C8JUA7u3\/8x52BjdcHVtvi7r33bZFKT+oyYKUdZxWNItU2DgcwiVV+c+fzH6GxXUfbbO9pmzYwAtVaky+Lb6qx5tSUqpV9rZUd7Vu7ChO\/WHtBOxGIEQEJ1Bg1RqyK4tW9T88pLUhB5T0NQklxREAE4kagzQYwCg72P1vEgW7HpXaX\/Td2l\/3Wtvjb1LZOtkjtYu+32RDouh7woa3wVlKgOrZWpDZ0shOp\/P9PFy3HnPm2t7b9OmjF5bCsBjQ2tILjPXVe9KwO6EW1D6i9W9nVaGhv4d+f2Sq18sVUDuUSqLP7nee2zqqt6qJY974XInlPvagoTAREIE0ENuhn12atgqNuW20rOroZO9rBre3j1ey+t72j9JbSurYDvqeA\/cb2oC61jSLVFqi8ti7Tsu+r8P8xuY9h2d5TtO+ARtst2kiByrLbb3jq66Yufrsc9iVw1AInS9GL2tr2oi6z7cEP7LrZ1\/VfBOJCwH5841IUlaNqBIp173t5T1k4eU9JQVY6Ad0pAvEnsMV\/2ALOfjXS\/WixuLbSszUpGmwBZ8aW2uKU40wpQI3X1BajjLfMFqYrbHPC228LtNmICVTUZny2DJ99vQSt+NWo1u1AcQqrlcmT4pTVMCd2NczeLqv930ShSKVgbWhj4c2vGWpiaCMCsSCw5imORVFUiFgQ4NhTmrswQcUpZ+5r7Kmbns5FQASSQqDjpsAmewMUdMZs4dbK7t5fRoFqi1MjQG1Ruopi1LblS4EV9jXLDqNgXWGfc7\/Jr6tS43HPfAqr7bpAm\/ZotGxXKD8XZcoNM1KBAhT8Z4fZNTEjFsy+lR1oH1i2teZtrS2MnWlHsoP1P4kE0ldmPqLpq5VqVDoBP+9p0O59jT0tnb3uFAERiAeBXhcC7Ta0Raot2OiC7GR34S+xX5cci9rkPV0rSL+wBWlbu9gNtpuVwpTW9TCgwzZ2YGX\/z\/jke3z13WpYrdsDXNi0sRUa2X9vF5tjTbmzuKHB\/rd232iLUvs\/qGBbNQC8heNRZ31jH+u\/CMSEgP0TF5OSqBi1J0DPKc1dEnpPae5w97m8p24iOg9BQFFFIFYEdrgMa0Sfreo49vRHtvd0vu1qXGHv6T1ld\/43tkjl+NSutieVwpTWcTtgsxGoxr\/xuXmw2nSwBWYHrF7VxhanrWFvQHFqhKnt+OVCAywLdTaN4abr3wLMSAC7evahOW7oYOG+mauhfyIQBwISqHFohbiUwUucsmzynpKCTAREoJ4IrNsL6H2RLfZsBbfKtvVtL2qDvf\/OFqlUelzz9Ev7+Ee2SG2wlSDXcmrTBdjm4qpRWrTIfoU3dLAdobYLd2UDGlfaUpP60i4mRSqL5BiFqznmNZpdZIY5haVw5fHs7+w0eSBLE4FE1kVPYiKbrUKF9urep+eUVixLeU+LEdJ1ERCBpBHo3B\/Y4giY9Zroiuxke0+\/Y5+4XZHv7T3FYEcqPfsc7WxxeinQsC5PKm7vfmQLY6s9rEY731Wt0coWqK1WwD4HHHFKAWrZupoft3LEKY9p\/NAV7Gvc06NqBKotXJfZadgp6L8I1JyABGrNmyAmBZD3NCYNoWJ4ElCgCNSKwJbHAJ33sEWfrUbb2rbCso\/twnxvvz7b2eLUPrXPgG6nAR23NYfV2Mz+xFaXsD2naGN7Tu2ysFy2foatW2EXi0ZRapcY3K+yo9Ppy30jj+04FKoUqQzn6lmN9v2Ntrd47sJq1EB5iEBhAvZTHe6aogAAEABJREFUXTiCrtYJAS\/vKasu7ykpyERABOqZwJbHASttqUel18p2M1IMrrJfn23sMHLp0M0WsRkeVc8sy+7abwOsaAVreSu7fHbWtvCELTKN2QLUiFTbI2rEp72nOKUYdVbLWm3HNWHc24bljWhcBixabKel\/3VDIK4VtZ\/quBZN5aoaAXpPae4Mg4hT3qOZ+6QgEwERSCuBDpsC7bewPae2IGVf+FrxB7uX31T5R7ubXTU3nde1PaerW9vCtBWslbZYtQUohSlXu2oyO4ya2gyZtQXoatu7SlFKwco9FySgceWsxmWNWLnUruLSRmzAjxJUszLKSwQ8CLTyCFNQvRHw854GmRylsaf19rTEsL4qkghUnsDqdXrbYtBWphSotvCjd9L0nVP9rf\/TyhfAlcOOW9ne05WtYNkeVFMW23tqxqDaQtR089tis9E2ilWeszvfEaUUpLTVtrd09XdA4+JGrLK9pqu+sz2o3zdi6y6uzHQqAjUg0KoGeSrLOBGg55TmLhO9pzR3uPtc3lM3EZ2LgAikkMDYR9bBe\/O6YaHVFYvQG0s7boOlnXbFV+1H4ONPOlS9xuutC6zb3vac2sIUK2ALVcB4UG2B2soWnpa9pzi1ltgC1D6HbY22B5WidbUdtpqC1LbVS9aI09W2SKUXta2twe2U9F8E1hCo4VYCtYbwY5G1lzhlweQ9JQWZCIiACBgCi779HpNm74rH5+6F3Jz+ePbTQfj3h\/3x9twtsfDTz\/H9ElsBmpjV2\/xkOwv0nlq2qLQckWrvKVTpNaUopZcUFKQ0u4irbK8qx5mutver7e58itVGW6Q6tuUGkgXVa0HlVIiAnsRCdOrhmlf3Pj2ntGL1l\/e0GCFdrz0BlUAEyiaw4PPPsU7bBrRv24j1OzZg8026YscdeuMn9u\/J7bffGe3bdMH8T74tO5+wCfwiA3BpVote1LVGzykFqrUMaGV7TLmn1xS2IIXtMaVXtdHes1u\/cW33Pr2oFKucxX\/MYCtsMRRfBCpCoFVFUlWiySAg72ky2kmlFAERqCmBp\/75CDqu8yM0tNoYCxeuj2mvLMKE8a\/g5Slv4p2Z76JhPWCLHhvWpIwD+sN071OkUpzSWrF73\/ak0lNKQUqRSoFKoWrGnNoeU3pVYXfrG3Fqe1fZ\/f+T3pIE0L8QBCobVU9jZfnGO3Uv7ylLbHsFuCto8p4WxKOLIiAC6SFw+Mn\/hfmLFmDxsnloaL8QXTdfge692tue0+Xo1L4N2sHCd4u+qUmFD9oL2GgTwAhUdvWvBMyYVHpPbaHKbn6OQ+WenlOK0kZbkOK7RqyyhSpFK75vxAadLAzfU5LApqf\/MSGQ2qfxu+++w5gxYzB06FD06NED3bt3x4477ojjjz8eU6dORSNnXkbQCExn5syZuPjiizFgwABss802TXkddthheOCBB7B0KftWIsgsyiToPaW50wwiTjVz301N5wkloGKLQBACb7w0Bet3aMB6HS1sveWm6NWjN7bddgdssMHWtjBtg3emzcPi72x1GCSxCsQ591hgk40Bek\/zx6Ia7ylFqu1NpRfVsoWo8ZyuFaYUp6vtsM7rWjjvP501s6B\/IhALAq1iUYqIC\/Hee+9h+PDhyGazmD59OlatWvOLY\/HixXj66afNtUsuuaRs4UgRzDwOOOAA3H333fj000+bhC\/zohA+++yzcdBBB+Gtt96KuJZlJufnPQ06OarM7HW7CIiACCSFwNx3PsSq1RtgwQK7e\/\/1r\/Dy5Nl47tlp9v4tzJn7EX68\/UbYeMvONa3O2f8F9PsJzKdO84UqBasZk2oLVQpWM3nK9pk02sLUWt6I7bexcP6xEqfQv6gJlJ1e6gTqJ598glNOOQX0apJO7969jVC94YYbMGzYMLRt29aISArKa6+91hwzXlhbsWIFRo0ahbvuusuk0dDQgP322w9XXnklmNcxxxxj\/3W9gUl27ty5OPbYY+MjUuk5pZnS5W3oPaXlBXkebrqpZ7ACRUAERCCNBA45djiOPf8\/8fMD+2Gdjh3RuKIt2rRa1+7m3xr7\/qo\/evfbOhbVHnEAcOZxwKabA634TQF6Tm1h2srs+QUswFrZaGzDzhZ+c0xrHPMLiVPoXywJtIplqUos1MqVK\/GXv\/wFs2fPhmVZOO644\/Dggw9i5MiROPjggzF69GhMmDAB3bp1MzmMHz8eU6ZMMcdhNy+++CLuu+8+c9sWW2wBpnXzzTfj8MMPN3n97ne\/Qy6Xw6GHHmriLFiwALfccgsobE1ALTd2uTyzD+I91dhTT3QKTCEBVUkEXAR22LUHjvrtATjmkqE46vz9sNeh\/bDxFl1dsWp7uumGwFnHAFdfBFxziW0X28bjiyxca9s1F7XC1Rc34LwTWuHHG9e2rMpdBAoRSJVApTB9\/PHHTX132mknnHzyyWjTpo05dzYcj5q1u\/7pSWUX\/dixY0Fh61wPsmf8+++\/34hNpn\/hhRdi5513bnHruuuuC17r2bOnufbcc8+ZIQfmpJYbu\/4tsqfnlNbigitA3lMXEJ2KgAiIgAiIgAiEIRAkbqoE6iuvvAJ6KlnxX\/7yl+jc2XtM0K677or+\/fszGngPx46ak4CbRYsWNXXXb7\/99thjjz1879xwww2xzz77mOvffvstvvjiC3Ncs83Eid5Zy3vqzUWhIiACIiACIiACVSeQGoFKr+a\/\/\/1vA7BTp07o16+fOfbadOjQAX369DGXPv\/8czMkwJwE3Hz55Zdo3749NtpoI7B7f5111il4Jz2pBSNU86KX95T5y3tKCjIRCEhA0URABERABCpJIDUClbPmOUGKsH70ox9h440LD67ZYYcdGNVMcJoxY4Y5DrrZbrvt8PDDD2Py5Mm48cYb0bp1a99buQwVhx4wgmVZ4GQq1Oofvae5XMvcg4hTjT1tyU0hIiACIiACIiAC0RJYm1pqBOr333+PhQsXmmptvvnm6Nixozn223Tt2tV4QXl91qxZ3FXEPv74YyNkmfgmm2xi1knlcc0sk2mZdZDufY09bclNISIgAiIgAiIgAhUhkBqByrGdX331VWBI7KLnBKfAN5QQkd7TO+64A45nd6+99sJmtfREDhwIPPssMGEC4HhNuacVql8ty1yoXLomAvEkoFKJgAiIgAiUSSA1AjWfA0VgmHGfFLb0wOanEcXxY489Bq4SwLQ4WerYY48tOByA8apimQxwyy1rTN7TqiBXJiIgAiIgAiIgAsEJeAvU4PenIuaSJUvMklFRVubRRx\/FWWedheXLl5uPA2SzWTjLTRXKh+NajzzySOQbF\/4vdE\/J1+g5pRVKoFOnQld1TQREQAREQAREQAQiJyCBaiPleNWouvvZrc9F+x1xyklR55xzDoYMGWLnVPx\/\/\/798bOf\/ayZFb+rgjHUvV9BuEq6HgmoziIgAiIgAsUJpFKgcl1TLsJfvPprYnDWf7t27daclLFdtWoVbrvtNrM4v+M5vfTSS80XrSzLCpzyGWecAbcFvjnKiPSerrtulCkqLREQAREQAREQAREoSqAEgVo0zZpE4LJSFJpBM1+2bFlTt34U3lMK4gsuuABXX301KFS5Nup1112Ho446CpYVXJwGLX9V4sl7WhXMykQEqkLg8suBQYNkUTIg06o0njIRgfojkBqBSg\/oBhtsYFqQM\/qXLl1qjv02XGyfIpXXt9pqK+5Ktvnz5+OUU07BfffdZ9ZV5YSoW265BUOHDk2uOJX3tOTnQTeKQMkEKnljLgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkckAuB+RyQC4H5HJALgfkcpVsMaUtAnVNIDUClR5Lrn\/K1uSsfIpGHvvZ22+\/bS5ZloVevXqZ41I2c+fOxdFHH41JkyaZ2zkR6u9\/\/3vBz5+aiHHfyHsa9xZS+URABERABEQgtQSiFqg1A8WvOe2+++4m\/0WLFmHmzJnm2GvD7vjXXnvNXCpn8Xyub3rCCSdg+vTpJq3ddtsNd911F3r06GHOE7uR9zSxTaeCi4AI1J7AzTffjO7duxs74ogj8O233wYuVP69PA58Y4iIfAdypRiWceDAgZg3b16IuxVVBKpDIDUClbh23XVXdOnShYcYN26c7y+FqVOnwhGovIfrppqbQmz4C+fCCy+E8xlTdudzghS790MkE8+o8p7Gs11UqjonoOonkcCUKVPAXjWu8JLE8qvMIlArAqkSqNtssw322Wcfw5K\/FEaNGgX3WNT33nsP2WzWrE\/Kxfz5VyS9r+amgBv+orn++uubuvUHDBiAK6+8Ep3oeQyYRmyjsQ6auR\/b5lHBRCBSAlwH2e4FggxFGZQBnp7Q119\/vYwUdKsI1B+BqgrUSuOl0Dz11FNBocq87rnnHgwZMgQ33XQTJkyYgIsuugjDhg0Dx43y+vDhw8FueR7nW373B7tA+Msl\/zqHDzA9J8yyLCNQmX4xe\/bZZ53b4rmX9zSe7aJSiUClCEicFhenZEQxX2IbsMeNK7xwX2ISkd5G5wy\/cjhnzhxMnDgRG220UaTpKzERiIJAqgQqgXCiFL2b3bp14yk++ugjjB492qwrym7\/xYsXm5n1I0aMwHnnnWeOTcQQG4rMBQsWNN3x\/PPPmyEFTL+YzZgxo+m+2B3Iexq7JlGBRCAgAUWLOQH26qmrP+aNpOLFikDqBCrp9unTBw8++KDpyu\/duzf4NSeGc6b\/4MGDwS89\/eEPf0CHDh0YHNpmzZoV+p5E3CDvaSKaSYUUARFIDgE6Q9q2bWsKzN44dfUbFNqIQFEC8RGoRYsaLgK7MEaOHIlHHnkEHHfKrow333zTfOmpX79+BT2nvNfp\/uB9J510UrPM6ZFleCnmTqtZwrU8kfe0lvSVtwiIQEoJDBo0CJzrwOqxiz+qrn7Or3j44YdxzDHHgO80Dkej0SnDuRi33noruKIN83Vb\/jC2\/Fn8DzzwgFl5gOn88Y9\/dN\/W4nzMmDFN8XnsjsD5GpyUfPzxxzcr4x577IGLL74YfIe679G5CDgEUitQnQpqH5CAvKcBQSmaCCSPgEpcWwInn3wyKBxZiii6+qdNm4aDDjoIp512Gp577jl8\/fXXTNrY8uXLjfC76qqrkMlk8Mwzz5jwIJtddtkFHCbHuBybmp8uw\/KNAtlJe9NNNzV55V+nOOackMMOOwxPP\/10szJ+\/vnnuPvuu7H\/\/vubry+uWLEi\/1Ydi4AhIIFqMNT5Rt7TOn8AVH0REIFKEuDyg1yWMIqu\/rfeekSz\/y0AABAASURBVAvHHXecmexrWRZ23HFH8DPbN954I\/h5bU4EZi8g60OPLVez4ZrdPC9mW2yxBfr37w\/+43wJTgjmsZd9+OGHcD54416ukfmeccYZePTRR82tLA+HOtxwww2mjAceeCDIgp8F51cXL7vssqZPj5sbtBEBm0Ar2xLwX0WsKAF5TyuKV4mLgAiIAJcjLLerf+XKlWaYGifpWpaF888\/H+yW5wdjKPoOPfRQMymY3s+f\/\/znBjq70d944w1zXGxjWZbxzLZp0wbLli0zQ+T87nEmC1uWhYMPPhhcRYdx2a3PicrO1xUPOOAAs1LAFVdcYeKxjBTT9Ko6q+jcd999eOqpp3i7TASaCEigNqGo0wN5T+u04VVtEVhLQLuqELAsC+V29X\/66ad45ZVXTHn79u0LeiUtyzLn+ZvOnTs3jXtl+AcffMBdIKNH1lmq8aWXXsLChQtb3EcP6ZNPPmnC+eXEnXfe2RxzQ6+rswwjwzkhmeXhtXzjUAKuH84P5bCLn19h5NjY\/Dg6rm8CEqj13f6AvKf1\/gSo\/iIgAlUiUG5X\/zfffIOuXbsa23fffQt+HIZe0FKqtcEGG2C\/\/fYzt\/JLiZxcbE7yNhShnHzMIH5inPXiMY0Cmh5eHnOtcS9xymu0rbfeumktcg4p4LABhstEgATSIFBZD1kpBOQ9LYWa7hEBERCBkgmU09XvLKHIiVbuFWHoheRYU65cc+6554JjXkst5J577gmOG2Wa7Mpnt31+Wgyjt5NxOFkr\/xpn7fOcXf7z588HVxrwM5aVcWmcVEUPMY9lIkACEqikUK8m72m9trzqLQIBCSha1AQsq\/yufk4uohD8\/e9\/b7yd7Jbv1asXKCw5c\/7++++H48Uspfzbb789fvKTn5hbJ0+ejC+\/\/NIcc8OZ\/S+88AIPwe79nj17mmNuKFodkcnxsn\/605\/MSgNcbcDPOIaW99JSu8Y4KycLTUACNTSylNwg72lKGlLVEAERSBoBdonTw8mZ7Cx7mAX8P\/74YzO+lMs33XnnnaCo4xcSmQ6NaW633XbgWqg8L8X4EZu9997b3MqufC5rZU7sDbv833nnHfsIOOSQQwoOMzCRtBGBEgmkXqCWyCX9t8l7mv42Vg1FQARiS6CUrn56J7nE1Msvv2zqxa8jDh06FJxsRK8px3++++67plv9V7\/6lYlT6oZrqHJ9U3bvc9ITPaI85mx7dv136dIFP\/vZz3yT72Q7QfhFR64iENTcwxZ8E9eFuiAggVoXzeyq5LrrAjRXsE5FQAREIAQBRS2DgGVZZj1Tp4uc40r\/\/ve\/gyLQL9l7770XnKDE61xGiov0\/\/nPf8bhhx8OzurnBCfLajmrn\/HDGmfXc31T3vfaa6\/hs88+M1397PJnGMWpM9uf5zSOSeV9POYyVRwOwGOZCJRCQAK1FGq6RwREQAREQATKJEAxxwlN7JZnUuzqpxeUx25jNz6FIsPbt2+P008\/HYVmyL\/++uuMWrJxkhMX\/edqAPTcMj129bPL37Is8xUoxnFnsO2225ogelk5VrWQ4DYRtREBHwL1LVB9oChYBERABERABKpBgF3pXI6JeXF9Uc6Q57HbKPTYzc5wCkNH1PLcbRyn6nzFyX0tzDknS3Xr1s14dbn4\/2OPPWaOf\/zjH8PxrrrTo2eX3fsM57ADCloeexknVR199NFmqSmOmXWGLnjFVVj9EZBArb82V41FQAREoOIElEEwAhSbp5xyCpyufr+7ON6Ui9vzOoXdPffcA3opeZ5vc+fONTPnuXfCOZHKOQ6z52QuCkfeQ+FM4\/HAgQOxySab8LCFcYIWx8XyApeZOvPMM5FfFobTli5dihtuuAH84hRXCVh\/\/fXRu3dvXpKJgCEggWowaCMCIiACIiACtSHg7ur3KoVlWfjFL34Bx3M6btw4M4v+1ltvNZOixowZY2b3c5F9dsVzQX8nrld6QcMGDRoEji3lOqU0dvlTtFqW91hXCm4udeWMT50+fTr4uVMuM8UlpTjhistjMd2\/\/vWvxiPLCVeXXnqpVgQI2ih1Ek8C1behdUEEREAEREAEqkMgv6vfL0fO\/D\/77LNhWWvEIcXfVVddZTym2WwWnMC0evVqcOwoJ1R1797dJMUxpPS6mpOQG66vyg8EOLex25\/rrjrnXnt6eseOHQuWl9eXL19uRDTLfsYZZ4DLY82bN4+XQC8tPal9+\/Y159qIgENAAtUhob0IiIAI1BuBV18FbA9c1S2JeVb42aDnsVhXv2VZOP744zF+\/HgMHjwY7BZnsSzLAr2wI0aMwJNPPonRo0djq622wg477MDLeOuttzBjxgxzHHZD7+mQIUOabmP3vpNvU6DHAYXnHXfcAQ5F4Nem6NF1onG4Qr9+\/Uw5n376aeyxxx7OJe1FoImABGoTCh2IgAiIQB0SSKJYrEWZKeYDPh5cz9NZ+5Pd4QFvMyKTE5Gce5mO+17LskBxd9ttt4Ffk2Lc2bNnm7GcV1xxBRyvqWVZuPbaa8Hrb7zxBnbZZZempCg66eHkNU5+2mijjZqueR2MHDnSpMP4Z555plcUz7CGhgb89Kc\/Bb8oxWW0eD+Ni\/3fd999xtPLsnjerMC6JyCBWtojoLtEQAREQAREQAREQAQqREACtUJglawIiIAIiEApBHSPCIiACAASqHoKREAEREAEREAEREAEYkVAArUCzaEkRUAERCB2BDIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJMBMhkgkwEyGSCTATIZIJOJXTOrQCKQFgISqGlpSdVDBERABAoRuOwy4Nlnk27xKj+ZFmKuayIgAiUTkEAtGZ1uFAEREAEREAEREAERqAQBCdRKUC2Upq6JgAiIgAiIgAiIgAgUJCCBWhCPLoqACIiACCSFgMopAiKQHgISqOlpS9VEBERABHwJDBoEWJYsSgZkCv0TARGoCAEJ1IpgLTVR3ScCIiACIiACIiACIiCBqmdABERABEQg\/QRUQxEQgUQRkEBNVHOpsCIgAiIgAnEl8NRTT6F79+5l25FHHonvvvsurtWsWrk++eQTXHDBBejXr18TUx7fc889VSuDMqodAQnU2rEPm7Pii4AIiIAIiEBdEKA4PeaYY3Dvvffi66+\/bqrzkiVLsPnmmzed6yC9BCRQ09u2qpkIiIAIFCSwyy7ALbfIbrmlOAOyKgjTvrjJJpvgiCOO8LWtt97ajrXm\/5577ukbb9CgQWjTps2aiHW6nTBhAmbPnm1qv+mmm+Lcc8\/FjTfeiD\/84Q\/I52giaJNKAhKoqWxWVUoEREAEghGg8JIBxRgEodmnTx+MGjXK137yk580JXPUUUf5xjv++OPRrl27prj1eDBr1ixT7fbt2+Paa6\/FKaecggMPPBD\/8R\/\/gS222MJc0ybdBCRQU9K+qoYIiIAIiIAIpI1A586dJUjT1qgB6yOBGhCUoomACIiACNQlAVW6hgRat24NelGhf3VHQAK17ppcFRYBERABEUgCAY675KoAAwcOxGeffQaOyxwwYICZ0c7Z7Oeddx44mSi\/LkuXLsXDDz8MTjBiHN5P6927N\/bZZx\/ceuutWLRoUf4tTcfz5s0D82L8m2++2YTPnDkTp59+etNM+h49emDo0KEYM2YMmBd8\/jU2NoL3Xnzxxdhjjz1MmZnujjvuiMMOOwwPPPBAi\/vffPNN7Lzzzibu\/fffb1L+6KOP0L9\/fxPG+7lSgrmQt\/nmm29MvQYPHgyWj\/FY32HDhnnmk3erGdvK+Kx3UMb59+u4cgQkUCvHNj4pqyQiIAIiIAKJJvDYY4+BgvTTTz819eDM9lwu12w5qmnTpuGggw7Caaedhueee67Z7Pfly5djzpw5uOqqq5DJZPDMM8+YdPw2FJi33XabGff50EMPNaW1atUqTJ8+Hdls1ghNt0BmeitWrMCVV16JAw44AHfffTc+\/\/xzBhtbvHgxpk6dirPPPhv7778\/3nrrLRNeyoZlpGDlhDPWa+7cuWD5mBbr+\/rrr5t8yCRIPkEYM21ZdQhIoFaHs3IRAREQARFIIYFqVOnjjz82go8z+48++mjccMMNGDFiBPbbbz9ss802pggUYMcddxwo0izLAj2VF1xwgZn5ft1114HexHXXXdfE\/fbbb80ELS9xaSLYG4rS\/\/t\/\/699BNBrS8HJdDhRqW3btiacQpXCkILUBKzdcGmov\/71r6CAZJ7Mm\/dyFj4nO2255ZYmJuv129\/+FvPnzzfnnPzECVGMt9tuu5mwLl26mLIyjLbDDjuYcG4oKE899VSwPpa1ps4UzoxH73O3bt0YzTA59thjQcFqAjw2LAvrWIixx20KqiABCdQKwlXSIiACIiACIlAuAQo9jsO85ZZbcNlll+Hggw\/GFVdcYYxjNFeuXAl6OxcsWADLsnD++eebru0TTjjBeEAPPfRQjB49GhMnTsTPf\/5zUxx6U9944w1z7LV59913sdFGG2H8+PGmO\/\/www8H06H4+8c\/\/gEKR9730ksv4f333+ehMYpFds+zzBSIjzzyiMmb91LcUjhS\/FL08oYZM2Zg8uTJPAQnRFF0Mx7FKgM7duyIvffe29SD4VxyiuEcPkAxSk9pp06dQDYPPPAARo4caeJSCD\/xxBNG2FNQk80111zTzOPMdBxjeQsxduJpXz0CEqjVYx3TnFQsERABERCBuBPYa6+94HgV3WVlt\/8rr7xigvv27Wu8q5ZlmfP8DQUgv1LlhH3wwQfOYYu9ZVk488wzzZhQ90Uul8VhAgz\/8ssvkZ8Ox6UyjNc4BtYRmjx3jIKSwxC6du1q1jTl4vvOtSB7ismxY8caz6tlWUa0c3ytZTWvc0NDA371q1+By3YxXYppRwzz3G2FGLvj6rzyBCRQK89YOYiACIiACNQjgQjrTLFHb6lXkpwkRLFH23fffUEB6BWPYezC5r6YbbbZZmZyklc8y7LASUjOtfwufsuy4JSTHttXX33VidZs\/9Of\/hRTpkzB008\/DXpnm10scsJJXryX0Xr16mXG1PLYyyzLMpPDONSAwpb5ecVjWCHGvC6rLgEJ1OryVm4iIAIiIAIiEJrAVltt5XsPPxDw4IMPGsF30kknNYtH8cixpuxqZ\/f6hRde2Oy63wnHia633np+l5FfnnwPKr20jqeX3epHHHEEfvnLX4LDAjjOkyLRN9GAF1gfGqNTcL\/wwgtm5QKuXuBlHK7gfPiAZf3uu+94awvLr1OLiwqoOgEJ1KojT1SGKqxctpUKAAAQAElEQVQIiIAIiECNCdD7t+GGGxYtBWewc4b873\/\/ezOBihOl6GHkLHdOJuLYUIrGogmVEYHeU+bleFhZJq4ucOmll4Jd6DvttJNZtore1e+\/\/76knL744gszMYo3c2mqM844w6xcwGEDXnbRRRfBqTeFrdeQgqCMmaesOgQkUKvDWbmIgAiIgAiIQB6B4IeWZaFVq8Kva3onOb6Ua4zeeeedmDVrFrikE9b+40Sh7bbbznR3rw2q2G7zzTfHuHHjcOKJJ4LCLz8jlomTpI499ljsuuuuZnIXvbz5cWpxbFlWUcbQv6oSKPzEV7UoykwEREAEREAERCAsAU6S4hJTL7\/8srl1nXXWMYvpc9kkek05gYrd3Oz+5qQhE6nCGw4P4GoC9Og+\/vjj4Kz6bbfd1qwy4GRNscplqv7nf\/4HpXb9cwkrrkgQ1Oi55eoEThm0jy8BCdT4tk3sS6YCioAIiIAI1J4A1x3lskssCZeR4iL9f\/7zn83ko759+2KDDTZoJgwZr1rGmfT8uhPHv3LZp3feeQd33HEHOOzAsiwjTP\/3f\/8X\/GJU0DJtvPHGTRPBvvrqK5Q6VCBofopXGwISqLXhrlxFQAREQAREwI9A4HB6IV977TUTn+t4nn766WY9URPgsSm0WL1H9NBBzz77rPnCFCdKPfrooy3u52SlgQMH4vbbbwdXHGAELkv14Ycf8jCQcbUCim5G5gcK6EHmsSxdBCRQ09Weqo0IiIAIiEAdEWDXOBfqZ5U5QYljTXnsZRyn6iUaveKWGsZZ9RSNFJ380pNTNnd6LCsX4Wc4RWuhpbEYJ9822WQTM36VYfPmzcNdd91lPLE89zJ+DpWTs+i15de1uLi\/VzyFxYtAq3gVR6VJDQFVRAREQAREoOIEON6Uk5KYEZdPuueee+A16YifQOUMd+4Zl8aJVNxHaTvvvDO47BXT5NhTft2JIprn+Uav7\/PPP2+CuOYqzZwE2FiWZb4Y5YhaClR+SYsrBrhv5woCXNWAbOhp5RCIQiLefb\/Oa0dAArV27JWzCIiACIiACIQmkH+DZVn4xS9+AUd0cfb8IYccgltvvdWsDTpmzBhwdv9+++0HijV2jztx89OJ6piikRO2mAc9lZwodeihhzaVhwKaa7VyfVQu\/WRZFo466igEWUYrv4wUwb\/5zW\/M2FoKU062Yh1vuummZvUePnw46DnmvfwgwJAhQ3goSwCBVgkoo4ooAiIgAiIgAiLgQ2DAgAE4++yzjVhjlOnTp4OCjR7TbDYLft5z9erV4Ix3Tqjq3r07o4EeRXoWzUmEG4pArj1KkUrvKdcqdcrDDwVwshRFJa9fcskloFgNm71lWeYTptdeey3oReb99A6PHj3arInq1Jv5WJZlxsWyTByCwLiy+BOQQI1\/G6WwhKqSCIhAHAjwK5QnngjIijMgqzi0mVcZLMsyYm38+PEYPHgw1l9\/fRPNsiyw63zEiBF48sknQfHGryXtsMMO5jrHis6YMcMcR7mxLMt0wfOzovRyduvWDZzNzzy45znDudoA10NlGK+FNcuyjOhmOhS+XOeVopfpWNYPdee422uuuabFmqyMJ4svAQnU+LaNSiYCIiACFSdA4SUDijGIoiEoEJ31OvfZZ5+iSTrx2TXPr0IVusGyLPBb8rfddhu49ijzmT17NiZNmoQrrrgCjtfUsizQ68jrb7zxBnbZZZemZLk+KNcJ5bWxY8cWFHQsP+PR2GXflEjeAcfGnnPOOaBQfe+998C43POc4cwvL3qzQ6fuLE+heLypc+fORqBznVd6j5lPft179uzZ5F1m\/Hxz8gnCOP8+HVeegARq5RkrBxEQAREQAREQAREQgRAEJFBDwFLUqhBQJiIgAiIgAiIgAnVOQAK1zh8AVV8EREAERKBeCKieIpAcAhKoyWkrlVQEREAESiaQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQLZLJDNAtkskM0C2SyQzQKZTMnNoRtFQASKEJBALQJIl+NFQKURAREojcDAgcBll8miZlBaa+guERCBYgQkUIsR0nUREAEREAERSD8B1VAEYkVAAjVWzaHCiIAIiIAIiIAIiIAISKDqGUgPAdVEBERABERABEQgFQQkUFPRjKqECIiACIiACFSOgFIWgWoTkECtNnHlJwIiIAIiIAIiIAIiUJCABGpBPLqYHgKqiQiIgAiIgAiIQFIISKAmpaVUThEQAREQARGIIwGVSQQqQEACtQJQlaQIiIAIiIAIiIAIiEDpBCRQS2enO9NDQDURAREQAREQARGIEQEJ1Bg1hooiAiIgAiIgAukioNqIQGkEJFBL46a7REAEREAEREAEREAEKkRAArVCYJVsegioJiIgAiIgAiIgAtUlIIFaXd7KTQREQAREQAREYA0BbUXAl4AEqi8aXRABERABERABERABEagFAQnUCKgvWrQI119\/PQYNGoRtttkG3bt3R79+\/XDeeedhzpw5EeSgJGJLQAUTAREQAREQARGInIAEaplIX3zxRQwZMgQ33ngjPvjgAzQ2NpoUv\/76a9x3333Yf\/\/9ceutt2LVqlUmXBsREAEREAEREIHiBBSjvglIoJbR\/q+\/\/jrOOOMMzJ8\/H5ZlYY899sCVV16J6667DgMHDkRDQ4MRpldffTXGjRtXRk66VQREQAREQAREQATqh4AEaolt\/d1335lu\/QULFqBt27a47LLLcNddd+Hwww\/HoYceijvuuMNYly5dQK\/qX\/7yF8ydO7fE3HRbMgmo1CIgAiIgAiIgAqUQkEAthZp9z6uvvorJkyfbR8C+++6LESNGGC+qCVi7GTBgAM4880wT\/umnn+LBBx9ce0U7ERABERABERCBkgnoxtQTkEAtsYlzuRxWrFiBNm3aYPjw4WbvldR+++2HHj16mEsTJ04Ex6aaE21EQAREQAREQAREQAQ8CUigemIpHEiRyfGnjLXZZpuhZ8+ePPS0zp07Y9tttzXXPvzwQ3zyySfmWJu6J+AJ4IYbbgDN86IC64IA259WF5VVJT0JsP1pnhcVWBcE2P60uqisTyUlUH3AFAqmQJ03b56Jsummm6JTp07m2GvTunVr9O7d21ziclTs6jcn2oiAB4GXXnoJNI9LCqoTAmx\/Wp1UV9X0IMD2p3lcUlAgAsmPxPanJb8mpddAArUEdhSonCTFW+lBXXfddXnoa1tssUXTtVmzZjUd60AEREAEREAEREAERKAlAQnUlkyKhnzxxRf49ttvi8ZzIhQTsE487UXAIaC9CIiACIiACNQzAQnUMlvfGV8aNBmK26BxFU8EREAEREAERCBSAkosIQQkUKvcUMU8r1y66sgjj4SsPhmw\/Wlq\/\/psf7Y725\/GY1l9Pgdsf5ravz7bn+3O9q+yPIlddhKoVW6SQhOqfvazn6F\/\/\/5VLpGyixMBtj+tYJl0MdUE2P60VFdSlStIgO1PKxhJF1NNgO1PTZDqShapnARqEUDFLoed9LTxxhv7JsnPpo4dOxYyMdAzoGdAz4CeAT0D1X8G4sScmsBXMNTBBQnUEhqZIrOQJ9SdpDPjn+Fc2J97mQiIgAiIgAiIgAiIgDcBCVRvLgVD119\/fTgz87ke6uLFiwvG\/\/jjj5uub7XVVk3HOhCB6AkoRREQAREQARFIPgEJ1BLakAJ1o402Mnfyy1BLliwxx16blStXYvr06eYSvyrFdVPNiTYiIAIiIAIiIALJIaCSVpWABGoJuClQ+\/bta+787LPP8P7775tjr838+fPx9ttvm0s\/\/vGPsfnmm5tjbURABERABERABERABLwJSKB6cykamslkwPGky5Ytw7333osVK1Z43vPMM8\/gww8\/NNcGDhwIiltzoo0IVJ+AchQBERABERCBRBCQQC2xmXbZZRfQePv999+P22+\/HatWreJpk02aNAl\/\/OMf0djYCHbtH3LIIU3XdCACIiACIiACIpAWAqpH1AQkUEskyklSv\/3tb9GlSxcjQK+99locfPDBGDNmDB544AGceuqpOPbYY7FgwQJYloWTTz4Z3bp1KzE33SYCIiACIiACIiAC9UNAArWMtuY41GuuuQYbbLCBSYWTobLZLM4++2w88sgjxqPa0NCA888\/H0cccYSJo40IxJWAyiUCIiACIiACcSEggVpmSwwaNAhPPvkkTjvtNHAJKcuyTIoca3rYYYfh8ccfxwknnAAKVXNBGxEQAREQAREQgXoioLqWQEACtQRo7lu4fNRZZ52FZ599FrNnz8acOXMwdepUsNu\/e\/fu7ug6FwEREAEREAEREAERKEBAArUAnEpf4uSpd999F6effjr69esHitltttkG9Mreeuut+OabbypdBKVfQwJc3eHnP\/+5aXe2fTG7+eaba1da5RwZgW+\/\/dYM+WF7P\/XUU4HS1e+KQJgSEynsM6DfFYlpWs+C8ud35syZuPjiizFgwADwPc+f\/x133BHsaeW8laVLl3remx\/IdOpJM0ig5rd+FY+5LNX\/\/M\/\/4Be\/+AUeeughfP311yZ3PoAffPABrrrqKuy777549dVXTbg26SPwxRdfYNGiRemrmGrkS4CfPb7sssswZcoU3zjuC\/pd4SaS7PNSngH9rkhum7O9OTflgAMOwN13341PP\/0UfM+zRvwKJXtbOW\/loIMOwltvvcVgT6vH3wMSqJ6PQmUD+XDecccduP76681EqnXWWcd4VG644Qbw5dVt7Wx\/LvJ\/yimngH95VbZESr0WBNiuXEfXsixwjVxOpCtkvXr1qkUxlWdEBJyfZ3pLgiap3xVBSSUjXinPAGum3xWkkDyjqBw1ahTuuusuI0o5F2W\/\/fbDlVdeCb7vjznmmKZJ1nPnzjUr\/3iJ1Hr9PSCBWoNnnl+Wuu2228wDu8UWW5i\/qvgQc5mqo48+Go899pjp9rcsC\/yFduONN\/p+CKAGxVeWERGYNWuWSYlLlV100UXgM1DIOPTD3BC7jQpUiABfLuzKpweFayMXiuu+pt8VbiLJPC\/nGWCN9buCFJJnL774Iu677z5TcL7rx48fDw7VOvzww82ylL\/73e+Qy+Vw6KGHmjhclvKWW25p8b6v198DEqjmsajehr+o+JDyQbQsC2eeeSb69OnTrAD8QtWJJ56IwYMHm\/CJEyfijTfeMMfapIMAu3Y4oY614edvN9poIx7KUkSAH+54+eWXMWzYMLOSx8KFC0PVTr8rQuGKZeRynwFWSr8rSCF5tnLlSvAjPvSi8p1+4YUXx0fP7gAAEABJREFUYuedd25REa6pzms9e\/Y015577jlwyUpzYm8aGxtRr5pBAtV+AKr5n2MOnfFnPXr0wJ577umZfYcOHfDrX\/8afLA5hoUrBHhGVGAiCfCl88EHH5iyU6BymIc50SY1BN555x0cd9xxmDZtWlOdOEGCvSRNAQUO9LuiAJyEXCr3GWA19buCFJJn\/Pl1uuu333577LHHHr6V2HDDDbHPPvuY65xAxzHH5sTeMJ161QwSqPYDUM3\/9Jq9\/\/77JkvO4Ovatas59tpwLKpznR5U\/qLyiqew5BH47LPPmiZI9e7dG61bt05eJYKVWLFsAvxZZtcex55vvPHGdkjx\/\/pdUZxRkmKU8gywfvpdQQrJsy+\/\/BLt27cHe8fYvV\/MCUFPqlct6\/n3gASq1xNRwbBPPvkEnBjDLLjUhGWtWdif527jF6q23HJLE0xvmwSqQZGKDQfE0zNuWRb41zWXDjn++OPBP1qc5Ud4zhme7OpNRaXrrBKWZaFv3764\/fbb8cQTT4CTIzhJIigG\/a4ISiq+8SyrvGeANdPvClJInm233XZ4+OGHMXnyZHAeSSEnBH\/HU4iylpZlNfuwT+HfA2j2L22aQQK1WfNW\/uTzzz9vymTbbbdtOvY64F9fjgf1q6++Qr7b3yu+wpJDwJn0wL+q6VXjEiNPP\/00nD9CuOf58OHDccYZZ4DdPsmpnUpKAhxb\/re\/\/Q177713sxcOrwUx\/a4IQineccp9Blg7\/a4ghXTbxx9\/bIQsa7nJJpuYdVJ5TKvn3wMSqHwCqmjOL5sgWfIvLorUIHEVJzkEvv\/++6ZB8PSivvDCC+AYJE6M41\/a2WwWu+22GyzLMis9cJ3c3\/zmN6kUqclpteqXVL8rqs88bjnqd0XcWiT68tB7SicFPaVMfa+99sJmm23GQ2P1\/HtAAtU8AtXfdOrUCUHHorF0HBbgLObPc1lyCdA7ysWanRpwiREuQ3T++efjwAMPxMiRIzFu3DjQ+8YlqBiPIpZhPJbVFwH9rqiv9s6vrX5X5NNI5zGXlRw7dqypHB0Vxx57rOechBJ+DzR9AMgknsCNBGpCGo1LVVCkJqS4KmYBAkuWLAF\/2XD4Bldx+P3vfw+vAfKc8c118riSA\/\/K5np6XBe3QNK6JAJmDUX9rkjHg6DfFeloR79aPProozjrrLOwfPlytG3bFuw9c5ab8rsnaHgaNIMEatDWrnE8ihR199e4ESLKnjM677nnHvO5S3pJvcSpk9WgQYOwyy67mFNOlpgxY4Y5rouNKlkSAf2uKAlbLG\/S74pYNkvZhaLDgWubOuKUkyfPOeccDBkypOy0nQTS8HtAAtVpzSrvOeklzKQnitP111+\/yqVUdrUmQPH6k5\/8xBSDfxFLoBoUdbXR74q6au6SK6vfFSWjq+qN\/HgDvyTJxfkdz+mll15q1ky2LP9VfaL+PVDVSpeYmQRqieBKva3YzP38dPklCqerjhOm+FdW\/nUd1wcBvnicmlKkOsfap5uAfleku30rUTv9rqgE1ejS5KTYCy64AFdffTUoVLmKy3XXXYejjjrKTIr1yqmefw9IoHo9ERUM4xISTvJc29Q59tpTnHKxX17jLx6OWeSxTAREIP0E9Lsi\/W2sGtYPAc4fOOWUU8C5BOzi54SoW265BUOHDvUVp6RTz78HJFD5BFTR+FlLdtczy2LLRyxcuBAfffQRo2KrrbYC\/9oyJ9okngD\/kp43bx64jEyxyuT\/IRPmr+li6ep6vAnod0W826dapdPvimqRrlw+nD\/ATxxPmjTJZMKJUH\/\/+98Lfv7URLQ3Nfk9YOcbh\/8SqFVuBX49auuttza5Tp8+veAyEDNnzoSzSO9OO+0kgWqoJX9z+eWXg+3Zv39\/cLJUoRrxr25+TYpx6EHnHyo8lqWfgH5XpL+Ni9VQvyuKEYr\/da5vesIJJ4Dve5aWa1zfdddd6NGjB0+LWj3\/HpBALfp4RBuhc+fOZhF2pvrOO+\/gueee42ELW7p0Ke69916zUDu79zmbu0UkBSSSACc9WdaawfD\/\/Oc\/sWjRIs96sBuI19977z1zfffddwe\/521OtClEIBXX9LsiFc1YViX0u6IsfDW\/mRObOBlq9uzZpizszucEKXbvm4AAm3r+PSCBGuABiTKKZVk47LDDzDqYnPDCNTBfffXVZlkwnGNT+KlLXhg4cKDxuPFYlnwC9Jz26tXLVGTatGm45pprwD9ITMDaDcUpxypxAD2PuWD\/8ccf77mA89pbtEsZAcuy9LsiZW0atjr6XRGWWHzi8\/f29ddfD6dbn+taX3nllebdH6aUlhW33wNhSl9eXAnU8viVdHefPn3wm9\/8xgyMXrBgAY444giceuqpeOCBBzBmzBgccsgh+NOf\/mS8p\/xL67TTTgPXNCspM90UOwJs07PPPrtpyAa7+ekh58zOhx9+2DwD\/LoUvyzlLEPCP2T43MSuMipQRQmwzfW7oqKIY524flfEunkKFo5D9CZMmNAUx7IsUKBedNFFKGbPPvts0308qNffAxKobP0qm2VZ4OfMOC6FS0dxuYlHHnkEFC38koQzVoW\/nG666SZwQHWVi6jsKkxgn332Ab3kbGNmxQlTPOcfI3wG3nzzTfMHCifGjRo1CkMiXMCZ+dWzJanulqXfFUlqr0qUVb8rKkG18mlSZNIB5eT0\/PPPY9y4cYHMvd61ZdXn7wEJVOfpqfKeHtHf\/va3+Ne\/\/oWDDjoIziL8lmWZGftcK+3JJ59s+opQlYun7KpAYI899gCHcbCLf7vttjOfumO2\/KOFY00pVjlGediwYcbbzmuy+iOg3xX11+buGut3hZtI\/M+LrdITtgYJ+T0QtloF40ugFsRT2YuWZYHChN35nKk9Z84ccDA1\/\/Kid3W99darbAGUes0JcALc8OHDwa59es75DHBSFIUrP4PHAfI1L6QKECmBk046CWxnGr1jQRK3LP2uCMIpKXFKeQb0uyIprbumnKNHj276OefPehjj87EmleZby6qv3wMSqM3bX2ciIAL1TEB1FwEREAERiAUBCdRYNIMKIQIiIAIiIAIiIALpJRC2ZhKoYYkpvgiIgAiIgAiIgAiIQEUJSKBWFK8SFwERSA8B1UQEREAERKBaBCRQq0Va+YiACIiACIiACIiACLQk4BEigeoBRUEiIAIiIAIiIAIiIAK1IyCBWjv2ylkERCA9BFQTERABERCBCAlIoEYIU0mJgAiIgAiIgAiIgAiUT+AHgVp+WkpBBERABERABERABERABMomIIFaNkIlIAIiIAKFCeiqCIiACIhAOAISqOF4KbYIiIAIiIAIiIAIiECFCQQUqBUuhZIXAREQAREQAREQAREQgbUEJFDXgtBOBERABGpCQJmKgAiIgAi0ICCB2gKJAkRABERABERABERABGpJIAqBWsvyK28REAEREAEREAEREIGUEZBATVmDqjoiIAJpIqC6iIAIiEB9EpBArc92V61FQAREQAREQAREILYEKi5QY1tzFUwEREAEREAEREAERCCWBCRQY9ksKpQIiEC1CJx77rno3r17UevduzcOPPBAXH\/99Zg3b17B4jlp7rzzznjzzTcLxi3jYlm33nzzzU11fuqpp8pKSzeLgAiIQNQEJFCjJqr0REAEUklg+fLlePfdd3HjjTdi8ODBuP\/++9HY2JjKuqpSIiACIlBrArUVqLWuvfIXAREQgTwCe+65J4444ogW9qtf\/Qo77LAD1llnHRN78eLFuOiii\/DYY4+Zc21EQAREQASiJSCBGi1PpSYCIpBgAkcddRRGjRrVwq666ipMmDABU6ZMwWmnnQbLskCPKr2p8+fPj2WNVSgREAERSDIBCdQkt57KLgIiUFUCHTp0wHHHHYe+ffuafGfMmIFp06aZY21EQAREQASiIxBjgRpdJZWSCIiACERFoFOnThg0aJBJjmNQZ82aZY61EQEREAERiI6ABGp0LJWSCIhAnRBo3bp1JDWdM2cOLr74YgwYMADbbLONmVXfr18\/HHPMMXjmmWewatWqQPl88sknZliCO53TTz8dU6dObTmZK0CqzPsvf\/lLU7k4Mey9994LcKeiiIAIiED5BCRQy2eoFERABOqMwBdffGFqbFkWtt12W3McZrN06VIjKPfff3\/cfffd+PTTT5tE5Ndff43nnnvODCU48sgj8fHHH\/sm7aSTyWRw++23t0jnoYcewvDhw3HllVdixYoVvum4L9Az\/Ne\/\/hWjR4825erWrRu4LFWPHj3cUXUuAiIgAhUhkFSBWhEYSlQEREAEihGYO3cunnzySROtV69e4Fqn5iTghkLxv\/\/7v42gpJeyoaHBeFApIm+44QaMGDEC6667rknt5ZdfxrHHHgt6SE1A3qZYOsOGDUPbtm2NwKTYvOOOO8xxXhKehxSnt912G66++moTX+LUE5MCRUAEKkxAArXCgJW8CIhAOgh88803ePTRR3H00UcbTyXFH2f0b7jhhqEqeO+99+Kee+4x92yxxRYYP348xowZg8MPPxwHH3wwrrjiCkycOBEHHHCAiTN79mxcfvnloLfUBKzdTJ482azFytMuXbqAAjQ\/HXo\/\/\/GPf4DXHNE5c+ZMRvc1xrvrrrtw3XXXSZz6UtIFERCBahCQQK0GZeUhAiKQCAInnHCCGQfq9WWpvn374je\/+Y3pcqco\/X\/\/7\/81iciglVu4cCEoGikE6SW99tprPT2wnTt3xh\/+8IemaxSsXOLKyef777\/H3\/72N7PUVZs2bfC73\/3OeGGd685+l112Mcti8XzBggV49tlneehpLNN9991nhh5wCS2OieWwAXXre+JSoAiIQIUJpFKgVpiZkhcBEahzApZl4e2338Z3330XisQ777wDekR501577QUKSB57GUUqvbW8xu78XC7HQ2McA8uvWvFk++23B9PisZftvvvu2HLLLc1YWYrZlStXekUzHx245JJLjOilOL311lvB7n3PyAoUAREQgQoTkECtMGAlLwIikBwCfl+S4tel9t13X2y00UZmkf558+aZiUf8wpTX+FC\/GnPdVIpNXuds\/WKrAfTs2RMUqoxPYcsvWPH4ww8\/xJdffslD9O7dG+uvv7459trQAzpx4kQ88cQT+D\/\/5\/\/AK89\/\/etfOOuss4w45fVTTjnFT5x6ZaEwERABEYicgARq5EiVoAiIQFIJ+H1Jil+XuuWWW8Bxn0899VRT1\/v06dPNJ0+DelLzx5FutdVWRTF17dq1acIUBSm79nnTsmXLmmblB0mH9xQyzvZntz7j0MN60003eU7M4nWZCIiACFSDQP0J1GpQVR4iIAKpJcBu7xtvvLHJw0jR+uqrrwaq7\/vvvx8onlckek8pHr2uRRHGetGDzLToreUaqJXMj\/nIREAERMCPgASqHxmFi4AIiIAPAc6+d8Z9ssuey0H5RG0WvPXWWzc7D3Oy6aabomPHjmFuCRyX4pTrnHKpKw4r4ORp+xMAAARHSURBVI1cXSB\/3CvDipmui4AIiEBUBCRQoyKpdERABOqKwMYbb9xU388\/\/7zpuNBBhw4dmi5\/8MEHTcd+B+zWd4YPcFkry7JMVK6dallrjoOkY24qsDn33HPBsaqbbbaZWamAk6nY5c+lqvgRgQK36pIIiIAIVISABGozrDoRAREQgWAEOJPeibnJJps4hwX3XNif4o+Rpk6dimJd6IyzaNEiRjefHF1nnXXMMT24XN+UJxwHy69P8djLKHBHjhxplqE6\/fTTwfVc3fGcMjF8yJAh2G+\/\/XgIrpvKpaa4BJUJ0EYEREAEqkRAArVKoJWNCIhAegjw86P8HClrZFkWuEYqj4sZl4TiEk6Mx\/sLjV2lMGU3O+NSQGYyGR4ao0BlWjzh0lUvvvgiDz2NKwe8\/vrr5uMCS5YsQbt27TzjOYHMK\/8DBGPHjsWkSZOcy6XvdacIiIAIhCAggRoClqKKgAiIAJeVYpc4P3lKGvSKBv3c6QYbbIBf\/\/rXZqkqejbPO+88TJs2jck0M4pTrknqXOvfv3+zNVM5VOA\/\/\/M\/zadMOQaWY0eduPkJzZ8\/H\/wYAPOi8DzssMOKClTez3Goxx13nCknu\/qZPtPiNZkIiIAIVIOABGpwyoopAiKQcgJ33XWXWTbqoosuarG\/4IILMHToUNCT6XzVieNCzz77bPDLUkHRcO3Uww8\/3ESnJ3b48OFgF\/w999yDCRMm4OKLL8bAgQPx6KOPmjj0llLI8stTJmDthnGGDRtmzpx0TjrpJOSnM3jwYDhlpTjdZ599TPwgG679+tOf\/tRE5TCCMWPGmM+fmgBtREAERKDCBCRQKwxYyYuACCSHwPPPP49x48Z52r333gsKtVWrVpkK0Rv65z\/\/GRSBJiDghp5MCmCuuWpZFpgeu9AvvPBCnHHGGbj77rubvlBFzyw\/adqnT58WqTOdyy+\/HCeeeCI4aYrpcDF+dzqWZYHilHnynhYJ+QR06tQJ559\/PrhnFJbDEbs8j9aUmgiIgAg0JyCB2pyHzkRABETAk4BlWeZLUlxeisKUSzDRI2lZa2bTe97kE0hvKMXlk08+iREjRiB\/khW\/CsU8ODmJY1C5BJRPMqDgpIh8\/PHHPdM56KCDwDSuueaapgX\/\/dLyCu\/bt6\/x7vIahwlcddVV4PADnstEQAREoJIEJFAjoqtkREAEkkmASynNmTMHxYyL13NR\/jvvvNN09VNk+tXYSZPjQnfccUe\/aOjevTuuuOIKcJKTkz9n7jOPvffe23hGfW\/Ou+CXzp\/+9Cf069fPjCXNi24OORzAyZNC2wS6NpZl4Zxzzmli889\/\/hOdO3d2xdKpCIiACERPQAI1eqZKUQREQAREIDoCSkkERKAOCUig1mGjq8oiIAIiIAIiIAIiEGcCEqjVaB3lIQIiIAIiIAIiIAIiEJiABGpgVIooAiIgAiIQNwIqjwiIQDoJ\/H8AAAD\/\/xx+OVsAAAAGSURBVAMAfLLPyf+L76EAAAAASUVORK5CYII=","height":302,"width":340}}
%---
%[output:85d28524]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202604\\English_Fig1B_LearningCurve.svg\n","truncated":false}}
%---
%[output:3235e23b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Arguments_deprecated：ShowScatter参数已弃用，将在未来版本删除，请改用Flags参数"}}
%---
%[output:4cd90a67]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAS4AAAEuCAYAAAAwQP9DAAAQAElEQVR4AeydiZrUuJJGpWIrmn1tdpp5kZl58rn3SYq12Zodmh0mj2lVufI6M51ZXmT78FWQtiyFQkf4J2wrXVshhJ+aDPw34L+BIf0bQLhm8fojAQlIYDgEFK7hzJWRSkAC\/xBQuP4BMaYPxyKBsRNQuMY+w45PAiMkoHCNcFIdkgTGTkDhGvsMO75xEHAU+wgoXPtwuCMBCQyBgMI1hFkyRglIYB8BhWsfDnckIIEhEBiHcA2BtDFKQAKNEVC4GkOpIwlIoCsCCldXpO1HAhJojIDC1RhKHTVLQG8SWExA4VrMxiMSkECmBBSuTCfGsCQggcUEFK7FbDwiAQk0S6AxbwpXYyh1JAEJdEVA4eqKtP1IQAKNEVC4GkOpIwlIoCsCCldXpFf3Yw0JSKAmAYWrJiirSUAC+RBQuPKZCyORgARqElC4aoKymgQ2IWCbdggoXO1w1asEJNAiAYWrRbi6loAE2iGgcLXDVa8SkECLBHoVrhbHpWsJSGDEBBSuEU\/uqqEdP3483LlzZyO7fv16OHTo0G4XbFOGv99\/\/323vK+Nra2tcO7cucDnJjGcPn264HLz5s1w9OjRTVwUfHJismgQzBfzRqzM46J6OZUrXDnNhrE0QgDRQXB+++23EGNsxKdO8iKgcOU1H71F8\/Xr1\/D27dva9uHDh\/Dz58\/\/jDeDEjLJTTOtDMI3hBoEFK4akKZQ5dOnT+HFixe17fXr1+HHjx+7aL5\/\/x4ePXoUdnZ2wtOnT3fL3ZBAGwQUrjao6lMCEmiVgMLVKl6dS2AMBPIbg8KV35wMMiKeRvFUiqdTPKUqD4Knctws5xg3zql78eLFcOvWrfDHH3+Ea9euhRMnTpSbhMOHD4fz58+H1I62t2\/fDleuXAncdN9XebaDz9R\/Ok6\/9EHb+ZhmTdb+OXPmTEh9pLhPnTq1tp+qBtyXu3z58u54GSt9weDIkSNVTSrLGPO8nxs3bhRPWGFU2WhFYYyx4A5HjLlb0aT1w1ut92AHEigR4Kb5pUuXAic8J1KMMRw7dixsb2\/v1mIZAyctQoGApQO05QRHhDi+zgmdfGzySZyIKyKCMOAjxl9xcxIfJBbGd\/Xq1YAgI97s45+x0hcM8H\/27FmKFxrt8EPdeT9woj1jgN9CJxUHiAPeqd27d+\/CX3\/9VVGz26Ktbruzt6kT4ATiJPj8+XN4\/vx5YR8\/fgzv378v0CBoZGWcMN++fSuecj579iw8efIk8EDgy5cvRT1OagQwxl\/LHXg4wMMFHgzgm0qUcZLR9s2bNxStbYgW4oS44o8Y8Pfq1avAk1gcEgsnNwLBfl1DbMiOtv8RbcZLnIwBNn\/\/\/Xfx5DbGWGRMFy5cqHS9yg98eZBCPZgRb6WjuULmgPiYLw7lIlrEonBB4UBm43UIxBgDSyn+\/PPPQqwQLIQAseFEIVvgE1F4\/Phx8ZST+px8iAVlbNMnQpEuC9nnySgnOwLDPp\/sU59jlK1rMcbispUYHjx4EIgBfwjYw4cPAyczPomF7IjtukYGhyBSH\/\/4e\/nyZSBmuCBgcEpiffLkySJTpX7ZEPvkh7a0KfuBL\/EiXggx\/3mU21dtMwcIZY6iRbwKFxS04oTg\/kUdS\/+YN8GGmJBVVLWNMRarzcPsD0JDBjLb3PfDyYd44Afbd7ClHUSVDKhq3RoCgZDRNSKKgLG9ysiyqE892pMZVvlHtOibcSMmKRulHUYWhdizjdiTdVZxgTn9UA+RW5V1IaoIJfURZ+JjOxdTuHKZiYnEwQnICVY1XE7cGH9d+nFSc4JV1UNI7t+\/H8hQyFSq6jRZxolLbFU+GU+KgWymrqgzvhh\/jRX\/+KnyTxnilUQHYSyLDowoox5xVIk9xzCyMUQN\/jH+6pvyssUYA5kWWRzlxJabaBGXwgUFrbhfU3fl\/LKTYxVKTppFJynlZFr4QAS42YzxPz+ZBeUd2W43jBWh3C2o2EBYEAQOlUWF\/UWW6tEOJovqpfLEJca477uTCBd1YJfEjf0q4\/ITwefSsWpMMcbiSS5ZHe0ZF5eYbOdmW7kFZDz9EODE4DKjjtU50RaNghNs0THKOVHSSRVjLJ42ckOZZREsEeBGOVlNjNUZAz6aNOJFXJb55Dj1qIPg8rnMYtyLnbbYsvocKzMviziXjxynf4ztTY3MLV124gNxXfe+He26MIWrC8r2sUtg0SVXqkCGw81lBIztVM4nJymXMCwdYH1WLicVY8KIsY4xjjoCt8gX7Rcda6KcS84klAgZl7VN+G3Sh8LVJE19NUaAG\/A8xcMQMbKwckbBycvTMayxTjd0FGPcfQtFjHGlF8ZRJ8ta5IhLuEXHDlrOPS2Wn\/DQgRgRWNbVwfugvptsv4lwNdm\/viSwlABZFyJGFpbuz3CTmZOfk4kMrHzptNTZBgfpg5N3WVOOU486xMvnMitnZ7TFltXnGJdxfC4y+scWHa9TjiAiWNSFMZkX21wy5vAfBLEkU7gSCT97J8ASgXQZyH2s+YA44bkBzfomTiyOc9K3KVz4XiUa3CAnDuLhXiGfqwyRoA7tVvmPMYbEAwapLe1Tf4hWqkN5lSFA3CvkK0DpBvx8vRj3MkYy3STEPCBhfubr97WvcPVF3n4rCXBycDJzb6WywlwhlzNkX3PFje5y0iIMVU4RtiQC3BdKQlJVt1yG8CJClJE1LvLPcYQNLmzTR1m4uISGAccQrmV+uFdFvPirwwy\/iBd1mRPWdsW4J2z02ZcpXH2Rz6zfHMLhhEwnPicZglEVFxkOJynHOKlSVsD+vCVxmC9fZx\/RqLpUijEGnnIiBPjj0mpZLNRJxjgRL\/YZC35i\/E9RIEviqSqCxFhZssIn7TCEjGUObMNlkR\/GkAQWsUt9026Zcc+LWKmD\/yoOHOvaFK6uidvfQgKckJyY\/E\/P\/\/AshOSLwTw95ORGyDiJWdvF8VSfz7LTJFZkF\/hABDlxy3XqbhML\/omBLzDzSSzcsOayi218cQnL6nS26xr3kxAR6pNhcglHVkO8jJXvPzJ+xIs6iA3iyHbZYFb2Q1zzfrgEhxnjSVlU2ceybe4xJkFG\/FI8y9q0fUzhapuw\/tciwMnJicIJRpbB\/\/KchJx4iBYndIwxcJwTn4xgvgMyEMSG9tRHABAa9ufrrtqnH1aOkw1ywqZYyDwQAtojWulrOezXNcSAdkl0EFqEkXgZKwIWYyy+aI0oUpdxzfvHD4tKU2ZEXFV+aAszGM\/7WLbP2BFH6sAQBnyy35cpXH2Rt9+FBBAjvs5DZsBJnTIoPtmnnNdEU6\/KCScmJzmXUZys1EEUNj3ZOHH5cjfigZDhj08EC8HA2Kd8XSNGnpjig2wqxcsn\/dInY0VwlvmmPjHu8zNrQDl9wAymiPqseO0fWDNeGpJlknmx3ZcpXH2Rz6Bf\/iHyjniMrOIgIXHicoLhi6d+ZV+cgKzH4ljdfjjhyLw4qe\/evVu8y55P9imnv3If89uIFyfqvXv3irb0T2YyX2\/RPhkG8TIm+iIexIMlGZTziUjAcJEP2tGe+vNM5tvgh\/VTKV4+aUufCM98\/UX7VX7gsIwZsREj\/RFzlW\/Gz3iphyGEVfW6KlO4uiLdQD9kDFxG8AYH\/tdrwKUuJDBIAgrXgKaNewvc9xhQyIYqgVYITFe4WsHZjlNutnJzmvU+7fSgVwkMi4DClfl88Rifx\/BeGmY+UYbXKQGFq1Pc9Tvj0TtZVlqzVL+lNSUwfgIKV4ZzjGhxE76cZfG0iEfjGYabUUiGMhUCClfmM826JR5DY+s8zs98WIYngQMRULgOhK+dxiy0ZO0TYsW6JbKtdnrSqwSGSUDhynDeWHDIokAFK8PJMaSuCVT2p3BVYrFQAhLImYDClfPsGJsEJFBJQOGqxDKuQt6MwLIKjO1xjc7RTJGAwjXsWa8VPYtYsVqVrSSBARBQuAYwSU2EyLuaeO0Jbwlowp8+JNAnAYWrT\/r2LQEJbERA4doIm40k0B4BPa8moHCtZmQNCUggMwIKV2YTYjgSkMBqAgrXakbWkIAEMiMwOOHKjJ\/hSEACPRBQuHqAbpcSkMDBCChcB+NnawlIoAcCClcP0O1yjoC7EliTgMK1JrA+q6ff9cfvtfOVN33OhH33TUDh6nsG7F8CElibgMK1NjIbSEACqwm0W0Phapev3iUggRYIKFwtQNWlBCTQLgGFq12+epeABFogoHC1AHW1S2tIQAIHIaBwHYSebSUggV4IKFy9YLdTCUjgIAQUroPQs60E9gi41SEBhatD2HYlAQk0Q0DhaoajXiQggQ4JKFwdwrYrCUigGQJdCVcz0epFAhKQwIyAwjWD4I8EJDAsAgrXsObLaCUggRkBhWsGwZ\/NCNhKAn0RULj6Im+\/EpDAxgQUro3R2VACEuiLgMLVF3n7lUCOBAYSk8I1kIkyTAlIYI+AwrXHwi0JSGAgBBSugUyUYUpAAnsEFK49Fqu3rCEBCWRBQOHKYhoMQgISWIeAwrUOLeuOnsDRo0fDzZs3w61btwLbox\/wQAeocA104gy7KQL7\/fz48aMo+P79e8CKHf\/KjoDCld2UGFDXBM6ePRvOnDlTdPvz58+QxIttCjmOsa3lQUDhymMejKInAltbW+HEiRPh\/PnzxeXhb7\/9VggX2dapU6eKy8Zz584VdajbU5h2O0dga27fXQlMigDZ1YsXL8LHjx9DjDFcvHgxbG9vh+PHjxdidvjw4fDly5fw+vXrQtCCf7IgsEK4sojRICTQKoFPnz6FJ0+ehAcPHoQPHz7s9sX2o0ePAsb27gE3eiegcPU+BQaQCwGyK7ItsjAuFdnOJTbj2E9A4drPw72JEkC0uEyMMYaXL18Wl4aHDh0qLh05NlEs2Q5b4cp2aloLTMcVBLg5f+zYsfD58+ficvH9+\/fFfS\/KOBZjrGhlUV8EFK6+yNtvVgSeP38e3r17V2RaXCpi3JCnjGNpaURWQU84GIVrwpPv0PcIIEx\/\/fVX4EZ9KmWbMo6lMj\/zIKBw5TEPRiGBAxGYWmOFa2oz7nglMAIC2QoXq5R5qhOjN0VH8O\/MIUigUQJZCdeRI0fChQsXwu3btwvjG\/rXrl0LCBijjjGGS5cuFYawUaZJQALTI5CNcPG9sKtXr4bTp0+HRaLETVKOnTx5MiBoddfXTG9aHbEExk0gC+FCtMi0Umb17du3yleKxBh3s6+UnSFkwT8SkMCkCPQuXAgQrxSJMRZfZn38+HHxnTHWzszPBBkXx\/lCLMf4SgZfhmVbk4AEpkOgd+HilSKIF1kWYsXamWX4ES\/W1nz9+rW4pES8ltX32EgJOKxJE+hduJLwkEXx+pA6s4HI\/f3330VVXq\/r5WKBwr8kMBkCvQoX97QwaNcVLepiiBefiFaMkU1NAhKYCIFehavMmNeIlPdXbfNdslV1PC4BCQyJQP1YexUu7lelULnkS9t1PlN9BKzsp05b60hAAsMm0KtwITrcZAchrw\/hLpkjnwAAEABJREFUso\/tVcb6Ld4NTj0yNfywrUlAAtMg0KtwgZhX4iI8CBfruShbZogbv7yAJ5G0o\/2y+h6TgATGR6B34eJpIksgECR+BRRf6SGjinH\/DfcYY\/ELDK5cuRJYOc9U8NI32rM9fnOEEpBAItC7cJE18apcnioiXojSzZs3w++\/\/17ESGZ1\/fr18McffwREi8yMA1wi0o727GsSkMB0CPQuXKDmPtfTp0\/3vcSNcizGuPs1n\/DPH0Tuzz\/\/LFba\/1PkhwQkMCECWQgXvFmXxdd5+FVQvC4XMStnUxznfha\/Roo67NNOk8CACRj6hgSyEa4UP9kUX+l5+PBhuHfvXtjZ2SmM33n37Nmz4hcYpLp+SkAC0yTQu3DFGItLwRj334wPK\/5wP4wlEXxBm+0V1T0sAQmMiECvwsXXfXivFi8M3N7eXgsrN+m5gc\/N\/BjXE721OrKyBCSQHYFehWsFjaWHedq4tIIHJSCB0RLoTLjIqHh3Vtm41CPrgm7V8XLd8jbrvTDaYX7lBwqaBKZDoDPhIkO6fPlyYC1WsosXLxb3t8CNEKXyVZ+snE+CxyLU8tNHfGkSkMC4CXQmXCxxYIV8kzgRLX7bcJM+9dUuAb1LoAkCnQkXwb548SKwDisZyx5YAc8xBCiV1\/m8f\/9+YBGq67mgp0lgWgQ6FS5Ehu8WJuMtpkm4yMZSeZ3P1G5a0+Vox0vgf2ZDa8pmrkb+06lwzbNEfFIWxmXf\/HH3JTAdAv83G2pTNnPV5U8PffUqXIw3ZVreYIeGJgEJ1CHQu3DVCXJZHVfNL6PjMQmMk0A2whVjDNvb24Gv8PDLYVcZSyl4\/c3Vq1d3l1SMc4oclQQkME8gC+FCsJIInT9\/Ppw+fXql8bZUXjg4P6Ds9g1IAhJonEDvwsVCUt56yue6o+O+GDf1XTm\/Ljnr50fgf2chLbJ\/z47N\/1C2qP583fHt9y5c5cyJZRC8uoZX2iBI4H716lVgn7VdrPXiSSTlvP6GV92wFgwBo0yTwHAJ\/GsW+iKbHar8Wbd+pZNBFvYuXFwmQg4hQrR4WSAvEeRpI+W8BSKt\/0LEeIkg67\/49WRnz56liiaBjgnYXd8EehUungim+1RkW+XMKWVcfMcxxr3X1pBxIWCIGdkaAtY3RPuXgAS6JdCrcMUYQ7o\/hRCVh07WRVmMMSRxS8fJzhA2hI\/3caVyPyUggWkQ6FW4yogRqvI+okUGhmhV3bhPl5JkZOV2bktAAuMn0IJw1YdGtoU40aJKgJYd45KRdouEjWOaBCQwTgK9ChfClAQo3aRPmMuiVnUfqyoLS239lIAExk2gV+ECLU8RETDecMqqecowhCtdPvJkkftZlCdLQkdb6qZyPyWQH4Gfs5AOYv89az\/\/Q9lBfNJ23udw9nsXLpY2IFAIE6vmb9y4EXhaCEKeNCJKZFwsUuWTS0q2ETrqcKMe8WK7KyM+fskHv137zp074fbt24G3uxJfUzHgD991jF8a0lS\/C\/xYLIGsCPQuXAgTi0jTJSPCdOLEiRBjLH6HIuIFMd5Pf\/369YCw8SQRoaMNGRvHuzDupxED35MkC4zx1zINYiFmvjeJ+B40Fvx5KXxQirYfM4HehQu4ZE0sLEWEEDIyKD45xvu6WPrAdtmo8+bNm5CeLpaPtbGNaJEFpayKmJ4\/fx6ePn0aeC01IorgcLnLO\/EPEgN+knDRz9u3b8Myg0GMv0T0IP3aVgJDIZCFcAGLE5+V83fv3g2IFWUYyyJ4RfPLly8DJzEih8AhGAgXdbowvvhNloVg8tUjYnr\/\/n3gUpeMkX0ueYmFukng2F\/XEEmMdggWPJYZHJLQ00aTQB0CQ67Tu3CRWZBhlCEiYuV9tjk5EQcyMwSOLIPyLozLVy5P6QvxJBa2y4bAImDEzngQr\/LxdbYRvRhjwFcSw3XaW1cCYyfQu3DxfUNeacMN91xhk2khsMRHtkfWxfa8IaYY5Tw8SFkT++sYwkV9sijEi21NAhLYI9CrcJGZsKyBTzKWvbDy2uLBABERIxkX24ssZUiMaRPhinHvK074UrgWkbZ8ygR6Fa4Y924oc+8qp4lIsSBAKdsi01olJCnjol3KnJKvOp\/0xaUpdRHKGGPgZj9ZKUsjWILBUox06Uo9TQJTI9CrcCECnJxA3+Qkp13bFmMMiFCY\/SFWYp5tLvwpi9smY0K4Yvwl6GRsLL\/gcpptOo0xBi5dubRGwJLIcUyTwFQIbPU90LSUgAwiXZL1HVO5f4QkCVe5fNE296WwRcdXlSNE9Ek97pPFGIvlFjyQwOCFOHIcAWPt2CYCSXtNAkMl0LtwsZyAEzLGGFIWwaURJy0nJCfxMovxV3bSxQSsyrbmYyDuGNeLjzEnP9zj4kkqTyt5KICxzRth4UY9+oAX29oKAh4eDYFehYuTjkshsga2yWzIIrg0unLlSuDYrVu3wjLjcom2uc7IJtkXl6SIFmvV2J4fGwLKui7qcAyRx9heZDwEgbMit4iQ5UMi0KtwDQnUprHGuF7GxUJb3qVPVpWEqapvBI3FqRyLMYZVwkU9TQJjIdCrcJGNcPnDCbip0R4\/XUzIupkdmVGbsbE0gz4Ye\/kSk\/1542nn48ePA6+9nj\/mvgSGRmBPuHqInJvMfH2Gy55Njfb4aSt8hGEd\/zHG4gvibcVT9osoYpSlT7Y1CYydQK\/CNQS4CEISLp74cR9uWdwcT5lZrmvTlsXvMQkMgYDCtWKWEC2yLqohSmk9FftVxk1wymm3qXDRD4afZUYdjDopRrY1CYydgMJVY4bLSw\/IupY1SfeaEC5uoC+rO38M0WNlPC8m5J1f88fn93kHWBIu7mHNHw\/BEgmMk4DCVWNeyzfBWSibxGK+KcLDcg7KeQHiusJF\/fQkkaeESQTxN28cQ7goJ7NTuCChTYWAwlVjphGTlHWxur\/qLadcQpIlcX+LbIunpDVc76uCcKV+EMfkb1+l2Q598VLDcl+0nR3yRwKTIKBw1Zxmnl6SeVGdd86zOJa3nSJkFy5cKBbLpstIRIssiLrzxvvh+bI0VvXOLt71lbInsjf6QcDIrjC2WXSb+uJlhnwNaL4f90dLwIHNCChcMwh1fshoeFVzEi8u1ci8ECIEiAyJTAvhOchaKXzwFSguNYmLrAqhJMPC2KaMeggky0iop0lgSgQUrjVmm0vG9N1BBIylEjRHRFgIywJPVr5TdhDjCeGTJ08Cb3vFL6KZ\/HGMDIs4FK1Exc+pEVC4NpjxJBx3794NOzs74d69e4EsadHlYbkLvn9IG4yMqXxsfht\/+OUrQNTH7t+\/H\/iiNSI6X999CUyFwKCFi0sm7gOVJstNCUhgAgR6FS6Eh5vP3Kjm8f86vKnPWyO4WY2fddpaVwISGDaBXoXrIOgUq4PQs60Ehk2gM+GKMQbEZt7CP3\/my5ft80SPpQg0jTGGdJOcfW18BByRBOYJdCZcCA2XdmXjMhERIijeflo+tmy73I6b1AoXBDUJTIdAZ8LF+iaWEDSJlqUBrJlSuJqkqi8J5E+gM+FCXFjjxBKAZKz6Zg0UmPiqSypf9ckqdtY58ZZQlgzQXpOABAZE4IChdiZcxMlXWVg0mQwhS4srEatUvuqTLIuV5Un08K1JQALTIdCpcM1jJQtjZTiilQRsvo77EpCABOYJ9CpcZExc9pFhcZN9Pjj3JSABCVQR6FW4qgKyLIQgBAlIYCmBzoSLl+yx2p3PckTsU76p0b7sz20JSGD8BDoRLhaT8s4qfskrn+yDlk\/2Kd\/UaI8f\/GkSkMA0CHQiXNNA6SglsIyAx5ok0IlwsVCUG\/CsveKTfQbBJ\/uUb2q0xw\/+NAlIYBoEOhEuULKGi7VXfLKfjH3KNzXaJ19+SkAC0yDQmXBNA6ejlIAEuiCQiXB1MVT7kIAExkJA4RrLTDoOCUyIQCfCxXIFXkXDm06bNvzif0Jz5lAlMHkCnQjX5ClPE4CjlkBrBBSu1tDqWAISaItAJ8LFOit+DyC\/WmuR8TsE07u1eE\/Xonrz5fjFf1uA9CsBCeRHoBPhYti8wgaBWWbUw+rUTX6oSxtNAhJon0AuPXQmXLkM2DgkIIHhE1C4hj+HjkACkyOgcE1uyh2wBIZPQOFqcA51JQEJdENA4eqGs71IQAINElC4GoSpKwlIoBsCClc3nO1lqASMO0sCCleW02JQEpDAMgIK1zI6HpOABLIkoHBlOS3DD+p\/ZkNoymau\/JHAPgIHE659rhbv8NoZXj+z7JU2t27dCkePHi2cnDp1KiyrWz6GX\/wXDf0rGwL\/N4ukKZu58kcC+wh0Ilz7enRHAhKQwAEJKFwHBGhzCUigewKdCBdvcuC1NTs7O6Fpwy\/+u0c31h4dlwTyJ9CJcOWPwQglIIEhEVC4hjRbA4r1f2exLrJ\/z47N\/1C2qP58XfcloHD5b6AVAv+aeV1ks0OVP+vWr3RiYRWB0ZUpXKObUgckgfETULjGP8eOUAKjI6BwjW5KHZAExk9A4Qph\/LPsCCUwMgIK18gm1OFIYAoEFK4pzLJjlMDICChcI5vQLobzc9bJQey\/Z+3nfyg7iE\/aln26PW4CCte459fRSWCUBBSuUU6rg5LAuAkoXOOeX0cngfEQKI1E4SrBcFMCEhgGAYVrGPNklBKQQImAwlWC4aYEJDAMAgrXMOZpdZTWkMCECChcE5pshyqBsRBQuMYyk45DAhMioHBNaLId6tAIGO8iAgrXIjKWS0AC2RJQuLKdGgOTgAQWEVC4FpGxXAISyJbAgIUrW6YGJgEJtExA4WoZsO4lIIHmCShczTPVowQk0DIBhatlwLpfi4CVJVCLgMJVC5OVJCCBnAgoXDnNhrFIQAK1CChctTBZSQIS2JRAG+0Urjao6lMCEmiVgMLVKl6dS0ACbRBQuNqgqk8JSKBVAgpXq3hXO7eGBCSwPgGFa31mtpCABHomoHD1PAF2LwEJrE9A4VqfmS0ksJyAR1snoHC1jtgOJCCBpgkoXE0TbdDf1tZWOHv2bLhx40a4fft2uHPnTrh582a4cOFCOHLkSIM96UoCwyKgcGU6X9vb2+HatWvh3LlzhUghYoR6+PDhcPr06XD9+vVw5swZijQJTI5A98I1OcTrD\/jo0aPh8uXLhWD9+PEjfPz4MTx\/\/jw8e\/YsfPjwIfz8+TPEGIts7NSpU+t3YAsJDJyAwpXhBJJlHTp0KHz\/\/j28fPkyPHnyJLx\/\/74QLcSLfY6RhXEpSd0Mh2FIEmiNgMLVGtrNHB8\/fjxgtCbTevfuHZv77NOnT+HVq1eBbIxLR7OufXjcmQABhSuzSUa0YozF5SBZ1qLwuGT89u1bcZg2ZF\/FTi9\/2akEuiWgcHXLe2lviM+xY8eKOojS58+fi+2qv8i2vn79WhziCSOZV7HjXxKYAAGFK6NJRriSACFKiNOy8Lhk5Dj3uDC2NQlMgYDCldEsI1wpHG6+p+1Fn+U6ZF2L6lkugQ0IZJeLMdMAAAMySURBVN1E4cpoesiaUsZVJ6xVGVkdH9aRwBAJKFyZztqXL1\/WiqyO4HETvwlbK7AOKzcxtjZ8dIhgra6aHOtaHTdQWeFqAGIOLsqXmVXxsBL\/ypUroQmr8p9DWRNja8NHDmyqYmhyrFX+2yxTuDajm12rZZeN6SZ+U0H\/1507IUdranxN+7lz579Cjtb0OLv0p3B1SXuNvvjazxrVA8snFtVnsSqr7bUnxbcQ5NA8h0X\/9toqV7jaIruBX54SLhOgeZerLg\/L9VmFr30svvcph+Y5lP+tdbGtcHVBuWYf5cu9OjfbeQqZXLPuK237uRkBWw2HgMKV0VwhXCnjQrhWZVTb29tF9GRqWLHjXxKYAAGFK6NJRrjS13wQrWWLSjme7oORbSXBy2g4hiKB1ggoXK2h3cwx91943xaXgSdPnlzo5MSJE4E6VKANose2JoEpEKgtXFOAkcMYESGMWBCuqrecconIO7vIusi0ql59Q3tNAmMloHBlOLMsX+CeFcJ0\/vz54hXOiBhZ1qVLlwILB8m2yLJev35dvHAww2EYkgRaI6BwtYZ2c8d83Yc3nSJeeOFVNwgWr3NGwGL89b4uRMtsC0La1AgoXJnOOKvdHz58WLzplJvvZFeEyqXh27dvw6NHj8KbN28o2txsKYGBElC4Mp44xIqsCgG7d+9e2NnZCQ8ePAgvXrwIiFnGoRuaBFoloHC1ilfnEpBAGwQUrjao6lMCvRGYRscK1zTm2VFKYFQEFK5RTaeDkcA0CChc05hnRymBURGYmHCNau4cjAQmS0DhmuzUO3AJDJeAwjXcuTNyCUyWgMI12akfzcAdyAQJKFwTnHSHLIGhE1C4hj6Dxi+BCRJQuCY46Q5ZArkTWBWfwrWKkMclIIHsCChc2U2JAUlAAqsIKFyrCHlcAhLIjoDCld2UrA7IGhKYOgGFa+r\/Ahy\/BAZIQOEa4KQZsgSmTkDhmvq\/AMefBwGjWIuAwrUWLitLQAI5EFC4cpgFY5CABNYioHCthcvKEpBADgSGIVw5kDIGCUggGwIKVzZTYSASkEBdAgpXXVLWk4AEsiGgcGUzFVMLxPFKYHMC\/w8AAP\/\/CBNJ7AAAAAZJREFUAwBCZ9VMScIanAAAAABJRU5ErkJggg==","height":151,"width":151}}
%---
%[output:68fbb553]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202604\\English_Fig1B_FirstSessionPerformance.svg\n","truncated":false}}
%---
