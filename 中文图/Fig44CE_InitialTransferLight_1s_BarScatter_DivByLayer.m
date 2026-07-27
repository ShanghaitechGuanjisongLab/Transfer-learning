% Combined Chinese Fig44C/E: initial-vs-Transfer 1 s bars and divergence-by-layer bars.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

barColors = [TransferLearning.NaiveColor; TransferLearning.TransferColor];
compareGroup = table([1 2], 'VariableNames', {'GroupPair'});

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
[idx0s, ok0s] = iFindTimeIndex(xsSec, 0, 0.25);
if ~ok0s
	error('Fig44CE:No0s', 'Cannot find sample close to 0s.');
end
[idx1sZ, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig44CE:No1s', 'Cannot find sample close to 1s.');
end
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[GInitial, initialStats] = iQueryInitialLightAll();
[GTransfer, transferStats] = iQueryTransferLightAll();
XInitial = iGetNtats2D(GInitial);
XTransfer = iGetNtats2D(GTransfer);
XInitial = iZeroAnchorZScore(XInitial, idx0s);
XTransfer = iZeroAnchorZScore(XTransfer, idx0s);
vInitial = XInitial(:, idx1sZ);
vTransfer = XTransfer(:, idx1sZ);
vInitial = vInitial(isfinite(vInitial));
vTransfer = vTransfer(isfinite(vTransfer));

activeNaive = iActiveMask(XInitial, idx1sZ, baseMask, kSigma);
activeTransfer = iActiveMask(XTransfer, idx1sZ, baseMask, kSigma);
nNaive = size(XInitial, 1);
nTransfer = size(XTransfer, 1);
nNaiveActive = sum(activeNaive);
nTransferActive = sum(activeTransfer);

sampleRate = 8;
idx1sDiv = 4 * sampleRate;
sources = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline(), 'Group', "Naive", 'StartPhase', "Naive")
	builtin('struct', 'Name', "LAInterspersed", 'DS', TransferLearning.LAInterspersed(), 'Group', "Naive", 'StartPhase', "Naive")
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline(), 'Group', "Transfer", 'StartPhase', "Transfer")
};

divRows = cell(numel(sources), 1);
for iS = 1:numel(sources)
	divRows{iS} = iBuildStartSessionDivergenceRows(sources{iS}, idx1sDiv, sampleRate);
end

divTable = vertcat(divRows{:});
if isempty(divTable)
	error('Fig44CE:EmptyDivergenceData', 'No valid LightWater sessions found for divergence panels.');
end

[divGroup, mouseU, groupU] = findgroups(string(divTable.Mouse), string(divTable.Group));
aggL23 = splitapply(@(x) mean(x, 'omitnan'), divTable.DivL23, divGroup);
aggL5 = splitapply(@(x) mean(x, 'omitnan'), divTable.DivL5, divGroup);
aggCellL23 = splitapply(@iSumFinite, divTable.NCellL23, divGroup);
aggCellL5 = splitapply(@iSumFinite, divTable.NCellL5, divGroup);
divSummary = table(mouseU, groupU, aggL23, aggL5, aggCellL23, aggCellL5, ...
	'VariableNames', {'Mouse','Group','DivL23','DivL5','NCellL23','NCellL5'});

maskNaiveL23 = divSummary.Group == "Naive" & isfinite(divSummary.DivL23);
maskTransferL23 = divSummary.Group == "Transfer" & isfinite(divSummary.DivL23);
maskNaiveL5 = divSummary.Group == "Naive" & isfinite(divSummary.DivL5);
maskTransferL5 = divSummary.Group == "Transfer" & isfinite(divSummary.DivL5);

naiveL23 = divSummary.DivL23(maskNaiveL23);
TransferL23 = divSummary.DivL23(maskTransferL23);
naiveL5 = divSummary.DivL5(maskNaiveL5);
TransferL5 = divSummary.DivL5(maskTransferL5);

nCellNaiveL23 = iSumFinite(divSummary.NCellL23(maskNaiveL23));
nCellTransferL23 = iSumFinite(divSummary.NCellL23(maskTransferL23));
nCellNaiveL5 = iSumFinite(divSummary.NCellL5(maskNaiveL5));
nCellTransferL5 = iSumFinite(divSummary.NCellL5(maskTransferL5));

