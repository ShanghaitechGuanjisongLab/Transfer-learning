% 图3.4b：非特异性对照（hM4D(Gi) vs mCherry）
%
% 4 子图：
%   1) 学习曲线（所有 LightWater 会话，mean±SEM；MultiShadowedLines）
%   2) 迁移首会话正确率（Phase=Transfer 的首个会话）
%   3) 学习速度：每点=一个会话，ΔPerf=Perf(s)-Perf(s-1)；
%      排除 Performance==0/1 的会话及其后的会话（对每只鼠分别截断）
%   4) time-to-criterion（KM style，按 session index）
%
% 数据库：
%   - hM4D(Gi): \\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制 声水转光水.v3.mat
%   - mCherry:  \\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.v2.mat
%
% 执行方式：
% - 本文件必须保持为脚本（SCRIPT），不得包含 local functions
% - 以“函数调用”方式执行（不使用 run）：TransferLearning.Fig34.Run_B_MOpVsMCherry()

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
exportPath = fullfile(outDirUNC, 'Fig3_4b_MOpVsMCherry.svg');

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		prjFile = fullfile(pwd, 'Transferlearning.prj');
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
giPath  = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制 声水转光水.v3.mat";
mchPath = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.v2.mat";

DS_Gi  = UniExp.DataSet(giPath);
DS_mCh = UniExp.DataSet(mchPath);

% --- 2) Query LightWater behavior blocks (do NOT filter Phase here)
requirePhaseTransfer = true; % 图2需要 Phase 字段
B1 = TransferLearning.Fig34.iQueryLightWaterBlocks(DS_Gi,  requirePhaseTransfer);
B2 = TransferLearning.Fig34.iQueryLightWaterBlocks(DS_mCh, requirePhaseTransfer);
if isempty(B1) || isempty(B2)
	error('Fig3_4b:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end

B1.Group = repmat("hM4D(Gi)", height(B1), 1);
B2.Group = repmat("mCherry",  height(B2), 1);

% Normalize DateTime
B1.DateTime = TransferLearning.Fig34.iNormalizeDateTime(B1.DateTime);
B2.DateTime = TransferLearning.Fig34.iNormalizeDateTime(B2.DateTime);

% Concatenate
J = [B1; B2];
J.Mouse = string(J.Mouse);
J.Group = string(J.Group);

% --- 3) Sessionize (Mouse+DateTime) and add session index
Sess = TransferLearning.Fig34.iSessionizeByDateTime(J(:, intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable')));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.Fig34.iAddSessionIndex(Sess);

% per-mouse table
perMouse = TransferLearning.Fig34.iPerMouseTable(Sess);
perMouse = TransferLearning.Fig34.iAddFirstTransferPerf(perMouse, Sess);

% --- 4) Build panel data & stats
statsOut = struct();
grpOrder = ["mCherry", "hM4D(Gi)"];

% Panel 1 learning curve (all LightWater sessions)
maxSess = max(Sess.Session);
curveMean = cell(numel(grpOrder), 1);
curveSem  = cell(numel(grpOrder), 1);
curveN    = nan(numel(grpOrder), 1);
for k = 1:numel(grpOrder)
	g = grpOrder(k);
	Sg = Sess(Sess.Group == g, :);
	mice = unique(Sg.Mouse);
	curveN(k) = numel(mice);
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
	curveMean{k} = mean(M, 1, 'omitnan')';
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
	curveSem{k} = se(:);
end

% Panel 2 transfer first session per mouse
tr_mCh = perMouse.TransferFirstPerf(perMouse.Group == "mCherry");
tr_Gi  = perMouse.TransferFirstPerf(perMouse.Group == "hM4D(Gi)");
[pTr, ~] = TransferLearning.Fig34.iRanksumSafe(tr_mCh, tr_Gi);
statsOut.TransferFirstP = pTr;

% Panel 3 session-level delta perf
Delta = TransferLearning.Fig34.iBuildSessionDeltaTable(Sess);
d_mCh = Delta.DeltaPerf(Delta.Group == "mCherry");
d_Gi  = Delta.DeltaPerf(Delta.Group == "hM4D(Gi)");
[pDelta, ~] = TransferLearning.Fig34.iRanksumSafe(d_mCh, d_Gi);
statsOut.DeltaPerfP = pDelta;

% Panel 4 time-to-criterion
thr = 0.80;
TTC = TransferLearning.Fig34.iTimeToCriterion(Sess, thr);
statsOut.TTCThreshold = thr;

% --- 5) Plot (2x2)
f = figure('Color','w', 'Name', 'Fig3.4b hM4D(Gi) vs mCherry');
MATLAB.Graphics.FigureAspectRatio(8, 5, 1/2);
tlo = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

