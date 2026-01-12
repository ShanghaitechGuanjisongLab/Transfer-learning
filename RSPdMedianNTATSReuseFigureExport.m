%% RSPd Median-NTATS 阈值复用图（最简版）
% 目标：检验 RSPd 中“Learned(声水)→Transfer(光水) 复用率”是否与 Transfer 表现相关
% 并导出 SVG 到：\\Data-Server-2\个人数据\张天夫\202601

% --- 0) 兜底：确保项目/路径已加载（避免 UniExp.* 类找不到）
try
    if ~exist('UniExp.DataSet','class')
        thisFile = mfilename('fullpath');
        thisDir = fileparts(thisFile);
        projFile = fullfile(thisDir, 'Transferlearning.prj');
        if exist(projFile,'file')
            try
                matlab.project.loadProject(projFile);
            catch
            end
        end
        if ~exist('UniExp.DataSet','class')
            matlabRoot = fileparts(thisDir); % ...\Documents\MATLAB
            ueaaf = fullfile(matlabRoot, 'Unified-Experimental-Analysis-and-Figuring');
            if exist(ueaaf,'dir')
                addpath(genpath(ueaaf));
            end
        end
    end
catch
end

% 性能点：避免每次 Clear 导致 memoized cache 失效
if evalin('base', "exist('RSPdDS','var')")
    RSP = evalin('base', 'RSPdDS');
else
    RSP = TransferLearning.RSPd;
    assignin('base', 'RSPdDS', RSP);
end

% --- 1) 时间窗与阈值
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);
kSigma = 3;

% 排除指定鼠（例如 vtf0353 原始视频亮度异常）
excludeMice = string(["vtf0353"]);

% --- 2) 取 Learned/Transfer 的“所有回合中位数”轨迹（每 cell 一条 48 点）
% 必须用 Phase 明确确认 Learned/Transfer（不允许用 Design/Stimulus 推断）。
% 注意：不要用 dFdF0（当 F0 可能为负时会崩）；统一用 z-score。
GLearn = RSP.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTran  = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
XLearn = iNtatsData(GLearn.NTATS);
XTran  = iNtatsData(GTran.NTATS);

% Transfer：按行为拆分（Behavior=1 命中，Behavior=0 错失）
% 注意：直接在 struct 里加 Behavior 可能触发 Empty_group；
% 这里用 QueryTable 方式一次性查询 Hit/Miss 两组。
QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
    'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});
try
    GTranHM = RSP.QueryNTATS(QT_HM, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
catch ME
    warning(ME.identifier, 'QueryNTATS Hit/Miss 为空：%s', ME.message);
    GTranHM = [];
end

XTranHit = nan(size(XTran));
XTranMiss = nan(size(XTran));
cellUIDTranHM = uint64([]);
if ~isempty(GTranHM) && height(GTranHM) > 0
    XTranHM = iNtatsData(GTranHM.NTATS);
    if ndims(XTranHM) ~= 3 || size(XTranHM,3) < 2
        error('Unexpected NTATS dimension for Hit/Miss QueryTable result.');
    end
    XTranHit = XTranHM(:,:,1);
    XTranMiss = XTranHM(:,:,2);
    cellUIDTranHM = uint64(GTranHM.CellUID);
end

% Learned：中位数轨迹阈值活跃
learnedBaseMu = mean(XLearn(:, baseMask), 2, 'omitnan');
learnedBaseSd = std(XLearn(:, baseMask), 0, 2, 'omitnan');
learnedWinMx  = max(XLearn(:, winMask), [], 2, 'omitnan');
learnedActiveMed = learnedWinMx > (learnedBaseMu + kSigma .* learnedBaseSd);

% Transfer：中位数轨迹阈值活跃
tranBaseMu = mean(XTran(:, baseMask), 2, 'omitnan');
tranBaseSd = std(XTran(:, baseMask), 0, 2, 'omitnan');
tranWinMx  = max(XTran(:, winMask), [], 2, 'omitnan');
tranActiveMed = tranWinMx > (tranBaseMu + kSigma .* tranBaseSd);

% Transfer Hit：中位数轨迹阈值活跃
tranHitBaseMu = mean(XTranHit(:, baseMask), 2, 'omitnan');
tranHitBaseSd = std(XTranHit(:, baseMask), 0, 2, 'omitnan');
tranHitWinMx  = max(XTranHit(:, winMask), [], 2, 'omitnan');
tranActiveMedHit = tranHitWinMx > (tranHitBaseMu + kSigma .* tranHitBaseSd);

% Transfer Miss：中位数轨迹阈值活跃
tranMissBaseMu = mean(XTranMiss(:, baseMask), 2, 'omitnan');
tranMissBaseSd = std(XTranMiss(:, baseMask), 0, 2, 'omitnan');
tranMissWinMx  = max(XTranMiss(:, winMask), [], 2, 'omitnan');
tranActiveMedMiss = tranMissWinMx > (tranMissBaseMu + kSigma .* tranMissBaseSd);

% --- 3) per mouse × layer 的复用率，并关联 Transfer performance
C = RSP.Cells;

