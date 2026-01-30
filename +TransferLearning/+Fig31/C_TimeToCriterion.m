%[text] `图3.1c：time-to-criterion（例如 80%/90%）的达标会话数：Kaplan–Meier（含删失）或每鼠散点；组间比较为非配对（可控制 BaselinePerf）。`
%
% 图3.1c：LightWater 达标速度（Naive vs Transfer）
% - Naive 组：LightAudioBaseline(成像行为) + LAInterspersed(成像行为) + LAPureBehavior(纯行为)
% - Transfer 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
%
% 关键约束（按用户口径硬执行）：
% - 必须通过 Stimulus="LightWater" 查询；不要依赖 Design 名称。
% - Naive 光水会话中掺杂 AudioWater 回合的鼠必须剔除（LAInterspersed：同一 Naive block 内出现 AudioWater 即剔除整鼠）。
% - 不同数据库之间理论上不应有重复鼠名；如出现重复，直接报错（不做去重或合并）。
% - 只导出 SVG（不导出 PNG/CSV；不 assignin）。
%
% 方法选择：
% - 本数据存在删失（例如 LAInterspersed 某些鼠缺少后续 Learned 会话），因此默认用 Kaplan–Meier。
% - 统计优先：Cox (Group + BaselinePerf)；若 Cox 不可用/失败，回退到 log-rank（不含协变量）。
%
% 执行方式（硬性要求，不要忘）：
% - 本文件必须保持为脚本（严禁改写成 function）。
% - 不要使用 run。
% - 在 MATLAB Editor 里打开后直接 Run/F5 执行。

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch ME
				warning(struct(...
					'identifier', 'Fig3_1c:ProjectLoadFailed', ...
					'message', sprintf('Project load failed: %s', ME.message)));
			end
		end
	end
catch ME
	warning(struct(...
		'identifier', 'Fig3_1c:ProjectCheckFailed', ...
		'message', sprintf('Project check failed: %s', ME.message)));
end

% --- 1) Load datasets
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（LightWater：Naive+Learned）
LAI  = TransferLearning.LAInterspersed();       % 成像：交错（含 Naive LightWater；需剔除混掺 AudioWater 的鼠）
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（LightWater：Naive+Learned）
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（LightWater：Transfer+Final）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（LightWater：Transfer+Final）

% --- 2) Build per-mouse per-session tables
% 重要：部分数据库会在 Naive→Learned / Transfer→Final 之间存在未标注 Phase 的 LightWater 会话。
% 为了与学习曲线一致，这里以 Phase 作为锚点，纳入两锚点之间所有 LightWater 会话（无论 Phase 是否缺失/其他值）。

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  "Naive",    "Learned"); %[output:9d52a02e]
naiveB = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", true, "Naive", "Learned"); %[output:00a018cc]
naiveC = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior", false, "Naive", "Learned");

tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  "Transfer", "Final"); %[output:230a1dce]
tranB  = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, "Transfer", "Final");

naive = [naiveA; naiveB; naiveC];
tran  = [tranA; tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");
iAssertNoMouseAppearsInMultipleGroups([naive; tran]);

if isempty(naive) || isempty(tran)
	warning(struct(...
		'identifier', 'Fig3_1c:EmptyData', ...
		'message', sprintf('Empty group detected (Naive sessions=%d, Transfer sessions=%d).', height(naive), height(tran))));
end

allSessions = sortrows([naive; tran], {'Group','Mouse','DateTime'});
allSessions = iAddSessionIndex(allSessions);

perMouse = iPerMouseTable(allSessions);

% --- 3) Time-to-criterion (two thresholds)
thresholds = [0.80 0.90];
%%

% --- 4) Plot Kaplan–Meier (1 - S(t))
f = figure('Color','w', 'Name', 'Fig3.1c Time-to-criterion (LightWater)'); %[output:5b85fc52]
MATLAB.Graphics.FigureAspectRatio(73,48,3/4); %[output:5b85fc52]
tlo = tiledlayout(f, 1, numel(thresholds), 'TileSpacing','compact', 'Padding','compact'); %[output:5b85fc52]

statsOut = struct();
for k = 1:numel(thresholds)
	thr = thresholds(k);
	[perMouseTTC, perMouseCens] = iTimeToCriterion(perMouse, thr);
	
	ax = nexttile(tlo, k); %[output:5b85fc52]
	hold(ax, 'on');
	
	% Naive
	idxN = string(perMouse.Group) == "Naive";
	idxT = string(perMouse.Group) == "Transfer";
	
	[sn, xn] = iKaplanMeier(perMouseTTC(idxN), perMouseCens(idxN));
	[st, xt] = iKaplanMeier(perMouseTTC(idxT), perMouseCens(idxT));
	
	ln1 = stairs(ax, [0; xn], [0; 1-sn], 'LineWidth', 1.8);
	ln2 = stairs(ax, [0; xt], [0; 1-st], 'LineWidth', 1.8);
	
	if k==1
		ylabel(ax, 'Fraction reached (Perf > Criterion)');
	end
	ylim(ax, [0 1]);
	box(ax, 'off');
	
	nNaive = sum(idxN);
	nTran  = sum(idxT);
	if k==1
		legend(ax, [ln1 ln2], {sprintf('Naive (n=%d)', nNaive), sprintf('Transfer (n=%d)', nTran)}, 'Location','southeast');
	end
	title(ax, sprintf('Criterion %.0f%%', 100*thr));
	
	% Stats: Cox (Group + BaselinePerf) preferred; fallback to log-rank.
	st = iStatsCoxOrLogRank(perMouseTTC, perMouseCens, perMouse);
	statsOut(k).Threshold = thr;
	statsOut(k).Stats = st;
	
	if isstruct(st) && isfield(st,'Method')
		if isfield(st,'PGroup') && isfinite(st.PGroup)
			text(ax, ax.XLim(2), 0.02, sprintf('%s: Group p=%.2g', st.Method, st.PGroup), ...
				'HorizontalAlignment','right', 'VerticalAlignment','bottom');
		elseif isfield(st,'P') && isfinite(st.P)
			text(ax, ax.XLim(2), 0.02, sprintf('%s: p=%.2g', st.Method, st.P), ...
				'HorizontalAlignment','right', 'VerticalAlignment','bottom');
		end
	end
end
xlabel(tlo, 'Session to criterion'); %[output:5b85fc52]

% --- 5) Export SVG only
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch ME
	warning(struct(...
		'identifier', 'Fig3_1c:MakeDirFailed', ...
		'message', sprintf('mkdir failed: %s', ME.message)));
end

svgPath = fullfile(outDirUNC, 'Fig3_1c_TimeToCriterion.svg');
try %[output:group:4ea5a36e]
	% Hide axes toolbar in SVG if present
	axAll = findall(f, 'Type', 'axes');
	for i = 1:numel(axAll)
		if isprop(axAll(i), 'Toolbar') && ~isempty(axAll(i).Toolbar)
			axAll(i).Toolbar.Visible = 'off'; %[output:5b85fc52]
		end
	end
	TransferLearning.PrintFigure(f, svgPath); %[output:5b85fc52] %[output:266f7848]
	disp("Wrote: " + string(svgPath)); %[output:6431746d]
catch ME
	warning(struct(...
		'identifier', 'Fig3_1c:ExportFailed', ...
		'message', sprintf('Export failed: %s', ME.message)));
end %[output:group:4ea5a36e]
%%

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
% 排除“Naive LightWater 会话中混入 AudioWater 回合”的鼠（整只鼠剔除）
if ~(string(startPhase) == "Naive" || string(endPhase) == "Naive")
	out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase);
	return;
end

% 先找出纯净 Naive LightWater 鼠（同一 Naive block 内不得出现 AudioWater trial）
pure = iFindPureNaiveLightWaterMice(DS, sourceName);
try
	T0 = DS.TableQuery("Mouse", Phase="Naive", Stimulus="LightWater");
	allNaiveMice = unique(string(T0.Mouse));
catch
	allNaiveMice = unique(string(pure.Mouse));
end
T = iQueryLightWaterBehaviorAll(DS);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
	return;
end

T.Mouse = string(T.Mouse);
if ~isempty(pure) && ismember('Mouse', pure.Properties.VariableNames)
	keepMice = string(pure.Mouse);
	excluded = setdiff(allNaiveMice, keepMice);
	T = T(ismember(T.Mouse, keepMice), :);
	fprintf('Fig3.1c: LAInterspersed kept %d pure mice (excluded %d mixed-Audio mice).\n', numel(keepMice), numel(excluded));
	if ~isempty(excluded)
		fprintf('  Excluded mice: %s\n', char(strjoin(excluded, ', ')));
	end
end

T.DateTime = iNormalizeDateTime(T.DateTime);
T = iSessionizeByDateTime(T);
T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
T.Source = repmat(string(sourceName), height(T), 1);
T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function T = iQueryLightWaterBehaviorAll(DS)
% 必须使用 Stimulus=LightWater（不回退到 Design）。Phase 仅作为锚点，不作为过滤条件。
vars = ["Mouse","DateTime","Performance","Phase","Stimulus"];
try
	T = DS.TableQuery(vars, Stimulus="LightWater");
