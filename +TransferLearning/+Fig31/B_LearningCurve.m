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
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（LightWater 是 Naive） %[output:054c0344] %[output:3af9f805] %[output:728e2d6d] %[output:7bcac8a0] %[output:767d119a] %[output:1bffc94e] %[output:96c64df2] %[output:8baf1f8e] %[output:45720084] %[output:4da7f097] %[output:9e893c20] %[output:39798ee1] %[output:70ab104d] %[output:85219b3b] %[output:82846c2b] %[output:592e8de3] %[output:94af9f74] %[output:31f637e4] %[output:9efdcaec]
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（LightWater 是 Transfer） %[output:345636c5] %[output:449599c1] %[output:237def92] %[output:80685059] %[output:7d5faeae] %[output:9ab90fd3] %[output:2d3047fa] %[output:4bdb87ce] %[output:5718817d] %[output:6f1064d4] %[output:4093dba4] %[output:42070c36] %[output:4707946e] %[output:810f47c6] %[output:9ebde0a7] %[output:155ee929] %[output:75946f6c] %[output:6df890f2] %[output:46c9bb6b] %[output:28a48c88] %[output:9001ed38] %[output:7283125b] %[output:4abf560c] %[output:7d1b6733] %[output:753a77d3] %[output:760c2ca3] %[output:7c00ce3d] %[output:9e406d21] %[output:76ce65fd] %[output:93b89c39] %[output:472da8be] %[output:957f3fe6]
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（LightWater 是 Naive）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（LightWater 是 Transfer）
LAI  = TransferLearning.LAInterspersed();       % 交替任务：含 Naive LightWater（需排除混入 AudioWater 的鼠） %[output:6405413e] %[output:2825f028] %[output:153b97c4] %[output:04cef15e] %[output:0f799e04] %[output:238ffd62] %[output:6f242437] %[output:496a4e3b] %[output:71b87730] %[output:3401c875] %[output:5ce77bc4] %[output:35ee3884] %[output:16fecef0] %[output:4f9ceb88] %[output:337d87b7] %[output:40b41a19] %[output:332d859e] %[output:52ba6edc] %[output:949521c2] %[output:9d15b738] %[output:59d674f8] %[output:7b4f8f36] %[output:057140c2] %[output:767e89bf] %[output:32fdf7ad] %[output:358123ff] %[output:54d7860e] %[output:09bec240] %[output:3307469e] %[output:39b39786] %[output:8537a817] %[output:7f8e5463] %[output:4eb7541b] %[output:7b5f0521] %[output:00841f9b] %[output:46b7601d] %[output:94cc0cd3] %[output:12239c8b] %[output:61277fa4] %[output:471aa8c1] %[output:416e2c6e] %[output:967dec24] %[output:2f14e8e8] %[output:93258dbb] %[output:37857905] %[output:7b40f1b4] %[output:2c14b520] %[output:93a006b7] %[output:8696b2f8] %[output:067ce8ed] %[output:1609ae07] %[output:6876315a] %[output:610eb679] %[output:28f78de4] %[output:3a984851] %[output:462d503f] %[output:838ea2b0] %[output:9393043e]

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
	warning('Fig3_1b:EmptyData', '%s', 'No LightWater sessions found.');
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
f.Position(3:4) = [3, 4.5]; % 30mm x 45mm %[output:5c266b7f]
ax = axes(f); %[output:5c266b7f]
ax.FontSize = 6; %[output:5c266b7f]
hold(ax,'on'); %[output:5c266b7f]
axes(ax); %[output:5c266b7f]

% Avoid white lines on white background
EdgeColors = TransferLearning.FigurePalette(2);

% MultiShadowedLines 要求：若 Y 为矩阵则 X/Shadow 尺寸必须与 Y 相同。
% 这里使用 cell 输入以适配不同组的有效长度（避免 NaN padding 影响绘图）。
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
Patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=EdgeColors(1:2,:)); %[output:5c266b7f]

