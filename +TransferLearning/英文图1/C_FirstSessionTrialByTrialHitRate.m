% English Fig1C（新）：First-session trial-by-trial hit rate（💡💧 LightWater; Naive vs Transfer）
%
% 需求：
% - 首会话拆成单回合：逐 trial 计算“每只鼠”的命中率（0/1），再做鼠间均值±SEM
% - 作 Naive/Transfer 两条 MATLAB.Graphics.MultiShadowedLines
% - 统计：两条线做差异分析，并画 P 值线（此处实现为：对每鼠“首会话整体平均命中率”做 ranksum；
%   在图右侧留白用 MATLAB.Graphics.PLine 画括号，只显示“*”）
%
% 首会话口径（按约定）：沿用 Fig3.1B 的锚点区间（Naive→Learned / Transfer→Final），
% 但仅取区间内第一天（即每鼠第一次出现 startPhase 的那天）。
%
% 额外约束：若同一 DateTime 出现多个 BlockUID，直接报错（避免 trial 串接歧义）。
%
% 执行方式：
% - 保持脚本（不要改成 function）
% - 通过 matlab_remote 运行本脚本出图

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1C_FirstSessionTrialByTrialHitRate.svg";

% --- Ensure project loaded (best-effort)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

% --- Load datasets (same cohort definitions as Fig3.1B)
LAB  = TransferLearning.LightAudioBaseline();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();
LAI  = TransferLearning.LAInterspersed();

naiveAnchors = ["Naive","Learned"];      % Naive LightWater 轨迹锚点
tranAnchors  = ["Transfer","Final"];     % Transfer LightWater 轨迹锚点

naiveA = iFirstSessionTrialsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iFirstSessionTrialsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iFirstSessionTrialsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2));

tranA  = iFirstSessionTrialsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iFirstSessionTrialsByMouse(ALPB, "ALPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");

allTrials = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allTrials);

if isempty(allTrials)
	warning('English_Fig1C_TrialCurve:EmptyData', '%s', 'No LightWater first-session trials found.');
	assignin('base', 'English_Fig1C_TrialCurve_Raw', allTrials);
	return;
end

% --- Enforce: one BlockUID per mouse per selected DateTime
[Gsess, gMouse, gDT] = findgroups(string(allTrials.Mouse), allTrials.DateTime);
uBlocks = splitapply(@(x) numel(unique(double(x))), double(allTrials.BlockUID), Gsess);
bad = find(uBlocks > 1, 1, 'first');
if ~isempty(bad)
	error('English_Fig1C_TrialCurve:MultipleBlocksInSession', ...
		'Multiple blocks detected within the selected first session. Mouse=%s DateTime=%s (unique BlockUID=%d).', ...
		char(gMouse(bad)), char(string(gDT(bad))), uBlocks(bad));
end

% --- Build per-mouse trial vectors
allTrials.Mouse = string(allTrials.Mouse);
allTrials.Group = string(allTrials.Group);
allTrials = sortrows(allTrials, {'Group','Mouse','DateTime','TrialIndex'});

mice = unique(allTrials.Mouse);
maxTrial = max(double(allTrials.TrialIndex(isfinite(double(allTrials.TrialIndex)))));
if ~isfinite(maxTrial) || isempty(maxTrial)
	error('English_Fig1C_TrialCurve:InvalidTrialIndex', 'No valid TrialIndex found in first-session trials.');
end

perMouseMat = nan(maxTrial, numel(mice));
perMouseGroup = strings(numel(mice), 1);
perMouseMean = nan(numel(mice), 1);

for i = 1:numel(mice)
	m = mice(i);
	Tm = allTrials(allTrials.Mouse == m, :);
	perMouseGroup(i) = string(Tm.Group(1));

	valid = isfinite(double(Tm.Behavior)) & isfinite(double(Tm.TrialIndex));
	Tm = Tm(valid, :);
	if isempty(Tm)
		continue;
	end
	[g, ~] = findgroups(double(Tm.TrialIndex));
	meanByTrial = splitapply(@(x) mean(double(x), 'omitnan'), double(Tm.Behavior), g);
	trialIdx = splitapply(@(x) double(x(1)), double(Tm.TrialIndex), g);

	trialIdx = double(trialIdx(:));
	meanByTrial = double(meanByTrial(:));
	keep = isfinite(trialIdx) & trialIdx >= 1 & trialIdx <= maxTrial;
	trialIdx = trialIdx(keep);
	meanByTrial = meanByTrial(keep);

	perMouseMat(trialIdx, i) = meanByTrial;
	perMouseMean(i) = mean(perMouseMat(:, i), 'omitnan');
