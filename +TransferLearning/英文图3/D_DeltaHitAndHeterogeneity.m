% English Fig3D: Naive / Learned AudioWater / Transfer — response heterogeneity by layer
%
% Two vertical tiles comparing three cohorts:
%   Top:    L2/3 response heterogeneity
%   Bottom: L5 response heterogeneity
%
% Metric per mouse (avg-first):
%   per-cell per-session median z@1s -> per-cell mean across used sessions
%   -> filter to [-1,1] -> std across cells
%
% Naive:           LightAudioBaseline + LAInterspersed (Naive→Learned)
% Learned Audio:   AudioLightBaseline (AudioWater, Learned)
% Transfer:        AudioLightBaseline (Transfer→Final, LightWater)
%
% Execution:
%   TransferLearning.英文图3.D_DeltaHitAndHeterogeneity

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS_NaiveLAB = TransferLearning.LightAudioBaseline();
DS_NaiveLAI = TransferLearning.LAInterspersed();
DS_Transfer = TransferLearning.AudioLightBaseline();
CellLAB = iDCellLayerTable(DS_NaiveLAB, "LAB");
CellLAI = iDCellLayerTable(DS_NaiveLAI, "LAI");
CellTransfer = iDCellLayerTable(DS_Transfer, "Transfer");

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('Fig3D:No1s', 'Cannot find sample close to 1s.'); end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];

[naiveTbl, naiveMice] = iDNaiveMouseAvgSDByLayer(DS_NaiveLAB, DS_NaiveLAI, CellLAB, CellLAI, idx1s, layers);
[learnedTbl, learnedMice] = iDLearnedAudioMouseAvgSDByLayer(DS_Transfer, CellTransfer, idx1s, layers);
[transferTbl, transferMice] = iDTransferMouseAvgSDByLayer(DS_Transfer, CellTransfer, idx1s, "Transfer", "Final", layers);

fprintf('Naive mice with layer values: %d\n', numel(unique(naiveMice)));
fprintf('Learned AudioWater mice with layer values: %d\n', numel(unique(learnedMice)));
fprintf('Transfer mice with layer values: %d\n', numel(unique(transferMice)));
%% 

% --- Figure: 2×1 tiledlayout
f = figure('Color', 'w', 'Name', 'Fig3D Response heterogeneity by layer');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(Layout, 'Response heterogeneity', 'FontSize', 6, 'FontWeight', 'normal');
pLineAll = gobjects(0, 1);
pTextAll = gobjects(0, 1);
axList = gobjects(2, 1);

palette3 = TransferLearning.FigurePalette(3);
colorNaive    = palette3(1,:);
colorTransfer = palette3(2,:);
colorLearned  = palette3(3,:);
CompareGroup = table([1 2; 3 2], 'VariableNames', {'GroupPair'});

