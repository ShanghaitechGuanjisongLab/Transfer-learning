% 图3.5a：cFos ensemble 抑制（Inhibited vs Control）行为效应
%
% 仅比较：Inhibited 组 (MOp) vs Control 组
% 4 子图：
%   1) 学习曲线（按 session index）
%   2) 正确率（首次迁移/Day0 = session 1 performance）
%   3) 学习速度（per-mouse slope，baseline-adjusted）
%   4) time-to-criterion（Kaplan–Meier 风格，含删失）
%
% 数据来源参考：\\Data-Server-2\个人数据\张天夫\202512\cFos.m
%   - cFos 数据库：\\Data-Server-2\个人数据\张天夫\202601\cFos合集.v2.mat
%   - Group 标注：ExpressedBrain；未标记 (MarkTimes==false) 视为 Control
%
% 执行方式：
% - 本文件保持为脚本（SCRIPT）入口
% - 以函数语法调用（按你的约束）：TransferLearning.Fig35.A_cFos_MOpVsControl()

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
			catch
			end
		end
	end
catch
end

% --- 1) Load cFos database
matPath = "\\Data-Server-2\个人数据\张天夫\202601\cFos合集.v2.mat";
cFosAll = UniExp.DataSet(matPath);

% --- 2) Build group table (Mouse -> Group)
S = cFosAll.Mice;
if isempty(S)
	error('Fig3_5a:EmptyMiceTable', 'cFosAll.Mice is empty.');
end

if ~ismember('Mouse', S.Properties.VariableNames)
	if ~isempty(S.Properties.RowNames)
		S.Mouse = string(S.Properties.RowNames);
	else
		error('Fig3_5a:MissingMouse', 'cFosAll.Mice has no Mouse column or RowNames.');
	end
end
S.Mouse = string(S.Mouse);

if ~ismember('ExpressedBrain', S.Properties.VariableNames)
	error('Fig3_5a:MissingExpressedBrain', 'cFosAll.Mice lacks ExpressedBrain.');
end
if ~ismember('MarkTimes', S.Properties.VariableNames)
	error('Fig3_5a:MissingMarkTimes', 'cFosAll.Mice lacks MarkTimes (needed to define Control).');
end

S.Group = string(S.ExpressedBrain);
S.Group(~logical(S.MarkTimes)) = "Control";

% remove weird labels with >1 spaces (match reference)
try
	bad = arrayfun(@(g) nnz(char(g) == ' ') > 1, S.Group);
	S = S(~bad, :);
catch
end

% only MOp vs Control
keepGroups = ismember(S.Group, ["Control","MOp"]);
S = S(keepGroups, :);

% de-duplicate mice if needed
[~, ia] = unique(S.Mouse, 'stable');
S = S(ia, :);

if isempty(S)
	error('Fig3_5a:EmptyGroups', 'No mice left after filtering to MOp vs Control.');
end

% --- 3) Query LightWater behavior and sessionize
B = iQueryLightWaterBlocks(cFosAll);
if isempty(B)
	error('Fig3_5a:EmptyBehavior', 'No LightWater behavior rows found in cFos dataset.');
end

B.Mouse = string(B.Mouse);
B.DateTime = iNormalizeDateTime(B.DateTime);

% join group labels
J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
J.Group = string(J.Group);

% --- accuracy must be restricted to Phase==Transfer sessions (earliest per mouse)
accCtrl = nan(0,1);
accMOp  = nan(0,1);
accP = nan;
accNote = "";
statsOut = struct();
if ismember('Phase', J.Properties.VariableNames)
	J.Phase = string(J.Phase);
	JT = J(J.Phase == "Transfer", :);
	if ~isempty(JT)
		SessT = iSessionizeByDateTime(JT(:, {'Mouse','DateTime','Performance','Group'}));
		SessT = sortrows(SessT, {'Group','Mouse','DateTime'});
		accT = iFirstSessionPerfPerMouse(SessT);
		accCtrl = accT.Performance(accT.Group == "Control");
		accMOp  = accT.Performance(accT.Group == "MOp");
	end
	accNote = " (Transfer only)";
