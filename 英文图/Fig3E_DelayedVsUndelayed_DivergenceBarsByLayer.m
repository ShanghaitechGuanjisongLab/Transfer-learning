% 英文图3E：2×2 逐鼠散度柱状图，把英文图S2B 按 MOp2/3 与 MOp5 拆开。
% 行 = 层（上 = MOp2/3，下 = MOp5），列 = 模态（左 = 💡 光，右 = 🔊 声）。
% 会话口径、回合集合、散度公式、时刻取法与 英文图/FigS2B_DelayedVsUndelayed_DivergenceBars.m 完全一致，
% 仅把细胞集合分成 MOp2/3 与 MOp5 两层分别计算（分层实现同 英文图/Fig1E_LightWater_NaiveVsTransfer_DivByLayer.m）。
%
% 组覆盖（每 tile 内 X 轴 = 范式 Undelayed/Delayed，条形颜色 = 阶段）：
%   光列：💡💧Naive（NaiveColor 紫）+ 💡💧Transfer（TransferColor 橙）× {Undelayed, Delayed}；
%   声列：🔊Naive（NaiveColor 紫）+ 🔊💧Learned（ColorB 绿）× {Undelayed, Delayed}。
% 散度：逐鼠逐组取该会话全部目标回合，QueryNTS ZScore（基线 1:24）构建 细胞×回合×时间 CTT，
% 取指定时刻的 细胞×回合 矩阵 X，div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )；
% Delayed 取 +1.5 s，Undelayed 取 +1 s。每层独立计算，柱高 = 逐鼠均值 ± s.e.m.。
%
% 显著性：同 FigS2B——每 X 组内两阶段的组间 P 值线（BarScatterCompare 二维 compareGroup +
% AsteriskThreshold 0.05），不画每鼠散点。
%
% Outputs (SVG):
%   - English_Fig3E_DelayedVsUndelayed_DivergenceBarsByLayer.svg
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

% ---- 会话取法（同 FigS2B / 英文图1D）----
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
LAD = TransferLearning.LADelayed();
ALD = TransferLearning.ALDelayed();
badNaiveLai = iMiceWithStimulusInPhase(LAI, "AudioWater", "Naive");
sessNU = [iFirstPureLWNaiveSessions(LAB, strings(0, 1)); iFirstPureLWNaiveSessions(LAI, badNaiveLai)];
sessTU = iFirstTransferLWSessions(ALB);
sessAU = iFirstStimSession(ALB, "AudioOnly");
sessAWU = iLastStimSession(ALB, "AudioWater", "Recall");
miceU = intersect(sessAU.Mouse, sessAWU.Mouse);
sessAU = sessAU(ismember(sessAU.Mouse, miceU), :);
sessAWU = sessAWU(ismember(sessAWU.Mouse, miceU), :);
sessND = iFirstLightLearnSessions(LAD);
sessTD = iFirstLightLearnSessions(ALD);
sessAD = iFirstStimSession(ALD, "AudioPreTrainCueOnly");
sessAWD = iLastStimSession(ALD, "AudioLearnWater", "Recall");
%% 

% ---- 组规格：模态 × 阶段 × 范式（同 FigS2B）----
paradigmLabels = ["Undelayed", "Delayed"];
stageLabels = {["Naive", "Transfer"], ["Naive", "Learned"]};   % {光, 声}
stageColors = {[TransferLearning.NaiveColor; TransferLearning.TransferColor], ...
	[TransferLearning.NaiveColor; TransferLearning.ColorB]};
tileEmoji = ["💡", "🔊"];   % 列：左光右声
layerLabels = ["MOp2/3", "MOp5"];   % 行：上 2/3 下 5
Spec = cell(2, 2, 2);
Spec{1, 1, 1} = struct('Sess', sessNU, 'Stim', "LightWater");
Spec{1, 1, 2} = struct('Sess', sessND, 'Stim', ["LightLearnWater", "LightLearnWaterAlways"]);
Spec{1, 2, 1} = struct('Sess', sessTU, 'Stim', "LightWater");
Spec{1, 2, 2} = struct('Sess', sessTD, 'Stim', ["LightLearnWater", "LightLearnWaterAlways"]);
Spec{2, 1, 1} = struct('Sess', sessAU, 'Stim', "AudioOnly");
Spec{2, 1, 2} = struct('Sess', sessAD, 'Stim', "AudioPreTrainCueOnly");
Spec{2, 2, 1} = struct('Sess', sessAWU, 'Stim', "AudioWater");
Spec{2, 2, 2} = struct('Sess', sessAWD, 'Stim', "AudioLearnWater");

