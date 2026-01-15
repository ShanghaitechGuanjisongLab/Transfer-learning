%[text] `图3.1b：学习曲线（以会话序号为横轴，均值±SEM；两 cohort 非配对）。`
%
% LightWater learning curve: Naive vs Transfer
% - Naive 组：LightAudioBaseline(成像行为) + LAPureBehavior(纯行为)
% - Transfer 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
%
% 口径：
% - 每只鼠内按 DateTime 排序，将 LightWater 的每个 DateTime 视为一个“会话”；
%   若同一 DateTime 有多个 block，则对该会话内 block 的 Performance 取均值。
% - 之后用 UniExp.LearningSummarize 对齐每鼠的会话序号，计算组均值±SEM。
% - 作图禁止 plot：使用 MATLAB.Graphics.MultiShadowedLines。

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

% --- 2) Query and sessionize (one row per mouse per session)
naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true);
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false);
tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true);
tranB  = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     false);

naive = [naiveA; naiveB];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

naive = iCollapseSameMouseSameSession(naive, "Naive");
tran  = iCollapseSameMouseSameSession(tran,  "Transfer");

allSessions = [naive; tran];
if isempty(allSessions)
	warning('Fig3_1b:EmptyData', '%s', 'No LightWater sessions found.');
	SummaryCurve = table();
	assignin('base', 'Fig3_1b_LearningCurve_Raw', allSessions);
	assignin('base', 'Fig3_1b_LearningCurve_Summary', SummaryCurve);
	return;
end

% UniExp.LearningSummarize expects a session/block table; keep basic fields.
allSessions = sortrows(allSessions, "DateTime");

% --- 3) Summarize learning curve (mean±SEM across mice per session index)
try
	Summary = UniExp.LearningSummarize(allSessions);
catch ME
	warning(ME.identifier, 'UniExp.LearningSummarize failed: %s', ME.message);
	Summary = table();
end

[meanMat, semMat, x] = iUnpackMeanSemCurves(Summary, allSessions);

% --- 4) Plot
f = figure('Color','w', 'Name', 'Fig3.1b Learning curve (LightWater)');
ax = axes(f);
hold(ax,'on');
axes(ax);

% Avoid white lines on white background
EdgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
Patches = MATLAB.Graphics.MultiShadowedLines(meanMat, semMat, X=x, EdgeColors=EdgeColors(1:2,:));

nNaive = numel(unique(string(naive.Mouse)));
nTran  = numel(unique(string(tran.Mouse)));
labels = {sprintf('Naive (n=%d)', nNaive), sprintf('Transfer (n=%d)', nTran)};
if numel(Patches) >= 2
	legend(ax, Patches(1:2), labels, 'Location', 'southeast');
else
	legend(ax, labels, 'Location', 'southeast');
end

xlabel(ax, 'Session');
ylabel(ax, 'Performance (LightWater)');
ylim(ax, [0 1]);
box(ax, 'off');
title(ax, 'Naive vs Transfer');

% Fig aspect if available
try
	MATLAB.Graphics.FigureAspectRatio(1,1,MATLAB.Flags.Narrow);
catch
end

% --- 5) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

	svgPath = fullfile(outDirUNC, 'Fig3_1b_LearningCurve.svg');
	pngPath = fullfile(outDirUNC, 'Fig3_1b_LearningCurve.png');
	csvRaw  = fullfile(outDirUNC, 'Fig3_1b_LearningCurve_Raw.csv');
	csvSum  = fullfile(outDirUNC, 'Fig3_1b_LearningCurve_Summary.csv');

try
	% Hide axes toolbar in SVG if present
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	exportgraphics(f, svgPath, 'ContentType','vector');
	exportgraphics(f, pngPath, 'Resolution', 300);
		fprintf('Wrote: %s\n', svgPath);
		fprintf('Wrote: %s\n', pngPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

iWriteTable(csvRaw, allSessions);

SummaryCurve = table;
SummaryCurve.Session = x(:);
SummaryCurve.NaiveMean = meanMat(:,1);
SummaryCurve.TransferMean = meanMat(:,2);
SummaryCurve.NaiveSem = semMat(:,1);
SummaryCurve.TransferSem = semMat(:,2);
iWriteTable(csvSum, SummaryCurve);

assignin('base', 'Fig3_1b_LearningCurve_Raw', allSessions);
assignin('base', 'Fig3_1b_LearningCurve_Summary', SummaryCurve);

%% --- local functions
function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort)
	T = iQueryLightWaterBehavior(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
		return;
	end

	T.Mouse = string(T.Mouse);
	T.DateTime = datetime(T.DateTime);

	T = iSessionizeByDateTime(T);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);

	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function T = iQueryLightWaterBehavior(DS)
	% Prefer indexed queries; keep fallbacks for older schemas.
	try
		T = DS.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");
		return;
	catch
	end
	try
		T = DS.TableQuery(["Mouse","DateTime","Performance"], Stimulus="LightWater");
		return;
	catch
	end

	msg = sprintf('TableQuery failed for LightWater (%s). Returning empty.', class(DS));
	warning('Fig3_1b:QueryFailed', '%s', msg);
	T = table();