else
	warning('Fig3_5a:PhaseMissing', ['Behavior table has no Phase column; cannot restrict to Phase==Transfer. ' ...
		'Falling back to each mouse''s earliest LightWater session for panel 2.']);
	Sess0 = iSessionizeByDateTime(J(:, {'Mouse','DateTime','Performance','Group'}));
	Sess0 = sortrows(Sess0, {'Group','Mouse','DateTime'});
	accT = iFirstSessionPerfPerMouse(Sess0);
	accCtrl = accT.Performance(accT.Group == "Control");
	accMOp  = accT.Performance(accT.Group == "MOp");
	accNote = " (Phase unavailable; first session)";
end

accCtrl = accCtrl(:);
accMOp  = accMOp(:);
accCtrl = accCtrl(isfinite(accCtrl));
accMOp  = accMOp(isfinite(accMOp));
accP = iRanksumSafe(accCtrl, accMOp);
statsOut.AccuracyNote = accNote;

% sessionize (Mouse+DateTime)
Sess = iSessionizeByDateTime(J(:, {'Mouse','DateTime','Performance','Group'}));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);

% per-mouse table
perMouse = iPerMouseTable(Sess);

% 4.1 learning curve (session-level; each point = one session)
% NOTE: 作为学习曲线展示，这里使用所有 LightWater 会话（不做 0/100% “天地板”排除）。
[grpOrder, grpNames] = iGroupOrder();
SessLC_All = Sess;
curveMean = cell(numel(grpOrder),1);
curveSem  = cell(numel(grpOrder),1);
curveN    = nan(numel(grpOrder),1);
try
	% Use LearningSummarize on session-level table (each row = one session)
	ST = UniExp.LearningSummarize(SessLC_All(:, {'Mouse','Performance','DateTime','Group'}));
	rn = string(ST.Properties.RowNames);
	ST = ST(ismember(rn, grpOrder), :);
	[~, ord] = ismember(grpOrder, string(ST.Properties.RowNames));
	if all(ord > 0)
		ST = ST(ord, :);
	end
	curveMean = ST.MeanCurve;
	curveSem  = ST.SemCurve;
catch ME
	warning('Fig3_5a:LearningSummarizeFailed', 'LearningSummarize failed (%s). Falling back to internal summarize.', ME.message);
	[curveMean, curveSem, curveN] = iLearningCurve(SessLC_All, grpOrder);
end

% n = # mice contributing (for legend)
for k = 1:numel(grpOrder)
	g = grpOrder(k);
	curveN(k) = numel(unique(SessLC_All.Mouse(SessLC_All.Group == g)));
end

% 4.2 day0 accuracy (Phase==Transfer, earliest Transfer session per mouse)
idxCtrl = perMouse.Group == "Control";
idxMOp  = perMouse.Group == "MOp";

statsOut.AccuracyP = accP;

% 4.3 learning speed: session-level DeltaNext (one session -> one point)
SessSpeed = iFilterSessionsForLearningCurve(Sess);
Delta = TransferLearning.Fig35.iBuildSessionDeltaNextTable(SessSpeed);
dCtrl  = Delta.DeltaPerf(Delta.Group == "Control");
dInhib = Delta.DeltaPerf(Delta.Group == "MOp");
[speedP, ~] = TransferLearning.Fig35.iRanksumSafe(dCtrl, dInhib);
statsOut.DeltaNextP = speedP;
statsOut.SpeedP = speedP;

% 4.4 time-to-criterion
thr = 0.80;
[ttc, cens] = iTimeToCriterion(Sess, perMouse, thr);
statsOut.TTCThreshold = thr;

% --- 5) Plot (1x3)
f = figure('Color','w', 'Name', 'Fig3.4a cFos Inhibited vs Control');
MATLAB.Graphics.FigureAspectRatio(3, 1, 1);
tlo = tiledlayout(f, 1, 3, 'TileSpacing','compact', 'Padding','compact');

% 5.1 learning curve
ax1 = nexttile(tlo, 1);
hold(ax1,'on');
axes(ax1);
meanCells = cellfun(@transpose, curveMean, UniformOutput=false);
semCells  = cellfun(@transpose, curveSem,  UniformOutput=false);
hLines = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), ...
	'EdgeColors', GlobalOptimization.ColorAllocate(numel(grpOrder), [1,1,1;1,1,1]));
