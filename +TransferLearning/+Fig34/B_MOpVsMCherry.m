% 图3.4b：非特异性 MOp 抑制对照（MOp vs mCherry）行为效应
%
% 仅比较：MOp 组 vs mCherry 组
% 4 子图：
%   1) 学习曲线（按 session index）
%   2) 正确率（首次迁移/Day0 = session 1 performance）
%   3) 学习速度（per-mouse slope，baseline-adjusted）
%   4) time-to-criterion（Kaplan–Meier 风格，含删失）
%
% 参考：\\Data-Server-2\个人数据\张天夫\202512\WTMulti.m
%   - MOp 数据库：\\Data-Server-2\个人数据\张天夫\202505\Mop-Gi运动皮层化学遗传学抑制 声水转光水.v2.mat
%   - mCherry 对照：\\Data-Server-2\个人数据\张天夫\202409\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.mat
%
% 执行方式：
% - 本文件是脚本，不能写成函数
% - 推荐用函数方式调用：TransferLearning.Fig34.Run_B_MOpVsMCherry()
%   (该 wrapper 不使用 run)

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
includePOControl = false;
requirePhaseTransfer = true;
doExport = true;
showFigure = true;

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
mopPath = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制 声水转光水.v3.mat";
mcPath  = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.v2.mat";

MOpDS = UniExp.DataSet(mopPath);
MChDS = UniExp.DataSet(mcPath);

% Optional: if you ever want to include other mCherry controls, add them here.
poCtrlPath = "\\Data-Server-2\个人数据\张天夫\202505\化学遗传抑制PO（对照）.v1.mat";

% --- 2) Query LightWater behavior blocks
Bm = iQueryLightWaterBlocks(MOpDS, requirePhaseTransfer);
Bc = iQueryLightWaterBlocks(MChDS, requirePhaseTransfer);
if height(Bm) == 0
	error('Fig3_4b:EmptyMOp', 'No LightWater behavior rows found in MOp dataset.');
end
if height(Bc) == 0
	error('Fig3_4b:EmptyMCherry', 'No LightWater behavior rows found in mCherry dataset.');
end

Bm.Group = repmat("MOp", height(Bm), 1);
Bc.Group = repmat("mCherry", height(Bc), 1);


if includePOControl
	try
		POCtrl = UniExp.DataSet(poCtrlPath);
		Bp = iQueryLightWaterBlocks(POCtrl, requirePhaseTransfer);
		if height(Bp) > 0 && ismember('Phase', Bp.Properties.VariableNames)
			Bp(string(Bp.Phase) == "Recall", :) = [];
		end
		if height(Bp) > 0
			Bp.Group = repmat("mCherry", height(Bp), 1);
		end
		B = MATLAB.DataTypes.MergeTables(Bm, Bc, Bp);
	catch
		B = MATLAB.DataTypes.MergeTables(Bm, Bc);
	end
else
	B = MATLAB.DataTypes.MergeTables(Bm, Bc);
end

if height(B) == 0
	error('Fig3_4b:EmptyBehavior', 'No LightWater behavior rows found after merging MOp and mCherry.');
end

B.Mouse = string(B.Mouse);
B.DateTime = iNormalizeDateTime(B.DateTime);
B.Group = string(B.Group);

if ismember('Design', B.Properties.VariableNames)
	assert(all(string(B.Design) == "LightWater"), 'Expected Design==LightWater after filtering.');
end
if requirePhaseTransfer
	assert(ismember('Phase', B.Properties.VariableNames), 'Phase is required but missing.');
	assert(all(string(B.Phase) == "Transfer"), 'Expected Phase==Transfer after filtering.');
end

% --- 3) Sessionize
Sess = iSessionizeByDateTime(B(:, {'Mouse','DateTime','Performance','Group'}));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);
perMouse = iPerMouseTable(Sess);

% --- 4) Summaries
statsOut = struct();

grpOrder = ["mCherry","MOp"];
[curveMean, curveSem, curveN, xSess] = iLearningCurve(Sess, grpOrder);

idxCtrl = perMouse.Group == "mCherry";
idxMOp  = perMouse.Group == "MOp";

accCtrl = perMouse.BaselinePerf(idxCtrl);
accMOp  = perMouse.BaselinePerf(idxMOp);
accP = iRanksumSafe(accCtrl, accMOp);
statsOut.AccuracyP = accP;

[perMouse, slopeP] = iAddBaselineAdjustedSlope(perMouse);
statsOut.SlopeAdjP = slopeP;

thr = 0.80;
[ttc, cens] = iTimeToCriterion(Sess, perMouse, thr);
statsOut.TTCThreshold = thr;

% --- 5) Plot (2x2)
f = figure('Color','w', 'Name', 'Fig3.4b MOp vs mCherry', 'Visible', matlab.lang.OnOffSwitchState(showFigure));
MATLAB.Graphics.FigureAspectRatio(8, 5, 1/2);
tlo = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

% 5.1 learning curve
ax1 = nexttile(tlo, 1);
hold(ax1,'on');
axes(ax1);
meanCells = cellfun(@transpose, curveMean, UniformOutput=false);
semCells  = cellfun(@transpose, curveSem,  UniformOutput=false);
hLines = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), ...
	'EdgeColors', GlobalOptimization.ColorAllocate(numel(grpOrder), [1,1,1;1,1,1]));
