% 图3.5d：7 天 homecage 间隔（Vacation7 vs Control）
%
% 用户明确要求：按大纲做“钙分析”，并参考 Fig3.2/3.3 的口径。
%
% 数据源：
% - 实验组：TransferLearning.Vacation7
% - 对照组：TransferLearning.AudioLightBaseline
%
% 4 子图（2×2）：
%   1) LightWater 学习曲线（所有 LightWater 会话，不限 Phase；UniExp.LearningSummarize + MultiShadowedLines）
%   2) 平均钙曲线（Median NTATS ZScore，Transfer，mean±SEM across mice）
%   3) 复用率：Reuse(1s)=P(TransferLight active@1s | LearnedAudio active@1s)（Median NTATS ZScore；每鼠第一个 Transfer 会话；不分层）
%   4) 稳定性：StdCells@1.5s（Median NTATS DeltaF；每会话一个点；仅 MOp5；与 Fig3.4c-4 图一致）
%
% 执行方式（工程约束）：
% - 本文件必须保持为脚本（SCRIPT）。
% - 不要使用 run。
% - 请用包名限定方式调用：
%     TransferLearning.Fig35.D_Vacation7VsCtrl

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

% --- 1) Load datasets
CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();

% --- 2) Time indices
xsSec = seconds(TransferLearning.Xs);
[dtMin1, idx1] = min(abs(xsSec - 1));
[dtMin15, idx15] = min(abs(xsSec - 1.5));
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig3_5d:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end

% --- 2b) Active predicate params (for Reuse@1s)
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig3_5d:BadTimeMask', 'Baseline(-3~0) has no samples in TransferLearning.Xs.');
end
kSigma = 3;
if isempty(idx15) || ~isfinite(dtMin15) || dtMin15 > 0.25
	error('Fig3_5d:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end

% --- 3) Transfer LightWater sessions (for calcium metrics: one per mouse)
phaseName = "Transfer";
stimName = "LightWater";
SC = iPhaseSessionsOnePerMouse(CtrlDS, phaseName, stimName);
SV = iPhaseSessionsOnePerMouse(V7DS, phaseName, stimName);
SC.Group(:) = "Ctrl";
SV.Group(:) = "Vacation7";
Sess = [SC; SV];

if isempty(Sess)
	error('Fig3_5d:EmptyTransfer', 'No Transfer LightWater sessions found in Ctrl/Vacation7 datasets.');
end

% --- 3b) Full LightWater learning curve across ALL LightWater sessions (Panel1)
Bc = iQueryLightWaterBlocks(CtrlDS);
Bv = iQueryLightWaterBlocks(V7DS);
Bc.Group(:) = "Ctrl";
Bv.Group(:) = "Vacation7";
B = MATLAB.DataTypes.MergeTables(Bc, Bv);
B.Mouse = string(B.Mouse);
B.DateTime = iNormalizeDateTime(B.DateTime);
B.Group = string(B.Group);

grpOrder = ["Ctrl","Vacation7"];
sessionForSummary = B(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);

PValueLS = NaN;
try
	[SummaryL, PValueLS] = UniExp.LearningSummarize(sessionForSummary);
catch
	SummaryL = UniExp.LearningSummarize(sessionForSummary);
end

% --- 4) Compute per-session metrics (one Transfer session per mouse)
nSess = height(Sess);
Mouse = strings(nSess, 1);
DateTime = NaT(nSess, 1);
Group = strings(nSess, 1);
Performance = nan(nSess, 1);
Reuse_1s = nan(nSess, 1);
StdCells1p5 = nan(nSess, 1);
NCells_Reuse = nan(nSess, 1);
NCells_ZScore = nan(nSess, 1);
MeanCurve_ZScore = cell(nSess, 1);

