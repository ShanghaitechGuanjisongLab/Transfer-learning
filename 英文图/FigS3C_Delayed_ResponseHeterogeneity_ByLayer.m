% English FigS3C: response heterogeneity by layer on Delayed data
% （英文图/Fig1I_ResponseHeterogeneity_ByLayer 的 Delayed 版；用户裁定两库三组）。
%
% 三组（取点 +1.5 s，延迟任务名义给水时刻，Fig1I 的 1.0 s 延迟版）：
%   Naive💡        = LADelayed 光水学习会话（全部 LightLearnWater 会话，每鼠 1 个；
%                    LightLearnWaterAlways 总是给水不参与；Fig1I 的 ≥2 会话要求放宽为 ≥1）
%   Learned🔊      = ALDelayed 最后一个 AudioLearnWater 会话（声水学会；Always 不参与）
%   Transfer💡     = ALDelayed 光水迁移→学会（全部 LightLearnWater 会话，Always 不参与；
%                    沿用 Fig1I 的 Transfer-like 截断：≥2 会话，去掉首个满分（Performance≥1）
%                    会话及其之后的部分）
%
% Metric per mouse per layer（Fig1I 口径）：每细胞每会话 median z@+1.5 s → 每细胞跨会话
%   均值 → 过滤 [-1,1] → 细胞间 std。
% 面板：2×1（L2/3 上、L5 下），三根柱（barColors = Naive/Transfer/Learned），
%   BarScatterCompare 组间比较（Naive vs Transfer、Learned vs Transfer），无散点。
%
% Outputs (SVG):
%   - English_FigS3C_Delayed_ResponseHeterogeneity_ByLayer.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS_AL = TransferLearning.ALDelayed();
DS_LA = TransferLearning.LADelayed();
CellAL = iCellLayerTable(DS_AL);
CellLA = iCellLayerTable(DS_LA);

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idxT, okT] = iFindTimeIndex(xsSec, 1.5, 0.25);
if ~okT
	error('FigS3C:No15s', 'Cannot find sample close to 1.5 s.');
end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];

% ---- Naive💡：LADelayed 光水学习会话（全部 LightLearnWater 会话） ----
sessNaive = iLightSessions(DS_LA);
[naiveTbl, naiveMice] = iMouseAvgSDByLayer(DS_LA, CellLA, sessNaive, idxT, layers, "LightLearnWater");
% ---- Learned🔊：ALDelayed 最后一个 AudioLearnWater 会话 ----
sessLearned = iLastAudioSessions(DS_AL);
[learnedTbl, learnedMice] = iMouseAvgSDByLayer(DS_AL, CellAL, sessLearned, idxT, layers, "AudioLearnWater");
% ---- Transfer💡：ALDelayed 光水迁移→学会（Transfer-like 截断） ----
sessTransfer = iLightSessions(DS_AL);
sessTransfer = iUsedTransferLikeSessions(sessTransfer);
[transferTbl, transferMice] = iMouseAvgSDByLayer(DS_AL, CellAL, sessTransfer, idxT, layers, "LightLearnWater");

fprintf('Naive mice with layer values: %d\n', numel(unique(naiveMice)));
fprintf('Learned AudioWater mice with layer values: %d\n', numel(unique(learnedMice)));
fprintf('Transfer mice with layer values: %d\n', numel(unique(transferMice)));
%%

% --- Figure: tiledlayout 2×1（同 Fig1I 版式）
f = figure('Color', 'w', 'Name', 'English FigS3C delayed Response heterogeneity by layer');
f.Units = 'centimeters';
f.Position(3:4) = [4,8];

t = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
title(t, sprintf('Response\nheterogeneity'));

barColors = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.LearnedColor];
CompareGroup = table([1 2; 3 2], 'VariableNames', {'GroupPair'});