if isempty(naiveL23) || isempty(TransferL23) || isempty(naiveL5) || isempty(TransferL5)
	error('Fig44CE:InsufficientDivergenceData', 'At least one LightWater layer comparison is empty.');
end
%% 

f = figure('Color', 'w', 'Name', 'Chinese Fig44CE Initial/Transfer LightWater bars');
f.Units = 'centimeters';
f.Position(3:4) = [4, 16];

layout = tiledlayout(f, 4, 1, 'TileSpacing','tight', 'Padding', 'tight');

axZ = nexttile(layout, 1);
[~, optZ, barsZ, errZ] = UniExp.BarScatterCompare({double(vInitial(:)), double(vTransfer(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optZ);
iStyleBarPanel(axZ, optZ, barsZ, errZ, barColors, 'z-score', '1 s z-score');
[pCTop, tCTop] = iExtractFirstPValueAndText(optZ);

axActive = nexttile(layout, 2);
[~, optActive, barsActive, errActive] = UniExp.BarScatterCompare({double(activeNaive(:)), double(activeTransfer(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optActive);
iStyleBarPanel(axActive, optActive, barsActive, errActive, barColors, 'Active fraction', 'Active fraction');
ylim(axActive, [0, max(0.1, axActive.YLim(2))]);
[pCBottom, tCBottom] = iExtractFirstPValueAndText(optActive);

axL23 = nexttile(layout, 3);
[~, optL23, barsL23, errL23] = UniExp.BarScatterCompare({double(naiveL23(:)), double(TransferL23(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optL23);
iStyleBarPanel(axL23, optL23, barsL23, errL23, barColors, 'Divergence', 'Layer 2/3');
[pETop, tETop] = iExtractFirstPValueAndText(optL23);

axL5 = nexttile(layout, 4);
[~, optL5, barsL5, errL5] = UniExp.BarScatterCompare({double(naiveL5(:)), double(TransferL5(:))}, UniExp.Flags.empty, compareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 1);
TransferLearning.Style.SetBarPValues(optL5);
iStyleBarPanel(axL5, optL5, barsL5, errL5, barColors, 'Divergence', 'Layer 5');
[pEBottom, tEBottom] = iExtractFirstPValueAndText(optL5);

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig44CE_InitialTransferLight_1s_BarScatter_DivByLayer.svg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== Fig44CE initial/Transfer LightWater bars ===\n');
fprintf('Naive 1s z-score: %d mice, %d cells\n', initialStats.MouseCount, initialStats.CellCount);
fprintf('Transfer 1s z-score: %d mice, %d cells\n', transferStats.MouseCount, transferStats.CellCount);
fprintf('C-top (1 s z-score): BarScatterCompare PValue=%.6g, PText="%s"\n', pCTop, tCTop);
fprintf('C-bottom (active fraction): BarScatterCompare PValue=%.6g, PText="%s"\n', pCBottom, tCBottom);
fprintf('E-top (Layer 2/3 divergence): Naive %d mice, %d cells; Transfer %d mice, %d cells; BarScatterCompare PValue=%.6g, PText="%s"\n', ...
	nnz(maskNaiveL23), nCellNaiveL23, nnz(maskTransferL23), nCellTransferL23, pETop, tETop);
fprintf('E-bottom (Layer 5 divergence): Naive %d mice, %d cells; Transfer %d mice, %d cells; BarScatterCompare PValue=%.6g, PText="%s"\n', ...
	nnz(maskNaiveL5), nCellNaiveL5, nnz(maskTransferL5), nCellTransferL5, pEBottom, tEBottom);

function [G, stats] = iQueryInitialLightAll()
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
qNaiveLW = struct('Phase', 'Naive', 'Stimulus', 'LightWater');
badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
qNaiveLWLAI = qNaiveLW;
qNaiveLWLAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badNaive);
G1 = LAB.QueryNTATS(qNaiveLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2 = LAI.QueryNTATS(qNaiveLWLAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G = iVcatNtatsTables(G1, G2);
stats = iGroupStats({G1, G2}, {LAB, LAI});
end

function [G, stats] = iQueryTransferLightAll()
ALB = TransferLearning.AudioLightBaseline();
qTransferLW = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
G = ALB.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
stats = iGroupStats({G}, {ALB});
end

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
if isempty(T)
	mice = string.empty(0, 1);
	return;
end
mice = unique(string(T.Mouse));
mice = mice(~ismember(mice, string(excludeMice(:))));
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
if isempty(T)
	badMice = strings(0, 1);
	return;
end
trials = DS.Trials;
trialStimulus = string(trials.Stimulus);
trialBlockUID = uint64(trials.BlockUID);
T.Mouse = string(T.Mouse);
blockUID = uint64(T.BlockUID);
mice = unique(T.Mouse);
bad = false(size(mice));
for iM = 1:numel(mice)
	mouseBlockUID = blockUID(T.Mouse == mice(iM));
	rows = ismember(trialBlockUID, mouseBlockUID);
	bad(iM) = any(trialStimulus(rows) == "AudioWater");
end
badMice = mice(bad);
end

function G = iVcatNtatsTables(G1, G2)
if isempty(G1)
	G = G2;
elseif isempty(G2)
	G = G1;
else
	G = [G1; G2];
end
end

function stats = iGroupStats(groupTables, dataSets)
cellCount = 0;
mouseNames = strings(0, 1);
for iGroup = 1:numel(groupTables)
	G = groupTables{iGroup};
	if isempty(G)
		continue;
	end
	cellCount = cellCount + height(G);
	cellMeta = dataSets{iGroup}.Cells(:, ["CellUID", "Mouse"]);
	cellMeta.Mouse = string(cellMeta.Mouse);
	[matched, loc] = ismember(uint64(G.CellUID), uint64(cellMeta.CellUID));
	mouseNames = [mouseNames; cellMeta.Mouse(loc(matched))]; %#ok<AGROW>
end
mouseNames = unique(mouseNames(~ismissing(mouseNames) & strlength(mouseNames) > 0), 'stable');
stats = struct('MouseCount', numel(mouseNames), 'CellCount', cellCount, 'MouseNames', mouseNames);
end

function X = iGetNtats2D(G)
if istable(G)
	nt = G.NTATS;
else
	nt = G;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = double(nt.Data);
	return;
end
if isnumeric(nt) && ismatrix(nt)
	X = double(nt);
	return;
end
error('Fig44CE:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function X = iZeroAnchorZScore(X, idx0s)
X = X - X(:, idx0s);
end

function [idx, ok] = iFindTimeIndex(xsSec, timeSec, tolSec)
[distance, idx] = min(abs(xsSec(:) - timeSec));
ok = isfinite(distance) && (distance <= tolSec);
end

function mask = iActiveMask(X, idx1s, baseMask, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
mask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end

function out = iBuildStartSessionDivergenceRows(spec, idx1s, sampleRate)
DS = spec.DS;
groupName = string(spec.Group);
startPhase = string(spec.StartPhase);

T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Phase","Stimulus","BlockUID"]);
if isempty(T)
	out = table();
	return;
end

T.Mouse = string(T.Mouse);
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);
T.DateTime = iNormalizeDateTime(T.DateTime);

cellTbl = DS.Cells;
cellTbl.Mouse = string(cellTbl.Mouse);
cellTbl.CellUID = uint64(cellTbl.CellUID);
cellTbl.ZLayer = string(cellTbl.ZLayer);

mice = unique(T.Mouse);
selectedMouse = strings(0, 1);
selectedDateTime = NaT(0, 1);
trialSets = cell(0, 1);

for iM = 1:numel(mice)
	mouseName = mice(iM);
	Tm = T(T.Mouse == mouseName, :);
	startRows = Tm(Tm.Phase == startPhase & Tm.Stimulus == "LightWater", :);
	if isempty(startRows)
		continue;
	end
	startDateTime = min(startRows.DateTime);
	sessionRows = Tm(Tm.DateTime == startDateTime, :);
	if any(sessionRows.Stimulus == "AudioWater")
		continue;
	end
	lightWaterRows = sortrows(sessionRows(sessionRows.Stimulus == "LightWater", :), 'TrialIndex');
	trialUIDs = unique(uint64(lightWaterRows.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	selectedMouse(end+1, 1) = mouseName; %#ok<AGROW>
	selectedDateTime(end+1, 1) = startDateTime; %#ok<AGROW>
	trialSets{end+1, 1} = trialUIDs; %#ok<AGROW>
end

if isempty(selectedMouse)
	out = table();
	return;
end

queryTable = table(selectedMouse, selectedDateTime, repmat("LightWater", numel(selectedMouse), 1), ...
	'VariableNames', {'Mouse','DateTime','Stimulus'});
ntsRaw = iQueryNtsRows(DS, queryTable);
if isempty(ntsRaw)
	out = table();
	return;
end

ntsRaw.Mouse = string(ntsRaw.Mouse);
ntsRaw.DateTime = iNormalizeDateTime(ntsRaw.DateTime);
ntsRaw.CellUID = uint64(ntsRaw.CellUID);
ntsRaw.TrialUID = uint64(ntsRaw.TrialUID);

nSession = numel(selectedMouse);
divL23 = nan(nSession, 1);
divL5 = nan(nSession, 1);
nCellL23 = zeros(nSession, 1);
nCellL5 = zeros(nSession, 1);
for iSession = 1:nSession
	mouseName = selectedMouse(iSession);
	dateTime = selectedDateTime(iSession);
	rawRows = ntsRaw(ntsRaw.Mouse == mouseName & ntsRaw.DateTime == dateTime, :);
	if isempty(rawRows)
		continue;
	end
	[CTT, cellUIDs] = iBuildCttFromRows(rawRows, trialSets{iSession}, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3
		continue;
	end
	X = CTT(:, :, idx1s);
	cellMeta = cellTbl(cellTbl.Mouse == mouseName, {'CellUID','ZLayer'});
	[matched, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs), 1);
	layers(matched) = cellMeta.ZLayer(loc(matched));
	mask23 = layers == "MOp2/3";
	mask5 = layers == "MOp5";
	if sum(mask23) >= 3
		nCellL23(iSession) = sum(mask23);
		divL23(iSession) = iDivFromX(X(mask23, :));
	end
	if sum(mask5) >= 3
		nCellL5(iSession) = sum(mask5);
		divL5(iSession) = iDivFromX(X(mask5, :));
	end
end

out = table(selectedMouse, repmat(groupName, nSession, 1), selectedDateTime, divL23, divL5, nCellL23, nCellL5, ...
	'VariableNames', {'Mouse','Group','DateTime','DivL23','DivL5','NCellL23','NCellL5'});
end

function total = iSumFinite(values)
values = values(isfinite(values));
total = sum(values);
end

function ntsRaw = iQueryNtsRows(DS, queryTable)
parts = cell(height(queryTable), 1);
for iRow = 1:height(queryTable)
	queryRow = queryTable(iRow, :);
	res = DS.QueryNTS(queryRow, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime","Mouse"]);
	parts{iRow} = iCollapseNtsResult(res);
end
parts = parts(~cellfun(@isempty, parts));
if isempty(parts)
	ntsRaw = table();
else
	ntsRaw = vertcat(parts{:});
end
end

function tbl = iCollapseNtsResult(res)
tbl = table();
if isempty(res)
	return;
end
if istable(res)
	tbl = res;
	return;
end
if iscell(res)
	parts = res(~cellfun(@isempty, res));
	if isempty(parts)
		return;
	end
	if istable(parts{1})
		tbl = vertcat(parts{:});
	end
end
end

function [CTT, cellUIDs] = iBuildCttFromRows(rawRows, trialUIDs, sampleRate)
CTT = [];
cellUIDs = uint64([]);
if isempty(rawRows) || numel(trialUIDs) < 2
	return;
end

rawRows = rawRows(ismember(uint64(rawRows.TrialUID), trialUIDs), :);
if isempty(rawRows)
	return;
end

allCells = unique(uint64(rawRows.CellUID));
traces = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cellUID = allCells(iC);
	rows = uint64(rawRows.CellUID) == cellUID;
	rowTrialUID = uint64(rawRows.TrialUID(rows));
	signal = double(rawRows.TrialSignal(rows, :));
	[matched, loc] = ismember(trialUIDs, rowTrialUID);
	if ~all(matched)
		continue;
	end
	orderedSignal = signal(loc, :);
	if size(orderedSignal, 2) < sampleRate || any(~isfinite(orderedSignal), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = orderedSignal;
	keepUID(nKeep) = cellUID;
end

if nKeep < 3
	return;
end

traces = traces(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = numel(trialUIDs);
nTime = size(traces{1}, 2);
CTT = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, nTrial, nTime);
end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function dateTime = iNormalizeDateTime(dateTime)
dateTime = datetime(dateTime);
if isdatetime(dateTime) && ~isempty(dateTime.TimeZone)
	dateTime.TimeZone = '';
end
end

function iStyleBarPanel(ax, optional, Bars, ErrorBars, colors, yLabelText, titleText)
iTagPValueObjects(optional);
delete(findobj(ax, 'Type', 'Scatter'));
iStyleAxes(ax, yLabelText, titleText);
iStyleBars(Bars, colors(1, :), colors(2, :));
iStyleErrorBars(ErrorBars, colors);
end

function iStyleAxes(ax, yLabelText, titleText)
ax.XTick = [1 2];
ax.XTickLabel = {'Naive', '  Transfer'};%Transfer前缀空格用来规避MATLAB的自动排版bug
ylabel(ax, yLabelText);
title(ax, titleText);
box(ax, 'off');
end

function iStyleBars(Bars, colorA, colorB)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nBar = numel(Bars.YData);
	Bars.CData = repmat([colorA; colorB], ceil(nBar / 2), 1);
	Bars.CData = Bars.CData(1:nBar, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.Visible = 'off';
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
	return;
end
if numel(Bars) >= 2
	Bars(1).FaceColor = colorA;
	Bars(2).FaceColor = colorB;
	Bars(1).BarWidth = 0.5;
	Bars(2).BarWidth = 0.5;
	Bars(1).FaceAlpha = 1;
	Bars(2).FaceAlpha = 1;
	Bars(1).LineWidth = 1;
	Bars(2).LineWidth = 1;
	Bars(1).BaseLine.Visible = 'off';
	Bars(2).BaseLine.Visible = 'off';
	Bars(1).EdgeColor = 'none';
	Bars(2).EdgeColor = 'none';
end
end

function iStyleErrorBars(ErrorBars, colors)
for iE = 1:height(ErrorBars)
	errorBar = ErrorBars.Object(iE);
	errorBar.LineWidth = 1;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
	if isprop(errorBar, 'LineStyle')
		errorBar.LineStyle = 'none';
	end
	if isprop(errorBar, 'CapSize')
		errorBar.CapSize = 7;
	end
end
end

function [pValue, pText] = iExtractFirstPValueAndText(options)
pValue = NaN;
pText = "";
if isfield(options, 'MultiCompare') && istable(options.MultiCompare) && ismember('PValue', options.MultiCompare.Properties.VariableNames) && ~isempty(options.MultiCompare.PValue)
	pValue = options.MultiCompare.PValue(1);
	if ismember('PText', options.MultiCompare.Properties.VariableNames) && ~isempty(options.MultiCompare.PText)
		pTextObj = options.MultiCompare.PText(1);
		if isgraphics(pTextObj) && isprop(pTextObj, 'String')
			pText = string(pTextObj.String);
		end
	end
end
end

function iTagPValueObjects(optional)
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
multiCompare = optional.MultiCompare;
if ismember('PLine', multiCompare.Properties.VariableNames)
	for pLine = multiCompare.PLine(:)'
		if isgraphics(pLine)
			pLine.Tag = 'PLine';
			pLine.LineWidth = 1;
		end
	end
end
if ismember('PText', multiCompare.Properties.VariableNames)
	for pText = multiCompare.PText(:)'
		if isgraphics(pText)
			pText.Tag = 'PText';
			pText.FontName = 'Arial';
			pText.FontSize = 6;
		end
	end
end
end