% --- 4b) Stats: draw significance bar at X=2 (在legend之前画，避免被包含在图例中)
y1_at2 = meanMat(2, 1); % Naive at session 2
y2_at2 = meanMat(2, 2); % Transfer at session 2
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
try
    lg.Title.String = '💡💧'; %[output:5c266b7f]

catch
    % older MATLAB may not support lg.Title
end

xlabel(ax, 'Session', 'FontSize', 6); %[output:5c266b7f]
ylabel(ax, 'Performance', 'FontSize', 6); %[output:5c266b7f]
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

	svgPath = fullfile(outDirUNC, 'Fig3_1b_LearningCurve.svg');

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
SummaryCurve.Session = x(:);
SummaryCurve.NaiveMean = meanMat(:,1);
SummaryCurve.TransferMean = meanMat(:,2);
SummaryCurve.NaiveSem = semMat(:,1);
SummaryCurve.TransferSem = semMat(:,2);
SummaryCurve.NaiveN = nMat(:,1);
SummaryCurve.TransferN = nMat(:,2);
SummaryCurve.PLearningSummarize(:) = PValueLS;

assignin('base', 'Fig3_1b_LearningCurve_Raw', allSessions);
assignin('base', 'Fig3_1b_LearningCurve_Summary', SummaryCurve);

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
%[output:054c0344]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：73"}}
%---
%[output:3af9f805]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：74"}}
%---
%[output:728e2d6d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：75"}}
%---
%[output:7bcac8a0]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：76"}}
%---
%[output:767d119a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：77"}}
%---
%[output:1bffc94e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：78"}}
%---
%[output:96c64df2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：79"}}
%---
%[output:8baf1f8e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：80"}}
%---
%[output:45720084]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 5"}}
%---
%[output:4da7f097]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：67"}}
%---
%[output:9e893c20]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：68"}}
%---
%[output:39798ee1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：69"}}
%---
%[output:70ab104d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：70"}}
%---
%[output:85219b3b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：71"}}
%---
%[output:82846c2b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 10"}}
%---
%[output:592e8de3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：26：最后一回合没拍到"}}
%---
%[output:94af9f74]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 26"}}
%---
%[output:31f637e4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：65：2次中断拍摄，无法对齐回合"}}
%---
%[output:9efdcaec]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 65"}}
%---
%[output:345636c5]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：36：CD1没记到"}}
%---
%[output:449599c1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 36"}}
%---
%[output:237def92]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：37：CD1没记到"}}
%---
%[output:80685059]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 37"}}
%---
%[output:7d5faeae]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 100"}}
%---
%[output:9ab90fd3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：38：CD1没记到"}}
%---
%[output:2d3047fa]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 38"}}
%---
%[output:4bdb87ce]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：51：水滴漏了，没有拍到"}}
%---
%[output:5718817d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：51"}}
%---
%[output:6f1064d4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 4"}}
%---
%[output:4093dba4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 58"}}
%---
%[output:42070c36]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 59"}}
%---
%[output:4707946e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 60"}}
%---
%[output:810f47c6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 63"}}
%---
%[output:9ebde0a7]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 64"}}
%---
%[output:155ee929]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 5"}}
%---
%[output:75946f6c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 65"}}
%---
%[output:6df890f2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 6"}}
%---
%[output:46c9bb6b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 67"}}
%---
%[output:28a48c88]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 68"}}
%---
%[output:9001ed38]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 69"}}
%---
%[output:7283125b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 7"}}
%---
%[output:4abf560c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 70"}}
%---
%[output:7d1b6733]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 71"}}
%---
%[output:753a77d3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 72"}}
%---
%[output:760c2ca3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 73"}}
%---
%[output:7c00ce3d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：9：中断两次，行为和钙对不上"}}
%---
%[output:9e406d21]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 9"}}
%---
%[output:76ce65fd]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：111：2\/5层亮度反相"}}
%---
%[output:93b89c39]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：85：中断两次，行为和钙对不上"}}
%---
%[output:472da8be]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：14：拍错Z层，舍弃信号"}}
%---
%[output:957f3fe6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 14"}}
%---
%[output:6405413e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：3"}}
%---
%[output:2825f028]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：4"}}
%---
%[output:153b97c4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：5"}}
%---
%[output:04cef15e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：6"}}
%---
%[output:0f799e04]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：7"}}
%---
%[output:238ffd62]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：8"}}
%---
%[output:6f242437]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：9"}}
%---
%[output:496a4e3b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：10"}}
%---
%[output:71b87730]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：11"}}
%---
%[output:3401c875]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：12"}}
%---
%[output:5ce77bc4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：13"}}
%---
%[output:35ee3884]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：16"}}
%---
%[output:16fecef0]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 19"}}
%---
%[output:4f9ceb88]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：22"}}
%---
%[output:337d87b7]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：23"}}
%---
%[output:40b41a19]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：134"}}
%---
%[output:332d859e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：24"}}
%---
%[output:52ba6edc]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：25"}}
%---
%[output:949521c2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：135"}}
%---
%[output:9d15b738]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：26"}}
%---
%[output:59d674f8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：27"}}
%---
%[output:7b4f8f36]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：28"}}
%---
%[output:057140c2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：136"}}
%---
%[output:767e89bf]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：31"}}
%---
%[output:32fdf7ad]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：32"}}
%---
%[output:358123ff]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：108"}}
%---
%[output:54d7860e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：137"}}
%---
%[output:09bec240]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：33"}}
%---
%[output:3307469e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：34"}}
%---
%[output:39b39786]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：109"}}
%---
%[output:8537a817]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：138"}}
%---
%[output:7f8e5463]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：110"}}
%---
%[output:4eb7541b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：139"}}
%---
%[output:7b5f0521]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：140"}}
%---
%[output:00841f9b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：111"}}
%---
%[output:46b7601d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：141"}}
%---
%[output:94cc0cd3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：142"}}
%---
%[output:12239c8b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：112"}}
%---
%[output:61277fa4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：39"}}
%---
%[output:471aa8c1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：40"}}
%---
%[output:416e2c6e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：43"}}
%---
%[output:967dec24]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：44"}}
%---
%[output:2f14e8e8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：45"}}
%---
%[output:93258dbb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：46"}}
%---
%[output:37857905]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：128"}}
%---
%[output:7b40f1b4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：129"}}
%---
%[output:2c14b520]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：130"}}
%---
%[output:93a006b7]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：131"}}
%---
%[output:8696b2f8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：132"}}
%---
%[output:067ce8ed]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：124"}}
%---
%[output:1609ae07]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：125"}}
%---
%[output:6876315a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：126"}}
%---
%[output:610eb679]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：118"}}
%---
%[output:28f78de4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：119"}}
%---
%[output:3a984851]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：120"}}
%---
%[output:462d503f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：121"}}
%---
%[output:838ea2b0]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：122"}}
%---
%[output:9393043e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 66"}}
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
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHgAAACqCAYAAABmkov2AAAAAXNSR0IArs4c6QAAFDVJREFUeF7tnWmMFcUWx88sgvAcfGwKo4MgsgaibIK4AIIaQAwQ2VEQWeKToD4eW\/wA5MUEREw0fgFUIiKDolFAVAQFFEEIiKJgGIdVFgkOGDAICnPf+9f1zFT37e7b1bd7um9TlRAGprqr+vzqnKo6VacqJ5FIJEin2EogRwOOLVvxYRpwvPlqwDHnqwFrwHGXQMy\/T\/fBGnDMJRDzz9MarAHHXAIx\/zzfNbikpISOHDlCvXr1irnosuPzfAW8efNmWrJkCfXu3ZsGDBiQHRKIeS19BXzmzBk6deoUlZaWUp8+fapcdJs2JYvcuJFo5swqLz6SBfoKGF\/4008\/iT8y4OHDh1Pnzp3pqaee8lUIJ04QLVxINGtW8rXdu1f+jZ+7dfO1OOuXoRJI584l\/3AqKHAunPO2aEF0zTWBVbRKAN9888104MAB3z4CMgVUwEXCz1WqsQz1+PFkBbgiO3emfmOHDqn\/J+fr1y\/QymcVYMgVMoU88WfyZKIXXvCt3Ti\/yAoqKgGADDEdTC5Bzjd8eHZpsJWUMtXg339PgoVVk7W2YcOA4XKLkouB9rEGynALC71VBqY8m0x0EIBLSirhQrbLlhE1b+5Nnq6eklsUP8Bg0cLGj0\/+AdTAW5mrGttm8t1E+w1YNsuQ8YIFlRYxs0+3eRpw9+2r7FsZLGsrwCIFPDjy69siDZhlDaVhuIHKVTbJEyZU9q9ynwmTGqj58Att8j2RBsymuWNHoh07AraIZs2FdFhbWeZZYJLNzSOygM2mOfB+19zRoy\/ggVPAAyF\/ddb4tkgClpUJlhKKFPBsItkH4A8KhLnIMlNs10giCZiVCfJG\/+tJe2EC2JuUbhqCFoVCAJdHcVZz2iBVLaB3Rw6wb9pr9io5aSRaFEwEoGbJ9Mdte4gcYLP2epoWya1EloTVIInzYiSHwuDEzqJRcjrQkQJsNUuBO1JZ3txKrL7ePM9CXiw\/oS8A4EDnYelw+P\/7yAA2Kx1PjZTlbae9suzk\/pUHVvj96tWR90ypNoHIAJaVLiPHhhvAbKrZZPBQ3TzvVZVmBPNHArCZCcvbU3cotxRop91oGJCxegHzjALhnlTuCyJI1FSlSAD2XXtls4sPZsjoY82J52IAnW46FX2eKTWMFGDZz4CaKve\/VkNwvEhe4jOb4SrzpITTOiIBmKesLGsonCdHktWLZLnyVEg22zyai4ljI5K+aHmpla2oMmDuyNnkWplj3i3AWpyRqywcjVQtNXQNNvsZWJF8M89miUBjecGeTQb2RUV84V4VLOePBGA4M5BYsZS1l\/tZ\/C3beSup8IYuLCiwyQ58JcMrnsyfCx0w9jLDzy+PfZSXXeV5FvepTrLhiTbyePKFZi74qnqDMuA\/\/viDVqxYQfv27aOxY8dSkyZNKuq6a9cuKi4upjZt2tCgQYOoRo0a4ndOm+4+\/DC57dVz34sCrEbPbOMBHwlzXt7min+jIaA\/8LRUVVV4Mi9HGfCnn35KdevWpWbNmtFbb71Fo0ePFiDPnj1Lr732Go0fP562bt1K1157LXXq1Ckt4OJiovnzKwEr971Wy0\/ybkdZRrKzm50gnvqDzAVfVW9QBrxw4UIRe1RUVERvvPEG9evXj+rUqUOXLl2iZcuWUa1atejnn3+mgQMH0g033JAW8H\/+k1Quz6t0speEzbMdNKttsMotqqrQ+FOOMuDXX39dQK1fv74BMOKSEHj20EMP0ZYtW6hp06bUpUuXCsAIW7EKXenRg2jYsAxW6XjuK0+PnKCZ14k1YGNL+uCDD6h169bUuHFjAXjIkCFCaxGP9M0334h\/4+ft27fTiBEj0mowz1o8DWTtzLMTNFmLY26eIXxlDT527BjBTNeuXVv0w127dqW3336bHnnkEWGi8\/Pz6ejRowJ087+d906DLADGIOvBBz2YJNk8y9OjdF4p1mIN2IPQLR6xAwwFhIzRByv7+WXtlc2zG2isxTE3z5402AvyQADbaa9baGgUbvN6+eiIPKNsor3U2w4wz4HhVFJO8mBJdm64hQYtjql7UpZlqIB5DqwMOBPzrNySsvuB0AHDa7hhg6IQ7cyzm\/5Xsahszx4qYDg5kJSCuO20Fy9ya56znZpC\/UMFjK4TK0lwdLhOdtqLF6SbHrkuJD4ZQwesPAe2G1xp82zZKkMDDEuLXZNYaHB9Go6TeVZeY4yPljp9SaiAlZ0cTuZZ97\/R02AGPH\/+bJqZ7hwkJ+3V5tlWiUPTYHZyzJ+\/ibp3705pL38xb56W13y19kYPMDs5PAE2b3\/Vo+foAeY5cL9+LjRYm2fPI0KDif76668J50pOmDBBrPciYdkv02Tli1YCrAdXnhFUAD59+jQtWrSIRo4cSevXr6fBgwfTyy+\/TOPGjRNbcjJJVoDZyVFY6EKD9dzXs\/htAWNbzuzZydGt34B5DgwnR0FBGsDaNekZLh60NNH8RuzQ4H1VmZRi1mB5oX\/nzjSAtWsyE9EbAWPrDRI2zk2fPp2GDRsWLmCz9vIRR6iknvu6Ap9ioidNmiT2OWODe1B9MM+BEZLrqMHmYG4+RwOfpue+aoDNQDHoCqoPlhf6N21yMNF63dcVRNe+aJ4mBd0HuwKs574Zw00ZZLl5o1Ns0sGDB8WW2kaNGolttNf8vVXSPMiSF\/ptNdisvagcBzBp8+wGlchjGEXPnTuXFkiB07feequIN5KnSXaxSefOnRMb4RGrBNAIZWnXrp0oxAwY0QwIVcFCvwzY0E0cPFj5ERmH\/ruWR+wy2g6y7L7ULjYJ0QwbN24k9N0Ia8EIXI4ulENXrAAjYA2NC\/FM586cocJq1WjayJHJ8zXkwZUePSs1wgrAbkfNdrFJAIx589SpU+n777+nkydPihgmOw3GVh1EM8gajHc89thj9MKMGdSlQYPkh5gDurV59gYYmvf444\/Td999V\/ECKxNtF5uEiMLVq1fTE088IWKTED9sBzgnpzKagQGXlZXR5MmT6emnn6YVr75Ko3r2pGZFRZVR+E43myh98pWVWXk92Ck26f3336dff\/1V3H4mB4eb+2ArwIb1YLvjkLR5Vm6dyoMs5RJMgywc2QDzzOeOWY6i7Y5D0uZZWfyWiw1Lly4Vq0r4mz1bym+WHjBrMJ+7jSwpgJ3O29AL+8oYUgBjeZCXDQE4iOVCWGA+FtIWsB49K8O0esBgonmxARlnzJghFv6nTZuWcUFmDZbjvlIAm0+A9XxwVsbVjsULqrwPhtQcAfMB3fLKER7S5tlTg1N2dHgpxWo9mAO+UzTYfAI7CtSjZy9iF88oOzq8lKQMGAd2wJepzbMXcRueCcVEyzVI0WAMrsyn1Wnz7Bl0KCbaFjDfX6R9z56Bmh80aLB8sJlvJaQ5ytCgwVaAtXMjIxQGDXbji\/ZSmtMxSgbAfHc7CuHTSbV59iLyimeiZaL5BjIeYOnRc0ZwQxtF2\/bBZsDaPPsH2O1yoZcSXZtoeQSttdeLqFOeUV4u9FKqa8AYPcfselcv8vLzmVAiGyxNNM4zxOHcMb1D0E9oKu8yDLLkfdBB7os2A541axZtwL2BDDjmp7CrAMo0b+iAKz4AUyTs4cK0CFFpV8Axg5nCc\/N86Ca6opLyCNrT4dFuPvfKy5NTVlaWkBf4\/djBYRaj0yDLABjTIuzL1oB9a4lCg80b3vntVrsqvZTsCrA8RdLeKy9itnxG2ZPlFLqCErCjEltrH330UapevbooNC1g2QetB1i+wTV4svgIh3Qm2i50BS9DuAqu2sHW2meeecbVvUniazRgX6HKL1Ne8LcLXcFLEZ14\/vx5Onz4MA0dOtQ9YHmRQY+gfYWtvJpkF7ryyy+\/iC2wffv2FTejmQHbXasjvkaPoH2FaqnBrIHpjlGyC105cOAArVy5kv766y\/as2ePCGGR703C722TBhw8YLfHKNmFriBoDIMqDMKWL1+uZqL1CLrqAQd5jJLha\/QAKzC4hlG0bKK5xKCOUdKAA2VqeHnoy4VigIVTwZH0CNp38gIwQlYQqoLkV7iKXFNHR4ceYPkO1TCKZl80HBxIfp2N5RowBlgcxa990L7DrlhsYA9WEFtnbTWYQ0V5o7v2QQcD2LxdlksJfLEBHiws9EOD9+2rjCn1\/TOv3BeGO8iSA830IkMgrTBwwPCMwUetk7oE4AnEVDWTFDjgtEuFmdQ+5s\/6ITsNOMKNRAOOMBw\/qqYBu5JigsqPzSW6uJVyatamxNWDKPeffW2fHLr3EjWunktzmua6enuQmTRgN9I9v5cuH\/oX5dZrTjn\/qEOXj+2hvOYriSgV4NrTCZpUWi7euqptHrWo4aaA4PJowC5kmzi3jcoPTSFK5FHO5QQlquVRXuu1RDn5hqeBtc\/uS3TwQo74\/661iBa3zHNRQnBZNGA3sk1cpEul4yj37H6icqJE0RDKa5B0y8ppZVk5Td2fMPzfslZ51KHATSHB5NGA3cr10ikq3zWQ6OqGlNv2Hcun\/nu4nJaeNAKeVpRLYxomNTqMpAG7lHp5eTltWbeAahY0pPZd+1s+taasnP5t0uDlrfKondZgZyn70QpdcnTMtmbNGqpXrx517tzZMh90d96Ry7TkJFF+DtHEwlwaWxie9qKSfshOOzr8aD0BvUMDDkiwUXlt1gCOisCysR6O241dfJCyibaLTcKJ7V999RWtWrWKWrRoIa6lxbU6frRCF98Ryyx+yE4ZsF1sEiIbENGADe+49+H48ePizgY\/KhlLei4+yg\/ZKQN2ik3iOmPECu3t1q2bETDu08FZ\/lFN3bsTbdgQmdqFAtguNglSgZn+7LPPxK0rOCk+Pz\/fCBi3cezYERkBplQEe8MSRmdHmJUNBbBdbBLg4tYVpP79+1NubtKZb6hklgHGduILFy6IWOfS0lLRcPv06WNgjlvekKdVq1a+t4VQANvFJvXs2ZOef\/55atmypYB71113UadOnbIaMO6B2rVrFw0cOFDEXQFwjx49xECypKRE3LN8\/fXXE671w0Vgd955J\/3www903XXX0f79+8VNcIi2xOZFLykUwKoVzWYN\/uijj6iwsJBw7R72R504cYLuuOMOunjxIsH9uW3bNmrTpo2IiYYmIw+6qPbt29Pu3bsJjR6NBINNeNFUkwasKrF0+U19MAA3a9ZMwMTJBbBIjRs3ps8\/\/1y4PAGcAeN0A2g4tLeoqEhoL8w2wmk7dOhAtWrVSld6yu81YGWRpXnABvAtt9xC77yTXIVq3bq10GjMEqC1GG8AbtOmTenFF18Ug8uCggJavHgx3XjjjeK0A4QD8UWdKlXOPsB6mqTC1xcfgvI8WKmGPq2IqJYZl\/xZp8FagdWaXtYBzrJpsBqNAHJrwD4L1ezIevfdd8V0B+eXYHCF+XADvrhaoewz\/7\/RHC7ewYMHU5MmTVw\/qQG7FpW7jFaeSkx92IOFBZUvv\/yScnJyxLRnx44dYu57++230xdffCGcHLfddpvwwb\/33nt09OhRGjRokHB6bN68mUaPHk0\/\/vgj7d27VzQWjKzxPrh0BwwYkP3TpGw00TJg\/vmee+6h3377TUDG6hqcH+vXr6cRI0YIxwa8edu3b6f77ruP\/vzzT5Hv22+\/FdMnaHPbtm3p448\/FvNq3Jxudn8yaa3B7hTTda50GgzA8FrBK1VcXEx33303HTp0SLhlcaX9vffeS3COwGUJs75u3TqqWbOmAMiAocEAB999nTp1xBzazpWpAbtG5y6jW8B169YVB66iP4VX68knnxSgGTC8WwCNfHCIwOsFwPj\/N998kxo1aiT812gIWKiIDeCoT5NwgkSUVjOzToPd6ZHOlbV9sEanJoGs0GB9hIMaVDl3VhzhgAr70RK9i+nKfjLwxQYNONwGpgGHK\/\/AS9eAAxdxuAVowOHKP\/DSfQUMJzq2mmIv0sMPPyyc6LoPDpyhYwG+AT579qzYmDZmzBixQgIXnes7G8KVgSj9pZdeIlwcEvWkWk\/fAMMRv2XLFho1apRYXpM3ieu5sH\/NRnVu7CtgrJRgM7gZsH+fp9+kKgHfAONKO+z4h4nGygn+ff\/996vWR+f3WQK+Acb6JgZYAIulMOwPrl+\/vs\/V1a9TlYBvgK0Kxu4FDLwwAIsqcMQYHTlyhHr16iXufEKMMxbvx44dq7R\/SlXwbvNbBdbn5eW5rmeggJcuXSp2O1x11VX0ySefCPON\/UxRSdgntWTJEurdu7fYE+V08WZYdbYKrEcgHDYTIKwGCoS9XnaRE4EBhjZgJyFuRANg821oYQlMLhcWBl0KQkOxrcZNcHuY9ebAelgYNErEQKW7YyNQwNi3hLM6EE4aRcCAJY\/4nYLbwwRrDqyH1UHEIsY4oQFGpSAwTJtgUjAAwxy5WrVqYcoqpWwZsF1we5gVtgqsV6lnYBoMoWCfMPYHo3\/AXmG7U+bCFKAM2BzcjuDtsBM28z333HOGwHrELKM7qV27tuiHneoZKOCwhaPLJ9KAY94KYgcYV\/jA942U6cVeeBcCuDFQzNYUK8CIJpg9ezbNnDlTRA3EAVCmDStWgDH3xoAEo3UMPuQ0d+5cWrBggThUBccrIGGOjhP5+MZVc56ysjKhwYgx4uv\/OK98YyumLHPmzPF0TEOmANM9HyvA+FhAnj59uggCYxMNUGvXrqWJEyeKmKFFixYJ0GgEvGbN\/8+XdOJdbAEwksUsAHnRCPAzwCPBfL\/yyiv0wAMPpDSqdMKvit\/HDrAsNEyB4AiABkJbOQH8vHnzaMqUKeJcTdZArIbxPcp8pRzeAS2HL102+3jXTTfdJKBrwFXRVP\/2SgHos88+K8wlayXckJs2bRIabJXMgAAVGt+xY0ehqXYarAFXEVi5GLlv5P4Wppj7V+SFxgIeBmNI6FehodzP8nPp+mANOATAukijBGLdB2vYRP8DiQTR5Lzv\/gUAAAAASUVORK5CYII=","height":170,"width":120}}
%---
%[output:552ba8f8]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\Fig3_1b_LearningCurve.svg\n","truncated":false}}
%---
%[output:724137e8]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\Fig3_1b_LearningCurve.svg\n","truncated":false}}
%---