% Performance：统一用 UniExp.DataSet.TableQuery（同样强制 Phase=Transfer）
PerfT = RSP.TableQuery(["Mouse","Performance"], Phase="Transfer", Design="LightWater");
PerfT.Mouse = string(PerfT.Mouse);
[gM, mKeys] = findgroups(PerfT.Mouse);
perfByMouse = table(mKeys, splitapply(@(p) mean(p, 'omitnan'), PerfT.Performance, gM), ...
    'VariableNames', {'Mouse','TransferPerformance'});

learnedCell = table(uint64(GLearn.CellUID), double(learnedActiveMed), 'VariableNames', {'CellUID','LearnedActiveMed'});
transferCell = table(uint64(GTran.CellUID), double(tranActiveMed), 'VariableNames', {'CellUID','TransferActiveMed'});

transferCellHit = table(cellUIDTranHM, double(tranActiveMedHit), 'VariableNames', {'CellUID','TransferActiveMedHit'});
transferCellMiss = table(cellUIDTranHM, double(tranActiveMedMiss), 'VariableNames', {'CellUID','TransferActiveMedMiss'});

learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
transferCell = innerjoin(transferCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');

if ~isempty(transferCellHit)
    transferCellHit = innerjoin(transferCellHit, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
end
if ~isempty(transferCellMiss)
    transferCellMiss = innerjoin(transferCellMiss, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
end

learnedCell.ZKey = iZKey(learnedCell.ZLayer);
transferCell.ZKey = iZKey(transferCell.ZLayer);

transferCellHit.ZKey = iZKey(transferCellHit.ZLayer);
transferCellMiss.ZKey = iZKey(transferCellMiss.ZLayer);

learnedCell.Mouse = string(learnedCell.Mouse);
transferCell.Mouse = string(transferCell.Mouse);
learnedCell.ZKey = string(learnedCell.ZKey);
transferCell.ZKey = string(transferCell.ZKey);

transferCellHit.Mouse = string(transferCellHit.Mouse);
transferCellMiss.Mouse = string(transferCellMiss.Mouse);
transferCellHit.ZKey = string(transferCellHit.ZKey);
transferCellMiss.ZKey = string(transferCellMiss.ZKey);

medLT = innerjoin(learnedCell(:,{'Mouse','ZKey','CellUID','LearnedActiveMed'}), ...
    transferCell(:,{'Mouse','ZKey','CellUID','TransferActiveMed'}), 'Keys', {'Mouse','ZKey','CellUID'});

medLT = outerjoin(medLT, transferCellHit(:,{'Mouse','ZKey','CellUID','TransferActiveMedHit'}), ...
    'Keys', {'Mouse','ZKey','CellUID'}, 'MergeKeys', true, 'Type', 'left');
medLT = outerjoin(medLT, transferCellMiss(:,{'Mouse','ZKey','CellUID','TransferActiveMedMiss'}), ...
    'Keys', {'Mouse','ZKey','CellUID'}, 'MergeKeys', true, 'Type', 'left');

mouseZ = unique(medLT(:,{'Mouse','ZKey'}));
maxRows = height(mouseZ);
sumMouse = strings(maxRows,1);
sumZKey = strings(maxRows,1);
sumPerf = nan(maxRows,1);
sumNCells = nan(maxRows,1);
sumLearnedRate = nan(maxRows,1);
sumReuse = nan(maxRows,1);
sumTransferRate = nan(maxRows,1);
sumReuseHit = nan(maxRows,1);
sumReuseMiss = nan(maxRows,1);
rowN = 0;

for i = 1:height(mouseZ)
    m = string(mouseZ.Mouse(i));
    z = string(mouseZ.ZKey(i));
    rows = (string(medLT.Mouse)==m) & (string(medLT.ZKey)==z);
    if nnz(rows) < 10
        continue;
    end

    LA = logical(medLT.LearnedActiveMed(rows));
    TA = logical(medLT.TransferActiveMed(rows));

    learnedRate = mean(double(LA));
    transferRate = mean(double(TA));

    reuse = NaN;
    if nnz(LA) >= 5
        reuse = mean(double(TA(LA)));
    end

    reuseHit = NaN;
    if ismember('TransferActiveMedHit', medLT.Properties.VariableNames)
        taHit = medLT.TransferActiveMedHit(rows);
        denom = LA & isfinite(taHit);
        if nnz(denom) >= 5
            reuseHit = mean(taHit(denom), 'omitnan');
        end
    end

    reuseMiss = NaN;
    if ismember('TransferActiveMedMiss', medLT.Properties.VariableNames)
        taMiss = medLT.TransferActiveMedMiss(rows);
        denom = LA & isfinite(taMiss);
        if nnz(denom) >= 5
            reuseMiss = mean(taMiss(denom), 'omitnan');
        end
    end

    perf = perfByMouse.TransferPerformance(perfByMouse.Mouse==m);
    if isempty(perf)
        perf = NaN;
    else
        perf = perf(1);
    end

    rowN = rowN + 1;
    sumMouse(rowN) = m;
    sumZKey(rowN) = z;
    sumPerf(rowN) = perf;
    sumNCells(rowN) = nnz(rows);
    sumLearnedRate(rowN) = learnedRate;
    sumReuse(rowN) = reuse;
    sumTransferRate(rowN) = transferRate;
    sumReuseHit(rowN) = reuseHit;
    sumReuseMiss(rowN) = reuseMiss;
end

Summary = table(sumMouse(1:rowN), sumZKey(1:rowN), sumPerf(1:rowN), sumNCells(1:rowN), sumLearnedRate(1:rowN), sumTransferRate(1:rowN), sumReuse(1:rowN), ...
    sumReuseHit(1:rowN), sumReuseMiss(1:rowN), ...
    'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','LearnedMedianActiveRate','TransferMedianActiveRate','ReuseRate_LearnedMedianActive', ...
    'ReuseRate_LearnedMedianActive_Hit','ReuseRate_LearnedMedianActive_Miss'});

Summary = sortrows(Summary, {'ZKey','TransferPerformance'}, {'ascend','descend'});

if ~isempty(excludeMice)
    Summary = Summary(~ismember(string(Summary.Mouse), excludeMice), :);
end

rows23 = Summary.ZKey=="RSPd23";
rows5  = Summary.ZKey=="RSPd5";

r23 = iCorrReport(Summary.TransferPerformance(rows23), Summary.ReuseRate_LearnedMedianActive(rows23));
r5  = iCorrReport(Summary.TransferPerformance(rows5),  Summary.ReuseRate_LearnedMedianActive(rows5));

% Hit vs Miss：同一只鼠同一层的配对比较（正向复用率）
p23 = iPairedHitMissP(Summary.ReuseRate_LearnedMedianActive_Hit(rows23), Summary.ReuseRate_LearnedMedianActive_Miss(rows23));
p5  = iPairedHitMissP(Summary.ReuseRate_LearnedMedianActive_Hit(rows5),  Summary.ReuseRate_LearnedMedianActive_Miss(rows5));

fprintf("\n=== RSPd Median-NTATS threshold reuse (AudioWaterActive→LightWaterActive) ===\n");
disp(Summary);
fprintf("\n[RSPd2/3 Spearman] rho=%.3f, p=%.4g (n=%d)\n", r23.rho, r23.p, r23.n);
fprintf("[RSPd5  Spearman] rho=%.3f, p=%.4g (n=%d)\n", r5.rho,  r5.p,  r5.n);

fprintf("\n=== Hit vs Miss (forward reuse: LearnedActive→TransferActive) ===\n");
fprintf("[RSPd2/3 signrank hit>miss] p=%.4g (n=%d)\n", p23.p, p23.n);
fprintf("[RSPd5  signrank hit>miss] p=%.4g (n=%d)\n", p5.p,  p5.n);

% --- 4) 画图并导出 SVG
figure('Name','RSPd reuse vs Performance (by layer)');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
sgtitle('Reuse vs Performance');

ax23 = nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows23);
y = Summary.TransferPerformance(rows23);
miceLbl = Summary.Mouse(rows23);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: AudioWaterActive \rightarrow LightWaterActive');
ylabel('Performance (LightWater)');
ylim([0,1]);
title(sprintf('RSPd2/3: \\rho=%.3f, p=%.3g (n=%d)', r23.rho, r23.p, r23.n));
hold on;
text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
iAddTrendLine(ax23, x, y);
hold off;
ax23 = gca;
if isprop(ax23, 'Toolbar') && ~isempty(ax23.Toolbar)
    ax23.Toolbar.Visible = 'off';
