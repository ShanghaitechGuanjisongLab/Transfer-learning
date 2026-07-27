%% EncodingDecoding_Fig2_Style.m
% 仿 Runyan et al. 2017 Fig.2 编码-解码框架
% 
% 思路:
%   Encoding: 用 trial 标签（hit=1, miss=0）作为特征，拟合每个神经元的
%             线性编码模型（简单 GLM），得到"编码权重"的时间过程
%   Decoding: 在每个时间点训练 LASSO 逻辑回归（与 Runyan 一致），
%             从群体活动解码 trial 类型（hit vs miss）
%             评估指标：准确率 + 互信息（bits）
%
% 数据:
%   训练集 = Naive + Learned 阶段（AudioWater — 听觉训练阶段）
%   验证集 = Transfer 阶段（LightWater — 迁移到光水）
%
% 每只鼠独立建模，输出图类似于 Fig 2 的 time-resolved decoding 面板

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end

rng(42);

%% 1. Load dataset and time axis
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);

%% 2. List mice
TQ = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialUID"]);
TQ.Mouse = string(TQ.Mouse);
TQ.Phase = string(TQ.Phase);
TQ = sortrows(TQ, ["Mouse","DateTime"]);

mice = unique(TQ.Mouse);
fprintf('=== Encoding-Decoding (Fig2-style) ===\n');
fprintf('Total mice: %d\n\n', numel(mice));

%% 2b. Define 0-1s post-stimulus window for analysis
tMask = (xs >= 0) & (xs <= 1);
tIdx = find(tMask);
nTimeWin = numel(tIdx);
fprintf('Time window: %.2f-%.2f s (%d time points / %d total)\n', ...
    xs(tIdx(1)), xs(tIdx(end)), nTimeWin, numel(xs));

%% 3. Per-mouse analysis
nMice = numel(mice);
encResults = cell(nMice, 1);  % encoding weights
decResults = cell(nMice, 1);  % decoding accuracy time course