lgdLabels = grpNames(:) + " n=" + string(curveN(:));
legend(ax1, hLines, lgdLabels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(hLines));
xlabel(ax1, 'Session');
ylabel(ax1, 'Performance');
title(ax1, 'LightWater learning curve');
box(ax1,'off');

% 5.2 accuracy day0
ax2 = nexttile(tlo, 2);
hold(ax2,'on');
TransferLearning.Fig35.iSwarm2(ax2, accCtrl, accMOp, ["Control","Inhibited"], 'Performance', accP);
title(ax2, 'First transfer session');
box(ax2,'on');

% 5.3 learning speed
ax3 = nexttile(tlo, 3);
hold(ax3,'on');
dCtrl = dCtrl(isfinite(dCtrl));
dInhib = dInhib(isfinite(dInhib));
TransferLearning.Fig35.iSwarm2(ax3, dCtrl, dInhib, ["Control","Inhibited"], 'Learning speed (DeltaNext)', speedP);
title(ax3, 'Learning speed');
box(ax3,'on');

% Hide axes toolbar overlays in SVG
try
	axAll = findall(f, 'Type', 'axes');
	for i = 1:numel(axAll)
		if isprop(axAll(i), 'Toolbar') && ~isempty(axAll(i).Toolbar)
			axAll(i).Toolbar.Visible = 'off';
		end
	end
catch
end

% Unify Fig3.5 style
try
	TransferLearning.Fig35.iApplyFig35Style(f);
catch
end

% --- 6) Export SVG
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, 'Fig3_5a_cFos_MOpVsControl.svg');
try
	drawnow;
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Exportgraphics failed: %s', ME.message);
	try
		print(f, svgPath, '-dsvg');
		fprintf('Wrote (print -dsvg): %s\n', svgPath);
	catch ME2
		warning(ME2.identifier, 'Export failed: %s', ME2.message);
	end
end

% Script outputs: Sess, perMouse, statsOut

%% --- local functions
function B = iQueryLightWaterBlocks(DS)
	varsWithPhase = ["Mouse","DateTime","Performance","Stimulus","Phase"];
	varsNoPhase   = ["Mouse","DateTime","Performance","Stimulus"];
	B = table();
	
	% Prefer Phase if the dataset supports it; otherwise fall back.
	try
		B = DS.TableQuery(varsWithPhase, Stimulus="LightWater");
	catch
		try
			B = DS.TableQuery(varsNoPhase, Stimulus="LightWater");
		catch
			try
				B = DS.TableQuery(varsNoPhase, Design="LightWater");
			catch
				try
					B = DS.TableQuery(varsNoPhase);
				catch
					B = table();
				end
			end
		end
	end
	if isempty(B)
		return;
	end
	if ~ismember('Mouse', B.Properties.VariableNames) || ~ismember('DateTime', B.Properties.VariableNames) || ~ismember('Performance', B.Properties.VariableNames)
		error('Fig3_5a:BehaviorMissingFields', 'Behavior query lacks required fields (Mouse/DateTime/Performance).');
	end
	if ismember('Stimulus', B.Properties.VariableNames)
		stim = string(B.Stimulus);
		B = B(stim == "LightWater", :);
	end
end

function out = iFirstSessionPerfPerMouse(Sess)
	% Sess: session-level table with Mouse, DateTime, Group, Performance
	mice = unique(string(Sess.Mouse));
	out = table();
	out.Mouse = mice;
	out.Group = strings(numel(mice),1);
	out.Performance = nan(numel(mice),1);
	for i = 1:numel(mice)
		m = mice(i);
		S = Sess(string(Sess.Mouse) == m, :);
		S = sortrows(S, 'DateTime');
		out.Group(i) = string(S.Group(1));
		out.Performance(i) = double(S.Performance(1));
	end
	out.Mouse = string(out.Mouse);
	out.Group = string(out.Group);
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

function Sess = iSessionizeByDateTime(T)
	% Input columns: Mouse, DateTime, Performance, Group (block-level rows)
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T.DateTime = datetime(T.DateTime);
	T.DateTime.TimeZone = '';
	[G, mouse, dt, grp] = findgroups(T.Mouse, T.DateTime, T.Group);
	perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
	nBlk = splitapply(@numel, T.Performance, G);
	Sess = table(mouse, dt, grp, perf, nBlk, 'VariableNames', {'Mouse','DateTime','Group','Performance','NBlocksInSession'});
