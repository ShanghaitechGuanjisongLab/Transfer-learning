% 英文图2O：2×1 逐鼠散度柱状图（Undelayed），模仿英文图3E（Fig3E_DelayedVsUndelayed_DivergenceBarsByLayer）。
% 相对 3E 的改动：
%   - 去掉 Delayed 数据，只做 Undelayed；图上不再标 Undelayed/Delayed 范式信息；
%   - tiledlayout 2 行 1 列：上 = 🔊 声任务（Naive vs Learned），下 = 💡 光任务（Naive vs 12h transfer）；
%   - 二维分组表原 Paradigm 维度换成层维度（MOp2/3 / MOp5），行 = 层、列 = 阶段；
%   - 配色按语义用 TransferLearning.ColorNaive/ColorLearned/Color12h（0-255，/255）：
%       声列组 Naive=ColorNaive（深紫黑）、Learned=ColorLearned（深蓝）；
%       光列组 Naive=ColorNaive（深紫黑）、12h=Color12h（紫）。
%
% 会话口径、回合集合、散度公式、时刻取法同 3E 的 Undelayed 半套（=英文图S2B 无延迟侧）：
%   💡 Naive = LAB+LAI 首个纯光水 Naive 会话（LAI 中 Naive 期出现过声水者整只排除）；
%   💡 12h  = ALB 首个 Transfer 光水会话；
%   🔊 Naive = ALB 首个 AudioOnly 会话；🔊 Learned = ALB 最后一个 AudioWater 会话（Recall 除外）；
%   声两侧取同鼠交集。
% 散度：逐鼠逐组取该会话全部目标回合，QueryNTS ZScore（基线 1:24）构建 细胞×回合×时间 CTT，
% 取 cue+1 s 的 细胞×回合 矩阵 X，div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )；
% 每层（MOp2/3、MOp5）独立计算，柱高 = 逐鼠均值 ± s.e.m.。
% 显著性：同 3E——每层内两阶段的组间 P 值线（BarScatterCompare 二维 compareGroup +
% AsteriskThreshold 0.05），不画每鼠散点。
%
% Outputs (SVG):
%   - English_Fig2O_Undelayed_DivergenceBarsByLayer.svg
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

% ---- 会话取法（同 3E 的 Undelayed 半套）----
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
badNaiveLai = iMiceWithStimulusInPhase(LAI, "AudioWater", "Naive");
sessNU = [iFirstPureLWNaiveSessions(LAB, strings(0, 1)); iFirstPureLWNaiveSessions(LAI, badNaiveLai)];
sessTU = iFirstTransferLWSessions(ALB);
sessAU = iFirstStimSession(ALB, "AudioOnly");
sessAWU = iLastStimSession(ALB, "AudioWater", "Recall");
miceU = intersect(sessAU.Mouse, sessAWU.Mouse);
sessAU = sessAU(ismember(sessAU.Mouse, miceU), :);
sessAWU = sessAWU(ismember(sessAWU.Mouse, miceU), :);
%%

% ---- 组规格：任务(行) × 阶段 × 层(列) ----
tileEmoji = ["🔊", "💡"];                       % 行标题：上声下光
stageLabels = {["Naive", "Learned"], ["Naive", "12h"]};   % {声, 光}（12h = Transfer 光迁移组）
stageColors = {[TransferLearning.ColorNaive; TransferLearning.ColorLearned] / 255, ...
	[TransferLearning.ColorNaive; TransferLearning.Color12h] / 255};
layerLabels = ["MOp2/3", "MOp5"];               % 二维分组的行维度：层
Spec = cell(2, 2);
Spec{1, 1} = struct('Sess', sessAU, 'Stim', "AudioOnly");           % 声 Naive
Spec{1, 2} = struct('Sess', sessAWU, 'Stim', "AudioWater");         % 声 Learned
Spec{2, 1} = struct('Sess', sessNU, 'Stim', "LightWater");          % 光 Naive
Spec{2, 2} = struct('Sess', sessTU, 'Stim', "LightWater");          % 光 12h transfer
idxT = iFindTimeIndex(1.0);                                          % Undelayed 取 cue+1 s

