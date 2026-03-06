% 诊断：从B的volshow数据中取出Trial截面做2D热图
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));

%% 1) 复用B脚本逻辑
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iExcludeCeiling(Sess);
SessSpeed = iSessionDeltaNext(Sess);
nPairs = height(SessSpeed);
deltaHit = double(SessSpeed.Speed_DeltaNext);

sd1sMean=nan(nPairs,1); sd1sK=nan(nPairs,1); sd1sK1=nan(nPairs,1); nCellMin=nan(nPairs,1);
for iP = 1:nPairs
	[~,ntatsK]=iSessionNTATS(DS,SessSpeed.DateTime(iP));
	[~,ntatsK1]=iSessionNTATS(DS,SessSpeed.DateTimeNext(iP));
	if isempty(ntatsK)||isempty(ntatsK1), continue; end
	vK=double(ntatsK(:,idx1s)); vK1=double(ntatsK1(:,idx1s));
	vK=vK(isfinite(vK)&vK>=-1&vK<=1); vK1=vK1(isfinite(vK1)&vK1>=-1&vK1<=1);
	nCellMin(iP)=min(numel(vK),numel(vK1));
	if numel(vK)>=3&&numel(vK1)>=3
		sd1sK(iP)=std(vK); sd1sK1(iP)=std(vK1); sd1sMean(iP)=(sd1sK(iP)+sd1sK1(iP))/2;
	end
end

valid=isfinite(deltaHit)&isfinite(sd1sMean)&(nCellMin>=10);
validIdx=find(valid);
[~,sortDesc]=sort(sd1sMean(validIdx),'descend');
sortedBySD=validIdx(sortDesc);
bestA=NaN; found=false;
for iA=1:numel(sortedBySD)
	candA=sortedBySD(iA); minSD_A=min(sd1sK(candA),sd1sK1(candA));
	for iB=numel(sortedBySD):-1:1
		candB=sortedBySD(iB);
		if candB==candA, continue; end
		maxSD_B=max(sd1sK(candB),sd1sK1(candB));
		if sd1sMean(candA)>sd1sMean(candB)&&(deltaHit(candA)-deltaHit(candB))>=0.10&&minSD_A>maxSD_B
			bestA=candA; found=true; break;
		end
	end
	if found, break; end
end

%% 2) 取Pair A Session K的raw data
xMask = (xsSec>=0)&(xsSec<=2);
dtK = SessSpeed.DateTime(bestA);
[~,ntats,ntsRaw] = iSessionNTATS(DS,dtK);
v1s = double(ntats(:,idx1s));
keepMask = isfinite(v1s)&v1s>=-1&v1s<=1;
[~,sortIdx]=sort(v1s(keepMask),'ascend');
raw3d = double(ntsRaw(keepMask,:,:));
raw3d = raw3d(sortIdx, xMask, :);

fprintf('Volume: %d cells × %d time × %d trials\n', size(raw3d,1), size(raw3d,2), size(raw3d,3));
fprintf('Global: min=%.3f, max=%.3f, mean=%.3f, median=%.3f\n', ...
	min(raw3d(:)), max(raw3d(:)), mean(raw3d(:),'omitnan'), median(raw3d(:),'omitnan'));

% 缓存原始体素，供“只画体素”脚本快速调用
cachePath = fullfile(outDirUNC, 'diag_B_pairA_sessionK_raw3d_cache.mat');
save(cachePath, 'raw3d', 'xsSec', 'xMask', '-v7.3');
fprintf('Wrote cache: %s\n', cachePath);

%% 2.5) 颜色一致性校验：volshow映射 vs imagesc映射（同一trial）
midTrial = round(size(raw3d, 3) / 2);
sliceMid = raw3d(:, :, midTrial);

nMap = 256; nHalf = nMap / 2;
blueWhiteRed = [linspace(0,1,nHalf)', linspace(0,1,nHalf)', ones(nHalf,1); ...
	ones(nHalf,1), linspace(1,0,nHalf)', linspace(1,0,nHalf)'];

