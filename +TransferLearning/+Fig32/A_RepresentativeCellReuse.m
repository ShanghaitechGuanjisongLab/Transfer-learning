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
% - This file is a SCRIPT with local functions.
% - Call from command window as:
%     TransferLearning.Fig32.A_RepresentativeCellReuse()
%   (parentheses are allowed; no output arguments)

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
if ~any(baseMask)
	error('Fig3_2a:NoBaselineSamples', 'baseline window -3~0s has no samples in TransferLearning.Xs');
end
if ~any(winMask)
	error('Fig3_2a:NoWindowSamples', 'response window 0~1s has no samples in TransferLearning.Xs');
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

% --- 3) Choose a plottable candidate (must have enough trials per condition in selected sessions)
Ts = AL.TrialSignals;
Tr = AL.Trials;

picked = struct('CellUID', uint64(0), 'Mouse', "", 'ZLayer', "", 'DateTimeNaive', NaT, 'DateTimeLearned', NaT, 'DateTimeTransfer', NaT);
plotSets = struct();

for iC = 1:numel(cellUIDOrdered)
	cid = uint64(cellUIDOrdered(iC));
	[m, z] = iCellMeta(AL, cid);
	if m == ""
		continue;
	end

	% pick representative sessions (one DateTime each)
	[dtNaive, tuNaive] = iPickOneSessionTrialUID(AL, m, "Naive", "AudioWater", []);
	[dtLearn, tuLearn] = iPickOneSessionTrialUID(AL, m, "Learned", "AudioWater", []);
	[dtTran, tuTran] = iPickOneSessionTrialUID(AL, m, "Transfer", "LightWater", []);
	if isempty(tuNaive) || isempty(tuLearn) || isempty(tuTran)
		continue;
	end

	% Split transfer session trials by behavior
	rowsTran = ismember(uint64(Tr.TrialUID), uint64(tuTran));
	bh = double(Tr.Behavior(rowsTran));
	tru = uint64(Tr.TrialUID(rowsTran));
	truHit = tru(bh == 1);
	truMiss = tru(bh == 0);

	% Need enough trials in each condition
	minTrials = 8;
	if numel(truHit) < minTrials || numel(truMiss) < minTrials
		continue;
	end

	S0 = iGetSignals(Ts, cid, uint64(tuNaive));
	S1 = iGetSignals(Ts, cid, uint64(tuLearn));
	S2 = iGetSignals(Ts, cid, uint64(truHit));
	S3 = iGetSignals(Ts, cid, uint64(truMiss));
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
		% allow a little relaxation for session display, but keep searching for a cleaner cell
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
	% keep at most N trials for display
	Nshow = min(12, size(Z,1));
	idx = 1:size(Z,1);
	idx = idx(randperm(numel(idx), Nshow));

	for k = 1:numel(idx)
		plot(ax, xsSec, Z(idx(k),:), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.75);
	end
	med = median(Z, 1, 'omitnan');
	plot(ax, xsSec, med, 'k-', 'LineWidth', 2);

	TransferLearning.DrawCueWaterLines(ax);
	grid(ax,'on');
	xlim(ax, [min(xsSec) max(xsSec)]);
	title(ax, titles(i), 'Interpreter','none');
	ylabel(ax, 'ZScore (baseline -3~0s)');
	xlabel(ax, 'Time from cue (s)');
	box(ax,'on');
end

sgtitle(TL, sprintf('Mouse=%s, CellUID=%d, %s | Sessions: Naive=%s, Learned=%s, Transfer=%s', ...
	picked.Mouse, picked.CellUID, picked.ZLayer, ...
	string(picked.DateTimeNaive,'yyyy-MM-dd HH:mm'), string(picked.DateTimeLearned,'yyyy-MM-dd HH:mm'), string(picked.DateTimeTransfer,'yyyy-MM-dd HH:mm')),
	'Interpreter','none');

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

% Script outputs (in caller workspace): picked, plotSets

