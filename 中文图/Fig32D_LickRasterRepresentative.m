% 中文图32D：光水首个训练单元舔水栅格（上下双tile，所有鼠叠加）
%
% Top:     Naive —— LightAudioBaseline 每鼠首个光水训练单元
% Bottom:  Continual —— AudioLightBaseline 每鼠首个光水训练单元
%
% Y轴为试次序号1-30，每个舔水时刻用 '|' 标记，所有鼠叠加在同一行。
% CD2二值化：基线均值(每试次[-3,0]s) + 1.0 * 全Block CD2标准差 为阈值。

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
winMask = xsSec >= -1 & xsSec <= 2;
xsWin = xsSec(winMask);
blMask = xsSec >= -3 & xsSec < 0;

%% --- 收集每鼠首个 LightWater block 的 binarized CD2 ---
[naiveAllX, naiveAllY, naiveMice] = iCollectGroupCD2(TransferLearning.LightAudioBaseline(), "Naive", winMask, blMask);
[contAllX,  contAllY,  contMice ] = iCollectGroupCD2(TransferLearning.AudioLightBaseline(), "Transfer", winMask, blMask);

fprintf('Naive: %d mice\n', numel(naiveMice));
fprintf('Continual: %d mice\n', numel(contMice));

%% --- 绘图 ---
f = figure('Color','w', 'Name','中文图32D LightWater first-block lick raster');
f.Units = 'centimeters';
f.Position(3:4) = [14, 12];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'auto';

layout = tiledlayout(f, 2, 1, 'TileSpacing','compact','Padding','tight');
lickColor = TransferLearning.ColorB;

% --- Top: Naive ---
axTop = nexttile(layout, 1);
if ~isempty(naiveAllX)
    scatter(axTop, naiveAllX, naiveAllY, 4, lickColor, '|');
end
title(axTop, sprintf('Naive (n=%d mice)', numel(naiveMice)), 'FontSize', 8, 'FontWeight','normal');
axTop.YDir = 'reverse';
axTop.YTick = [1, 10, 20, 30];
axTop.FontSize = 8;
axTop.XAxis.Visible = 'off';
box(axTop,'off');

% --- Bottom: Continual ---
axBot = nexttile(layout, 2);
if ~isempty(contAllX)
    scatter(axBot, contAllX, contAllY, 4, lickColor, '|');
end
title(axBot, sprintf('Continual (n=%d mice)', numel(contMice)), 'FontSize', 8, 'FontWeight','normal');
axBot.YDir = 'reverse';
axBot.YTick = [1, 10, 20, 30];
axBot.FontSize = 8;
box(axBot,'off');

xlabel(axBot, 'Time (s)', 'FontSize', 8);
ylabel(layout, 'Trial', 'FontSize', 8);

%% --- 导出 ---
TransferLearning.Style.ApplyStandardFigureStyle(f, 2);
svgPath = TransferLearning.StandardFigureSvgPath('中文图Fig32D_LickRasterAllMice.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ========== 子函数 ==========

function [allX, allY, mice] = iCollectGroupCD2(DS, phaseName, winMask, blMask)
allX = [];
allY = [];

% 匹配 Phase
dt = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
dt.DateTime = iNormDT(datetime(dt.DateTime));
dt.Mouse = string(dt.Mouse);
dt.Phase = string(dt.Phase);

lw = DS.Blocks(string(DS.Blocks.Design) == "LightWater", :);
lw.DateTime = iNormDT(datetime(lw.DateTime));
lw = innerjoin(lw, dt, 'Keys','DateTime');
phaseRows = lw(string(lw.Phase) == string(phaseName), :);
if isempty(phaseRows), mice = {}; return; end

mice = unique(string(phaseRows.Mouse), 'stable');

% 预先计算全数据集的 CD2 标准差（作为各鼠阈值参考）
CD2sAll = [];
blkUIDs = uint64(DS.Blocks.BlockUID);
for b = 1:min(numel(blkUIDs), 50)  % 采样前50个block估算
    bt = DS.Blocks.BlockTags{b};
    if ~isempty(bt) && isfield(bt, 'CD2')
        CD2sAll = [CD2sAll; double(bt.CD2(:))]; %#ok<AGROW>
    end
end
globalSD = std(CD2sAll);

xsWin = TransferLearning.Xs;
xsSecWin = double(seconds(xsWin));
winVals = xsSecWin(winMask);

tr = DS.Trials;
tr.BlockUID = uint64(tr.BlockUID);

for iM = 1:numel(mice)
    m = mice(iM);
    rows = phaseRows(string(phaseRows.Mouse) == m, :);
    rows = sortrows(rows, 'DateTime');
    blkUID = rows.BlockUID(1);

    % 获取该block的CD2总体标准差
    blockSD = globalSD;
    bt = DS.Blocks.BlockTags(DS.Blocks.BlockUID == blkUID);
    if ~isempty(bt) && isfield(bt{1}, 'CD2')
        blockSD = double(std(bt{1}.CD2));
    end

    % LightWater 试次
    sessTr = tr(tr.BlockUID == blkUID & string(tr.Stimulus) == "LightWater", :);
    sessTr = sortrows(sessTr, 'TrialIndex');

    for tIdx = 1:height(sessTr)
        trialNum = double(sessTr.TrialIndex(tIdx));
        rt = sessTr.ResampledTags{tIdx};
        if isempty(rt) || ~isfield(rt, 'CD2'), continue; end
        cd2 = double(rt.CD2);
        bl = cd2(blMask);
        thresh = mean(bl) + 1.0 * blockSD;
        bin = cd2 > thresh;
        lickTimes = winVals(bin(winMask));
        if isempty(lickTimes), continue; end
        allX = [allX; lickTimes(:)]; %#ok<AGROW>
        allY = [allY; repmat(trialNum, numel(lickTimes), 1)]; %#ok<AGROW>
    end
end
end

function dt = iNormDT(dt)
dt = datetime(dt);
try
    if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end