end

function T = iAddSessionIndex(T)
	T.Session = nan(height(T),1);
	mice = unique(T.Mouse);
	for i = 1:numel(mice)
		m = mice(i);
		rows = (T.Mouse == m);
		[~, ord] = sort(T.DateTime(rows));
		idx = find(rows);
		T.Session(idx(ord)) = (1:numel(ord))';
	end
end

function perMouse = iPerMouseTable(Sess)
	mice = unique(Sess.Mouse);
	perMouse = table();
	perMouse.Mouse = mice;
	perMouse.Group = strings(numel(mice),1);
	perMouse.BaselinePerf = nan(numel(mice),1);
	perMouse.NSessions = nan(numel(mice),1);
	perMouse.Slope = nan(numel(mice),1);
	
	for i = 1:numel(mice)
		m = mice(i);
		S = Sess(Sess.Mouse == m, :);
		S = sortrows(S, 'Session');
		perMouse.Group(i) = string(S.Group(1));
		perMouse.NSessions(i) = max(S.Session);
		perMouse.BaselinePerf(i) = S.Performance(find(S.Session==1,1,'first'));
		
		ok = isfinite(S.Session) & isfinite(S.Performance);
		if nnz(ok) >= 2
			x = double(S.Session(ok));
			y = double(S.Performance(ok));
			p = polyfit(x, y, 1);
			perMouse.Slope(i) = p(1);
		end
	end
	perMouse.Mouse = string(perMouse.Mouse);
	perMouse.Group = string(perMouse.Group);
end

function [grpOrder, grpNames] = iGroupOrder()
	grpOrder = ["Control","MOp"];
	grpNames = ["Control","Inhibited"];
end

function [meanCells, semCells, nMice] = iLearningCurve(Sess, grpOrder)
	maxSess = max(Sess.Session);
	meanCells = cell(numel(grpOrder), 1);
	semCells  = cell(numel(grpOrder), 1);
	nMice = nan(numel(grpOrder), 1);
	
	for k = 1:numel(grpOrder)
		g = grpOrder(k);
		Sg = Sess(Sess.Group == g, :);
		mice = unique(Sg.Mouse);
		nMice(k) = numel(mice);
		M = nan(numel(mice), maxSess);
		for i = 1:numel(mice)
			Sm = Sg(Sg.Mouse == mice(i), :);
			for s = 1:maxSess
				row = Sm.Session == s;
				if any(row)
					M(i,s) = mean(double(Sm.Performance(row)), 'omitnan');
				end
			end
		end
		m = mean(M, 1, 'omitnan');
		se = nan(1, maxSess);
		for s = 1:maxSess
			xs = M(:,s);
			xs = xs(isfinite(xs));
			if numel(xs) >= 2
				se(s) = std(xs, 0) ./ sqrt(numel(xs));
			elseif numel(xs) == 1
				se(s) = 0;
			end
		end
		meanCells{k} = m(:);
		semCells{k}  = se(:);
	end
end

function [dCtrl, dInhib] = iSessionDeltaPerfByGroup(SessLC)
	% One session = one point, using delta from previous session.
	% For each mouse: diff(Performance) across sessions.
	dCtrl = nan(0,1);
	dInhib = nan(0,1);
	mice = unique(SessLC.Mouse);
	for i = 1:numel(mice)
		m = mice(i);
		S = SessLC(SessLC.Mouse == m, :);
		S = sortrows(S, 'Session');
		if height(S) < 2
			continue;
		end
		d = diff(double(S.Performance));
		g = string(S.Group(1));
		if g == "Control"
			dCtrl = [dCtrl; d(:)]; %#ok<AGROW>
		elseif g == "MOp"
			dInhib = [dInhib; d(:)]; %#ok<AGROW>
		end
	end
	dCtrl = dCtrl(isfinite(dCtrl));
	dInhib = dInhib(isfinite(dInhib));
end

