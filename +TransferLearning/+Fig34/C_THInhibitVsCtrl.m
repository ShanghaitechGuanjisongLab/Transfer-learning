% 图3.4c：丘脑后部抑制（THInhibit vs Control）
%
% 用户明确要求：第 2/3/4 子图为“平均钙曲线、相关性、稳定性”，参考 Fig3.2 与 Fig3.3 的口径。
%
% 数据源：
% - 抑制组：TransferLearning.THInhibit
% - 对照组：TransferLearning.AudioLightBaseline
%
% 4 子图（2×2）：
%   1) Transfer 行为表现（LightWater，one Transfer session per mouse）
%   2) 平均钙曲线（Median NTATS ZScore，Transfer，mean±SEM across mice）
%   3) 相关性：CellCorr(1s, 1.5s)（Median NTATS ZScore，Transfer，会话内跨细胞向量相关）
%   4) 稳定性：StdCells@1.5s（Median NTATS DeltaF，Transfer，会话内跨细胞 SD）
%
% 执行方式（工程约束）：
% - 本文件必须保持为脚本（SCRIPT）。
% - 不要使用 run。
% - 请用包名限定方式调用：
%     TransferLearning.Fig34.C_THInhibitVsCtrl

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% Options
nBoot = 2000; % bootstrap iterations for error bars (cell as sample)
nPerm = 2000; % permutation iterations for p value (cell as sample)

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
CtrlDS = TransferLearning.AudioLightBaseline();
THDS   = TransferLearning.THInhibit();

% --- 2) Time indices
xsSec = seconds(TransferLearning.Xs);

% Active@1s definition (Learned Audio筛选/复用率口径)：
%   value(1s) > mean(-3~0s) + 3*std(-3~0s)
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig3_4c:BadBaselineMask', 'Baseline window (-3~0s) has no samples in TransferLearning.Xs.');
end
kSigma = 3;

[dtMin03, idx03] = min(abs(xsSec - 0.3));
[dtMin1, idx1] = min(abs(xsSec - 1));
[dtMin15, idx15] = min(abs(xsSec - 1.5));
if isempty(idx03) || ~isfinite(dtMin03) || dtMin03 > 0.25
	error('Fig3_4c:No0p3sSample', 'Cannot find a sample close to 0.3s in TransferLearning.Xs.');
end
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig3_4c:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end
if isempty(idx15) || ~isfinite(dtMin15) || dtMin15 > 0.25
	error('Fig3_4c:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end

% --- 3) Transfer LightWater sessions (one per mouse)
phaseName = "Transfer";
stimName = "LightWater";
SC = iPhaseSessionsOnePerMouse(CtrlDS, phaseName, stimName);
ST = iPhaseSessionsOnePerMouse(THDS, phaseName, stimName);
SC.Group(:) = "Ctrl";
ST.Group(:) = "TH";
Sess = [SC; ST];

if isempty(Sess)
	error('Fig3_4c:EmptyTransfer', 'No Transfer LightWater sessions found in Ctrl/TH datasets.');
end

% --- 3b) Full LightWater learning curve across ALL LightWater sessions, for Panel1
Bc = iQueryLightWaterBlocks(CtrlDS);
Bt = iQueryLightWaterBlocks(THDS);
Bc.Group(:) = "Ctrl";
Bt.Group(:) = "TH";
B = MATLAB.DataTypes.MergeTables(Bc, Bt);
B.Mouse = string(B.Mouse);
B.DateTime = iNormalizeDateTime(B.DateTime);
B.Group = string(B.Group);

grpOrder = ["Ctrl","TH"];
% IMPORTANT: ensure one row per session (Mouse+DateTime). TableQuery often returns block-level rows.
SessAll = iSessionizeByDateTime(B(:, ["Mouse","DateTime","Performance","Group"]));
SessAll = sortrows(SessAll, ["Group","Mouse","DateTime"]);
SessAll = iAddSessionIndex(SessAll);

sessionForSummary = SessAll(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);

% --- 3c) ALSO include legacy PO chemogenetic inhibition behavior into TH group (Panel1 only)
% Reference: \\Data-Server-2\个人数据\张天夫\202512\WTMulti.m
poMatPath = "\\Data-Server-2\个人数据\张天夫\202505\化学遗传抑制PO.v1.mat";
try
	if exist(poMatPath, 'file')
		PO = UniExp.DataSet(poMatPath);
		POTable = PO.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater", Expression="溢出");
		if ~isempty(POTable)
			if ismember('Phase', POTable.Properties.VariableNames)
				POTable.Phase = string(POTable.Phase);
				POTable(POTable.Phase=="Recall", :) = [];
			end
			poSess = POTable(:, intersect(["Mouse","DateTime","Performance"], string(POTable.Properties.VariableNames), 'stable'));
			poSess.Mouse = string(poSess.Mouse);
			poSess.DateTime = iNormalizeDateTime(poSess.DateTime);
			poSess.Group = repmat("TH", height(poSess), 1);
			poSess = unique(poSess(:, ["Mouse","DateTime","Performance","Group"]), 'rows');
			% Merge into session-level table used by LearningSummarize
			sessionForSummary = [sessionForSummary; poSess]; %#ok<AGROW>
			sessionForSummary.Group = string(sessionForSummary.Group);
			sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
		end
	end
