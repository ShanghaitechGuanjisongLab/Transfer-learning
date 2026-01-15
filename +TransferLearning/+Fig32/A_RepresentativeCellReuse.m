% 图3.2a：代表性单细胞原始信号曲线（复用示意）
%
% Goal (script): pick ONE representative cell (same CellUID) that shows:
% - Naive AudioWater: inactive
% - Learned AudioWater: active
% - Transfer LightWater Hit: active
% - Transfer LightWater Miss: inactive
%
% Signal constraints:
% - Do NOT display ΔF/F_0.
% - Display either DeltaF or ZScore.
% - Baseline is cue pre-3s (-3~0s).
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
% - IMPORTANT: MUST REMAIN A SCRIPT (do not convert to a function again).
% - Do NOT use run.
% - Invoke from command window (no parentheses):
%     TransferLearning.Fig32.A_RepresentativeCellReuse
% - Or run from the MATLAB editor (Run/F5).

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2a_RepresentativeCellReuse.svg";

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

% --- 1) Load dataset (Audio→Light paradigm)
AL = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs; % duration(48x1): -3~3s
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask = (xsSec >= 0) & (xsSec <= 1);
plotMask = (xsSec >= -2) & (xsSec <= 2);
xsPlot = xsSec(plotMask);
if ~any(baseMask)
	error('Fig3_2a:NoBaselineSamples', 'baseline window -3~0s has no samples in TransferLearning.Xs');
end
if ~any(winMask)
	error('Fig3_2a:NoWindowSamples', 'response window 0~1s has no samples in TransferLearning.Xs');
end
if ~any(plotMask)
	error('Fig3_2a:NoPlotSamples', 'plot window -2~2s has no samples in TransferLearning.Xs');
end

kSigma = 3;

% --- 2) Fast screening using median NTATS (ZScore)
% Naive/Learned: AudioWater; Transfer: LightWater Hit/Miss
GNaive = iQueryNTATSOrEmpty(AL, struct('Stimulus','AudioWater','Phase','Naive'));
GLearn = iQueryNTATSOrEmpty(AL, struct('Stimulus','AudioWater','Phase','Learned'));
GTranHM = iQueryTransferHitMissOrEmpty(AL);

if isempty(GNaive) || isempty(GLearn) || isempty(GTranHM)
	error('Fig3_2a:MissingGroups', 'Cannot query all required groups (Naive/Learned/Transfer Hit/Miss).');
end

XNaive = iNtatsData(GNaive.NTATS);
XLearn = iNtatsData(GLearn.NTATS);
XHM = iNtatsData(GTranHM.NTATS);
if ndims(XHM) ~= 3 || size(XHM,3) < 2
	error('Fig3_2a:BadTransferHM', 'Unexpected NTATS dimension for Transfer Hit/Miss.');
end
XHit = XHM(:,:,1);
XMiss = XHM(:,:,2);

cellUID = uint64(GLearn.CellUID);

% Align cell sets across groups (inner join on CellUID)
cellUID = intersect(cellUID, uint64(GNaive.CellUID));
cellUID = intersect(cellUID, uint64(GTranHM.CellUID));

if isempty(cellUID)
	error('Fig3_2a:NoCommonCells', 'No CellUID is common across Naive/Learned/Transfer(Hit/Miss).');
end

[~, idxNaive] = ismember(cellUID, uint64(GNaive.CellUID));
[~, idxLearn] = ismember(cellUID, uint64(GLearn.CellUID));
[~, idxHM] = ismember(cellUID, uint64(GTranHM.CellUID));

XNaive = XNaive(idxNaive, :);
XLearn = XLearn(idxLearn, :);
XHit = XHit(idxHM, :);
XMiss = XMiss(idxHM, :);

% Active predicate (matches Methods section): max(0~1s) > mean(base)+k*std(base)
naiveAct = iMedianActive(XNaive, baseMask, winMask, kSigma);
learnAct = iMedianActive(XLearn, baseMask, winMask, kSigma);
hitAct = iMedianActive(XHit, baseMask, winMask, kSigma);
missAct = iMedianActive(XMiss, baseMask, winMask, kSigma);