% ---- 逐鼠分层散度（同 3E / Fig1E 口径）----
DivByLayer = cell(2, 2);   % {task, stage} = table(Mouse, DivL23, DivL5)
for iTask = 1:2
	for iStage = 1:2
		sp = Spec{iTask, iStage};
		rows = iSessionDivergenceByLayer(sp.Sess, sp.Stim, idxT);
		DivByLayer{iTask, iStage} = iCollapseByMouse(rows);
	end
end
%%

% ---------- figure：2×1，行 = 任务 ----------
f = figure('Color', 'w', 'Name', 'English Fig2O undelayed divergence bars by layer');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

tlo = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
axAll = gobjects(2, 1);
barAll = cell(2, 1);
errAll = cell(2, 1);
for iTask = 1:2
	ax = nexttile(tlo);
	dataCell = cell(2, 2);   % 行 = 层，列 = 阶段
	for iLayer = 1:2
		layerField = iif(iLayer == 1, "DivL23", "DivL5");
		for iStage = 1:2
			dataCell{iLayer, iStage} = DivByLayer{iTask, iStage}.(layerField);
		end
	end
	dataTable = cell2table(dataCell, 'VariableNames', cellstr(stageLabels{iTask}), ...
		'RowNames', cellstr(layerLabels));
	dataTable.Properties.DimensionNames = cellstr(["Layer", "Stage"]);
	compareGroup = iWithinItemCompareGroup(layerLabels, stageLabels{iTask}, dataTable.Properties.DimensionNames);
	colorTable = array2table(stageColors{iTask}, 'VariableNames', {'R','G','B'}, ...
		'RowNames', cellstr(stageLabels{iTask}));
	% 不画散点：BarScatterCompare 默认不显示散点（仅加 ShowScatter 旗帜才画）
	[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, ...
		colorTable, ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
	iStyleBars(ax, barHandles, errorBars, stageColors{iTask});
	axAll(iTask) = ax;
	barAll{iTask} = barHandles;
	errAll{iTask} = errorBars;
	legendHandle = optional.Legend;
	legendHandle.String = cellstr(stageLabels{iTask});
	legendHandle.Title.String = 'Stage';
	legendHandle.Title.FontWeight = 'normal';
	legendHandle.Location = 'eastoutside';
	legendHandle.Box = 'off';
	% 行标题（任务 emoji）：每个 tile 各自标注；不再另写任务文字 ylabel（与 emoji 重复）
	ylabel(ax, tileEmoji(iTask));
	% 层名放 X 轴刻度；上行清空刻度标签，下行补层维度名
	xticklabels(ax, layerLabels);
	if iTask == 1
		xticklabels(ax, {});
	elseif iTask == 2
		xlabel(ax, 'Layer');
	end
	box(ax, 'off');
	grid(ax, 'off');
	iRetunePValueLines(optional);
end
% Divergence 标在 layout 级 ylabel
ylabel(tlo, 'Divergence');

% 先应用标准样式，再做自定义调整（统一 CapSize），最后用 print 导出
% （不要同时用 ApplyStandardExportStyle 与 ExportStandardFigure——后者内部已含前者）
TransferLearning.ApplyStandardExportStyle(f, 2);
% 统一各 tile 误差条 CapSize
iUnifyErrorBarCapSizes(axAll(:).', barAll(:).', errAll(:).', 0.5);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig2O_Undelayed_DivergenceBarsByLayer.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2O_DivergenceByLayer', DivByLayer);
assignin('base', 'Fig2O_GroupLabels', struct('Task', taskLabels, 'Tile', tileEmoji, ...
	'Stage', {stageLabels}, 'Layer', layerLabels));

%% ========== local functions ==========
% ---------- 分层散度（Fig1E 口径，同 3E） ----------
function rows = iSessionDivergenceByLayer(sessTable, stimNames, idxT)
rows = table(strings(0, 1), nan(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
for iS = 1:height(sessTable)
	DS = sessTable.DS(iS);
	m = sessTable.Mouse(iS);
	dt = sessTable.DateTime(iS);
	ntsCell = DS.QueryNTS(struct('Stimulus', stimNames, 'Mouse', m, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
	if isempty(nts)
		continue;
	end
	trialUIDs = unique(uint64(nts.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	[CTT, cellUIDs] = iBuildCtt(nts, trialUIDs);
	if isempty(CTT) || size(CTT, 1) < 3
		continue;
	end
	X = CTT(:, :, idxT);
	CellTbl = DS.Cells;
	CellTbl.CellUID = uint64(CellTbl.CellUID);
	CellTbl.Mouse = string(CellTbl.Mouse);
	CellTbl.ZLayer = string(CellTbl.ZLayer);
	cellMeta = CellTbl(CellTbl.Mouse == m, {'CellUID', 'ZLayer'});
	[tf, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs), 1);
	layers(tf) = cellMeta.ZLayer(loc(tf));
	mask23 = layers == "MOp2/3";
	mask5 = layers == "MOp5";
	d23 = NaN;
	d5 = NaN;
	if sum(mask23) >= 3
		d23 = iDivFromX(X(mask23, :));
	end
	if sum(mask5) >= 3
		d5 = iDivFromX(X(mask5, :));
	end
	rows = [rows; table(string(m), d23, d5, 'VariableNames', {'Mouse', 'DivL23', 'DivL5'})]; %#ok<AGROW>
end
end

function [CTT, cellUIDs] = iBuildCtt(nts, trialUIDs)
allCells = unique(uint64(nts.CellUID));
traces = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rowsC = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rowsC));
	sig = double(nts.TrialSignal(rowsC, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	so = sig(loc, :);
	if any(~isfinite(so), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepUID(nKeep) = cid;
end
if nKeep < 3
	CTT = [];
	cellUIDs = uint64([]);
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

function rows = iCollapseByMouse(rows)
if isempty(rows)
	return;
end
[G, mouseU] = findgroups(rows.Mouse);
d23 = splitapply(@(v) mean(v, 'omitnan'), rows.DivL23, G);
d5 = splitapply(@(v) mean(v, 'omitnan'), rows.DivL5, G);
rows = table(mouseU, d23, d5, 'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
end

function idx = iFindTimeIndex(targetSec)
xsSec = seconds(TransferLearning.Xs);
[~, idx] = min(abs(xsSec(:) - targetSec));
end

function out = iif(cond, a, b)
if cond
	out = a;
else
	out = b;
end
end

% ---------- 会话取法（同 3E 的 Undelayed 半套） ----------
function mice = iMiceWithStimulusInPhase(DS, stimulusName, phaseName)
T = DS.TableQuery(["Mouse", "Stimulus", "Phase"], Phase=phaseName);
if isempty(T)
	mice = strings(0, 1);
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
mice = unique(T.Mouse(T.Stimulus == stimulusName));
end

function sess = iFirstPureLWNaiveSessions(DS, excludeMice)
sess = iEmptySessTable(DS);
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Naive");
if isempty(T)
	return;
end
T = iTidyTrialTable(T);
if ~isempty(excludeMice)
	T = T(~ismember(T.Mouse, string(excludeMice)), :);
end
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sessDates = sort(unique(Tm.DateTime), 'ascend');
	for s = 1:numel(sessDates)
		Tss = Tm(Tm.DateTime == sessDates(s), :);
		if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
			sess = [sess; table(DS, mice(i), sessDates(s), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
			break;
		end
	end
end
end

function sess = iFirstTransferLWSessions(DS)
sess = iEmptySessTable(DS);
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Transfer");
if isempty(T)
	return;
end
T = iTidyTrialTable(T);
T = T(T.Stimulus == "LightWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iFirstStimSession(DS, stim)
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T)
	return;
end
T = T(ismember(T.Stimulus, stim), :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iLastStimSession(DS, stim, excludePhases)
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T)
	return;
end
T = T(ismember(T.Stimulus, stim), :);
if ~isempty(excludePhases) && ismember('Phase', T.Properties.VariableNames)
	T = T(~ismember(T.Phase, excludePhases), :);
end
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), max(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iEmptySessTable(DS)
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS','Mouse','DateTime'});
end

function T = iTrialTable(DS)
vars = ["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"];
if any(strcmp('Phase', DS.DateTimes.Properties.VariableNames))
	vars(end+1) = "Phase";
end
T = DS.TableQuery(vars);
if isempty(T)
	return;
end
T = iTidyTrialTable(T);
end

function T = iTidyTrialTable(T)
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
if ismember('Phase', T.Properties.VariableNames)
	T.Phase = string(T.Phase);
end
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
end

% ---------- 条形样式（同 3E） ----------
function compareGroup = iWithinItemCompareGroup(itemLabels, groupLabels, dimensionNames)
itemLabels = string(itemLabels(:));
groupLabels = string(groupLabels(:)).';
itemPair = [itemLabels, itemLabels];
groupPair = repmat(groupLabels(1:2), numel(itemLabels), 1);
GroupPair = table(itemPair, groupPair, 'VariableNames', cellstr(dimensionNames));
compareGroup = table(GroupPair);
end

function iStyleBars(ax, barHandles, errorBars, groupColors)
for iBar = 1:numel(barHandles)
	barHandles(iBar).LineStyle = 'none';
	barHandles(iBar).FaceColor = groupColors(iBar, :);
	if isprop(barHandles(iBar), 'BaseLine') && isgraphics(barHandles(iBar).BaseLine)
		barHandles(iBar).BaseLine.Visible = 'off';
	end
end
for iRow = 1:height(errorBars)
	eBar = errorBars.Object(iRow);
	if ~isgraphics(eBar)
		continue;
	end
	x = double(eBar.XData(1));
	bestDist = inf;
	bestColor = groupColors(1, :);
	for iBar2 = 1:numel(barHandles)
		xp = double(barHandles(iBar2).XEndPoints(:));
		d = min(abs(xp - x));
		if d < bestDist
			bestDist = d;
			bestColor = barHandles(iBar2).FaceColor;
		end
	end
	eBar.Color = bestColor;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end

function iUnifyErrorBarCapSizes(axList, barHandlesList, errorBarsList, capSizeRatio)
capSize = nan(numel(axList), 1);
for iTile = 1:numel(axList)
	ax = axList(iTile);
	axUnits = ax.Units;
	ax.Units = 'points';
	axWidth = ax.Position(3);
	ax.Units = axUnits;
	barHandles = barHandlesList{iTile};
	barWidth = barHandles(1).BarWidth;
	groupWidth = barHandles(1).GroupWidth;
	xRange = diff(xlim(ax));
	nBars = numel(barHandles);
	capSize(iTile) = axWidth * barWidth * groupWidth * capSizeRatio / (xRange * nBars);
end
capSize = mean(capSize, 'omitnan');
for iTile = 1:numel(errorBarsList)
	errorBars = errorBarsList{iTile};
	for iRow = 1:height(errorBars)
		eBar = errorBars.Object(iRow);
		if isgraphics(eBar) && isprop(eBar, 'CapSize')
			eBar.CapSize = capSize;
		end
	end
end
end

function iRetunePValueLines(optional)
if ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
	return;
end
if ~all(ismember({'PLine','PText'}, optional.MultiCompare.Properties.VariableNames))
	return;
end
MATLAB.Graphics.PLineRetune(optional.MultiCompare.PLine, optional.MultiCompare.PText);
for pLine = optional.MultiCompare.PLine(:)'
	if isgraphics(pLine)
		pLine.LineWidth = 1;
		pLine.Tag = 'PLine';
		% 豁免标准样式的线宽调整：保持 P 值线 LineWidth=1 不被导出时改写
		setappdata(pLine, 'TransferLearningPreserveLineWidth', true);
	end
end
for pText = optional.MultiCompare.PText(:)'
	if isgraphics(pText)
		pText.Tag = 'PText';
	end
end
end