end

% --- Group summary: mean ± SEM per trial
isNaive = (perMouseGroup == "Naive");
isTran  = (perMouseGroup == "Transfer");

[meanNaive, semNaive, nNaive] = iMeanSem(perMouseMat(:, isNaive));
[meanTran,  semTran,  nTran ] = iMeanSem(perMouseMat(:, isTran));

% --- Stats (overall first-session mean per mouse)
xNaive = perMouseMean(isNaive);
xTran  = perMouseMean(isTran);
xNaive = xNaive(isfinite(xNaive));
xTran  = xTran(isfinite(xTran));

p = NaN;
if numel(xNaive) >= 2 && numel(xTran) >= 2
	p = ranksum(xNaive, xTran);
end

% --- Plot
f = figure('Color','w', 'Name', 'English Fig1C First-session trial-by-trial hit rate');
MATLAB.Graphics.FigureAspectRatio(90, 80, 1);
ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

EdgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines([meanNaive, meanTran], [semNaive, semTran]);
Patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=EdgeColors(1:2,:));

xlabel(ax, 'Trial', 'FontSize', 6);
ylabel(ax, 'Hit rate', 'FontSize', 6);
ylim(ax, [0 1]);
try
	ax.XLim = [0.5, double(maxTrial) + 2.5];
catch
end

labels = {'Naive', 'Transfer'};
try
	if numel(Patches) >= 2
		lg = legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2)));
	else
		lg = legend(ax, labels, 'Location', 'best');
	end
	lg.FontSize = 6;
	try
		lg.Title.String = '💡💧';
	catch
	end
catch
end

% --- P-line annotation (right-side bracket, asterisk only)
if isfinite(p) && p < 0.05
	try
		yTop = max([meanNaive; meanTran], [], 'omitnan');
		if ~isfinite(yTop), yTop = 1; end
		yTop = min(0.98, yTop + 0.06);
		xA = double(maxTrial) + 1;
		xB = double(maxTrial) + 2;
		S = scatter(ax, [xA xB], [yTop yTop], 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
		Descriptors = table(S, 0, 0, "*", 0, ...
			'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
		[~, pTexts] = MATLAB.Graphics.PLine(Descriptors);
		for pt = pTexts(:)'
			pt.FontSize = 6;
		end
		try, delete(S); catch, end
	catch
	end
end

% --- Export SVG
try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% --- Outputs for debugging
Summary = table((1:maxTrial).', meanNaive, semNaive, nNaive, meanTran, semTran, nTran, ...
	'VariableNames', {'Trial','NaiveMean','NaiveSem','NaiveN','TransferMean','TransferSem','TransferN'});
assignin('base', 'English_Fig1C_TrialCurve_Raw', allTrials);
assignin('base', 'English_Fig1C_TrialCurve_Summary', Summary);
assignin('base', 'English_Fig1C_TrialCurve_P', p);

%% --- local functions
function out = iFirstSessionTrialsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryLightWaterTrialsAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), false(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DateTime','BlockUID','TrialIndex','Behavior','Group','ImagingCohort','Source'});
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T.Phase = string(T.Phase);
	T = sortrows(T, {'Mouse','DateTime','TrialIndex'});

	Sess = iSessionizeTrialsToSessions(T(:, {'Mouse','DateTime','Phase','BlockUID'}));
	Sess = iSelectFirstSessionInAnchorInterval(Sess, startPhase, endPhase);
	if isempty(Sess)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), false(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DateTime','BlockUID','TrialIndex','Behavior','Group','ImagingCohort','Source'});
		return;
	end

	K = Sess(:, {'Mouse','DateTime'});
	K.Mouse = string(K.Mouse);
	K.DateTime = iNormalizeDateTime(K.DateTime);
	J = innerjoin(T, K, 'Keys', {'Mouse','DateTime'});
	J.Group = repmat("", height(J), 1);
	J.Source = repmat(string(sourceName), height(J), 1);
	J.ImagingCohort = repmat(logical(imagingCohort), height(J), 1);
	out = J(:, {'Mouse','DateTime','BlockUID','TrialIndex','Behavior','Group','ImagingCohort','Source'});
end

function out = iFirstSessionTrialsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	badMice = iFindMiceWithAudioWaterInPhase(DS, startPhase);
	T = iQueryLightWaterTrialsAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), false(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DateTime','BlockUID','TrialIndex','Behavior','Group','ImagingCohort','Source'});
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isempty(badMice)
		T = T(~ismember(T.Mouse, badMice), :);
		fprintf('English Fig1C trial-curve: LAInterspersed excluded %d mice with AudioWater mixed into %s phase.\n', numel(badMice), char(string(startPhase)));
		fprintf('  Excluded mice: %s\n', char(strjoin(string(badMice), ', ')));
	end
	out = iFirstSessionTrialsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase);
end

function T = iQueryLightWaterTrialsAll(DS)
	vars = ["Mouse","DateTime","Stimulus","Phase","Behavior","TrialIndex","BlockUID","Design","Performance"]; 
	try
		T = DS.TableQuery(vars, Stimulus="LightWater");
	catch
		T = DS.TableQuery(vars, Design="LightWater");
	end
	if isempty(T)
		return;
	end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
end

function dt = iNormalizeDateTime(dt)
	try
		dt = datetime(dt);
		if isdatetime(dt) && ~isempty(dt.TimeZone)
			dt.TimeZone = '';
		end
	catch
	end
end

function Sess = iSessionizeTrialsToSessions(T)
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T.Phase = string(T.Phase);
	T = sortrows(T, {'Mouse','DateTime'});
	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), T.Phase, G);
	blockCount = splitapply(@(x) numel(unique(double(x))), double(T.BlockUID), G);
	Sess = table(mouseKeys, dtKeys, phaseSession, blockCount, ...
		'VariableNames', {'Mouse','DateTime','Phase','NUniqueBlocks'});
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