for iM = 1:nMice
    m = mice(iM);
    fprintf('========== Mouse %s (%d/%d) ==========\n', m, iM, nMice);

    % ---- 3a. Query neural data ----
    % Training: Naive + Learned AudioWater（听觉阶段）
    % 注：Naive/Learned 阶段只有 AudioWater，没有 LightWater
    trainRaw = table();
    for phaseName = ["Naive", "Learned"]
        qp = struct('Mouse', m, 'Phase', phaseName, 'Stimulus', "AudioWater");
        try
            resp = DS.QueryNTS(qp, UniExp.Flags.ZScore, 1:nTime, ...
                'ExtraColumns', ["Behavior","DateTime"]);
            if ~isempty(resp) && ~isempty(resp{1})
                tbl = resp{1};
                tbl.Phase = repmat(phaseName, height(tbl), 1);
                trainRaw = [trainRaw; tbl];
            end
        catch
        end
    end

    % Validation: Transfer LightWater
    valRaw = table();
    qVal = struct('Mouse', m, 'Phase', "Transfer", 'Stimulus', "LightWater");
    try
        resp = DS.QueryNTS(qVal, UniExp.Flags.ZScore, 1:nTime, ...
            'ExtraColumns', ["Behavior","DateTime"]);
        if ~isempty(resp) && ~isempty(resp{1})
            valRaw = resp{1};
            valRaw.Phase = repmat("Transfer", height(valRaw), 1);
        end
    catch, end

    if isempty(trainRaw) || isempty(valRaw)
        fprintf('  SKIP: no data (train=%d, val=%d)\n', ...
            height(trainRaw), height(valRaw));
        continue;
    end
    if ~ismember('TrialSignal', string(trainRaw.Properties.VariableNames))
        fprintf('  SKIP: no TrialSignal\n'); continue;
    end

    % ---- 3b. Build trial-level matrices ----
    allCellUIDs = [trainRaw.CellUID; valRaw.CellUID];
    cellUIDs = uint64(unique(allCellUIDs));
    nCell = numel(cellUIDs);
    if nCell < 5; fprintf('  SKIP: %d cells\n', nCell); continue; end

    [XTrain, yTrain] = iBuildTrialMatrix(trainRaw, cellUIDs);
    [XVal, yVal] = iBuildTrialMatrix(valRaw, cellUIDs);

    % Subset to 0-1s post-stimulus window
    XTrain = XTrain(:, :, tIdx);
    XVal   = XVal(:, :, tIdx);

    if isempty(XTrain) || isempty(XVal)
        fprintf('  SKIP: empty feature matrix\n'); continue;
    end
    if sum(yTrain==1) < 2 || sum(yTrain==0) < 2 || ...
       sum(yVal==1) < 2 || sum(yVal==0) < 2
        fprintf('  SKIP: class imbalance (train: H%d/M%d, val: H%d/M%d)\n', ...
            sum(yTrain==1), sum(yTrain==0), sum(yVal==1), sum(yVal==0));
        continue;
    end

    nTr = size(XTrain, 1);
    nVl = size(XVal, 1);
    nT = size(XTrain, 3);
    fprintf('  Cells=%d  Train=%d(H%d/M%d)  Val=%d(H%d/M%d)  TimePts=%d [%.2f-%.2fs]\n', ...
        nCell, nTr, sum(yTrain==1), sum(yTrain==0), ...
        nVl, sum(yVal==1), sum(yVal==0), nT, xs(tIdx(1)), xs(tIdx(end)));

    % ---- 3c. Encoding: GLM per cell per time point ----
    % Simple encoding model: neural_activity ~ beta * behavioral_label
    % at each time point independently.
    % weight > 0 表示该神经元在该时间点对 hit 响应更强
    encBeta = nan(nCell, nT);
    encPVal = nan(nCell, nT);
    for iC = 1:nCell
        for iT = 1:nT
            act = squeeze(XTrain(:, iC, iT));
            if all(isnan(act)) || range(act) == 0
                continue;
            end
            % Simple linear regression: act ~ b0 + b1*y
            [b, dev, stats] = glmfit(yTrain, act, 'normal');
            encBeta(iC, iT) = b(2);  % coefficient for y
            encPVal(iC, iT) = stats.p(2);
        end
    end

    % ---- 3d. Decoding: per-time-point LASSO logistic regression ----
    % 与 Runyan 一致：使用 L1 正则化逻辑回归
    % 使用固定 lambda（经测试在 60 trial 下折中过拟合与欠拟合）
    decAccTr  = nan(nT, 1);
    decAccVl  = nan(nT, 1);
    decMiTr   = nan(nT, 1);
    decMiVl   = nan(nT, 1);
    decPVal   = nan(nT, 1);
    decShufMn = nan(nT, 1);
    decShufSd = nan(nT, 1);

    lambdaFix = 1 / sqrt(nTr) * 0.02;  % 约 0.0026，平衡强度
    nShuffle = 100;

    for iT = 1:nT
        xTr = squeeze(XTrain(:, :, iT));
        xVl = squeeze(XVal(:, :, iT));

        % 标准化
        muTr = mean(xTr, 1, 'omitnan');
        sdTr = std(xTr, 0, 1, 'omitnan');
        sdTr(sdTr == 0) = 1;
        xTrS = (xTr - muTr) ./ sdTr;
        xVlS = (xVl - muTr) ./ sdTr;
        xTrS(isnan(xTrS)) = 0;
        xVlS(isnan(xVlS)) = 0;

        if all(xTrS(:) == 0), continue; end

        % 训练 LASSO 逻辑回归
        try
            lrMdl = fitclinear(xTrS, yTrain, ...
                'Learner', 'logistic', ...
                'Regularization', 'lasso', ...
                'Lambda', lambdaFix, ...
                'Solver', 'sparsa');
        catch
            try
                lrMdl = fitclinear(xTrS, yTrain, ...
                    'Learner', 'logistic', ...
                    'Regularization', 'lasso', ...
                    'Lambda', lambdaFix);
            catch
                continue;
            end
        end

        % 预测
        predTr = predict(lrMdl, xTrS);
        predVl = predict(lrMdl, xVlS);

        decAccTr(iT) = mean(predTr == yTrain);
        decAccVl(iT) = mean(predVl == yVal);
        decMiTr(iT)  = iMutualInfo(yTrain, predTr, 2);
        decMiVl(iT)  = iMutualInfo(yVal, predVl, 2);

        % 置换检验
        nShuf = min(nShuffle, nTr);
        sa = zeros(nShuf, 1);
        for iS = 1:nShuf
            sy = yTrain(randperm(nTr));
            try
                smdl = fitclinear(xTrS, sy, ...
                    'Learner', 'logistic', ...
                    'Regularization', 'lasso', ...
                    'Lambda', lambdaFix);
                sp = predict(smdl, xVlS);
                sa(iS) = mean(sp == yVal);
            catch
                sa(iS) = 0.5;
            end
        end
        decShufMn(iT) = mean(sa, 'omitnan');
        decShufSd(iT) = std(sa, 'omitnan');
        decPVal(iT) = (sum(sa >= decAccVl(iT), 'omitnan') + 1) / (nShuf + 1);
    end

    % ---- Store results ----
    encRes = struct();
    encRes.Mouse = m;
    encRes.CellUIDs = cellUIDs;
    encRes.NCells = nCell;
    encRes.Beta = encBeta;
    encRes.PVal = encPVal;
    encRes.NTrain = nTr;
    encResults{iM} = encRes;

    decRes = struct();
    decRes.Mouse = m;
    decRes.CellUIDs = cellUIDs;
    decRes.NCells = nCell;
    decRes.DecAccTrain = decAccTr;
    decRes.DecAccVal   = decAccVl;
    decRes.PVal        = decPVal;
    decRes.ShufMean    = decShufMn;
    decRes.ShufStd     = decShufSd;
    decRes.MiTrain     = decMiTr;
    decRes.MiVal       = decMiVl;
    decRes.NTrain = nTr;
    decRes.NVal   = nVl;
    decRes.NHitVal = sum(yVal==1);
    decRes.NMissVal = sum(yVal==0);
    decRes.HiddenSize = [];
    decResults{iM} = decRes;

    % Print summary for this mouse
    bestT = find(decAccVl == max(decAccVl, [], 'omitnan'), 1);
    if ~isempty(bestT)
        fprintf('  Peak @t=%.2fs: Acc=%.1f%% MI=%.3fbits (train Acc=%.1f%%)\n', ...
            xs(tIdx(bestT)), decAccVl(bestT)*100, decMiVl(bestT), decAccTr(bestT)*100);
    end
