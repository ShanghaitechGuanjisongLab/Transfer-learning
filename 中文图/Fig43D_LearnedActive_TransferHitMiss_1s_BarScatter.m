% 中文图43D：声水学会阶段活跃细胞的光水迁移命中/错失回合1s z-score比较

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;
[~, idx1] = min(abs(xsSec - 1));
if abs(xsSec(idx1) - 1) > 0.25
	error('Fig43D:No1s', 'Cannot find sample close to 1s.');
end

qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTHit = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 1);
qTMiss = struct('Phase', 'Transfer', 'Stimulus', 'LightWater', 'Behavior', 0);

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit = DS.QueryNTATS(qTHit, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = DS.QueryNTATS(qTMiss, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

XLearned = squeeze(X(:, :, 1));
baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
v1sLearned = XLearned(:, idx1);
activeMask = isfinite(v1sLearned) & isfinite(baseMu) & isfinite(baseSd) & (v1sLearned > (baseMu + kSigma * baseSd));
activeRowIndex = find(activeMask);

X = X(activeMask, :, :);
vHit = X(:, idx1, 2);
vMiss = X(:, idx1, 3);
maskPair = isfinite(vHit) & isfinite(vMiss);
vHit = vHit(maskPair);
vMiss = vMiss(maskPair);
pairedRowMask = false(size(activeMask));
pairedRowMask(activeRowIndex(maskPair)) = true;
sampleCounts = TransferLearning.PanelSampleCountTable(S, ["Hit"; "Miss"], [pairedRowMask, pairedRowMask], DS.Cells);
hitMissPValue = signrank(vHit, vMiss);
%% 

f = figure('Color', 'w', 'Name', '中文图43D Learned-active Hit Miss 1s');
f.Units = 'centimeters';
f.Position(3:4) = [4, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4, 8];
f.PaperSize = [4, 8];

tiledlayout(f, 1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
nexttile;

Data = array2table([double(vHit(:)), double(vMiss(:))], 'VariableNames', {'Hit', 'Miss'});
CompareGroup = table(["Hit", "Miss"], 'VariableNames', {'GroupPair'});
[~, optional, Bars, EB] = UniExp.BarScatterCompare(Data, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
iTagPValueObjects(optional);
ax = gca;
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ylabel(ax, 'z-score');
ax.XTickLabel = {'Hit', 'Miss'};
box(ax, 'off');
grid(ax, 'off');

hitMissColors = TransferLearning.GroupColors(["Hit", "Miss"]);
colorHit = hitMissColors(1, :);
colorMiss = hitMissColors(2, :);
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = [colorHit; colorMiss];
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
else
	for ib = 1:numel(Bars)
		if ib == 1
			Bars(ib).FaceColor = colorHit;
		else
			Bars(ib).FaceColor = colorMiss;
		end
		Bars(ib).FaceAlpha = 1;
		Bars(ib).BarWidth = 0.5;
		Bars(ib).LineWidth = 1;
		Bars(ib).BaseLine.LineWidth = 1;
		Bars(ib).EdgeColor = 'none';
	end
	end
iStyleErrorBars(EB, hitMissColors);
for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 1;
end

scatters = findobj(ax, 'Type', 'Scatter');
for is = 1:numel(scatters)
	scatters(is).LineWidth = 0.2;
	if isprop(scatters(is), 'MarkerEdgeAlpha')
		scatters(is).MarkerEdgeAlpha = 0.5;
	end
	if isprop(scatters(is), 'MarkerFaceAlpha')
		scatters(is).MarkerFaceAlpha = 0.6;
	end
	xMean = mean(double(scatters(is).XData), 'omitnan');
	if xMean < 1.5
		scatters(is).MarkerFaceColor = colorHit;
		scatters(is).MarkerEdgeColor = colorHit;
	else
		scatters(is).MarkerFaceColor = colorMiss;
		scatters(is).MarkerEdgeColor = colorMiss;
	end
end

allText = findall(f, 'Type', 'Text');
for it = 1:numel(allText)
	allText(it).FontSize = 6;
end

allAxes = findall(f, 'Type', 'Axes');
for ia = 1:numel(allAxes)
	allAxes(ia).FontSize = 6;
end

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = '中文图Fig43D_LearnedActive_TransferHitMiss_1s_BarScatter.svg';
title("🔊💧"+newline+"active cells");
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== Fig43D sample counts ===\n');
disp(sampleCounts);
fprintf('Hit vs Miss signrank p = %.6g\n', hitMissPValue);

assignin('base', 'Fig43D_NTATS1s', struct('TransferHit', vHit, 'TransferMiss', vMiss, 'Idx1', idx1, 'XsSec', xsSec, 'MaskPair', maskPair, 'SampleCounts', sampleCounts, 'SignrankPValue', hitMissPValue));

function iTagPValueObjects(optional)
if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
multiCompare = optional.MultiCompare;
if ismember('PLine', multiCompare.Properties.VariableNames)
	for pLine = multiCompare.PLine(:)'
		if isgraphics(pLine)
			pLine.Tag = 'PLine';
		end
	end
end
if ismember('PText', multiCompare.Properties.VariableNames)
	for pText = multiCompare.PText(:)'
		if isgraphics(pText)
			pText.Tag = 'PText';
		end
	end
end
end

function iStyleErrorBars(errorBars, colors)
for iE = 1:height(errorBars)
	errorBar = errorBars.Object(iE);
	errorBar.LineWidth = 1;
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
end
end

function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end

if isnumeric(nt)
	if ndims(nt) ~= 3
		error('Fig43D:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

	error('Fig43D:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