function Sess = iSelectFirstSessionInAnchorInterval(Sess, startPhase, endPhase)
	% For each mouse: find first session where Phase==startPhase.
	% Keep only that DateTime ("interval first day").
	startPhase = string(startPhase);
	endPhase = string(endPhase); %#ok<NASGU>
	if isempty(Sess)
		return;
	end
	Sess.Mouse = string(Sess.Mouse);
	Sess.Phase = string(Sess.Phase);
	Sess = sortrows(Sess, {'Mouse','DateTime'});

	mice = unique(Sess.Mouse);
	keep = false(height(Sess),1);
	for i = 1:numel(mice)
		m = mice(i);
		idx = find(Sess.Mouse == m);
		ph = Sess.Phase(idx);
		st = find(ph == startPhase, 1, 'first');
		if isempty(st)
			continue;
		end
		keep(idx(st)) = true;
	end
	Sess = Sess(keep, :);
end

function [m, s, n] = iMeanSem(mat)
	mat = double(mat);
	n = sum(isfinite(mat), 2);
	m = nan(size(mat,1),1);
	s = nan(size(mat,1),1);
	for i = 1:size(mat,1)
		x = mat(i, :);
		x = x(isfinite(x));
		if isempty(x)
			continue;
		end
		m(i) = mean(x, 'omitnan');
		if numel(x) <= 1
			s(i) = 0;
		else
			s(i) = std(x, 'omitnan') / sqrt(numel(x));
		end
	end
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
	if ~isequal(size(meanMat), size(semMat))
		error('English_Fig1C_TrialCurve:CurveSizeMismatch', 'meanMat and semMat must have same size.');
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
			yCells{j} = double(y(1:last));
			sCells{j} = double(s(1:last));
			xCells{j} = (1:last).';
		end
	end
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
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
		error('English_Fig1C_TrialCurve:DuplicateMouseAcrossSources', ...
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
		error('English_Fig1C_TrialCurve:MouseInMultipleGroups', ...
			'Some mice appear in multiple groups (Naive/Transfer):\n%s', char(strjoin(msgLines, newline)));
	end
end
