% Fig2F: 时间连续性对"印迹复用"与"群体异质性"的不同衰减
%
% 上：重激活率 P(transfer-active | learned-active)，12 h vs 7 d
% 下：L5 响应异质性（Fig1I 口径），Naive vs 12 h vs 7 d
%
% 输出（\\Data-Server-2\个人数据\<USERNAME>\yyyyMM）：
%   - Fig2F_TimeContinuityDecay.svg
%   - Fig2F_TimeContinuityDecay.csv
%   - 本脚本副本

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
V7 = TransferLearning.Vacation7();

CellLAB = iDCellLayerTable(LAB, "LAB");
CellLAI = iDCellLayerTable(LAI, "LAI");
CellALB = iDCellLayerTable(ALB, "ALB");
CellV7 = iDCellLayerTable(V7, "V7");

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig2F:No1s', '找不到 1 s 采样点。');
end
layers = ["MOp2/3"; "MOp5"];

[tN, ~] = iDNaiveMouseAvgSDByLayer(LAB, LAI, CellLAB, CellLAI, idx1s, layers);
[tT, ~] = iDTransferMouseAvgSDByLayer(ALB, CellALB, idx1s, "Transfer", "Final", layers);
[t7, ~] = iDTransferMouseAvgSDByLayer(V7, CellV7, idx1s, "Transfer", "Final", layers);

RCtrl = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer(DataSet=ALB, Source="AudioLightBaseline", RequireHitMiss=false);
RV7 = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer(DataSet=V7, Source="Vacation7", RequireHitMiss=false);
RCtrl.Group(:) = "Control";
RV7.Group(:) = "Vacation7";
R = [RCtrl; RV7];
R.Mouse = string(R.Mouse);
n23 = R.NLearnedActive23; n5 = R.NLearnedActive5;
n23(~isfinite(n23)) = 0; n5(~isfinite(n5)) = 0;
w23 = n23 .* R.Prob23; w5 = n5 .* R.Prob5;
w23(~isfinite(w23)) = 0; w5(~isfinite(w5)) = 0;
nTot = n23 + n5;
R.PTgivenL = (w23 + w5) ./ nTot;
R.PTgivenL(nTot == 0) = NaN;
reactCtrl = R.PTgivenL(R.Group == "Control" & isfinite(R.PTgivenL));
react7 = R.PTgivenL(R.Group == "Vacation7" & isfinite(R.PTgivenL));
[pReact, ~] = ranksum(reactCtrl, react7);

rhL5N = tN.SD(tN.Layer == "MOp5");
rhL5T = tT.SD(tT.Layer == "MOp5");
rhL57 = t7.SD(t7.Layer == "MOp5");
pT7 = ranksum(rhL5T, rhL57);
pN7 = ranksum(rhL5N, rhL57);
pNT = ranksum(rhL5N, rhL5T);

fprintf('\n=== Fig2F ===\n');
fprintf('Reactivation: 12 h %.4f+-%.4f (n=%d) | 7 d %.4f+-%.4f (n=%d), p=%.4g\n', ...
	mean(reactCtrl), std(reactCtrl)/sqrt(numel(reactCtrl)), numel(reactCtrl), ...
	mean(react7), std(react7)/sqrt(numel(react7)), numel(react7), pReact);
fprintf('L5 RH: Naive %.3f+-%.3f (n=%d) | 12 h %.3f+-%.3f (n=%d) | 7 d %.3f+-%.3f (n=%d)\n', ...
	mean(rhL5N), std(rhL5N)/sqrt(numel(rhL5N)), numel(rhL5N), ...
	mean(rhL5T), std(rhL5T)/sqrt(numel(rhL5T)), numel(rhL5T), ...
	mean(rhL57), std(rhL57)/sqrt(numel(rhL57)), numel(rhL57));
fprintf('L5 RH p: N-T %.4g | T-7d %.4g | N-7d %.4g\n', pNT, pT7, pN7);
retReact = mean(react7) / mean(reactCtrl);
retRH = (mean(rhL57) - mean(rhL5N)) / (mean(rhL5T) - mean(rhL5N));
fprintf('7 d 保留比例：印迹复用 %.0f%%，L5 异质性 %.0f%%\n', 100*retReact, 100*retRH);

colors3 = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];
f = figure('Color', 'w', 'Name', 'Fig2F time continuity decay');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 7.5];
f.PaperUnits = 'centimeters';
f.PaperSize = [4.5, 7.5];
f.PaperPositionMode = 'auto';
Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'loose');

