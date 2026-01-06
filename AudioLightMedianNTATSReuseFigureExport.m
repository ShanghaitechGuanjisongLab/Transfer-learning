%% AudioLight Median-NTATS 阈值复用图（最简版）
% 目标：生成“LearnedMedianActive → TransferMedianActive 的复用率 vs Transfer Performance”
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

TransferLearning.Clear;
AL = TransferLearning.AudioLightBaseline;

% --- 1) 时间窗与阈值
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);
kSigma = 3;

% --- 2) 取 Learned/Transfer 的“所有回合中位数”轨迹（每 cell 一条 48 点）
GLearn = AL.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.dFdF0, 1:30, UniExp.Flags.Median);
GTran  = AL.QueryNTATS(struct('Stimulus','LightWater','Phase','Transfer'), UniExp.Flags.dFdF0, 1:30, UniExp.Flags.Median);

XLearn = iNtatsData(GLearn.NTATS);
XTran  = iNtatsData(GTran.NTATS);

% Learned：中位数轨迹阈值活跃
learnedBaseMu = mean(XLearn(:, baseMask), 2);
learnedBaseSd = std(XLearn(:, baseMask), 0, 2);
learnedWinMx  = max(XLearn(:, winMask), [], 2);
learnedActiveMed = learnedWinMx > (learnedBaseMu + kSigma .* learnedBaseSd);

% Transfer：中位数轨迹阈值活跃
tranBaseMu = mean(XTran(:, baseMask), 2);
tranBaseSd = std(XTran(:, baseMask), 0, 2);
tranWinMx  = max(XTran(:, winMask), [], 2);
tranActiveMed = tranWinMx > (tranBaseMu + kSigma .* tranBaseSd);

% --- 3) 组装 per mouse × layer 的复用率，并关联 Transfer performance
C = AL.Cells;

% Performance：统一用 UniExp.DataSet.TableQuery（这里直接用 DataSet 对象的 TableQuery 方法）
PerfT = AL.TableQuery(["Mouse","Performance"], Design="LightWater", Phase="Transfer");
PerfT.Mouse = string(PerfT.Mouse);
[gM, mKeys] = findgroups(PerfT.Mouse);
perfByMouse = table(mKeys, splitapply(@(p) mean(p, 'omitnan'), PerfT.Performance, gM), ...
    'VariableNames', {'Mouse','TransferPerformance'});

learnedCell = table(uint64(GLearn.CellUID), double(learnedActiveMed), 'VariableNames', {'CellUID','LearnedActiveMed'});
transferCell = table(uint64(GTran.CellUID), double(tranActiveMed), 'VariableNames', {'CellUID','TransferActiveMed'});

learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
transferCell = innerjoin(transferCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');

learnedCell.ZKey = iZKey(learnedCell.ZLayer);
transferCell.ZKey = iZKey(transferCell.ZLayer);

learnedCell.Mouse = string(learnedCell.Mouse);
transferCell.Mouse = string(transferCell.Mouse);
learnedCell.ZKey = string(learnedCell.ZKey);
transferCell.ZKey = string(transferCell.ZKey);

medLT = innerjoin(learnedCell(:,{'Mouse','ZKey','CellUID','LearnedActiveMed'}), ...
    transferCell(:,{'Mouse','ZKey','CellUID','TransferActiveMed'}), 'Keys', {'Mouse','ZKey','CellUID'});

mouseZ = unique(medLT(:,{'Mouse','ZKey'}));
maxRows = height(mouseZ);
sumMouse = strings(maxRows,1);
sumZKey = strings(maxRows,1);
sumPerf = nan(maxRows,1);
sumNCells = nan(maxRows,1);
sumLearnedRate = nan(maxRows,1);
sumReuse = nan(maxRows,1);
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
    if nnz(LA) < 5
        continue;
    end

    reuse = mean(double(TA(LA)));
    learnedRate = mean(double(LA));

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
end

Summary = table(sumMouse(1:rowN), sumZKey(1:rowN), sumPerf(1:rowN), sumNCells(1:rowN), sumLearnedRate(1:rowN), sumReuse(1:rowN), ...
    'VariableNames', {'Mouse','ZKey','TransferPerformance','NCells','LearnedMedianActiveRate','ReuseRate_LearnedMedianActive'});

Summary = sortrows(Summary, {'ZKey','TransferPerformance'}, {'ascend','descend'});

rows23 = Summary.ZKey=="MOp23";
rows5  = Summary.ZKey=="MOp5";

r23 = iCorrReport(Summary.TransferPerformance(rows23), Summary.ReuseRate_LearnedMedianActive(rows23));
r5  = iCorrReport(Summary.TransferPerformance(rows5),  Summary.ReuseRate_LearnedMedianActive(rows5));

fprintf("\n=== Median-NTATS threshold reuse (LearnedActive→TransferActive) ===\n");
disp(Summary);
fprintf("\n[MOp2/3 Spearman] rho=%.3f, p=%.4g (n=%d)\n", r23.rho, r23.p, r23.n);
fprintf("[MOp5  Spearman] rho=%.3f, p=%.4g (n=%d)\n", r5.rho,  r5.p,  r5.n);

% --- 4) 画图并导出 SVG
figure('Name','AudioLight Median-NTATS threshold reuse vs Performance (by layer)');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
sgtitle(sprintf('Median NTATS threshold: max(0~1s)>mean(base)+%g*std(base)', kSigma));

nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows23);
y = Summary.TransferPerformance(rows23);
miceLbl = Summary.Mouse(rows23);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
ylabel('Perf');
title(sprintf('MOp2/3: \\rho=%.3f, p=%.3g (n=%d)', r23.rho, r23.p, r23.n));
hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

nexttile;
x = Summary.ReuseRate_LearnedMedianActive(rows5);
y = Summary.TransferPerformance(rows5);
miceLbl = Summary.Mouse(rows5);
scatter(x, y, 50, 'filled');
grid on; box off;
xlabel('Reuse: LearnedMedianActive → TransferMedianActive');
ylabel('Perf');
title(sprintf('MOp5: \\rho=%.3f, p=%.3g (n=%d)', r5.rho, r5.p, r5.n));
hold on; text(x, y, miceLbl, 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left'); hold off;

outDirUNC = "\\\\Data-Server-2\\个人数据\\张天夫\\202601";
fileName = sprintf('AudioLight_MedianNTATS_Reuse_LearnedActive_to_TransferActive_k%g.svg', kSigma);

outFile = fullfile(outDirUNC, fileName);
exportgraphics(gcf, outFile, 'ContentType','vector');
fprintf("\nSVG exported: %s\n", outFile);

% 同步把 Summary 留到 base，方便你后续直接用
assignin('base','AudioLight_MedianNTATSReuse_Summary',Summary);

%% ---- local functions ----
function zKey = iZKey(zLayer)
zl = string(zLayer);
zKey = strings(size(zl));
zKey(zl=="MOp2/3") = "MOp23";
zKey(zl=="MOp5") = "MOp5";
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

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable')
    X = NT.Data;
else
    X = NT;
end
end
