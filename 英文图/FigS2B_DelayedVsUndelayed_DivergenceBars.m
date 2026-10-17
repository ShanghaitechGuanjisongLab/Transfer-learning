% FigS2B（英文图）：光/声两 tile 的逐鼠散度柱状图（2×1），中文图54B 的二维分组表条形样式
% （+TransferLearning/PlotPreFormalConnectionWeightStdBars.m）+ 英文图1E 的散度口径
% （英文图/Fig1E_LightWater_NaiveVsTransfer_DivByLayer.m）。
%
% 组覆盖与英文图/FigS2A_DelayedVsUndelayed_DivergencePCA_L23.m 完全一致的 8 组：
%   上 tile = 光（💡）：💡💧Naive + 💡💧Transfer × {Undelayed, Delayed}；
%   下 tile = 声（🔊）：🔊Naive + 🔊💧Learned × {Undelayed, Delayed}。
%   光-Undelayed 两组用英文图1D 口径（Naive = LightAudioBaseline+LAInterspersed 首个纯 LW
%   Naive 会话，LAI 中 Naive 期出现过 AudioWater 的鼠整只排除；Transfer = AudioLightBaseline
%   首个 Transfer LW 会话）；其余会话取法同 FigS2A（含 Undelayed 声侧只保留两阶段都有的鼠、
%   Delayed 无 Phase 列取首个/最后一个目标会话、ALB 的 Learned 会话=最后一个非 Recall 的
%   AudioWater 会话）。回合集合与 FigS2A 一致（Delayed 光侧 LightLearnWater+LightLearnWaterAlways，
%   Delayed 声侧只 AudioLearnWater）。
%
% 每 tile 的二维分组表（用户裁定）：X 轴 = 范式（Undelayed/Delayed），
% 条形颜色 = 阶段（声 tile：Naive=NaiveColor 紫、Learned=ColorB 绿；
% 光 tile：Naive=NaiveColor 紫、Transfer=TransferColor 橙），与 FigS2A 列配色一致。
%
% 散度（同英文图1E，不分 2/5 层）：逐鼠逐组取该会话全部目标回合（按 TrialIndex 排序），
% QueryNTS ZScore（基线 1:24）构建 细胞×回合×时间 CTT，取指定时刻的 细胞×回合 矩阵 X：
%   div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )
% 时刻按范式给水点：Delayed 取 +1.5 s，Undelayed 取 +1 s（离 TransferLearning.Xs 最近采样）。
% 细胞集合 = MOp2/3 + MOp5 全部混在一起（真正的不分层），每鼠每组一个散度值（LAB+LAI 重复
% 鼠按 Fig1E 口径取均值合并），柱高 = 逐鼠均值 ± s.e.m.。
%
% 显著性标注（用户裁定）：同中文图54B 样式——每 X 组内两阶段的组间 P 值线
% （BarScatterCompare 二维 compareGroup + AsteriskThreshold 0.05，PLine/PText 走标准样式
% Retune），不画每鼠散点。
%
% Outputs (SVG):
%   - English_FigS2B_DelayedVsUndelayed_DivergenceBars.svg
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

% ---- 会话取法（同 FigS2A / 英文图1D）----
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

% ---- 组规格：tile × 阶段 × 范式 ----
paradigmLabels = ["Undelayed", "Delayed"];
stageLabels = {["Naive", "Transfer"], ["Naive", "Learned"]};   % {光 tile, 声 tile}
stageColors = {[TransferLearning.NaiveColor; TransferLearning.TransferColor], ...
	[TransferLearning.NaiveColor; TransferLearning.ColorB]};