lgdLabels = grpOrder(:) + " n=" + string(curveN(:));
legend(ax1, hLines, lgdLabels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(hLines));
xlabel(ax1, 'Session');
ylabel(ax1, 'Hit rate');
title(ax1, 'Learning curve (LightWater)');
box(ax1,'off');

% 5.2 accuracy day0
ax2 = nexttile(tlo, 2);
hold(ax2,'on');
x1 = ones(sum(idxCtrl),1);
x2 = 2*ones(sum(idxMOp),1);
swarmchart(ax2, x1, accCtrl, 24, 'filled');
swarmchart(ax2, x2, accMOp,  24, 'filled');
ax2.XLim = [0.5 2.5];
ax2.XTick = [1 2];
ax2.XTickLabel = {sprintf('mCherry (n=%d)', sum(idxCtrl)), sprintf('MOp (n=%d)', sum(idxMOp))};
ylabel(ax2, 'Session-1 performance');
title(ax2, sprintf('Accuracy (Day0)  ranksum p=%.2g', accP));
box(ax2,'on');

% 5.3 learning speed
ax3 = nexttile(tlo, 3);
hold(ax3,'on');
slCtrl = perMouse.SlopeAdj(idxCtrl);
slMOp  = perMouse.SlopeAdj(idxMOp);
slCtrl = slCtrl(isfinite(slCtrl));
slMOp  = slMOp(isfinite(slMOp));
swarmchart(ax3, ones(size(slCtrl)), slCtrl, 24, 'filled');
swarmchart(ax3, 2*ones(size(slMOp)),  slMOp,  24, 'filled');
ax3.XLim = [0.5 2.5];
ax3.XTick = [1 2];
ax3.XTickLabel = {sprintf('mCherry (n=%d)', numel(slCtrl)), sprintf('MOp (n=%d)', numel(slMOp))};
ylabel(ax3, 'Baseline-adjusted slope');
title(ax3, sprintf('Learning speed  ranksum p=%.2g', slopeP));
box(ax3,'on');

% 5.4 time-to-criterion (KM-style)
ax4 = nexttile(tlo, 4);
hold(ax4,'on');
[sc, xc] = iKaplanMeier(ttc(idxCtrl), cens(idxCtrl));
[sm, xm] = iKaplanMeier(ttc(idxMOp),  cens(idxMOp));
stairs(ax4, [0; xc], [0; 1-sc], 'LineWidth', 1.8);
stairs(ax4, [0; xm], [0; 1-sm], 'LineWidth', 1.8);
ylim(ax4, [0 1]);
xlabel(ax4, 'Session to criterion');
ylabel(ax4, sprintf('Fraction reached (Perf \\geq %.0f%%)', 100*thr));
title(ax4, sprintf('Time-to-criterion (censored)  thr=%.0f%%', 100*thr));
legend(ax4, {sprintf('mCherry (n=%d)', sum(idxCtrl)), sprintf('MOp (n=%d)', sum(idxMOp))}, 'Location','southeast');
box(ax4,'off');

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

% --- 6) Export SVG
if doExport
	try
		if ~isfolder(outDirUNC)
			mkdir(outDirUNC);
		end
	catch
	end

	svgPath = fullfile(outDirUNC, 'Fig3_4b_MOpVsMCherry.svg');
	try
		exportgraphics(f, svgPath, 'ContentType','vector');
		fprintf('Wrote: %s\n', svgPath);
	catch ME
		warning(ME.identifier, 'Export failed: %s', ME.message);
	end
end

%% --- local functions


function B = iQueryLightWaterBlocks(DS, requirePhaseTransfer)
	vars1 = ["Mouse","DateTime","Performance","Stimulus","Design","Phase"];
	vars2 = ["Mouse","DateTime","Performance","Stimulus","Design"];
	B = table();
	% Try common query signatures
	try
		B = DS.TableQuery(vars1, Stimulus="LightWater");
	catch
		try
			B = DS.TableQuery(vars2, Stimulus="LightWater");
		catch
			try
				B = DS.TableQuery(vars2, Design="LightWater");
			catch
				B = table();
			end
		end
	end
	if isempty(B)
		return;
	end
	if ~ismember('Mouse', B.Properties.VariableNames) || ~ismember('DateTime', B.Properties.VariableNames) || ~ismember('Performance', B.Properties.VariableNames)
		error('Fig3_4b:BehaviorMissingFields', 'Behavior query lacks required fields (Mouse/DateTime/Performance).');
	end
	if ismember('Stimulus', B.Properties.VariableNames)
		stim = string(B.Stimulus);
		if any(stim == "LightWater")
			B = B(stim == "LightWater", :);
		end
	end
	if ismember('Design', B.Properties.VariableNames)
		des = string(B.Design);
		if any(des == "LightWater")
			B = B(des == "LightWater", :);
		end
	end
	if nargin >= 2
		requirePhaseTransfer = logical(requirePhaseTransfer);
		if requirePhaseTransfer && ~ismember('Phase', B.Properties.VariableNames)
			error('Fig3_4b:MissingPhase', 'Behavior table has no Phase column; cannot guarantee Phase=Transfer.');
		end
		if ismember('Phase', B.Properties.VariableNames)
			ph = string(B.Phase);
			B = B(ph == "Transfer", :);
		end
	end
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

function [meanCells, semCells, nMice, xSess] = iLearningCurve(Sess, grpOrder)
	maxSess = max(Sess.Session);
	xSess = (1:maxSess)';
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
	
	x = perMouse.SlopeAdj(perMouse.Group == "mCherry");
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
