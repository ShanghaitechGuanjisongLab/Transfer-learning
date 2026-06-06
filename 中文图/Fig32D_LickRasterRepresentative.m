% Fig32D: 代表性训练日的舔水原始记录（Naive vs Transfer）
%
% 横轴为时间[-1, 2]s，纵轴为试次序号，颜色为二值化舔水（0/1）。
% 二值化方法：以[-3,0]s基线均值+2倍标准差为阈值，超过即判定为舔水。
% 两张子图：Naive代表日 / Transfer代表日。
% CD2取自ResampledTags，时间轴为TransferLearning.Xs。

warning('off', 'backtrace');

if ~exist('TransferLearning','class') || ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

%% 加载数据
LAB = TransferLearning.LightAudioBaseline();  % Naive LightWater
ALB = TransferLearning.AudioLightBaseline();  % Transfer LightWater

xs = TransferLearning.Xs;
xsSec = seconds(xs);

% 显示窗口 [-1, 2]
winMask = xsSec >= -1 & xsSec <= 2;
xsWin = xsSec(winMask);

%% 选择代表性会话
% Naive: yqn0044, 2022-07-04 21:42, perf=0%（首次接触光水，无预期舔水）
% Transfer: yqn0020, 2024-04-24 05:57, perf=83%（迁移首日，已有学习迁移）

% 基线窗口 [-3, 0]
blMask = xsSec >= -3 & xsSec < 0;

[naiveMat, naiveBehav] = iExtractSessionCD2(LAB, "yqn0044", datetime(2022,7,4,21,42,0), winMask, blMask);
[tranMat, tranBehav]   = iExtractSessionCD2(ALB, "yqn0020", datetime(2024,4,24,5,57,0), winMask, blMask);

%% 作图
f = figure('Color', 'w', 'Name', 'Fig32D LickRaster');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];  % 90mm x 80mm (高度40mm倍数 x2)
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0 0 9 8];
f.PaperSize = [9 8];

tl = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'tight');

% 💡 at t=0, 💧 at t=1
tLight = 0;
tWater = 1;
behaviorColors = TransferLearning.GroupColors(["Miss","Hit"]);
lickColor = TransferLearning.ColorB;

% --- Naive ---
ax1 = nexttile(tl, 1);
imagesc(ax1, xsWin, 1:size(naiveMat,1), naiveMat);
hold(ax1, 'on');
xline(ax1, tLight, '--', 'LineWidth', 2);
xline(ax1, tWater, '--', 'LineWidth', 2);
ax1.YDir = 'reverse';
ax1.FontSize = 12;
ax1.LineWidth = 2;
title(ax1, 'Naive', 'FontSize', 12, 'FontWeight', 'normal');
iReplaceTickWithEmoji(ax1, tLight, '💡', tWater, '💧');
box(ax1, 'off');

% 在右侧标注Hit/Miss色带
iDrawBehaviorStrip(ax1, naiveBehav, xsWin, behaviorColors);

% --- Transfer ---
ax2 = nexttile(tl, 2);
imagesc(ax2, xsWin, 1:size(tranMat,1), tranMat);
hold(ax2, 'on');
xline(ax2, tLight, '--', 'LineWidth', 2);
xline(ax2, tWater, '--', 'LineWidth', 2);
ax2.YDir = 'reverse';
ax2.FontSize = 12;
ax2.LineWidth = 2;
xlabel(ax2, 'Time (s)', 'FontSize', 12);
ylabel(tl, 'Trial', 'FontSize', 12);
title(ax2, 'Continual', 'FontSize', 12, 'FontWeight', 'normal');
iReplaceTickWithEmoji(ax2, tLight, '💡', tWater, '💧');
box(ax2, 'off');

iDrawBehaviorStrip(ax2, tranBehav, xsWin, behaviorColors);

% 使用二值colormap: 白=0(无舔), 有色=1(舔水)
cmap2 = [1 1 1; lickColor];
colormap(ax1, cmap2);
colormap(ax2, cmap2);
clim(ax1, [0 1]);
clim(ax2, [0 1]);

% 图例：用一个隐藏的patch在ax1上标注
pLick = patch(ax1, NaN, NaN, cmap2(2,:), 'EdgeColor', 'none', 'DisplayName', 'Lick');
lg = legend(ax1, pLick, 'Location', 'northwest');
lg.FontSize = 12;
lg.Box = 'off';

%% 导出
svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig32D_LickRaster.svg');
fprintf('Saved SVG: %s\n', svgPath);

%% === 辅助函数 ===

function [mat, behav] = iExtractSessionCD2(DS, mouseName, targetDT, winMask, blMask)
% 提取指定鼠指定会话的LightWater试次CD2，二值化后返回 nTrials x nTimeBins 矩阵
% 二值化：基线均值(每试次[-3,0]s) + 1倍全Block CD2标准差
mouseName = string(mouseName);
blks = DS.Blocks;
blks.BlockUID = uint64(blks.BlockUID);
blks.DateTime = datetime(blks.DateTime);
if ~isempty(blks.DateTime.TimeZone); blks.DateTime.TimeZone = ''; end

% 找到目标DateTime对应的Block
sessBlks = blks(blks.DateTime == targetDT, :);
if isempty(sessBlks)
	error('Session not found: %s @ %s', mouseName, char(targetDT));
end

% 计算全Block CD2的std
blockStds = nan(height(sessBlks), 1);
for iB = 1:height(sessBlks)
	bt = sessBlks.BlockTags{iB};
	blockStds(iB) = double(std(bt.CD2));
end
blockSD = mean(blockStds);  % 若多个block取均值

tr = DS.Trials;
tr.BlockUID = uint64(tr.BlockUID);

% 筛选该session的LightWater试次
mask = ismember(tr.BlockUID, sessBlks.BlockUID) & string(tr.Stimulus) == "LightWater";
sessTr = tr(mask, :);
sessTr = sortrows(sessTr, 'TrialIndex');

nTrials = height(sessTr);
nBins = sum(winMask);
mat = nan(nTrials, nBins);

rt = sessTr.ResampledTags;
for i = 1:nTrials
	cd2 = rt{i}.CD2;
	bl = cd2(blMask);
	thresh = mean(bl) + blockSD;
	binarized = double(cd2 > thresh);
	mat(i, :) = binarized(winMask);
end

behav = double(sessTr.Behavior);
end



function iReplaceTickWithEmoji(ax, t1, emoji1, t2, emoji2)
% 保留默认XTick，只把对应位置的label替换为emoji
ticks = ax.XTick;
labels = string(ax.XTickLabel);
for i = 1:numel(ticks)
	if abs(ticks(i) - t1) < 1e-10
		labels(i) = emoji1;
	elseif abs(ticks(i) - t2) < 1e-10
		labels(i) = emoji2;
	end
end
ax.XTickLabel = labels;
end

function iDrawBehaviorStrip(ax, behav, xsWin, behaviorColors)
% 在热图右侧画一条细的Hit/Miss色带
stripX = xsWin(end) + diff(xsWin(1:2)) * 1.5;
stripW = diff(xsWin(1:2)) * 2;
for i = 1:numel(behav)
	if behav(i) == 1
		clr = behaviorColors(2,:);
	else
		clr = behaviorColors(1,:);
	end
	rectangle(ax, 'Position', [stripX, i-0.5, stripW, 1], 'FaceColor', clr, 'EdgeColor', 'none');
end
end
