% PPT14：光水首个训练单元 CD2 颜色图（上下双tile）
%
% Top:     Naive —— LightAudioBaseline + LAInterspersed，Naive phase trial
% Bottom:  Continual —— AudioLightBaseline，Transfer phase trial
%
% 每鼠取首个含 LightWater trial 的 Naive/Transfer block；
% 每个时间点的 CD2 值 rescale 到 [0,1]，映射到深绿→浅绿渐变。
% xline 颜色为粉色。

if ~exist('UniExp.DataSet','class')
    thisFile = mfilename('fullpath');
    thisDir = fileparts(thisFile);
    prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
    if exist(prjFile,'file')
        matlab.project.loadProject(prjFile);
    end
end

xs = TransferLearning.Xs;
xsSec = double(seconds(xs));
winMask = xsSec >= -1 & xsSec <= 3;
xsWin = xsSec(winMask);
blMask = xsSec >= -3 & xsSec < 0;

%% --- 提取每鼠首个 Naive/Transfer phase 的 LightWater trial CD2 矩阵 ---
[naiveCD2, naiveMice] = iCollectTrialCD2Matrix( ...
    {TransferLearning.LightAudioBaseline(), TransferLearning.LAInterspersed()}, "Naive", winMask);
[contCD2,  contMice ] = iCollectTrialCD2Matrix( ...
    {TransferLearning.AudioLightBaseline()}, "Transfer", winMask);

fprintf('Naive: %d mice, %d trials\n', numel(naiveMice), size(naiveCD2,1));
fprintf('Continual: %d mice, %d trials\n', numel(contMice), size(contCD2,1));

%% --- Rescale CD2 到 [0,1]（Naive 和 Continual 统一缩放）---
if ~isempty(naiveCD2) || ~isempty(contCD2)
    allVals = [];
    if ~isempty(naiveCD2), allVals = naiveCD2(:); end
    if ~isempty(contCD2),  allVals = [allVals; contCD2(:)]; end
    gMin = min(allVals);
    gMax = max(allVals);
    if ~isempty(naiveCD2)
        naiveCD2 = rescale(naiveCD2, 0, 1, 'InputMin', gMin, 'InputMax', gMax);
    end
    if ~isempty(contCD2)
        contCD2  = rescale(contCD2,  0, 1, 'InputMin', gMin, 'InputMax', gMax);
    end
end

%% --- 自定义颜色映射 ---
nColors = 256;
cmapGreen=MATLAB.ElMat.LinSpace([1,1,1],[0.5414	0.0000	0.8231],256,1);

%% --- 绘图 ---
f = figure('Color','w', 'Name','PPT14 CD2 color raster');
f.Units = 'centimeters';
f.Position(3:4) = [9,8];

layout = tiledlayout(f, 2, 1, 'TileSpacing','tight','Padding','tight');

xlineColor = [0.0017	0.3805	0.0000];

% --- Top: Naive ---
axTop = nexttile(layout, 1);
if ~isempty(naiveCD2)
    imagesc(axTop, xsWin, 1:size(naiveCD2,1), naiveCD2);
    colormap(axTop, cmapGreen);
end
title(axTop, 'Naive');
axTop.XAxis.Visible = 'off';
xlim(axTop, [-1, 3]);
box(axTop,'off');
xline(axTop, 0,'--', 'Color', xlineColor);
xline(axTop, 1,'--', 'Color', xlineColor);

% --- Bottom: Continual ---
axBot = nexttile(layout, 2);
if ~isempty(contCD2)
    imagesc(axBot, xsWin, 1:size(contCD2,1), contCD2);
    colormap(axBot, cmapGreen);
end
title(axBot, 'Continual');
xlim(axBot, [-1, 3]);
box(axBot,'off');
xline(axBot, 0,'--', 'Color', xlineColor);
xline(axBot, 1,'--', 'Color', xlineColor);

xlabel(axBot, 'Time (s)');
ylabel(layout, 'Trial');
title(layout, '💡💧 first block');


% --- Colorbar ---
cb = colorbar(axBot);
cb.Layout.Tile = 'east';
cb.Label.String = 'Lick probability';

TransferLearning.Style.ApplyStandardFigureStyle(f, 2);
axBot.XTickLabels(ismember(axBot.XTick,[0,1])) = {'💡','💧'};
svgPath = TransferLearning.StandardFigureSvgPath('中文图32D_CD2ColorRaster.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ========== 子函数 ==========

function [cd2Matrix, mice] = iCollectTrialCD2Matrix(DSlist, phaseName, winMask)
% 收集 CD2 并按 TrialIndex 聚合（同一试次号跨鼠求均值）
cd2Matrix = [];
nTimeBins = sum(winMask);

% 第一遍：收集所有 (TrialIndex, CD2向量)
allTrialIdx = [];
allCD2Rows = {};

allMice = string.empty;
for d = 1:numel(DSlist)
    DS = DSlist{d};
    dt = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
    dt.DateTime = iNormDT(datetime(dt.DateTime));
    dt.Mouse = string(dt.Mouse);
    dt.Phase = string(dt.Phase);

    blk = DS.Blocks;
    blk.DateTime = iNormDT(datetime(blk.DateTime));
    blk2 = innerjoin(blk, dt, 'Keys','DateTime');

    phaseBlks = blk2(string(blk2.Phase) == string(phaseName), :);
    if isempty(phaseBlks), continue; end

    tr = DS.Trials;
    tr.BlockUID = uint64(tr.BlockUID);

    miceThisDS = unique(string(phaseBlks.Mouse), 'stable');
    for iM = 1:numel(miceThisDS)
        m = miceThisDS(iM);
        if ismember(m, allMice), continue; end
        allMice(end+1) = m; %#ok<AGROW>

        rows = phaseBlks(string(phaseBlks.Mouse) == m, :);
        rows = sortrows(rows, 'DateTime');

        for b = 1:height(rows)
            blkUID = rows.BlockUID(b);
            sessTr = tr(tr.BlockUID == blkUID & string(tr.Stimulus) == "LightWater", :);
            if isempty(sessTr), continue; end
            sessTr = sortrows(sessTr, 'TrialIndex');

            for tIdx = 1:height(sessTr)
                trialNum = double(sessTr.TrialRI(tIdx));
                rt = sessTr.ResampledTags{tIdx};
                if isempty(rt) || ~ismember('CD2', rt.Properties.VariableNames), continue; end
                cd2 = double(rt.CD2);
                if numel(cd2) < nTimeBins, continue; end
                cd2Win = cd2(winMask);
                allTrialIdx(end+1) = trialNum; %#ok<AGROW>
                allCD2Rows{end+1} = cd2Win(:)'; %#ok<AGROW>
            end
            break;
        end
    end
end
mice = allMice;

% 第二遍：按 TrialIndex 聚合（跨鼠均值）
if isempty(allTrialIdx), return; end
uniqueTrials = unique(allTrialIdx);
cd2Matrix = zeros(numel(uniqueTrials), nTimeBins);
for iT = 1:numel(uniqueTrials)
    mask = allTrialIdx == uniqueTrials(iT);
    rows = vertcat(allCD2Rows{mask});
    cd2Matrix(iT, :) = mean(rows, 1);
end
end

function dt = iNormDT(dt)
dt = datetime(dt);
try
    if ~isempty(dt.TimeZone), dt.TimeZone = '';
end
catch
end
end