%% --- local functions
function G = iQueryNTATSOrEmpty(DS, query)
	G = [];
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch ME
		warning(ME.identifier, 'QueryNTATS failed: %s', ME.message);
		G = [];
	end
end

function G = iQueryTransferHitMissOrEmpty(DS)
	G = [];
	QT = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
		'VariableNames', {'GroupName','Phase','Stimulus','Behavior'});
	try
		G = DS.QueryNTATS(QT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch ME
		warning(ME.identifier, 'QueryNTATS Transfer Hit/Miss failed: %s', ME.message);
		G = [];
	end
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function act = iMedianActive(X, baseMask, winMask, kSigma)
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	winMx = max(X(:, winMask), [], 2, 'omitnan');
	act = winMx > (baseMu + kSigma .* baseSd);
end

function [mouse, zlayer] = iCellMeta(DS, cellUID)
	mouse = "";
	zlayer = "";
	try
		C = DS.Cells;
		row = find(uint64(C.CellUID) == uint64(cellUID), 1, 'first');
		if isempty(row)
			return;
		end
		mouse = string(C.Mouse(row));
		zlayer = string(C.ZLayer(row));
	catch
	end
end

function [dt, trialUID] = iPickOneSessionTrialUID(DS, mouse, phaseName, stimulusName, dateTimeSelect)
	% Pick one representative session (DateTime) for a mouse/phase/stimulus.
	% If dateTimeSelect is empty: Naive -> earliest; Learned -> latest; Transfer -> earliest.
	dt = NaT;
	trialUID = uint64([]);
	vars = ["TrialUID","Mouse","DateTime","Phase","Stimulus","Behavior"];
	T = [];
	try
		T = DS.TableQuery(vars, Mouse=mouse, Phase=phaseName, Stimulus=stimulusName);
	catch
		% fallback without Behavior
		try
			vars2 = ["TrialUID","Mouse","DateTime","Phase","Stimulus"];
			T = DS.TableQuery(vars2, Mouse=mouse, Phase=phaseName, Stimulus=stimulusName);
		catch
			T = [];
		end
	end
	if isempty(T)
		return;
	end
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = sortrows(T, 'DateTime');
	if ~isempty(dateTimeSelect) && ~ismissing(dateTimeSelect)
		dt = dateTimeSelect;
	else
		if string(phaseName) == "Learned"
			dt = T.DateTime(end);
		else
			dt = T.DateTime(1);
		end
	end
	trialUID = uint64(T.TrialUID(T.DateTime == dt));
	trialUID = unique(trialUID);
end

function dt = iNormalizeDateTime(dt)
	try
		dt = datetime(dt);
	catch
		% leave as-is
	end
	try
		if isdatetime(dt)
			dt.TimeZone = '';
		end
	catch
	end
end

function S = iGetSignals(Ts, cellUID, trialUID)
	% Return [nTrial x nTime] matrix
	trialUID = uint64(trialUID(:));
	cellUID = uint64(cellUID);
	mask = (uint64(Ts.CellUID) == cellUID) & ismember(uint64(Ts.TrialUID), trialUID);
	if ~any(mask)
		S = [];
		return;
	end
	sig = Ts.ResampledSignal(mask, :);
	S = double(sig);
end

function Z = iZScoreByBaseline(S, baseMask)
	mu = mean(S(:, baseMask), 2, 'omitnan');
	sd = std(S(:, baseMask), 0, 2, 'omitnan');
	sd(sd == 0 | ~isfinite(sd)) = 1;
	Z = (S - mu) ./ sd;
end

function tf = iSessionActive(Z, winMask, thr)
	m = median(Z, 1, 'omitnan');
	pk = max(m(winMask), [], 'omitnan');
	tf = isfinite(pk) && pk >= thr;
end

function tf = iSessionInactive(Z, winMask, thr)
	m = median(Z, 1, 'omitnan');
	pk = max(m(winMask), [], 'omitnan');
	tf = isfinite(pk) && pk <= thr;
end