catch
	% Keep figure generation robust even if PO mat is unavailable.
end

PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

% --- 4) Per-session metrics (one Transfer session per mouse)
rows = table(string.empty(0,1), NaT(0,1), string.empty(0,1), ...
	nan(0,1), cell(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Group', 'NCells_ZScore','MeanCurve_ZScore', 'Reuse_1s', 'SD_MOp5_0p3', 'SD_MOp5_1p5'});

for i = 1:height(Sess)
	m = string(Sess.Mouse(i));
	dt = Sess.DateTime(i);
	grp = string(Sess.Group(i));

	if grp=="Ctrl"
		DS = CtrlDS;
	else
		DS = THDS;
	end

	% Panel2筛选：只保留 Learned(AudioWater) 阶段 1s 活跃的细胞（MOp5）
	uidLearnActive = iLearnedAudioActiveCellUIDs_At1s(DS, m, baseMask, idx1, kSigma, "MOp5");
	[meanCurve, nCellZ] = iMeanCurveZScore(DS, m, dt, "MOp5", uidLearnActive);
	% Panel3复用率：只看“首个 Transfer 会话”的复用率
	% Reuse(1s)=P(TransferLight(active@1s in THIS session) | LearnedAudio active@1s)
	% NOTE: 统一口径：Reuse 一律用 MOp2/3 层
	reuse = iReuseRate_1s_FirstTransferSession(DS, m, dt, baseMask, idx1, kSigma, "MOp2/3");
	sd03 = iStdCellsAt_DeltaF(DS, m, dt, idx03, "MOp5");
	sd15 = iStdCellsAt_DeltaF(DS, m, dt, idx15, "MOp5");

	rows = [rows; table(m, dt, grp, nCellZ, {meanCurve}, reuse, sd03, sd15, ...
		'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
end

assignin('base', 'Fig3_4c_THInhibitVsCtrl_TransferSessions', Sess);
assignin('base', 'Fig3_4c_THInhibitVsCtrl_Rows', rows);

idxCtrl = rows.Group=="Ctrl";
idxTH = rows.Group=="TH";

% Stats (session as sample, one session per mouse)
pReuse = iRanksumSafe(rows.Reuse_1s(idxCtrl), rows.Reuse_1s(idxTH));
pSD03 = iRanksumSafe(rows.SD_MOp5_0p3(idxCtrl), rows.SD_MOp5_0p3(idxTH));
pSD15 = iRanksumSafe(rows.SD_MOp5_1p5(idxCtrl), rows.SD_MOp5_1p5(idxTH));

% --- 4b) All LightWater sessions: MOp5 SD at 0.3s and 1.5s (each session as one sample)
SessLW_C = iAllLightWaterSessions(CtrlDS);
SessLW_T = iAllLightWaterSessions(THDS);
SessLW_C.Group(:) = "Ctrl";
SessLW_T.Group(:) = "TH";
SessLW = [SessLW_C; SessLW_T];

rowsLW = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Group','SD_MOp5_0p3','SD_MOp5_1p5'});
for i = 1:height(SessLW)
	grp = string(SessLW.Group(i));
	m = string(SessLW.Mouse(i));
	dt = SessLW.DateTime(i);
	if grp=="Ctrl"
		DS = CtrlDS;
	else
		DS = THDS;
	end
	sd03_all = iStdCellsAt_DeltaF(DS, m, dt, idx03, "MOp5");
	sd15_all = iStdCellsAt_DeltaF(DS, m, dt, idx15, "MOp5");
	rowsLW = [rowsLW; table(m, dt, grp, sd03_all, sd15_all, 'VariableNames', rowsLW.Properties.VariableNames)]; %#ok<AGROW>
end

idxCtrlLW = rowsLW.Group=="Ctrl";
idxTHLW = rowsLW.Group=="TH";
pSD03_LW = iRanksumSafe(rowsLW.SD_MOp5_0p3(idxCtrlLW), rowsLW.SD_MOp5_0p3(idxTHLW));
pSD15_LW = iRanksumSafe(rowsLW.SD_MOp5_1p5(idxCtrlLW), rowsLW.SD_MOp5_1p5(idxTHLW));

assignin('base', 'THInhibitVsCtrl_AllLightWaterSessions', SessLW);
assignin('base', 'THInhibitVsCtrl_MOp5_SD_AllLightWaterSessions', rowsLW);

statsOut = struct();
statsOut.P_LearningSummarize = PValueLS;
statsOut.P_Reuse_1s = pReuse;
statsOut.P_SD_MOp5_0p3 = pSD03;
statsOut.P_SD_MOp5_1p5 = pSD15;
statsOut.P_SD_MOp5_0p3_AllLightWaterSessions = pSD03_LW;
statsOut.P_SD_MOp5_1p5_AllLightWaterSessions = pSD15_LW;
statsOut.N_AllLightWaterSessions = [sum(idxCtrlLW), sum(idxTHLW)];

assignin('base', 'Fig3_4c_THInhibitVsCtrl_Stats', statsOut);

% --- 5) Plot (2x2)
f = figure('Color','w', 'Name', 'Fig3.4c THInhibit vs Ctrl');
try
	MATLAB.Graphics.FigureAspectRatio(8, 5, 1/2);
catch
end
tlo = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

% Colors
try
	cols = GlobalOptimization.ColorAllocate(2, [1,1,1;1,1,1]);
catch
	cols = lines(2);
end

% 5.1 Full LightWater learning curve (required: LearningSummarize + MultiShadowedLines)
ax1 = nexttile(tlo, 1);
hold(ax1,'on');
iHideToolbar(ax1);
SummaryPlot = SummaryL;
try
	SummaryPlot = SummaryL(grpOrder, :);
catch
end
meanCells = cellfun(@transpose, SummaryPlot.MeanCurve, UniformOutput=false);
semCells  = cellfun(@transpose, SummaryPlot.SemCurve,  UniformOutput=false);
Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=cols(1:numel(grpOrder),:));

nCtrl = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="Ctrl"))));
nTH = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="TH"))));
labels = {sprintf('Ctrl (n=%d)', nCtrl), sprintf('TH (n=%d)', nTH)};
try
	if numel(Patches) >= 2
		legend(ax1, Patches(1:2), labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches(1:2)));
	else
		legend(ax1, labels, 'Location', 'best');
	end
