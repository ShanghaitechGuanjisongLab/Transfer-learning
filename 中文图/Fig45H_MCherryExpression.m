% Fig45H_MCherryExpression.m
% hSyn-mCherry 共聚焦图像表达率定量分析
% 方法：Cellpose DAPI 核分割 + Cellpose Cyto mCherry 形态分割
%       → 环阈值 HC+ 与 Cyto 形态并集 → 表达率
%
% 输出：中文图45H_MCherry表达率.svg

% 确保项目根目录在路径中
projectRoot = fileparts(fileparts(mfilename('fullpath')));
if ~contains(path, projectRoot)
    addpath(projectRoot);
end

%% ===================== 配置 =====================
cziPath = '\\Data-Server-2\个人数据\杨青宁\202607\共聚焦\vtf0245-10x-3-4-all.czi';
ringWidthPx = 1;          % 核周环宽度（像素）
ringBgSDFactor = 2.5;     % 环阈值：背景均值 + N × SD
minRingArea = 10;         % 最小环面积（像素）
ringChannel = 2;          % DAPI 通道
mCherryChannel = 1;       % mCherry 通道

%% ===================== 步骤1: 读取图像 =====================
fprintf('========== 步骤1: 读取 .czi 图像 ==========\n');
fprintf('文件: %s\n', cziPath);
tic;
bim = bioformatsread(cziPath);
img = gather(bim);
t = toc;
fprintf('读取完成 (%.1f 秒), 尺寸: %s, 类型: %s\n', t, mat2str(size(img)), class(img));

dapi = double(img(:,:,ringChannel));
mCherry = double(img(:,:,mCherryChannel));
fprintf('DAPI 范围: [%.0f, %.0f]\n', min(dapi(:)), max(dapi(:)));
fprintf('mCherry 范围: [%.0f, %.0f]\n', min(mCherry(:)), max(mCherry(:)));

%% ===================== 步骤2: Cellpose DAPI 核分割 =====================
fprintf('\n========== 步骤2: Cellpose cpsam_v2 分割 DAPI 核 ==========\n');
np = py.importlib.import_module('numpy');
models = py.importlib.import_module('cellpose.models');

dapi_py = np.array(dapi, pyargs('dtype', np.float64));
model_nuc = models.CellposeModel(pyargs('pretrained_model', 'cpsam_v2', 'gpu', true));

tic;
result_nuc = model_nuc.eval(dapi_py, pyargs('diameter', py.None, 'channels', py.list({int64(0), int64(0)})));
t = toc;
fprintf('DAPI 核分割完成 (%.1f 秒)\n', t);

masks_nuc = double(result_nuc{1});
nNucleiTotal = max(masks_nuc(:));
fprintf('检测到 DAPI 核: %d 个\n', nNucleiTotal);

%% ===================== 步骤3: Cellpose cyto3 分割 mCherry =====================
fprintf('\n========== 步骤3: Cellpose cyto3 分割 mCherry 细胞形态 ==========\n');
mCherry_py = np.array(mCherry, pyargs('dtype', np.float64));
model_cyto = models.CellposeModel(pyargs('pretrained_model', 'cyto3', 'gpu', true));

tic;
result_cyto = model_cyto.eval(mCherry_py, pyargs('diameter', py.None, 'channels', py.list({int64(0), int64(0)})));
t = toc;
fprintf('mCherry 细胞形态分割完成 (%.1f 秒)\n', t);

masks_cyto = double(result_cyto{1});
nCytoTotal = max(masks_cyto(:));
fprintf('检测到 mCherry 细胞形态对象: %d 个\n', nCytoTotal);

%% ===================== 步骤4: 核周环 mCherry 测量 =====================
fprintf('\n========== 步骤4: 核周环 mCherry 定量 ==========\n');
bwNuc = masks_nuc > 0;
bwDilated = imdilate(bwNuc, strel('disk', ringWidthPx));
ringAll = bwDilated & ~bwNuc;

% 背景 mCherry（扩展区域外）
bgVals = mCherry(~bwDilated);
bgMean = mean(bgVals);
bgStd = std(bgVals);
fprintf('背景 mCherry: mean=%.0f, std=%.0f\n', bgMean, bgStd);

% 用距离变换分配环像素到最近核
[~, distIdx] = bwdist(bwNuc);
nearestNuc = zeros(size(masks_nuc), 'uint32');
nearestNuc(ringAll) = uint32(arrayfun(@(x) masks_nuc(x), distIdx(ringAll)));

