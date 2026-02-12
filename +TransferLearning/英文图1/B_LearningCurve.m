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
f.Position(3:4) = [9, 8]; % 90mm x 80mm
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
    	lg = legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2))); %[output:5c266b7f]
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
% Keep B plot unchanged; generate a second SVG from the Fig1C bar-plot logic.

% Run the original A and E scripts to populate base workspace summaries
try
	evalc('TransferLearning.Fig31.A_FirstSessionPerformance');
catch
end
try
	evalc('TransferLearning.Fig31.E_FirstSessionPerformance_AudioWater');
catch
end

% Retrieve raw tables left in base by those scripts
try
	rawA = evalin('base', 'Fig3_1a_FirstSessionPerformance_Raw');
catch
	warning('English_Fig1B_FirstSession:MissingA', 'Missing Fig3_1a_FirstSessionPerformance_Raw; skip extra SVG.');
	rawA = table();
end

if ~isempty(rawA)
	% Extract per-mouse performance vectors (LightWater)
	naiveA = double(rawA.FirstPerformance(rawA.Group=="Naive"));
	tranA  = double(rawA.FirstPerformance(rawA.Group=="Transfer"));

	DataCell = {naiveA, tranA}; % {Naive, Transfer}
	CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

	% --- Plot (transparent background, 30mm x 15mm)
	f2 = figure('Color','none', 'Name', 'English Fig1B First-session performance');
	try
		f2.Units = 'centimeters';
		pos2 = f2.Position;
		pos2(3:4) = [3.0, 1.5];
		f2.Position = pos2;
		try
			f2.PaperUnits = 'centimeters';
			f2.PaperSize = [3.0, 1.5];
		catch
		end
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

	tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
	nexttile;
	[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
	ax2 = gca;
	ax2.FontSize = 6;
	ax2.Color = 'none';

	try
		ax2.XTick = [1, 2];
		ax2.XTickLabel = {'Naive', 'Transfer'};
		legend(ax2, 'off');
	catch
	end

	% Asterisk font size
	if isfield(Optional2, 'MultiCompare') && ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
		for pt = Optional2.MultiCompare.PText(:)'
			pt.FontSize = 6;
		end
	end

	% Bar styling (match B curve colors)
	colorNaive = [1 0 0];
	colorTrans = [0 0 1];
	try
		if numel(Bars2) == 1
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
	catch
	end
	for eb = ErrorBars2.Object(:)'
		eb.LineWidth = 0.5;
	end
	try
		ax2.XLim = [0.5, 2.5];
	end

	ylabel(ax2, 'Hit rate', 'FontSize', 6);
	title(ax2, 'Block#1', 'FontSize', 6);
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
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAKoAAACqCAYAAAA9dtSCAAAAAXNSR0IArs4c6QAAGOFJREFUeF7tnXtwFUX2x08ID5GHArIYQH+8EUQoS6ggJSCKD+KCoiIGRFAR1Nqfj9oqfrWluFCWfyzlLr7qp4v4QCWAoKjxga4KyEuRh4qiCREUkIggAYIPAkm2vn3pm76TmXunZ3ru9Aw9Vank5s6j+\/RnTp9zuvt0Tm1tbS2Zw0hAcwnkGFA1byFTPCYBA6oBIRISMKBGoplMIQ2ohoFISMCAGolmMoU0oBoGIiEBA2okmskU0oBqGIiEBAyokWgmU0iloJaWltLOnTtp+PDhRrJGAkoloAzU1atX04svvkgjRoyg0aNHKy2kuZmRgDJQKyoqaN++fVRWVkYFBQWRkezKlXVFXbEi8ffFFxMNHRqZKpwUBVUGKqS1bds29iOCOm7cOMrPz6d77rknVIEeOUJUWUk0Z06iGDNm1EHJCwZAtQcVFcGByvADf4uf8f8WLeTlLd6jfXuivDz5ewR0ReCgdunShbZv3x5Q8Z1vy8Hcs6cOTkA6ZQoR2uDvf896kbw9kFcEV6My\/Ni4kQg\/4ud0T7jgAvtvxXuIZ4wcqZWQYgdqeXlCuXDtyeHkWlQjJVEfHBFKJzB5lwDwRPicQMwEstN1AFUjYSkF1e6VzZZGBaCiwuHtyTWoRjKvE5P4VjlpQ1RErAwqJB7o4r1085n0O+7ZvHmms7L2fSxALS2tM9F4u6I98dOzp1byTjSs9a0Sm1vs0sXugAMKu0UziLJBa+RBtUKKdkabwjHq0SMbIpR4hlWDcii5nch\/825d1J6aOTcStVZyaqRB5ZCifadOTQCKHygcLSG1s014M1ptTv7\/kxxQLobIgipq0v79if7974RvoR2kcJBKSlK9c\/GtctI3BtAUyUQOVGu7o80BqLaaNJ0BjaYAkPw4CW1Pt3ZBpEC1U07wN6BNtVRAotOEgnIDWkvV7xaZcM6LFKjW2DTv8pU7TgBMDPl4CdOIb5Wo9tHO2tkn4cAn89TIgCr2oKig2PZKQ1BWtS12y7yrdgMuL7CBVIZHx3MjAaoVUmhW3uUrV07Wh9mJLpOdwbt8Ho7YsCFxl0zXKWnSeN5Ee1DtuBG9\/KxoUxlYnbp8A6mvN0hrUO0GcAL18t1oU1HcdvBZ42bQpgZSX5DiYm1BtYNU7PJR+NC0qROsojblXn5RkYajD765yfoNtATVaSg80MC+rDa1g1UMSwQWksg6I1o8UEtQ7aZIWp1npdpUfDO4AyQ2jzgVDiMLbqbUcW9PaUG1YCaUQmgHql10yAopJJWJFSlpim+G3cOs3\/PxWqeH8CFS5QFeqVrF6mTtQbXjRqlvYrUz0GXzcJJdU\/N5hE6wioa00abKXhbtQBVNRTtIlWpTq\/oWJyinEzF3lACr9eDaFCrfgBp\/UJ2YUapNrQ6U6K1lErEdrIGORGQqULy\/106j8rbGbzuFpcw2tdOmTg91YsD6NhltGtjbohWoYAdhR+4wW2utjTYVC8btE7xBYsGVvVGBtX2kbqwdqHCU7SJASiG1OlDWkQS+LklsSr7mXZylz78HrFwbmyl8gbwAUqD+\/vvvtHjxYiopKaHJkydT586dk4XavHkzLViwgPr06UNjxoyhpk2bsu9kVqGCH6zStYKqFFKn+Jf40HTa0Gk0QlyIZ5wo5bBKgfr+++9TmzZtqHv37jR\/\/nyaNGkSA\/Lw4cP07LPP0pQpU2jdunV02mmn0YABA6RBhW+DNhajQ0ohRYnSTcXC926mY6VbRao0LKG8vSN7QylQ58yZw5KgnXXWWTRv3jwaOXIktW7dmo4fP05FRUXUsmVL2rVrF1177bXUoUOHJKhI5+Mmpc+CBUT\/\/GedE6UcUjfa1K02dBpydQN6ZHEJr+BSoD733HMMzrZt26aAigRpyOQ3atQoWrt2LXXt2pUGDhworVHFWLpySFVpU7Gt7MZ63YIeXptH8slSoL7++uvUu3dv6tSpEwN17NixTIsiMdqmTZvYZ\/y9fv16Gj9+vBSoUHZwpGAeIoGZ8swmTnMGRdtUFjLrPY02DewlkAL1xx9\/JHT\/rVq1YnbqoEGDaNGiRTRhwgTW9Tds2JB2797NgO1xYmG9W2dKdKSsWWt8196uy7d6+l4hE2H1eg\/fFYz\/DaRA9SIOt6ByRwpx1MJCL09Kc42dPSkG53GpH1uDmwCyGllxNeN8O+1ARa4GpVlO7LSp3fCnH8jwDMRXlRY8ztjJ100bULkjhazPbhZ5uq6q1eHh803F2U+my3YtzrBO1AJUKKS\/\/jUxuKMU1EyLrrjU\/WjTsFruJHuuNqDyoVNljpQbB8ptgP8kg0LH6moBKvf4oVWVOVKZ1lkbbaojj45l0gJU7vErc6ScHCiIwaqyzSynSACrBajckSouVhTod3KgrEtMjBMVCUhRSK1AVeJIuRmBMt1+ZADlBQ0dVO7xo0CYkLJxY2KHsqFediRzGzM1TpQB1SqBTCNT1qHTYcOGsVssX75cXphuHSjc2YSk5OUb4hWha1SwNW5cIo4Kj98zqG4TAkDYfoZLQ2ysk\/nRWoAK5cY9fs+gGgcq1hyHDqrV4\/cEqtsRKNPlRxbmUEEVV51yj18aVLcjUKbLjyykoYen+GRpxOBhp2IyijSobqbwGS8\/0pCGDqrdZGkpUGW0qfHyIw1rqF2\/3dCpFKhGm0YaPpnChwoqd6TEpMyuQXWTktqMQMmwoPW5WoAqjvG7BtUp22+g2Su0bstYFy40UK1Dp3xWvytQ7bSpUypIMzsqFgBLgZoupc+OHTvYCtWzzz6brUptfoI8pyFUp1WnGUF12rDMLmWkGYGKBaTSXr9TSp\/Kykq2zh8pfgAsMqecf\/75TEjKQbVzoIw2jQ2QThWR0qhOKX2QdGLFihV04MABlkWlsLAwY5I0aFQoPOtk6bQa1SkchaXP1rmmRpvGCl4pUJ1S+gBUJKCYNm0abdmyhfbu3ctS\/3CNapd76q23EhlRrNswcVCXLVtGq1atovz8fGrBN9B1CkfxfdDFpjG2aXxBhUZcs2YNdevWjdq1a8cSoImHU0ofJEYrLi6mO++8k6X0QVpKEdTt27fXExoH1TpZmoM6a9Ysmj17NktvOWTIEJaFJWMmPv4Uo01jBWmKjfrTTz\/RkiVLmPbq1asXyx81ceLEOm1GROlS+ixdupT2799P+\/btS8md6mSjYtop8jVgsrS4jp+DirSWhw4dYs\/v2LEjkZtMfLx5jDaNL6jQhEeOHKHy8nKWV6q0tJT69u3LUkz6OdKBivmn1rV2jjaqFVRr7iijTf00k\/bXJm1UQPr444\/TwYMHWW7To0ePspymTZo08VUJJ1BzchL2qXV5tCOoVvvUmjvKaFNf7aT7xUlQEVLCD0DFkZuby1JKBgUqvH6kxbema3IFqlM4ytimuvPmuXwMVOTfh41ZVVXFnCgcsEfvv\/9+lmLSz5Eujor7WvOgOoJqtyGu1RY1M6T8NJXW1zJQoUl5oJ6Ditz8fMMIPzVIByqiTtaEaLag2m0vbt2EyqzR99NM2l+b7PphkyL8tGfPHqZZf\/nlF3rggQdY9+\/nUAIqH9vnmfjs9io12tRPM2l\/bRJUeP0\/\/PADHTt2jIWnvv76a7rkkkt8a9V0oNqlP7fVqNyRctoc1dim2oPmt4ApoGJEqVmzZtSoUSMGLfL1i3tJeXmYE6joze3yoNqCyu1Tp52fTdzUS9NE6poUrx+jS4ihvvDCC5SXl0d33XVXYBrVNajcPjVx00iBpbqwSVBhm2Ko86KLLlL6jEyZUqwPq6dROah23b5xoJS2lc43S4KKESk4U9grCt5+Tk4O24GvQYMGvsrvG1TRPrXO3jcOlK+2idLFSVCxTeTWrVtZ0B8HAv0YQg0q4O8kpHoalYNqtU+NNo0SZ77LKjXNz8vTfGtU2KZ29qnRpl6aI7LX6A0qt08xZIqDz2Ax2jSywHktOAMVa6EwW+qPP\/5gXj8ORAD4prxeb47rfGlUHui3TkAx2tRPk0TyWgYqhk+x6S6A5UOo55xzDl122WWJCcs+Dl+g2tmnRpv6aI3oXspA\/fXXX1mQH79ra2tZbbTw+u3sU6NNo0ubj5InNSpm0peVlYXu9a9ceSI1OkabsPJPnNJntKmPpo72pQxUTJrGRBTxCEujJssgBvp5\/NRo02jT5qP0DFSs+Pzmm2\/YHFQcmOGPYP8NN9yQTCTh9RmyNmryOXb2qRnT99oMkb8uJTz1ySefsAoNHDhQWcV8gYolquj6MffUdPvK2iSKN9ITVLuJKGYqXxT5UlZmBirW4WOZM37j6Nmzp+0QarrcU7gO98B8gZtvvjk59OpJoxr7VFkDx+VGKaCKlbIb63fKPYXrMEcAa\/Fh5953330ZU\/qkFaBon6Lbh21q7NO4MOepHlJDqE65p\/Bk2Le\/\/fYbm3B94403poBql9InI6jGPvXUoHG9SApUp9xTyLKC+OdVV11FixcvrgeqXUqftAK1BvqNfRpX\/lzXSwpUp9xTAPGNN95g662w1go5qHjkQNpGNfap68Y7mU6UAtUp99Qtt9zCnCc4WwsXLvSnUe0mShv79GRi0rauUqB6kZa0RuXdPs95auKnXsQeu2v0AtXET2MHmKoK6QWqXbdvxvdVtXWk76MXqHz9vjhR2tinkQZMVeH1AVXML8UX8hn7VFU7R\/4++oDKu31xIZ+Jn0YeMFUV0AdUsdvnmfqMfaqqnSN\/Hz1Atev2IVpjn0YeMFUV0ANUu24\/i\/bpuHHj2FwFc\/iTAEYjsY1TEIceoNp5+1m0T6UHJYJoiRjcM0g5hg+qU7efRfs0SAHHgD\/XVQhSjuGDatftZ9k+DVLArlsZJ9ZUUe2BV4iqtxI1uYByTr8u7eW\/HCOavqOa\/tEll1r4S78gVUynk4OUY\/ig2nX7WbRPIfQgBSxDQPXO\/yOq2kK5ef2IjlZS9fHzKfdPtzneYuaOGiraV0uT2hH97X9yZR4VyLlByjFcUJ2S9GbRPtUH1Gqq3nop0XGi3HbnUM3RCqo53oIadplrC9XuP4iGf1FNtTlEDXOI3jsvlzqeEgh\/rm8aX1Cdcp9m0T7VB1Si49tupgYVZVTbvDHlVFYRdRhBDTpOtwXlf7dV0\/sVdV8VtMqh2d395bJ1TaTDifEF1S7In2X7VCdQ6fdvqeabOxO26qntKbf7\/xM1alsPi7LfiK76qrre\/\/\/TL5fO9rfRoi9W4wmqJt2+VqDCn\/rpX5RTspBq+82gBqcX2IKz8mAtTSmtqffd3B45NPj08LRqPEHVKKVkkAKWVVFfbl5Nv5Z\/Qn\/qUUBdu\/W2vbziGNHgzdV0TPi2SQOilf1yqVUj2SeqOz9IOYbnTHFQxZTnWfb2eRMFKWBZDLDmDLlq+\/fvn3Zn71f319BTu2tpVxXRWY2J\/tIhh65pG542DbpnChfU4uK6lD2oaZadKB1BRZmwi6LfvRNkXxAV5wf5wocL6siRiXTnmHwSkjYNWhOoACAq99AGVKeUPkj+u2bNGnrzzTdZOqCxY8cmswA6Fv6tt4hmzEgkQAtRm3JQowKD7uWUzuHgskJSGtUppQ8SUCDxBNbzf\/HFF2zjX+T\/T6uthg0jKiysm8oX4pS+IDWBy3aIxWlBylEK1HQpfbik3377baZNhw4dmh7UmTOJ\/vznxGUhdvum61f3jmgDqlNKH1QV3f+HH35I2KX69ttvT25SgcLb5p7iXn\/I3X49UKHpkfdK1+Pii4mWL9eydNqA6pTSB5AuXbqUCe+aa65J2ZbSsfAc1JC1aT1Qc3KINmzQEgRWKITzTmwIgo+bN28m7GozevRotkEIdrcZPHhwvV3BcQ5+sLV9UIc2oDql9Ln00ktp1qxZhC1\/sHcqNv4dMGBA+q6fgxpSSEpsrBQBRwxUrEx49NFHaebMmcyRffLJJ+mKK66gbt26UWVlJVVXV7M09zU1NSw1KD6feuqprPrIvoi\/sb8YfvzufasNqF7exLQatbKSqEcPL7dVek3UQYUz+91339HUqVPZFvYAddOmTcwcwz5hAPLCCy9kAwkHDx5kWhXa991336XevXvT+vXrqVOnTvTzzz\/TxIkTPe8tFl9Q0e03b64UOi83izqoqDO0JTJ+7969m6688krKy8tjG4jg59ChQ+x\/8B\/wf5yHAQU4vWvXrmUjYGeccQZ98MEHdNttt6UdEUsn3\/iCmpfnhSvl18QBVAy5Pv\/887R69WqaNm0aLV++nGCStWzZkt577z1mtwLUIUOG0EsvvcRMgEmTJtErr7zCtC12bNy7dy917dqVGjdu7EnG8QQVs6c00KZRd6bEnWzQdU+fPp3uvfdeBiwgLS8vZ0Oyo0aNYs5UQUEBLVq0iP0Pey3AHMDnjh07Mq2MFKJetxWNJ6ie3tlgLkoRsAlPeRayAdWz6NxdGKSA3ZUgHmcFKUepkSkv4gyy8F7KY3eNWEajUL1LNci2NqBaVqFGLIxKDz30EAtF8QOhqTvuuMMzbbBT586dy\/ZjmDJlitR0QwOqZ7G7u1AUcNRARQ0PHDhAzzzzDN19990MLMRNEeBHMB+\/sSlz06ZN2Q+2uuexVR7gx6w4BPyxwzhishhlvPXWW9n5CG2dcsopyWsRm83NzU1uz+Q4cOJO9K7PMho14hrVCiqge\/DBB2nQoEHUr18\/tlsNckJ99tlnNH78eFqyZAmDGZACToSm1q1bR23btmURAIwqvvPOO3TTTTcRJhhhtOvbb79lWzPhM8AfPnw4u7f1MBrV9Xvn7cQ4aVSAitjo5MmT2XA2NqhDWArBfISePv74YxaiAqzFxcVslApDsPgNaHHg\/wAd98EsOAydQyvjwLUYNMhk63trCeerjEaNoUYFaBgKxdzgLVu2MG2IDevOPfdcNhLF5wrjvOuvv55tu4R5ARgIgCZdtWoVGxgA1DgXpgSGXAE7Prdu3dqAqvpNdHO\/uGlUDirG\/zGhHd034JswYQJ9+eWXKaBCkz7xxBPUt29f2r9\/P9sjDCNZMBMw0gV7FsOyWLUBE8GA6oaogM6JUngKCyF0nYVobNSAAOW3DVLAARddq9sHKUdjo2qUzU8r6jwUxoDqQWgyl5jU6DLScj43\/qnR1cjJ3CXGEjBdf4wbN05VM6DGqTVjXBcDaowbN05VM6DGqTVjXBdloG7dupUtaejVqxcbluPLGYIMWcS4XUzVLBJQAurhw4dp\/vz5bGoYhuqwuhGhChxhg\/rYY4+xTC1hHWE\/H\/UOuwwqnq8EVKxuxGQHTITA3\/jBLBscJkYZ1iuiz3NVxFeVgYr141jpaAVVH3GZkkRZAkpARUID5EZF1\/\/555+zBAeXX355lOViyq6ZBJSAiuUJcKQAKOY1IpsfZoybw0hAlQSUgGpXmIqKCuZgwdEKC1wkFH7ttdfYQjVEI5DWJlsHlnXs3LmTLdtwytQddFnEMkCBYMY+2gMpfGCmec2IkqncdhnIsc4Kc2NLSkrY6oPOnTtnuk3K94GB+vLLL7P1N40aNaJly5YxswCzxLN5wMHD83lmwWw9G1lKkP5xxIgRLB2kU6buIMtjLQOgxURqlCnowy4DOZa+tGnThrp3784UGNIJYfGg2yMQUKFBkJ0aa3QAysKFC9nMcZmCua1AuvMAC+K7WAKMiMR5552n4rYZ74HeBGZQWVkZi364ydSd8aaSJ1jL8NFHH7GFflhHhRy2WGqSDcXBM5BDk+IlgTafN29e2pUCdlUNDNQFCxaw5QsQTFigYlHbmWeeybp+LKtApjrEeLNxiNGPdJm6gyyLWAYs0MNyaCyhfuqpp2jMmDFMNkEd1gzkUBpYxgLfRRtQUUg0DuwgqHw4WtBoQdlEdsKuqqoiaBGYH9Ac0GoAFYnDsnGIkDhl6g66HGIZIAvkQkXWPoAKaKDdgjjsMpD7lUEgGhWV\/+qrr+jVV19l3T2W3Obn5wchk7T3RONsOLHACN1+NuwzXiCrNsOL0qpVK2ajYVVoNg6xDHyIG2VALlSYYl6z9mUq+\/fff08PP\/xwSgby9u3bM2XhVQaBgZqpMuZ7IwEZCRhQZaRlzg1NAgZUCdHDk0b3tWvXLtatIcQi65zhHtjmCDPMzOFeAgZU97JiTiEARd6ljRs3Jnco5EnGeNIxOHJIgQOI4UCKn2EX4vxmzZql\/B\/n2SUwkyherE81oEo0L9KQIxZ59dVXU58+fRiIn376acquInDYMBoGoDHlEdEOJB3jnzHwsWLFimR8FU4m9pHF\/+F8ignM8D9zJCRgQJUkAZoSm5ABWIS+YAaIu4ogPllUVMQGF7DBA+KWjzzySPIzoiBIuYM0OxiIwD1wP6TNQQ5+MYEZIDeHAVWKAQwaYFgY2hRJwjDyBFMAGhCw8V1FAC26dpyPQQ\/EKxGS4Z+R6wn5nxDTBPTDhg0jaGrYrgBVTGBmQK1rIqNRJXDFeDkSimHzMEw4gTMFW1PcVQRj+7Nnz2YgIp6IZGNIsss\/FxYWMpPguuuuo6effppBjDF47GSCDcoMqPYNYkCVANWcGp4EDKjhyd48WUIC\/wXLdGMCnPuVAwAAAABJRU5ErkJggg==","height":170,"width":170}}
%---
%[output:552ba8f8]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\Fig3_1b_LearningCurve.svg\n","truncated":false}}
%---
%[output:724137e8]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\Fig3_1b_LearningCurve.svg\n","truncated":false}}
%---
