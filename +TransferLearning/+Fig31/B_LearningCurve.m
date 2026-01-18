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

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2)); %[output:634dd7c2]
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2)); %[output:99dbb8ec]

tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2)); %[output:7fd89108]
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
try %[output:group:5609978e]
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary); %[output:3ee32ee3]
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end %[output:group:5609978e]

[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);
%%

% --- 4) Plot
f = figure('Color','w', 'Name', 'Fig3.1b Learning curve (LightWater)'); %[output:17c93ed5]
MATLAB.Graphics.FigureAspectRatio(8,5,1/2); %[output:17c93ed5]
ax = axes(f); %[output:17c93ed5]
hold(ax,'on'); %[output:17c93ed5]
axes(ax); %[output:17c93ed5]

% Avoid white lines on white background
EdgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);

% MultiShadowedLines 要求：若 Y 为矩阵则 X/Shadow 尺寸必须与 Y 相同。
% 这里使用 cell 输入以适配不同组的有效长度（避免 NaN padding 影响绘图）。
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
Patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=EdgeColors(1:2,:)); %[output:17c93ed5]

nNaive = numel(unique(string(naive.Mouse)));
nTran  = numel(unique(string(tran.Mouse)));
labels = {sprintf('Naive (n=%d)', nNaive), sprintf('Transfer (n=%d)', nTran)};
if numel(Patches) >= 2
	legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2))); %[output:17c93ed5]
else
	legend(ax, labels, 'Location', 'best');
end

xlabel(ax, 'Session'); %[output:17c93ed5]
ylabel(ax, 'Performance (LightWater)'); %[output:17c93ed5]
ylim(ax, [0 1]); %[output:17c93ed5]
box(ax, 'off'); %[output:17c93ed5]
title(ax, 'Naive vs Transfer'); %[output:17c93ed5]

% --- 4b) Stats
% LearningSummarize 通常内部使用 LME 并返回一个 p 值（Fig1 用法）。
% 若其返回 NaN，则回退到更稳健的 LME（仅随机截距），尽量避免 NaN。
pText = "";
if isfinite(PValueLS)
	pText = sprintf('p=%.2g', PValueLS);
else
	stats = iFitMixedEffectPValue(allSessions);
	if isstruct(stats) && isfield(stats,'PGroup') && isfinite(stats.PGroup)
		pText = sprintf('p=%.2g', stats.PGroup);
	end
end
if strlength(pText) > 0
	text(ax, 0.02, 0.02, pText, 'Units','normalized', ... %[output:17c93ed5]
		'HorizontalAlignment','left', 'VerticalAlignment','bottom'); %[output:17c93ed5]
end

% --- 5) Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

	svgPath = fullfile(outDirUNC, 'Fig3_1b_LearningCurve.svg');