end

%% 4. Summary
validIdx = find(~cellfun(@isempty, decResults));
nValid = numel(validIdx);
fprintf('\n========== SUMMARY ==========\n');
fprintf('Valid mice: %d/%d\n', nValid, nMice);

peakValAcc = nan(nValid, 1);
peakValMi  = nan(nValid, 1);
meanValAcc = nan(nValid, 1);
mouseNames = cell(nValid, 1);
for i = 1:nValid
    r = decResults{validIdx(i)};
    peakValAcc(i) = max(r.DecAccVal, [], 'omitnan');
    peakValMi(i)  = max(r.MiVal, [], 'omitnan');
    meanValAcc(i) = mean(r.DecAccVal, 'omitnan');
    mouseNames{i} = r.Mouse;
    bestT = find(r.DecAccVal == peakValAcc(i), 1);
    sigStr = '';
    if max(r.PVal, [], 'omitnan') < 0.05; sigStr = ' *'; end
    fprintf('  %s: cells=%d peakAcc=%.1f%% peakMI=%.3fbits meanAcc=%.1f%% (H%d/M%d)%s\n', ...
        r.Mouse, r.NCells, peakValAcc(i)*100, peakValMi(i), meanValAcc(i)*100, ...
        r.NHitVal, r.NMissVal, sigStr);
end

%% 5. Figures (only if valid mice exist)
if nValid == 0
    fprintf('\nNo valid mice to plot.\n');
    return;
end

% ---- 5a. Per-mouse time-resolved decoding (like Fig2 d-g) ----
nCols = min(4, nValid);
nRows = ceil(nValid / nCols);
fDec = figure('Name','Fig2-style Time-resolved decoding','Color','w', ...
    'Position', [50 50 nCols*300 nRows*240]);
tiledlayout(fDec, nRows, nCols, 'TileSpacing','compact','Padding','compact');