% 5.1 learning curve
ax1 = nexttile(tlo, 1);
hold(ax1,'on');
axes(ax1);
try, if isprop(ax1,'Toolbar'), ax1.Toolbar.Visible = 'off'; end, catch, end
meanCells = cellfun(@transpose, curveMean, UniformOutput=false);
semCells  = cellfun(@transpose, curveSem,  UniformOutput=false);
edgeColors = GlobalOptimization.ColorAllocate(numel(grpOrder), [1,1,1;1,1,1]);
hLines = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), 'EdgeColors', edgeColors);
lgdLabels = grpOrder(:) + " n=" + string(curveN(:));
legend(ax1, hLines, lgdLabels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(hLines));
xlabel(ax1, 'Session');
ylabel(ax1, 'Hit rate');
title(ax1, 'Learning curve');
box(ax1,'off');

% 5.2 transfer first session
ax2 = nexttile(tlo, 2);
hold(ax2,'on');
try, if isprop(ax2,'Toolbar'), ax2.Toolbar.Visible = 'off'; end, catch, end
tr_mCh = tr_mCh(isfinite(tr_mCh));
tr_Gi  = tr_Gi(isfinite(tr_Gi));
if ~isempty(tr_mCh)
	swarmchart(ax2, ones(numel(tr_mCh),1), tr_mCh, 24, 'filled');
end
if ~isempty(tr_Gi)
	swarmchart(ax2, 2*ones(numel(tr_Gi),1), tr_Gi, 24, 'filled');
end
ax2.XLim = [0.5 2.5];
ax2.XTick = [1 2];
ax2.XTickLabel = {sprintf('mCherry (n=%d)', numel(tr_mCh)), sprintf('hM4D(Gi) (n=%d)', numel(tr_Gi))};
ylabel(ax2, 'Perf');
title(ax2, 'First session');
% p-value line (via MATLAB.Graphics.PLine)
if isfinite(pTr) && ~isempty(tr_mCh) && ~isempty(tr_Gi)
	S = scatter(ax2, [ones(numel(tr_mCh),1); 2*ones(numel(tr_Gi),1)], [tr_mCh(:); tr_Gi(:)], ...
		1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end
	Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', pTr), 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		MATLAB.Graphics.PLine(Descriptors);
	catch
	end
	try
		delete(S);
	catch
	end
end
box(ax2,'on');

% 5.3 delta perf
ax3 = nexttile(tlo, 3);
hold(ax3,'on');
try, if isprop(ax3,'Toolbar'), ax3.Toolbar.Visible = 'off'; end, catch, end
d_mCh = d_mCh(isfinite(d_mCh));
d_Gi  = d_Gi(isfinite(d_Gi));
if ~isempty(d_mCh)
	swarmchart(ax3, ones(numel(d_mCh),1), d_mCh, 20, 'filled');
end
if ~isempty(d_Gi)
	swarmchart(ax3, 2*ones(numel(d_Gi),1), d_Gi, 20, 'filled');
end
ax3.XLim = [0.5 2.5];
ax3.XTick = [1 2];
ax3.XTickLabel = {sprintf('mCherry (n=%d)', numel(d_mCh)), sprintf('hM4D(Gi) (n=%d)', numel(d_Gi))};
ylabel(ax3, 'Learning speed (DeltaNext)', 'Interpreter','none');
title(ax3, 'Learning speed');
% p-value line (via MATLAB.Graphics.PLine)
if isfinite(pDelta) && ~isempty(d_mCh) && ~isempty(d_Gi)
	S = scatter(ax3, [ones(numel(d_mCh),1); 2*ones(numel(d_Gi),1)], [d_mCh(:); d_Gi(:)], ...
		1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end
	Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', pDelta), 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		MATLAB.Graphics.PLine(Descriptors);
	catch
	end
	try
		delete(S);
	catch
	end
end
box(ax3,'on');

% 5.4 TTC KM
ax4 = nexttile(tlo, 4);
hold(ax4,'on');
try, if isprop(ax4,'Toolbar'), ax4.Toolbar.Visible = 'off'; end, catch, end
for k = 1:numel(grpOrder)
	g = grpOrder(k);
	Tg = TTC(TTC.Group == g, :);
	if isempty(Tg)
		continue;
	end
	[xKM, yKM] = TransferLearning.Fig34.iKaplanMeier(Tg.TTC, Tg.Censored);
	if ~isempty(xKM)
		stairs(ax4, xKM, 1 - yKM, 'LineWidth', 1.5);
	end
end
xlabel(ax4, 'Session');
ylabel(ax4, 'Fraction reached');
title(ax4, sprintf('Reached criterion (%.0f%%)', thr*100));
legend(ax4, grpOrder, 'Location', 'best');
box(ax4,'off');

% --- 6) Export
try
	exportgraphics(f, exportPath, 'ContentType','vector');
catch
	try
		print(f, exportPath, '-dsvg');
	catch
	end
end

statsOut.ExportPath = exportPath;