ax1 = nexttile(Layout, 1);
CG1 = table([1 2], 'VariableNames', {'GroupPair'});
[~, O1, B1, E1] = UniExp.BarScatterCompare({reactCtrl, react7}, UniExp.Flags.empty, CG1, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iColorBars(B1, [colors3(2,:); colors3(3,:)]);
iColorErr(E1, [colors3(2,:); colors3(3,:)]);
if isfield(O1, 'MultiCompare') && istable(O1.MultiCompare) && ismember('PText', O1.MultiCompare.Properties.VariableNames)
	for ip = 1:height(O1.MultiCompare)
		pt = O1.MultiCompare.PText(ip);
		if isgraphics(pt), pt.String = TransferLearning.Style.iFormatPText(pReact); end
	end
end
ax1.XTick = [1 2];
ax1.XTickLabel = {'12 h', '7 d'};
ylabel(ax1, 'Reactivated');
ylim(ax1, [0, 0.30]);

ax2 = nexttile(Layout, 2);
CG2 = table([1 2; 2 3; 1 3], 'VariableNames', {'GroupPair'});
[~, O2, B2, E2] = UniExp.BarScatterCompare({rhL5N, rhL5T, rhL57}, UniExp.Flags.empty, CG2, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iColorBars(B2, colors3);
iColorErr(E2, colors3);
pairs2 = [pNT; pT7; pN7];
if isfield(O2, 'MultiCompare') && istable(O2.MultiCompare) && ismember('PText', O2.MultiCompare.Properties.VariableNames)
	for ip = 1:min(height(O2.MultiCompare), numel(pairs2))
		pt = O2.MultiCompare.PText(ip);
		if isgraphics(pt), pt.String = TransferLearning.Style.iFormatPText(pairs2(ip)); end
	end
end
ax2.XTick = [1 2 3];
ax2.XTickLabel = {'Naive', '12 h', '7 d'};
ax2.XTickLabelRotation = 30;
ylabel(ax2, 'L5 heterogeneity');
ylim(ax2, [0, 0.72]);
box(ax1, 'off');
box(ax2, 'off');
outDir = fileparts(TransferLearning.StandardFigureSvgPath('Fig2F_TimeContinuityDecay.svg'));
figPath = fullfile(outDir, 'Fig2F_TimeContinuityDecay.fig');
savefig(f, figPath);
fprintf('Saved: %s\n', figPath);

csv = table;
csv.Metric = ["Reactivation 12h"; "Reactivation 7d"; "L5 RH Naive"; "L5 RH 12h"; "L5 RH 7d"];
csv.NMice = [numel(reactCtrl); numel(react7); numel(rhL5N); numel(rhL5T); numel(rhL57)];
csv.Mean = [mean(reactCtrl); mean(react7); mean(rhL5N); mean(rhL5T); mean(rhL57)];
csv.Sem = [std(reactCtrl)/sqrt(numel(reactCtrl)); std(react7)/sqrt(numel(react7)); ...
	std(rhL5N)/sqrt(numel(rhL5N)); std(rhL5T)/sqrt(numel(rhL5T)); std(rhL57)/sqrt(numel(rhL57))];
writetable(csv, fullfile(outDir, 'Fig2F_TimeContinuityDecay.csv'));
copyfile([mfilename('fullpath'), '.m'], fullfile(outDir, 'Fig2F_TimeContinuityDecay.m'));
assignin('base', 'Fig2F_Data', struct('ReactCtrl', reactCtrl, 'React7', react7, 'RH', {rhL5N, rhL5T, rhL57}, ...
	'PR', pReact, 'PRH', pairs2, 'RetainReact', retReact, 'RetainRH', retRH));

function iColorBars(Bars, cols)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = cols;
else
	for k = 1:numel(Bars), Bars(k).FaceColor = cols(k, :); end
end
for k = 1:numel(Bars)
	Bars(k).BarWidth = 0.5;
	Bars(k).EdgeColor = 'none';
	Bars(k).FaceAlpha = 1;
end
end

function iColorErr(EB, cols)
if istable(EB) && ~isempty(EB) && ismember('Object', EB.Properties.VariableNames)
	for k = 1:height(EB)
		eb = EB.Object(k);
		if isgraphics(eb) && k <= size(cols, 1)
			eb.Color = cols(k, :);
		end
	end
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
outTbl = table(strings(0,1), strings(0,1), nan(0,1), nan(0,1), 'VariableNames', {'Mouse','Layer','SD','NCells'});
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
			rows = [rows; {miceIn(iM), layerName, std(vals), numel(vals)}]; %#ok<AGROW>
		end
	end
end

if isempty(rows), return; end
outTbl = cell2table(rows, 'VariableNames', {'Mouse','Layer','SD','NCells'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
outTbl.NCells = double(outTbl.NCells);
miceOut = unique(outTbl.Mouse);
end

function [outTbl, miceOut] = iDMouseAvgByLayerMergedSources(DS_LAB, DS_LAI, CellLAB, CellLAI, SessUsed, miceIn, idx1s, layers)
outTbl = table(strings(0,1), strings(0,1), nan(0,1), nan(0,1), 'VariableNames', {'Mouse','Layer','SD','NCells'});
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
			rows = [rows; {miceIn(iM), layerName, std(vals), numel(vals)}]; %#ok<AGROW>
		end
	end
end

if isempty(rows), return; end
outTbl = cell2table(rows, 'VariableNames', {'Mouse','Layer','SD','NCells'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
outTbl.NCells = double(outTbl.NCells);
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
if ismember('MustWarn', string(DS.Blocks.Properties.VariableNames))
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = repmat(missing, height(Blocks), 1);
end
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
if ismember('MustWarn', string(DS.Blocks.Properties.VariableNames))
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = repmat(missing, height(Blocks), 1);
end
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




