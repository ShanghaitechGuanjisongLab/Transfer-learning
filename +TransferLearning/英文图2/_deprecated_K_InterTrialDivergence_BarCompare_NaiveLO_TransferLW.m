% [DEPRECATED] v6 设计文档已移除此面板（p=0.089 不显著）
%
% 英文图2K：Inter-trial divergence Bar compare（Naive LightOnly vs Transfer LightWater）
%
% Divergence per mouse, unpaired comparison (different cohorts):
%   - Naive LightOnly: LightAudioBaseline + LAInterspersed, Phase=Naive, Stimulus=LightOnly
%   - Transfer LightWater: AudioLightBaseline, Phase=Transfer, Stimulus=LightWater
%
% Plot: UniExp.BarScatterCompare, Wilcoxon rank-sum (unpaired)
%
% Execution:
%   TransferLearning.英文图2.K_InterTrialDivergence_BarCompare_NaiveLO_TransferLW

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig2K_InterTrialDivergence_BarCompare_NaiveLO_TransferLW.svg";

baselineSec = 0;
useCellFilter = true;

% --- 1) Datasets
% Naive LightOnly sources
SourcesNaive = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
	builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};
% Transfer LightWater source
SourcesTransfer = {
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
};

% --- 2) Compute per-mouse divergence
% Naive LightOnly
naivePerMouse = cell(size(SourcesNaive));
for iS = 1:numel(SourcesNaive)
	naivePerMouse{iS} = iPerSourceDivergence( ...
		SourcesNaive{iS}.DS, SourcesNaive{iS}.Name, ...
		"Naive", "LightOnly", baselineSec, useCellFilter);
end
allNaive = vertcat(naivePerMouse{:});

% Transfer LightWater
transferPerMouse = cell(size(SourcesTransfer));
for iS = 1:numel(SourcesTransfer)
	transferPerMouse{iS} = iPerSourceDivergence( ...
		SourcesTransfer{iS}.DS, SourcesTransfer{iS}.Name, ...
		"Transfer", "LightWater", baselineSec, useCellFilter);
end
allTransfer = vertcat(transferPerMouse{:});

% Collapse by mouse (average across sources if duplicated)
[miceN, divN] = iCollapseByMouse(allNaive);
[miceT, divT] = iCollapseByMouse(allTransfer);

keepN = isfinite(divN);
keepT = isfinite(divT);
divNaive = divN(keepN);
divTransfer = divT(keepT);

fprintf('Fig2K: Naive LightOnly mice=%d, Transfer LightWater mice=%d\n', numel(divNaive), numel(divTransfer));

if isempty(divNaive) || isempty(divTransfer)
	error('Fig2K:Empty', 'Not enough mice.');
end

% Stats (unpaired, different cohorts)
pRankSum = ranksum(divNaive, divTransfer);
fprintf('Wilcoxon rank-sum (unpaired): Naive LO vs Transfer LW: p=%.6g\n', pRankSum);

%% --- 3) Plot
DataCell = {divNaive, divTransfer};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'English Fig2K Inter-trial divergence');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];

tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';

ax.XTick = [1, 2];
ax.XTickLabel = {'Naive💡', '💡💧Trans.'};
legend(ax, 'off');

% Set asterisk font size
if isfield(Optional, 'MultiCompare') && ismember('PText', Optional.MultiCompare.Properties.VariableNames)
	for pt = Optional.MultiCompare.PText(:)'
		pt.FontSize = 6;
	end
end

% Bar styling
colorNaive = [1 0 0];
colorTransfer = [0 0 1];
if numel(Bars) == 1
	Bars.FaceColor = 'flat';
	nBars = numel(Bars.YData);
	reps = ceil(nBars/2);
	Bars.CData = repmat([colorNaive; colorTransfer], reps, 1);
	Bars.CData = Bars.CData(1:nBars, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 0.5;
	Bars.FaceAlpha = 1/3;
else
	if numel(Bars) >= 2
		Bars(1).FaceColor = colorNaive;
		Bars(2).FaceColor = colorTransfer;
		for b = Bars(:)'
			b.LineWidth = 0.5;
			b.FaceAlpha = 1/3;
		end
	end
end

for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end

ylabel(ax, 'Divergence', 'FontSize', 6);
box(ax, 'off');
ax.Toolbar.Visible = 'off';

% --- 4) Export
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

Summary = table;
Summary.Group = ["NaiveLO"; "TransferLW"];
Summary.N = [numel(divNaive); numel(divTransfer)];
Summary.Mean = [mean(divNaive,'omitnan'); mean(divTransfer,'omitnan')];
Summary.SEM = [std(divNaive,'omitnan')/sqrt(numel(divNaive)); std(divTransfer,'omitnan')/sqrt(numel(divTransfer))];
Summary.P_RankSum = repmat(pRankSum, 2, 1);
assignin('base', 'Fig2K_Summary', Summary);

%% === Local helpers ===

function perMouse = iPerSourceDivergence(DS, sourceName, phaseName, stimulusName, baselineSec, useCellFilter)
% Compute per-mouse divergence for one source/phase/stimulus.

