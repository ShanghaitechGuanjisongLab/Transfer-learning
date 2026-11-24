% [存档] 旧编号脚本（已去图号，不再对应正式面板），保留代码备查。
% 英文图1J：声水学会阶段活跃细胞的光水迁移命中/错失回合1s z-score比较。

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
	error('Fig1J:No1s', 'Cannot find sample close to 1s.');
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

% 每鼠先对Learned-active细胞取1 s z-score均值，再配对比较Hit/Miss。
PairedCellUIDs = uint64(S.CellUID(pairedRowMask));
[IsMatched, CellLocations] = ismember(PairedCellUIDs, uint64(DS.Cells.CellUID));
assert(all(IsMatched), '部分配对细胞无法映射到所属小鼠。');
PairedMice = string(DS.Cells.Mouse(CellLocations));
[MouseNames, ~, MouseGroups] = unique(PairedMice, 'stable');
HitByMouse = splitapply(@mean, vHit, MouseGroups);
MissByMouse = splitapply(@mean, vMiss, MouseGroups);
PValue = signrank(HitByMouse, MissByMouse);
%% 

Figure = figure('Color', 'w', 'Name', 'English Fig1J Learned-active Hit Miss 1s paired');
Figure.Units = 'centimeters';
Figure.Position(3:4) = [4, 8];
Figure.PaperUnits = 'centimeters';
Figure.PaperPositionMode = 'manual';
Figure.PaperPosition = [0, 0, 4, 8];
Figure.PaperSize = [4, 8];

Ax = axes(Figure);
hold(Ax, 'on');
if isprop(Ax, 'Toolbar') && ~isempty(Ax.Toolbar)
	Ax.Toolbar.Visible = 'off';
end
Ax.LineWidth = 1;
Ax.FontSize = 6;
Ax.FontName = 'Segoe UI Emoji';

ColorHit = TransferLearning.ColorHit / 255;
ColorMiss = TransferLearning.ColorMiss / 255;
PairLines = plot(Ax, [HitByMouse, MissByMouse]', '-', LineWidth=1, Color=[0, 0, 0], HandleVisibility='off');
for PairLine = PairLines(:)'
	setappdata(PairLine, 'TransferLearningPreserveLineWidth', true);
end
scatter(Ax, ones(size(HitByMouse)), HitByMouse, 15, ColorHit, 'filled', LineWidth=0.2, MarkerEdgeColor=ColorHit, HandleVisibility='off');
scatter(Ax, 2 * ones(size(MissByMouse)), MissByMouse, 15, ColorMiss, 'filled', LineWidth=0.2, MarkerEdgeColor=ColorMiss, HandleVisibility='off');
Ax.XTick = [1, 2];
Ax.XTickLabel = {'Hit', 'Miss'};
ylabel(Ax, '1s z-score', FontSize=6);
title(Ax, '', FontSize=6, FontWeight='normal');
box(Ax, 'off');
grid(Ax, 'off');

SPlot = scatter(Ax, [ones(size(HitByMouse)); 2 * ones(size(MissByMouse))], [HitByMouse; MissByMouse], 1, 'k', 'filled', Visible='off', HandleVisibility='off');
Descriptors = table(SPlot, 0, 0, TransferLearning.Style.iFormatPText(PValue), 0, VariableNames={'ObjectA', 'IndexA', 'IndexB', 'Text', 'ExtraOffset'});
[PLines, PTexts] = MATLAB.Graphics.PLine(Descriptors);
for PLine = PLines(:)'
	PLine.LineWidth = 1;
	PLine.Tag = 'PLine';
end
for PText = PTexts(:)'
	PText.FontSize = 6;
	PText.Tag = 'PText';
end
delete(SPlot);

SvgPath = TransferLearning.ExportStandardFigure(Figure, 2, 'English_Fig_LearnedActive_TransferHitMiss_1s_Paired.svg');
fprintf('Wrote: %s\n', SvgPath);
fprintf('\n=== Fig1J sample counts ===\n');
disp(sampleCounts);
fprintf('配对鼠数：%d；Hit=%.6f±%.6f；Miss=%.6f±%.6f；双侧配对signrank p=%.9g。\n', numel(MouseNames), mean(HitByMouse), std(HitByMouse) / sqrt(numel(HitByMouse)), mean(MissByMouse), std(MissByMouse) / sqrt(numel(MissByMouse)), PValue);

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
		error('Fig1J:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

	error('Fig1J:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