end

function S = iSessionizeByDateTime(T)
	% Collapse blocks within the same (Mouse, DateTime) into one session.
	T = T(:, {'Mouse','DateTime','Performance'});
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Mouse','DateTime'});

	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
	nBlocks = splitapply(@(x) sum(isfinite(double(x))), T.Performance, G);

	S = table(mouseKeys, dtKeys, perf, nBlocks, ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
end

function T2 = iCollapseSameMouseSameSession(T, groupName)
	% If the same mouse accidentally appears in multiple sources within a group,
	% merge duplicated (Mouse, DateTime) by averaging performance.
	if isempty(T)
		T2 = T;
		return;
	end

	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	T = sortrows(T, {'Mouse','DateTime'});

	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	counts = splitapply(@numel, T.Performance, G);
	dupMask = counts > 1;
	if any(dupMask)
		dupMice = unique(mouseKeys(dupMask));
		fprintf('Fig3.1b: Found %d duplicated mice across sources in %s, collapsing per-session.\n', numel(dupMice), char(string(groupName)));
		fprintf('  Duplicates: %s\n', char(strjoin(dupMice, ', ')));
	end

	perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
	nBlocks = splitapply(@(x) sum(double(x), 'omitnan'), T.NBlocksInSession, G);
	imaging = splitapply(@(x) any(logical(x)), T.ImagingCohort, G);
	src = splitapply(@(x) strjoin(unique(string(x)), ','), T.Source, G);

	T2 = table(mouseKeys, dtKeys, perf, src, imaging, nBlocks, repmat(string(groupName), numel(mouseKeys), 1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Group'});
end

function [meanMat, semMat, x] = iUnpackMeanSemCurves(Summary, rawSessions)
	% Robustly unpack UniExp.LearningSummarize output.
	if istable(Summary) && all(ismember(["MeanCurve","SemCurve"], string(Summary.Properties.VariableNames)))
		meanMat = double(Summary.MeanCurve);
		semMat = double(Summary.SemCurve);
	else
		meanMat = nan(0,2);
		semMat = nan(0,2);
	end

	% Ensure 2 columns: [Naive, Transfer]
	if isempty(meanMat)
		maxN = iMaxSessionsPerMouse(rawSessions);
		meanMat = nan(maxN, 2);
		semMat = nan(maxN, 2);
	else
		if size(meanMat,2) == 1
			meanMat(:,2) = nan(size(meanMat,1),1);
			semMat(:,2) = nan(size(semMat,1),1);
		elseif size(meanMat,2) > 2
			meanMat = meanMat(:,1:2);
			semMat = semMat(:,1:2);
		end
	end

	x = (1:size(meanMat,1)).';
	if isempty(semMat)
		semMat = zeros(size(meanMat));
	end
end

function maxN = iMaxSessionsPerMouse(T)
	if isempty(T)
		maxN = 0;
		return;
	end
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Mouse','DateTime'});
	[G, ~] = findgroups(T.Mouse);
	n = splitapply(@numel, T.DateTime, G);
	maxN = max(n);
end

function iWriteTable(filePath, T)
	try
		writetable(T, filePath);
	catch ME
		msg = string(ME.message);
		if contains(lower(msg), "permission denied") || contains(lower(msg), "access")
			[p, n, e] = fileparts(filePath);
			ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
			alt = fullfile(p, [n '_' ts e]);
			try
				writetable(T, alt);
				msg = sprintf('File locked; wrote alternative: %s', alt);
				warning('Fig3_1b:Export:Retry', '%s', msg);
				return;
			catch ME2
				warning(ME2.identifier, 'Export failed (retry): %s', ME2.message);
			end
		end
		warning(ME.identifier, 'Export failed: %s', ME.message);
	end
end


%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