tileEmoji = ["💡", "🔊"];
tileOrder = [1, 2];   % 上=光，下=声
% Spec{tile, stage, paradigm} = struct('Sess',…,'Stim',…,'IdxT',…)
Spec = cell(2, 2, 2);
Spec{1, 1, 1} = struct('Sess', sessNU, 'Stim', "LightWater");
Spec{1, 1, 2} = struct('Sess', sessND, 'Stim', ["LightLearnWater", "LightLearnWaterAlways"]);
Spec{1, 2, 1} = struct('Sess', sessTU, 'Stim', "LightWater");
Spec{1, 2, 2} = struct('Sess', sessTD, 'Stim', ["LightLearnWater", "LightLearnWaterAlways"]);
Spec{2, 1, 1} = struct('Sess', sessAU, 'Stim', "AudioOnly");
Spec{2, 1, 2} = struct('Sess', sessAD, 'Stim', "AudioPreTrainCueOnly");
Spec{2, 2, 1} = struct('Sess', sessAWU, 'Stim', "AudioWater");
Spec{2, 2, 2} = struct('Sess', sessAWD, 'Stim', "AudioLearnWater");

% ---- 逐鼠散度（Fig1E 口径，不分层）----
DivVals = cell(2, 2, 2);   % {tile, stage, paradigm} = 逐鼠散度列向量
for iTile = 1:2
	for iStage = 1:2
		for iPara = 1:2
			sp = Spec{iTile, iStage, iPara};
			idxT = iFindTimeIndex(iPara);   % Delayed +1.5 s，Undelayed +1 s
			rows = iSessionDivergenceRows(sp.Sess, sp.Stim, idxT);
			rows = iCollapseByMouse(rows);
			DivVals{iTile, iStage, iPara} = rows.Div;
			fprintf('%s %s / %s: n=%d mice, div = %.4f ± %.4f\n', tileEmoji(iTile), ...
				stageLabels{iTile}(iStage), paradigmLabels(iPara), ...
				sum(isfinite(rows.Div)), mean(rows.Div, 'omitnan'), iSem(rows.Div));
		end
	end
end
%%

% ---------- figure（中文图54B 样式二维分组表条形图） ----------
f = figure('Color', 'w', 'Name', 'English FigS2B delayed vs undelayed divergence bars light and sound');
f.Units = 'centimeters';
f.Position(3:4) = [6, 8];

tlo = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');axAll = gobjects(2, 1);
barAll = cell(2, 1);
errAll = cell(2, 1);for iRow = 1:2
	iTile = tileOrder(iRow);
	ax = nexttile(tlo);
	dataCell = cell(2, 2);   % 行 = 范式，列 = 阶段
	for iPara = 1:2
		for iStage = 1:2
			dataCell{iPara, iStage} = DivVals{iTile, iStage, iPara};
		end
	end
	dataTable = cell2table(dataCell, 'VariableNames', cellstr(stageLabels{iTile}), ...
		'RowNames', cellstr(paradigmLabels));
	dataTable.Properties.DimensionNames = cellstr(["Paradigm", "Stage"]);
	compareGroup = iWithinItemCompareGroup(paradigmLabels, stageLabels{iTile}, dataTable.Properties.DimensionNames);
	colorTable = array2table(stageColors{iTile}, 'VariableNames', {'R','G','B'}, ...
		'RowNames', cellstr(stageLabels{iTile}));
	[~, optional, barHandles, errorBars] = UniExp.BarScatterCompare(dataTable, compareGroup, ...
		colorTable, ax, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
	delete(findobj(ax, 'Type', 'Scatter'));   % 不画每鼠散点（用户裁定）
	iStyleBars(ax, barHandles, errorBars, stageColors{iTile});
	axAll(iRow) = ax;
	barAll{iRow} = barHandles;
	errAll{iRow} = errorBars;
	legendHandle = optional.Legend;
	legendHandle.String = cellstr(stageLabels{iTile});
	legendHandle.Title.String = 'Stage';
	legendHandle.Title.FontWeight = 'normal';
	legendHandle.Location = 'eastoutside';
	legendHandle.Box = 'off';
	title(ax, tileEmoji(iTile));
	if iRow == 1
		% 上 tile 清空 x 刻度标签但保留 X 轴；下 tile 不改（组名只由下 tile 的 x 轴标出）
		xticklabels(ax, {});
	else
		xlabel(ax, 'Paradigm');
	end
	box(ax, 'off');
	grid(ax, 'off');
	iRetunePValueLines(optional);
end
% Divergence 标在 layout 级 ylabel（用户裁定）
ylabel(tlo, 'Divergence');

TransferLearning.ApplyStandardExportStyle(f, 2);
% 统一两 tile 的误差条 CapSize（用户裁定）：布局定型后按 54B 公式取两 tile 均值统一施加
iUnifyErrorBarCapSizes(axAll, barAll, errAll, 0.5);
% 标准样式会自动旋转较长的 x 刻度标签，tight padding 下会被裁切，强制归零（同 DeltaBars）
for iRow = 1:2
	axAll(iRow).XTickLabelRotation = 0;
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS2B_DelayedVsUndelayed_DivergenceBars.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'FigS2B_Divergence', DivVals);
assignin('base', 'FigS2B_GroupLabels', struct('Paradigm', paradigmLabels, ...
	'Tile', tileEmoji, 'Stage', {stageLabels}));