for i = 1:nValid
    r = decResults{validIdx(i)};
    ax = nexttile;
    hold(ax, 'on');

    % Validation accuracy
    validT = ~isnan(r.DecAccVal);
    hl = plot(ax, xs(tIdx(validT)), r.DecAccVal(validT)*100, '-', ...
        'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
    % Training accuracy
    plot(ax, xs(tIdx(validT)), r.DecAccTrain(validT)*100, '-', ...
        'Color', [0 0.4470 0.7410], 'LineWidth', 0.8);
    % Shuffle baseline
    if any(~isnan(r.ShufMean))
        plot(ax, xs(tIdx(validT)), r.ShufMean(validT)*100, '--', ...
            'Color', [0.5 0.5 0.5], 'LineWidth', 0.6);
        % Shade shuffle ±1 std
        xVec = xs(tIdx(validT));
        yLo = (r.ShufMean(validT) - r.ShufStd(validT)) * 100;
        yHi = (r.ShufMean(validT) + r.ShufStd(validT)) * 100;
        fill(ax, [xVec; flipud(xVec)], [yLo; flipud(yHi)], ...
            [0.5 0.5 0.5], 'EdgeColor', 'none', 'FaceAlpha', 0.15);
    end
    % Chance level
    yline(ax, 50, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.5);

    % Highlight significant time points
    sigT = validT & r.PVal < 0.05;
    if any(sigT)
        scatter(ax, xs(tIdx(sigT)), r.DecAccVal(sigT)*100, 6, ...
            [0.8500 0.3250 0.0980], 'filled', 'MarkerEdgeColor', 'none');
    end

    hold(ax, 'off');
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Decoding (%)');
    title(ax, sprintf('%s (cells=%d)', r.Mouse, r.NCells), ...
        'FontSize', 8, 'FontWeight', 'normal');
    xlim(ax, [xs(tIdx(1)), xs(tIdx(end))]);
    ylim(ax, [30 100]);
    ax.FontSize = 7;
    box(ax, 'off');
    if i == 1
        legend(ax, {'Validation','Training','Shuffle'}, ...
            'Location', 'southeast', 'Box', 'off', 'FontSize', 5);
    end
end
for i = nValid+1 : nRows*nCols
    nexttile; axis off;
end
sgtitle(fDec, 'Time-resolved decoding of hit vs miss (AudioWater train \rightarrow LightWater test)', ...
    'FontSize', 9);

% ---- 5b. Average decoding curve across mice ----
fAvg = figure('Name','Average decoding','Color','w', ...
    'Position', [100 100 360 280]);
axAvg = axes(fAvg);
hold(axAvg, 'on');

% Collect all decoding curves (0-1s window)
nTwin = numel(tIdx);
allDec = nan(nValid, nTwin);
allShuf = nan(nValid, nTwin);
for i = 1:nValid
    r = decResults{validIdx(i)};
    allDec(i, :) = r.DecAccVal(:)';
    allShuf(i, :) = r.ShufMean(:)';
end

mnDec = mean(allDec, 1, 'omitnan') * 100;
seDec = std(allDec, 0, 1, 'omitnan') / sqrt(nValid) * 100;
mnShuf = mean(allShuf, 1, 'omitnan') * 100;

hl = plot(axAvg, xs(tIdx), mnDec, '-', 'Color', [0.8500 0.3250 0.0980], ...
    'LineWidth', 2);
% SE shading
xVec = xs(tIdx)';
yLo = mnDec - seDec;
yHi = mnDec + seDec;
fill(axAvg, [xVec, fliplr(xVec)], [yLo, fliplr(yHi)], ...
    [0.8500 0.3250 0.0980], 'EdgeColor', 'none', 'FaceAlpha', 0.2);
% Shuffle
plot(axAvg, xs(tIdx), mnShuf, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
yline(axAvg, 50, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

hold(axAvg, 'off');
xlabel(axAvg, 'Time from stimulus (s)');
ylabel(axAvg, 'Decoding accuracy (%)');
title(axAvg, sprintf('Average across %d mice', nValid), ...
    'FontSize', 9, 'FontWeight', 'normal');
legend(axAvg, {'Decoding','Shuffle','Chance'}, ...
    'Location', 'southeast', 'Box', 'off');
xlim(axAvg, [xs(tIdx(1)), xs(tIdx(end))]);
ylim(axAvg, [30 100]);
box(axAvg, 'off');

% ---- 5c. Average mutual information curve across mice ----
fMi = figure('Name','Average mutual information','Color','w', ...
    'Position', [100 120 360 280]);
axMi = axes(fMi);
hold(axMi, 'on');

allMi = nan(nValid, nTwin);
for i = 1:nValid
    r = decResults{validIdx(i)};
    allMi(i, :) = r.MiVal(:)';
end
mnMi = mean(allMi, 1, 'omitnan');
seMi = std(allMi, 0, 1, 'omitnan') / sqrt(nValid);

plot(axMi, xs(tIdx), mnMi, '-', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 2);
xVec = xs(tIdx)';
fill(axMi, [xVec, fliplr(xVec)], [mnMi-seMi, fliplr(mnMi+seMi)], ...
    [0.8500 0.3250 0.0980], 'EdgeColor', 'none', 'FaceAlpha', 0.2);
yline(axMi, 0, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 0.8);

hold(axMi, 'off');
xlabel(axMi, 'Time from stimulus (s)');
ylabel(axMi, 'Mutual information (bits)');
title(axMi, sprintf('Average across %d mice (MI)', nValid), ...
    'FontSize', 9, 'FontWeight', 'normal');
xlim(axMi, [xs(tIdx(1)), xs(tIdx(end))]);
ylim(axMi, [0, max(mnMi+seMi)*1.3 + 0.01]);
box(axMi, 'off');

% ---- 5d. Encoding weight heatmap (like Fig2 h,i) ----
% Show the encoding beta weights for a representative mouse
bestMouseIdx = validIdx(1);  % or find best decoding
if ~isempty(encResults{bestMouseIdx})
    eR = encResults{bestMouseIdx};
    fEnc = figure('Name','Encoding weights','Color','w', ...
        'Position', [150 150 400 300]);
    axEnc = axes(fEnc);
    imagesc(axEnc, xs(tIdx), 1:eR.NCells, eR.Beta);
    colormap(axEnc, redbluecmap);
    caxis(axEnc, [-1 1] * max(abs(eR.Beta(:)), [], 'omitnan'));
    colorbar(axEnc);
    xlabel(axEnc, 'Time (s)');
    ylabel(axEnc, 'Neuron #');
    title(axEnc, sprintf('Encoding weights: %s (hit>miss = positive)', ...
        eR.Mouse), 'FontSize', 8);
    axEnc.FontSize = 7;
    box(axEnc, 'off');
end

%% 6. Export
TransferLearning.ExportStandardFigure(fDec, 2, 'EncodingDecoding_TimeResolved.svg');
TransferLearning.ExportStandardFigure(fAvg, 2, 'EncodingDecoding_AverageAcc.svg');
TransferLearning.ExportStandardFigure(fMi, 2, 'EncodingDecoding_AverageMI.svg');
if exist('fEnc', 'var')
    TransferLearning.ExportStandardFigure(fEnc, 2, 'EncodingDecoding_Weights.svg');
end

fprintf('\nDone. %d/%d mice with valid data.\n', nValid, nMice);


% ==================== Local Functions ====================

function [X, y] = iBuildTrialMatrix(rawTbl, cellUIDs)
% Convert QueryNTS table to [nTrial x nCell x nTime] array
sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), 'VariableNames', {'CellUID','TrialUID','Behavior'});
sigCell = cell(size(sig,1), 1);
for i = 1:size(sig,1); sigCell{i} = sig(i,:); end
ntsTbl.Signal = sigCell;

% Filter to relevant cells
keepRows = ismember(ntsTbl.CellUID, cellUIDs);
ntsTbl = ntsTbl(keepRows, :);
if isempty(ntsTbl); X=[]; y=[]; return; end

trialUIDs = unique(ntsTbl.TrialUID);
nTrials = numel(trialUIDs);
nCells = numel(cellUIDs);
X = zeros(nTrials, nCells, nTime);
y = nan(nTrials, 1);
for iT = 1:nTrials
    rows = ntsTbl(ntsTbl.TrialUID == trialUIDs(iT), :);
    [~, loc] = ismember(rows.CellUID, cellUIDs);
    for iR = 1:height(rows)
        ci = loc(iR);
        if ci > 0
            X(iT, ci, :) = rows.Signal{iR};
        end
    end
    beh = rows.Behavior(~isnan(rows.Behavior));
    if isempty(beh); y(iT) = NaN; else; y(iT) = mode(beh); end
end

% Remove degenerate trials
hasData = all(isfinite(X), [2 3]) & isfinite(y);
X = X(hasData, :, :);
y = y(hasData);
X(isnan(X)) = 0;
end


function mi = iMutualInfo(yTrue, yPred, ~)
% 计算互信息 I(yTrue; yPred) 单位 bits
% 加伪计数 (0.5) 校正小样本偏差
if numel(unique(yTrue)) < 2 || numel(unique(yPred)) < 2
    mi = 0; return;
end
try
    cm = confusionmat(yTrue, yPred);
    cm = cm + 0.5;
    joint = cm / sum(cm(:));
    py = sum(joint, 2);     % P(y_true) 边缘
    pp = sum(joint, 1);     % P(y_pred) 边缘
    % 确保 joint 与 py*pp 维度一致
    margin = py * pp;
    ratio = joint ./ margin;
    mi = sum(joint(:) .* log2(ratio(:)), 'omitnan');
    mi = max(0, mi);
catch
    mi = 0;
end
end


function cmap = redbluecmap
% Simple red-blue colormap
n = 64;
half = round(n/2);
r = [linspace(0, 1, half)'; ones(half, 1)];
g = [linspace(0, 1, half)'; linspace(1, 0, half)'];
b = [ones(half, 1); linspace(1, 0, half)'];
cmap = [r, g, b];
end
