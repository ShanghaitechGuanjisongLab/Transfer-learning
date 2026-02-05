function AudioWater_Divergence_NaiveLearned_LikeEnglishFig1L
% TransferLearning.AudioWater_Divergence_NaiveLearned_LikeEnglishFig1L
%
% Divergence comparison for AudioWater using the SAME cohort sources as the PCA plot,
% and additionally including ALInterspersed per user request:
%   - TransferLearning.AudioLightBaseline()
%   - TransferLearning.ALInterspersed()
%
% Per-mouse:
%   - Naive: earliest AudioWater session
%   - Learned: latest AudioWater session
%   - Use ALL trials within each chosen session
%
% Plot style: like English Fig1L (UniExp.BarScatterCompare + bar styling)
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "AudioWater_Divergence_NaiveVsLearned_LikeEnglishFig1L.svg";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

stimulusName = "AudioWater";

% --- 1) Datasets
Sources = {
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
	builtin('struct', 'Name', "ALInterspersed",     'DS', TransferLearning.ALInterspersed())
};

perSource = cell(size(Sources));
diagSource = cell(size(Sources));
for iS = 1:numel(Sources)
	[perSource{iS}, diagSource{iS}] = iPerSourceDivergence(Sources{iS}.DS, Sources{iS}.Name, stimulusName);
	try
		d = diagSource{iS};
		fprintf('%s: candidate mice=%d, with NTS=%d, finite both=%d\n', string(d.Source), d.NCandidateMice, d.NWithNTS, d.NFiniteBoth);
	catch
	end
end

allPerMouse = vertcat(perSource{:});
if isempty(allPerMouse)
	error('AudioWaterDiv:EmptyAll', 'No mice computed from AudioLightBaseline/ALInterspersed for Stimulus=%s.', stimulusName);
end

% Collapse duplicates across sources by mouse (mean)
[miceKeep, naiveKeep, learnKeep, nSrc] = iCollapsePairedByMouse(allPerMouse);

fprintf('AudioWater divergence (Naive vs Learned): %d mice after merging sources\n', numel(miceKeep));
if any(nSrc > 1)
	fprintf('Note: %d mice appeared in multiple sources; values averaged.\n', sum(nSrc > 1));
end

if isempty(miceKeep)
	error('AudioWaterDiv:EmptyAfterFilter', 'No mice left after filtering non-finite divergence.');
end

% Stats (paired, same mice)
pSignedRank = nan;
try
	pSignedRank = signrank(naiveKeep, learnKeep);
	fprintf('Wilcoxon signed-rank (paired): p=%.6g\n', pSignedRank);
catch
end

% --- 4) Plot (like English Fig1L)
DataCell = {naiveKeep, learnKeep};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'AudioWater divergence Naive vs Learned');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 2.0]; % 30mm x 20mm

tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

try
	ax.XTick = [1, 2];
	ax.XTickLabel = {'Naive', 'Learned'};
	legend(ax, 'off');
catch
end

% Set asterisk font size
if isfield(Optional, 'MultiCompare') && ismember('PText', Optional.MultiCompare.Properties.VariableNames)
	for pt = Optional.MultiCompare.PText(:)'
		pt.FontSize = 6;
	end
end

% Bar styling (red/blue)
colorNaive = [1 0 0];
colorLearn = [0 0 1];
try
	if numel(Bars) == 1
		Bars.FaceColor = 'flat';
		nBars = numel(Bars.YData);
		reps = ceil(nBars/2);
		Bars.CData = repmat([colorNaive; colorLearn], reps, 1);
		Bars.CData = Bars.CData(1:nBars, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	else
		if numel(Bars) >= 2
			Bars(1).FaceColor = colorNaive;
			Bars(2).FaceColor = colorLearn;
			Bars(1).LineWidth = 0.5;
			Bars(2).LineWidth = 0.5;
			Bars(1).FaceAlpha = 1/3;
			Bars(2).FaceAlpha = 1/3;
		end
	end
catch
end

for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end

try
	ax.XLim = [0.5, 2.5];
catch
end

ylabel(ax, 'Divergence', 'FontSize', 6);
box(ax, 'off');
try, ax.Toolbar.Visible = 'off'; catch, end

% --- 5) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

% Save summary to base
Summary = table;
Summary.Group = ["Naive"; "Learned"];
Summary.N = [numel(naiveKeep); numel(learnKeep)];
Summary.Mean = [mean(naiveKeep,'omitnan'); mean(learnKeep,'omitnan')];
Summary.SEM = [std(naiveKeep,'omitnan')/sqrt(numel(naiveKeep)); std(learnKeep,'omitnan')/sqrt(numel(learnKeep))];
Summary.P_SignRank = [pSignedRank; pSignedRank];
assignin('base', 'AudioWater_Divergence_NaiveLearned_Summary', Summary);
assignin('base', 'AudioWater_Divergence_NaiveLearned_PerMouse', table(miceKeep, naiveKeep, learnKeep, 'VariableNames', {'Mouse','Naive','Learned'}));

end

function [perMouse, diag] = iPerSourceDivergence(DS, sourceName, stimulusName)
% Compute per-mouse Naive/Learned divergence within one dataset source.