% 逐核测量环 mCherry
nucArea = zeros(nNucleiTotal, 1);
ringArea = zeros(nNucleiTotal, 1);
ringMcMean = zeros(nNucleiTotal, 1);

for i = 1:nNucleiTotal
    ni = (masks_nuc == i);
    nucArea(i) = sum(ni(:));
    ri = (nearestNuc == i);
    ringArea(i) = sum(ri(:));
    if ringArea(i) > 0
        ringMcMean(i) = mean(mCherry(ri));
    end
end

% 有效核（环面积足够）
validNuc = ringArea >= minRingArea & nucArea > 0;
nValidNuc = sum(validNuc);

% 环阈值判定
ringThresh = bgMean + ringBgSDFactor * bgStd;
isRingPositive = ringMcMean > ringThresh & validNuc;
nRingPos = sum(isRingPositive);
fprintf('有效核（环面积>=%dpx）: %d / %d\n', minRingArea, nValidNuc, nNucleiTotal);
fprintf('环阈值 (BG + %.1fSD = %.0f): mCherry+ = %d (%.1f%% of valid nuclei)\n', ...
    ringBgSDFactor, ringThresh, nRingPos, 100*nRingPos/nValidNuc);

%% ===================== 步骤5: 交叉匹配核与 Cyto 对象 =====================
fprintf('\n========== 步骤5: DAPI 核与 mCherry 细胞交叉匹配 ==========\n');

cytoHasNucleus = false(nCytoTotal, 1);
cytoBestNucleus = zeros(nCytoTotal, 1);
nucleusHasCyto = false(nNucleiTotal, 1);

for c = 1:nCytoTotal
    cytoMask = (masks_cyto == c);
    overlapNuc = masks_nuc(cytoMask);
    overlapNuc = overlapNuc(overlapNuc > 0);
    if ~isempty(overlapNuc)
        cytoHasNucleus(c) = true;
        bestNuc = mode(overlapNuc);
        cytoBestNucleus(c) = bestNuc;
        nucleusHasCyto(bestNuc) = true;
    end
end

nCytoMatched = sum(cytoHasNucleus);
nCytoOnly = sum(~cytoHasNucleus);
nNucMatched = sum(nucleusHasCyto);
cytoOnlyIds = find(~cytoHasNucleus);
cytoOnlyAreas = zeros(nCytoOnly, 1);
for k = 1:nCytoOnly
    cytoOnlyAreas(k) = sum(masks_cyto(:) == cytoOnlyIds(k));
end

fprintf('Cyto 对象总计: %d\n', nCytoTotal);
fprintf('  与 DAPI 核匹配: %d (%.1f%%)\n', nCytoMatched, 100*nCytoMatched/nCytoTotal);
fprintf('  无 DAPI 核 (Cyto-only): %d (%.1f%%), 面积 %d-%d px\n', ...
    nCytoOnly, 100*nCytoOnly/nCytoTotal, min(cytoOnlyAreas), max(cytoOnlyAreas));
fprintf('DAPI 核总计: %d\n', nNucleiTotal);
fprintf('  有 Cyto 匹配: %d (%.1f%%)\n', nNucMatched, 100*nNucMatched/nNucleiTotal);

%% ===================== 步骤6: 表达率计算 =====================
fprintf('\n========== 步骤6: mCherry 表达率 ==========\n');

hcNucIds = find(isRingPositive);
cytoNucIds = find(nucleusHasCyto);
unionNucIds = union(hcNucIds, cytoNucIds);
nUnionNuc = length(unionNucIds);

nIntersect = length(intersect(hcNucIds, cytoNucIds));
nHCOnly = length(setdiff(hcNucIds, cytoNucIds));
nCytoOnlyNuc = length(setdiff(cytoNucIds, hcNucIds));

nMcPositive = nUnionNuc + nCytoOnly;
nTotalCells = nNucleiTotal + nCytoOnly;
exprRate = 100 * nMcPositive / nTotalCells;