try %[output:group:5b8c50e8]
	% Hide axes toolbar in SVG if present
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off'; %[output:17c93ed5]
	end
	exportgraphics(f, svgPath, 'ContentType','vector'); %[output:17c93ed5]
	fprintf('Wrote: %s\n', svgPath); %[output:8221b056]
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end %[output:group:5b8c50e8]

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
%[output:634dd7c2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID           MustWarn        \n    ________    _______________________\n\n       26       \"最后一回合没拍到\"        \n       65       \"2次中断拍摄，无法对齐回合\"\n"}}
%---
%[output:99dbb8ec]
%   data: {"dataType":"text","outputData":{"text":"Fig3.1b: LAInterspersed excluded 4 mice with AudioWater mixed into Naive phase.\n  Excluded mice: vtf0045, vtf0101, yqn0051, yqn0052\n","truncated":false}}
%---
%[output:7fd89108]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID        MustWarn     \n    ________    _________________\n\n       14       \"拍错Z层，舍弃信号\" \n       51       \"水滴漏了，没有拍到\"\n      111       \"2\/5层亮度反相\"   \n"}}
%---
%[output:3ee32ee3]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAjAAAADWCAIAAABAES+OAAAAB3RJTUUH6gEOBwMvIwe02AAAIABJREFUeJzt3X1UFNf9P\/CL4MMIqIwgkWhcWU60ZYknJRNNUwk1rRJJQ7ohPRhjI\/bEhNqns7QlFmptC0Vy4vY0LV2DLZj42Eq27jF2xUaD0Kp0mljLYNQ4ySpxjUoGwoMT1xV+f3xO5rffXSCL7uKg79df7HBn9s7d2fnce2f2MxE9PT0MAADgZht1sysAAADAGAISAADoBAIS3I4+\/fTTgwcPbt682ev1DlKst7f31KlTp0+f9l349ttvHzx4sKOjo99VLl++3NbW1tvbSy\/7+vra2to+\/fTTwJLd3d2vvfbarl27PB5P4H8\/\/vjjrq6uYPcH4JaAgAS3o87Ozj\/+8Y82m62lpWWQYrIsWyyWH\/\/4x2fPnqUlXV1dr7766g9\/+MN33nmnr68vcJX6+vrMzMwXXnhBVdXe3t7q6urMzMw9e\/YEFvZ4PE6n8\/Dhw9euXaMlXq\/37Nmzr7\/++jPPPPPQQw99\/\/vfP3\/+fCh2F2BkiLrZFQC4CRISEh577LHKysoPPvhgzpw5gQXefvvtw4cP9\/X1xcbGNjc3v\/jii7Nnz2aMnT9\/\/sCBAwaD4dixY8ePH3\/ggQfS09O1tTo6Ov72t79FRUVlZ2dzHMcY+\/rXv7579+6ampp77703OTl5kCodPXr0O9\/5Do2WoqKi7r\/\/\/scff5w2AnCbQECCW58sywUFBW63O\/BfJSUlJSUl2sukpCSbzWY0Gs+cObNhwwZteX19fX19vfbS5XL9+c9\/pvJaQOrr69uzZ8\/hw4cXLFjwpS99iRZOnz592bJlv\/jFLzZu3FhSUhIdHc0Y83q93d3dnZ2d165d83g8HR0dV65c8Xg8Ho\/nW9\/6ltlsNhqNCEVwG0JAgltfVFSUwWCYPHkyY+zKlSvvv\/\/+qFGjkpOTR48e7VcyNjY2KiqKMfbII49kZmZqy995550f\/ehHTz755KpVq0aN+v8T3b5h48iRI5WVlRMmTPjOd74TGxtLCyMiIrKyso4cObJ79+4777zz+eefj4qKOnPmjBYgjx8\/\/o9\/\/CMtLW358uWMMZPJZDKZwtMMAHqHgAS3vhkzZlRVVdHfNFqaPHlyZWUlz\/MDrcJxnM1mq66u9l24c+fOnTt3ai9XrFhhsVjo75MnT5aVlXV2dq5evfqee+7xXSs6OnrlypXvvvvun\/70p8jIyGeffTY2NvbJJ590uVwOhyMlJSUzM5Pn+bFjxzLGVFVVFMWvJhgtwW0CAQluL729vb29vTExMYGn\/qioqNjY2IiICHp5zz33PP\/884yxjo6O3bt3jx8\/Pjs7e9y4cVp5uqrEGGtpabFYLOfOnYuKinr99dffeOONwPft6uryer2bN2++\/\/7709PTn3322c2bNzscjtjY2KeeemrKlCmiKDLGysvLy8vLfVf81a9+ZTabQ9oGADqFgAS3l46Ojo8++uijjz5atGiR37+WL19eWFjIGLt48aLD4bhy5QotV1W1p6dn6tSpNJunOXHixAcffJCTk\/PFL35x1apV+\/fvv3z58uHDh\/t93zvuuGPp0qUZGRl0eam7u\/vf\/\/43Y+zo0aO\/\/e1vtetYmZmZs2fPPnHiBN2tN3v27BkzZoS0AQD0CwEJbi90IzWd630XOhyOUaNG0fCoq6tr586dfjdBnD592u8HSYyxpKSkBQsWTJky5Rvf+MbixYsvX77s9XrpgtPSpUufe+45xlh3d\/fPf\/7z9vb2ZcuWTZs2jVZ87733KCCNGzfO6XTed9998fHxjLFnnnlGEAS73V5fX79gwQKMjeC2goAEtxGv1ytJEmPsySeffOihh7TlBw8edDgcCQkJ9HLGjBl\/\/etfaXLvlVde2b59+1NPPbVy5Urf2xnIqFGjYmJiGGMRERFRUVETJkxgn8W81NRU7RqVx+OJjo4eP3689tJut6empl68eDElJSU2NnbUqFEff\/xxeHceQPcQkOA24na7Dx06lJycbDQafZdTMKB7shljUVFRkyZN6uvr27VrF93FsG3btm3btvltLS0trbKy0m8er6Ojo76+PiEhYdasWQNV4\/Dhw7t377ZYLE6nc+zYsQUFBXFxcZs3b77jjjsmTZoUkj0FGImQqQFuF16v1263u1yu+fPn33HHHb7\/crlcjLHp06drSzwez\/bt23\/5y1+OHz\/+kUceSUtLS0tLu\/POOxljd955p\/bSb8zU19e3f\/\/+pqamr3zlKzNnzqSFnZ2dHR0d8fHxY8aMoSVjxox58MEHMzIy6GVcXFxkZOS5c+cmTpxIYyyA2xNGSHBb6O3tdTgcmzZtMhgMTzzxhO+wpru7+4MPPvAdnbjd7nXr1h04cGDChAmlpaVf\/epX6dqS3W5fs2bNc8891++lHZqIe\/HFFxMSEpYsWaKFn87OTkVRYmJitJ89paenGwwGus+btLe3S5KUkpKCgAS3MwQkuPVdvnx5w4YNr7322vjx47\/3ve8lJydfu3btn\/\/8Z3NzM2Ps4sWLjY2NgiAkJiZS+dGjR3d2dqakpEyZMmXjxo0bN26k5XSb+CuvvKL9Gik2Nra4uHjq1KmHDh165ZVXmpubJ0yY8POf\/\/wLX\/jC+fPnd+\/e7fF43nnnnZ6enpkzZ2oRaMyYMVOnTvW96fztt98+efJkbm4ufnIEtzMEJLj1eb3eS5cuTZw48YUXXqC7vSMjI6dMmbJz5066ejR58uQVK1Zoo5OEhASr1Tpu3LgNGzb4\/TaWMXbu3Llz587R30lJSV6vd\/To0e3t7e+++256evpPf\/rT1NRUxtikSZNkWd6zZw9jLCUlZcGCBQNV79NPPz1+\/HhycvKDDz4Yhr0HGDEi8MRYuB20tbVdvXp16tSp2hJKKEfPibjxbAgej6e1tXXmzJm+V5W6u7s9Hg\/died37wOt0tzcPHbs2NmzZ0dGRn7yyScTJ06kucEPP\/zw7Nmzd911l3abOMDtAAEJAAB0AXfZAQCALiAgAQCALiAgAQCALiAgAQCALiAgAQCALiAgAQCALiAgAQCALgQbkGRZXrhwoclkKioq2rp1a1jrpCuKoixZssRkMhUUFFRVVamqeiNbs9vtJpPJZDJZrVZ6QujwUFW1qKjIarUOUkYURarbkiVL\/B6leiPoyLHb7b7vor0M7bvo7fjUaqUZhg\/darVqbzf4J+6LqhpM9Xy3Tw1+g18KAE1QqYNUVXU4HDt27OB5nvIlh7lWOlJbW1taWmo0GkVRrK2tvZFNybLc1tYmSZKqqmvXrg1RBYPCcVxRUZHT6RykzKlTpxoaGrRH+ISK0Wh8\/vnnd+7cmZmZyXFcY2PjD37wg9A+d063x6fRaCwrK2OMCYLAGAt5GO5XQUHBlClTnnjiCY7j7Ha7KIr07oPTqupLUZTi4uIf\/\/jHvk\/r8N2+oiibNm0Kbf3hdjbkKTuz2WyxWNhnnW6t30cjCbvdTsupl639XVdX59v11jpZW7ZsqaurY\/936BDynQwJQRAqKircbjd1JGl\/i4qK3G73kiVLnnvuOZPJVFdXRwsH7zNyHFdRUUGnCW1cUlVVRQ0Y2mpr2x8kmtK+lJeXZ2RkhGP4whjLzs4WRVGSpNTUVHrskFYxrbn8jijGmN1up\/Y0mUwLFy6UZflz30g7PsPdsEMiiqIoimazOZjYEEJz5sxRFEU7Vrds2aI1uDZ68x0Qnzx5khbS15Dn+bKyspKSksDGV1V1y5YtHMdZLBYkhIVQCSogcRyXk5OTl5fne\/qw2Wy5ubmSJImiuHfv3vb29tLS0ujoaDrbPvroo8znzHvgwAFRFLdv387zvCiKBoOBVmxubu7p6RFF0eVySZIkSZLBYBjOuazPlZubW1JSon1vtY4kz\/PV1dVpaWlxcXGlpaXTpk1raGj497\/\/XVpaumDBAr+nXxOj0RgfH09nSTo\/yrK8d+9eOlN3d3cLghDaoYPf9i9cuNBvMZ7nt2\/fvnr16oaGBkmSwvHY7FmzZl2+fPno0aNpaWl+FcvNzdWGbsuWLZMkqaGh4dSpU4wxOoPPnTtXkiSbzRb4BHESeHyGu2GHJD8\/Pz8\/\/6a8taIoPM\/TscoYu3jxoiRJFRUVqqpWVVXt2LFDkqTS0tLKykr6Uu\/Zs4cWGgwGOkTp2NixY4dvWGpubs7IyKBc6QAhFOwIyWg07tu3j04fNpuNulQmk4kxxnFcVlbWIFcdEhMTi4qKtG6Uoihz5sxhn4Urs9nc2tpaXV1NZ+o1a9Y0Njbe6G6FDn0h\/b63ge6\/\/36O42bOnJmUlDTI1sxmM8Vdl8tFw6ysrCxqmeXLl2uPPwiVcG9\/SKZNm3bvvfeOGzeOKvaXv\/xFEASTyZSfn9\/U1KSqqqqqZWVlJpMpIyNDi52JiYmZmZmfu\/HA41M\/O15TU1NTUzOc79jc3ExtW1tbS19SxlhaWlpBQQH9Lcvy3LlzaXrWaDQmJyfTgW2xWGhhZmamdqjTxF1paem+ffto7i4tLa2hoYH6FgAhFFRAkmW5qqqK\/uZ5PjU1lef5xMRE30PW99qDLMv\/\/Oc\/B9oaz\/PHjh3zXTJnzpz169dLn6EpFz1QFMVqtdJuxsXFJScn+85OSJI0pE4iTejT39SGPM\/v3buXtl9fXz\/QCOa6hXv7QyIIgjZhZTQaV69erX3iFRUVHMeJolhaWkojpCGFkH6PT\/3sOPu\/+z4M0tLSaHRIDRtYwGg0al9eVVX7+vqoWG1trdZoHMfRtF5eXp7fZSTGGMdxTz\/9NCbrILSCHSFRV8tkMpWUlNBXa968eTRJYjKZWlpajEZjUlLSgQMHqMyECRPoiovvxQk6HQuC4HK5tLt07Ha70WhsaWnxXRLGPR4iuiZsMpny8vLmzZvHGDMajXQNrLq6urOz02q1lpSUFBYW0gykzWbr6ekZ6H68\/Px83xYzGo1ZWVm0\/aamJu0sTCeCG7+c5rd9URS1qULf7ftdQ9KiJl3Yu8EZVFmWN2zYkJ+fTyPCVatWlZeX0\/nO72awlJSUgoICGiGVl5dT\/C4vL6+oqFAUpaqqihq533fxOz4Haljtasrw3Bgmy3JxcTF96MM2Ee10OtetWycIgvb5yrKck5NDC2najed5rf0FQZg1a5bb7S4uLk5MTKRGc7lcZrOZxp3awIjYbDbaFO6vg5DD4yf0QlEUp9O5dOnSm12RWw0aFmCkwBNjdUEURbruzXHcTbz8futBwwKMIBghAQCALiB1EAAA6AICEgAA6AICEgAA6AICEgAA6AICEgAA6AICEgAA6ELEY489puW\/yc7OXrt2rdPpXLNmjVaipqaG5\/mCggItYeiKFSssFovVaqWMjYyxpKQkm8127NgxvxWNRuOqVauGefs2m81vRcYYtj+k7S9fvjyYDw7bH3z7QR7YI337flmFAK4bfocEAAC6gCk7AADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQhWADkiiKJpPJZDL9+te\/3rJli6qqYa2WnqmqWlRUZDKZlixZoijK4IVlWV6yZIksy9oSRVGWLFkiiqLvS5PJVFRU5NuqgSuGlSzLCxcutFqtYdq+dvzY7fbBS\/q1D7Hb7b7tY7VaTSbTwoUL\/drHarVqu6C9YzAf03Wgevp9ana7nd7Ur\/6B+v18fet\/I6gaYdpxgPAJKiDJsrx3715RFCVJSk1N1TKO3J6cTmdubq4kSaWlpbW1tYOUVFXV4XBkZ2f7LqytrfVdIopiaWmpJEm5ublOp3OQFcPqyJEjGzZsSExMDMfGFUVpbGyk46etrW3wKOvXPowxWZZdLldaWpr2MjU1VZKkHTt2OBwOLR6IohgTE+O7CzU1NZIkbd++nef5UO8TE0WxuLhYqxVjTFEUVVUlSRJFsbGxcZBg0O\/nG1j\/6yPLcltbWzDHJ4DeBBWQjh07lpWVxXEcY8xsNldUVHAcR72wuro66uBTl5C6rlpH2G63UzeNuqt2u5164lu2bFm4cKHJZApflzx8zGazIAiMsbi4uOjo6EFKOp3O+fPnJyQkaEtEUYyPj581a1ZgYZPJpG0tcMVwW7p06aRJk8K0cZ7nLRYLHT8zZswYpGRg+9C5Oy8vr9\/N3nfffRSQKOY9+uijoa77gBYtWjRQDjeO4xYuXNje3j7QuoGfbwjrr6rqww8\/zBgzGo3R0dEYJMEIElRAio6ODuxjms3mmpqa9evXUwdfEAS73W4wGCRJkiTJ5XKJomg2m+k7JgiCw+GIjo42Go1lZWV79uzZsWOHJEkGg+Fz53D0SVXVysrKefPmDVSAOqoUugiddB555BHfYoIglJSUmEwmQRAOHDigqmrgircMURRbWloGOo\/32z507o6Li9OWGI3GlpYW6veUlpbSeb+2tjYnJ2fcuHG+6+bn5\/c7sxcmPM9zHEcVy8vLGygS9Pv59lv\/63Pq1CkEIRihooIvqqrq2rVr9+zZwxirqamhb1RZWRmdX1RVdblcy5cvp8I5OTmnT58eaFMWi4UiXGZmpjZPNYIoirJq1SqLxTJInuNjx469\/PLLL7\/8Mvssm7Isy9XV1ZQpOS0trbKykud5nue3b99O23Q6nRzHBa5IY4uRzm63NzU1rV27dqACge3DcVxTU5OWgnr8+PFms5kxZrFYLBYLY2zr1q1xcXGKorz11lvUYoyxu+++WxAEQRAkSWKfNezwZKQ2m81Uw7q6uoHmCQM\/X1VVA+t\/3XWYPn36da8LcHMFFZBSUlL279+\/cuXKioqKoqKiTZs2mUwmvzIcx6Wmpra3t9P3UFEUvy+kw+EwGAz0d21trclk4jiuvr5+xJ1t6eKBzWZLSkrasmXLE0880e8u+J6bUlJSOI7TTpE0venXPvX19XfffXe\/Kw7DToUVdWUSExMrKipo3\/s94fbbPhUVFRUVFaqqvv76636DJ1mWe3p6qJhvUBcEQVXVl1566amnnjIaje3t7cOc0l5RlJaWloyMjH7\/G\/j5chznV\/8beXee56kvSOOkcFw\/AwiToKbsjEZjfHy8NheRk5PDcZzVas3Pz6dZEboUpM0+mUwmCjmMsbvvvjsjI8NkMvX09GzYsIHONYmJiYIgmEwml8tFX84RpLGx0e125+TkCILge3+H1Wrt976vwsLCqqoq7dq73W7Pz8+3Wq10vtDuy3K5XL5nosAVw4fuG8zIyCgvLw\/mRrihcrvdR48era6uNplM+fn52nLa98Ab6nzbhzGmKMqKFSvWrVtHg2m6DGkymUpKSnJzc7UVZVnOy8srLy8XRZHjuFWrVtHR6FcsVKxWqyAI69atEwSBjn\/thkntO6KVDObA8K3\/jVRMm9LMy8sbZEoZQIduwvOQBukjAwDAbWu4fxgry3JxcTF1gYf5rQEAQM\/wxFgAANAFpA4CAABdQEACAABdQEACAABdCCogaQmBfDM20t2315HAURRFv7tgtftlg8y\/GbiFYRZM8sp+c7AG3ujcb3JVyrQ0nPsY7uSq2m4O\/uEGZk3tN4dpYDGttW\/uzTL93sjux\/fb5Ffb4UyuOkhyWN+G1W6yH6EZVWBkCSogFRQUvPDCC5Qc02Kx1NfXM8aMRuO+ffuuI\/uWIAiFhYW+SyhbgcPhWL9+vSRJn\/vLpMAtDKcgk1cG5mCl5Js1NTW+xQKTq4qiWFtbK4qizWbbv39\/uHeHhDW5KmOstraWdnOQ5KqiKFLqKd+sqYE5TAOTq9IPb6m1Y2JiblZPpd\/PN1BiYmJDQ4MkSQ0NDb4NPszJVfttWFrRt2EdDgdl+frcrLgAN+56puwGyU3il1yV+fSwioqKqqqqtC6b1qXttzupddh9t+Y75rh06RKV1J4yQH09KkNdPFr9Bn9mGCjI5JWBOVh5nl+6dOlAm9WSqwqCQOlrQ1vtwYU1uaqqqjNmzKDkPQ8\/\/PBAOaUEQaC+CMdxU6ZMoYWD5DDVkqtyHFdRUXHTf9k2+OerWbp0KWVPkGWZcnOwm5Fctd+GpdS3vu0\/ZcqUYLLiAoREsAGpubmZcitoKRgCBSZX9e1h5ebmvvXWW1ph6v82NDT0ex6hHKwXLlwQRVEUxcuXL6uqarPZtDEHpdTzfS4GjTA4jlu7dm1WVlZcXJzBYNBy7oXQkJJXfm4O1sDkquyz6ZQwpRgYfqqqtrS0BJ9ywmazzZo1a6CQ3G9yVfbZdFN8fPzwpK27cadOndKqqofkqlrDCoJA7c9x3KxZs+iLP0hWXIBQCTYgpaWlaed9SgfpV4CSq2ZmZtLLnJwcmsFITEyk\/qAgCNqTaXp6eoqLi1euXDl4oq3c3FztrKSq6pQpUygWGo1GyuKqKMpf\/vIX+sLk5+c3NTVRfzknJycvL88vGU+oBJ+8knLeZGVlDfJNpulKmsC55557aH9pYWlpaWVl5S3wLETfHvfgaIBrMBgG\/+AsFgv1e5555hktEbjZbNZ6QiGodJj5Jpqj5LA5OTmUvekG63\/dyVW1uVBRFE+ePEnzDSdPntQehIYpOwi3IU\/ZmUymxMTEwLOkllyVXlJyVY7jLly4ENhfi46OLisre+mll4I\/xDmOu3jxopa\/edeuXYwxo9G4evVq6TM006UoSlVV1Y4dO8L0bAue52mPBk9eKYpiXl5eaWmpyWQK5hm7WnJVq9VKp6S4uLju7u5bIyBFRETQjpw+fTolJaXfYrIs5+Tk5Obmms3mrVu3BvM0XkquKsvyr3\/9a9q+wWBobW0N+S6EnO98nW+nZPXq1TeeXDWY47Nfd955J2OM4zjtWU0JCQnUSaJ\/AYRVUAHJZrNREkkazs+fP5\/nebpCU15enpGRQddsApOraoMV3zv0RFFcv349Y6yjoyMnJ8dut9MMVU5OTmFhIV0xUhTFarUWFxfLsux0OtetW2ez2QoKCmizeXl5SUlJJSUljDHtCTR0zxJlqDx69Gh7e7vL5VqzZk3IY9JAySv9cmgG5mClC2OUkVYrGZhcVdvNjIyM3NzcYcjWHO7kqoyxefPm0WHgO\/Pjd0\/asWPH3G43pet94403aGFgDtPA5KpGozErK4uOz6amJr+k4MOm38+XDZBc1Xe+Tls9rMlV\/aoR2LBJSUmbN2+mo7Gnp4em7Hp6emjJ5s2bk5KSbqRiAJ8LqYMAAEAX8MNYAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQhSFn+74N8\/7S7vvmRQ7MNj3Iiv2mNvf9rYnf9n1zn4ck6UC\/9e83o3P4UowHme07MFu2Vje\/NNiBeakBYKQbcrZvh8NBOUBvE1arlRL0zZ07l\/JEBGab7nfFgYrV1tZmZ2cPsn3G2KOPPkq5J2489dFA9fdLl15YWEjvGKY06sFk+w7Mlu2bC9FgMGiBym63u1wuSZL27duHBGsAt4whTNmpqrply5akpKRFixaxz7qodXV11POlLKiUJodyclNfWOvhak9n6beYblksloEeh6Flmx58C77FRFGMj4+fNWtWMNsPicDtG41G+gQDl6iqeunSpZD\/ID\/IbN+B2bI5jrNYLJSrQkvRRnHLYrGEtpIAcNMNIdt3RkYGpcAhZrO5pqZm\/fr11PMVBEEQBIfD8dprr1FObrPZrKWVoxTdlCo0sFh4di1kKIJqqX0GyjbtJ7AYPWIgMLGN3\/YZY2+88UYIZ0cDtz8Qt9ut5S4LoaFm+w5Ead0ptW57e\/uFCxf6nccDgBFtCNm+GxoafB\/nRcrKyvzmTAoLC7UTnyzLc+fOpR6u0WhMTk7Wzkq+xXROEASaMtLCQ7\/ZpgP5FZNlubq6WhCE\/Px8q9WqJQ\/1276WalOSJFVVr+9RAoPXfyCDZD69EcFn++6XKIolJSWrVq2iSEnpEKmXgxTUALeSIUzZcRz39NNPq6pqtVqD7O0ajUatpKqqfX19w\/zcuRukKEpRURGFhOnTp7tcLt\/\/atmmB9+IVowCgyRJNTU1NBPV7\/btdrv2QMILFy6Er\/5+wjRfx4LO9t0vq9VaW1tbXV3d3t5eV1fHGKMMv\/TftLS0kXVEAcAghpztOyMjg86SVquVEhtrMyd2u13L2E33dNETKGj2SXvqV2Cx8O7iDeB5fuXKlZSm2mq10kOYArNNk4FuXfMrZrfbtRFSv9s3m80ul8s3sXpo608zeIWFhTk5OdqFPRa2+ToSTLbvwGzZNBjas2ePIAg5OTmUCNg3hXxhYWFIHmoHAHqAbN8AAKAL+GEsAADoAgISAADoAgISAADoAgISAADoAgISAADoQlABiW7P1dzgvdqUZ3NkpcW02+3aXquqSkmPfO+ZDtRvjlS65dp336lYWG9\/\/9zkqmzgHKYAAMMmqIAUHR3tcDgcDsf69esbGhoSExMHKllXV\/e5YYYyEYQpiWc4yLLscrm0LBVOp5OSHpWWltbW1g6yol+OVEodRFkGtHSroigWFxcHpsAIlSCTqx45ciQwhykAwHAKKiAtWrRI+zEjz\/MWi4XjOG2gQCMAekk\/t\/Ttj9OYQP+\/gR0IJZzOy8vTlpjNZgowcXFxQ0p83t7evnDhQo7jeJ5PTU11u93s\/7ZtOASTXNVXZmbmSPyYAOAWcP3XkGw2Gw0URFHcu3ev2+2uqKhYv369w+GQJKmiooJ+8z958uSGhgZJkhYsWECn4JHF6XTOnz8\/MGGdqqqVlZXz5s0bZF2\/HKmKopw6dSqMdR1AMMlVtUwKGRkZ\/\/nPf4azegAA5DoDEl07oezLHMdlZWUNdDXlv\/\/9b0ZGhslkWr9+\/XXX8mZRVbWpqSk\/P18QhHXr1jmdTlquKMqKFSuysrIGGdwE5kjlef6mPEoqmOSqRqNx37599Lyr1NTU4aweAAC5zoDE83xiYqI2t0NnW98CVqvVbrfTo2vC+uS3sOI4rqKigkaBL7zwAj05QhTFvLy80tJSeqrTQBNcgTlS4+Li2traWDjTmPoZUnJVsn\/\/\/nAk\/AYA+FzBBiSr1UoZUbVby7RJHt+MmTzP0zXkSwnTAAAJy0lEQVQkxpjZbOZ5\/sKFC1SmsLCwpKREURS6Z0+72qT\/S+g0HtJGSI2NjW63OycnRxAE3wdE+d26FpgjVUs1q+WZpbVo+CUIQsjvcAs+uar2lPr4+Hg8gxUAbgokVwUAAF3AD2MBAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJAAAEAXEJBgBDt58uQbb7zBGPN4PK+88kpbW1u\/xWRZrqqqClwuimJRUZGqqlarVRRFRVGKiooURdH+8C3c0dGxZ88er9criqLdbmeMNTU1\/etf\/6LtFxQUUPm+vr7Ozk6lP6qqBlagpqamr6\/Pd2Fvb6+iKKIovvjii2+++eb1tw7ASBN1sysAcJ28Xu++ffsWL17MGGtvb\/d4PBMmTND+e+bMmbKysq6uLsbYlStX2tvb33rrLfrXvffe+8Mf\/rC3t7exsbGoqIjjuGDebuLEideuXTtw4EBcXBxjzO12Hzp0aOXKlYwxo9G4YsWK+vp6s9l89erVAwcOfPjhh4yxjo6O999\/\/0tf+hJt4YEHHkhPT1dVVYtMSUlJBw8edLvdVIeoqKiYmJg333zz3Llzp0+f\/u53v8vz\/OrVq997773Ro0d7PJ4XX3zRaDSGqP0AdAcBCUaqlpaWxMTE0aNHHzt2zO12v\/XWW4cOHWKMaSdubVQky\/L+\/fspeGhEUWSM8TwfzHudOHGipqaGMXbt2rX3339fVdXGxsYxY8b86le\/SklJ+fa3v200GmtrazMzM3menz9\/\/q5du5YtW9ba2krve\/bsWafTec899zDGjh8\/fvjwYdrmxIkTp06d+re\/\/Y3eZdq0aYsXL164cKGqqjabjaJUQkLCT37yE57n+x3kAdxKEJBgRLp06dKOHTvmz5+\/YcOG7OxsSZJeffXV2NhYxph24rbb7TU1NTExMb4jJC1cNTY2zp8\/P8i3mz17dkVFxeXLl7dt2xYVFRUVFXXt2rWsrKwHH3wwKiqKMTZ27NjExERZlnmepyDX0tJCI7a+vr5Dhw7df\/\/9o0ePZoylp6enp6czxv70pz\/de++99Lemo6PjZz\/7WWtr60cffXTo0KEvfvGLY8eODVWjAegcAhKMSLGxscuWLWtqapo3b97cuXMnT578j3\/847HHHouKioqIiIiMjKRia9asEQTBd4RE4UpV1Z6eniCHR4yxtra2gwcPNjQ0rFy5cs6cOa2trY8\/\/viRI0fWrFmzdOnS1NRUxpjBYGhtbRUEISIi4uGHH3a73RSQurq6IiMjqYwvVVWdTieNlhhjycnJixYtmjRp0ksvvXT06NE1a9b85je\/mT59us1mC0WDAYwACEgwIo0bN87r9fb29s6bN+\/8+fOzZs366KOPNm3atHz58vHjx2sXk3bt2tXU1ETXcjweD2Ps3Xffffjhh4f6dmPGjElPT\/\/mN785atSo48ePjx49etSoUV\/+8pfvu+8+ukylqaur27RpE\/3tOzKz2+2xsbHFxcUzZsxgjF2+fPnKlStPP\/00VfXs2bNNTU0URz0ez7\/+9a+77rpr27ZtK1asuJFWAhhZEJBgRDp\/\/vzvf\/\/7+Pj4N99887777ouIiHjooYc6OztlWdbutXvkkUcyMzO7u7vXrVv3v\/\/97ytf+QoNoWJiYq5evTqkt3vvvfe0oYwsy1evXj1z5gy9pAs\/Y8aMoZeLFi1atGiRVjLw2hVpbW2NjIycNm0azfh9\/PHH9Adj7D\/\/+c9dd93l8XiysrLeffddvxU9Hk99fX1XV1d2dva4ceOGtBcAOoeABCPS1KlTN27cyBjzer2qqvb19UVERDz22GOqqo4ZM4ZO7hzHXbhwwWazLV68eM6cOfHx8Vu3bn322WfpIlB0dLSiKEHetKZd+Ll06dIf\/vCHyMjI9PT0Bx54wLeMy+UK8qKU1+vdv3\/\/ggULtCDU1tZGN++dP3\/+8OHDzzzzzOnTp++4446ZM2c2Nzd3dnYyxq5cucIYa2pqMhgMkyZN2r9\/f3Z2dvAtBqB\/CEgwIl28eHHDhg1nz56dMWPGggUL5s6dSyf3zs7Onp6esWPHtrW1bdu2raen5yc\/+cknn3zidru\/8Y1vSJK0evXqzMzMRYsWzZ8\/v7GxURCEIN+xp6fn8OHD27dvX7169bRp0zZu3Pi\/\/\/3vm9\/8ZkJCQkREhKIoFy5cCCa8eb3enTt3Msa0q0p9fX3Hjx+nmiQkJHz\/+9+\/du2aVr6rq6u2tnbcuHEnTpxYvHhxZGTk6NGjIyMj\/X69BHALiOjp6bnZdQAYMq\/Xe+3aNd870BRFKSsra29vX7VqVXp6eltbW1dXl8FgiIiIOHPmzKFDh5YsWcIY83g8p06dmj179tWrV2022\/Lly4O5taGurq6+vj4rK2vu3Lk0UdbX1\/fhhx\/u3r37k08++d73vnfixInW1laz2ey7lu\/7akRRPH\/+\/OLFi6Oionp6en73u981Nzd\/7WtfW7p0qTYFd+XKla1bt5rN5piYmPfff99gMIwZM4YCrdfr\/fvf\/84Yy8rKGj9+\/A03JICOICDB7UsUxdra2rVr1wb529iByLL80ksvlZWVBX\/bHgAEQkACAABdQC47AADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQBQQkAADQhf8Hh2H\/CXmMjOAAAAAASUVORK5CYII=","height":214,"width":560}}
%---
%[output:17c93ed5]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAARMAAACsCAYAAABYQkisAAAAAXNSR0IArs4c6QAAH+FJREFUeF7tXU2IF0f6rhwN2RwUAxFDJMHZQw6CswfxohuQSMgY8DJRAoOGrAhGDw5+wzjEMZNBD9FAmJVBhKAGQYgTAsHDOgiSQxQkEFiDMopxD2ICusGj\/\/\/Ts2\/7\/mqququ7q\/rzbRh0prvr46mqp9+veuuFZ8+ePVNyCQKCgCBQEIEXhEwKIiivCwKCQISAkIlMBEFAEPCCgJCJFxjzFfLNN9+okydPqtOnT6vly5dHhfz+++9q9+7d6sCBA\/HfTKU\/ffpU7du3T23atEmtWrUqXwM8vUVtmZ6enlfiwMCAGh8fVwsWLPBUm7mYzz\/\/XE1OTqqy6gvamYYWLmRS4cCBTPbv36+2bdum9u7dm4lMKmx2YtW\/\/vqr2rNnj5qYmEgkQ5\/tB5mNjY2poaGh0ur02f62lCVkUuFIgkyuXbum7t27F5EJJAxdMtG\/+vTlRbNJMpmZmVHLli1Tg4ODUW\/wlcaFMvX3z549O0+S0aUc+n316tVRmfTVR5mc+EzQmcjkxx9\/jMp4+PCh6u\/vjySVmzdvqs2bN8dFULvw\/tGjR9XLL7+sSNKhe3pfPvvsM7Vhw4YIB\/1Z3mY8x7H55Zdf1NWrVxX\/e4XToDVVC5lUOJQgk9nZWbVmzRp17ty5aJFhwXA1hxMDiOajjz6KSGLFihUxmaAL9D4nGZATfx+Lenh4uEetou5TW1A2J7RHjx71lJ0mAdjIhNerP0Okiv7fv39fbdmyRX3yyScxkT148CDC5tKlSxFe1MbR0VE1MjISqVBc5TOVd+zYsYhEgQeVF1r1qnBqVVK1kEklsM9VSgt4586d0WKAJLBu3TqrzYRLEJxMFi1aFKsWKBdf9uPHj0d1EPlgISXZWUh6mJqaUrdu3YoJBBIEEZXL4kuSTFD2woUL5yGOuqkOkAlXk\/g9Tia8EBMuJFWRpEaSGyfXCoe+lVULmVQ4rFwaIPH+0KFD6siRI7EBFn\/HlxpfU7og9nMy4f+\/e\/duz9cbZAJC4JdJvOfSyMWLF3vUJrLtoIw01cBGJjohcTUE5ZL6BjIhMgTxcDIBmfH3dPUHxmjCQjcGk3qG97lKWOHwt65qIZMKh5STCX1BQRqPHz+OyGTp0qWxxAKd3yaZQOqgslAO1CaT\/SWtq1hor7zyirp9+7bRmOniQXIhEy4F6YSRRibUB05+hBMnE5uXS8gkbRbkv28kEww2N47xL2LVbsj8Xa3fmzqZkE0Ehkq4i3UyoXHRJROMCUkwixcvVlyd4GI9PUP2Ax0RKp+7V3kbXbwmWcmE7B1oC9lMbJLJiRMnYqkCWLnYTNBmSGcffPBBbIMRySTMWughE5pMJos9t6SbPAJhmtfuUnUyQW91IykndowLLiwG8mLQF5jGZ8mSJbGbGc+aPCDk2dDRJTKjhZf1fTzvQia8TWgvpLALFy5Edh4YfG1kQsRAaptJzaGPnc0DJZJJuDUVkwkm0qlTpxSMgWmGtjNnzkQ6rsmY5tJU18Asl7LkGUFAEKgHAvPUHC4+5iWLpK6RqI1neORnPeCQVggCgkBeBIw2k1CiIEk\/69evV4cPHy41SjIvQPKeICAIuCFglExM7kQUB7ebLVbArbq5p6oIuc7SPnlWEBAEsiNQiWtYyMQ+UDMz9ntXrjy\/t3YtXMDZB1zeEARCIVA7MoFLGh6MXbt2RT9tuP773+e9ePJk7v\/Xr8\/94AJJEFGAJGwXv9d5MiFQCVACjf+u3zMB+5e\/+JliSXX19\/upo+alGMmEu+7gtUF4MyIz07bFu\/Y1STJ544031J07d1yLquVzmOeYW\/TDiYP\/\/x\/\/UGrJkrkujIzUsivVNUonC1qsfNESG9O\/1Fr+u36Pnim6wPG+qWzT3zqSzHAemfB4hY0bNyq4gQ8ePBhtssIOVx+5KdpGJv\/5z9wMJfLgksc\/\/6kU5h3NXUgU+MEH8aWXqlurldWcJlHYvvAAkgPLyUAnhqR7JsLxCYaJpIoSl8\/2BSwr0TWMACIiE5AMRRyGcBlTH5simYBA2HaZeIgw52neQ\/Lg0serrwYcyToWTSxrAiqpvVx842DiHc7MXEXR1RX63cTYXO8MgVsnvxKWtI20TXvr1q1RZOL27dvVjh07ov0elMQnxBigzLqTiYlEaL7jX5AHzXeoMEIg2kxJU01wnxMGAKULBEE\/HV2wodadj3KtBlh9f07ablEfjakzmdhIhAgEbad53zkSsUkgumpCkgX\/lyYOqQK6SkBGpc6xsq8VVV45lXhzkrpXN8kkjUT4h7NTJAJguJGIDypIhFQV0vWyzGkhkCxo1eZZ53D60GH2dbOZ2NYKrZPJyedj2Lm5n2YwIoblTAu4bDYO\/ndRX2pDDlkb0rPRzxb5SoWWkfm7asmE3Lo246quzuD3TkngOpGQBEL6nk4gnRLXsi6\/dj3vLJmU1e0qycT2wcV6IRdvbewiaKzuwQj9Vb91a061waVbnYVEyloita1HbCb\/n3HdRiIYNRAJ0ohw1b\/yj21Sg2mq6SpFEfEJ4tq\/\/\/18EpOuB2OpkEhtF3fZDTOSCc\/5yRvka6NfXQywSSoNfXx16b0RRGIDOE\/jdSIhdoXRiHte8pRd9myX+oIiYFRz6KgFJBamfKKh0hLovStLzUn7uNPHl+JGyH7Y1xd0PJILT2u0a9NcF76pvr\/9TSlOJJ2zPruC3L3nEm0mly9fNp5T0uQIWJf1qAddtopI+BxPIhUTUND3uGrjSkrdW1ed7LF1bw7OHVm5cmV8hsmNGzfU+fPnveQzqUrNcSESfb1QW\/\/61wr30rg0PO\/0hW0FpMCNt0lhvmQjqRSQvJ2V90IiYLSZ8JgSSCc4DxdXGYmkQ6g5LmuR9tSYYqwqXTdJMR2mmZF3oxmRCrw1ul9cD64RiSTkmmxs2Z3w5th2oduMrHw0G0UkaLhtW3yeSFQqD+LaTz\/NwQLSqdRw1Ni11vqGt55MdGcEH9EkaQTPVfoBTpJIQBg8BDdtmlKgDJ7jFmWX90Ak3OBaKbumNVjuV4mAMQK2DHXG1mnfag6Ps6I600ikVUSShT31QRGDa5Vrs3F1z5NMTDEmZYTRE3K+yYRL\/S4kUlsiscV3ZJ1yrlKKTiSi3mRFunPPO6k5tqMnOVp0GhxOW0siH37SmimtgU8y4SqOK5FUumaS4vl1daPoVDWF9nLRTVelRL0pinjr37eSCScHoJCm+lBQm35sJUeQH1iNLG7ILTsxMaGWL18eP+aTTKDiIFGzvq\/GNqq1tJGgsTZ\/tY\/p+b8jR2NbimlbdKUM66OTUkYZCPSQCScQnAHreuIevYcsbMjGZjpDF52BhEPnyOpnyoZQc+jji7KT7JWUvKvI9pVCg5Xku7YRCZjPNbO6yd3LG8xVH5JIXPKoFuq0vNw2BHoMsBRGzyUFlw7rZweDTGzJp0ll6u\/vNyan9iWZkIpDm\/RsOX0rlUYAbhKRmEJx8xp1ktxaNMhkYOJgiXrjsgTkGaXlgNVVG9dUja5kwknm\/v37QdUcruKYpJLKSQTTz+RqSrJb4F4RlQOEgoA0l\/NkitYly6tzCCQaYLmxNMmo6qrm8M2CdKQGwvYHBwd7bCb4peghXDxnj54VrTJ1hk+vPESC931ICi4hwb7q6tyS6m6Hnbw5tPDv3btn3ZvjYoDlkgnKRGY3srP4tJmYVJzK7SLUwTR1I8kF7INIqB1phFIL0a27C7OJPZ9HJlwaoQ65GGO5irRt27b4SAwQCC6SPspwDesqTm3WRREiCdEJm9pTRJVq4iqQNntBYF4E7MOHD529OF5aoBXiwwCrqzi1OFDNlUhMe2hCL25d5fIpAYWYJFJmLRFwzgHblOz0uoqDozgr35eWplIkBZCVZbugNoaQgGo59aVRvhFoXXZ6UnFoo2vlH9k0IkkLzS2zA2Di0Empfc9gKa82CDhLJmW1uKiaUysVx5VI9Hyqz41VHTtHo6xZJvWEQMDJmxOiYluZRcikVipOUSIJbScpc1Clrk4gYCQT\/ZxhQqLu2enJjoicx8jlU6aG0DNbXIgkLSdJZY3vxLyXTgZAwKjmmOI\/AtRtLLKIZKK7hCtZjz6IRIygZU03qccjAq2xmdRCxUmKasWg2fba8AEVIvE4vaWoMhGwqjkzMzNx4FmZDcormVSu4qQRiUsaAbGTlDnVpC7PCGRyDdfZZlKZiuOyec6FSEQi8Ty1pbiyEWiFN6cyFSctqhWjKURS9pyW+ipCoBVkoqs4pWgLQiQVTVmptq4IWL05yOVqulw2\/RXpbB6bSekqjhBJkSGWd1uKgFEyMaVdpL\/hIPNz584Zs6T5wCgrmZSu4qS5fkW18TENpIwGIuDsGqaNfjt37lQnTpxQIyMjKsQB5lnJhKs4iEoPurHPF5FUEgDTwNkpTW4UAtaDy69fvx6nIuB5W99\/\/3317bff1kYyKU3FESJp1MSWxpaPgNUAq4fU46iLvr4+lTfptGvXskgmpoxqQXKX+CCSUqzCrijLc4KAfwS8eXNcD+HiJMUzslHXspAJqTiUgT6IiiNE4n\/WSYmtRMAbmbjkgOXn5ixYsECNjY2poaGh3IdwBVdxhEhaOemlU2EQ6ImAHR0dVTCwDg8PK5Nr2BYB65qdXs8Ha+qSq2TCVRyUY0sJkhs2FyJJ22sjqk1u+OXF5iHgRTLJcm7Ozz\/\/rK5cuaIePHigiqg5tNaDqDg+iARzQbw2zVsR0uLcCDiTSVIOWFcygSoEEhkfH1dFj7rAep+entuIC6nE27oVIsk9meTFbiPgjUx4DhTbWcP870UP4dLJxIsXxyWyNU21wXySTXvdXlUd7b0XMgF2WQ2weKfIIVwgk4EBpXAyhDcvTloaASGSji4T6bYLAt7IxPUQLkgn+\/fvj9pmOsvY1QD73XdKHT7sWcWhg7tNyAmRuMwneabDCHgjE18YVkYmSSqOEImv4ZVyWoxAY5MjjY7OnQIRXMVxIRJxAbd4iUjXXBFwlkxcCyz6nKtkQk4XL+vYJpUIkRQdTnm\/Qwj0SCbT09NRRGradebMGTUwMFDprmEiEy8uYZPh1YVIAJSXBqQhLvcFgfoj0COZ0L4ZUzAZuXJBONj0t2rVqiC9yyKZPHni4Rxhk1QiRBJkbKXQdiOQ6RCukCRCMJdOJnqQmhBJu2e89C4YAo22mcBeUvicba7igEjSTtrDUEhQWrAJKQU3F4FGkwm8OYUuXcXBuaJpOwaFSApBLi+3F4HGkgl4wKtUAomENvrYxluIpL0rQXpWGIHGkknhnutSCW0\/tm3yESIpDLkU0G4Euksm3FaSJpUIkbR7FUjvvCBgJBPuBkY8yZ49e9ShQ4fUgQMHerKieWmBVoirN6dw3XwfTpJUIkRSGGopoBsIWLPT47CtjRs3KgSoHTx4UF26dEldu3YtWFb6rK7hQsPDVRyQCsjkp5\/mFylEUghmeblbCCSem\/Po0aOYTCCtIK1jqPNySiUTruLYzgIWIunWSpDeFkbAqOZQRrStW7eqCxcuqO3bt6sdO3ZEUa979+4tXGlSAcHVHBd3sBBJ0DGWwtuJgPO5OabcIyEgCU4maYZXIZIQwypldgCB7nlzkgyvXrYgd2DWSBcFAQMCRjLB+Tbw4ExMTETeG2RHO3\/+vJqamgqyU5i3K6hkohte9SA12QEsi0QQyI2A1ZuzadOmnp3BIJQkb47riX7UUthlcOk2mKBkohtekUCWgtREKsk9ieRFQQAIJHpzFi5cGKOUdNQFHnJJKE2FJaU6CEYmae5gkUpkRQgChRAwqjmQQk6ePKlOnz4dqTkkddi8Oa4n+qGlREoo988\/\/yxPMklyB4tUUmgSycuCgFEyIVhgN9myZUt0aBauJG+O6yFcJMGsWbNG3b17V83OzpZHJtzwit3BPEhNPDiyGgSBwgh48ea4kgnUm5mZmYhAbAd1Qc3BtWvXrujHy8VVHFPOEi8neHlpqRQiCDQWAW9k4nKiH+wqk8gXwi49RWQQm4m4gxs7QaXhzUEgU9rGFStWWN3DWQywgCdJMrlz544\/BHlaRtPuYDG8+sNaSuo0AkZvjunYzjSUXE\/0o3JKIZO0nCVieE0bVrkvCDgj4Owadi6x4INe1Zy00HmRSgqOlrwuCDxHwOoaNnlaygDOG5mYpBIYWhGohkukkjKGU+roEAJWNefmzZvzYEiymfjCzBuZ6IeQ6+5gkUp8DZmUIwhECHjx5vjE0guZmM7C4UdYiFTic8ikLEGgpWRiOqFPT8soUolMf0HAOwJWm8n+\/fubqebo5wZLkJr3SSMFCgImBIw2k927d0fJoy9evKgQ+o49ORRHMjg4GBTJQmqOLpVQfld+sJaEzgcdPym8uwgkuoYvX74c759J2zXsC8JCZKIbXU35XSV03tdQSTmCQA8C1nwmq1evVitXroyTJN24caOUBEm5ySTN6Ipui+FVpr8gEAwBo82ESyGQTsh+cvbs2Z6ESSFalYtMXNQbNFYMryGGTMoUBFrkzdGNrib1RqQSmfKCQFAEmh9nokslJu+NSCVBJ5EULggAAW+7hn3BmVnN4UZXk\/dGbCW+hkbKEQQSEfC2a9gXzpnIRDe62k7n66CtZPPmzQrJqORqNwII24Atsw5Xc3cNu6o3HY0ryUTKdZiJ0oZcCNRpnJu7a1hPemQ6fLzDRtc6TbJcq0ReckKgTuPc3HB6Tib63hsahg6qN9T1nkn2978rdeWK0+Ss5KG1a5X6178qqbrpldaaTPTk0K5guxzCxZ9BuaaM987gEJmI98Y4RD04vvBCbzZ+10Et6zmkh3j2LK5NP1ESN5CZD5dtOwfsQzjxoMh2D8zPU6dOqZ07d6oFCxY49\/7p06dq3759anp6OnoHNoy+vj6FjIU8lQfyHX\/88ce56rA1xnm9OPcm\/4PGCNgTJ05EneaHcKVV4ZIDlu\/voaM0jh071hMI5wwOyASDZ1JvOmon4WPUdDI5cuSIeu2119TBgwejhZ1GJmnz0+X+l19+qd55553orKgsF2+bbdvJmTNn1MDAQLSmMPfx8+6772apJv2jUbi0YgVYXcN0JIVL8VkO4aLyiM31Y0gzkcnAwFzmNL7fpsN2kjaRyQ8\/\/KAWL14cSyN8wfJTDrBAx8fHIwkAksnrr78eH6eCOTY2NqaGhobUo0ePFDxcuPQTEfA3LpXgvdHRUXX9+vXo3Ciq49KlS3E0OGGtR4XjXf1jjLajXfC84DI947LOTM84r5e8FWR4z0umNddzc3i7wMxHjx5Vx48f75GAnMEZHp6zA2hHZ\/QQSwYg2vZo0yUTkAnUBCID7A3DtW7dOvXHH3+oN998M1qUnCxAJrgPIhgZGVG3bt2KiAVSNv0NkoFJyuFqEp\/PS5cujetIk1hMH0ib6pRXCtLnqfN6KWGCe4mAzUomSXYZ50O4vvtOqVdf7YWowwbXxEnWQJsJyGTHjh2ROgAVAeTx4osvRjYROqsafV6yZEl0jC0kD7KZkCQAIkEKjUWLFvWcTmmSTnQy4bYTWvggND3PD0kmtjlts+VAuqL0HkXWea3JJE+qgSxqjk0iIUCdwdED1sRO0jMn2yCZgExwgRywiGGwx052IhqTZAKyIQJ68uRJJKHg4pKJafG6kIlNMkma0zYJpDOSSZ5ESC4GWBpkMqoV0gE5mYidZB6UbSITUh+QFgNqDHlJIJWsXbtWvffee1H\/uTdHn8NcmsGzuidRt5mYJBMbmegnVVLidRiOTc4MsZkopZKy06cdwrVhw4Ye95nNgJVZMhEiMUrJjYozgQGdHyRfRO4v8K4vaSGtCT7c2Jkl+bRGebjvxWbioR1xEZnJROwk6WTic4BaXFbeOJMskPiuw3m9ZGlkzmebTSbotG6EzQlE216r0yRrG7Z16k+dxtlIJnpEH8AjX3uWyMA8oDuDg41+L72Up4pOvOOMYyfQaG8n6zTO1hywMG7t3bs3HgUYmRDAgwChkIRSJ3CaPAU5jk3bmrNr1644NJ3GIMTHjOx8qGNqaipTxDfe0YPRXOcLNwbzfpHXCuVQYF1aHXVaL84pCPK4jF3B5c\/VCZw87a\/LOxzHhoWZxBD6NFSaxgXeRXIzZx23vO\/q64gC6ODyRjwNeTp5HAoPxdfbWaf1YlRz0BFsWkIwENxhtI8GLMqllawD4PJ8SHBsIfy2dmEyA4s8Xy0qk39tdHek7q6kAKy0SMusOLaFTIDl999\/r27fvh3NTZzrNPm\/CGgeVv\/VV1+pq1evRjAR5tx9SxvuyMWM3xFApofb08JHWL0+97nEQO2iOm0b\/UzSlY0weflJpBpyvbjMM\/6M1QDLFwEflKwVZH0+FDjcDuSSZb+oCIx+892v+H3Pnj1qYmIi3kgGjGdnZ4MQdBslE31DnS2s\/ty5c5E6fv\/+\/ehrv337dvX111\/P2w1M0gVIxBRuz0Pz+aZXPU6EjyMWvuu+NjxLbeWmA31eJElBodZL1nWL52MyKUuNSWtkCHBIsurv71f37t2LFi9turK1h742jx8\/zi2ZoIxr167FdiY9kCpPcGAafnS\/rWTCN8ylhdVzNyzfpEf2CFqk2Cm8ZcuWyCZIV1K6ABOZULs4QekpCHT7iOlDYpoTScGeIdaL6xzTn5tHJsjlgKg9hCFnSUGQtwEuOiB94RH49umnn\/aIrybPE5VJEshvv\/0W\/QnsjwFOIxMavLfffludPHmyh0yImDDx0tQSTAxcpBry33lUZ5EcHDbc204m\/GttC6s3xXTwZ4EdbCa6ZEKY2mJCXMiEtgKYxsdEGEkqeOMkE3RaDwvWgUiKgA1NJvhyQLIg8RW\/67lQ0tqg7yGyPU\/GL8KEbCb6+2k2FX3ScPFVTxSFukzJotL61FUy4fjZwuqJDD788MNo0yAlKtIlE9wzhdtDzbElS9JtJrpkYiMT\/jGiscO4432y2egfw8baTKpWd0ximymRkv7Vd1l0LmTCdV6dLHQdN82gm0Qmep9syaJc+mV6pg2SSd6+l\/FeXm9O1ral7eOppZrDRbu0HZZZAcnyvI1MbMZLqGU8ZR6vSze0ppEJF4HhUdHJRDdK8y8LXHtc70bdMMTZ1Byb+Mufz4Kb\/myT40yK9LvMd9NiQHy0Ja2OWpMJifbLli0rlE8zL5BVSiYmERT94DkzTNZ3W191q3yawTXtfhZM6zTJsrRbns2GQJ3G2UumtWzdT346iUzI159XJUiTTPSW6ZKJ\/n5aO5JcwyYVanh4OI7tKYppnSZZ0b7I+3YE6jTOjdjoR4vyrbfeik8vy2OsNJGJzdeP4TMZWHXpJa0dWYLWXOJfXBeWnOjnilSzn6v1iX5VQ+tqM6m6nVK\/ICAI9CKQumsYqgWMn4cOHVIHDhzIfAxAVsCFTLIiJs8LAvVAIHHX8MaNG+PNR4gg5NGceZvPxX6TWC9kkhdZeU8QqBaBxF3DyPhNOxnpLJEikbE88S6OITB5RupkUKp2aKR2QaBZCFh3DSNcfOvWrerChQvRRilE9MHYU2TXMN+rAnLavXv3PNWpjWTyxRdfKOToaNMlfWrGaJY5TlZvTlo27zxQmsLJ9X0ybSQT6VOe2VL+OzJOxTAv1TXsQibi0iw2oPK2IMARKNN1XDqZkBHXpubIVBAEBIFmIlAqmbgYYJsJo7RaEBAEeshEj+70GZFJUJNrOC0XiAyNICAINAuBmEz07fRJ56c2q4vSWkFAECgDAWvaRn07fujGpAWzha7fd\/l6BrgyEkv57oNeHvY26e587vVL26cUun15yjf1iScJa5IErSfc4uNRxjglkgnyhGzatCk1X2qeQeTvtNGWYpqkRXGq8n1SgdEGOrWA9xF\/P3r0qDp+\/Hgl6T7zYGPqU1rCqzz1lPUOT2HBd7T39fXFH4GQ41QLMnEJZitrQHzV0yY1kdIfrl+\/Xh0+fDjOsM93VSO\/blkfHx9jZOtTWz4CnBSBFx3ZEnKceshEz6atD1ooUd0l\/sTHBCqzjKqOCgnZR56fhTLR0ZYI1AsyWb16dSVJtfL229QnnouV8sXmLb+q92zSfshxKtU1bAO2jWTC+5o1KVNVEzCt3i6QCccg9AkCaXjnva9LVzxnTyfIpM3BbE2dlPpkNpFJGeJz3kXl8p7eJ\/2dPInLXeoN9YxJvS5LHa2FZNJGAyw\/fS5twoaaWL7L1fvRdAMs8DERJJ3I1zSJEn3h5xXT+Jc1TrUgE3S6bcFsumu4iW7TNMkE97nLMUSQo29CdOmTfi5xkZ3yodtP5dsOo6MxKWOcakMmZYEu9QgCgkAYBIRMwuAqpQoCnUNAyKRzQy4dFgTCICBkEgZXKVUQ6BwCQiadG3LpsCAQBgEhkzC41q5UPb0EjjAZHx9XCK\/2ffk85tR326S8cAgImYTDtjYlm44xxYJH0vBQhFKbzktDSkNAyKQ0qKuryHbMKQ5Xm5iYiA5W0+MUeMyILe6Cxy7wfVtcMrGVS3\/HFv\/JyckInKbug6luZOtVs5BJvcYjSGsokvPhw4fWg9F52DhIgg5Rx9lJfDPf2NiYGhoaUosWLerJbcIjfjmZcAno5s2bcblLly6NNgbignTE74Hc5GoeAkImzRuz3C3mO5l50h89bFzfvm46LC1pqz6RyYYNG3rSEvA9SnSPdhm3Zet\/7sFpwYtCJi0YxDxd4KoP3jeln6AtAJyE+LYAbtTlBl0ik3Xr1kXl8rORbEQjZJJnFOv1jpBJvcYjSGu4CkIV8MWrqyy2RiRlIeNpJLJIJpTJT8gkyNCXWqiQSalwV1OZadcyFv\/58+fV1NRUlGaR20y49+fu3btqdnY2ki54XmD0hKdpzGszETKpZk6EqFXIJASqNSxTjzPRs+bZdjkn7X7m6o9JzRkcHLR6iXQpRySTGk6ajE0SMskImDwuCAgCZgSETGRmCAKCgBcEhEy8wCiFCAKCwP8BCtoRsPme4EIAAAAASUVORK5CYII=","height":172,"width":275}}
%---
%[output:8221b056]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\Fig3_1b_LearningCurve.svg\n","truncated":false}}
%---