for iL = 1:numel(layers)
	layerName = layers(iL);
	layerLabel = layerLabels(iL);
	valsN = naiveTbl.SD(naiveTbl.Layer == layerName);
	valsL = learnedTbl.SD(learnedTbl.Layer == layerName);
	valsT = transferTbl.SD(transferTbl.Layer == layerName);
	pValNT = iRanksumSafe(valsN, valsT);
	pValLT = iRanksumSafe(valsL, valsT);

	fprintf('\n=== %s ===\n', layerLabel);
	fprintf('Naive:    %.4f +- %.4f (n=%d mice)\n', mean(valsN), std(valsN)/sqrt(numel(valsN)), numel(valsN));
	fprintf('Learned:  %.4f +- %.4f (n=%d mice)\n', mean(valsL), std(valsL)/sqrt(numel(valsL)), numel(valsL));
	fprintf('Transfer: %.4f +- %.4f (n=%d mice)\n', mean(valsT), std(valsT)/sqrt(numel(valsT)), numel(valsT));
	fprintf('Naive vs Transfer ranksum p = %.6g\n', pValNT);
	fprintf('Learned AW vs Transfer ranksum p = %.6g\n', pValLT);

	nexttile(Layout, iL);
	[~, Opt, Bars, EB] = UniExp.BarScatterCompare({valsN, valsT, valsL}, false, CompareGroup, 'AsteriskThreshold', 0.05);
	for eb = EB.Object(:)', eb.LineWidth = 0.5; end
	ax = gca;
	axList(iL) = ax;
	ax.FontSize = 6;
	ax.XTick = [1 2 3];
	if iL == 1
		ax.XTickLabel = {};
	else
		ax.XTickLabel = {'Naive', 'Tran.', '🔊💧100%'};
	end
	ylabel(ax, layerLabel, 'FontSize', 6);
	legend(ax, 'off');
	box(ax, 'off');
	grid(ax, 'off');
	ax.Toolbar.Visible = 'off';
	if isscalar(Bars)
		Bars.FaceColor = 'flat';
		nB = numel(Bars.YData);
		Bars.CData = repmat([colorNaive; colorTransfer; colorLearned], ceil(nB/3), 1);
		Bars.CData = Bars.CData(1:nB, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	elseif numel(Bars) >= 3
		Bars(1).FaceColor = colorNaive;
		Bars(2).FaceColor = colorTransfer;
		Bars(3).FaceColor = colorLearned;
		for ib = 1:3
			Bars(ib).LineWidth = 0.5;
			try, Bars(ib).FaceAlpha = 1/3; catch, end
		end
	end
	if isfield(Opt, 'MultiCompare') && ismember('PText', Opt.MultiCompare.Properties.VariableNames)
		for pt = Opt.MultiCompare.PText(:)', pt.FontSize = 6; end
	end
	if isfield(Opt, 'MultiCompare') && istable(Opt.MultiCompare)
		if ismember('PLine', Opt.MultiCompare.Properties.VariableNames)
			pLine = Opt.MultiCompare.PLine;
			pLine = pLine(isgraphics(pLine));
			if ~isempty(pLine)
				pLineAll(end+1:end+numel(pLine), 1) = pLine(:); %#ok<AGROW>
			end
		end
		if ismember('PText', Opt.MultiCompare.Properties.VariableNames)
			pText = Opt.MultiCompare.PText;
			pText = pText(isgraphics(pText));
			if ~isempty(pText)
				pTextAll(end+1:end+numel(pText), 1) = pText(:); %#ok<AGROW>
			end
		end
	end
end

MATLAB.Graphics.UnifyAxesLims(axList, @ylim);
if ~isempty(pLineAll) || ~isempty(pTextAll)
	MATLAB.Graphics.PLineRetune(pLineAll, pTextAll);
end

% --- Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, 'English_Fig3D_DeltaHitAndHeterogeneity.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function [dhVec, sdVec] = iCohortData(DS, idx1s, phaseStart, phaseEnd)
% Returns:
%   dhVec: ΔHit per session pair (one element per adjacent pair)
%   sdVec: Response heterogeneity per session (one element per session)

Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);

if isempty(Sess)
	dhVec = []; sdVec = []; return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

% --- Session-pair ΔHit (ceiling-excluded) ---
mice = unique(string(Sess.Mouse));
dhVec = [];
allUsedDTs = datetime.empty(0,1);
for iM = 1:numel(mice)
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2, continue; end
	perf = double(R.Performance);
	dhVec = [dhVec; diff(perf)]; %#ok<AGROW>
	allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
end

% --- Session-level SD (per session, not averaged across mouse) ---
allUsedDTs = unique(allUsedDTs);
sdVec = [];
if isempty(allUsedDTs), return; end

q = struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs);
try
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
rawTbl = ntsCell{1};
rawTbl.CellUID  = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

% Per-cell per-session median
[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

% Compute SD per session
uDTs = unique(dtU1);
sdVec = nan(numel(uDTs), 1);
for iDT = 1:numel(uDTs)
	vals = med1s(dtU1 == uDTs(iDT));
	vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
	if numel(vals) >= 3, sdVec(iDT) = std(vals); end
end
sdVec = sdVec(isfinite(sdVec));
end

function [dhVec, sdVec, mice] = iNaiveMergedCohortData(DS_LAB, DS_LAI, idx1s)
% Naive 合并两个数据库来源，按学习过程规则筛选：
%   - Naive→Learned 日期范围（包含 missing phase）
%   - 排除含 AudioWater trial 的会话
%   - 排除首个 100% 及其后续会话

AllSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
AllSess = iExcludeAudioWaterSessions(AllSess, DS_LAB, DS_LAI);
AllSess = iExcludeCeilingNaive(AllSess);

[dhVec, SessUsed, mice] = iNaiveDeltaHitSessions(AllSess);
sdVec = iNaiveSessionSD(SessUsed, DS_LAB, DS_LAI, idx1s);
end

function [dhVec, SessUsed, mice] = iNaiveDeltaHitSessions(Sess)
if isempty(Sess)
	SessUsed = Sess;
	dhVec = [];
	mice = string.empty(0,1);
	return;
end

Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
dhVec = [];
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);