fprintf('\n--- 分子 (mCherry+) ---\n');
fprintf('  环 HC+ 核 (ring > BG+%.1fSD):      %5d\n', ringBgSDFactor, nRingPos);
fprintf('  Cyto 形态匹配核:                    %5d\n', nNucMatched);
fprintf('  交集 (HC+ ∩ Cyto):                  %5d\n', nIntersect);
fprintf('  HC+ only:                           %5d\n', nHCOnly);
fprintf('  Cyto only (核):                     %5d\n', nCytoOnlyNuc);
fprintf('  并集 (HC+ ∪ Cyto, 核):              %5d\n', nUnionNuc);
fprintf('  Cyto-only 独立细胞 (无 DAPI 核):     %5d\n', nCytoOnly);
fprintf('  ────────────────────────────────────\n');
fprintf('  总 mCherry+ 细胞:                   %5d\n', nMcPositive);
fprintf('\n--- 分母 (总细胞) ---\n');
fprintf('  DAPI 核:                            %5d\n', nNucleiTotal);
fprintf('  Cyto-only 额外细胞:                 %5d\n', nCytoOnly);
fprintf('  ────────────────────────────────────\n');
fprintf('  总细胞数:                           %5d\n', nTotalCells);
fprintf('\n  ★ mCherry 表达率: %d / %d = %.2f%%\n', nMcPositive, nTotalCells, exprRate);
fprintf('\n--- 各方法单独表达率 ---\n');
fprintf('  环阈值法 (HC+ / DAPI核):       %d / %d = %.2f%%\n', nRingPos, nNucleiTotal, 100*nRingPos/nNucleiTotal);
fprintf('  Cyto形态法 (cyto / 总细胞):     %d / %d = %.2f%%\n', nCytoTotal, nTotalCells, 100*nCytoTotal/nTotalCells);
fprintf('  并集法 (HC+∪Cyto / 总细胞):    %d / %d = %.2f%%\n', nMcPositive, nTotalCells, exprRate);

%% ===================== 步骤7: 制作中文图45H =====================
fprintf('\n========== 步骤7: 生成中文图45H ==========\n');

dapiNorm = (dapi - min(dapi(:))) / (max(dapi(:)) - min(dapi(:)));
mCherryNorm = (mCherry - min(mCherry(:))) / (max(mCherry(:)) - min(mCherry(:)));

% 各类轮廓
nucPerim = imdilate(bwperim(bwNuc), strel('disk', 1));

cytoOnlyPerim = false(1024, 1024);
cytoMatchedPerim = false(1024, 1024);
for c = 1:nCytoTotal
    cmPerim = bwperim(masks_cyto == c);
    if cytoHasNucleus(c)
        cytoMatchedPerim = cytoMatchedPerim | cmPerim;
    else
        cytoOnlyPerim = cytoOnlyPerim | cmPerim;
    end
end
cytoOnlyPerim = imdilate(cytoOnlyPerim, strel('disk', 2));
cytoMatchedPerim = imdilate(cytoMatchedPerim, strel('disk', 1));

hcPerim = false(1024, 1024);
for i = 1:nNucleiTotal
    if isRingPositive(i)
        hcPerim = hcPerim | bwperim(masks_nuc == i);
    end
end
hcPerim = imdilate(hcPerim, strel('disk', 1));

% 创建图窗
Fig = figure('Visible', 'off', 'Units', 'centimeters', ...
    'Position', [2 2 18 24], 'Color', 'w');
tlo = tiledlayout(4, 1, 'Padding', 'tight', 'TileSpacing', 'compact');
title(tlo, 'hSyn-mCherry 表达定量分析', 'FontSize', 14, 'FontWeight', 'bold');

% Panel A: DAPI + 核轮廓（青）+ Cyto 轮廓（绿/黄）+ HC+（红）
ax1 = nexttile;
dapiRGB = repmat(dapiNorm, [1 1 3]);
dapiRGB(:,:,2) = max(dapiRGB(:,:,2), nucPerim * 0.3);
dapiRGB(:,:,3) = max(dapiRGB(:,:,3), nucPerim * 0.3);
dapiRGB(:,:,2) = max(dapiRGB(:,:,2), cytoMatchedPerim * 0.6);
dapiRGB(:,:,1) = max(dapiRGB(:,:,1), cytoOnlyPerim * 0.8);
dapiRGB(:,:,2) = max(dapiRGB(:,:,2), cytoOnlyPerim * 0.8);
dapiRGB(:,:,1) = max(dapiRGB(:,:,1), hcPerim * 0.8);
imagesc(ax1, dapiRGB); axis image off;
title(ax1, sprintf('DAPI + 分割轮廓 (核=%d, 细胞形态=%d)', nNucleiTotal, nCytoTotal), ...
    'FontSize', 11, 'FontWeight', 'bold');