catch
	% Some datasets may not have Stimulus indexed; try broader
	try
		T = DS.TableQuery(vars);
	catch
		T = table();
	end
end

if isempty(T)
	return;
end

if ~ismember("Stimulus", string(T.Properties.VariableNames))
	error(struct(...
		'identifier', 'Fig3_1c:MissingStimulus', ...
		'message', sprintf('TableQuery result lacks Stimulus; cannot enforce Stimulus=LightWater for %s.', class(DS))));
end
if ~ismember("Phase", string(T.Properties.VariableNames))
	% 允许缺失 Phase：此时无法做锚点定位，后续会被 iSelectSessionsBetweenPhases 过滤为空。
	T.Phase = repmat(missing, height(T), 1);
end

T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
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
if ~ismember('Phase', S.Properties.VariableNames)
	S = S([],:);
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

function dt = iNormalizeDateTime(dt)
% Unify timezone to avoid vertcat errors across datasets.
try
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end

function S = iSessionizeByDateTime(T)
% Collapse blocks within the same (Mouse, DateTime) into one session.
if ~ismember('Phase', T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
T = T(:, {'Mouse','DateTime','Performance','Phase'});
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse','DateTime'});

[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
nBlocks = splitapply(@(x) sum(isfinite(double(x))), T.Performance, G);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);

S = table(mouseKeys, dtKeys, perf, nBlocks, phaseSession, ...
	'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
end

function ph = iPickSessionPhase(phases)
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

function pure = iFindPureNaiveLightWaterMice(DS, sourceName)
% “纯净”定义：在 Phase=Naive & Stimulus=LightWater 的 blockUID 集合内，Trials 里不能出现 AudioWater。
try
	B = DS.TableQuery(["Mouse","BlockUID","Phase","Stimulus"], Phase="Naive", Stimulus="LightWater");
catch ME
	error(struct(...
		'identifier', 'Fig3_1c:PureNaiveQueryFailed', ...
		'message', sprintf('Pure-Naive query failed for %s (%s): %s', char(string(sourceName)), class(DS), ME.message)));
end

if isempty(B)
	pure = table(string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','NBlocks'});
	return;
end

B.Mouse = string(B.Mouse);
if ~isprop(DS, 'Trials')
	error(struct(...
		'identifier', 'Fig3_1c:MissingTrials', ...
		'message', sprintf('DataSet %s (%s) has no Trials; cannot detect AudioWater mixing.', char(string(sourceName)), class(DS))));
end
Tr = DS.Trials;
if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
	error(struct(...
		'identifier', 'Fig3_1c:TrialsMissingFields', ...
		'message', sprintf('Trials table for %s (%s) lacks Stimulus/BlockUID.', char(string(sourceName)), class(DS))));
end
Tr.Stimulus = string(Tr.Stimulus);

mice = unique(B.Mouse);
keep = false(size(mice));
nBlocks = nan(size(mice));

for i = 1:numel(mice)
	m = mice(i);
	rowsM = (B.Mouse == m);
	bu = unique(uint64(B.BlockUID(rowsM)));
	nBlocks(i) = numel(bu);
	hasAudio = false;
	for j = 1:numel(bu)
		b = bu(j);
		trB = (uint64(Tr.BlockUID) == b);
		if any(Tr.Stimulus(trB) == "AudioWater")
			hasAudio = true;
			break;
		end
	end
	keep(i) = ~hasAudio;
end

bad = mice(~keep);
if ~isempty(bad)
	fprintf('Fig3.1c: Excluding %d mice from %s due to AudioWater-mixed Naive blocks.\n', numel(bad), string(sourceName));
	fprintf('  %s\n', char(strjoin(bad, ', ')));
end

pure = table(mice(keep), nBlocks(keep), 'VariableNames', {'Mouse','NBlocks'});
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
	error(struct(...
		'identifier', 'Fig3_1c:DuplicateMouseAcrossSources', ...
		'message', sprintf('Group %s has duplicated mice across sources (should not happen).\n%s', ...
		char(string(groupName)), char(strjoin(msgLines, newline)))));
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
	error(struct(...
		'identifier', 'Fig3_1c:MouseInMultipleGroups', ...
		'message', sprintf('Some mice appear in multiple groups (Naive/Transfer):\n%s', char(strjoin(msgLines, newline)))));
end
end

function T = iAddSessionIndex(T)
% Add per-mouse session index based on DateTime ordering.
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(string(T.Group), string(T.Mouse));
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

function perMouse = iPerMouseTable(T)
% One row per mouse with BaselinePerf and N sessions.
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','Session'});
[G, gk, mk] = findgroups(T.Group, T.Mouse);
perfSeq = splitapply(@(p) {double(p(:))}, T.Performance, G);
sessSeq = splitapply(@(s) {double(s(:))}, T.Session, G);
base = cellfun(@(s,p) p(find(s==1,1,'first')), sessSeq, perfSeq);
nSess = cellfun(@(s) max(s), sessSeq);
perMouse = table(gk, mk, base(:), nSess(:), sessSeq(:), perfSeq(:), ...
	'VariableNames', {'Group','Mouse','BaselinePerf','NSessions','SessionSeq','PerfSeq'});
perMouse = sortrows(perMouse, {'Group','Mouse'});
end

function [ttc, cens] = iTimeToCriterion(perMouse, thr)
% One row per mouse: TTC is the first session index with Performance>=thr.
% If never reached, censored at last available session.
ttc = nan(height(perMouse), 1);
cens = false(height(perMouse), 1);
for i = 1:height(perMouse)
	s = double(perMouse.SessionSeq{i});
	p = double(perMouse.PerfSeq{i});
	idx = find(p >= thr, 1, 'first');
	if isempty(idx)
		ttc(i) = max(s);
		cens(i) = true;
	else
		ttc(i) = s(idx);
		cens(i) = false;
	end
end
end

function [surv, x] = iKaplanMeier(time, censor)
% Kaplan–Meier survivor function via ecdf.
time = double(time(:));
censor = logical(censor(:));
if isempty(time)
	surv = 1;
	x = 0;
	return;
end

try
	[surv, x] = ecdf(time, 'censoring', censor, 'function', 'survivor');
catch
	% Minimal fallback: treat censored as events at last time (conservative)
	t = time;
	[ts, ord] = sort(t);
	surv = 1 - (0:numel(ts)-1)'/numel(ts);
	x = ts(ord);
end
end

function st = iStatsCoxOrLogRank(time, censor, perMouse)
% Return a struct with fields Method and p-value(s).
st = struct('Method', "", 'PGroup', nan, 'PBaseline', nan, 'P', nan);

grp = double(perMouse.Group == "Transfer");
X = [grp(:), double(perMouse.BaselinePerf(:))];

% Prefer CoxPH if available
if exist('coxphfit','file') == 2
	try
		[~, ~, stCox] = coxphfit(X, double(time(:)), 'censoring', logical(censor(:)), 'ties', 'breslow');
		st.Method = "Cox";
		if isfield(stCox,'p') && numel(stCox.p) >= 1
			st.PGroup = stCox.p(1);
		end
		if isfield(stCox,'p') && numel(stCox.p) >= 2
			st.PBaseline = stCox.p(2);
		end
		return;
	catch ME
		warning(struct(...
			'identifier', 'Fig3_1c:CoxFailed', ...
			'message', sprintf('coxphfit failed, fallback to log-rank: %s', ME.message)));
	end
end

% Fallback: log-rank (no covariates)
try
	p = iLogRankP(double(time(:)), logical(censor(:)), grp(:));
	st.Method = "LogRank";
	st.P = p;
catch ME
	warning(struct(...
		'identifier', 'Fig3_1c:LogRankFailed', ...
		'message', sprintf('log-rank failed: %s', ME.message)));
end
end

function p = iLogRankP(time, censor, group)
% Two-sample log-rank test.
% time: event or censor time; censor=true means censored.
% group: 0/1.
time = double(time(:));
censor = logical(censor(:));
group = double(group(:));
if numel(unique(group)) < 2
	p = nan;
	return;
end

% Unique event times only
eventMask = ~censor;
if ~any(eventMask)
	p = nan;
	return;
end
uniqT = unique(time(eventMask));
uniqT = sort(uniqT(:));

O1 = 0; E1 = 0; V1 = 0;
for i = 1:numel(uniqT)
	t = uniqT(i);
	atRisk = time >= t;
	n1 = sum(atRisk & group==0);
	n2 = sum(atRisk & group==1);
	n = n1 + n2;
	if n <= 1
		continue;
	end
	d1 = sum((time==t) & eventMask & group==0);
	d2 = sum((time==t) & eventMask & group==1);
	d = d1 + d2;
	if d == 0
		continue;
	end
	E1t = d * (n1 / n);
	% Hypergeometric variance with finite population correction
	Vt = (d * (n1/n) * (1 - n1/n)) * ((n - d) / (n - 1));
	O1 = O1 + d1;
	E1 = E1 + E1t;
	V1 = V1 + Vt;
end

if V1 <= 0
	p = nan;
	return;
end

chi2 = (O1 - E1)^2 / V1;
% p-value for chi-square with 1 dof: 1 - chi2cdf(chi2,1)
% Use gammainc to avoid toolbox dependency
p = 1 - gammainc(chi2/2, 1/2);
end


%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:9d52a02e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID           MustWarn        \n    ________    _______________________\n\n       26       \"最后一回合没拍到\"        \n       65       \"2次中断拍摄，无法对齐回合\"\n"}}
%---
%[output:00a018cc]
%   data: {"dataType":"text","outputData":{"text":"Fig3.1c: Excluding 4 mice from LAInterspersed due to AudioWater-mixed Naive blocks.\n  vtf0045, vtf0101, yqn0051, yqn0052\nFig3.1c: LAInterspersed kept 8 pure mice (excluded 4 mixed-Audio mice).\n  Excluded mice: vtf0045, vtf0101, yqn0051, yqn0052\n","truncated":false}}
%---
%[output:230a1dce]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID        MustWarn     \n    ________    _________________\n\n       14       \"拍错Z层，舍弃信号\" \n       51       \"水滴漏了，没有拍到\"\n      111       \"2\/5层亮度反相\"   \n"}}
%---
%[output:5b85fc52]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAhwAAAFRCAYAAAA\/0HRTAAAAAXNSR0IArs4c6QAAIABJREFUeF7tnV+IHUd+72vfdhLYa41xuDsRaLL2+CF+GK\/3ZRgbZD8sehqb+7ArjeAiZGURa0Wey46iGY0TS3KQRlIk4wglMJGHwXmQrGvwRdKTCKzt4BV6uckOwQt35bUnwlEgRvaCL2if4suvdWvc09N9TtWvu+t0dX8azK7m1K\/+fKp+db7nV9VV3\/r666+\/NjwQgAAEIAABCECgRgLfQnDUSJesIQABCEAAAhBICCA4GAgQgAAEIAABCNROAMFRO2IKgAAEIAABCEAAwcEYgAAEIAABCECgdgIIjtoRUwAEIAABCEAAAggOxgAEIAABCEAAArUTQHDUjpgCIAABCEAAAhBAcDAGIAABCEAAAhConQCCo3bEYQr44osvzL59+8zq6mpS4Pj4uFleXjbDw8O5Fbh9+7Y5fPiwOXPmjBkbG1NX8v79+2Z+ft5MTk6anTt3qvPJM7xy5Yo5cuRI8tHU1JQ5deqUGRoaSv6dbm+2rdK2vXv3mrt375rFxcX1esnfT548ac6dO1fIpdIGkBkEaiDQRl8\/ffq0WVpaSmjt37\/fzM3NrZPD12sYRAPKEsExIPBVFmu\/YA8ePLj+5Spf1m+\/\/Xah6EgLjocffjgRK+LkExMTXlWrS3DcunXLyCQkoklEhoiakZGR9YlIPpNH6pz+\/7Y+09PT5vHHHzezs7NmYWEhEVWSbvv27d5t9AJCYgjUSKCNvp6dq8RPR0dH1+cyfL3GARU4awRHYOB1FJd2SJu\/jxCwvyA0gqOO9kieMgndvHlzPaqR\/re0LS2Q0pELEScnTpwwe\/bsMSKkrOCQPN966y3zyiuvrEdJ6qo7+UKgLgJt8\/W8eUr82foqvl7XSBpMvgiOwXCvrFRXsSAT1VdffWXef\/9984Mf\/MD8yZ\/8iXn11VfNa6+9Zt58801z\/fr1pE6XLl1KIgBFyxn2y\/073\/lOYrOysmLefffdDUsqReFR+bssc9y5cydZ+pGIhdjnLenkRTjssk12OSj9761btybREBvhOH78uDl69Ki5ePEi0Y3KRh0ZDYJAG329SHDYpc979+5tWPrF1wcx8qorE8FRHcuB5OS6F0O+7OVL3O7r6LWkkv6ylz0g6V9V2ZBudsLIi0Ts2rUrCY9KPlak2CUOESDpvRlpiOm9GFYIyefZvRgyEaeXTrJ7OJ566imiGwMZnRRaJYG2+np2bkrPE8Ivve8KX69yRIXPC8ERnnmlJfpMQlKw3YzVS3Bk11DTX\/DZXxxpwfH8889v2kCaFiDnz59P2m7rkF02SYPJW9e1tv0ERxaw3bshf9+9e\/eGSE6lnUFmEKiRQFt93c4hNsr6F3\/xF+batWvJhvZ+ggNfr3HA1ZA1gqMGqCGz9AmzuggOeeNDliSs89u22OUP+Xf67Za04PjhD3+4afOpRnAUhVltudk69JqI7Xrwz372M\/P6668nezuyk1jI\/qIsCGgJtNHX81ikI6y9llSyS7H4unZkhbNDcIRjXVtJeRvJpLCi3d3ymU+EI13x7Jd7HRGOfoIjvRlUJp1er7va6Eb6jZWsfW0dQ8YQqJhA23w9D092WTa7XFr0aju+XvFgqyE7BEcNUENnmfeqnPxKOHTo0PqmzOxE5bOHI7280WtJRfZp9NvDkY6y+C6ppPd79BJTln96t7v8zb69QoQj9AilvKoItNXX19bWkqVW276zZ8+uv76Or1c1egafD4Jj8H1QSQ36HQbUS3DYDZxy8I49KCv9lkr6bZJeEQ578Fevt1RcBYeN0NjDgHwO\/rJAs+duiAhjD0clw41MBkigbb6e3cORPqxPMPc6+AtfH+BAVBTdSMHRK0SuaCMmEIBAQwng6w3tGKoFgRoINE5w2JDaI4880vNo7hpYkCUEIBCQAL4eEDZFQaABBBolOOy+AzmK+p133uHOiwYMEKoAgToI4Ot1UCVPCDSbQKMEh0VFmLXZg4baQaAqAvh6VSTJBwLNJ4DgaH4fUUMItJYAgqO1XUvDILCJQJSCQ940kJDszMxM8h9POQL\/fuw5c\/+j983QE8+a7x57r1xmWJcm8Pzf\/tJ8+PGX5pnHtphrLz1ZOr8mZ9BPcODr1fYevl4tz0HldvrGmjl949Ok+C9ef25Q1fAuN0rB8b3vfc988skn3o3FIJ8Ak1CzRgaC45v+wNerHZv4erU8B5UbgqNC8v1+9TAJVQjbGMMkVC3PsrkhOBAcZcdQkT2+XhfZsPkiOCrkjeCoEKZDVkxCDpACJkFwIDjqGm74el1kw+aL4AjImwhHtbCZhKrlWTa3LgmOfqzw9X6E\/D7H1\/14NTU1giNgzzAJVQubSahanmVzQ3AQ4Sg7hlhSqYtgM\/JFcATsBwRHtbARHNXyLJsbggPBUXYMITjqItiMfBEcAfsBwVEtbARHtTzL5obgQHCUHUMIjroINiNfBEfAfkBwVAsbwVEtz7K5ITgQHGXHEIKjLoLNyBfBEbAfEBzVwkZwVMuzbG4IDgRH2TGE4KiLYDPyRXAE7AcER7WwERzV8iybG4IDwVF2DCE46iLYjHwRHAH7AcGRD\/uTH32rVC9wtPlmfL\/4zW+NOHfIR441l6cLR5v344qv9yPk9zk\/Lvx41Z1a5haZY3wfO0eIHUeb+9LzTM8khODwHDLq5DIZTP3NP6vtyxgiOIzB18uMoM22CI5qeZbNzUYzy+SD4ChDz8GWSai34JBIxbefeNaB5OYkW350VGXXVqO04BABEPJ5+tGHzNyO0ZBFNq4sfL3aLkFwVMuzbG5pwaGdX2K64LGRl7f160Qmod6CY8uPjxmEQ79R5PZ5WnDE9EvCrXXNT4WvV9tHCI5qeZbNrWv7tRAcZUdMg+ztHg4ER3WdguCojqUmJwSHhlqxDYKjWp5lc0NwlCUYwJ5JiAhHgGGWFIHgCEU6vxx8vVr+CI5qeZbNDcFRlmAAeyYhBEeAYYbgCAW5Rzn4erWdgOColmfZ3BAcZQkGsGcSQnAEGGYIjlCQERzBSCM4gqF2KgjB4YRpsIkQHAiOUCOQJZVQpFlSCUEawRGCsnsZCA53VgNLieBAcIQafAiOUKQRHCFIIzhCUHYvA8HhzmpgKREcCI5Qgw\/BEYo0giMEaQRHCMruZSA43Fl5pTx9+rRZWloyIyMjZmVlxYyNjW2y\/+KLL8y+ffvM6upqz3QIDgSH1+ArkRjB4Q8PX\/dnFsoCwRGKtFs5CA43Tl6prly5Ym7evGlOnTqViAmZkJaXl83w8PB6Pvfv3zfz8\/OJ0JibmzO3bt3KTScGCA4Eh9cALJEYweEHD1\/346VNLcJB89z\/6P3EjHuT8ulp7jXR9IO1kbtU5F6UrlxjEOTgLxEYo6OjZufOncZGMURUTExMrPeV\/H12dtYsLCwk0Q8rQKanpzekQ3AUD28O\/irj+sUTkL1LhZNG+\/PF1\/szqiIFFzVWQXFjHtybVD3TbI61C46scLD\/npycTASIfYoERzYdggPBUb9bfFMCEQ532vi6O6uyKdOCQ6IVvo\/ctcT1BwgO33FTNn3tgiMb0SgSHNklldu3b5u9e\/eagwcPbhAmVnDI\/87MzCT\/8TwgQISj+pGA4HBniq+7syqbEl8vS3CzfdrXrx\/4fvUF9MlRLmts+1O74HD91SOgrci4e\/eu2b59e8J+\/\/79LKk4jkImIUdQHskQHO6w8HV3VmVT4utlCfYWHCyfVs9XcqxdcEghLuu62eZll1jSn7NpNH8wMAlV7yQIDj+m+LofL21qfF1LrtgOX6+eaTbHIILDZ+e63SSathkaGtpQbwQHgqN+13hQApOQH2l83Y+XNjWCQ0sOwVE9OfccgwgOG+XInsORjWKkl1TGx8c3vTprm4XgQHC4D\/FyKREc\/vzyzuHA1\/059rJAcFTLkx8X1fPMyzGY4KiyOQgOBEeV46lXXgiOUKTzy8HX8fVQIxBfr580gqN+xsFK4FdP9aiZhKpn6pMjggPB4TNeyqTF18vQc7NFcLhxiiIVgqP6bmISqp6pT44IDgSHz3gpkxZfL0PPzRbB4cYpilQIjuq7iUmoeqY+OSI4EBw+46VMWny9DD03W2fBYd+xv379+qacp6amkntSsm+TuFXBP1WbJ6Hf\/eoDY+878CXz5f88lphs+fExThH0hVeQnkmoIpDKbPD1fHD4unJA9TDD16tnms2xr+Cwb46IYdEtr3LR2u7du3ve8FplU9o+Cd096n9UcZovgmPzaJPJRC5K0jxyuZI8HAakoVfOBl\/vzQ9fLze+0tYIjupYFuXUU3DIq2wXL140L7\/8slP0QqIg58+fT257rfNhEmIS8h1fIjZO3\/jU12xDegRHKXwqY3wdX1cNHIURgkMBzdOkb4TDM78gybsyCY0cf998+48fHPHOU46AFRxyDbT2zoK5HaPlKoG1NwF83RsZBkoCCA4lOA8zBIcHrBBJZQ+HXVJBcFRHPC04rr30ZHUZk1OtBBActeIl8xQBBEf9w8FLcNi9Gtlq9ToVtI4mMAnVQbXdeSI44uxffD3Ofoux1giO+nvNWXDYq6d37dq16br4+qu5sQQmodDE4y8PwRFnH+LrcfZbjLVGcNTfa16CY3Z21iwsLJixsbH6a9ajBCahgeKPsnAER5TdZvD1OPstxlojOOrvNWfBIVWRmyDX1tZqfwulX7OZhPoR4vMsAQRHnGMCX4+z32KsNYKj\/l5zFhx2SWV1dXVTrdjDUV1HsWm0OpbpnBAc9XCtO1cER92Eyd8SQHDUPxacBUf9VXEvgUnInRUpHxBAcMQ5EvD1OPstxlojOOrvNQRH\/Yy9SiDC4YXLOTGCwxlVoxIiOBrVHa2uDIKj\/u71Fhyyj+PIkSPrNVtcXAz+1kosk5CIB99H7lGx9yRwDocvveL0CI7qWIbMKRZf1zDhx4WGWn02CI762NqcvQTH6dOnjZzFsby8bIaHh43d1zExMRF0I2kMk9CX7xxfFw7aboxBcIiTxvCI4JA7UeSkUQ7+iqHHHtQxBl\/X0oxNcMTi69r++PBjuW\/pwfUHXGOgpdjbzllwiLjIey1WLnc7efKkOXfuXCJCih4RK0tLSz0veEvfSDsyMlJ4WVwMk1AXBEf6F0E9w7P6XBEc1TPN5tg1X9cSjUlwxOjr2n5BcJQhV5HgkGy0EQ5Zhrl582Zyhb285SL52ChJunryd3nk8jeJpBSli01wSKRC8zT9HpUYJyEEh2Ykutt00dfd6WxMieDQkqvfjghHPYydIxy2eM0eDhEOo6OjyV4PuwwjokKWYuxjoxuTk5NJOomcHD582Jw5c2bTQWOxCY7vvfN1Pb034FxZ8xxwBzSw+C76urYbYhUcfBlrexw7b8Hhi8wKienp6URgZIVFOj\/XX0cIDt9eqCc9gqMerrHm2lVf1\/YXgkNLDrtYCdQuOLIRjV6CQyDaCMrU1FSyBDM0NLSJrQgOeWZmZpL\/mvik93AQ4WhiD1Gnqgl01de1HBEcWnLYxUqgp+CwE8jnn39uzp49m+yp8D1p1PVXD0sq8Q0hIhzx9VmdNe6qr2uZIji05LCLlUDtEQ4B47Kum92z0SsSwpJKM4YbgqMZ\/dCkWnTR17X8ERxactjFSsBZcBS9FuvScJe9GXkRjr179yaRlfTmUikPweFCvf40CI76GcdWQhd9XdtHCA4tOexiJeAsOLKRCt8G572bnxUx2Qviik4xRXD40q8nPYKjHq6x59o1X9f2F4JDSw67WAk4Cw5ui\/XrYjaN+vEiNQTyCMTw40LbcwgOLTnsYiXgLDia1MAYJiEER5NGDHWJlUAMvq5li+DQksMuVgIIjj499+\/HnjNyoVqZh9diy9DDtssEYhAcXbvGgIO\/uuyR5dqO4EBwqEcQezjU6DB0JIDgcARVczJ8vWbAHcneS3CkL1eTg7lefPFF88Ybb\/S9uK1qliEnIRvhGHriWbPlx8dUTWn6nSiqRhljmIS05LBzJRDS113rlE2XjnB04d4kIhzakYKds+BIv7a6bds2c\/ny5eQk0GvXrq1fzJZ3KmgdiENOQmnB8d1j79XRnGjzRHBE23XRVDykr2uhsF9LSw67rhFwFhzpV1jv3bu3Ljg+++wzp+vpqwQbchJCcBT3HIKjylFNXnkEQvq6tgcQHFpy2HWNgLPgEDDyfv3du3fNCy+8YK5evZosqRw4cMDI8orc\/hrqCTkJITgQHKHGNeVsJhDS17X8ERxacth1jYCX4BA4t27dMrt3717nVHQ4V50gQ05CCA4ER51jmbx7Ewjp69q+QHBoyWHXNQLegqMJgEJOQggOBEcTxnxX6xDS17WMERxacth1jYCz4Ci6S0UuXTt58mTQN1VCTkJdEBynb6ypx\/3pG58mtuxcVyPEsAeBkL6u7QgEh5Ycdl0j0FdwiKCQS9Rk70bRI3s45I0V3lKJc\/g8\/7e\/NB9+\/GWpyiM4SuHDuIAAgqMZQ4MN4s3oh9hr0Vdw2AaWuS22akghJ6EuRDgQHFWPUPKrikBIX9fWmQiHlhx2XSPgLDiaBCbkJNQlwfHMY1vMtZeebFJXU5eOEwjp61rUCA4tOey6RqCn4LA3xH7++efm7NmzyWuxq6urmxiNj4+b5eVlMzw8HIRfyEkIwRGkSykEArkEQvq6tgsQHFpy2HWNABGOPj2O4OiaS9DeJhFAcDSjN9jD0Yx+iL0WCA4Eh7F7OFhSid2d21d\/BEcz+hTB0Yx+iL0WzoKDTaPPmrbepYLgiN2N21t\/BEcz+hbB0Yx+iL0WzoJDGip7OEZHR83OnTu92y22S0tLZmRkxKysrJixsbENeRS9fpt3kmnISYglFe+uxqDjBGL1dW23sYdDSw67rhFwFhx2A6lm0+iVK1fWb5QVe5mQ+m0ylSPUi9IhOKodpkQ4quXZ5dxi9nVtvyE4tOSw6xoBZ8FRBkw6MmKFi1z2NjExkZvt\/fv3zfz8vJmens5Ng+Ao0xubbREc1fLscm4x+7q23xAcWnLYdY1A7YIjKx7svycnJwuXZiS6cfny5cLTSxEc1Q5TBEe1PLuaW+y+ru03BIeWHHZdI+AkOCRM+vbbb29YBhFRcOjQodz9GGmI2YhGP8HRL7oheYvgkGdmZib5r86HPRx10iXvNhGI3de1fYHg0JLDrmsE+gqOPLFhIdmNngcPHiyMVvj+6nG5DI4IR7XDlAhHtTy7mlvsvq7tNwSHlhx2XSPQ96TR2dlZs7CwsOmtEguq1+ZOm8ZnXVcEztrampE9HkUPgqPaYYrgqJZnl3OL2de1\/Ybg0JLDrmsESgsOl4iEz851l1dvERzVDlMER7U8u5xbzL6u7TcEh5Ycdl0j0HdJRQSAPEURh\/QE0+t6+rx387OHibns35C6IDiqHaYIjmp5dj23WH1d228IDi057LpGoK\/gSJ+\/kT6ES4TGkSNHCg\/yqhMkgqNaugiOanmSW3UEQvq6ttYIDi057LpGoK\/gsEBkr8bu3bvX+RSdGBoCYMhJiLdUQvQoZUAgn0BIX9f2AYJDSw67rhFwFhxNAhNyEkJwNKnnqUvXCIT0dS1bBIeWHHZdI4Dg6NPjCI6uuQTtbRIBBEe1vXH6xpo6w9M3Pk1sv3j9OXUeGHabAIIDwcH19N2eAxrdegRHtd1j92uVyRXBUYZet20RHAgOBEe354BGtx7BUW33IDiq5UlufgQQHAgOBIefz5A6IAEER7WweSOtWp7k5kfAW3C43qHiVw2\/1CEnIfZw+PUNqSFQJYGQvq6td0ybRhEc2l7GrgoC3oLjwoUL5vd\/\/\/fN7\/3e7xXen1JFxXrlEXISQnDU3ZvkD4FiAiF9XdsPCA4tOey6RsBLcMgx5m+99Zb56U9\/as6cOWOOHj1qhoeHgzMLOQkhOIJ3LwVCYJ1ASF\/XYkdwaMlh1zUCXoIjfc+J\/P\/t27ebiYmJ4MxCTkIIjuDdS4EQQHDUNAZYUqkJLNk6EXAWHHLE+fHjx9ejGjba8corr5hed6g41cIzEYLDE1if5ExC1fIkt+oIhPR1ba2JcGjJYdc1As6CI3ttvOtFa3UADTkJEeGoowfJEwJuBEL6uluNNqdCcGjJYdc1As6Co0lgQk5CMQkO7SmCv\/jNb82HH39pnnlsi7n20pNN6mrq0nECIX1dixrBoSWHXdcIIDj69HhMgmP4Z++VGr8IjlL4MK6BAIKjWqgsn1bLk9z8CCA4Wio4RDz4Pk8\/+pCZ2zHqa0Z6CNRGAMFRLVoER7U8yc2PAIKjhYJjbscfIRz8\/IDUDSWA4Ki2YxAc1fIkNz8CCA4Eh9+IITUEAhJAcFQLG8FRLU9y8yPQU3DIq7Czs7NmYWHBjI2N+eWcSS3ndiwtLZmRkRGzsrJSmJ9NJ+aLi4u5p5mGnIRi3MNBhKPUUMW4JIFYfV3bbDaNaslh1zUCzoLj4YcfVosPeaX25s2b5tSpU2Z1ddXIhLS8vLzplNJ0OnnttkjsIDjyh6ndNIrg6JobN6e9Mfu6liKCQ0sOu64R6LukIhPIkSNHenIZHx\/PFRDWKH1CqURN9u3bZ+bm5jacUioC48SJE2bPnj19oykIDgRH1xw1lvbG7OtaxggOLTnsukagr+CwQLTLK9kDwuy\/JycnNyyX2JNMZenm9ddfT4plScVvOBLh8ONF6moJxO7rWhoIDi057LpGoHbBkY1o9BIcEvmQu1kk+iFHpx8+fDi5JC67f0QiHPLMzMwk\/9X5sIejTrrk3SYCsfu6ti8QHFpy2HWNgLPgEDDpcKkrKJ9fPek9G0XCRMplSYUlFdfxR7pwBGL3dS0pBIeWHHZdI+AsOOyvF9n0mX2q2sMxPz9vpqenkygHgsN\/KLKk4s8Mi2oJuO7haKKva0kgOLTksOsaAWfBUQaMz871tbW1ZEnl1q1b5tChQ7mv0BLhIMJRZjxiWx+BmH1dSwXBoSWHXdcIBBEcdjkmew5H3kbU9Dkcly5d2vAmi+0cBAeCo2uOGlN7887hiMHXtYwRHFpy2HWNQDDBUSVYBAeCo8rxRF7NJRDS17UUEBxacth1jYCX4LD7Kq5fv26mpqbMiy++aN544w1z7ty5TYd41Qky5CTEWyp19iR5Q6A3gZC+ru0LBIeWHHZdI+AsONKbOLdt22YuX76cnBx67dq19VNEh4aGgvALOQkhOIJ0KYVAIJdASF\/XdgGCQ0sOu64RcBYc6TXYe\/furQuOzz77zJw8eTJolCPkJITg6JpL0N4mEQjp69p2Izi05LDrGgFnwSFgZDPY3bt3zQsvvGCuXr2aLKkcOHAgWV6RN0tCPSEnIQRHqF6lHAhsJhDS17X8ERxacth1jYCX4BA48rrq7t271zkVHT9eJ8iQkxCCo86eJG8I9CYQ0te1fYHg0JLDrmsEvAVHEwCFnIRCC45f\/Oa35sOPf6vCfPrGp4kdt8Wq8GHUQAIhfV3b\/EEIjtM31lTVfTC\/fGmeeWyLufbSk6o8MIKAloCT4HA5G0NbAY1dyEloEIJj6m\/+WYNl3QbBUQofxg0iENLXtc0ehOCwpwpr64zg0JLDrgyBvoJDxIYsoywvLxvZLLp3715z8ODBDTe9lqmAxjbkJDRIwSGTguaZ2zFqnn70IY0pNhBoFIGQvq5t+KAFh2aekPlB5gkeCIQk0FNw5J0OKOLDvhIb6jXYLJCQk9AgBcf1A99HOIT0BspqHIGQvq5t\/CAFB9FMba9hNwgCCI4+1BEcgxiWlAmBBwQQHPkjgYsa8ZAYCSA4EBwxjlvq3BECCA4ER0eGeieaieBAcHRioNPIOAkgOBAccY5cap1HoK\/g2Ldvn1ldXe1Jb3x8PNlUOjw8HIRyyEmIJZUgXUohEMglENLXtV3AHg4tOey6RqDvWypNBBJyEkJwNHEEUKeuEAjp61qmCA4tOey6RgDBwZJK18Y87Y2IAIKDJZWIhitV7UOg75LKxYsXzcsvv2xcXoGVG2XPnz9f+70qISchIhz4EAQGRyCkr2tbSYRDSw67rhHoG+G4fft2ctiXPCsrK2ZsbGwTI3u\/ysjISGEae1pprzS2LLkgTp6ivSEhJyEER9dcgvaWJRCrr2vbjeDQksOuawT6Cg4LRKIX8\/Pz5vr165sYyW2xp06dKoyCXLlyxdy8eTNJIxtQZULK22TqeqgYgqNrw5T2xkIgZl\/XMkZwaMlh1zUCzoKjDBgRGKOjo8lx6HJ6qbz5ItfZT0xMbMhWJqu1tbW+SzIIjjK9gS0E6iMQs69rqSA4tOSw6xqB2gWHjYxMT08nAsP+e3JyctN9LOlL4qQjLl26tEmUyN8RHF0bprQ3BgKx+7qWMYJDSw67rhGoXXBkIxpFgiP7d1leOXToUO6eEARH14Yp7Y2BQOy+LsLhdx+97436fsrme+987W2vMeBocw01bAZNoHbB4fOrJw2jVyREBIc8MzMzyX91PmwarZMuebeJQFt8vUyfIDjK0MO27QRqFxwC0HVdN09w2KWY9GdEONo+LGlfrATa4OvCfuiJZ1Vd8N1j76nsfI2IcPgSI30TCAQRHC471yUcOzs7axYWFpJXb2VJpehtFgRHE4YOdYDAZgL4ephRgeAIw5lSqiXQ9+Cvqu5SyXs3Pysy0udw9DqvA8FR7SAgNwhUSQBfr5Jmfl4IjvoZU0L1BLwiHOlwqa1K+heNy2mkVTQBwVEFRfKAQPMJtNnXy9BHcJShh+2gCDgLjmw0wlZYohInT540586d47bYCnrxF7\/5rZn6m39Ocrp+4Pvm6UcfqiBXsoBAnAQQHEQ44hy51DqPgLPgEGMbKrXnY9gjzffv39\/3sK4q8bd5EkJwVDlSyCt2Am329TJ9Q4SjDD1sB0XAS3BIJV33WdTZoDZPQgiOOkcOecdGoM2+XqYvEBxl6GE7KALegmNQFU2X2+ZJCMHRhBFGHZpCoM2+XoYxgqMMPWwHRQDB0Yc8B38NamhSLgTafY1Bmf5FcJShh+2gCHgJjvSNsXKsmTarAAAgAElEQVRD7IsvvmjeeOONoBtGBVSbf\/UQ4RiUK1BuEwm02dfL8EZwlKGH7aAIOAuO9FHj27ZtM5cvX06um7927dr61fO8Flu+GxEc5RmSQ3sIIDjy+xLB0Z4x3qWWOAuO9Gux9+7dWxccn332Ga\/FVjhiEBwVwiSr6AkgOBAc0Q9iGrBOwFlwiIW8Fnv37l3zwgsvmKtXryZLKgcOHDCyvDI3NxcMa5snIQRHsGFEQREQaLOvl8FPhKMMPWwHRcBLcEgl7dkbtsKLi4tm586dQesfwyQkwuH0jTUVlw8\/\/jKx4+AvFT6MWkQgBl8fBG4ExyCoU2ZZAt6Co2yBVdjHMAmJ2Dh949NSzUVwlMKHcQsIxODrg8CM4BgEdcosSwDB0Yeg9rXYtOB45rEtqn6a2zHK0eYqchi1hQCCI78nERxtGeHdaoeX4Mgup1hU4+PjZnl5mbtUUmMnLTi+eP25bo0qWguBigggOBAcFQ0lsmkAAWfBIW+pyFX1u3btCr5nI8sphkkIwdGA0U0VoicQg68PAjIRjkFQp8yyBLwEx+zsrFlYWDBjY2Nlyy1lH8MkhOAo1cUYQyAhEIOvD6KrEByDoE6ZZQk4Cw4pSJZUPvjgg6CvwOY1MIZJCMFRdmhiDwEER9EYQHDgHTES6Ck47DLK6upqz7axh2MzHgRHjO5AnZtGIIYfF4NghuAYBHXKLEvAK8JRpjA5NGxpacmMjIyYlZWVvssykl6evAPFYpiEEBxlRgu2MRPomq8Poq8QHIOgTpllCXgJjvTx5rKP48qVK073qKTTSbREJqReb7XYt2H279+P4Cjbw9hDICCBLvp6QLzrRSE4BkGdMssScBYc6cvb0ieLygSztrbWc1+HCIzR0dHk7Ra7TCORi4mJiU31l8+PHz+e\/F2iIUQ4ynYx9hAIR6CLvq6lW8VpxHM7\/sjIeT08EIiBgLPgyEY3bONu377d8\/I2K1Smp6cTgVEkXGx+dsISEcOSSgxDiDpC4AGBrvq6tv\/T9yZp80BwaMlhNwgCzoIjO5nYysryR68lkmxEo5fgEPHy1ltvmVdeecWcP38ewTGIEUGZEFAS6KqvK3GZtODgNGItRexiIuAsOKRRsnxy5MgRc+nSpSRaYfda9LrAzfVXj6Q7ceKE2bNnT7KhtN+mUanPzMxM8l+dTxVHm3PSaJ09RN5NIdBVX9fy52ZoLTnsYiXgJTikkRKF2Lt3b3JNvTxWfPQC4LKum83X5pe3cZS3VGIdbtS77QS66OvaPkVwaMlhFysBb8GhaajvznUpo1+E45NPPtFUxduGCIc3Mgw6TKCLvq7tbgSHlhx2sRIIIjisgMiew1G0ERXBEetwot4QePBjoUu+ru1zBIeWHHaxEvASHNwW+55zP3PwlzMqEkKgkEAMy6fa7kNwaMlhFysBZ8Fhd6AfPHjQ\/PznP082d27dutXMz8+bycnJoDfIxjAJIThidQnq3SQCMfi6lheCQ0sOu1gJeAkOe1vsu+++u36QV79zOOoAE8MkhOCoo+fJs2sEYvB1bZ8gOLTksIuVgLPgsK+8yemf27dvN7t37zZvvvmmuXr1qrlz507Po8qrhhPDJITgqLrXya+LBGLwdW2\/IDi05LCLlYCz4LANvHDhgtmxY4e5d+9eIjqmpqbMqVOnzNDQUDAGMUxCCI5gw4GCWkwgBl\/X4kdwaMlhFysBb8HRhIbGMAkhOJowUqhD7ARi8HUtYwSHlhx2sRJAcPTpOc7hiHVoU+82EEBwtKEXaQMEHhBAcCA48AUINJYAgqOxXUPFIOBNwEtw2I2j169fT\/ZuvPjii+aNN94w586dM8PDw96Faw1imIRYUtH2LnYQ+IZADL6u7S+WVLTksIuVgLPgSN\/yum3bNnP58uVks+i1a9fMzZs3g24cjWESQnDE6hLUu0kEYvB1LS8Eh5YcdrEScBYc6WPI5Q0VKzg+++wzc\/LkyaBRjhgmIQRHrC5BvZtEIAZf1\/JCcGjJYRcrAWfBIQ2UOxLkltgXXnghOX9DllQOHDiQLK\/Mzc0FYxDDJITgCDYcKKjFBGLwdS1+BIeWHHaxEvASHNLI7H0qi4uLQY81lzrEMAkhOGJ1CerdJAIx+LqWF4JDSw67WAl4C44mNDSGSQjB0YSRQh1iJxCDr2sZIzi05LCLlYCz4Oh1lXzoxscwCSE4Qo8KymsjgRh8XcsdwaElh12sBJwFhzRQ9nCMjo4GX0LJwo1hEkJwxOoS1LtJBGLwdS0vBIeWHHaxEnAWHPZ6+tXV1U1tHR8f5\/K2DBUER6wuQb2bRADB0aTeoC4QKEfAWXCUK6Zaa80kJEeUa577H72fmA098az57rH3nLNAcDijIiEECglofF2LU3uNgbY8IhxactjFSiCY4JDlmKWlJSPX26+srJixsbFNzG7fvm327t2bvHrbK2qimYQ++dG3SvURgqMUPow7RGDQvq5FjeDQksMOAm4EggiOK1eurJ9GKksyMiEtLy9vOA5dTjI9ceKE2bNnTyJG0jZDQ0MbWlNWcIh48H2+\/cSzZsuPjjqbEeFwRkXCFhFogq9rcSI4tOSwg4AbgSCCI73Z1O4FkYPCJiYmCmsp0Y6iE0zLCI4tPz7mJRzcMG5OheDQksMuZgJN8HUtPwSHlhx2EHAjULvgsHewTE9PJwIjfSfLzp07C2tZV4QDweE2MEgFAV8CTfF133rb9AgOLTnsIOBGoHbBkY1o9BMc6bdhLl26lBsFIcLh1rmkgkBIAk3xdW2bERxacthBwI2Al+DIHmtui+i1wVP7q6fX0osIDnlmZmaS\/1weu2mUCIcLLdJAwJ9AU3zdv+YPLBAcWnLYQcCNgLPgsAJg165d3gd\/adZ1e0VCiHC4dS6pIBCaQBN8XdtmBIeWHHYQcCPgJThmZ2fNwsJC7iutvYpz2bmePTpdNo0ePnzYnDlzZlN5CA63ziUVBEITaIKva9uM4NCSww4CbgScBYdkJ5PJ2tqa6ir6vHfz80SGPYdDymMPh1snkgoCTSIwaF\/XskBwaMlhBwE3As6CI\/ajzdnD4TYgSAWBJhHQRDO19UdwaMlhBwE3As6Cwy27MKk0kxCCI0zfUAoEqiSg8XVt+QgOLTnsIOBGAMHhxsk7FQd\/eSPDAAKbCCA4GBQQaA8Bb8Eh+ziOHDmyTmBxcdH7rZWy+DSTEBGOstSxh0B4Ahpf19aSCIeWHHYQcCPgJThkM5icxWHvQbH7OuQEUTmqPNSjmYQQHKF6h3IgUB0Bja9rS0dwaMlhBwE3As6CI\/tGic2+150nblXwT6WZhBAc\/pyxgMCgCWh8XVtnBIeWHHYQcCPgLDgkOyIcblATVjfWzOkbnyYGX7z+nLshKSEAgXUCCA4GAwTaQ8BLcEiz2cPh1vkIDjdOpIJALwIIDsYHBNpDwFtwNKHpmkmIJZUm9Bx1gIAfAY2v+5XwTWqWVLTksIOAGwEEhxsn71REOLyRYQCBTQQQHAwKCLSHQE\/BYd9C+fzzz83Zs2eTPRyrq6ubWt\/rttg6UGkmISIcdfQEeUKgXgIaX9fWiAiHlhx2EHAjQITDjZN3KiIc3sgwgAARDsYABFpMAMFRU+ciOGoCS7adIkCEo1PdTWNbTsBZcHAOh99IQHD48SI1BPIIIDgYFxBoD4G+gkMO9kpfGZ\/X9KmpKXPq1CkzNDQUhIxmEmIPR5CuoRAIVEpA4+vaCrCHQ0sOOwi4EegrOGw2RREOt2KqTaWZhBAc1fYBuUEgBAGNr2vrheDQksMOAm4EnAWHZJcVHXII2M2bN4NGN6QemkkIweE2IEgFgSYR0Pi6tv5awZFePtWWff3A983Tjz6kNccOAlEQcBYc9+\/fN\/Pz82ZycnLD7bAiOtbW1ri8LdPd7OGIYvxTyYYTQHA0vIOoHgQ8CDgLjrKbRuUMj6WlJTMyMmJWVlbM2NjYpmrKTbS7d+9e\/\/ulS5eM3ESbfTSTEBEOj1FBUgiUIDBoX9dWvYoIx9yOP1IV\/8xjDxHhUJHDKCYCzoLDRjimp6c3iAARCTLB2Cvr8xqfXnqRg8Py0ougOX78uDl69KgZHh42vfJFcMQ0xKhrlwg0wde1vKsQHFzUqKWPXRcIOAsOgWEvbrORBxuRWFxc3LDMkgUnAmN0dDRJY08vnZuby41eWNte6RAcXRiatDFGAk3wdS03BIeWHHYQcCPgJTgky+xrskXLHrb4bGSkaC9ItrpSzuHDh82ZM2c2Lb8gONw6l1QQCEmgKb6ubTOCQ0sOOwi4EfAWHG7ZfpMqG6lwERz90iA4fHuB9BCon0BTfF3bUgSHlhx2EHAjULvg8P3VY9PL5lJZdsl7RHDIMzMzk\/zn8rBp1IUSaSCgJ9AUX9e2AMGhJYcdBNwIeAmO7Fsktoh+t8W6ruv2i2zY8ohwuHUuqSAQmkATfF3bZgSHlhx2EHAj4Cw4bLj04MGD5uc\/\/7nZs2eP2bp1a+7ZHNmiXXauu4oNyRvB4da5pIJAaAJN8HVtmxEcWnLYQcCNgJfgmJ2dNQsLC+bdd99df+tENneePHnSnDt3LnmdtejJezc\/fbaH2OXd2ZK3KRXB4da5pILAIAgM2te1bUZwaMlhBwE3As6CI723Yvv27ckBXW+++aa5evWquXPnTs9zONyq4p4KweHOipQQiJmAxte17UVwaMlhBwE3As6Cw2Z34cIFs2PHDnPv3r1EdIS+KVbqoZmE2DTqNiBIBYEmEdD4urb+CA4tOewg4EbAW3C4ZVtvKs0khOCot0\/IHQJ1END4urYeCA4tOewg4EbAWXBwPb0bUJuKy9v8eJEaAnkEEByMCwi0h4Cz4JAmp195GyQCzSREhGOQPUbZENAR0Pi6riRjiHBoyWEHATcCzoLDvhYrl69ln37ncLhVxT2VZhJCcLjzJSUEmkJA4+vauiM4tOSwg4AbAWfB4ZZdmFSaSQjBEaZvKAUCVRLQ+Lq2fASHlhx2EHAjgOBw4+Sdij0c3sgwgMAmAggOBgUE2kOgp+Bo0kbRNHLNJESEoz2DlpZ0h4DG17V0iHBoyWEHATcC3oKjCRtHNZOQVnA8\/7e\/NB9+\/KUbzYJUX7z+XCl7jCHQVQIaX9eyQnBoyWEHATcCCI4+nNogOOSANrl4j6dbBCYmJoxcDRDzg+CIufeoOwQ2EkBwOAqOZx7bYp5+9CHV+JnbMaqyq8oo5KRdVZ3JpzyBNvR7yDYQ4Sg\/5sgBAr0IIDg8BMe1l56McjSFnLSjBNTSSreh30O2AcHRUkegWY0h0Fdw7Nu3z+SdvZFuQZvP4bBLKhLhQHA0ZtxSEQcCIb+sHaqjShKyDQgOVRdhBAFnArwWS4TDebAMIuHt27fN3r17zcGDB83OnTuTKsjfTp48ac6dO2eGh4dzq3XlyhWztrZm5ubmSlVbyrpx44b50z\/9U+98ZN+M7J+RZ2RkxKysrJiHH37YZEW8\/UzKkYsRx8bGvMvKMwj5ZV1JhXMyCdkGBEddvUi+EHhAAMGB4Gi0L1jB8cgjj5jl5eVEYLgIjioadf\/+fXP+\/Hnzk5\/8pFDYFJWTfaVcBNDbb7+93gZrJ3+XR8SU2Fy8eNG8\/PLLZmhoqHQTQn5Zl65sQQYh24DgqKsXyRcCCA6nMcCSihOm2hKJuDh8+LB5\/vnnzX\/8x38kEYu04JAv5vn5eXP9+vWkDlNTU+bUqVPm2rVrSYRj+\/bt5vLly8nfJK281i2PiAgbabARhmxkQSIU\/\/qv\/7ouBmZnZ80f\/uEfJm9+FNkUgcgTSXl\/EwGybds2I2+YlH1CflmXrWuRfcg2IDjq6kXyhQCCw2kMtFFwDP\/sPae2DypR+twSKziOHTtm3nnnHbNnz56kWnZJRaIQ8ogQSEcV\/umf\/ikRHCIsRCgsLCyYrVu3mhMnTiQC4s033zTT09PJF7sIi7Qose0WcSKCRdLYu4R27dqV2OcJF2uXJ0bylnjS+VtbqcsHH3xQeilI8gv5ZV3XWAnZBgRHXb1IvhAILDhkcl1aWnL6ZdgvZK6ZhMoe\/NWmTaMxCo4zZ84kI9buc0jv4RDRYaMc9sveCg6JiNgvdtk\/8dZbb5mf\/vSnyZ6M9GborEiQPEWciMCRyIcVHJKfCBCfPSJ5gkbyO378uDl69OiG5RoZ+1LHV155pfSyisZPqpgYB+3r2jYgOLTksIOAG4Egezhkcr5582YS1pZJXiYkux6frWbemn02jWYiRXB8so7xF7\/5rdvoGFCq9HknNsIhgkO++GXs\/MEf\/IH5x3\/8x2TT6K9\/\/etkY6Ysczz++OPr0Yy04LBRg9HRB+eh\/PCHP1xPV7RB01VwpJdm8iIcRcKkKJIRu+Bogq9rh60VHP\/720+a\/Y+8rsqGU4VV2DDqCIEggiN9HHr2l2Kas0zChw4dSsLfEj4vegsBweE3OjW8\/EqoL3VWcNjxIyWKaBXBYZdDRMzK+JG3QdKCwy61\/Od\/\/qf58z\/\/82RpRSIiEtWQiIWMuzwRnLek4hPhSG8IzRLKW06RNLEvqTTB17WjEcGhJYcdBNwI1C44bLjbrpfbf09OTq6\/5pgX5ej12qPmC5QIxzcRDreh0YxUWcEhtUq\/8SH\/tps\/JdLx1VdfJXszZLNn+rXY9C9v2TxqhYuIlF6bRu1+Ct8lFRupu3v37jpIe16NlJ9erkmTLhIimt7Q+ImmHGvTFF\/XtiG9pPLJf\/9fqmy0pxGrCsMIApERqF1wZCdqBEf4ERL6iyd8C+spscxrsZoaxf5abFN8XcNebLR7OLTlYQeBrhGoXXDU9atHOmpmZib5z+UhwhFnhMOlb+tMU+USR796VhndkLJCC82m+Ho\/zkWfIzi05LCDgBuB2gWHVMN1XddWmbdU3DrPNVXoLx7XepGuXgKD6Pcm+LqWKoJDSw47CLgRCCI4fHauS7URHG6d55pqEF88rnUjXX0EBtHvTfB1LVEEh5YcdhBwIxBEcNgoR\/Ycjuzxz0Q43DrNN9Ugvnh860j66gkMqt\/zzuEI6etakggOLTnsIOBGIJjgcKuOWyrNRMoejjj3cMgeHXtseXp0LC4uFr7l5DaK8lPZC9e0NyCX2WiafnNGamfbWPT39NHrea3R+EkZdnXYhmwDgqOOHiRPCHxDAMHRZzS08WjzGB2g3zJbVW1K70HQ5FnmLpR02fa12rNnzyZHncuhZXKkevrvcuLphQsXCm+YDfllrWHlYhOyDQgOlx4hDQT0BBAcHRQcv\/vVB\/oRE8Dy23+8fVMpWcFhQ\/Ryh8pHH32UfPHKaaR5l7jJKbd37txJTrndv3\/\/+gVwcu29nJORPg79yJEjSdlycqkchW7T2IiHfGYvcZNy0yfmpl9rlXT2cDFZSrR5ul7Kln3jwwLJ\/l24yHHvclR79gn5ZV3XsAjZBgRHXb1IvhB4QADB0UHBYZeXmuoE33vnayfBIQd+2cvU\/u3f\/i2xybvEzV4Lf+\/eveTmWREm77777nrUIH38uI0yZI8\/t2nsUea23HRF06\/QWmFgTzO1mylfffVV89prr21aJhKBkxYjRRGdPOGVdyeL1Cvkl3VdYylkGxAcdfUi+UIAweE0Btq4pNImwWGPGpfOLLrEzd7jI5\/bm2NFfMjJpNlTRq3geOqpp9ajG3agSJTjr\/7qr8yf\/dmfJVGSbLQifZR59oC7ohtp8wZh0QbLvL9n73xJ5xfyy9rJmRSJQrYBwaHoIEwg4EGACEcHIxwe46MxSfN+2UuEw37x282eeZe45QkOe2mbiARZRpmamkouFzx\/\/nwS+RDBkXe8fq+7gFwER78Ih2tkw3YMgqO6IYrgqI4lOUEgjwCCA8ERhWe4CI6iS9zyBIcsqWzfvj2JUqSjD1ZwyJJKesnGLonIkozsl8iLcOQtqdg7g1wiHEU3xfa6QbbomnuWVPyHNYLDnxkWEPAhgOBAcPiMl4Gl7Sc40q+OZi9xyxMcsiHUXvqWXlbJe1NENpamN42mIytpIOkvf7mgTTaNugqO9HJQOk+5+VbEUfbVYLvno9fR6yGXI+oaGCHbgOCoqxfJFwIPCCA4EBz4QoUEyrwWq6kGr8VqqOXbIDiqY0lOEGBJxRiz5cfHzJYfHXUeDW3cNOrceBJ6E+i1xOGdWR+DfhfLhYwOVN02m1\/INiA46upF8oUAEQ6nMYDgcMJEogYSCPllXVfzQ7YBwVFXL5IvBDosOH71lNuV9oLo9I018+HHX5pnHttirr30ZJTjRvY0yK9hnm4RkA2xstcj5gfBEXPvUXcIbCTQuT0cf\/df9pi\/+84e73EQs+DwbiwGEGgIAQRHQzqCakCgAgIIDkeICA5HUCSDQIUEEBwVwiQrCAyYQOcEx69+8D+8No2m++fpRx8acHdRPAS6RQDB0a3+prXtJtA5weH7lkq7u5\/WQaDZBBAcze4fagcBHwIIDh9apIUABIISQHAExU1hEKiVAIKjVrxkDgEIlCGA4ChDD1sINItA4wSHHC29tLS06RbPNDbNJGRvSGVJpVkDkNp0l0Bdvq4lyjkcWnLYQcCNQKMEh70gS27tXF1dNTIhLS8vm+Hh4Q2tQXC4dS6pINBUAnX6urbNCA4tOewg4EagUYIjfXFWr2vAERzFnfvXf\/3XZmbG\/WAzt2HSjlSwac64qdPXtaM1NsHBeG7OeNaOuUHYDXLcNEZw2Nsyp6enkyvD7b\/tbZvpjvlv4yNGriL3ee4efTZJ3vYlFY0Y8+EYc1rYFPdeSDZ1+7p2jH75P4+Z+x+9b4aeeNZ899h72myC2YXss2CNqqgg2DTD17O1aIzgyEY0egkOux9DMzb\/\/t+3mL+\/y3kaGnbYtJdAyGPQQ\/m6trdW\/++Qmf0\/\/1Vrjh0EGk0gpK83VnD4\/OrRCo6R4++bb\/\/x9kYPBioHgbYTCOHrWoZtj4BquWAHgSoINCbCIY1xXdf93a8+ULUdsaHChhEEKidQt69rK8wcoSWHHQT6E2iU4HDdud6\/WaSAAASaTABfb3LvUDcI1EOgUYLDRjn6ncNRDwpyhQAEQhJwOYcjZH0oCwIQqJdA4wRHvc0ldwhAAAIQgAAEBkEAwTEI6pQJAQhAAAIQ6BiBqATH7du3zd69e83du3fN\/v37zdzcXMe6q7i5NjxtUywuLpqdO3d2no+MmZMnT5pz586tn1hrX8uU02ynpqaMnGw7NDTUOVZ5bGRvxZEjR9ZZDMrP8HV83dch8fViYk3x9WgER\/rd\/fHxcTM\/P2\/yDgXzHaRtSJ99zbANbaqiDfZL65FHHlk\/Ij97vosINXm6Jl7z2AiH9NsjVfSBJg98vZgavp7PBl\/vLTbkh3p6HhyUr0cjOLIKLb3LvYu\/TtPDSybo2dlZs7CwYMbGxjRzfOtsbt26ZQ4dOpQweeedd9YjHFlWkq7ozp7WQfn\/DSpi05QvM3y9eOTh65vZ4OvF46Vpvh6N4BBwcpy5DX938YuiaFilw8+SpsvLBFlG2S+vvH8fPnzYnDlzpnNiLcsivdQkHCWSmHd5Yt1CDF\/v\/2tVlpXx9Y2c8HX3JZVB+Xo0giMb0UBwfDO40iwk2iPLTSMjI51bJshzt+wklB038jmC48H+liwLifzIF1voPS74eu9frDYih6\/3Fhz4+jd8+v3QCuXr0QgOfvW4\/65EjPV2tPQmUgTHxg216VE2KDb4Or7uTgBfd2GVt2l0EL4ejeBgXddlWD1Ik52w3S3blzJv2SC936XL4sxlEsq+4RNihODr7pTx9WLBwX6tYjb9lp7dR6BfymgEBzvXiztWQtBra2vJEkqvW3b9hkY7Ume\/vHhLpXgSyn55DeoNHnwdX9fMPvh6MbW8peX0nshQvh6N4BCUvJtfPKDS53AM6uwEzSRRtw3v5rtPQpIyfQ7HIDcf4+v4uu\/cgK8339ejEhy+A5D0EIAABCAAAQg0gwCCoxn9QC0gAAEIQAACrSaA4Gh199I4CEAAAhCAQDMIIDia0Q\/UAgIQgAAEINBqAgiOVncvjYMABCAAAQg0gwCCoxn9QC0gAAEIQAACrSaA4Gh199I4CEAAAhCAQDMIIDia0Q\/UAgIQgAAEINBqAgiOVncvjYMABCAAAQg0gwCCoxn9QC1aQiB9QqZt0iBO7Ax5R8yFCxfMjh07zNjYWNBezLZRjkS\/ePGiefnll43cpKp90kerT0xMaLPBDgIQyBBAcDAkIFARAfkC3L17t7l06ZJJf1HJsfPy2fLycnINfJseadehQ4fMyspKcMGR5Rjqiu029R9tgUBIAgiOkLQpq9UEii5Asr+Yd+3aZXbu3NkqBgiOVnUnjYFArQQQHLXiJfOuELC30I6MjCS39ro86Qv3xC4bJUh\/LvktLi5uECy9Ps9bUklfzJbNz9b\/ySefNL\/85S\/N9evXkyb0Wg7qlV+2btmoTx6f7HJUumwp61\/+5V\/MV199ldRNLijcvn27kXJkSefMmTPrdU6ztGJvdXU1tz15+f7kJz8x+\/btS\/rRRqp61U0ylnxu3rxphN9f\/uVfJmXl9anLuCANBNpKAMHR1p6lXcEJ2C\/g8fHxvssn2WWW7HJMdnnAfuGdPXs2+RLs93lWcEh6+aK2osbmd\/DgwUTEWMEhaaw4yKbJA5qNcNh87ty5s86gaKkpnV9emnQbr127Zo4cObJBdOW18e7du+bUqVPJHg4rNoSXFYFZ7rbP0mIuu4fD1s2msW2U+tuybD72pua8NMEHJAVCoGEEEBwN6xCqEzeB7K\/+vMhEVjzYFtsv2FdffdW89tpryS\/kvGiJSzQl\/WV87949s3fvXmPFii1P6vr2228nwkC+oOfn5zeV2W9fRFZwFC2x9MunaDkqr652H0w\/wZFun7XJLm\/1SiPsRTzmccn2YV4+TVpuiturqH1bCCA42tKTtKNRBNIRg2x4Pe\/LSdKkv0D\/4R\/+IflFXxQt6RdNSef161\/\/OndjZ\/pL036xTk5Oblq2SUcNspCzXxTxefcAAAJhSURBVKq92la0udRlj4tdsrARhSwvERRpUSOf5wkF+Xta3OTlm45wPP7448nySnb\/TVb0FdWvKRtqG+UcVKazBBAcne16Gh6KgP1ilz0J8qs5Lwpi65IWGDaUbz\/L7qfo9XlWcMiXbPYtmboEh+xlSAsDKw76CY70nols32gFh92Lks3PLn24Co5s3RAcobyHctpEAMHRpt6kLY0lkN2PYJcyXF+TteLCflHmRRrklVz7uWuE4\/Dhw8mGy61btyYRgTojHHmiR9oROsKRZucqOIoiHJYXEY7Guh4VaxABBEeDOoOqxEugaF+GbVE6jF+0tp\/3pdXvy7Hoc3krw37B++zhKCs4NHs4XPak+EY4ZE9K3r4RW1YvoZBeUvHZw5GN7LCHI15\/pub1EEBw1MOVXDtIIPsmiEUgYsRGEuxpnNm3JfKWN9KbRtNRgOeff37T\/oRslED7lkpZwVHlWyrp\/SCypyXvCz0dNckKjLy3VLJ7TPpFOOQNF9e3VBAcHXR6muxFAMHhhYvEEOhNILuvQlIXnWXR66yK7KZTySe9nNLvc5dzONJnY2R\/+acjM702jabrka5fvzNG8ihmz7pI72dxiXCk7W3bsudwZDfhuggOqWu2btmlLZZUmBkg0J8AgqM\/I1JAAAIQgAAEIFCSAIKjJEDMIQABCEAAAhDoTwDB0Z8RKSAAAQhAAAIQKEkAwVESIOYQgAAEIAABCPQngODoz4gUEIAABCAAAQiUJIDgKAkQcwhAAAIQgAAE+hNAcPRnRAoIQAACEIAABEoSQHCUBIg5BCAAAQhAAAL9Cfw\/eLpTRmjh30sAAAAASUVORK5CYII=","height":337,"width":540}}
%---
%[output:6431746d]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202601\\Fig3_1c_TimeToCriterion.svg\n","truncated":false}}
%---
%[output:266f7848]
%   data: {"dataType":"warning","outputData":{"text":"警告: 绘制场景时出错: Error in SceneTree: Could not find node in replaceChild"}}
%---