for iM = 1:numel(miceAll)
	m = miceAll(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	perf = double(R.Performance);
	if any(~isfinite(perf)), continue; end
	dhVec = [dhVec; diff(perf)]; %#ok<AGROW>
	keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
	keepMice(iM) = true;
end

SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function sdVec = iNaiveSessionSD(SessUsed, DS_LAB, DS_LAI, idx1s)
sdVec = [];
if isempty(SessUsed), return; end

rawParts = {};
for srcName = ["LAB"; "LAI"]'
	dts = unique(SessUsed.DateTime(SessUsed.Source == srcName));
	if isempty(dts), continue; end
	if srcName == "LAB"
		DS = DS_LAB;
	else
		DS = DS_LAI;
	end
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
			UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	catch
		continue;
	end
	if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
	part = ntsCell{1};
	part.CellUID = uint64(part.CellUID);
	part.DateTime = iNormDT(datetime(part.DateTime));
	part.Source = repmat(srcName, height(part), 1);
	rawParts{end+1} = part; %#ok<AGROW>
	end

	if isempty(rawParts), return; end
	rawTbl = vertcat(rawParts{:});
	sig = double(rawTbl.TrialSignal);
	z1s = sig(:, idx1s);

	[G1, cellU1, dtU1, srcU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
	med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

	mapTbl = SessUsed(:, {'DateTime','Source'});
	mapTbl.Source = string(mapTbl.Source);
	[~, iU] = unique(mapTbl(:, {'DateTime','Source'}), 'rows');
	mapTbl = mapTbl(iU, :);

	medTbl = table(cellU1, dtU1, srcU1, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
	medTbl = innerjoin(medTbl, mapTbl, 'Keys', {'DateTime','Source'});
	if isempty(medTbl), return; end

	[G2, ~, ~] = findgroups(medTbl.DateTime, medTbl.Source);
	sdPerSess = splitapply(@iSessionBoundedSD, medTbl.Med1s, G2);
	sdVec = sdPerSess(isfinite(sdPerSess));
end

function out = iSessionBoundedSD(vals)
vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
if numel(vals) >= 3
	out = std(vals);
else
	out = NaN;
end
end

function S = iDCellLayerTable(DS, sourceName)
S = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
S.Mouse = string(S.Mouse);
S.CellUID = uint64(S.CellUID);
S.ZLayer = string(S.ZLayer);
S.Source = repmat(string(sourceName), height(S), 1);
end

function [outTbl, miceOut] = iDTransferMouseAvgSDByLayer(DS, CellMap, idx1s, phaseStart, phaseEnd, layers)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
Sess = sortrows(Sess, {'Mouse','DateTime'});
[SessUsed, mice] = iDUsedTransferLikeSessions(Sess);
[outTbl, miceOut] = iDMouseAvgByLayerSingleSource(DS, CellMap, SessUsed, mice, idx1s, layers, "LightWater");
end

function [outTbl, miceOut] = iDLearnedAudioMouseAvgSDByLayer(DS, CellMap, idx1s, layers)
Sess = iAudioWaterSessions(DS);
Sess = Sess(string(Sess.Phase) == "Learned", :);
Sess = sortrows(Sess, {'Mouse','DateTime'});
mice = unique(string(Sess.Mouse));
[outTbl, miceOut] = iDMouseAvgByLayerSingleSource(DS, CellMap, Sess, mice, idx1s, layers, "AudioWater");
end

function [SessUsed, mice] = iDUsedTransferLikeSessions(Sess)
if isempty(Sess)
	SessUsed = Sess;
	mice = string.empty(0,1);
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2, continue; end
	keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
	keepMice(iM) = true;
	end
SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function [outTbl, miceOut] = iDNaiveMouseAvgSDByLayer(DS_LAB, DS_LAI, CellLAB, CellLAI, idx1s, layers)
AllSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
AllSess = iExcludeAudioWaterSessions(AllSess, DS_LAB, DS_LAI);
AllSess = iExcludeCeilingNaive(AllSess);
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[SessUsed, mice] = iDUsedNaiveSessions(AllSess);
[outTbl, miceOut] = iDMouseAvgByLayerMergedSources(DS_LAB, DS_LAI, CellLAB, CellLAI, SessUsed, mice, idx1s, layers);
end

function [SessUsed, mice] = iDUsedNaiveSessions(Sess)
if isempty(Sess)
	SessUsed = Sess;
	mice = string.empty(0,1);
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	perf = double(R.Performance);
	if any(~isfinite(perf)), continue; end
	keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
	keepMice(iM) = true;
	end
SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function [outTbl, miceOut] = iDMouseAvgByLayerSingleSource(DS, CellMap, SessUsed, miceIn, idx1s, layers, stimulusName)
outTbl = table(strings(0,1), strings(0,1), nan(0,1), 'VariableNames', {'Mouse','Layer','SD'});
miceOut = string.empty(0,1);
if isempty(SessUsed) || isempty(miceIn), return; end

dts = unique(SessUsed.DateTime);
try
	ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'DateTime', dts), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
rawTbl = iDAttachLayer(rawTbl, CellMap);
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

[G1, cellU1, dtU1, zLayer1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.ZLayer));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouse = SessUsed(:, {'DateTime','Mouse'});
dtMouse.Mouse = string(dtMouse.Mouse);
[~, iU] = unique(dtMouse.DateTime);
dtMouse = dtMouse(iU, :);

medTbl = table(cellU1, dtU1, zLayer1, med1s, 'VariableNames', {'CellUID','DateTime','ZLayer','Med1s'});
medTbl = innerjoin(medTbl, dtMouse, 'Keys', 'DateTime');

rows = [];
for iM = 1:numel(miceIn)
	for iL = 1:numel(layers)
		layerName = layers(iL);
		R = medTbl(string(medTbl.Mouse) == miceIn(iM) & string(medTbl.ZLayer) == layerName, :);
		if isempty(R), continue; end
		[~, ~, cellID] = unique(R.CellUID);
		meanPerCell = accumarray(cellID, R.Med1s, [], @mean);
		vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
		if numel(vals) >= 3
			rows = [rows; {miceIn(iM), layerName, std(vals)}]; %#ok<AGROW>
		end
	end
	end

if isempty(rows), return; end
outTbl = cell2table(rows, 'VariableNames', {'Mouse','Layer','SD'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
miceOut = unique(outTbl.Mouse);
end

function [outTbl, miceOut] = iDMouseAvgByLayerMergedSources(DS_LAB, DS_LAI, CellLAB, CellLAI, SessUsed, miceIn, idx1s, layers)
outTbl = table(strings(0,1), strings(0,1), nan(0,1), 'VariableNames', {'Mouse','Layer','SD'});
miceOut = string.empty(0,1);
if isempty(SessUsed) || isempty(miceIn), return; end

rawParts = {};
for iDS = 1:2
	if iDS == 1
		DS = DS_LAB;
		srcName = "LAB";
		cellMap = CellLAB;
	else
		DS = DS_LAI;
		srcName = "LAI";
		cellMap = CellLAI;
	end
	dts = unique(SessUsed.DateTime(SessUsed.Source == srcName));
	if isempty(dts), continue; end
	try
		ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	catch
		continue;
	end
	if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
	part = ntsCell{1};
	part.CellUID = uint64(part.CellUID);
	part.DateTime = iNormDT(datetime(part.DateTime));
	part.Source = repmat(srcName, height(part), 1);
	part = iDAttachLayer(part, cellMap);
	rawParts{end+1} = part; %#ok<AGROW>
	end

if isempty(rawParts), return; end
rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

[G1, cellU1, dtU1, srcU1, zLayer1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source), string(rawTbl.ZLayer));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

mapTbl = SessUsed(:, {'DateTime','Source','Mouse'});
mapTbl.Source = string(mapTbl.Source);
mapTbl.Mouse = string(mapTbl.Mouse);
[~, iU] = unique(mapTbl(:, {'DateTime','Source'}), 'rows');
mapTbl = mapTbl(iU, :);

medTbl = table(cellU1, dtU1, srcU1, zLayer1, med1s, 'VariableNames', {'CellUID','DateTime','Source','ZLayer','Med1s'});
medTbl = innerjoin(medTbl, mapTbl, 'Keys', {'DateTime','Source'});

rows = [];
for iM = 1:numel(miceIn)
	for iL = 1:numel(layers)
		layerName = layers(iL);
		R = medTbl(string(medTbl.Mouse) == miceIn(iM) & string(medTbl.ZLayer) == layerName, :);
		if isempty(R), continue; end
		cellKeys = strcat(string(R.Source), "__", string(R.CellUID));
		[~, ~, cellID] = unique(cellKeys);
		meanPerCell = accumarray(cellID, R.Med1s, [], @mean);
		vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
		if numel(vals) >= 3
			rows = [rows; {miceIn(iM), layerName, std(vals)}]; %#ok<AGROW>
		end
	end
	end

if isempty(rows), return; end
outTbl = cell2table(rows, 'VariableNames', {'Mouse','Layer','SD'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
miceOut = unique(outTbl.Mouse);
end

function T = iDAttachLayer(T, cellMap)
cellMap = cellMap(:, {'CellUID','ZLayer'});
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = string(cellMap.ZLayer(loc(has)));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function p = iRanksumSafe(x, y)
p = NaN;
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if numel(x) >= 2 && numel(y) >= 2
	try, p = ranksum(x, y); catch, end
end
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		'VariableNames',{'Mouse','DateTime','Phase','Performance'}); return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function Sess = iAudioWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID','Behavior'});
if isempty(TrAW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		'VariableNames',{'Mouse','DateTime','Phase','Performance'}); return;
end
[G, bu] = findgroups(uint64(TrAW.BlockUID));
awPerf = splitapply(@(x) mean(double(x),'omitnan'), TrAW.Behavior, G);
perfByBlock = table(uint64(bu), awPerf, 'VariableNames',{'BlockUID','AWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.AWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks, 'Keys','BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	dtM = DT(DT.Mouse == m, :);
	phDates = dtM.DateTime(dtM.Phase == phaseStart);
	endDates = dtM.DateTime(dtM.Phase == phaseEnd);
	if isempty(phDates) || isempty(endDates), continue; end
	startDT = min(phDates);
	endDT   = max(endDates);
	if ismissing(startDT) || ismissing(endDT), continue; end
	rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});
for iDS = 1:2
	if iDS == 1
		DS = LAB;
		srcName = "LAB";
	else
		DS = LAI;
		srcName = "LAI";
	end
	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormDT(datetime(T.DateTime));
	T.Phase = string(T.Phase);
	Tr = DS.Trials;
	mice = unique(T.Mouse);
	for iM = 1:numel(mice)
		m = mice(iM);
		Tm = T(T.Mouse == m, :);
		phases = unique(Tm.Phase);
		if ~any(phases == "Naive"), continue; end
		hasLearned = any(phases == "Learned");
		hasTransfer = any(phases == "Transfer");
		sessDTs = sort(unique(Tm.DateTime));
		sessPhase = strings(numel(sessDTs), 1);
		for ii = 1:numel(sessDTs)
			ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
			ph = ph(ph ~= "" & ~ismissing(ph));
			if isempty(ph)
				sessPhase(ii) = "";
				continue;
			end
			[uPh, ~, ic] = unique(ph);
			counts = accumarray(ic, 1);
			[~, mx] = max(counts);
			sessPhase(ii) = uPh(mx);
		end
		idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
		if hasLearned
			idxEnd = find(sessPhase == "Learned", 1, 'last');
		elseif hasTransfer
			idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
			idxEnd = idxTransferStart - 1;
		else
			idxEnd = numel(sessDTs);
		end
		if isempty(idxNaiveStart) || idxEnd < idxNaiveStart, continue; end
		for k = idxNaiveStart:idxEnd
			dt = sessDTs(k);
			blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
			TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
			if isempty(TrSess), continue; end
			lwMask = string(TrSess.Stimulus) == "LightWater";
			if ~any(lwMask), continue; end
			perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
			if ~isfinite(perf), continue; end
			AllSess = [AllSess; table(m, dt, perf, srcName, ...
				'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
		end
	end
end
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows');
AllSess = AllSess(ia, :);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess), 1);
for i = 1:height(AllSess)
	if AllSess.Source(i) == "LAB"
		DS = LAB;
	else
		DS = LAI;
	end
	if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
		keep(i) = false;
	end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
	rows = find(AllSess.Mouse == m);
	p = double(AllSess.Performance(rows));
	i100 = find(p >= 1 - 1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus));
st = st(~ismissing(st));
tf = any(st == string(stim));
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end
