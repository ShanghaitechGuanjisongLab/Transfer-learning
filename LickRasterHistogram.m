%[text] `舔水直方图：Naive/Learned Audiowater & Continual/Naive Lightwater 的
% 舔水栅格图与概率直方图。`
%
% 分组情况：
%   - Naive Audiowater: A2L_A.mat 每个小鼠第1次记录（声音→水）
%   - Learned Audiowater: A2L_A.mat 每个小鼠第5次记录（声音→水）
%   - Continual Lightwater: A2L_L.mat 第1次记录（光→水，从A2L连续训练）
%   - Naive Lightwater: L2A_L.mat 第1次记录（光→水）
%
% 每组输出两张图：
%   图1：栅格图。横轴时间[-3,10]秒（cue对齐），虚线标出给cue时刻。
%        纵轴为trials，每一行是一个trial，多只鼠的trial叠加。
%   图2：舔水概率直方图。横轴时间[-3,10]秒（cue对齐），
%        在cue时刻和cue+1.5s处标虚线。SVG格式。
%
% 执行方式：
%   - 本文件为脚本，直接在MATLAB Editor中Run/F5执行。


% --- 0) Ensure project loaded
if ~exist('UniExp.DataSet', 'class')
    thisFile = mfilename('fullpath');
    thisDir = fileparts(thisFile);
    prjFile = fullfile(thisDir, 'Transferlearning.prj');
    if exist(prjFile, 'file')
        matlab.project.loadProject(prjFile);
    end
end

% --- 0b) Parameters
TIME_WINDOW = [-3, 10];   % 秒，cue对齐
BIN_WIDTH   = 0.05;       % 直方图时间窗宽度（秒）