cand = (~naiveAct) & learnAct & hitAct & (~missAct);
if ~any(cand)
	warning('Fig3_2a:NoPerfectCandidate', 'No cell meets all 4 predicates; will relax Miss/Naive to choose the best-scoring cell.');
	cand = learnAct & hitAct;
end

% Score candidates to prefer stronger contrast
peakNaive = max(XNaive(:, winMask), [], 2, 'omitnan');
peakLearn = max(XLearn(:, winMask), [], 2, 'omitnan');
peakHit = max(XHit(:, winMask), [], 2, 'omitnan');
peakMiss = max(XMiss(:, winMask), [], 2, 'omitnan');
score = peakLearn + peakHit - peakNaive - peakMiss;
score(~cand) = -inf;

[~, order] = sort(score, 'descend', 'MissingPlacement', 'last');
cellUIDOrdered = cellUID(order);

% --- 2.5) Precompute per-mouse representative sessions & trial lists (vectorized)
% Goal: avoid per-cell TableQuery inside the candidate loop.

Tnaive = AL.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Naive", Stimulus="AudioWater");
Tlearn = AL.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Learned", Stimulus="AudioWater");
Ttran  = AL.TableQuery(["Mouse","DateTime","TrialUID","Behavior"], Phase="Transfer", Stimulus="LightWater");

Tnaive.Mouse = string(Tnaive.Mouse);
Tlearn.Mouse = string(Tlearn.Mouse);
Ttran.Mouse  = string(Ttran.Mouse);

Tnaive.DateTime = iNormalizeDateTime(Tnaive.DateTime);
Tlearn.DateTime = iNormalizeDateTime(Tlearn.DateTime);
Ttran.DateTime  = iNormalizeDateTime(Ttran.DateTime);

% pick representative DateTime per mouse: Naive earliest; Learned latest; Transfer earliest
dtNaiveT = groupsummary(Tnaive, "Mouse", "min", "DateTime");
dtNaiveT.Properties.VariableNames{end} = 'DateTimeNaive';
dtLearnT = groupsummary(Tlearn, "Mouse", "max", "DateTime");
dtLearnT.Properties.VariableNames{end} = 'DateTimeLearned';
dtTranT  = groupsummary(Ttran,  "Mouse", "min", "DateTime");
dtTranT.Properties.VariableNames{end} = 'DateTimeTransfer';