% ---- 逐鼠分层散度（Fig1E 口径）----
% DivByLayer{modality, stage, para} = table(Mouse, DivL23, DivL5)
DivByLayer = cell(2, 2, 2);
for iTile = 1:2
	for iStage = 1:2
		for iPara = 1:2
			sp = Spec{iTile, iStage, iPara};
			idxT = iFindTimeIndex(iPara);
			rows = iSessionDivergenceByLayer(sp.Sess, sp.Stim, idxT);
			DivByLayer{iTile, iStage, iPara} = iCollapseByMouse(rows);
		end
	end
end
%%

% ---------- figure：2×2，行=层，列=模态 ----------
f = figure('Color', 'w', 'Name', 'English Fig3E delayed vs undelayed divergence bars by layer');
f.Units = 'centimeters';
f.Position(3:4) = [15, 8];

tlo = tiledlayout(f, 2, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
axAll = gobjects(2, 2);
barAll = cell(2, 2);
errAll = cell(2, 2);
% X 轴刻度标签：给 Delayed 前缀空格使其与 Undelayed 等长
paradigmTickLabels = ["Undelayed", "Delayed"];
for iLayer = 1:2
	layerField = iif(iLayer == 1, "DivL23", "DivL5");
	for iTile = 1:2
		ax = nexttile(tlo);
		dataCell = cell(2, 2);   % 行 = 范式，列 = 阶段
		for iPara = 1:2
			for iStage = 1:2
				dataCell{iPara, iStage} = DivByLayer{iTile, iStage, iPara}.(layerField);
			end
		end
		dataTable = cell2table(dataCell, 'VariableNames', cellstr(stageLabels{iTile}), ...
			'RowNames', cellstr(paradigmLabels));
		dataTable.Properties.DimensionNames = cellstr(["Paradigm", "Stage"]);
		compareGroup = iWithinItemCompareGroup(paradigmLabels, stageLabels{iTile}, dataTable.Properties.DimensionNames);
		colorTable = array2table(stageColors{iTile}, 'VariableNames', {'R','G','B'}, ...
			'RowNames', cellstr(stageLabels{iTile}));
		% 不画散点：BarScatterCompare 默认不显示散点（仅加 ShowScatter 旗帜才画），故无需事后删除
		[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, ...
			colorTable, ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
		iStyleBars(ax, barHandles, errorBars, stageColors{iTile});
		axAll(iLayer, iTile) = ax;
		barAll{iLayer, iTile} = barHandles;
		errAll{iLayer, iTile} = errorBars;
		legendHandle = optional.Legend;
		legendHandle.String = cellstr(stageLabels{iTile});
		legendHandle.Title.String = 'Stage';
		legendHandle.Title.FontWeight = 'normal';
		legendHandle.Location = 'eastoutside';
		legendHandle.Box = 'off';
		% 列标题（模态 emoji）只写在首行；层名写在首列 ylabel
		if iLayer == 1
			title(ax, tileEmoji(iTile));
		end
		if iTile == 1
			ylabel(ax, layerLabels(iLayer));
		end
		% 统一 X 轴刻度标签（前缀空格等长）；上行清空刻度标签只保留下行标注
		xticklabels(ax, paradigmTickLabels);
		if iLayer == 1
			xticklabels(ax, {});
		elseif iLayer == 2
			xlabel(ax, 'Paradigm');
		end
		box(ax, 'off');
		grid(ax, 'off');
		iRetunePValueLines(optional);
	end
end
% Divergence 标在 layout 级 ylabel
ylabel(tlo, 'Divergence');

% 先应用标准样式，再做自定义调整（统一 CapSize），最后用 print 导出
% （不要同时用 ApplyStandardExportStyle 与 ExportStandardFigure——后者内部已含前者）
TransferLearning.ApplyStandardExportStyle(f, 2);
% 统一各 tile 误差条 CapSize
iUnifyErrorBarCapSizes(axAll(:).', barAll(:).', errAll(:).', 0.5);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig3E_DelayedVsUndelayed_DivergenceBarsByLayer.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3E_DivergenceByLayer', DivByLayer);
assignin('base', 'Fig3E_GroupLabels', struct('Paradigm', paradigmLabels, ...
	'Tile', tileEmoji, 'Stage', {stageLabels}, 'Layer', layerLabels));

%% ========== local functions ==========
% ---------- 分层散度（Fig1E 口径） ----------
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

function idx = iFindTimeIndex(iPara)
if iPara == 2
	targetSec = 1.5;
else
	targetSec = 1;
end
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

% ---------- 会话取法（同 FigS2B / 英文图1D） ----------
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

function sess = iFirstLightLearnSessions(DS)
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T)
	return;
end
T = T(T.Stimulus == "LightLearnWater", :);
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

% ---------- 条形样式（同 FigS2B） ----------
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