for iL = 1:numel(layers)
	layerName = layers(iL);
	layerLabel = layerLabels(iL);
	valsN = naiveTbl.SD(naiveTbl.Layer == layerName);
	valsL = learnedTbl.SD(learnedTbl.Layer == layerName);
	valsT = transferTbl.SD(transferTbl.Layer == layerName);
	nCellsN = sum(naiveTbl.NCells(naiveTbl.Layer == layerName), 'omitnan');
	nCellsL = sum(learnedTbl.NCells(learnedTbl.Layer == layerName), 'omitnan');
	nCellsT = sum(transferTbl.NCells(transferTbl.Layer == layerName), 'omitnan');
	pValNT = iRanksumSafe(valsN, valsT);
	pValLT = iRanksumSafe(valsL, valsT);

	fprintf('\n=== FigS3C (Delayed) %s ===\n', layerLabel);
	fprintf('Naive:    %.4f +- %.4f (n=%d mice, %d cells)\n', mean(valsN), std(valsN)/sqrt(numel(valsN)), numel(valsN), round(nCellsN));
	fprintf('Learned:  %.4f +- %.4f (n=%d mice, %d cells)\n', mean(valsL), std(valsL)/sqrt(numel(valsL)), numel(valsL), round(nCellsL));
	fprintf('Transfer: %.4f +- %.4f (n=%d mice, %d cells)\n', mean(valsT), std(valsT)/sqrt(numel(valsT)), numel(valsT), round(nCellsT));
	fprintf('Naive vs Transfer ranksum p = %.6g\n', pValNT);
	fprintf('Learned AW vs Transfer ranksum p = %.6g\n', pValLT);

	ax = nexttile(t, iL);
	[~, Opt, Bars, EB] = UniExp.BarScatterCompare({valsN, valsT, valsL}, CompareGroup, AsteriskThreshold=0.05);
	delete(findobj(ax, 'Type', 'Scatter'));   % 不画每鼠散点
	% Tag P-value lines without replacing asterisk text（编号标签交给标准样式 Retune）
	if isfield(Opt, 'MultiCompare') && istable(Opt.MultiCompare)
		if ismember('PLine', Opt.MultiCompare.Properties.VariableNames)
			for i = 1:height(Opt.MultiCompare)
				pl = Opt.MultiCompare.PLine(i);
				if isgraphics(pl), pl.Tag = sprintf('PLine_%d', i); end
			end
		end
		if ismember('PText', Opt.MultiCompare.Properties.VariableNames)
			for i = 1:height(Opt.MultiCompare)
				pt = Opt.MultiCompare.PText(i);
				if isgraphics(pt), pt.Tag = sprintf('PText_%d', i); end
			end
		end
	end
	for eb = EB.Object(:)'
		x = double(eb.XData(:));
		[~, colorIndex] = min(abs((1:size(barColors, 1)).' - x(1)));
		eb.Color = barColors(colorIndex, :);
	end
	ax.XTick = [1 2 3];
	if iL == 1
		ax.XTickLabel = {};
	else
		ax.XTickLabel = {'Naive💡', 'Transfer💡', 'Learned🔊'};
	end
	ylabel(ax, layerLabel);
	if isscalar(Bars)
		Bars.FaceColor = 'flat';
		nB = numel(Bars.YData);
		Bars.CData = repmat(barColors, ceil(nB/3), 1);
		Bars.CData = Bars.CData(1:nB, :);
		Bars.EdgeColor = 'none';
		Bars.BarWidth = 0.5;
	end
	box off
end

% --- Export（同 Fig1I）
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS3C_Delayed_ResponseHeterogeneity_ByLayer.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS3C_Delayed_HetByLayer', struct('Naive', naiveTbl, 'Learned', learnedTbl, 'Transfer', transferTbl));

%% ========== local functions（度量同 Fig1I，会话定义适配 ALDelayed/LADelayed） ==========
function S = iCellLayerTable(DS)
S = DS.Cells(:, {'Mouse', 'CellUID', 'ZLayer'});
S.Mouse = string(S.Mouse);
S.CellUID = uint64(S.CellUID);
S.ZLayer = string(S.ZLayer);
end

function Sess = iLightSessions(DS)
% 全部 LightLearnWater 会话（Performance = LightLearnWater 回合 hit 均值；Always 不参与）。
Sess = table(string.empty(0, 1), NaT(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"]);
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = iNormDT(datetime(T.DateTime));
T = T(T.Stimulus == "LightLearnWater", :);
[G, mouseList, dtList] = findgroups(T.Mouse, T.DateTime);
val = double(T.Behavior);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
S = table(mouseList, dtList, perf, 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
Sess = S(isfinite(S.Performance), :);
end

function Sess = iLastAudioSessions(DS)
% 每鼠最后一个 AudioLearnWater 会话（声水学会；Always 不参与）。
Sess = table(string.empty(0, 1), NaT(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DateTime', 'Performance'});
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"]);
if isempty(T)
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.DateTime = iNormDT(datetime(T.DateTime));
T = T(T.Stimulus == "AudioLearnWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	dt = max(Tm.DateTime);
	Ts = Tm(Tm.DateTime == dt, :);
	b = double(Ts.Behavior);
	b = b(isfinite(b));
	if isempty(b)
		continue;
	end
	Sess = [Sess; table(mice(i), dt, mean(b), 'VariableNames', {'Mouse', 'DateTime', 'Performance'})]; %#ok<AGROW>
end
end

function SessOut = iUsedTransferLikeSessions(Sess)
% Fig1I 的 Transfer-like 会话规则：每鼠 ≥2 会话；去掉首个满分（Performance≥1）会话及其之后的部分。
if isempty(Sess)
	SessOut = Sess;
	return;
end
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
miceAll = unique(string(Sess.Mouse));
keepRows = false(height(Sess), 1);
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2
		continue;
	end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2
		continue;
	end
	keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
end
SessOut = Sess(keepRows, :);
end

function [outTbl, miceOut] = iMouseAvgSDByLayer(DS, CellMap, SessUsed, idxT, layers, stimulusName)
% Fig1I 的 iDMouseAvgByLayerSingleSource 口径：每细胞每会话 median z@idxT →
% 每细胞跨会话均值 → 过滤 [-1,1] → 细胞间 std（逐鼠逐层）。
outTbl = table(strings(0, 1), strings(0, 1), nan(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'Layer', 'SD', 'NCells'});
miceOut = string.empty(0, 1);
if isempty(SessUsed)
	return;
end
miceIn = unique(string(SessUsed.Mouse));
dts = unique(SessUsed.DateTime);
try
	ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'DateTime', dts), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
	return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
[~, loc] = ismember(rawTbl.CellUID, CellMap.CellUID);
rawTbl.ZLayer = strings(height(rawTbl), 1);
has = loc > 0;
rawTbl.ZLayer(has) = CellMap.ZLayer(loc(has));
sig = double(rawTbl.TrialSignal);
zT = sig(:, idxT);

[G1, cellU1, dtU1, zLayer1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.ZLayer));
medT = splitapply(@(x) median(x, 'omitnan'), zT, G1);

dtMouse = SessUsed(:, {'DateTime', 'Mouse'});
dtMouse.Mouse = string(dtMouse.Mouse);
[~, iU] = unique(dtMouse.DateTime);
dtMouse = dtMouse(iU, :);

medTbl = table(cellU1, dtU1, zLayer1, medT, 'VariableNames', {'CellUID', 'DateTime', 'ZLayer', 'Med'});
medTbl = innerjoin(medTbl, dtMouse, 'Keys', 'DateTime');

rows = [];
for iM = 1:numel(miceIn)
	for iL = 1:numel(layers)
		layerName = layers(iL);
		R = medTbl(string(medTbl.Mouse) == miceIn(iM) & string(medTbl.ZLayer) == layerName, :);
		if isempty(R)
			continue;
		end
		[~, ~, cellID] = unique(R.CellUID);
		meanPerCell = accumarray(cellID, R.Med, [], @mean);
		vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
		if numel(vals) >= 3
			rows = [rows; {miceIn(iM), layerName, std(vals), numel(vals)}]; %#ok<AGROW>
		end
	end
end
if isempty(rows)
	return;
end
outTbl = cell2table(rows, 'VariableNames', {'Mouse', 'Layer', 'SD', 'NCells'});
outTbl.Mouse = string(outTbl.Mouse);
outTbl.Layer = string(outTbl.Layer);
outTbl.SD = double(outTbl.SD);
outTbl.NCells = double(outTbl.NCells);
miceOut = unique(outTbl.Mouse);
end

function p = iRanksumSafe(x, y)
x = x(isfinite(x));
y = y(isfinite(y));
if isempty(x) || isempty(y)
	p = NaN;
	return;
end
p = ranksum(x, y);
end

function dt = iNormDT(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end
