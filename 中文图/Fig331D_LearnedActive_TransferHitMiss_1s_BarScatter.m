% 中文图331D：声水学会阶段活跃细胞的光水迁移命中/错失回合1s z-score比较

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
	error('中文图331D:No1s', 'Cannot find sample close to 1s.');
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

f = figure('Color', 'w', 'Name', '中文图331D Learned-active Hit Miss 1s');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;

Data = array2table([double(vHit(:)), double(vMiss(:))], 'VariableNames', {'Hit', 'Miss'});
CompareGroup = table(["Hit", "Miss"], 'VariableNames', {'GroupPair'});
[~, ~, Bars, EB] = UniExp.BarScatterCompare(Data, false, CompareGroup);
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

palette2 = TransferLearning.FigurePalette(2);
colorHit = palette2(2, :);
colorMiss = palette2(2, :) * 0.75;
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = [colorHit; colorMiss];
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1/3;
else
	for ib = 1:numel(Bars)
		if ib == 1
			Bars(ib).FaceColor = colorHit;
		else
			Bars(ib).FaceColor = colorMiss;
		end
		Bars(ib).FaceAlpha = 1/3;
		Bars(ib).LineWidth = 1;
		Bars(ib).BaseLine.LineWidth = 1;
		Bars(ib).EdgeColor = 'none';
	end
	end
for eb = EB.Object(:)'
	eb.LineWidth = 1;
	end
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
end

allText = findall(f, 'Type', 'Text');
for it = 1:numel(allText)
	allText(it).FontSize = 6;
	if isprop(allText(it), 'String')
		allText(it).String = iPTextToStars(allText(it).String);
	end
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

svgPath = '中文图Fig331D_LearnedActive_TransferHitMiss_1s_BarScatter.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== Fig331D sample counts ===\n');
disp(sampleCounts);
fprintf('Hit vs Miss signrank p = %.6g\n', hitMissPValue);

assignin('base', 'Fig331D_NTATS1s', struct('TransferHit', vHit, 'TransferMiss', vMiss, 'Idx1', idx1, 'XsSec', xsSec, 'MaskPair', maskPair, 'SampleCounts', sampleCounts, 'SignrankPValue', hitMissPValue));

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
		error('中文图331D:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

	error('中文图331D:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

	function out = iPTextToStars(in)
	out = in;
	if isstring(in)
		if isscalar(in)
			out = string(iPTextToStars(char(in)));
		else
			out = arrayfun(@(s) string(iPTextToStars(char(s))), in);
		end
		return;
	end

	if iscell(in)
		out = cell(size(in));
		for ii = 1:numel(in)
			out{ii} = iPTextToStars(in{ii});
		end
		return;
	end

	if ~(ischar(in) || (isnumeric(in) && isscalar(in)))
		return;
	end

	if isnumeric(in)
		in = char(string(in));
	end

	token = regexp(in, 'p\s*=\s*([0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)', 'tokens', 'once');
	if isempty(token)
		return;
	end

	p = str2double(token{1});
	if ~isfinite(p)
		return;
	end

	if p < 1e-4
		out = '****';
	elseif p < 1e-3
		out = '***';
	elseif p < 1e-2
		out = '**';
	elseif p < 0.05
		out = '*';
	else
		out = 'ns';
	end
	end

