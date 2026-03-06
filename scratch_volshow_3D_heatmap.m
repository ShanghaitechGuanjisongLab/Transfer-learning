% scratch_volshow_3D_heatmap.m
% 用真实一个会话的 NTS 数据演示 volshow 体积渲染
% 三维：X=时间, Y=细胞(按@1s排序), Z=Trial
% 颜色=z-score，FaceAlpha极低展现纵深
%
% 运行: TransferLearning.scratch_volshow_3D_heatmap  (或直接 run)

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
xMask = (xsSec >= 0) & (xsSec <= 2);  % 0~2s 用于3D显示
xsSub = xsSec(xMask);

[~, idx1s] = min(abs(xsSec - 1));  % @1s 索引用于细胞排序

%% 1) 直接取第一个有效会话（有唯一 Design 的 LightWater 会话）
T = DS.TableQuery(["DateTime","Design","Mouse"], Stimulus="LightWater");
T.DateTime = datetime(T.DateTime); if ~isempty(T.DateTime.TimeZone), T.DateTime.TimeZone=''; end
T.Mouse = string(T.Mouse); T.Design = string(T.Design);
T = T(~ismissing(T.Design), :);

% 向量化：对每个 DateTime 计算 unique Design 数量，取第一个数量==1的
[uDts, ~, dtIdx] = unique(T.DateTime);
nDesPerDt = accumarray(dtIdx, 1, [], @(x) numel(unique(x)));  % 每个DateTime的unique Design数
% 实际要统计 Design 唯一数，重新用 groupsummary
T2 = table(T.DateTime, T.Design, 'VariableNames', {'DateTime','Design'});
[G2, gDt] = findgroups(T2.DateTime);
nUniqDes = splitapply(@(d) numel(unique(d(~ismissing(d)))), T2.Design, G2);
firstValid = find(nUniqDes == 1, 1, 'first');
if isempty(firstValid), error('No valid LightWater session found.'); end
bestDT  = gDt(firstValid);
bestDes = unique(T.Design(T.DateTime == bestDT)); bestDes = bestDes(~ismissing(bestDes));
fprintf('Selected session: %s\n', datestr(bestDT));

%% 2) 获取该会话所有 trial 的 NTS 数据
G = DS.QueryNTS(struct('DateTime', bestDT, 'Stimulus','LightWater','Design',char(bestDes)), ...
    UniExp.Flags.ZScore, 1:24);
if iscell(G), G = G{1}; end

cellUIDs  = uint64(G.CellUID);
trialUIDs = uint64(G.TrialUID);
if isa(G.TrialSignal, 'MATLAB.DataTypes.NDTable')
    sig = double(G.TrialSignal.Data);  % rows × 24
else
    sig = double(G.TrialSignal);
end

uCells  = unique(cellUIDs,  'stable');
uTrials = unique(trialUIDs, 'stable');
nCells  = numel(uCells);
nTrials = numel(uTrials);
nTime   = sum(xMask);

fprintf('nCells=%d, nTrials=%d, nTime=%d\n', nCells, nTrials, nTime);

%% 3) 按@1s 排序细胞（向量化：用 accumarray + median）
[~, cellLabel] = ismember(cellUIDs, uCells);   % 每行对应的细胞编号 [1..nCells]
v1s = sig(:, idx1s);
median1s = accumarray(cellLabel, v1s, [nCells, 1], @(x) median(x, 'omitnan'), NaN);
[~, sortIdx]   = sort(median1s, 'ascend');
uCells_sorted  = uCells(sortIdx);
% 重新映射 cellLabel 到排序后的索引
[~, cellLabelSorted] = ismember(cellUIDs, uCells_sorted);

%% 4) 构建 3D 体积 V(cellIdx, timeIdx, trialIdx)（向量化：线性索引一次赋值）
[~, trialLabel] = ismember(trialUIDs, uTrials);  % 每行对应的 trial 编号 [1..nTrials]

% 有效行：cell 和 trial 都能匹配
validRows = (cellLabelSorted > 0) & (trialLabel > 0);
cL = cellLabelSorted(validRows);
tL = trialLabel(validRows);
sigSub = sig(validRows, xMask);   % 有效行 × nTime