catch
	legend(ax1, labels, 'Location', 'best');
end

xlabel(ax1, 'Session');
ylabel(ax1, 'Performance (LightWater)');
title(ax1, 'LightWater learning curve');
grid(ax1,'on');
box(ax1,'off');

% 5.2 Mean calcium curve (ZScore)
ax2 = nexttile(tlo, 2);
hold(ax2,'on');
iHideToolbar(ax2);
[mC, sC] = iMeanSemCurves(rows.MeanCurve_ZScore(idxCtrl));
[mT, sT] = iMeanSemCurves(rows.MeanCurve_ZScore(idxTH));
iPlotMeanSem(ax2, xsSec, mC, sC, cols(1,:), 'Ctrl');
iPlotMeanSem(ax2, xsSec, mT, sT, cols(2,:), 'TH');
xlabel(ax2, 'Time (s)');
ylabel(ax2, 'Z-score');
title(ax2, 'Mean Ca trace (MOp5)');

grid(ax2,'on');
box(ax2,'off');
legend(ax2, {'Ctrl','TH'}, 'Location','best');

% 5.3 Reuse rate (per mouse)
ax3 = nexttile(tlo, 3);
hold(ax3,'on');
iHideToolbar(ax3);
iSwarm2(ax3, rows.Reuse_1s(idxCtrl), rows.Reuse_1s(idxTH), {'Ctrl','TH'}, 'Reuse(1s) (MOp2/3)', pReuse);
title(ax3, 'Reuse');
grid(ax3,'on');

% 5.4 Stability: SD across cells (DeltaF), MOp5 only (ALL LightWater sessions)
ax4 = nexttile(tlo, 4);
hold(ax4,'on');
iHideToolbar(ax4);
iSwarm2(ax4, rowsLW.SD_MOp5_1p5(idxCtrlLW), rowsLW.SD_MOp5_1p5(idxTHLW), {'Ctrl','TH'}, 'Inter-cell SD @1.5 s (MOp5)', pSD15_LW);
title(ax4, 'Stability');
grid(ax4,'on');

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
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, 'Fig3_4c_THInhibitVsCtrl.svg');
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% Script outputs: Sess, rows, statsOut