text(ax1, 10, 25, '{\\color{cyan}■} DAPI核', 'FontSize', 8, 'Background', [0 0 0 0.5], 'Color', 'w');
text(ax1, 10, 55, '{\\color{green}■} Cyto匹配', 'FontSize', 8, 'Background', [0 0 0 0.5], 'Color', 'w');
text(ax1, 10, 85, '{\\color{yellow}■} Cyto-only(无核)', 'FontSize', 8, 'Background', [0 0 0 0.5], 'Color', 'w');
text(ax1, 10, 115, '{\\color{red}■} HC+环阳性', 'FontSize', 8, 'Background', [0 0 0 0.5], 'Color', 'w');

% Panel B: mCherry + 同样轮廓
ax2 = nexttile;
mcRGB = repmat(mCherryNorm, [1 1 3]);
mcRGB(:,:,2) = max(mcRGB(:,:,2), nucPerim * 0.3);
mcRGB(:,:,3) = max(mcRGB(:,:,3), nucPerim * 0.3);
mcRGB(:,:,2) = max(mcRGB(:,:,2), cytoMatchedPerim * 0.6);
mcRGB(:,:,1) = max(mcRGB(:,:,1), cytoOnlyPerim * 0.8);
mcRGB(:,:,2) = max(mcRGB(:,:,2), cytoOnlyPerim * 0.8);
mcRGB(:,:,1) = max(mcRGB(:,:,1), hcPerim * 0.8);
imagesc(ax2, mcRGB); axis image off;
title(ax2, sprintf('mCherry + 分割轮廓 (环阈值 BG+%.1fSD=%.0f)', ringBgSDFactor, ringThresh), ...
    'FontSize', 11, 'FontWeight', 'bold');

% Panel C: 合成图（mCherry=品红, DAPI=青）
ax3 = nexttile;
merge = cat(3, mCherryNorm, dapiNorm, mCherryNorm * 0.2 + dapiNorm * 0.2);
imagesc(ax3, merge); axis image off;
title(ax3, '合成 (mCherry=品红, DAPI=青)', 'FontSize', 11, 'FontWeight', 'bold');

% Panel D: mCherry+ 分类图
ax4 = nexttile;
classRGB = repmat(dapiNorm * 0.5, [1 1 3]);
classRGB(:,:,1) = max(classRGB(:,:,1), hcPerim * 0.8);
cytoOnlyNucPerim = false(1024, 1024);
for i = 1:nNucleiTotal
    if nucleusHasCyto(i) && ~isRingPositive(i)
        cytoOnlyNucPerim = cytoOnlyNucPerim | bwperim(masks_nuc == i);
    end
end
cytoOnlyNucPerim = imdilate(cytoOnlyNucPerim, strel('disk', 1));
classRGB(:,:,2) = max(classRGB(:,:,2), cytoOnlyNucPerim * 0.6);
classRGB(:,:,1) = max(classRGB(:,:,1), cytoOnlyPerim * 0.8);
classRGB(:,:,2) = max(classRGB(:,:,2), cytoOnlyPerim * 0.8);
imagesc(ax4, classRGB); axis image off;
title(ax4, sprintf('mCherry+ 分类 (并集=%d, 表达率=%.1f%%)', nMcPositive, exprRate), ...
    'FontSize', 11, 'FontWeight', 'bold');
text(ax4, 10, 25, sprintf('{\\color{magenta}■} HC+环阳性: %d', nRingPos), ...
    'FontSize', 8, 'Background', [0 0 0 0.5], 'Color', 'w');
text(ax4, 10, 60, sprintf('{\\color{green}■} Cyto形态: %d (核内) + %d (独立)', nNucMatched, nCytoOnly), ...
    'FontSize', 8, 'Background', [0 0 0 0.5], 'Color', 'w');
text(ax4, 10, 95, sprintf('{\\color{cyan}■} 总细胞: %d (DAPI核) + %d (Cyto-only) = %d', ...
    nNucleiTotal, nCytoOnly, nTotalCells), ...
    'FontSize', 8, 'Background', [0 0 0 0.5], 'Color', 'w');
text(ax4, 10, 130, sprintf('★ 表达率 = %d/%d = %.2f%%', nMcPositive, nTotalCells, exprRate), ...
    'FontSize', 9, 'FontWeight', 'bold', 'Background', [0 0 0 0.6], 'Color', 'w');

% 导出 SVG
svgPath = TransferLearning.ExportStandardFigure(Fig, 2, '中文图45H_MCherry表达率.svg');
fprintf('图已保存: %s\n', svgPath);
close(Fig);
fprintf('\n============ 分析完成 ============\n');