% 输出目录
outDirUNC = fullfile('\\Data-Server-2\个人数据\杨青宁', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
    mkdir(outDirUNC);
end

% 颜色（Nature-style 协调色系，避开黑/灰以免与坐标轴混同）
NAIVE_COLOR         = [0.000, 0.447, 0.741];  % Naive Audiowater — 蓝
LEARNED_COLOR       = [0.835, 0.369, 0.000];  % Learned Audiowater — 朱红
CONTINUAL_COLOR     = [0.000, 0.620, 0.451];  % Continual Lightwater — 绿
NAIVE_LIGHT_COLOR   = [0.494, 0.184, 0.556];  % Naive Lightwater — 紫

fprintf('输出目录: %s\n', outDirUNC);

%% ======================== 主流程 ========================

fprintf('=== 开始提取舔水数据 ===\n\n');

% --- 提取所有4组数据 ---
fprintf('提取数据...\n');
[dataNA, nNA] = iExtractGroupData(...
    '\\Data-Server-2\个人数据\杨青宁\202607\行为学\A2L_A.mat', ...
    'DataSetA', 1, '声音响', TIME_WINDOW);
[dataLA, nLA] = iExtractGroupData(...
    '\\Data-Server-2\个人数据\杨青宁\202607\行为学\A2L_A.mat', ...
    'DataSetA', 5, '声音响', TIME_WINDOW);
[dataCL, nCL] = iExtractGroupData(...
    '\\Data-Server-2\个人数据\杨青宁\202607\行为学\A2L_L.mat', ...
    'DataSetA2L', 1, '灯光亮', TIME_WINDOW);
[dataNL, nNL] = iExtractGroupData(...
    '\\Data-Server-2\个人数据\杨青宁\202607\行为学\L2A_L.mat', ...
    'DataSetL', 1, '灯光亮', TIME_WINDOW);

% --- 计算4组概率直方图的全局纵轴最大值，统一y轴 ---
allData = {dataNA, dataLA, dataCL, dataNL};
globalYMax = 0;
for di = 1:4
    m = iComputeMaxLickProb(allData{di}, TIME_WINDOW, BIN_WIDTH);
    globalYMax = max(globalYMax, m);
end
commonYMax = globalYMax * 1.15 + 0.02;
% 圆整到0.1的整倍数
commonYMax = ceil(commonYMax * 10) / 10;

fprintf('\n统一概率直方图纵轴上限: %.2f\n\n', commonYMax);

% --- 绘图 ---
fprintf('[1/4] Naive Audiowater\n');
rasterFileNA = fullfile(outDirUNC, 'Fig1A_NaiveAudiowater_Raster.svg');
probFileNA   = fullfile(outDirUNC, 'Fig2A_NaiveAudiowater_LickProb.svg');
iPlotRaster(dataNA, NAIVE_COLOR, 'Naive Audiowater', rasterFileNA, TIME_WINDOW, nNA);
iPlotLickProb(dataNA, NAIVE_COLOR, 'Naive Audiowater', probFileNA, TIME_WINDOW, BIN_WIDTH, nNA, commonYMax);

fprintf('\n[2/4] Learned Audiowater\n');
rasterFileLA = fullfile(outDirUNC, 'Fig1B_LearnedAudiowater_Raster.svg');
probFileLA   = fullfile(outDirUNC, 'Fig2B_LearnedAudiowater_LickProb.svg');
iPlotRaster(dataLA, LEARNED_COLOR, 'Learned Audiowater', rasterFileLA, TIME_WINDOW, nLA);
iPlotLickProb(dataLA, LEARNED_COLOR, 'Learned Audiowater', probFileLA, TIME_WINDOW, BIN_WIDTH, nLA, commonYMax);

fprintf('\n[3/4] Continual Lightwater\n');
rasterFileCL = fullfile(outDirUNC, 'Fig1C_ContinualLightwater_Raster.svg');
probFileCL   = fullfile(outDirUNC, 'Fig2C_ContinualLightwater_LickProb.svg');
iPlotRaster(dataCL, CONTINUAL_COLOR, 'Continual Lightwater', rasterFileCL, TIME_WINDOW, nCL);
iPlotLickProb(dataCL, CONTINUAL_COLOR, 'Continual Lightwater', probFileCL, TIME_WINDOW, BIN_WIDTH, nCL, commonYMax);

fprintf('\n[4/4] Naive Lightwater\n');
rasterFileNL = fullfile(outDirUNC, 'Fig1D_NaiveLightwater_Raster.svg');
probFileNL   = fullfile(outDirUNC, 'Fig2D_NaiveLightwater_LickProb.svg');
iPlotRaster(dataNL, NAIVE_LIGHT_COLOR, 'Naive Lightwater', rasterFileNL, TIME_WINDOW, nNL);
iPlotLickProb(dataNL, NAIVE_LIGHT_COLOR, 'Naive Lightwater', probFileNL, TIME_WINDOW, BIN_WIDTH, nNL, commonYMax);

fprintf('\n=== 完成！所有SVG已保存至: %s ===\n', outDirUNC);


%% ======================== 本地函数 ========================

function [groupData, nMice] = iExtractGroupData(matPath, varName, sessionN, cueEventName, timeWindow)
    % iExtractGroupData 从mat文件中提取某组数据
    %   matPath: .mat文件路径
    %   varName: 文件中DataSet变量名
    %   sessionN: 取第N次记录（每鼠按DateTime排序后的第N个会话）
    %   cueEventName: '声音响' 或 '灯光亮'
    %   timeWindow: [pre, post] 秒
    %
    % 返回:
    %   groupData: 结构体数组，每个元素包含一个trial的:
    %       .lickTimes: 相对cue的舔舐时间向量
    %       .mouseID:  小鼠标识
    %   nMice: 该组的小鼠数量

    s = load(matPath);
    ds = s.(varName);

    % 按小鼠分组并确定每个小鼠的第N个会话
    dt = ds.DateTimes;
    mice = unique(dt.Mouse);

    % 预分配：先收集到cell数组再转换
    lickCell = {};
    mouseCell = {};
    trialIdxCell = {};

    nMiceWithEnough = 0;

    for mi = 1:length(mice)
        m = mice(mi);
        idx = find(dt.Mouse == m);
        [~, sortIdx] = sort(dt.DateTime(idx));
        sortedDT = dt.DateTime(idx(sortIdx));

        if length(sortedDT) < sessionN
            continue;
        end
        nMiceWithEnough = nMiceWithEnough + 1;

        targetDT = sortedDT(sessionN);

        % 找到该DateTime对应的所有blocks
        blockMask = ds.Blocks.DateTime == targetDT;
        blockUIDs = ds.Blocks.BlockUID(blockMask);

        for bi = 1:length(blockUIDs)
            blkUID = blockUIDs(bi);
            blkRow = find(ds.Blocks.BlockUID == blkUID, 1);

            el = ds.Blocks.EventLog{blkRow};
            elTimes = seconds(el.Time);
            elEvents = el.Event;

            trials = ds.Trials(ds.Trials.BlockUID == blkUID, :);

            for ti = 1:height(trials)
                ts = seconds(trials.Time(ti));

                if ti < height(trials)
                    te = seconds(trials.Time(ti + 1));
                else
                    te = ts + 60;
                end

                mask = elTimes >= ts & elTimes < te;
                trialEvents = elEvents(mask);
                trialTimes  = elTimes(mask);

                cueIdx = find(trialEvents == cueEventName, 1);
                if isempty(cueIdx)
                    continue;
                end
                cueTime = trialTimes(cueIdx);

                % 排除cue与trial开始间距<0.5s的异常trial（硬件触发异常）
                if cueTime - ts < 0.5
                    continue;
                end

                lickMask = trialEvents == '舔';
                lickTimes = trialTimes(lickMask) - cueTime;

                lickTimes = lickTimes(lickTimes >= timeWindow(1) & lickTimes <= timeWindow(2));

                lickCell{end+1, 1} = lickTimes;   %#ok<AGROW>
                mouseCell{end+1, 1} = char(m);    %#ok<AGROW>
                trialIdxCell{end+1, 1} = trials.TrialIndex(ti); %#ok<AGROW>
            end
        end
    end

    % 转换为结构体
    nTotal = length(lickCell);
    groupData = struct('lickTimes', lickCell, 'mouseID', mouseCell, 'trialIndex', trialIdxCell);
    nMice = nMiceWithEnough;

    fprintf('  Extracted %d trials (%d mice with >=%d sessions)\n', ...
        nTotal, nMice, sessionN);
end


function iPlotRaster(groupData, color, groupName, svgFilename, timeWindow, nMice)
    % 图1：栅格图 —— 多鼠同trial index叠加在同一行，≤100行，带透明度
    f = figure('Color', 'w', 'Name', ['Raster - ' groupName], 'Visible', 'off');
    f.Units = 'centimeters';
    f.Position(3:4) = [12, 8];
    ax = axes(f);
    hold(ax, 'on');

    if isempty(groupData)
        text(ax, 0.5, 0.5, 'No data', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        xlabel(ax, 'Time from cue (s)');
        ylabel(ax, 'Trial');
        box(ax, 'off');
        print(f, svgFilename, '-dsvg', '-vector');
        close(f);
        return;
    end

    % 按 trialIndex 分组：同一trial index的所有鼠标lick合并到同一行
    allTrialIdx = [groupData.trialIndex];
    uniqueIdx = unique(allTrialIdx);
    if length(uniqueIdx) > 100
        uniqueIdx = uniqueIdx(1:100);
    end
    nRows = length(uniqueIdx);

    % 给水时段阴影（1.5-2.5s）
    yLimits = [0.5, nRows + 0.5];
    fill(ax, [1.5, 2.5, 2.5, 1.5], yLimits([1 1 2 2]), [0.75 0.75 0.75], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5, 'HandleVisibility', 'off');

    % 透明度alpha值（每个lick标记的透明度）
    lickAlpha = 0.25;

    for ri = 1:nRows
        tidx = uniqueIdx(ri);
        % 找出该trialIndex对应的所有条目（多只鼠）
        mask = [groupData.trialIndex] == tidx;
        % 合并所有lick时间
        allLicks = [];
        for mi = find(mask)
            allLicks = [allLicks; groupData(mi).lickTimes(:)]; %#ok<AGROW>
        end
        if isempty(allLicks)
            continue;
        end
        % 用plot画lick标记，使用RGBA颜色实现透明度
        plot(ax, allLicks, repmat(ri, size(allLicks)), '|', ...
            'Color', [color, lickAlpha], 'MarkerSize', 3, 'LineWidth', 0.3);
    end

    % Cue虚线
    xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);

    xlabel(ax, 'Time from cue (s)');
    ylabel(ax, 'Trial');
    xlim(ax, timeWindow);
    ylim(ax, [0.5, nRows + 0.5]);
    ax.YTick = 20:20:nRows;
    box(ax, 'off');
    ax.FontSize = 10;
    ax.TickDir = 'out';
    ax.LineWidth = 0.8;

    % 标注小鼠数量
    text(ax, 0.02, 0.98, sprintf('n = %d mice', nMice), ...
        'Units', 'normalized', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);

    % 去除工具栏
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end

    print(f, svgFilename, '-dsvg', '-vector');
    fprintf('  Wrote: %s\n', svgFilename);
    close(f);
end


function maxProb = iComputeMaxLickProb(groupData, timeWindow, binWidth)
    % 计算一组数据的最大lick概率值（用于统一y轴）
    nTrials = length(groupData);
    if nTrials == 0
        maxProb = 0;
        return;
    end
    binEdges = timeWindow(1):binWidth:timeWindow(2);
    nBins = length(binEdges) - 1;
    lickCounts = zeros(1, nBins);
    for ti = 1:nTrials
        lt = groupData(ti).lickTimes;
        if isempty(lt), continue; end
        for li = 1:length(lt)
            binIdx = find(lt(li) >= binEdges(1:end-1) & lt(li) < binEdges(2:end), 1);
            if ~isempty(binIdx)
                lickCounts(binIdx) = lickCounts(binIdx) + 1;
            end
        end
    end
    maxProb = max(lickCounts / nTrials);
end


function iPlotLickProb(groupData, color, groupName, svgFilename, timeWindow, binWidth, nMice, commonYMax)
    % 图2：舔水概率直方图
    f = figure('Color', 'w', 'Name', ['LickProb - ' groupName], 'Visible', 'off');
    f.Units = 'centimeters';
    f.Position(3:4) = [12, 6];
    ax = axes(f);
    hold(ax, 'on');

    nTrials = length(groupData);
    if nTrials == 0
        text(ax, 0.5, 0.5, 'No data', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        xlabel(ax, 'Time from cue (s)');
        ylabel(ax, 'Lick probability');
        box(ax, 'off');
        print(f, svgFilename, '-dsvg', '-vector');
        close(f);
        return;
    end

    % 时间bin
    binEdges = timeWindow(1):binWidth:timeWindow(2);
    nBins = length(binEdges) - 1;
    binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
    lickCounts = zeros(1, nBins);

    for ti = 1:nTrials
        lt = groupData(ti).lickTimes;
        if isempty(lt)
            continue;
        end
        for li = 1:length(lt)
            binIdx = find(lt(li) >= binEdges(1:end-1) & lt(li) < binEdges(2:end), 1);
            if ~isempty(binIdx)
                lickCounts(binIdx) = lickCounts(binIdx) + 1;
            end
        end
    end

    lickProb = lickCounts / nTrials;

    % 给水时段阴影（1.5-2.5s，使用统一yMax）
    yMax = commonYMax;
    fill(ax, [1.5, 2.5, 2.5, 1.5], [0 0 yMax yMax], [0.75 0.75 0.75], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5, 'HandleVisibility', 'off');

    % 柱状图
    bar(ax, binCenters, lickProb, 1, 'FaceColor', color, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.8);

    % 虚线：cue时刻
    xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);

    xlabel(ax, 'Time from cue (s)');
    ylabel(ax, 'Lick probability');
    xlim(ax, timeWindow);
    ylim(ax, [0, yMax]);
    box(ax, 'off');
    ax.FontSize = 10;
    ax.TickDir = 'out';
    ax.LineWidth = 0.8;

    % n标注（只显示小鼠数量）
    text(ax, 0.02, 0.98, sprintf('n = %d mice', nMice), ...
        'Units', 'normalized', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);

    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end

    print(f, svgFilename, '-dsvg', '-vector');
    fprintf('  Wrote: %s\n', svgFilename);
    close(f);
end
