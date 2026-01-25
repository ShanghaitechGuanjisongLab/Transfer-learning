%[text] `图3.1f：学习曲线（AudioWater；以会话序号为横轴，均值±SEM；两 cohort 非配对）。`
%
% AudioWater learning curve: Naive vs Transfer（与 Fig3.1b 口径一致，只是 Stimulus 改为 AudioWater）
% - Naive 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
% - Transfer 组：LightAudioBaseline(成像行为) + LAPureBehavior(纯行为，\\data-server-2\个人数据\张天夫\202601\基本迁移行为 光水转声水.v3.mat)
%
% 口径（与 Fig3.1b 一致）：
% - 每只鼠内按 DateTime 排序，将 AudioWater 的每个 DateTime 视为一个“会话”；
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
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（AudioWater 是 Naive）
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（AudioWater 是 Transfer）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（AudioWater 是 Naive）
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（AudioWater 是 Transfer）

% --- 2) Query and sessionize (one row per mouse per session)
naiveAnchors = ["Naive","Learned"];      % Naive AudioWater 轨迹锚点
tranAnchors  = ["Transfer","Final"];     % Transfer AudioWater 轨迹锚点

naiveA = iAudioWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iAudioWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));

tranA  = iAudioWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iAudioWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran,  "Transfer");

allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	warning('Fig3_1f:EmptyData', '%s', 'No AudioWater sessions found.');
	SummaryCurve = table();
	assignin('base', 'Fig3_1f_LearningCurve_AudioWater_Raw', allSessions);
	assignin('base', 'Fig3_1f_LearningCurve_AudioWater_Summary', SummaryCurve);
	return;
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

% --- 3) Build curves via UniExp.LearningSummarize
sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);

PValueLS = nan;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);

% --- 4) Plot
f = figure('Color','w', 'Name', 'Fig3.1f Learning curve (AudioWater)');
MATLAB.Graphics.FigureAspectRatio(8,5,1/3);
ax = axes(f);
hold(ax,'on');
axes(ax);

EdgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
Patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=EdgeColors(1:2,:));

nNaive = numel(unique(string(naive.Mouse)));
nTran  = numel(unique(string(tran.Mouse)));
labels = {sprintf('Naive (n=%d)', nNaive), sprintf('Transfer (n=%d)', nTran)};
if numel(Patches) >= 2
	legend(ax, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2)));
else
	legend(ax, labels, 'Location', 'best');
end

xlabel(ax, 'Session');
ylabel(ax, 'Performance (AudioWater)');
ylim(ax, [0 1]);
box(ax, 'off');
title(ax, 'Naive vs Transfer');

% --- 4b) Stats text
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
	text(ax, 0.02, 0.02, pText, 'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','bottom');
end

% --- 5) Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, 'Fig3_1f_LearningCurve_AudioWater.svg');
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

SummaryCurve = table;
SummaryCurve.Session = x(:);
SummaryCurve.NaiveMean = meanMat(:,1);
SummaryCurve.TransferMean = meanMat(:,2);
SummaryCurve.NaiveSem = semMat(:,1);
SummaryCurve.TransferSem = semMat(:,2);
SummaryCurve.NaiveN = nMat(:,1);
SummaryCurve.TransferN = nMat(:,2);
SummaryCurve.PLearningSummarize(:) = PValueLS;

assignin('base', 'Fig3_1f_LearningCurve_AudioWater_Raw', allSessions);
assignin('base', 'Fig3_1f_LearningCurve_AudioWater_Summary', SummaryCurve);

%% --- local functions
function out = iAudioWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryAudioWaterBehaviorAll(DS);
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

function T = iQueryAudioWaterBehaviorAll(DS)
	vars = ["Mouse","DateTime","Performance","Stimulus","Phase","Design"];
	T = table();
	try
		T = DS.TableQuery(vars, Stimulus="AudioWater");
	catch
		try
			T = DS.TableQuery(vars, Design="AudioWater");
		catch
			T = table();
		end
	end
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	if ismember('Stimulus', T.Properties.VariableNames)
		T.Stimulus = string(T.Stimulus);
		T = T(T.Stimulus=="AudioWater", :);
	end
	T = T(~ismissing(T.Mouse) & ~ismissing(T.DateTime), :);
end

function T = iSessionizeByDateTime(T)
	% Ensure one row per mouse per DateTime by averaging Performance within session.
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	if ~ismember('Performance', T.Properties.VariableNames)
		error('Fig3_1f:MissingPerformance', 'TableQuery result lacks Performance.');
	end
	[G, keys] = findgroups(T(:, {'Mouse','DateTime'}));
	perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
	nBlocks = splitapply(@numel, T.Performance, G);
	Tout = keys;
	Tout.Performance = perf;
	Tout.NBlocksInSession = nBlocks;

	% Preserve Phase at the session level (needed for anchor selection).
	if ismember('Phase', T.Properties.VariableNames)
		ph = string(T.Phase);
		ph = splitapply(@iPickPhase, ph, G);
		Tout.Phase = ph;
	end

	T = Tout;
end

function out = iPickPhase(ph)
	% Pick the first non-missing/non-empty phase within a (Mouse,DateTime) group.
	ph = string(ph);
	idx = find(~ismissing(ph) & strlength(ph) > 0, 1, 'first');
	if isempty(idx)
		out = missing;
	else
		out = ph(idx);
	end
end