T = DS.TableQuery(["Mouse","DateTime"], Phase=phaseName, Stimulus=stimulusName);
if isempty(T)
	perMouse = table(string.empty(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','Divergence','Source'});
	return
end
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
try T.DateTime.TimeZone = ''; catch, end

mice = unique(T.Mouse);
divVec = nan(numel(mice), 1);

for i = 1:numel(mice)
	m = mice(i);
	dts = T.DateTime(T.Mouse == m);
	% Pick last session for this phase
	sessionDt = max(dts);

	% Get NTS
	nts = iQueryNtsOnce(DS, stimulusName, m);
	if isempty(nts), continue; end

	% Get trial UIDs for this session
	[trialUIDs, nts2] = iPrepareSessionTrials(DS, nts, phaseName, stimulusName, m, sessionDt);
	if isempty(trialUIDs) || isempty(nts2), continue; end

	% Cell filter
	if useCellFilter
		ntatsG = iQueryNtatsSession(DS, stimulusName, m, phaseName, sessionDt);
		keepUids = iSelectLatePeakCells(ntatsG);
	else
		keepUids = unique(uint64(nts2.CellUID));
	end
	if isempty(keepUids), continue; end

	divVec(i) = iDivergenceForMouseSession(nts2, trialUIDs, keepUids, baselineSec);
end

keep = isfinite(divVec);
perMouse = table(mice(keep), divVec(keep), repmat(string(sourceName), sum(keep), 1), ...
	'VariableNames', {'Mouse','Divergence','Source'});
fprintf('%s %s %s: %d/%d mice with finite divergence\n', sourceName, phaseName, stimulusName, sum(keep), numel(mice));
end

function [miceOut, divOut] = iCollapseByMouse(T)
if isempty(T)
	miceOut = string.empty(0,1);
	divOut = nan(0,1);
	return
end
T.Mouse = string(T.Mouse);
[G, miceOut] = findgroups(T.Mouse);
divOut = splitapply(@(x) mean(x,'omitnan'), T.Divergence, G);
end

function nts = iQueryNtsOnce(DS, stimulusName, mouseId)
nts = [];
ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Mouse', string(mouseId)), UniExp.Flags.DeltaF, 1:24);
if iscell(ntsCell) && ~isempty(ntsCell)
	nts = ntsCell{1};
else
	nts = ntsCell;
end
end

function ntatsGroup = iQueryNtatsSession(DS, stimulusName, mouseId, phaseName, sessionDateTime)
ntatsGroup = [];
queryStruct = struct('Stimulus', string(stimulusName), 'Phase', string(phaseName), 'Mouse', string(mouseId), 'DateTime', sessionDateTime);
ntatsGroup = DS.QueryNTATS(queryStruct, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
end

function [trialUIDs, nts2] = iPrepareSessionTrials(DS, nts, phaseName, stimulusName, mouseId, sessionDateTime)
trialUIDs = uint64([]);
nts2 = [];
T = DS.TableQuery(["TrialUID","TrialIndex"], Phase=phaseName, Stimulus=stimulusName, Mouse=mouseId, DateTime=sessionDateTime);
if isempty(T), return; end
T = sortrows(T, "TrialIndex");
trialUIDs = uint64(T.TrialUID);
trialUIDs = unique(trialUIDs(:), 'stable');
inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial, :);
if isempty(nts2)
	trialUIDs = uint64([]);
	return
end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2
	trialUIDs = uint64([]);
	nts2 = [];
end
end

function keepUids = iSelectLatePeakCells(ntatsGroup)
keepUids = uint64([]);
if isempty(ntatsGroup) || height(ntatsGroup) == 0, return; end
data = squeeze(ntatsGroup.NTATS{:,:,1});
if ~ismatrix(data), return; end
cellUIDs = uint64(ntatsGroup.CellUID);
sampleRate = 8;
idxCue0 = 3 * sampleRate;
idx0 = max(1, min(size(data, 2), idxCue0));
sigNtats = data - data(:, idx0);
idx0_1 = idxCue0:(idxCue0 + sampleRate);
idx1_2 = (idxCue0 + sampleRate):(idxCue0 + 2 * sampleRate);
idx0_1 = idx0_1(idx0_1 >= 1 & idx0_1 <= size(sigNtats, 2));
idx1_2 = idx1_2(idx1_2 >= 1 & idx1_2 <= size(sigNtats, 2));
if isempty(idx0_1) || isempty(idx1_2), return; end
peak0_1 = max(sigNtats(:, idx0_1), [], 2);
peak1_2 = max(sigNtats(:, idx1_2), [], 2);
keepUids = cellUIDs(peak1_2 > peak0_1);
end

function div = iDivergenceForMouseSession(nts2, trialUIDs, keepUids, baselineSec)
div = nan;
if isempty(trialUIDs) || isempty(nts2) || isempty(keepUids), return; end

cellUIDs = unique(uint64(nts2.CellUID));
cellUIDs = cellUIDs(ismember(cellUIDs, uint64(keepUids)));
if isempty(cellUIDs), return; end

cellTraces = cell(0,1);
for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	rowsC = (uint64(nts2.CellUID) == cid);
	if sum(rowsC) < numel(trialUIDs), continue; end
	uid = uint64(nts2.TrialUID(rowsC));
	sig = double(nts2.TrialSignal(rowsC, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf), continue; end
	sigOrdered = sig(loc, :);
	if any(~isfinite(sigOrdered), 'all'), continue; end
	cellTraces{end+1, 1} = sigOrdered; %#ok<AGROW>
end

if isempty(cellTraces), return; end

nCells = numel(cellTraces);
nTrials = size(cellTraces{1}, 1);
nTime = size(cellTraces{1}, 2);
CellTrialTimes = nan(nCells, nTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC,:,:) = cellTraces{iC};
end

sampleRate = 8;
idx0 = 3 * sampleRate + round(baselineSec * sampleRate);
idx0 = max(1, min(nTime, idx0));
baseline0 = CellTrialTimes(:,:,idx0);
CellTrialTimes = CellTrialTimes - baseline0;

div = TransferLearning.Divergence(CellTrialTimes);
end