for i = 1:nSess
	m = string(Sess.Mouse(i));
	dt = Sess.DateTime(i);
	grp = string(Sess.Group(i));

	Mouse(i) = m;
	DateTime(i) = dt;
	Group(i) = grp;

	if grp=="Ctrl"
		Performance(i) = iSessionPerformance(CtrlDS, m, dt, phaseName, stimName);
		DS = CtrlDS;
	else
		Performance(i) = iSessionPerformance(V7DS, m, dt, phaseName, stimName);
		DS = V7DS;
	end

	% Query Learned(AudioWater) once, reuse for both Reuse@1s and curve filtering.
	[learnedCell, keepUID] = iLearnedAudioCellTable_1s(DS, m, idx1, baseMask, kSigma);
	[Reuse_1s(i), NCells_Reuse(i)] = iReuse1s_LearnedAudio_to_TransferLight(DS, m, dt, idx1, baseMask, kSigma, "MOp2/3", learnedCell);
	[MeanCurve_ZScore{i}, NCells_ZScore(i)] = iMeanCurveZScore(DS, m, dt, keepUID);
	StdCells1p5(i) = iStdCells1p5_DeltaF(DS, m, dt, idx15, "MOp5");
end

rows = table(Mouse, DateTime, Group, Performance, Reuse_1s, StdCells1p5, NCells_Reuse, NCells_ZScore, MeanCurve_ZScore, ...
	'VariableNames', {'Mouse','DateTime','Group', 'Performance','Reuse_1s','StdCells1p5','NCells_Reuse','NCells_ZScore','MeanCurve_ZScore'});

assignin('base', 'Fig3_5d_Vacation7VsCtrl_TransferSessions', Sess);
assignin('base', 'Fig3_5d_Vacation7VsCtrl_Rows', rows);

idxCtrl = rows.Group=="Ctrl";
idxV7 = rows.Group=="Vacation7";

% Stats (per-mouse, one-session calcium metrics)
pReuse = iRanksumSafe(rows.Reuse_1s(idxCtrl), rows.Reuse_1s(idxV7));
pSD   = iRanksumSafe(rows.StdCells1p5(idxCtrl), rows.StdCells1p5(idxV7));

% --- 4b) Stability (ALL LightWater sessions): each session as one sample (match Fig3.4c)
SessLW_C = iAllLightWaterSessions(CtrlDS);
SessLW_V = iAllLightWaterSessions(V7DS);
SessLW_C.Group(:) = "Ctrl";
SessLW_V.Group(:) = "Vacation7";
SessLW = [SessLW_C; SessLW_V];

nLW = height(SessLW);
MouseLW = strings(nLW, 1);
DateTimeLW = NaT(nLW, 1);
GroupLW = strings(nLW, 1);
StdCells1p5LW = nan(nLW, 1);
for i = 1:nLW
	grp = string(SessLW.Group(i));
	m = string(SessLW.Mouse(i));
	dt = SessLW.DateTime(i);
	MouseLW(i) = m;
	DateTimeLW(i) = dt;
	GroupLW(i) = grp;
	if grp=="Ctrl"
		DS = CtrlDS;
	else
		DS = V7DS;
	end
	StdCells1p5LW(i) = iStdCells1p5_DeltaF(DS, m, dt, idx15, "MOp5");
end
rowsLW = table(MouseLW, DateTimeLW, GroupLW, StdCells1p5LW, 'VariableNames', {'Mouse','DateTime','Group','StdCells1p5'});

idxCtrlLW = rowsLW.Group=="Ctrl";
idxV7LW = rowsLW.Group=="Vacation7";
pSD_LW = iRanksumSafe(rowsLW.StdCells1p5(idxCtrlLW), rowsLW.StdCells1p5(idxV7LW));

assignin('base', 'Vacation7VsCtrl_AllLightWaterSessions', SessLW);
assignin('base', 'Vacation7VsCtrl_MOp5_SD_AllLightWaterSessions', rowsLW);

