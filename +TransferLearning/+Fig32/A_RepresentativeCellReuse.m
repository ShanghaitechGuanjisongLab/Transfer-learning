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

% --- Optional: pin to a specific known good cell (Mouse + CellIndex)
% Example request: yqn0020, Cell197
pinEnabled = true;
pinMouse = "yqn0020";
pinCellUIDExact = uint64(197); % if non-empty, pin by CellUID directly
pinCellIndex = [];             % otherwise pin by CellIndex (can be non-unique)
pinCellUIDs = uint64([]); % will be resolved from AL.Cells (may be multiple)

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

% Resolve pinned cell UID (if requested)
if pinEnabled
	try
		Cpin = AL.Cells(:, ["Mouse","CellIndex","CellUID"]);
		mMask = string(Cpin.Mouse) == string(pinMouse);
		if ~isempty(pinCellUIDExact)
			idxPin = find(mMask & (uint64(Cpin.CellUID) == uint64(pinCellUIDExact)));
			if numel(idxPin) ~= 1
				error('Fig3_2a:BadPinnedCell', 'Pinned CellUID not uniquely found: Mouse=%s CellUID=%d (matches=%d).', string(pinMouse), uint64(pinCellUIDExact), numel(idxPin));
			end
			pinCellUIDs = uint64(Cpin.CellUID(idxPin));
			fprintf('Fig3.2a pinned selection: Mouse=%s CellUID=%d\n', string(pinMouse), pinCellUIDs);
		else
			idxPin = find(mMask & (double(Cpin.CellIndex) == double(pinCellIndex)));
			if isempty(idxPin)
				error('Fig3_2a:BadPinnedCell', 'Pinned cell not found: Mouse=%s CellIndex=%d.', string(pinMouse), pinCellIndex);
			end
			pinCellUIDs = uint64(Cpin.CellUID(idxPin));
			fprintf('Fig3.2a pinned selection: Mouse=%s CellIndex=%d -> CellUIDs=[%s]\n', ...
				string(pinMouse), pinCellIndex, strjoin(string(pinCellUIDs(:).'), ','));
		end
	catch ME
		warning(ME.identifier, 'Failed to resolve pinned cell; disabling pin. (%s)', ME.message);
		pinEnabled = false;
	end
end

xs = TransferLearning.Xs; % duration(48x1): -3~3s
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask = (xsSec >= 0) & (xsSec <= 1);
win2Mask = (xsSec >= 0) & (xsSec <= 2);
plotMask = (xsSec >= -2) & (xsSec <= 2);
xsPlot = xsSec(plotMask);
if ~any(baseMask)
	error('Fig3_2a:NoBaselineSamples', 'baseline window -3~0s has no samples in TransferLearning.Xs');
end
if ~any(winMask)
	error('Fig3_2a:NoWindowSamples', 'response window 0~1s has no samples in TransferLearning.Xs');
end
if ~any(win2Mask)
	error('Fig3_2a:NoWindowSamples02', 'peak-compare window 0~2s has no samples in TransferLearning.Xs');
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

% If pinned, restrict to the specified cell.
if pinEnabled && ~isempty(pinCellUIDs)
	candT = candT((string(candT.Mouse) == string(pinMouse)) & ismember(uint64(candT.CellUID), uint64(pinCellUIDs)), :);
	if isempty(candT)
		error('Fig3_2a:PinnedCellNotCandidate', 'Pinned cell(s) not present in candidate table: Mouse=%s CellIndex=%d. Check that they exist in all required groups.', string(pinMouse), pinCellIndex);
	end
end

% Keep only mice that have all required sessions
candT = candT(ismember(candT.Mouse, Sess.Mouse), :);
if isempty(candT)
	error('Fig3_2a:NoCandidateMice', 'No candidate cells belong to mice that have Naive/Learned/Transfer sessions.');
end

% pick top-1 per mouse
if pinEnabled
	% pinned: only evaluate this one cell
	candTop = candT;
else
	% pick top-N per mouse (increase robustness after QueryNTATS changes)
	candidatesPerMouse = 30;
	candT = sortrows(candT, ["Mouse","Score"], ["ascend","descend"]);
	[gM, ~] = findgroups(candT.Mouse);
	idxCell = splitapply(@(ii){ii(1:min(numel(ii), candidatesPerMouse))}, (1:height(candT))', gM);
	idxKeep = vertcat(idxCell{:});
	candTop = candT(idxKeep, :);
	% search order: best overall score first
	candTop = sortrows(candTop, 'Score', 'descend');
end

% --- 3) Choose a plottable candidate (must have enough trials per condition in selected sessions)
Ts = AL.TrialSignals;
Tr = AL.Trials;

picked = struct('CellUID', uint64(0), 'Mouse', "", 'ZLayer', "", 'DateTimeNaive', NaT, 'DateTimeLearned', NaT, 'DateTimeTransfer', NaT);
plotSets = struct();

fallbackFull = picked;            % Learned+Hit active AND Naive+Miss inactive
fallbackFullPlotSets = struct();
hasFallbackFull = false;

fallbackPartial = picked;         % Learned+Hit active only
fallbackPartialPlotSets = struct();
hasFallbackPartial = false;
fallbackPartialWeaker = false;

qual = table(uint64.empty(0,1), string.empty(0,1), string.empty(0,1), ...
	double.empty(0,1), double.empty(0,1), double.empty(0,1), logical.empty(0,1), ...
	'VariableNames', ["CellUID","Mouse","ZLayer","MedPkLearn01","MedPkHit02","MedPkMiss02","HitGtMiss02"]);

minTrials = 3; % user request: 3~4 trials per condition is enough
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

	% Do NOT randomly sample trials; use ALL trials in the selected sessions.
	% Plot will later display up to 4 trials chosen deterministically by peak ranking.
	tuNaive = tuNaiveAll;
	tuLearn = tuLearnAll;
	truHit  = truHitAll;
	truMiss = truMissAll;

	[S0, S1, S2, S3] = iGetSignals4Cond(Ts, cid, tuNaive, tuLearn, truHit, truMiss);
	if isempty(S0) || isempty(S1) || isempty(S2) || isempty(S3)
		continue;
	end

	% Normalize to ZScore with baseline -3~0s
	Z0 = iZScoreByBaseline(S0, baseMask);
	Z1 = iZScoreByBaseline(S1, baseMask);
	Z2 = iZScoreByBaseline(S2, baseMask);
	Z3 = iZScoreByBaseline(S3, baseMask);

	% Deterministically select up to 4 trials for DISPLAY (not for selection):
	% - Naive: smallest 0~2s peak
	% - Learned: largest 0~2s peak
	% - Transfer Hit: largest 0~2s peak
	% - Transfer Miss: smallest 0~2s peak
	Ndisp = 4;
	pk0 = max(Z0(:, win2Mask), [], 2, 'omitnan');
	pk1 = max(Z1(:, win2Mask), [], 2, 'omitnan');
	pk2 = max(Z2(:, win2Mask), [], 2, 'omitnan');
	pk3 = max(Z3(:, win2Mask), [], 2, 'omitnan');

	[~, o0] = sort(pk0, 'ascend', 'MissingPlacement','last');
	[~, o1] = sort(pk1, 'descend', 'MissingPlacement','last');
	[~, o2] = sort(pk2, 'descend', 'MissingPlacement','last');
	[~, o3] = sort(pk3, 'ascend', 'MissingPlacement','last');

	i0 = o0(1:min(numel(o0), Ndisp));
	i1 = o1(1:min(numel(o1), Ndisp));
	i2 = o2(1:min(numel(o2), Ndisp));
	i3 = o3(1:min(numel(o3), Ndisp));

	Z0p = Z0(i0, :);
	Z1p = Z1(i1, :);
	Z2p = Z2(i2, :);
	Z3p = Z3(i3, :);

	% Re-check that this particular session-level pattern roughly holds
	okNaive = iSessionInactive(Z0, winMask, 1.5);
	okLearn = iSessionActive(Z1, winMask, 3);
	okHit = iSessionActive(Z2, winMask, 3);
	okMiss = iSessionInactive(Z3, winMask, 1.5);
	if ~(okLearn && okHit)
		if ~pinEnabled
			continue;
		end
	end

	% Prefer: Transfer Hit active but weaker than Learned ("最好能")
	pkLearn = max(Z1(:, winMask), [], 2, 'omitnan');
	pkHit   = max(Z2(:, winMask), [], 2, 'omitnan');
	medLearn = median(pkLearn, 'omitnan');
	medHit   = median(pkHit, 'omitnan');
	isWeaker = isfinite(medLearn) && isfinite(medHit) && (medHit < medLearn);

	% Additional required predicate: within 0~2s, Transfer Hit peak must exceed Miss peak
	pkHit02  = max(Z2(:, win2Mask), [], 2, 'omitnan');
	pkMiss02 = max(Z3(:, win2Mask), [], 2, 'omitnan');
	medHit02  = median(pkHit02, 'omitnan');
	medMiss02 = median(pkMiss02, 'omitnan');
	hitGtMiss02 = isfinite(medHit02) && isfinite(medMiss02) && (medHit02 > medMiss02);

	% Keep diagnostics (for later ">=4 sessions" question)
	qual = [qual; table(cid, m, z, medLearn, medHit02, medMiss02, hitGtMiss02, ...
		'VariableNames', qual.Properties.VariableNames)]; %#ok<AGROW>
	if ~hitGtMiss02
		if ~pinEnabled
			continue;
		end
	end

	isFullPattern = okNaive && okMiss;
	if isFullPattern && isWeaker
		picked.CellUID = cid;
		picked.Mouse = m;
		picked.ZLayer = z;
		picked.DateTimeNaive = dtNaive;
		picked.DateTimeLearned = dtLearn;
		picked.DateTimeTransfer = dtTran;

		plotSets.NaiveAudio = Z0p;
		plotSets.LearnedAudio = Z1p;
		plotSets.TransferHit = Z2p;
		plotSets.TransferMiss = Z3p;
		break;
	end

	if isFullPattern
		if ~hasFallbackFull
			fallbackFull.CellUID = cid;
			fallbackFull.Mouse = m;
			fallbackFull.ZLayer = z;
			fallbackFull.DateTimeNaive = dtNaive;
			fallbackFull.DateTimeLearned = dtLearn;
			fallbackFull.DateTimeTransfer = dtTran;

			fallbackFullPlotSets.NaiveAudio = Z0p;
			fallbackFullPlotSets.LearnedAudio = Z1p;
			fallbackFullPlotSets.TransferHit = Z2p;
			fallbackFullPlotSets.TransferMiss = Z3p;
			hasFallbackFull = true;
		end
		continue;
	end

	% Partial fallback: Learned/Hit active, but Naive/Miss not strictly inactive.
	if ~hasFallbackPartial || (isWeaker && ~fallbackPartialWeaker)
		fallbackPartial.CellUID = cid;
		fallbackPartial.Mouse = m;
		fallbackPartial.ZLayer = z;
		fallbackPartial.DateTimeNaive = dtNaive;
		fallbackPartial.DateTimeLearned = dtLearn;
		fallbackPartial.DateTimeTransfer = dtTran;

		fallbackPartialPlotSets.NaiveAudio = Z0p;
		fallbackPartialPlotSets.LearnedAudio = Z1p;
		fallbackPartialPlotSets.TransferHit = Z2p;
		fallbackPartialPlotSets.TransferMiss = Z3p;
		hasFallbackPartial = true;
		fallbackPartialWeaker = isWeaker;
	end
	continue;

end

if picked.CellUID == 0
	if hasFallbackFull
		warning('Fig3_2a:NoWeakerTransferCell', 'No cell found with Transfer Hit weaker than Learned; using the first cell that matches the 4-condition pattern (still requires Hit>Miss peak within 0~2s).');
		picked = fallbackFull;
		plotSets = fallbackFullPlotSets;
	elseif hasFallbackPartial
		warning('Fig3_2a:NoFullPatternCell', 'No cell found matching strict inactive(Naive/Miss) + active(Learned/Hit); using a cell with Learned/Hit active (still requires Hit>Miss peak within 0~2s).');
		picked = fallbackPartial;
		plotSets = fallbackPartialPlotSets;
	else
		error('Fig3_2a:NoPlottableCell', 'No candidate cell found that satisfies: Learned/Hit active (0~1s), Naive/Miss inactive (preferred), and Transfer Hit peak > Miss peak within 0~2s.');
	end
end

% --- 3.8) Diagnostics: how many candidates satisfy Hit>Miss(0~2s)?
try
	assignin('base', 'Fig3_2a_RepresentativeCellReuse_QualCandidates', qual);
catch
end
try
	qok = qual(qual.HitGtMiss02, :);
	nOk = height(qok);
	nMouseOk = numel(unique(qok.Mouse));
	fprintf('Fig3.2a diagnostics: candidates Hit>Miss within 0~2s: %d (mice=%d)\n', nOk, nMouseOk);
	if nOk < 4
		warning('Fig3_2a:FewerThan4Candidates', 'Only %d candidates satisfy Hit>Miss within 0~2s (mice=%d). If you require >=4 sessions, consider relaxing constraints or increasing candidatesPerMouse.', nOk, nMouseOk);
	end
catch
end

%% 
% --- 4) Plot (single-trial overlays)
svgName = "Fig3_2a_RepresentativeCellReuse.svg";
figTitle = sprintf('Representative Cell (Mouse=%s, CellUID=%d, %s)', picked.Mouse, picked.CellUID, picked.ZLayer);
f = figure('Color','w', 'Name', figTitle);
MATLAB.Graphics.FigureAspectRatio(71,46,3/4);

TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

titles = [
	"Naive AudioWater (inactive)";
	"Learned AudioWater (active)";
	"Transfer LightWater Hit (active)";
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
	for k = 1:size(Z,1)
		plot(ax, xsPlot, Z(k,:), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.75);
	end
	med = median(Z, 1, 'omitnan');
	plot(ax, xsPlot, med, 'k-', 'LineWidth', 2);

	TransferLearning.DrawCueWaterLines(ax);
	grid(ax,'on');
	xlim(ax, [-2 2]);
	title(ax, titles(i), 'Interpreter','none');
	box(ax,'off');
end

% Unify limits across panels
try
	MATLAB.Graphics.UnifyAxesLims(axesList, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

% One shared axis label set on tiledlayout
xlabel(TL, 'Time from cue (s)');
ylabel(TL, 'z-score');

% Font size
for iA = 1:numel(axesList)
	axesList(iA).FontSize = 6;
end

% Hide top-row X axes; hide right-column Y axes
try
	axesList(1).XAxis.Visible = 'off';
	axesList(2).XAxis.Visible = 'off';
	axesList(2).YAxis.Visible = 'off';
	axesList(4).YAxis.Visible = 'off';
catch
end

sgtitle(TL, sprintf('Mouse=%s, CellUID=%d', ...
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
	TransferLearning.PrintFigure(f, svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end
