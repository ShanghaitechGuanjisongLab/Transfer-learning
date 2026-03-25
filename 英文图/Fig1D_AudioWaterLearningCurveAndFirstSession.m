% 英文图1D：声水初始/迁移学习曲线 + 首会话条形图
%
% AudioWater learning curve: Naive vs Transfer
% - Naive 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
% - Transfer 组：LightAudioBaseline(成像行为) + LAPureBehavior(纯行为)
%
% 口径：模仿英文图1B
% - 每只鼠内按 DateTime 排序，将 AudioWater 的每个 DateTime 视为一个“会话”；
%   若同一 DateTime 有多个 block，则对该会话内 block 的 Performance 取均值。
% - 之后按每鼠会话序号对齐，计算组均值±SEM。
% - 学习曲线使用 MATLAB.Graphics.MultiShadowedLines。
% - 同一脚本额外导出首会话透明背景条形图。


if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

ALB  = TransferLearning.AudioLightBaseline();
LAB  = TransferLearning.LightAudioBaseline();
ALPB = TransferLearning.ALPureBehavior();
LAPB = TransferLearning.LAPureBehavior();

naiveAnchors = ["Naive","Learned"];
tranAnchors  = ["Transfer","Final"];

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
	error('English_Fig1D:EmptyData', 'No AudioWater sessions found.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);

PValueLS = nan;
[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');

[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);

f = figure('Color','w', 'Name', 'English Fig1D AudioWater learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
ax = axes(f);
ax.FontSize = 12;
hold(ax,'on');
axes(ax);

edgeColors = TransferLearning.FigurePalette(2);
[yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat);
patches = MATLAB.Graphics.MultiShadowedLines(yCells, sCells, X=xCells, EdgeColors=edgeColors(1:2,:));

curveP = iLearningCurvePValue(allSessions, PValueLS);
if isfinite(curveP) && numel(x) >= 2
	y1At2 = meanMat(2, 1);
	y2At2 = meanMat(2, 2);
	if isfinite(y1At2) && isfinite(y2At2)
		yMid = (y1At2 + y2At2) / 2;
		yHalfLen = abs(y1At2 - y2At2) / 4;
		plot(ax, [2 2], [yMid - yHalfLen, yMid + yHalfLen], 'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
		text(ax, 2.1, yMid, iPToStars(curveP), 'FontSize', 12, ...
			'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'HandleVisibility', 'off');
	end
end

labels = {'Naive', 'Transfer'};
if numel(patches) >= 2
	lg = legend(ax, patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(patches(1:2)));
else
	lg = legend(ax, labels, 'Location', 'best');
end
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '🔊💧';
lg.Title.FontSize = 12;

xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
ylim(ax, [0 1]);
box(ax, 'off');
grid(ax, 'off');

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
svgPath = fullfile(outDirUNC, 'English_Fig1D_AudioWater_LearningCurve.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

summaryCurve = table;
summaryCurve.Block = x(:);
summaryCurve.NaiveMean = meanMat(:,1);
summaryCurve.TransferMean = meanMat(:,2);
summaryCurve.NaiveSem = semMat(:,1);
summaryCurve.TransferSem = semMat(:,2);
summaryCurve.NaiveN = nMat(:,1);
summaryCurve.TransferN = nMat(:,2);
summaryCurve.PLearningSummarize(:) = curveP;

assignin('base', 'English_Fig1D_AudioWaterLearningCurve_Raw', allSessions);
assignin('base', 'English_Fig1D_AudioWaterLearningCurve_Summary', summaryCurve);

firstSess = allSessions(allSessions.Session == 1, :);
naiveFirst = double(firstSess.Performance(string(firstSess.Group) == "Naive"));
tranFirst  = double(firstSess.Performance(string(firstSess.Group) == "Transfer"));
naiveFirst = naiveFirst(isfinite(naiveFirst));
tranFirst  = tranFirst(isfinite(tranFirst));

if isempty(naiveFirst) || isempty(tranFirst)
	error('English_Fig1D:EmptyFirstSession', 'First-session AudioWater performance is empty for at least one group.');
end

f2 = figure('Color','none', 'Name', 'English Fig1D AudioWater first-session performance');
	f2.Units = 'centimeters';
	pos2 = f2.Position;
	pos2(3:4) = [4, 4];
	f2.Position = pos2;
	f2.InvertHardcopy = 'off';
	f2.PaperUnits = 'centimeters';
	f2.PaperSize = [4,4];
	f2.PaperPositionMode = 'auto';

tiledlayout(1,1,'TileSpacing','normal','Padding','normal');
nexttile;
dataCell = {naiveFirst, tranFirst};
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare(dataCell, false, compareGroup, 'AsteriskThreshold', 0.05);
ax2 = gca;
ax2.FontSize = 12;
ax2.Color = 'none';
ax2.XAxis.Visible = 'off';
ax2.XTick = [];
legend(ax2, 'off');

if isfield(optional2, 'MultiCompare') && ismember('PText', optional2.MultiCompare.Properties.VariableNames)
	for pt = optional2.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end

colorNaive = edgeColors(1,:);
colorTrans = edgeColors(2,:);
if numel(bars2) == 1
	bars2.FaceColor = 'flat';
	nBars = numel(bars2.YData);
	reps = ceil(nBars/2);
	bars2.CData = repmat([colorNaive; colorTrans], reps, 1);
	bars2.CData = bars2.CData(1:nBars, :);
	bars2.BarWidth = 0.5;
	bars2.LineWidth = 2;
	bars2.FaceAlpha = 1/3;
else
	if numel(bars2) >= 2
		bars2(1).FaceColor = colorNaive;
		bars2(2).FaceColor = colorTrans;
		bars2(1).LineWidth = 2;
		bars2(2).LineWidth = 2;
		bars2(1).FaceAlpha = 1/3;
		bars2(2).FaceAlpha = 1/3;
	else
		bars2.FaceColor = colorNaive;
		bars2.LineWidth = 2;
		bars2.FaceAlpha = 1/3;
	end
end
for eb = errorBars2.Object(:)'
	eb.LineWidth = 2;
end
ax2.XLim = [0.5, 2.5];
ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
grid(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end

svgPath2 = fullfile(outDirUNC, 'English_Fig1D_AudioWater_FirstSessionPerformance.svg');
TransferLearning.PrintFigure(f2, svgPath2, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath2);

nFirst = max(numel(naiveFirst), numel(tranFirst));
firstSessionTable = table(nan(nFirst,1), nan(nFirst,1), 'VariableNames', {'NaiveFirst','TransferFirst'});
firstSessionTable.NaiveFirst(1:numel(naiveFirst)) = naiveFirst(:);
firstSessionTable.TransferFirst(1:numel(tranFirst)) = tranFirst(:);
assignin('base', 'English_Fig1D_AudioWater_FirstSession', firstSessionTable);


function out = iAudioWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryAudioWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
		return;
	end

	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
end

function T = iQueryAudioWaterBehaviorAll(DS)
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus="AudioWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="AudioWater");
	end
	if isempty(T)
		return;
	end
	if ~ismember('Stimulus', T.Properties.VariableNames)
		error('English_Fig1D:MissingStimulus', 'TableQuery result lacks Stimulus for %s.', class(DS));
	end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "AudioWater", :);
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
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

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	startPhase = string(startPhase);
	endPhase = string(endPhase);
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
		error('English_Fig1D:DuplicateMouseAcrossSources', ...
			'Group %s has duplicated mice across sources.\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
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
		error('English_Fig1D:MouseInMultipleGroups', 'Some mice appear in multiple groups.\n%s', char(strjoin(msgLines, newline)));
	end
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, groupOrder)
	groupOrder = string(groupOrder);
	if ~istable(SummaryL)
		if isstruct(SummaryL)
			SummaryL = struct2table(SummaryL);
		else
			error('English_Fig1D:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
		end
	end
	if ~ismember('MeanCurve', SummaryL.Properties.VariableNames) || ~ismember('SemCurve', SummaryL.Properties.VariableNames)
		error('English_Fig1D:MissingLearningSummarizeFields', 'LearningSummarize output lacks MeanCurve/SemCurve.');
	end

	meanCurve = SummaryL.MeanCurve;
	semCurve = SummaryL.SemCurve;
	if iscell(meanCurve) && numel(meanCurve) == 1, meanCurve = meanCurve{1}; end
	if iscell(semCurve) && numel(semCurve) == 1, semCurve = semCurve{1}; end

	meanCells = meanCurve(:);
	semCells = semCurve(:);
	if ~isempty(SummaryL.Properties.RowNames)
		rn = string(SummaryL.Properties.RowNames);
	else
		rn = strings(numel(meanCells),1);
	end

	idx = nan(1, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if all(rn == "")
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

	maxLen = 0;
	for k = 1:numel(groupOrder)
		if ~isfinite(idx(k))
			continue;
		end
		mv = meanCells{idx(k)};
		sv = semCells{idx(k)};
		maxLen = max(maxLen, numel(mv));
		maxLen = max(maxLen, numel(sv));
	end
	meanMat = nan(maxLen, numel(groupOrder));
	semMat  = nan(maxLen, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if ~isfinite(idx(k))
			continue;
		end
		mv = double(meanCells{idx(k)}(:));
		sv = double(semCells{idx(k)}(:));
		meanMat(1:numel(mv), k) = mv;
		semMat(1:numel(sv), k) = sv;
	end
	x = (1:maxLen).';
end

function nMat = iComputeNBySession(T, x, groups)
	groups = string(groups);
	x = double(x(:));
	nMat = zeros(numel(x), numel(groups));
	T.Group = string(T.Group);
	T.Session = double(T.Session);
	for g = 1:numel(groups)
		rowsG = (T.Group == groups(g));
		for s = 1:numel(x)
			rowsS = rowsG & (T.Session == s) & isfinite(double(T.Performance));
			if any(rowsS)
				nMat(s,g) = numel(unique(string(T.Mouse(rowsS))));
			end
		end
	end
end

function out = iFitMixedEffectPValue(T)
	out = struct('PGroup', nan, 'PInteraction', nan);
	use = isfinite(double(T.Performance)) & isfinite(double(T.Session));
	if nnz(use) < 10
		return;
	end
	Tbl = table;
	Tbl.Performance = double(T.Performance(use));
	Tbl.Session = double(T.Session(use));
	Tbl.Group = categorical(string(T.Group(use)), ["Naive","Transfer"]);
	Tbl.Mouse = categorical(string(T.Mouse(use)));
	lme = fitlme(Tbl, 'Performance ~ Session*Group + (1|Mouse)');
	A = anova(lme);
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

function p = iLearningCurvePValue(T, pFromSummary)
	p = pFromSummary;
	if isfinite(p)
		return;
	end
	stats = iFitMixedEffectPValue(T);
	if isfinite(stats.PGroup)
		p = stats.PGroup;
	else
		p = stats.PInteraction;
	end
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
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

function stars = iPToStars(p)
	if ~isfinite(p)
		stars = 'n.s.';
	elseif p < 0.001
		stars = '***';
	elseif p < 0.01
		stars = '**';
	elseif p < 0.05
		stars = '*';
	else
		stars = 'n.s.';
	end
end