%% ========== local functions ==========
% ---------- 散度（英文图1E 口径） ----------
function rows = iSessionDivergenceRows(sessTable, stimNames, idxT)
% 逐会话散度：全部目标回合（按 TrialIndex 排序）→ ZScore CTT → 取 idxT 时刻 → 不分层散度。
rows = table(strings(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'Div'});
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
	CTT = iBuildCtt(nts, trialUIDs);
	if isempty(CTT) || size(CTT, 1) < 3
		continue;
	end
	X = CTT(:, :, idxT);
	rows = [rows; table(string(m), iDivFromX(X), 'VariableNames', {'Mouse', 'Div'})]; %#ok<AGROW>
end
end

function CTT = iBuildCtt(nts, trialUIDs)
% cells × trials × time；细胞需覆盖全部回合且数据有限（同 Fig1E）。
allCells = unique(uint64(nts.CellUID));
traces = cell(numel(allCells), 1);
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
end
if nKeep < 3
	CTT = [];
	return;
end
traces = traces(1:nKeep);
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
% 同一鼠多来源（如 LAB+LAI 的 Naive）按均值合并（同 Fig1E）。
if isempty(rows)
	return;
end
[G, mouseU] = findgroups(rows.Mouse);
div = splitapply(@(v) mean(v, 'omitnan'), rows.Div, G);
rows = table(mouseU, div, 'VariableNames', {'Mouse', 'Div'});
end

function idx = iFindTimeIndex(iPara)
% Delayed 取 +1.5 s，Undelayed 取 +1 s（TransferLearning.Xs 最近采样）。
if iPara == 2
	targetSec = 1.5;
else
	targetSec = 1;
end
xsSec = seconds(TransferLearning.Xs);
[~, idx] = min(abs(xsSec(:) - targetSec));
end

function s = iSem(v)
v = v(:);
v = v(isfinite(v));
if isempty(v)
	s = NaN;
	return;
end
s = std(v) / sqrt(numel(v));
end

% ---------- 会话取法（同 FigS2A / 英文图1D） ----------
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
% 延迟库（ALDelayed/LADelayed）无 Phase 列：每鼠取首个含 LightLearnWater 回合的 DateTime。
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
% 每鼠最后一个含 stim 回合的 DateTime；excludePhases 中的 Phase 会话跳过（如 Recall）。
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
% 通用回合表；库带 Phase 列时一并取出（用于排除 Recall 等）。
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

% ---------- 条形样式（中文图54B：+TransferLearning/PlotPreFormalConnectionWeightStdBars.m） ----------
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
% 统一各 tile 误差条 CapSize（用户裁定）：逐 tile 按 54B 公式计算后取均值，
% 再把同一个值施加到所有误差条，保证跨 tile 视觉一致。
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
% 54B 式 P 值线整备：PLineRetune + 打 PLine/PText 标签供标准样式接管
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
	end
end
for pText = optional.MultiCompare.PText(:)'
	if isgraphics(pText)
		pText.Tag = 'PText';
	end
end
end