statsOut = struct();
statsOut.P_Reuse_1s = pReuse;
statsOut.P_StdCells1p5 = pSD;
statsOut.P_StdCells1p5_AllLightWaterSessions = pSD_LW;
statsOut.N_AllLightWaterSessions = [sum(idxCtrlLW), sum(idxV7LW)];

% --- 4c) Behavior-only panels (match Fig3.5a/b): first transfer session + learning speed
pPerf = iRanksumSafe(rows.Performance(idxCtrl), rows.Performance(idxV7));

dCtrl = nan(0,1);
dV7 = nan(0,1);
pDelta = nan;
try
	SessAll = TransferLearning.Fig35.iSessionizeByDateTime(B(:, intersect(B.Properties.VariableNames, {'Mouse','DateTime','Performance','Group'}, 'stable')));
	SessAll = sortrows(SessAll, {'Group','Mouse','DateTime'});
	SessAll = TransferLearning.Fig35.iAddSessionIndex(SessAll);
	Delta = TransferLearning.Fig35.iBuildSessionDeltaTable(SessAll);
	dCtrl = Delta.DeltaPerf(string(Delta.Group) == "Ctrl");
	dV7   = Delta.DeltaPerf(string(Delta.Group) == "Vacation7");
	pDelta = TransferLearning.Fig35.iRanksumSafe(dCtrl, dV7);
catch
end
%% 

% --- 5) Plot (1x3, behavior only)
f = figure('Color','w', 'Name', 'Fig3.5d Vacation7 vs Ctrl');
try
	MATLAB.Graphics.FigureAspectRatio(3, 1, 1);
catch
end
tlo = tiledlayout(f, 1, 3, 'TileSpacing','compact', 'Padding','compact');

% Colors
try
	cols = GlobalOptimization.ColorAllocate(2, [1,1,1;1,1,1]);
catch
	cols = lines(2);
end

% 5.1 Learning curve (ALL LightWater sessions; required: LearningSummarize + MultiShadowedLines)
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
nV7 = numel(unique(string(sessionForSummary.Mouse(sessionForSummary.Group=="Vacation7"))));
labels = {sprintf('Ctrl (n=%d)', nCtrl), sprintf('Vacation7 (n=%d)', nV7)};
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
ylabel(ax1, 'Performance');
ylim(ax1, [0 1]);
title(ax1, 'LightWater learning curve');
grid(ax1,'on');
box(ax1,'off');

% 5.2 Transfer first session performance
ax2 = nexttile(tlo, 2);
hold(ax2,'on');
iHideToolbar(ax2);
TransferLearning.Fig35.iSwarm2(ax2, rows.Performance(idxCtrl), rows.Performance(idxV7), ["Ctrl","Vacation7"], 'Performance', pPerf);
title(ax2, 'First transfer session');
grid(ax2,'on');

% 5.3 Learning speed (session-level delta perf)
ax3 = nexttile(tlo, 3);
hold(ax3,'on');
iHideToolbar(ax3);
[pLines_ax3, pTexts_ax3] = TransferLearning.Fig35.iSwarm2(ax3, dCtrl, dV7, ["Ctrl","Vacation7"], 'Learning speed (DeltaNext)', pDelta);
title(ax3, 'Learning speed');
grid(ax3,'on');

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

svgPathUNC = fullfile(outDirUNC, 'Fig3_5d_Vacation7VsCtrl.svg');

try
	TransferLearning.PrintFigure(f, svgPathUNC);
	fprintf('Wrote: %s\n', svgPathUNC);
catch ME
	warning(ME.identifier, 'UNC export failed: %s', ME.message);
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
Sess = sortrows(Sess, {'Mouse','DateTime'});
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
% Query all LightWater sessions/blocks regardless of Phase.
B = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Performance"], Design="LightWater");
if isempty(B)
	return;
end
B.Mouse = string(B.Mouse);
B.DateTime = iNormalizeDateTime(B.DateTime);
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