diag = builtin('struct');
diag.Source = string(sourceName);
diag.NCandidateMice = 0;
diag.NWithNTS = 0;
diag.NFiniteBoth = 0;

Tn = DS.TableQuery(["Mouse","DateTime"], Phase="Naive",  Stimulus=stimulusName);
Tl = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus=stimulusName);
if isempty(Tn) || isempty(Tl)
	perMouse = table(string.empty(0,1), nan(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','Naive','Learned','Source'});
	return
end

Tn.Mouse = string(Tn.Mouse);
Tl.Mouse = string(Tl.Mouse);
Tn.DateTime = datetime(Tn.DateTime); try, Tn.DateTime.TimeZone = ''; catch, end
Tl.DateTime = datetime(Tl.DateTime); try, Tl.DateTime.TimeZone = ''; catch, end

mice = intersect(unique(Tn.Mouse), unique(Tl.Mouse));
diag.NCandidateMice = numel(mice);
if isempty(mice)
	perMouse = table(string.empty(0,1), nan(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','Naive','Learned','Source'});
	return
end

naiveDt = NaT(numel(mice),1);
learnDt = NaT(numel(mice),1);
for i = 1:numel(mice)
	m = mice(i);
	naiveDt(i) = min(Tn.DateTime(Tn.Mouse == m));
	learnDt(i) = max(Tl.DateTime(Tl.Mouse == m));
end

naiveDiv = nan(numel(mice),1);
learnDiv = nan(numel(mice),1);
hasNts = false(numel(mice),1);

for i = 1:numel(mice)
	m = mice(i);
	nts = iQueryNtsOnce(DS, stimulusName, m);
	if isempty(nts)
		continue
	end
	hasNts(i) = true;
	naiveDiv(i) = iDivergenceForMouseSession(DS, nts, "Naive", stimulusName, m, naiveDt(i));
	learnDiv(i) = iDivergenceForMouseSession(DS, nts, "Learned", stimulusName, m, learnDt(i));
end

diag.NWithNTS = sum(hasNts);
keep = isfinite(naiveDiv) & isfinite(learnDiv);
diag.NFiniteBoth = sum(keep);

perMouse = table(mice(keep), naiveDiv(keep), learnDiv(keep), repmat(string(sourceName), sum(keep), 1), ...
	'VariableNames', {'Mouse','Naive','Learned','Source'});
end

function [miceOut, naiveOut, learnedOut, nSourceOut] = iCollapsePairedByMouse(T)
% Collapse duplicates by mouse using mean for Naive/Learned separately.
T.Mouse = string(T.Mouse);
[G, miceOut] = findgroups(T.Mouse);
naiveOut = splitapply(@(x) mean(x,'omitnan'), T.Naive, G);
learnedOut = splitapply(@(x) mean(x,'omitnan'), T.Learned, G);
nSourceOut = splitapply(@(x) numel(unique(string(x))), T.Source, G);

keep = isfinite(naiveOut) & isfinite(learnedOut);
miceOut = miceOut(keep);
naiveOut = naiveOut(keep);
learnedOut = learnedOut(keep);
nSourceOut = nSourceOut(keep);
end

function nts = iQueryNtsOnce(DS, stimulusName, mouseId)
nts = [];
try
	ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Mouse', string(mouseId)), UniExp.Flags.DeltaF, 1:24);
	if iscell(ntsCell) && ~isempty(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
catch
	nts = [];
end
end

function div = iDivergenceForMouseSession(DS, nts, phaseName, stimulusName, mouseId, sessionDateTime)
% Build Cell x Trial x Time tensor for one mouse/session, then compute divergence.

try
	T = DS.TableQuery(["TrialUID","TrialIndex"], Phase=phaseName, Stimulus=stimulusName, Mouse=mouseId, DateTime=sessionDateTime);
catch
	div = nan;
	return
end

if isempty(T)
	div = nan;
	return
end

T = sortrows(T, "TrialIndex");
trialUIDs = uint64(T.TrialUID);
trialUIDs = unique(trialUIDs(:), 'stable');

try
	inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
	nts2 = nts(inTrial, :);
catch
	div = nan;
	return
end

if isempty(nts2)
	div = nan;
	return
end

% Only keep trials that actually exist in NTS for this session.
% (Some datasets may have behavior-only trials in TableQuery without calcium signals.)
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2
	div = nan;
	return
end

cellUIDs = unique(uint64(nts2.CellUID));
cellTraces = cell(0,1);
for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	rowsC = (uint64(nts2.CellUID) == cid);
	if sum(rowsC) < numel(trialUIDs)
		continue
	end

	uid = uint64(nts2.TrialUID(rowsC));
	sig = double(nts2.TrialSignal(rowsC, :));

	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue
	end

	sigOrdered = sig(loc, :);
	if any(~isfinite(sigOrdered), 'all')
		continue
	end
	cellTraces{end+1,1} = sigOrdered; %#ok<AGROW>
end

if isempty(cellTraces)
	div = nan;
	return
end

nCells = numel(cellTraces);
nTrials = size(cellTraces{1}, 1);
nTime = size(cellTraces{1}, 2);
CellTrialTimes = nan(nCells, nTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC,:,:) = cellTraces{iC};
end

div = TransferLearning.Divergence(CellTrialTimes);
end
