% FigS1H (English, merged from Chinese Fig43F/G/H): active-cell fraction pies
%
% 左: Learned AudioWater 活跃细胞占所有记录细胞比例（中文图43F）
% 中: Transfer LightWater 首个训练单元活跃细胞占所有记录细胞比例（中文图43G）
% 右: Learned 活跃细胞在 Transfer 首个训练单元中被重新激活的比例（中文图43H）
%
% 活跃判定：线索后 1 s 处 z-score > 基线(-3~0 s)均值 + 3σ
% 输出单个 SVG，横向三个饼图

% --- 0) Ensure project loaded
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
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('FigS1H:No1s', 'Cannot find sample close to 1s.');
end

kSigma = 3;

%% --- F: Learned AudioWater active fraction ---
qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
GLearned = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
learnedTable = iBuildActiveCellTable(GLearned, idx1s, baseMask, kSigma, 'FigS1H:BadNTATS');
[learnedActiveN, learnedTotalN] = iUniqueCounts(learnedTable);

%% --- G: Transfer LightWater first-block active fraction ---
firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS);
transferTables = cell(height(firstTransfer), 1);
for iMouse = 1:height(firstTransfer)
	qTransferOne = struct('Stimulus', 'LightWater', 'DateTime', firstTransfer.DateTime(iMouse));
	GTransferOne = DS.QueryNTATS(qTransferOne, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	transferTables{iMouse} = iBuildActiveCellTable(GTransferOne, idx1s, baseMask, kSigma, 'FigS1H:BadNTATS');
end
if isempty(transferTables)
	transferTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
else
	transferTable = vertcat(transferTables{:});
end
[transferActiveN, transferTotalN] = iUniqueCounts(transferTable);

%% --- H: reuse fraction (Learned-active cells re-activated in Transfer first block) ---
learnedActiveIDs = unique(uint64(learnedTable.CellUID(logical(learnedTable.IsActive))));
transferActiveIDs = unique(uint64(transferTable.CellUID(logical(transferTable.IsActive))));
reuseIDs = intersect(learnedActiveIDs, transferActiveIDs);
nReuse = numel(reuseIDs);
[learnedActiveNDedup, ~] = iUniqueCounts(learnedTable(learnedTable.IsActive, :));
nLearnedActiveDenom = learnedActiveNDedup;

%% --- Plot: 3 pies side by side ---
% 绘图逻辑照抄中文图43FG / 英文旧Fig1I 原版 iPlotOnePie：
% 单饼原版为 6×4 cm、axes Position [0.22,0.12,0.56,0.78]（轴 3.36×3.12 cm）。
% 合并版保持轴尺寸与高度不变，仅把每饼槽宽从 6.0 cm 压到 4.9 cm（总宽 14.7 cm <15 cm、高 4.0 cm）。
slotCm = 4.9;
axWCm = 3.36;
axLeft0Cm = 0.3;
figWCm = 3 * slotCm;
figHCm = 4.0;

f = figure('Color', 'none', 'Name', 'English FigS1H Active Fraction Pies');
f.Units = 'centimeters';
f.Position(3:4) = [figWCm, figHCm];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, figWCm, figHCm];
f.PaperSize = [figWCm, figHCm];

specs = { ...
	learnedActiveN, learnedTotalN, sprintf('🔊💧\nactive cells'), 'fraction'; ...
	transferActiveN, transferTotalN, sprintf('💡💧\nactive cells'), 'fraction'; ...
	nReuse, nLearnedActiveDenom, sprintf('💡💧\nreactivated'), 'reuse'};
for iP = 1:3
	axLeftCm = (iP - 1) * slotCm + axLeft0Cm;
	ax = axes(f, 'Units', 'normalized', ...
		'Position', [axLeftCm / figWCm, 0.12, axWCm / figWCm, 0.78]);
	iPlotOnePie(ax, specs{iP, 1}, specs{iP, 2}, specs{iP, 3}, specs{iP, 4});
end

set(findobj(f, 'Type', 'text'), 'FontSize', 6);

%% --- Export ---
svgName = "English_FigS1H_ActiveFractionPies.svg";
svgPath = TransferLearning.ExportStandardFigureTransparent(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('Learned AudioWater active = %d / %d (%.4f)\n', learnedActiveN, learnedTotalN, learnedActiveN / learnedTotalN);
fprintf('Transfer first-block active = %d / %d (%.4f)\n', transferActiveN, transferTotalN, transferActiveN / transferTotalN);
fprintf('Reuse = %d / %d (%.4f)\n', nReuse, nLearnedActiveDenom, nReuse / nLearnedActiveDenom);

summary = table(learnedActiveN, learnedTotalN, transferActiveN, transferTotalN, nReuse, nLearnedActiveDenom, ...
	'VariableNames', {'LearnedActiveN', 'LearnedTotalN', 'TransferFirstActiveN', 'TransferFirstTotalN', 'ReuseN', 'ReuseDenominatorN'});
assignin('base', 'FigS1H_ActiveFractionSummary', summary);

%% ========== Local helpers ==========

function firstTransfer = iPerMouseFirstTransferLightWaterDateTime(DS)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);

