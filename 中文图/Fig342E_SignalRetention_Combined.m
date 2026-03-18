% 中文图342E：信号保留散点 + 分组条形图组合

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
svgName = "中文图Fig342E_SignalRetention_Combined.svg";

DS = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));

baseMask = 1:24;

Blocks = DS.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);

Trials = DS.Trials;
Trials.BlockUID = uint64(Trials.BlockUID);

mice = unique(DT.Mouse);
nMice = numel(mice);

allAW = MATLAB.DataTypes.ArrayBuilder;
allLW = MATLAB.DataTypes.ArrayBuilder;

meanLW_AWpos = nan(nMice, 1); meanLW_AWneg = nan(nMice, 1);
meanAW_LWpos = nan(nMice, 1); meanAW_LWneg = nan(nMice, 1);

for mi = 1:nMice
	m = mice(mi);
	mouseDTs = DT.DateTime(DT.Mouse == m);

	awTrials = Trials(string(Trials.Stimulus) == "AudioWater", :);
	awBlkDTs = innerjoin(awTrials(:, 'BlockUID'), Blocks(:, {'BlockUID','DateTime'}), 'Keys', 'BlockUID');
	awMouseDates = intersect(unique(awBlkDTs.DateTime), mouseDTs);
	if isempty(awMouseDates), continue; end
	lastAWdt = max(awMouseDates);

	lwTrials = Trials(string(Trials.Stimulus) == "LightWater", :);
	lwBlkDTs = innerjoin(lwTrials(:, 'BlockUID'), Blocks(:, {'BlockUID','DateTime'}), 'Keys', 'BlockUID');
	lwMouseDates = intersect(unique(lwBlkDTs.DateTime), mouseDTs);
	if isempty(lwMouseDates), continue; end
	firstLWdt = min(lwMouseDates);

	qAW = struct('Stimulus', 'AudioWater', 'DateTime', lastAWdt);
	ntsAW = DS.QueryNTS(qAW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsAW) || isempty(ntsAW{1}), continue; end
	ntsAW = ntsAW{1};
	if ~istable(ntsAW) || height(ntsAW) == 0, continue; end

	awCells = unique(uint64(ntsAW.CellUID));
	medAW_1s = nan(numel(awCells), 1);
	for ic = 1:numel(awCells)
		rows = ntsAW(uint64(ntsAW.CellUID) == awCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medAW_1s(ic) = med(idx1s); end
	end

	qLW = struct('Stimulus', 'LightWater', 'DateTime', firstLWdt);
	ntsLW = DS.QueryNTS(qLW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsLW) || isempty(ntsLW{1}), continue; end
	ntsLW = ntsLW{1};
	if ~istable(ntsLW) || height(ntsLW) == 0, continue; end

	lwCells = unique(uint64(ntsLW.CellUID));
	medLW_1s = nan(numel(lwCells), 1);
	for ic = 1:numel(lwCells)
		rows = ntsLW(uint64(ntsLW.CellUID) == lwCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medLW_1s(ic) = med(idx1s); end
	end

	[~, idxAW, idxLW] = intersect(awCells, lwCells);
	awMatched = medAW_1s(idxAW);
	lwMatched = medLW_1s(idxLW);

	modMask = isfinite(awMatched) & isfinite(lwMatched) ...
		& awMatched >= -1 & awMatched <= 1 ...
		& lwMatched >= -1 & lwMatched <= 1;
	if sum(modMask) < 3, continue; end

	allAW.Append(awMatched(modMask));
	allLW.Append(lwMatched(modMask));

	awPos = modMask & awMatched > 0;
	awNeg = modMask & awMatched < 0;
	if sum(awPos) >= 3 && sum(awNeg) >= 3
		meanLW_AWpos(mi) = mean(lwMatched(awPos));
		meanLW_AWneg(mi) = mean(lwMatched(awNeg));
	end

	lwPos = modMask & lwMatched > 0;
	lwNeg = modMask & lwMatched < 0;
	if sum(lwPos) >= 3 && sum(lwNeg) >= 3
		meanAW_LWpos(mi) = mean(awMatched(lwPos));
		meanAW_LWneg(mi) = mean(awMatched(lwNeg));
	end
end

awAll = allAW.Harvest;
lwAll = allLW.Harvest;
[rho, pCorr] = corr(awAll, lwAll, 'Type', 'Spearman');
fprintf('Signal retention: rho=%.3f, p=%.4g, n=%d cells\n', rho, pCorr, numel(awAll));

vPN1 = isfinite(meanLW_AWpos) & isfinite(meanLW_AWneg);
pPN1 = signrank(meanLW_AWpos(vPN1), meanLW_AWneg(vPN1));
vPN2 = isfinite(meanAW_LWpos) & isfinite(meanAW_LWneg);
pPN2 = signrank(meanAW_LWpos(vPN2), meanAW_LWneg(vPN2));

palette3 = TransferLearning.FigurePalette(3);
colorPos = palette3(1,:);
colorNeg = palette3(2,:);
colorFit = palette3(3,:);
fs = 6;

f = figure('Color', 'w', 'Name', '中文图342E Signal retention');
f.Units = 'centimeters';
f.Position(3:4) = [4.5 4.0];

LM = 0.16; BM = 0.14; RM = 0.04; TM = 0.06;
bwR = 0.24; bhT = 0.24; G = 0.06;

sW = 1 - LM - G - bwR - RM;
sH = 1 - BM - G - bhT - TM;
sX = LM;
sY = BM;

axE = axes(f, 'Position', [sX sY sW sH]);
hold(axE, 'on');
sc = scatter(axE, awAll, lwAll, 1, colorNeg, 'LineWidth', 0.2, 'MarkerFaceAlpha', 0.05, MarkerEdgeAlpha=0.05, Marker='.');
set(sc, 'MarkerEdgeColor', colorNeg, 'MarkerFaceColor', colorNeg);
xline(axE, 0, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.4);
yline(axE, 0, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.4);
pf = polyfit(awAll, lwAll, 1);
plot(axE, [-1 1], polyval(pf, [-1 1]), '-', 'Color', colorFit, 'LineWidth', 1);
hold(axE, 'off');
xlim(axE, [-1.3 1.3]); ylim(axE, [-1.3 1.3]);
axE.FontSize = fs;
axE.XTick = [-1 0 1]; axE.YTick = [-1 0 1];
xlh = xlabel(axE, '🔊💧 z-score');
ylh = ylabel(axE, '💡💧 z-score');
box(axE, 'off');
xlh.Units = 'normalized';
xlh.Position(1) = (sW/2 + G/2 + bwR/2) / sW;
ylh.Units = 'normalized';
ylh.Position(2) = (sH/2 + G/2 + bhT/2) / sH;
if pCorr == 0 || pCorr < 1e-10
	pStr = 'p<10^{-10}';
elseif pCorr < 0.001
	pStr = sprintf('p=%.1e', pCorr);
else
	pStr = sprintf('p=%.2g', pCorr);
end
text(axE, 0.03, 0.97, pStr, 'Units', 'normalized', 'FontSize', fs, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

axT = axes(f, 'Position', [sX sY+sH+G sW bhT]);
valsN1 = meanLW_AWneg(vPN1); valsP1 = meanLW_AWpos(vPN1);
mN1 = mean(valsN1); seN1 = std(valsN1)/sqrt(numel(valsN1));
mP1 = mean(valsP1); seP1 = std(valsP1)/sqrt(numel(valsP1));
hold(axT, 'on');
bb = bar(axT, [1 2], [mN1 mP1], 0.5);
bb.FaceColor = 'flat'; bb.CData = [colorNeg; colorPos];
bb.FaceAlpha = 1/3; bb.LineWidth = 0.5;
for ib = 1:2
	vals = [mN1 mP1]; ses = [seN1 seP1]; xPos = [1 2];
	yEnd = vals(ib) + sign(vals(ib)) * ses(ib);
	if vals(ib) == 0, yEnd = ses(ib); end
	plot(axT, [xPos(ib) xPos(ib)], [vals(ib) yEnd], 'k-', 'LineWidth', 0.5);
	plot(axT, xPos(ib)+[-0.08 0.08], [yEnd yEnd], 'k-', 'LineWidth', 0.5);
end
yBrk = max(abs(mN1)+seN1, abs(mP1)+seP1) + 0.015;
plot(axT, [1 2], [yBrk yBrk], 'k-', 'LineWidth', 0.5, 'Clipping', 'off');
plot(axT, [1 1], [yBrk yBrk-0.005], 'k-', 'LineWidth', 0.5, 'Clipping', 'off');
plot(axT, [2 2], [yBrk yBrk-0.005], 'k-', 'LineWidth', 0.5, 'Clipping', 'off');
text(axT, 1.5, yBrk+0.005, iAsterisk(pPN1), 'FontSize', fs, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
hold(axT, 'off');
axT.FontSize = fs;
axT.XTick = [1 2]; axT.XTickLabel = {'−', '+'};
axT.XAxisLocation = 'bottom';
axT.YAxisLocation = 'left';
box(axT, 'off');

axR = axes(f, 'Position', [sX+sW+G sY bwR sH]);
valsN2 = meanAW_LWneg(vPN2); valsP2 = meanAW_LWpos(vPN2);
mN2 = mean(valsN2); seN2 = std(valsN2)/sqrt(numel(valsN2));
mP2 = mean(valsP2); seP2 = std(valsP2)/sqrt(numel(valsP2));
hold(axR, 'on');
bh = barh(axR, [1 2], [mN2 mP2], 0.5);
bh.FaceColor = 'flat'; bh.CData = [colorNeg; colorPos];
bh.FaceAlpha = 1/3; bh.LineWidth = 0.5;
for ib = 1:2
	vals = [mN2 mP2]; ses = [seN2 seP2]; yPos = [1 2];
	xEnd = vals(ib) + sign(vals(ib)) * ses(ib);
	if vals(ib) == 0, xEnd = ses(ib); end
	plot(axR, [vals(ib) xEnd], [yPos(ib) yPos(ib)], 'k-', 'LineWidth', 0.5);
	plot(axR, [xEnd xEnd], yPos(ib)+[-0.08 0.08], 'k-', 'LineWidth', 0.5);
end
xBrk = max(abs(mN2)+seN2, abs(mP2)+seP2) + 0.015;
plot(axR, [xBrk xBrk], [1 2], 'k-', 'LineWidth', 0.5, 'Clipping', 'off');
plot(axR, [xBrk xBrk-0.005], [1 1], 'k-', 'LineWidth', 0.5, 'Clipping', 'off');
plot(axR, [xBrk xBrk-0.005], [2 2], 'k-', 'LineWidth', 0.5, 'Clipping', 'off');
text(axR, xBrk+0.01, 1.5, iAsterisk(pPN2), 'FontSize', fs, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 270);
hold(axR, 'off');
axR.FontSize = fs;
axR.YTick = [1 2]; axR.YTickLabel = {'−', '+'};
axR.YAxisLocation = 'left';
box(axR, 'off');

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

function s = iAsterisk(p)
	if p < 0.001
		s = '***';
	elseif p < 0.01
		s = '**';
	elseif p < 0.05
		s = '*';
	else
		s = 'n.s.';
	end
end