% Restrict to mice having all three stages
Sess = innerjoin(dtNaiveT(:, ["Mouse","DateTimeNaive"]), dtLearnT(:, ["Mouse","DateTimeLearned"]), 'Keys', 'Mouse');
Sess = innerjoin(Sess, dtTranT(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');

% Collect trial lists for the selected DateTimes
naiveJoin = innerjoin(Tnaive, Sess(:, ["Mouse","DateTimeNaive"]), 'Keys', 'Mouse');
naiveJoin = naiveJoin(naiveJoin.DateTime == naiveJoin.DateTimeNaive, :);
[gN, mkN] = findgroups(naiveJoin.Mouse);
trialNaive = splitapply(@(x){uint64(x)}, uint64(naiveJoin.TrialUID), gN);
naiveTrialsT = table(mkN, trialNaive, 'VariableNames', ["Mouse","TrialUIDNaive"]);

learnJoin = innerjoin(Tlearn, Sess(:, ["Mouse","DateTimeLearned"]), 'Keys', 'Mouse');
learnJoin = learnJoin(learnJoin.DateTime == learnJoin.DateTimeLearned, :);
[gL, mkL] = findgroups(learnJoin.Mouse);
trialLearn = splitapply(@(x){uint64(x)}, uint64(learnJoin.TrialUID), gL);
learnTrialsT = table(mkL, trialLearn, 'VariableNames', ["Mouse","TrialUIDLearned"]);

tranJoin = innerjoin(Ttran, Sess(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');
tranJoin = tranJoin(tranJoin.DateTime == tranJoin.DateTimeTransfer, :);
[gT, mkT] = findgroups(tranJoin.Mouse);
[trialHit, trialMiss] = splitapply(@(uid,bh) iSplitHitMiss(uid,bh), uint64(tranJoin.TrialUID), double(tranJoin.Behavior), gT);
tranTrialsT = table(mkT, trialHit, trialMiss, 'VariableNames', ["Mouse","TrialUIDHit","TrialUIDMiss"]);

Sess = innerjoin(Sess, naiveTrialsT, 'Keys', 'Mouse');
Sess = innerjoin(Sess, learnTrialsT, 'Keys', 'Mouse');
Sess = innerjoin(Sess, tranTrialsT,  'Keys', 'Mouse');

% Pre-map candidate CellUID -> Mouse/ZLayer (vectorized)
Cmeta = AL.Cells(:, ["CellUID","Mouse","ZLayer"]);
cellUIDAll = uint64(Cmeta.CellUID);
[tfMeta, locMeta] = ismember(uint64(cellUIDOrdered), cellUIDAll);
mouseOf = strings(numel(cellUIDOrdered), 1);
zOf = strings(numel(cellUIDOrdered), 1);
mouseOf(tfMeta) = string(Cmeta.Mouse(locMeta(tfMeta)));
zOf(tfMeta) = string(Cmeta.ZLayer(locMeta(tfMeta)));

% Build one best candidate per mouse (highest score; already ordered by score)
scoreOrdered = score(order);
candT = table(uint64(cellUIDOrdered(:)), double(scoreOrdered(:)), mouseOf(:), zOf(:), ...
	'VariableNames', ["CellUID","Score","Mouse","ZLayer"]);
candT = candT(candT.Mouse ~= "", :);

% Keep only mice that have all required sessions
candT = candT(ismember(candT.Mouse, Sess.Mouse), :);
if isempty(candT)
	error('Fig3_2a:NoCandidateMice', 'No candidate cells belong to mice that have Naive/Learned/Transfer sessions.');
end

% pick top-1 per mouse
candT = sortrows(candT, ["Mouse","Score"], ["ascend","descend"]);
[~, firstIdx] = unique(candT.Mouse, 'stable');
candTop = candT(firstIdx, :);
% search order: best overall score first
candTop = sortrows(candTop, 'Score', 'descend');

% --- 3) Choose a plottable candidate (must have enough trials per condition in selected sessions)
Ts = AL.TrialSignals;
Tr = AL.Trials;

picked = struct('CellUID', uint64(0), 'Mouse', "", 'ZLayer', "", 'DateTimeNaive', NaT, 'DateTimeLearned', NaT, 'DateTimeTransfer', NaT);
plotSets = struct();

minTrials = 4; % user request: 3~4 trials per condition is enough
nPick = 4;

for iRow = 1:height(candTop)
	cid = uint64(candTop.CellUID(iRow));
	m = string(candTop.Mouse(iRow));
	z = string(candTop.ZLayer(iRow));

	idxSess = find(string(Sess.Mouse) == m, 1, 'first');
	if isempty(idxSess)
		continue;
	end

	dtNaive = Sess.DateTimeNaive(idxSess);
	dtLearn = Sess.DateTimeLearned(idxSess);
	dtTran  = Sess.DateTimeTransfer(idxSess);

	tuNaiveAll = uint64(Sess.TrialUIDNaive{idxSess});
	tuLearnAll = uint64(Sess.TrialUIDLearned{idxSess});
	truHitAll  = uint64(Sess.TrialUIDHit{idxSess});
	truMissAll = uint64(Sess.TrialUIDMiss{idxSess});

	if numel(tuNaiveAll) < minTrials || numel(tuLearnAll) < minTrials || numel(truHitAll) < minTrials || numel(truMissAll) < minTrials
		continue;
	end

	tuNaive = tuNaiveAll(randperm(numel(tuNaiveAll), nPick));
	tuLearn = tuLearnAll(randperm(numel(tuLearnAll), nPick));
	truHit  = truHitAll(randperm(numel(truHitAll), nPick));
	truMiss = truMissAll(randperm(numel(truMissAll), nPick));

	[S0, S1, S2, S3] = iGetSignals4Cond(Ts, cid, tuNaive, tuLearn, truHit, truMiss);
	if isempty(S0) || isempty(S1) || isempty(S2) || isempty(S3)
		continue;
	end

	% Normalize to ZScore with baseline -3~0s
	Z0 = iZScoreByBaseline(S0, baseMask);
	Z1 = iZScoreByBaseline(S1, baseMask);
	Z2 = iZScoreByBaseline(S2, baseMask);
	Z3 = iZScoreByBaseline(S3, baseMask);

	% Re-check that this particular session-level pattern roughly holds
	okNaive = iSessionInactive(Z0, winMask, 1.5);
	okLearn = iSessionActive(Z1, winMask, 3);
	okHit = iSessionActive(Z2, winMask, 3);
	okMiss = iSessionInactive(Z3, winMask, 1.5);
	if ~(okLearn && okHit)
		continue;
	end
	if ~(okNaive && okMiss)
		continue;
	end

	picked.CellUID = cid;
	picked.Mouse = m;
	picked.ZLayer = z;
	picked.DateTimeNaive = dtNaive;
	picked.DateTimeLearned = dtLearn;
	picked.DateTimeTransfer = dtTran;

	plotSets.NaiveAudio = Z0;
	plotSets.LearnedAudio = Z1;
	plotSets.TransferHit = Z2;
	plotSets.TransferMiss = Z3;
	break;
end

if picked.CellUID == 0
	error('Fig3_2a:NoPlottableCell', 'No candidate cell found with sufficient trials and clear 4-condition pattern.');
end

% --- 4) Plot (single-trial overlays)
figTitle = sprintf('Fig3.2a Representative Cell (Mouse=%s, CellUID=%d, %s)', picked.Mouse, picked.CellUID, picked.ZLayer);
f = figure('Color','w', 'Name', figTitle);
MATLAB.Graphics.FigureAspectRatio(8,5,1/2);

TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

titles = [
	"Naive AudioWater (inactive)",
	"Learned AudioWater (active)",
	"Transfer LightWater Hit (active)",
	"Transfer LightWater Miss (inactive)" ];

dataCells = {plotSets.NaiveAudio, plotSets.LearnedAudio, plotSets.TransferHit, plotSets.TransferMiss};
axesList = gobjects(4,1);

for i = 1:4
	ax = nexttile(TL);
	axesList(i) = ax;
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	Z = dataCells{i};
	Z = Z(:, plotMask);
	% keep at most N trials for display
	Nshow = min(4, size(Z,1));
	idx = 1:size(Z,1);
	idx = idx(randperm(numel(idx), Nshow));

	for k = 1:numel(idx)
		plot(ax, xsPlot, Z(idx(k),:), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.75);
	end
	med = median(Z, 1, 'omitnan');
	plot(ax, xsPlot, med, 'k-', 'LineWidth', 2);

	TransferLearning.DrawCueWaterLines(ax);
	grid(ax,'on');
	xlim(ax, [-2 2]);
	title(ax, titles(i), 'Interpreter','none');
	box(ax,'on');
end

% Unify limits across panels
try
	MATLAB.Graphics.UnifyAxesLims(axesList, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

% One shared axis label set on tiledlayout
xlabel(TL, 'Time from cue (s)');
ylabel(TL, 'ZScore (baseline -3~0s)');

% Hide top-row X axes; hide right-column Y axes
try
	axesList(1).XAxis.Visible = 'off';
	axesList(2).XAxis.Visible = 'off';
	axesList(2).YAxis.Visible = 'off';
	axesList(4).YAxis.Visible = 'off';
catch
end

sgtitle(TL, sprintf('Fig3.2a Representative Cell | Mouse=%s, CellUID=%d', ...
	picked.Mouse, picked.CellUID), 'Interpreter','none');

% --- 5) Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end
