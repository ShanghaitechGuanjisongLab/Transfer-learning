% 快速体素渲染：仅绘制指定Trial，不做Pair筛选与统计
% 依赖缓存文件：diag_B_pairA_sessionK_raw3d_cache.mat

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
cachePath = fullfile(outDirUNC, 'diag_B_pairA_sessionK_raw3d_cache.mat');
if ~isfile(cachePath)
	error('CacheNotFound: %s. 先运行一次 scratch_diag_B_slice.m 生成缓存。', cachePath);
end

S = load(cachePath, 'raw3d');
raw3d = S.raw3d;

% 你可以只改这里：指定要堆成体素的trial
trialsWanted = [1, 30];
trialsWanted = unique(trialsWanted(:)');
trialsWanted = trialsWanted(trialsWanted >= 1 & trialsWanted <= size(raw3d, 3));
if isempty(trialsWanted)
	error('No valid trials selected.');
end

% 与B脚本一致的全局对称映射
vAbsGlobal = sqrt(max(abs(raw3d(:))));  % 二次方根clim
vol = raw3d(:, :, trialsWanted);
volClamp = max(-vAbsGlobal, min(vAbsGlobal, vol));
volNorm = 0.5 + 0.5 * (volClamp / vAbsGlobal);
volNorm = max(0, min(1, volNorm));
volNorm(isnan(volNorm)) = 0.5;

% 锚点体素：强制volshow的自动归一化范围为[0,1]，防止窄范围被拉伸
volNorm(1,1,1) = 0;
volNorm(end,end,end) = 1;

nMap = 256;
nHalf = nMap / 2;
blueWhiteRed = [linspace(0,1,nHalf)', linspace(0,1,nHalf)', ones(nHalf,1); ...
                ones(nHalf,1), linspace(1,0,nHalf)', linspace(1,0,nHalf)'];
alphaVec = repmat(1/2, nMap, 1);

fig = uifigure('Name', 'Volshow Trials Only', 'Position', [120 120 680 520]);
viewer = viewer3d(fig, 'BackgroundColor', [0,0,0], 'BackgroundGradient', 'off', 'Lighting', 'off');
tform = affinetform3d(diag([2.5, 1.0, 2.0, 1]));

volshow(single(volNorm), 'Parent', viewer, ...
	'RenderingStyle', 'VolumeRendering', ...
	'Colormap', blueWhiteRed, ...
	'Alphamap', alphaVec, ...
	'Transformation', tform);

uilabel(fig, 'Text', sprintf('Trials in volume: %s', mat2str(trialsWanted)), ...
	'FontSize', 8, 'FontColor', [0.15 0.15 0.15], 'Position', [10, 38, 640, 18], 'BackgroundColor', 'none');
uilabel(fig, 'Text', sprintf('Global clim = [%.1f, %.1f], alpha = 0.04', -vAbsGlobal, vAbsGlobal), ...
	'FontSize', 8, 'FontColor', [0.15 0.15 0.15], 'Position', [10, 18, 640, 18], 'BackgroundColor', 'none');

pause(1);
outPng = fullfile(outDirUNC, sprintf('diag_B_volshow_trials_%s.png', strrep(mat2str(trialsWanted), ' ', '')));
exportapp(fig, outPng);
fprintf('Wrote: %s\n', outPng);