function Tout = iSelectSessionsBetweenPhases(Tin, startPhase, endPhase)
	% Keep sessions between the first occurrence of startPhase and the last occurrence of endPhase per mouse.
	Tin = sortrows(Tin, {'Mouse','DateTime'});
	Tin.Mouse = string(Tin.Mouse);

	% Need phase info: query it again per session (robust to missing Phase field)
	if ~ismember('Phase', Tin.Properties.VariableNames)
		Tout = Tin;
		return;
	end
	Tin.Phase = string(Tin.Phase);

	mice = unique(Tin.Mouse);
	keep = false(height(Tin), 1);
	for iM = 1:numel(mice)
		m = mice(iM);
		rowsM = find(Tin.Mouse==m);
		ph = Tin.Phase(rowsM);
		kStart = find(ph==string(startPhase), 1, 'first');
		kEnd   = find(ph==string(endPhase),   1, 'last');
		if isempty(kStart) || isempty(kEnd) || kEnd < kStart
			continue;
		end
		keep(rowsM(kStart:kEnd)) = true;
	end
	Tout = Tin(keep, :);
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	T.Session = nan(height(T),1);
	groups = unique(string(T.Group));
	for gi = 1:numel(groups)
		g = groups(gi);
		idxG = string(T.Group)==g;
		mice = unique(string(T.Mouse(idxG)));
		for mi = 1:numel(mice)
			m = mice(mi);
			idx = idxG & string(T.Mouse)==m;
			T.Session(idx) = (1:nnz(idx))';
		end
	end
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	mice = unique(T.Mouse);
	msgLines = strings(0,1);
	for i = 1:numel(mice)
		m = mice(i);
		sources = unique(T.Source(T.Mouse==m));
		if numel(sources) > 1
			msgLines(end+1,1) = m + ": " + strjoin(sources, ", "); %#ok<AGROW>
		end
	end
	if ~isempty(msgLines)
		error('Fig3_1f:DuplicateMouseAcrossSources', 'Some mice appear in multiple sources within %s:\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
	end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	mice = unique(T.Mouse);
	over = strings(0,1);
	for i = 1:numel(mice)
		m = mice(i);
		gs = unique(T.Group(T.Mouse==m));
		if numel(gs) > 1
			over(end+1,1) = m + ": " + strjoin(gs, ", "); %#ok<AGROW>
		end
	end
	if ~isempty(over)
		error('Fig3_1f:MouseInMultipleGroups', 'Some mice appear in multiple groups:\n%s', char(strjoin(over, newline)));
	end
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, groupOrder)
	% Accept table or struct; return Nx2 mean/sem.
	if istable(SummaryL)
		SummaryT = SummaryL;
	else
		try
			SummaryT = struct2table(SummaryL);
		catch
			error('Fig3_1f:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
		end
	end

	try
		SummaryT = SummaryT(string(groupOrder), :);
	catch
	end
	if ~all(ismember(["MeanCurve","SemCurve"], string(SummaryT.Properties.VariableNames)))
		error('Fig3_1f:MissingLearningSummarizeFields', 'LearningSummarize output lacks MeanCurve/SemCurve.');
	end

	meanCells = SummaryT.MeanCurve;
	semCells  = SummaryT.SemCurve;
	% Convert to numeric matrices with NaN padding
	L = cellfun(@numel, meanCells);
	maxL = max(L);
	meanMat = nan(maxL, numel(groupOrder));
	semMat = nan(maxL, numel(groupOrder));
	for i = 1:numel(groupOrder)
		m = meanCells{i}(:);
		s = semCells{i}(:);
		meanMat(1:numel(m), i) = m;
		semMat(1:numel(s), i) = s;
	end
	x = (1:size(meanMat,1))';
end

function nMat = iComputeNBySession(allSessions, x, groupOrder)
	nMat = nan(numel(x), numel(groupOrder));
	for gi = 1:numel(groupOrder)
		g = string(groupOrder(gi));
		Tg = allSessions(string(allSessions.Group)==g, :);
		for si = 1:numel(x)
			nMat(si, gi) = numel(unique(string(Tg.Mouse(Tg.Session==x(si)))));
		end
	end
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
	% Match Fig3.1b behavior: use per-line column vectors with contiguous X.
	if ~isnumeric(meanMat) || ~isnumeric(semMat)
		error('Fig3_1f:InvalidCurveType', 'meanMat/semMat must be numeric matrices.');
	end
	if ~isequal(size(meanMat), size(semMat))
		error('Fig3_1f:CurveSizeMismatch', 'meanMat and semMat must have the same size.');
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

function stats = iFitMixedEffectPValue(allSessions)
	stats = struct('PGroup', nan);
	if ~exist('fitlme','file')
		return;
	end
	T = allSessions;
	T.Mouse = categorical(string(T.Mouse));
	T.Group = categorical(string(T.Group));
	try
		lme = fitlme(T, 'Performance ~ Session*Group + (1|Mouse)');
		idx = strcmp(string(lme.Coefficients.Name), 'Group_Transfer');
		if any(idx)
			stats.PGroup = lme.Coefficients.pValue(find(idx,1,'first'));
		end
	catch
	end
end

function dt = iNormalizeDateTime(dt)
	if isdatetime(dt)
		dt.TimeZone = '';
		return;
	end
	try
		dt = datetime(dt);
		dt.TimeZone = '';
	catch
		dt = datetime(dt, 'ConvertFrom','datenum');
		dt.TimeZone = '';
	end
end
