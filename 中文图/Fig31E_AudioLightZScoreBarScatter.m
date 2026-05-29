% 中文图332C：比较初始光水与迁移光水的1s-0s z-score（全细胞，不做筛选）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
[idx0s, ok0s] = iFindTimeIndex(xsSec, 0, 0.25);
if ~ok0s
	error('Fig332C:No0s', 'Cannot find sample close to 0s.');
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig332C:No1s', 'Cannot find sample close to 1s.');
end
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

[GAudFirst, GAudLearned, statsAudFirst, statsAudLearned] = iQueryAudioAll();
[GLigFirst, GLigLearned, statsLigFirst, statsLigLearned] = iQueryLightAll();
vAudFirst = iExtract1s(GAudFirst, idx1s, idx0s);
vAudLearned = iExtract1s(GAudLearned, idx1s, idx0s);
vLigFirst = iExtract1s(GLigFirst, idx1s, idx0s);
vLigLearned = iExtract1s(GLigLearned, idx1s, idx0s);

DataCell = {vAudFirst, vAudLearned, vLigFirst, vLigLearned};
PhaseLabels = categorical(["First"; "Learned"; "First"; "Learned"]);
StimLabels = categorical(["Audio"; "Audio"; "Light"; "Light"]);
GroupingData = table(PhaseLabels, StimLabels, 'VariableNames', {'Phase', 'Stimulus'});

palette2 = TransferLearning.FigurePalette(4);

f = figure('Color', 'w', 'Name', '中文图31E Audio/Light First/Learned 1s z-score');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 8];
f.PaperSize = [6, 8];

TL = tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axTop = nexttile(TL, 1);
GroupingData.GroupPair = [1 2; 3 4; 1 3; 2 4];
[~, optTop, Bars, EB] = UniExp.BarScatterCompare(DataCell, false, GroupingData);
delete(findobj(axTop, 'Type', 'Scatter'));
ax = axTop;
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 1;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 1;
	ax.YAxis.LineWidth = 1;
end
ylabel(ax, 'z-score (zero-anchored)');
ax.XTick = [1 2 3 4];
ax.XTickLabel = {'First\n🔊', 'Learned\n🔊', 'First\n💡', 'Learned\n💡'};
box(ax, 'off');
grid(ax, 'off');

if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nBar = numel(Bars.YData);
	Bars.CData = repmat(palette2, ceil(nBar / 4), 1);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 1;
	Bars.BaseLine.LineWidth = 1;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1/3;
else
	if numel(Bars) >= 4
		Bars(1).FaceColor = palette2(1, :);
		Bars(2).FaceColor = palette2(2, :);
		Bars(3).FaceColor = palette2(3, :);
		Bars(4).FaceColor = palette2(4, :);
		for ib = 1:4
			Bars(ib).FaceAlpha = 1/3;
			Bars(ib).LineWidth = 1;
			Bars(ib).BaseLine.LineWidth = 1;
			Bars(ib).EdgeColor = 'none';
		end
	end
end

for eb = EB.Object(:)'
	if isgraphics(eb)
		eb.LineWidth = 1;
		if isprop(eb, 'Color')
			eb.Color = [0 0 0];
		end
		if isprop(eb, 'LineStyle')
			eb.LineStyle = 'none';
		end
	end
end

for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 1;
end

allText = findall(f, 'Type', 'Text');
for it = 1:numel(allText)
	allText(it).FontSize = 6;
end

allAxes = findall(f, 'Type', 'Axes');
for ia = 1:numel(allAxes)
	allAxes(ia).FontSize = 6;
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = '中文图Fig31E_AudioLightZScoreBarScatter.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== 中文图31E ===\n');
fprintf('Audio First: %d mice, %d cells\n', statsAudFirst.MouseCount, statsAudFirst.CellCount);
fprintf('Audio Learned: %d mice, %d cells\n', statsAudLearned.MouseCount, statsAudLearned.CellCount);
fprintf('Light First: %d mice, %d cells\n', statsLigFirst.MouseCount, statsLigFirst.CellCount);
fprintf('Light Learned: %d mice, %d cells\n', statsLigLearned.MouseCount, statsLigLearned.CellCount);
if isfield(optTop, 'MultiCompare') && istable(optTop.MultiCompare)
	disp(optTop.MultiCompare(:, {'Group1','Group2','PValue'}));
end

function v = iExtract1s(G, idx1s, idx0s)
if isempty(G), v = []; return; end
X = iGetNtats2D(G);
if isempty(X)
v = [];
else
X = iZeroAnchorZScore(X, idx0s);
v = double(X(:, idx1s));
v = v(isfinite(v));
end
end

function [GFirst, GLearned, statsFirst, statsLearned] = iQueryAudioAll()
DS = TransferLearning.AudioLightBaseline();
qFirst = struct('Phase', 'Naive', 'Stimulus', 'AudioWater', 'Session', 1);
qLearned = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
try GFirst = iQueryFirstSession(DS, qFirst); catch, GFirst = table(); end
try GLearned = DS.QueryNTATS(qLearned, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median); catch, GLearned = table(); end
statsFirst = iGroupStats({GFirst}, {DS});
statsLearned = iGroupStats({GLearned}, {DS});
end

function [GFirst, GLearned, statsFirst, statsLearned] = iQueryLightAll()
DS = TransferLearning.LightAudioBaseline();
qFirst = struct('Phase', 'Naive', 'Stimulus', 'LightWater', 'Session', 1);
qLearned = struct('Phase', 'Learned', 'Stimulus', 'LightWater');
try GFirst = iQueryFirstSession(DS, qFirst); catch, GFirst = table(); end
try GLearned = DS.QueryNTATS(qLearned, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median); catch, GLearned = table(); end
statsFirst = iGroupStats({GFirst}, {DS});
statsLearned = iGroupStats({GLearned}, {DS});
end

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
if isempty(T)
	mice = string.empty(0,1);
	return;
end
mice = unique(string(T.Mouse));
mice = mice(~ismember(mice, string(excludeMice(:))));
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
if isempty(T)
	badMice = strings(0,1);
	return;
end
Tr = DS.Trials;
TrStim = string(Tr.Stimulus);
TrBU = uint64(Tr.BlockUID);
T.Mouse = string(T.Mouse);
blkBU = uint64(T.BlockUID);
mice = unique(T.Mouse);
bad = false(size(mice));
for i = 1:numel(mice)
	bu = blkBU(T.Mouse == mice(i));
	rows = ismember(TrBU, bu);
	bad(i) = any(TrStim(rows) == "AudioWater");
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
if istable(G) && ismember('NTATS', G.Properties.VariableNames)
nt = G.NTATS;
else
X = []; return;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
X = nt.Data.Data;
elseif isnumeric(nt)
X = nt;
elseif iscell(nt)
X = nt{1};
else
try
X = double(nt{:,:,:});
catch
X = [];
end
end
end