%% --- local functions
function Sess = iPhaseSessionsOnePerMouse(DS, phaseName, stimName)
	% Return table(Mouse, DateTime) for Phase + Stimulus.
	phaseName = string(phaseName);
	stimName = string(stimName);
	Sess = table(string.empty(0,1), NaT(0,1), 'VariableNames', {'Mouse','DateTime'});
	T = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Phase","Stimulus"], Phase=phaseName, Stimulus=stimName);
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Phase = string(T.Phase);
	if ismember('Stimulus', T.Properties.VariableNames)
		T.Stimulus = string(T.Stimulus);
	end
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = T(~ismissing(T.Mouse) & ~ismissing(T.DateTime), :);
	if isempty(T)
		return;
	end

	% Unique sessions then drop mixed (AudioWater present in same session)
	Sess = unique(T(:,{'Mouse','DateTime'}), 'rows');
	Sess = sortrows(Sess, ["Mouse","DateTime"]);
	Sess = iDropMixedSessions(DS, Sess);
	if isempty(Sess)
		return;
	end

	% One session per mouse: earliest session within phase
	mice = unique(Sess.Mouse);
	keep = false(height(Sess),1);
	for iM = 1:numel(mice)
		m = mice(iM);
		rowsM = find(Sess.Mouse==m);
		if isempty(rowsM)
			continue;
		end
		[~, k] = min(Sess.DateTime(rowsM));
		keep(rowsM(k)) = true;
	end
	Sess = Sess(keep, :);
end

function Sess = iAllLightWaterSessions(DS)
	% Return unique sessions (Mouse, DateTime) for ALL LightWater blocks.
	Sess = table(string.empty(0,1), NaT(0,1), 'VariableNames', {'Mouse','DateTime'});
	T = table();
	try
		T = DS.TableQuery(["Mouse","DateTime","Stimulus"], Stimulus="LightWater");
	catch
		try
			T = DS.TableQuery(["Mouse","DateTime","Design"], Design="LightWater");
		catch
			T = table();
		end
	end
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = T(~ismissing(T.Mouse) & ~ismissing(T.DateTime), :);
	if isempty(T)
		return;
	end
	Sess = unique(T(:, {'Mouse','DateTime'}), 'rows');
	Sess = sortrows(Sess, ["Mouse","DateTime"]);
	Sess = iDropMixedSessions(DS, Sess);
end

function B = iQueryLightWaterBlocks(DS)
	% Block/session-level behavior rows for LightWater.
	vars = ["Mouse","DateTime","Performance","Stimulus","Phase","Design"];
	B = table();
	try
		B = DS.TableQuery(vars, Stimulus="LightWater");
	catch
		try
			B = DS.TableQuery(vars, Design="LightWater");
		catch
			B = table();
		end
	end
	if isempty(B)
		return;
	end
	B.Mouse = string(B.Mouse);
	B.DateTime = iNormalizeDateTime(B.DateTime);
	if ismember('Stimulus', B.Properties.VariableNames)
		B.Stimulus = string(B.Stimulus);
		B = B(B.Stimulus=="LightWater", :);
	end
	% Keep ALL phases: user required using all LightWater sessions for learning curve.
	B = B(~ismissing(B.Mouse) & ~ismissing(B.DateTime), :);
end

function perf = iSessionPerformance(DS, mouse, dt, phaseName, stimName)
	perf = NaN;
	phaseName = string(phaseName);
	stimName = string(stimName);
	T = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Performance","Phase","Stimulus"], Mouse=mouse, Phase=phaseName, Stimulus=stimName);
	if isempty(T) || ~ismember('Performance', T.Properties.VariableNames)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	rows = (T.Mouse==string(mouse)) & (T.DateTime==datetime(dt));
	if ~any(rows)
		% allow within 6 hours
		try
			dd = abs(datetime(T.DateTime) - datetime(dt));
			[best, k] = min(dd);
			if ~isempty(best) && isfinite(best) && best <= hours(6)
				rows = false(height(T),1);
				rows(k) = true;
			end
		catch
		end
	end
	if ~any(rows)
		return;
	end
	perf = mean(double(T.Performance(rows)), 'omitnan');
end