% 线性索引：V 的维度是 [nCells, nTime, nTrials]
% 对每个有效行，目标是 V(cL(r), :, tL(r)) = sigSub(r, :)
% 用 sub2ind 展开 time 维
V = nan(nCells, nTime, nTrials, 'single');
nValid = sum(validRows);
timeIdx = repmat(1:nTime, nValid, 1);           % nValid × nTime
cIdx    = repmat(cL, 1, nTime);                  % nValid × nTime
tIdx    = repmat(tL, 1, nTime);                  % nValid × nTime
linIdx  = sub2ind([nCells, nTime, nTrials], cIdx, timeIdx, tIdx);
V(linIdx) = single(sigSub);

%% 5) 归一化到 [0,1] 用于 volshow（内部使用线性映射）
vMin = -2; vMax = 2;  % clamp 到 ±2 SD
V_clamp = max(vMin, min(vMax, V));
V_norm  = single((V_clamp - vMin) / (vMax - vMin));  % [0,1], 0.5=zero
V_norm(isnan(V_norm)) = 0.5;  % NaN → grey (neutral)

%% 6) 构造颜色映射：蓝-白-红
nMap = 256;
blueWhiteRed = [linspace(0,1,nMap/2)', linspace(0,1,nMap/2)', ones(nMap/2,1); ...
                ones(nMap/2,1), linspace(1,0,nMap/2)', linspace(1,0,nMap/2)'];

% Alphamap：中间(near 0 z-score) 几乎透明，两端(高/低响应) 较不透明
alphaVec = zeros(nMap, 1);
center = nMap/2;
sigma  = nMap/6;
gaussBell = exp(-((1:nMap)' - center).^2 / (2*sigma^2));
% 两端高响应更不透明，中间透明
alphaVec = 0.04 * (1 - gaussBell * 0.95);

%% 7) volshow 渲染
fig = uifigure('Name', '3D NTS Volume', 'Color', 'w', ...
    'Position', [100 100 560 480]);
viewer = viewer3d(fig, ...
    'BackgroundColor', [1 1 1], ...
    'BackgroundGradient', 'off');

% Transformation: volshow V(row,col,slice)→(Y,X,Z)
% dim1=Cell(141)→Y, dim2=Time(32)→X, dim3=Trial(30)→Z
% 拉伸 X(Time) 和 Z(Trial) 轴让体素块比例更合理
% affinetform3d diag = [Xscale, Yscale, Zscale, 1]
scaleVec = [2.5, 1.0, 2.0];  % X=Time×2.5, Y=Cell×1.0, Z=Trial×2.0
tform = affinetform3d(diag([scaleVec, 1]));
h = volshow(V_norm, ...
    'Parent',         viewer, ...
    'RenderingStyle', 'VolumeRendering', ...
    'Colormap',       blueWhiteRed, ...
    'Alphamap',       alphaVec, ...
    'Transformation', tform);

%% 8) 坐标轴标签（紧贴左下角 XYZ 指示器）
% volshow V(row,col,slice) → (Y, X, Z)
% dim1=Cell→Y(绿), dim2=Time→X(红), dim3=Trial→Z(蓝)
uilabel(fig, 'Text', 'X: Time (0 ~ 2 s)', ...
    'FontSize', 7, 'FontColor', [0.85 0.1 0.1], ...
    'Position', [5, 48, 200, 16], 'BackgroundColor', 'none');
uilabel(fig, 'Text', 'Y: Cell (sorted by z@1s)', ...
    'FontSize', 7, 'FontColor', [0.1 0.6 0.1], ...
    'Position', [5, 30, 200, 16], 'BackgroundColor', 'none');
uilabel(fig, 'Text', 'Z: Trial', ...
    'FontSize', 7, 'FontColor', [0.1 0.1 0.85], ...
    'Position', [5, 12, 200, 16], 'BackgroundColor', 'none');

%% 9) 导出PNG
outPath = fullfile(outDirUNC, 'scratch_volshow_3D_heatmap.png');
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
pause(1);  % 等待渲染稳定
exportapp(fig, outPath);
fprintf('Wrote: %s\n', outPath);