function [meanCurve, nCell] = iMeanCurveZScore(DS, mouse, dt, keepCellUID)
meanCurve = []; nCell = NaN;
try
	q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
	G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
		return;
	end
	M = iNtatsData(G.NTATS);
	if nargin >= 4 && ~isempty(keepCellUID)
		try
			keep = ismember(uint64(G.CellUID), uint64(keepCellUID(:)));
			M = M(keep, :);
		catch
		end
	end
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

function keepUID = iLearnedActiveCellUIDs_1s(DS, mouse, idx1, baseMask, kSigma)
% Cells active@1s during Learned AudioWater (pooled within phase), used to filter Panel2.
keepUID = uint64([]);
try
	mouse = string(mouse);
	G = iQueryNTATSOrEmpty(DS, struct('Mouse', mouse, 'Stimulus','AudioWater', 'Phase','Learned'));
	if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
		return;
	end
	X = iNtatsData(G.NTATS);
	if isempty(X)
		return;
	end
	act = iActiveAtIdx(X, baseMask, idx1, kSigma);
	keepUID = uint64(G.CellUID(act));
catch
	keepUID = uint64([]);
end
end

function [learnedCell, keepUID] = iLearnedAudioCellTable_1s(DS, mouse, idx1, baseMask, kSigma)
% Return learned-phase table(CellUID, LearnedActive) and active CellUIDs for filtering.
learnedCell = table(uint64.empty(0,1), logical.empty(0,1), 'VariableNames', {'CellUID','LearnedActive'});
keepUID = uint64([]);
try
	mouse = string(mouse);
	G = iQueryNTATSOrEmpty(DS, struct('Mouse', mouse, 'Stimulus','AudioWater', 'Phase','Learned'));
	if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
		return;
	end
	X = iNtatsData(G.NTATS);
	if isempty(X)
		return;
	end
	act = iActiveAtIdx(X, baseMask, idx1, kSigma);
	learnedCell = table(uint64(G.CellUID), logical(act), 'VariableNames', {'CellUID','LearnedActive'});
	keepUID = uint64(G.CellUID(act));
catch
	learnedCell = table(uint64.empty(0,1), logical.empty(0,1), 'VariableNames', {'CellUID','LearnedActive'});
	keepUID = uint64([]);
end
end


function [reuse, nCells] = iReuse1s_LearnedAudio_to_TransferLight(DS, mouse, transferDT, idx1, baseMask, kSigma, zLayer, learnedCell)
% Reuse(1s) = P(TransferLight active@1s | LearnedAudio active@1s)
% Active predicate matches Fig3.2c: Z(1s) > mean(Z(-3~0)) + kSigma*std(Z(-3~0)) on Median NTATS ZScore.
reuse = NaN;
nCells = NaN;
try
	mouse = string(mouse);
	transferDT = iNormalizeDateTime(transferDT);
	
	GLearn = [];
	if nargin < 8 || isempty(learnedCell)
		GLearn = iQueryNTATSOrEmpty(DS, struct('Mouse', mouse, 'Stimulus','AudioWater', 'Phase','Learned'));
	end
	GTran  = iQueryNTATSOrEmpty(DS, struct('Mouse', mouse, 'Stimulus','LightWater', 'Phase','Transfer', 'DateTime', transferDT));
	if (isempty(learnedCell) && isempty(GLearn)) || isempty(GTran)
		return;
	end

	XT = iNtatsData(GTran.NTATS);
	if isempty(XT)
		return;
	end

	if isempty(learnedCell)
		XL = iNtatsData(GLearn.NTATS);
		if isempty(XL)
			return;
		end
		actL = iActiveAtIdx(XL, baseMask, idx1, kSigma);
		learnedCell = table(uint64(GLearn.CellUID), logical(actL), 'VariableNames', {'CellUID','LearnedActive'});
	end

	actT = iActiveAtIdx(XT, baseMask, idx1, kSigma);
	transferCell = table(uint64(GTran.CellUID), logical(actT), 'VariableNames', {'CellUID','TransferActive'});
	
	LT = innerjoin(learnedCell, transferCell, 'Keys','CellUID');
	% Layer filter (uniform requirement): keep only the specified ZLayer (e.g., MOp2/3)
	if nargin >= 7 && strlength(string(zLayer)) > 0
		LT = iFilterTableByZLayer(DS, LT, string(zLayer));
	end
	nCells = height(LT);
	if nCells < 10
		reuse = NaN;
		return;
	end
	den = logical(LT.LearnedActive);
	if nnz(den) < 1
		reuse = NaN;
		return;
	end
	reuse = mean(double(LT.TransferActive(den)), 'omitnan');