function sd = iStdCellsAt_DeltaF(DS, mouse, dt, idxT, layerName)
	% SD across cells at a specific time index, using Median NTATS DeltaF.
	sd = NaN;
	layerName = string(layerName);
	q = struct('Mouse', string(mouse), 'DateTime', dt, 'Stimulus', 'LightWater');
	try
		G = DS.QueryNTATS(q, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
	catch
		% Some sessions have no imaging / empty group; treat as missing.
		return;
	end
	if isempty(G) || ~ismember("NTATS", string(G.Properties.VariableNames))
		return;
	end
	if strlength(layerName) > 0 && ismember("ZLayer", string(G.Properties.VariableNames))
		zl = string(G.ZLayer);
		G = G(zl==layerName, :);
		if isempty(G)
			return;
		end
	end
	M = iNtatsData(G.NTATS);
	if isempty(M) || idxT < 1 || idxT > size(M,2)
		return;
	end
	v = double(M(:, idxT));
	sd = std(v, 'omitnan');
end

function S = iPooledCellsCorrStats(CtrlDS, THDS, SC, ST, idx1, idx15, layerName, nBoot, nPerm)
	% Cell as sample: compare corr(Z@1s,Z@1.5s) between groups via permutation on Fisher-z.
	layerName = string(layerName);
	[rC, xC1, xC2] = iPooledCellsVectors(CtrlDS, SC, idx1, idx15, layerName);
	[rT, xT1, xT2] = iPooledCellsVectors(THDS, ST, idx1, idx15, layerName);

	S = struct();
	S.R = [rC, rT];
	S.N = [numel(xC1), numel(xT1)];
	S.SemR = [NaN, NaN];
	S.P = NaN;
	if any(S.N < 3) || ~all(isfinite(S.R))
		return;
	end

	% Bootstrap SEM of r (resample cells within group)
	B = max(50, double(nBoot));
	rBootC = nan(B,1);
	rBootT = nan(B,1);
	nC = numel(xC1);
	nT = numel(xT1);
	for b = 1:B
		ic = randi(nC, nC, 1);
		it = randi(nT, nT, 1);
		rBootC(b) = corr(xC1(ic), xC2(ic), 'Type','Pearson', 'Rows','complete');
		rBootT(b) = corr(xT1(it), xT2(it), 'Type','Pearson', 'Rows','complete');
	end
	S.SemR = [std(rBootC, 'omitnan'), std(rBootT, 'omitnan')];

	% Permutation p-value on Fisher-z difference
	zC = atanh(max(min(rC,0.999999),-0.999999));
	zT = atanh(max(min(rT,0.999999),-0.999999));
	zObs = zC - zT;
	if ~isfinite(zObs)
		return;
	end
	x1 = [xC1; xT1];
	x2 = [xC2; xT2];
	labels = [zeros(nC,1); ones(nT,1)];
	P = max(200, double(nPerm));
	dZ = nan(P,1);
	for p = 1:P
		lab = labels(randperm(numel(labels)));
		maskC = (lab==0);
		maskT = (lab==1);
		rc = corr(x1(maskC), x2(maskC), 'Type','Pearson', 'Rows','complete');
		rt = corr(x1(maskT), x2(maskT), 'Type','Pearson', 'Rows','complete');
		zc = atanh(max(min(rc,0.999999),-0.999999));
		zt = atanh(max(min(rt,0.999999),-0.999999));
		dZ(p) = zc - zt;
	end
	dZ = dZ(isfinite(dZ));
	if isempty(dZ)
		return;
	end
	S.P = mean(abs(dZ) >= abs(zObs));
end

function [r, x1, x2] = iPooledCellsVectors(DS, Sess, idx1, idx15, layerName)
	x1 = [];
	x2 = [];
	r = NaN;
	layerName = string(layerName);
	if isempty(Sess)
		return;
	end
	for i = 1:height(Sess)
		mouse = string(Sess.Mouse(i));
		dt = Sess.DateTime(i);
		q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~ismember("NTATS", string(G.Properties.VariableNames))
			continue;
		end
		if strlength(layerName) > 0 && ismember("ZLayer", string(G.Properties.VariableNames))
			zl = string(G.ZLayer);
			G = G(zl==layerName, :);
			if isempty(G)
				continue;
			end
		end
		M = iNtatsData(G.NTATS);
		if isempty(M) || idx1<1 || idx15<1 || idx1>size(M,2) || idx15>size(M,2)
			continue;
		end
		v1 = double(M(:, idx1));
		v2 = double(M(:, idx15));
		mask = isfinite(v1) & isfinite(v2);
		x1 = [x1; v1(mask)]; %#ok<AGROW>
		x2 = [x2; v2(mask)]; %#ok<AGROW>
	end
	if numel(x1) < 3
		return;
	end
	r = corr(x1, x2, 'Type','Pearson', 'Rows','complete');
end

function [XYc, XYt] = iPooledCellsForScatter(CtrlDS, THDS, SC, ST, idx1, idx15)
	[~, xC1, xC2] = iPooledCellsVectors(CtrlDS, SC, idx1, idx15);
	[~, xT1, xT2] = iPooledCellsVectors(THDS, ST, idx1, idx15);
	XYc = [xC1, xC2];
	XYt = [xT1, xT2];
	% Downsample for plotting if too many points
	maxN = 20000;
	if size(XYc,1) > maxN
		ix = randperm(size(XYc,1), maxN);
		XYc = XYc(ix,:);
	end
	if size(XYt,1) > maxN
		ix = randperm(size(XYt,1), maxN);
		XYt = XYt(ix,:);
	end
end

function [meanCurve, nCell] = iMeanCurveZScore(DS, mouse, dt, layerName, keepCellUID)
	meanCurve = []; nCell = NaN;
	if nargin < 4
		layerName = "";
	end
	if nargin < 5
		keepCellUID = uint64([]);
	end
	try
		q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
			return;
		end
		% Optional layer filter (e.g., "MOp5")
		if strlength(string(layerName)) > 0 && ismember('ZLayer', G.Properties.VariableNames)
			G.ZLayer = string(G.ZLayer);
			G = G(G.ZLayer == string(layerName), :);
			if isempty(G)
				return;
			end
		end
		% Optional CellUID filter (e.g., Learned Audio active@1s cells)
		if ~isempty(keepCellUID)
			uid = uint64(G.CellUID);
			mask = ismember(uid, uint64(keepCellUID));
			G = G(mask, :);
			if isempty(G)
				return;
			end
		end
		M = iNtatsData(G.NTATS);
		if isempty(M)
			return;
		end
		nCell = size(M,1);
		meanCurve = mean(double(M), 1, 'omitnan');
		meanCurve = meanCurve(:);
	catch
		meanCurve = []; nCell = NaN;
	end
end

function uid = iLearnedAudioActiveCellUIDs_At1s(DS, mouse, baseMask, idx1, kSigma, layerName)
	uid = uint64([]);
	try
		qL = struct('Mouse', mouse, 'Phase', 'Learned', 'Stimulus', 'AudioWater');
		GL = iQueryNTATSOrEmpty(DS, qL);
		if isempty(GL) || ~all(ismember(["CellUID","NTATS"], string(GL.Properties.VariableNames)))
			return;
		end
		% Layer filter
		if strlength(string(layerName)) > 0 && ismember('ZLayer', GL.Properties.VariableNames)
			GL.ZLayer = string(GL.ZLayer);
			GL = GL(GL.ZLayer == string(layerName), :);
			if isempty(GL)
				return;
			end
		end
		X = iNtatsData(GL.NTATS);
		if isempty(X)
			return;
		end
		act = iActiveAt1s(double(X), baseMask, idx1, kSigma);
		uid = uint64(GL.CellUID(act));
	catch
		uid = uint64([]);
	end
end

function reuse = iReuseRate_1s(DS, mouse, baseMask, idx1, kSigma, layerName)
	% Reuse(1s)=P(TransferLight active@1s | LearnedAudio active@1s)
	reuse = NaN;
	try
		qL = struct('Mouse', mouse, 'Phase', 'Learned', 'Stimulus', 'AudioWater');
		qT = struct('Mouse', mouse, 'Phase', 'Transfer', 'Stimulus', 'LightWater');
		GL = DS.QueryNTATS(qL, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		GT = DS.QueryNTATS(qT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(GL) || isempty(GT)
			return;
		end
		if ~all(ismember(["CellUID","NTATS"], string(GL.Properties.VariableNames))) || ~all(ismember(["CellUID","NTATS"], string(GT.Properties.VariableNames)))
			return;
		end

		uidL = uint64(GL.CellUID);
		uidT = uint64(GT.CellUID);
		uid = intersect(uidL, uidT);
		if isempty(uid)
			return;
		end
		[~, iL] = ismember(uid, uidL);
		[~, iT] = ismember(uid, uidT);
		XL = double(iNtatsData(GL.NTATS));
		XT = double(iNtatsData(GT.NTATS));
		XL = XL(iL, :);
		XT = XT(iT, :);

		% Layer filter via DS.Cells (QueryNTATS may not carry ZLayer)
		if strlength(string(layerName)) > 0
			C = DS.Cells;
			if isempty(C) || ~all(ismember(["CellUID","ZLayer"], string(C.Properties.VariableNames)))
				return;
			end
			C.CellUID = uint64(C.CellUID);
			[tf, loc] = ismember(uid, C.CellUID);
			zl = strings(numel(uid),1);
			zl(tf) = string(C.ZLayer(loc(tf)));
			maskZ = (zl == string(layerName));
			if ~any(maskZ)
				return;
			end
			XL = XL(maskZ, :);
			XT = XT(maskZ, :);
		end

		learnAct = iActiveAt1s(XL, baseMask, idx1, kSigma);
		tranAct  = iActiveAt1s(XT, baseMask, idx1, kSigma);
		if nnz(learnAct) < 1
			return;
		end
		reuse = mean(double(tranAct(learnAct)), 'omitnan');
	catch ME
		iAppendDebugError_("iReuseRate_1s", mouse, NaT, ME);
		reuse = NaN;
	end
end

function reuse = iReuseRate_1s_FirstTransferSession(DS, mouse, transferDT, baseMask, idx1, kSigma, layerName)
	% Reuse(1s)=P(TransferLight active@1s in the specified session | LearnedAudio active@1s)
	% Learned is pooled at phase level (per mouse). Transfer is restricted to the first Transfer session DateTime.
	reuse = NaN;
	try
		qL = struct('Mouse', mouse, 'Phase', 'Learned', 'Stimulus', 'AudioWater');
		qT = struct('Mouse', mouse, 'DateTime', transferDT, 'Stimulus', 'LightWater');
		GL = DS.QueryNTATS(qL, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		GT = DS.QueryNTATS(qT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(GL) || isempty(GT)
			return;
		end
		if ~all(ismember(["CellUID","NTATS"], string(GL.Properties.VariableNames))) || ~all(ismember(["CellUID","NTATS"], string(GT.Properties.VariableNames)))
			return;
		end
		uidL = uint64(GL.CellUID);
		uidT = uint64(GT.CellUID);
		uid = intersect(uidL, uidT);
		if isempty(uid)
			return;
		end
		[~, iL] = ismember(uid, uidL);
		[~, iT] = ismember(uid, uidT);
		XL = double(iNtatsData(GL.NTATS));
		XT = double(iNtatsData(GT.NTATS));
		XL = XL(iL, :);
		XT = XT(iT, :);

		% Layer filter via DS.Cells (QueryNTATS may not carry ZLayer)
		if strlength(string(layerName)) > 0
			C = DS.Cells;
			if isempty(C) || ~all(ismember(["CellUID","ZLayer"], string(C.Properties.VariableNames)))
				return;
			end
			C.CellUID = uint64(C.CellUID);
			[tf, loc] = ismember(uid, C.CellUID);
			zl = strings(numel(uid),1);
			zl(tf) = string(C.ZLayer(loc(tf)));
			maskZ = (zl == string(layerName));
			if ~any(maskZ)
				return;
			end
			XL = XL(maskZ, :);
			XT = XT(maskZ, :);
		end

		learnAct = iActiveAt1s(XL, baseMask, idx1, kSigma);
		tranAct  = iActiveAt1s(XT, baseMask, idx1, kSigma);
		if nnz(learnAct) < 1
			return;
		end
		reuse = mean(double(tranAct(learnAct)), 'omitnan');
	catch ME
		iAppendDebugError_("iReuseRate_1s_FirstTransferSession", mouse, transferDT, ME);
		reuse = NaN;
	end
end

function iAppendDebugError_(where, mouse, dt, ME)
	% Keep the first few errors for post-mortem debugging (avoid flooding)
	persistent ERR
	if isempty(ERR)
		ERR = table(string.empty(0,1), string.empty(0,1), NaT(0,1), string.empty(0,1), string.empty(0,1), ...
			'VariableNames', {'Where','Mouse','DateTime','Identifier','Message'});
	end
	try
		if height(ERR) >= 20
			return;
		end
		row = table(string(where), string(mouse), iNormalizeDateTime(dt), string(ME.identifier), string(ME.message), ...
			'VariableNames', ERR.Properties.VariableNames);
		ERR = [ERR; row]; %#ok<AGROW>
		assignin('base', 'Fig3_4c_Debug_ReuseErrors', ERR);
	catch
		% ignore
	end
end

function act = iActiveAt1s(X, baseMask, idx1, kSigma)
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	val1 = X(:, idx1);
	act = val1 > (baseMu + kSigma .* baseSd);
end

function zl = iCellZLayer(DS, cellUID)
	% Fallback for layer assignment when QueryNTATS doesn't carry ZLayer
	zl = strings(numel(cellUID),1);
	try
		C = DS.Cells;
		if isempty(C) || ~all(ismember({"CellUID","ZLayer"}, C.Properties.VariableNames))
			return;
		end
		uid = uint64(cellUID(:));
		Cu = C;
		Cu.CellUID = uint64(Cu.CellUID);
		[tf, loc] = ismember(uid, Cu.CellUID);
		zl(tf) = string(Cu.ZLayer(loc(tf)));
	catch
		zl = strings(numel(cellUID),1);
	end
end

function G = iQueryNTATSOrEmpty(DS, query)
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
end

function r = iCellCorr1s1p5s_ZScore(DS, mouse, dt, idx1, idx15)
	r = NaN;
	try
		q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["NTATS"], string(G.Properties.VariableNames)))
			return;
		end
		M = iNtatsData(G.NTATS);
		v1 = double(M(:, idx1));
		v2 = double(M(:, idx15));
		mask = isfinite(v1) & isfinite(v2);
		if nnz(mask) < 3 || std(v1(mask))==0 || std(v2(mask))==0
			return;
		end
		r = corr(v1(mask), v2(mask), 'Type','Pearson');
	catch
		r = NaN;
	end
end

function sd15 = iStdCells1p5_DeltaF(DS, mouse, dt, idx15)
	sd15 = NaN;
	try
		q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
		G = DS.QueryNTATS(q, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["NTATS"], string(G.Properties.VariableNames)))
			return;
		end
		M = iNtatsData(G.NTATS);
		v = double(M(:, idx15));
		sd15 = std(v, 0, 1, 'omitnan');
	catch
		sd15 = NaN;
	end
end

function [m, s] = iMeanSemCurves(curveCells)
	% curveCells: cell array of column vectors
	m = []; s = [];
	if isempty(curveCells)
		return;
	end
	curves = curveCells(:);
	curves = curves(~cellfun(@isempty, curves));
	if isempty(curves)
		return;
	end
	L = cellfun(@numel, curves);
	L0 = mode(L);
	curves = curves(L==L0);
	if isempty(curves)
		return;
	end
	A = nan(numel(curves), L0);
	for i = 1:numel(curves)
		x = double(curves{i}(:));
		if numel(x) == L0
			A(i,:) = x;
		end
	end
	m = mean(A, 1, 'omitnan');
	n = sum(isfinite(A), 1);
	s = std(A, 0, 1, 'omitnan') ./ sqrt(max(n,1));
	m = m(:);
	s = s(:);
end

function iPlotMeanSem(ax, xsSec, m, s, col, label)
	if isempty(m) || isempty(s)
		return;
	end
	x = double(xsSec(:));
	if numel(x) ~= numel(m)
		return;
	end
	X = [x; flipud(x)];
	Y = [m+s; flipud(m-s)];
	patch(ax, X, Y, col, 'FaceAlpha', 0.20, 'EdgeColor','none', 'HandleVisibility','off');
	plot(ax, x, m, 'LineWidth', 1.8, 'Color', col, 'DisplayName', label);
end

function iSwarm2(ax, xA, xB, labels, yLabel, p)
	xA = double(xA(:));
	xB = double(xB(:));
	xA = xA(isfinite(xA));
	xB = xB(isfinite(xB));

	swarmchart(ax, ones(size(xA)), xA, 24, 'filled', 'MarkerFaceAlpha', 0.75);
	swarmchart(ax, 2*ones(size(xB)), xB, 24, 'filled', 'MarkerFaceAlpha', 0.75);
	medA = median(xA,'omitnan');
	medB = median(xB,'omitnan');
	plot(ax, [0.85 1.15], [medA medA], '-', 'LineWidth', 2);
	plot(ax, [1.85 2.15], [medB medB], '-', 'LineWidth', 2);
	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('%s (n=%d)', labels{1}, numel(xA)), sprintf('%s (n=%d)', labels{2}, numel(xB))};
	ylabel(ax, yLabel);
	% p-value line (required: MATLAB.Graphics.PLine)
	try
		iPValuePLineScatter(ax, 1, 2, xA, xB, p);
	catch
	end
end

function iPValuePLineScatter(ax, x1, x2, y1, y2, p, opts)
	arguments
		ax
		x1
		x2
		y1
		y2
		p
		opts.extraOffset double = 0
	end
	if ~isfinite(p)
		return;
	end
	y1 = y1(:);
	y2 = y2(:);
	y1 = y1(isfinite(y1));
	y2 = y2(isfinite(y2));
	if isempty(y1) || isempty(y2)
		return;
	end

	% Create an invisible scatter with exactly two unique X values.
	X = [x1*ones(numel(y1),1); x2*ones(numel(y2),1)];
	Y = [y1; y2];
	S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end

	Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), opts.extraOffset, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		MATLAB.Graphics.PLine(Descriptors);
	catch
		% fallback: draw a simple bracket + text
		try
			yAll = Y(isfinite(Y));
			if isempty(yAll); return; end
			yMax = max(yAll);
			yMin = min(yAll);
			yR = max(1e-6, yMax - yMin);
			y0 = yMax + 0.12*yR;
			plot(ax, [x1 x1 x2 x2], [y0-0.01*yR y0 y0 y0-0.01*yR], 'k-', 'LineWidth', 1);
			text(ax, mean([x1 x2]), y0, sprintf('p=%.3g', p), 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Interpreter','none');
		catch
		end
	end

	try
		delete(S);
	catch
	end
end

function iHideToolbar(ax)
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end
end

function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	if ismember('DateTime', T.Properties.VariableNames)
		T.DateTime = iNormalizeDateTime(T.DateTime);
	end
end

function Sess = iDropMixedSessions(DS, Sess)
	Ta = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Stimulus"], Stimulus="AudioWater");
	if isempty(Ta) || isempty(Sess)
		return;
	end
	Ta.Mouse = string(Ta.Mouse);
	Ta.DateTime = iNormalizeDateTime(Ta.DateTime);
	badKey = unique(Ta.Mouse + "|" + string(Ta.DateTime,'yyyy-MM-dd HH:mm:ss'));
	key = string(Sess.Mouse) + "|" + string(iNormalizeDateTime(Sess.DateTime),'yyyy-MM-dd HH:mm:ss');
	Sess = Sess(~ismember(key, badKey), :);
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
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

function [perMouse, p] = iAddBaselineAdjustedSlope(perMouse, groupA, groupB)
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
	
	x = perMouse.SlopeAdj(perMouse.Group == string(groupA));
	y = perMouse.SlopeAdj(perMouse.Group == string(groupB));
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