T = T(T.Phase == "Transfer" & T.Stimulus == "LightWater", {'Mouse', 'DateTime'});
if isempty(T)
	firstTransfer = table(string.empty(0, 1), NaT(0, 1), 'VariableNames', {'Mouse', 'DateTime'});
	return;
end

T = sortrows(T, {'Mouse', 'DateTime'});
[groupId, mouseName] = findgroups(T.Mouse);
firstDate = splitapply(@(x) x(1), T.DateTime, groupId);
firstTransfer = table(mouseName, firstDate, 'VariableNames', {'Mouse', 'DateTime'});
end

function activeTable = iBuildActiveCellTable(G, idx1s, baseMask, kSigma, errId)
if isempty(G)
	activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
	return;
end
S = UniExp.NtatsCellStrip(struct('Q', G));
X = iGetNtats3D(S, errId);
if isempty(X)
	activeTable = table(uint64.empty(0, 1), false(0, 1), 'VariableNames', {'CellUID', 'IsActive'});
	return;
end
if size(X, 3) > 1
	XLane = squeeze(X(:, :, 1));
else
	XLane = squeeze(X);
end
if ~istable(S) || ~ismember('CellUID', S.Properties.VariableNames)
	error(errId, 'NtatsCellStrip result does not contain CellUID.');
end

baseMu = mean(XLane(:, baseMask), 2, 'omitnan');
baseSd = std(XLane(:, baseMask), 0, 2, 'omitnan');
v1 = XLane(:, idx1s);
isActive = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
activeTable = table(uint64(S.CellUID), logical(isActive), 'VariableNames', {'CellUID', 'IsActive'});
end

function X = iGetNtats3D(S, errId)
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
		error(errId, 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error(errId, 'Unsupported NTATS container type: %s', class(nt));
end

function [activeN, totalN] = iUniqueCounts(activeTable)
if isempty(activeTable)
	activeN = 0;
	totalN = 0;
	return;
end
[cellUID, idx] = unique(uint64(activeTable.CellUID), 'stable');
isActive = logical(activeTable.IsActive(idx));
activeN = nnz(isActive);
totalN = numel(cellUID);
end

function iPlotOnePie(ax, activeN, totalN, smallSliceLabel, pieMode)
% 照抄中文图43FG / 英文旧Fig1I 的 iPlotOnePie 绘图逻辑
if totalN > 0
	frac = activeN / totalN;
else
	frac = NaN;
end

majorColor = 0.7922 .* [1 1 1];
minorColor = [0, 0.6275, 0.9137];

if strcmp(pieMode, 'reuse')
	% 旧 Fig1I/43H：valueVec = [pNon, pReuse]，标题=分母标签，侧标= reuse 扇区（第2扇区）
	valueVec = [1 - frac, frac];
	wedgeColors = [majorColor; minorColor];
	titleText = sprintf('🔊💧\nactive cells');
	sideText = smallSliceLabel;
	sideWedge = 2;
else
	% 43F/G：valueVec = [pActive, pInactive]，标题=大扇区标签，侧标=小扇区中点角
	valueVec = [frac, 1 - frac];
	if valueVec(1) >= valueVec(2)
		wedgeColors = [majorColor; minorColor];
	else
		wedgeColors = [minorColor; majorColor];
	end
	labelTexts = [string(smallSliceLabel), "all cells"];
	[~, majorIdx] = max(valueVec);
	[~, minorIdx] = min(valueVec);
	titleText = iCapitalizeLeadingLetter(labelTexts(majorIdx));
	sideText = labelTexts(1);
	sideWedge = minorIdx;
end

MATLAB.Graphics.NestedPie( ...
	{valueVec}, ...
	WedgeColors={wedgeColors}, ...
	LabelText=strings(1, 2), ...
	PercentStatus="on", ...
	PercentFontColor='k', ...
	RhoLower=0.4, ...
	LineWidth=0.5, ...
	LabelOffset=0.16, ...
	AxesHandle=ax);
title(ax, titleText, 'FontSize', 6, 'FontWeight', 'normal');

if all(isfinite(valueVec)) && sum(valueVec) > 0
	startAngleDeg = [0, 360 * valueVec(1) / sum(valueVec)];
	endAngleDeg = [startAngleDeg(2), 360];
	thetaDeg = 0.5 * (startAngleDeg(sideWedge) + endAngleDeg(sideWedge));
	theta = deg2rad(thetaDeg);
	labelRadius = 1.12;
	tx = labelRadius * cos(theta);
	ty = labelRadius * sin(theta);
	if tx >= 0
		hAlign = 'left';
		tx = tx + 0.005;
	else
		hAlign = 'right';
		tx = tx - 0.005;
	end
	text(ax, tx, ty, sideText, 'FontSize', 6, 'FontWeight', 'normal', ...
		'Color', minorColor, 'HorizontalAlignment', hAlign, ...
		'VerticalAlignment', 'middle', 'Clipping', 'off');
end
end

function outText = iCapitalizeLeadingLetter(inText)
outText = string(inText);
chars = char(outText);
idx = regexp(chars, '[A-Za-z]', 'once');
if isempty(idx)
	return;
end
chars(idx) = upper(chars(idx));
outText = string(chars);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end
