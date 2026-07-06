% 中文图32D：光水首个训练单元舔水栅格（上下双tile，所有鼠叠加至同一试次行）
%
% Top:     Naive —— LightAudioBaseline + LAInterspersed，Naive phase trial
% Bottom:  Continual —— AudioLightBaseline，Transfer phase trial
%
% 不限制 Block.Design，只要 Trial.Stimulus=="LightWater" 即可。
% 每鼠取首个含 LightWater trial 的 Naive/Transfer block；
% 以 TrialIndex 为 Y 轴行号，所有鼠叠加在同一行，用 scatter '|' 标记舔水。

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

%% --- 提取每鼠首个 Naive/Transfer phase 的 LightWater trial CD2 ---
[naiveAllX, naiveAllY, naiveMice] = iCollectTrialCD2( ...
    {TransferLearning.LightAudioBaseline(), TransferLearning.LAInterspersed()}, "Naive", winMask, blMask);
[contAllX,  contAllY,  contMice ] = iCollectTrialCD2( ...
    {TransferLearning.AudioLightBaseline()}, "Transfer", winMask, blMask);

fprintf('Naive: %d mice\n', numel(naiveMice));
fprintf('Continual: %d mice\n', numel(contMice));

%% --- 绘图 ---
f = figure('Color','w', 'Name','中文图32D LightWater first-block lick raster');
f.Units = 'centimeters';
f.Position(3:4) = [4, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'auto';

layout = tiledlayout(f, 2, 1, 'TileSpacing','tight','Padding','tight');

% --- Top: Naive ---
axTop = nexttile(layout, 1);
if ~isempty(naiveAllX)
    scatter(axTop, naiveAllX, naiveAllY, 4, TransferLearning.NaiveColor, '|');
end
title(axTop, sprintf('Naive (n=%d mice)', numel(naiveMice)), 'FontSize', 8, 'FontWeight','normal');
axTop.FontSize = 8;
axTop.XAxis.Visible = 'off';
xlim(axTop, [-1, 3]);
box(axTop,'off');
xline(0,':');
xline(1,':');

% --- Bottom: Continual ---
axBot = nexttile(layout, 2);
if ~isempty(contAllX)
    scatter(axBot, contAllX, contAllY, 4, TransferLearning.ContinualColor, '|');
end
title(axBot, sprintf('Continual (n=%d mice)', numel(contMice)), 'FontSize', 8, 'FontWeight','normal');
axBot.FontSize = 8;
xlim(axBot, [-1, 3]);
box(axBot,'off');

xlabel(axBot, 'Time (s)', 'FontSize', 8);
ylabel(layout, 'Trial', 'FontSize', 8);
title(layout,'Lick events of 💡💧 first block');
xline(0,':');
xline(1,':');
axBot.XTickLabels(ismember(axBot.XTick,[0,1]))={'💡','💧'};

TransferLearning.Style.ApplyStandardFigureStyle(f, 1);
svgPath = TransferLearning.StandardFigureSvgPath('中文图Fig32D_LickRasterAllMice.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ========== 子函数 ==========

function [allX, allY, mice] = iCollectTrialCD2(DSlist, phaseName, winMask, blMask)
allX = [];
allY = [];

xsWin = TransferLearning.Xs;
xsSecWin = double(seconds(xsWin));
winVals = xsSecWin(winMask);

% 跨数据集累计鼠名，去重
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

    % 跨 block 采样 CD2 标准差（中位数，抗离群）作为阈值参考
    sdSamples = nan(min(height(blk), 50), 1);
    for b = 1:numel(sdSamples)
        bt = DS.Blocks.BlockTags{b};
        if ~isempty(bt) && ismember('CD2', bt.Properties.VariableNames)
            v = double(bt.CD2);
            if ~isempty(v), sdSamples(b) = std(v); end
        end
    end
    sdSamples = sdSamples(isfinite(sdSamples) & sdSamples > 0);
    if isempty(sdSamples), blockSD = NaN; else, blockSD = median(sdSamples); end

    miceThisDS = unique(string(phaseBlks.Mouse), 'stable');
    for iM = 1:numel(miceThisDS)
        m = miceThisDS(iM);
        % 跳过已在别的数据集中出现过的鼠
        if ismember(m, allMice), continue; end
        allMice(end+1) = m; %#ok<AGROW>

        rows = phaseBlks(string(phaseBlks.Mouse) == m, :);
        rows = sortrows(rows, 'DateTime');

        % 找首个含 LightWater trial 的 block
        found = false;
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
                bl = cd2(blMask);
                % 用采样 block 的 CD2 std 中位数；若无则用试次基线标准差
                sd = blockSD;
                if ~isfinite(sd), sd = std(bl); end
                if ~isfinite(sd) || sd == 0, continue; end
                thresh = mean(bl) + 2 * sd;
                bin = cd2 > thresh;
                lickTimes = winVals(bin(winMask));
                if isempty(lickTimes), continue; end
                allX = [allX; lickTimes(:)]; %#ok<AGROW>
                allY = [allY; repmat(trialNum, numel(lickTimes), 1)]; %#ok<AGROW>
            end
            found = true;
            break;  % 只取该鼠的第一个有效 block
        end
        if ~found
            % 删掉没贡献的鼠
            allMice(end) = [];
        end
    end
end
mice = allMice;
end

function dt = iNormDT(dt)
dt = datetime(dt);
try
    if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end