end

ax5 = nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows5);
y = Summary.TransferPerformance(rows5);
miceLbl = Summary.Mouse(rows5);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: AudioWaterActive \rightarrow LightWaterActive');
ylabel('Performance (LightWater)');
ylim([0,1]);
title(sprintf('RSPd5: \\rho=%.3f, p=%.3g (n=%d)', r5.rho, r5.p, r5.n));
hold on;
text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');
iAddTrendLine(ax5, x, y);
hold off;
ax5 = gca;
if isprop(ax5, 'Toolbar') && ~isempty(ax5.Toolbar)
    ax5.Toolbar.Visible = 'off';
end

MATLAB.Graphics.UnifyAxesLims([ax23, ax5], @xlim);

outDirUNC = "\\\\Data-Server-2\\个人数据\\张天夫\\202601";
fileName = 'RSPd_Reuse_AudioWaterActive_to_LightWaterActive.svg';
outFile = fullfile(outDirUNC, fileName);
exportgraphics(gcf, outFile, 'ContentType','vector');
fprintf("\nSVG exported: %s\n", outFile);

% --- 5) Hit vs Miss：用 UniExp.BarScatterCompare 作图示意（按 layer）
figure('Name','RSPd Hit vs Miss reuse (BarScatterCompare)');
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
sgtitle('RSPd Hit vs Miss forward reuse (2D groups)');