% Case A: 全局clim（与B线性版一致）
vAbsGlobal = max(abs(raw3d(:)));
vClampA = max(-vAbsGlobal, min(vAbsGlobal, sliceMid));
vNormVolA = 0.5 + 0.5 * (vClampA / vAbsGlobal);
vNormVolA = max(0, min(1, vNormVolA));
idxVolA = 1 + floor(vNormVolA * (nMap - 1));
idxVolA = max(1, min(nMap, idxVolA));

% imagesc 等价归一化： (x-cmin)/(cmax-cmin), cmin=-vAbs, cmax=+vAbs
vNormImgA = (sliceMid + vAbsGlobal) / (2 * vAbsGlobal);
vNormImgA = max(0, min(1, vNormImgA));
idxImgA = 1 + floor(vNormImgA * (nMap - 1));
idxImgA = max(1, min(nMap, idxImgA));

rgbVolA = ind2rgb(idxVolA, blueWhiteRed);
rgbImgA = ind2rgb(idxImgA, blueWhiteRed);
diffA = abs(rgbVolA - rgbImgA);
fprintf('Color-check Global (Trial %d): maxRGBDiff=%.6f, meanRGBDiff=%.6f\n', ...
	midTrial, max(diffA(:)), mean(diffA(:)));

% Case B: self-clim（与diag_B_slice_trialXX_self图一致）
vAbsSelf = max(abs(sliceMid(:)));
vClampB = max(-vAbsSelf, min(vAbsSelf, sliceMid));
vNormVolB = 0.5 + 0.5 * (vClampB / vAbsSelf);
vNormVolB = max(0, min(1, vNormVolB));
idxVolB = 1 + floor(vNormVolB * (nMap - 1));
idxVolB = max(1, min(nMap, idxVolB));

vNormImgB = (sliceMid + vAbsSelf) / (2 * vAbsSelf);
vNormImgB = max(0, min(1, vNormImgB));
idxImgB = 1 + floor(vNormImgB * (nMap - 1));
idxImgB = max(1, min(nMap, idxImgB));

rgbVolB = ind2rgb(idxVolB, blueWhiteRed);
rgbImgB = ind2rgb(idxImgB, blueWhiteRed);
diffB = abs(rgbVolB - rgbImgB);
fprintf('Color-check Self   (Trial %d): maxRGBDiff=%.6f, meanRGBDiff=%.6f\n', ...
	midTrial, max(diffB(:)), mean(diffB(:)));

fprintf('Slice stats (Trial %d): fracNeg=%.3f, fracPos=%.3f, frac|z|<1=%.3f\n', ...
	midTrial, mean(sliceMid(:)<0), mean(sliceMid(:)>0), mean(abs(sliceMid(:))<1));

%% 3) 取几个trial的2D截面
trialsToShow = [1, round(size(raw3d,3)/4), round(size(raw3d,3)/2), size(raw3d,3)];
trialsToShow = unique(trialsToShow);

% -- 用本slice自身范围 --
for t = 1:numel(trialsToShow)
	tr = trialsToShow(t);
	slice = raw3d(:,:,tr);
	vAbsSlice = max(abs(slice(:)));

	fprintf('\nTrial %d: min=%.3f, max=%.3f, mean=%.3f, median=%.3f, vAbs=%.3f\n', ...
		tr, min(slice(:)), max(slice(:)), mean(slice(:),'omitnan'), median(slice(:),'omitnan'), vAbsSlice);
	fprintf('  fracNeg=%.3f, fracPos=%.3f\n', mean(slice(:)<0), mean(slice(:)>0));

	fh = figure('Color','w');
	fh.Units = 'centimeters';
	fh.Position(3:4) = [12, 8];
	imagesc(xsSec(xMask), 1:size(slice,1), slice);
	colormap(blueWhiteRed);
	clim([-vAbsSlice, vAbsSlice]);
	cb = colorbar; cb.FontSize = 6;
	xlabel('Time (s)'); ylabel('Cell (sorted by z@1s)');
	title(sprintf('PairA SessionK Trial%d  clim=[%.1f, %.1f]', tr, -vAbsSlice, vAbsSlice), 'FontSize', 8);
	set(gca, 'FontSize', 7);
	
	pngName = fullfile(outDirUNC, sprintf('diag_B_slice_trial%d_self.png', tr));
	exportgraphics(fh, pngName, 'Resolution', 200);
	fprintf('Wrote: %s\n', pngName);
	close(fh);