catch
	reuse = NaN;
	nCells = NaN;
end

end

function T = iFilterTableByZLayer(DS, T, zLayer)
% Filter a table with CellUID by DS.Cells.ZLayer.
try
	if isempty(T) || ~ismember('CellUID', T.Properties.VariableNames)
		return;
	end
	if ~isprop(DS, 'Cells')
		return;
	end
	C = DS.Cells;
	need = ["CellUID","ZLayer"];
	if ~all(ismember(need, string(C.Properties.VariableNames)))
		return;
	end
	uids = uint64(T.CellUID);
	[tf, loc] = ismember(uids, uint64(C.CellUID));
	if ~any(tf)
		T = T([],:);
		return;
	end
	z = strings(numel(uids), 1);
	z(tf) = string(C.ZLayer(loc(tf)));
	keep = (z == string(zLayer));
	T = T(keep, :);
catch
end
end

function act = iActiveAtIdx(X, baseMask, idx, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
val = X(:, idx);
act = val > (baseMu + kSigma .* baseSd);
end

function G = iQueryNTATSOrEmpty(DS, query)
try
	G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
catch
	G = [];
end
end

function sd15 = iStdCells1p5_DeltaF(DS, mouse, dt, idx15, zLayer)
% Match Fig3.4c: filter by QueryNTATS-provided ZLayer when available.
sd15 = NaN;
layerName = string(zLayer);
q = struct('Mouse', string(mouse), 'DateTime', dt, 'Stimulus', 'LightWater');
try
	G = DS.QueryNTATS(q, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
catch
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
if isempty(M) || idx15 < 1 || idx15 > size(M,2)
	return;
end
v = double(M(:, idx15));
sd15 = std(v, 'omitnan');
end

function M = iFilterByZLayer(DS, G, M, zLayer)
% Filter rows of M by DS.Cells.ZLayer, aligned to G.CellUID.
try
	if isempty(M)
		return;
	end
	if ~isprop(DS, 'Cells')
		return;
	end
	C = DS.Cells;
	need = ["CellUID","ZLayer"];
	if ~all(ismember(need, string(C.Properties.VariableNames)))
		return;
	end
	uids = uint64(G.CellUID);
	[tf, loc] = ismember(uids, uint64(C.CellUID));
	if ~any(tf)
		M(:,:) = [];
		return;
	end
	z = strings(numel(uids), 1);
	z(tf) = string(C.ZLayer(loc(tf)));
	keep = (z == string(zLayer));
	M = M(keep, :);
catch
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

function iSwarm2(ax, xA, xB, labels, yLabel)
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
end

function iPValuePLineScatter(ax, x1, x2, y1, y2, p)
% p-value line (required: MATLAB.Graphics.PLine). Do not manually place text.
if ~isfinite(p)
	return;
end
y1 = double(y1(:));
y2 = double(y2(:));
y1 = y1(isfinite(y1));
y2 = y2(isfinite(y2));
if isempty(y1) || isempty(y2)
	return;
end

X = [x1*ones(numel(y1),1); x2*ones(numel(y2),1)];
Y = [y1; y2];
S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
try
	if isprop(S, 'HitTest'); S.HitTest = 'off'; end
	if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
	if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
catch
end

Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), 0, ...
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