nexttile;
hit23 = Summary.ReuseRate_LearnedMedianActive_Hit(rows23);
miss23 = Summary.ReuseRate_LearnedMedianActive_Miss(rows23);
mask23 = isfinite(hit23) & isfinite(miss23);

hit5 = Summary.ReuseRate_LearnedMedianActive_Hit(rows5);
miss5 = Summary.ReuseRate_LearnedMedianActive_Miss(rows5);
mask5 = isfinite(hit5) & isfinite(miss5);

colHit = {hit23(mask23); hit5(mask5)};
colMiss = {miss23(mask23); miss5(mask5)};
Groups = table(colHit, colMiss, ...
    'VariableNames', {'Hit','Miss'}, ...
    'RowNames', {'RSPd2/3','RSPd5'});
Groups.Properties.DimensionNames = {'Layer','Outcome'};

layerNames = string(Groups.Properties.RowNames);
layerPairs = [layerNames, layerNames];
outcomePairs = repmat(["Hit","Miss"], numel(layerNames), 1);
groupPair2D = table(layerPairs, outcomePairs, 'VariableNames', Groups.Properties.DimensionNames);
CompareGroup = table(groupPair2D, 'VariableNames', {'GroupPair'});

UniExp.BarScatterCompare(Groups, false, CompareGroup);
ylabel('Reuse');
title('Forward reuse (Hit vs Miss)');
ax = gca;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
    ax.Toolbar.Visible = 'off';
end

fileNameHM = 'RSPd_Reuse_AudioWaterActive_to_LightWaterActive_HitMiss.svg';
outFileHM = fullfile(outDirUNC, fileNameHM);
exportgraphics(gcf, outFileHM, 'ContentType','vector');
fprintf("\nSVG exported (hit-miss): %s\n", outFileHM);

% 同步把 Summary 留到 base，方便你后续直接用
assignin('base','RSPd_MedianNTATSReuse_Summary',Summary);

%% ---- local functions ----
function zKey = iZKey(zLayer)
zl = string(zLayer);
zKey = strings(size(zl));
zKey(zl=="RSPd2/3") = "RSPd23";
zKey(zl=="RSPd5")   = "RSPd5";
end

function out = iCorrReport(x, y)
x = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask); y = y(mask);
out = struct('rho', NaN, 'p', NaN, 'n', numel(x));
if numel(x) < 4
    return;
end
if std(x)==0 || std(y)==0
    return;
end
[r,p] = corr(x, y, 'type','Spearman');
out.rho = r;
out.p = p;
end

function out = iPairedHitMissP(hit, miss)
hit = hit(:);
miss = miss(:);
mask = isfinite(hit) & isfinite(miss);
hit = hit(mask);
miss = miss(mask);
out = struct('p', NaN, 'n', numel(hit));
if numel(hit) < 4
    return;
end
out.p = signrank(hit, miss, 'tail', 'right');
end

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable')
    X = NT.Data;
else
    X = NT;
end
end

function h = iAddTrendLine(ax, x, y)
% 在相关性散点图上添加一条线性趋势线段（仅基于输入点拟合）
h = gobjects(0);
if nargin < 3 || isempty(ax) || ~isgraphics(ax)
    return;
end
x = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask); y = y(mask);
if numel(x) < 2
    return;
end
if std(x) == 0
    return;
end
p = polyfit(double(x), double(y), 1);
xl = xlim(ax);
xFit = double(xl(:))';
yFit = polyval(p, xFit);
hold(ax, 'on');
h = plot(ax, xFit, yFit, '-', 'Color', 'k', 'LineWidth', 1.2);
end