function SessOut = iFilterSessionsForLearningCurve(SessIn)
	% Apply session-level exclusions per mouse:
	% 1) Drop perf==0
	% 2) Find first perf==1, and drop that session and all later sessions,
	%    PLUS the last step into ceiling (session immediately before the first 1)
	SessOut = SessIn;
	SessOut = SessOut(isfinite(SessOut.Performance), :);
	SessOut = SessOut(double(SessOut.Performance) > 0, :);

	mice = unique(SessOut.Mouse);
	keep = false(height(SessOut),1);
	for i = 1:numel(mice)
		m = mice(i);
		idx = find(SessOut.Mouse == m);
		S = SessOut(idx, :);
		[~, ord] = sort(double(S.Session));
		idxSorted = idx(ord);
		p = double(SessOut.Performance(idxSorted));
		k100 = find(p >= 1, 1, 'first');
		if isempty(k100)
			keep(idxSorted) = true;
		elseif k100 > 2
			% keep only strictly before the last step into ceiling
			keep(idxSorted(1:k100-2)) = true;
		end
	end
	SessOut = SessOut(keep, :);

	% Reindex Session per mouse (sequential after filtering)
	mice = unique(SessOut.Mouse);
	for i = 1:numel(mice)
		m = mice(i);
		idx = find(SessOut.Mouse == m);
		S = SessOut(idx, :);
		[~, ord] = sort(double(S.Session));
		idxSorted = idx(ord);
		SessOut.Session(idxSorted) = (1:numel(idxSorted))';
	end
end

function p = iRanksumSafe(x, y)
	x = x(isfinite(x));
	y = y(isfinite(y));
	if isempty(x) || isempty(y)
		p = nan;
		return;
	end
	try
		p = ranksum(x, y);
	catch
		p = nan;
	end
end

function [perMouse, p] = iAddBaselineAdjustedSlope(perMouse)
	perMouse.SlopeAdj = nan(height(perMouse),1);
	ok = isfinite(perMouse.Slope) & isfinite(perMouse.BaselinePerf);
	if any(ok)
		try
			if exist('robustfit','file')
				b = robustfit(double(perMouse.BaselinePerf(ok)), double(perMouse.Slope(ok)));
				perMouse.SlopeAdj(ok) = double(perMouse.Slope(ok)) - (b(1) + b(2) * double(perMouse.BaselinePerf(ok)));
			else
				mdl = fitlm(perMouse(ok,:), 'Slope ~ 1 + BaselinePerf');
				perMouse.SlopeAdj(ok) = mdl.Residuals.Raw;
			end
		catch
		end
	end
	
	x = perMouse.SlopeAdj(perMouse.Group == "Control");
	y = perMouse.SlopeAdj(perMouse.Group == "MOp");
	p = iRanksumSafe(x, y);
end

function [ttc, cens] = iTimeToCriterion(Sess, perMouse, thr)
	% First session index where Performance >= thr; censored if never reaches.
	ttc = nan(height(perMouse),1);
	cens = true(height(perMouse),1);
	for i = 1:height(perMouse)
		m = string(perMouse.Mouse(i));
		S = Sess(Sess.Mouse == m, :);
		S = sortrows(S, 'Session');
		if isempty(S)
			continue;
		end
		k = find(double(S.Performance) >= thr, 1, 'first');
		if ~isempty(k)
			ttc(i) = double(S.Session(k));
			cens(i) = false;
		else
			ttc(i) = max(double(S.Session));
			cens(i) = true;
		end
	end
end

function [S, X] = iKaplanMeier(time, cens)
	% Kaplan–Meier survival S(t) with censor indicator.
	% time: vector (>=1)
	% cens: true if censored
	time = double(time(:));
	cens = logical(cens(:));
	ok = isfinite(time) & time > 0;
	time = time(ok);
	cens = cens(ok);
	
	if isempty(time)
		S = 1;
		X = 0;
		return;
	end
	
	% event times only
	eventTimes = unique(time(~cens));
	eventTimes = sort(eventTimes);
	if isempty(eventTimes)
		S = 1;
		X = max(time);
		return;
	end
	
	S = nan(numel(eventTimes),1);
	X = eventTimes;
	prodS = 1;
	for i = 1:numel(eventTimes)
		t = eventTimes(i);
		nAtRisk = sum(time >= t);
		d = sum((time == t) & ~cens);
		if nAtRisk > 0
			prodS = prodS * (1 - d / nAtRisk);
		end
		S(i) = prodS;
	end
end