end

% -- 用全局范围 --
vAbsGlobal = max(abs(raw3d(:)));
fprintf('\n=== 全局范围 vAbsGlobal=%.3f ===\n', vAbsGlobal);

% -- 5个Trial拼图（统一全局clim，便于横向比较）--
nTrials = size(raw3d, 3);
trialPanel = unique(round(linspace(1, nTrials, 5)));
if numel(trialPanel) < 5
	allIdx = 1:nTrials;
	extra = allIdx(~ismember(allIdx, trialPanel));
	trialPanel = [trialPanel, extra(1:min(5-numel(trialPanel), numel(extra)))];
	trialPanel = sort(trialPanel);
end

fhPanel = figure('Color', 'w');
fhPanel.Units = 'centimeters';
fhPanel.Position(3:4) = [30, 8]; % 300 mm x 80 mm
tl = tiledlayout(fhPanel, 1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
for iT = 1:numel(trialPanel)
	tr = trialPanel(iT);
	nexttile(tl, iT);
	imagesc(xsSec(xMask), 1:size(raw3d,1), raw3d(:,:,tr));
	colormap(blueWhiteRed);
	clim([-vAbsGlobal, vAbsGlobal]);
	title(sprintf('Trial %d', tr), 'FontSize', 7);
	xlabel('Time (s)', 'FontSize', 6);
	if iT == 1
		ylabel('Cell (sorted)', 'FontSize', 6);
	else
		set(gca, 'YTickLabel', []);
	end
	set(gca, 'FontSize', 6);
end
cbp = colorbar;
cbp.Layout.Tile = 'east';
cbp.FontSize = 6;
title(tl, sprintf('PairA SessionK: 5 trial slices (global clim=[%.1f, %.1f])', -vAbsGlobal, vAbsGlobal), 'FontSize', 8);

pngPanel = fullfile(outDirUNC, 'diag_B_slice_5trials_global_panel.png');
exportgraphics(fhPanel, pngPanel, 'Resolution', 220);
fprintf('Wrote: %s\n', pngPanel);
close(fhPanel);

% -- 5个Trial直接堆成体素（Z轴=5 trials）--
vol5 = raw3d(:, :, trialPanel);
vol5Clamp = max(-vAbsGlobal, min(vAbsGlobal, vol5));
vol5Norm = 0.5 + 0.5 * (vol5Clamp / vAbsGlobal);
vol5Norm = max(0, min(1, vol5Norm));
vol5Norm(isnan(vol5Norm)) = 0.5;

figV5 = uifigure('Name', 'Volshow 5 Trials', 'Color', 'w', 'Position', [120 120 680 520]);
viewer5 = viewer3d(figV5, 'BackgroundColor', [1 1 1], 'BackgroundGradient', 'off');

nCellsHere = size(vol5, 1);
yScale = 1.0;
% 为了和原B脚本一致并公平比较，不按trial数量放大Z轴。
tform5 = affinetform3d(diag([2.5, yScale, 2.0, 1]));

alphaVec5 = repmat(0.04, nMap, 1);
volshow(single(vol5Norm), 'Parent', viewer5, ...
	'RenderingStyle', 'VolumeRendering', ...
	'Colormap', blueWhiteRed, ...
	'Alphamap', alphaVec5, ...
	'Transformation', tform5);

uilabel(figV5, 'Text', sprintf('Trials in volume: %s', mat2str(trialPanel)), ...
	'FontSize', 8, 'FontColor', [0.15 0.15 0.15], 'Position', [10, 38, 640, 18], 'BackgroundColor', 'none');
uilabel(figV5, 'Text', sprintf('Global clim = [%.1f, %.1f], alpha = 0.04', -vAbsGlobal, vAbsGlobal), ...
	'FontSize', 8, 'FontColor', [0.15 0.15 0.15], 'Position', [10, 18, 640, 18], 'BackgroundColor', 'none');

pause(1);
pngVol5 = fullfile(outDirUNC, 'diag_B_volshow_5trials_global.png');
exportapp(figV5, pngVol5);
fprintf('Wrote: %s\n', pngVol5);
close(figV5);

% -- 2个Trial直接堆成体素（与5-trial参数一致）--
trial2 = [trialPanel(1), trialPanel(end)];
vol2 = raw3d(:, :, trial2);
vol2Clamp = max(-vAbsGlobal, min(vAbsGlobal, vol2));
vol2Norm = 0.5 + 0.5 * (vol2Clamp / vAbsGlobal);
vol2Norm = max(0, min(1, vol2Norm));
vol2Norm(isnan(vol2Norm)) = 0.5;

figV2 = uifigure('Name', 'Volshow 2 Trials', 'Color', 'w', 'Position', [120 120 680 520]);
viewer2 = viewer3d(figV2, 'BackgroundColor', [1 1 1], 'BackgroundGradient', 'off');

% 为了和原B脚本一致并公平比较，不按trial数量放大Z轴。
tform2 = affinetform3d(diag([2.5, 1.0, 2.0, 1]));

alphaVec2 = repmat(0.04, nMap, 1);
volshow(single(vol2Norm), 'Parent', viewer2, ...
	'RenderingStyle', 'VolumeRendering', ...
	'Colormap', blueWhiteRed, ...
	'Alphamap', alphaVec2, ...
	'Transformation', tform2);

uilabel(figV2, 'Text', sprintf('Trials in volume: %s', mat2str(trial2)), ...
	'FontSize', 8, 'FontColor', [0.15 0.15 0.15], 'Position', [10, 38, 640, 18], 'BackgroundColor', 'none');
uilabel(figV2, 'Text', sprintf('Global clim = [%.1f, %.1f], alpha = 0.04', -vAbsGlobal, vAbsGlobal), ...
	'FontSize', 8, 'FontColor', [0.15 0.15 0.15], 'Position', [10, 18, 640, 18], 'BackgroundColor', 'none');

pause(1);
pngVol2 = fullfile(outDirUNC, 'diag_B_volshow_2trials_global.png');
exportapp(figV2, pngVol2);
fprintf('Wrote: %s\n', pngVol2);
close(figV2);

midTrial = round(size(raw3d,3)/2);
slice = raw3d(:,:,midTrial);

fh2 = figure('Color','w');
fh2.Units = 'centimeters';
fh2.Position(3:4) = [12, 8];
imagesc(xsSec(xMask), 1:size(slice,1), slice);
colormap(blueWhiteRed);
clim([-vAbsGlobal, vAbsGlobal]);
cb2 = colorbar; cb2.FontSize = 6;
xlabel('Time (s)'); ylabel('Cell (sorted by z@1s)');
title(sprintf('PairA SessionK Trial%d  global clim=[%.1f, %.1f]', midTrial, -vAbsGlobal, vAbsGlobal), 'FontSize', 8);
set(gca, 'FontSize', 7);

pngName2 = fullfile(outDirUNC, 'diag_B_slice_mid_global.png');
exportgraphics(fh2, pngName2, 'Resolution', 200);
fprintf('Wrote: %s\n', pngName2);
close(fh2);

% -- 分布直方图 --
fh3 = figure('Color','w');
fh3.Units = 'centimeters';
fh3.Position(3:4) = [12, 6];
histogram(raw3d(:), 300, 'FaceColor', [0.3 0.3 0.7], 'EdgeColor', 'none');
xlabel('z-score'); ylabel('Count');
title('All voxels distribution (entire volume)', 'FontSize', 8);
xline(0, 'r--', 'LineWidth', 1.5);
xlim([-20 20]); % zoom in to see bulk
pngName3 = fullfile(outDirUNC, 'diag_B_voxel_distribution.png');
exportgraphics(fh3, pngName3, 'Resolution', 200);
fprintf('Wrote: %s\n', pngName3);
close(fh3);

%% === Local functions (copied from B script) ===

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1; ok = false; return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
Stim = string(Tr.Stimulus);

TrLW = Tr(Stim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Phase','Performance','NBlocksInSession'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});

T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');

[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perfSess = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
nBlocks = splitapply(@numel, T.LWPerf, G2);
phase = splitapply(@(x) string(x(1)), T.Phase, G2);

Sess = table(mouse, dt, phase, perfSess, nBlocks, ...
	'VariableNames', {'Mouse','DateTime','Phase','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
Stim = string(Tr.Stimulus);
TrAW = Tr(Stim == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end

function SessSpeed = iSessionDeltaNext(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(Sess.Mouse);
nTotal = 0;
for mi = 1:numel(mice)
	R = Sess(Sess.Mouse == mice(mi), :);
	perf = double(R.Performance);
	use = isfinite(perf) & ~ismissing(R.DateTime);
	nTotal = nTotal + max(0, nnz(use) - 1);
end
outM = strings(nTotal, 1); outDT = NaT(nTotal, 1); outP = nan(nTotal, 1);
outDT2 = NaT(nTotal, 1); outP2 = nan(nTotal, 1); outDN = nan(nTotal, 1);
pos = 0;
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance); dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	perf = perf(use); dt = dt(use);
	if numel(perf) < 2, continue; end
	dn = diff(perf);
	n = numel(dn);
	idx = (pos+1):(pos+n);
	outM(idx) = repmat(m, n, 1);
	outDT(idx) = dt(1:end-1); outP(idx) = perf(1:end-1);
	outDT2(idx) = dt(2:end); outP2(idx) = perf(2:end);
	outDN(idx) = dn(:);
	pos = pos + n;
end
if pos < nTotal
	outM(pos+1:end)=[]; outDT(pos+1:end)=[]; outP(pos+1:end)=[];
	outDT2(pos+1:end)=[]; outP2(pos+1:end)=[]; outDN(pos+1:end)=[];
end
SessSpeed = table(outM, outDT, outP, outDT2, outP2, outDN, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end

function [uid, ntats, ntsRaw] = iSessionNTATS(DS, dt)
T = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
if isempty(T)
	uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return;
end
des = unique(string(T.Design));
des = des(~ismissing(des));
if numel(des) ~= 1
	uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return;
end
G = DS.QueryNTS(struct('DateTime', dt, 'Stimulus', 'LightWater', 'Design', char(des(1))), ...
	UniExp.Flags.ZScore, 1:24);
if isempty(G), uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return; end
if iscell(G), G = G{1}; end
if isempty(G), uid = uint64.empty(0,1); ntats = []; ntsRaw = []; return; end
cellUIDs = uint64(G.CellUID);
trialUIDs = uint64(G.TrialUID);
if isa(G.TrialSignal, 'MATLAB.DataTypes.NDTable')
	ntsAll = double(G.TrialSignal.Data);
else
	ntsAll = double(G.TrialSignal);
end
uid = unique(cellUIDs, 'stable');
tids = unique(trialUIDs, 'stable');
nCells = numel(uid); nTrials = numel(tids); nTime = size(ntsAll, 2);
ntats = nan(nCells, nTime);
ntsRaw = nan(nCells, nTime, nTrials);
for ic = 1:nCells
	rowsC = (cellUIDs == uid(ic));
	ntats(ic, :) = median(ntsAll(rowsC, :), 1, 'omitnan');
	for it = 1:nTrials
		rowsCT = rowsC & (trialUIDs == tids(it));
		if any(rowsCT)
			ntsRaw(ic, :, it) = mean(ntsAll(rowsCT, :), 1, 'omitnan');
		end
	end
end
end
