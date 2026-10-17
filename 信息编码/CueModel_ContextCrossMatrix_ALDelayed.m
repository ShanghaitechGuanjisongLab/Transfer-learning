%% CueModel_ContextCrossMatrix_ALDelayed.m
% ALDelayed（有延迟不舔不给水钙成像，声水转光水，延迟任务）上下文交叉解码矩阵（3x3）。
% 注：Always（总是给水）回合不参与分析。
% 模仿 信息编码/CueModel_ContextCrossMatrix.m（AudioLightBaseline 4x4）的解码口径：
% - 每 trial 取 pre/post 窗均值训练 pre(0)/post(1) 逻辑回归解码器
%   （TransferLearning.DecodeCuePrePostTransfer，Fig3D 规则）；
% - 对角线：训练域内 5-fold trial-aware OOF 自测；
% - 非对角：行上下文训练后直接读出列上下文（不重训）；
% - 训练标签置换（200 次）生成 null95。
%
% 上下文（实验时间线：预训练 → 声水学习 → 光水迁移；全部含 cue）：
%   Audio only  = AudioPreTrainCueOnly   （预训练声 cue-only，对应原图 AO）
%   Audio-water = AudioLearnWater        （声水学习，延迟期舔才给水）
%   Light-water = LightLearnWater        （光水迁移，延迟期舔才给水）
%   AudioLearnWaterAlways / LightLearnWaterAlways（总是给水）不参与分析；
%   AudioPreTrainWaterOnly 无 cue（同原图排除 WaterOnly 的理由），不解码。
%
% 时间窗（延迟任务：反应/名义给水 = cue +1.5 s，用户要求时间范围 [-1.5, 1.5] s）：
%   pre = -1.5..0 s，post = 0..1.5 s，读出网格 [-1.5, 1.5] s。
%
% 块排除（同原图口径：MustWarn 块跳过）。本库 4 个被标记块：BlockUID 7「后来电脑蓝屏」
% 与 3 个缺 Design 块「标通道没打上」「没拍」×2。
% 细胞集合：每鼠三个上下文的交集（注册全会话共享；yqn2200/2201/2202/2203 约
% 504/783/344/635 个）。
%
% 输出：
% - CueModel_ContextCrossMatrix_ALDelayed_Results.mat（缓存，经 TransferLearning.CachePath
%   存到数据服务器个人缓存目录，不在代码工作区内、不被 git 追踪）
%
% 执行：
% - 保持脚本形态（不要改 function）。
% - 在 MATLAB Editor 里运行。

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
rng(42);

DS = TransferLearning.ALDelayed();
dsName = 'ALDelayed (delayed task, water at cue+1.5 s)';
xs = TransferLearning.Xs;
if isduration(xs)
	xs = seconds(xs);
end
tPre = (xs >= -1.5) & (xs <= 0);
tPost = (xs >= 0) & (xs <= 1.5);
tIdxFull = find((xs >= -1.5) & (xs <= 1.5));
tVec = xs(tIdxFull);
nT = numel(tVec);
NPERM = 200;
ctxStim = ["AudioPreTrainCueOnly", "AudioLearnWater", "LightLearnWater"];
ctxShort = ["AO", "AW", "LW"];
ctxLabel = ["Audio only", "Audio-water", "Light-water"];
nCtx = numel(ctxStim);
fprintf('=== CueModel 3x3 cross-context matrix (%s) ===\n', dsName);
fprintf('Pre: %.2f-%.2fs  Post: %.2f-%.2fs  | read-out grid: %d pts (%.2f-%.2f s)  | permutations: %d\n', ...
	xs(find(tPre, 1)), xs(find(tPre, 1, 'last')), xs(find(tPost, 1)), xs(find(tPost, 1, 'last')), ...
	nT, tVec(1), tVec(end), NPERM);

%% 1. 块质量标记（同原图口径：MustWarn 块跳过）
Blk = DS.Blocks;
Blk.MustWarn = string(Blk.MustWarn);
nFlag = ~ismissing(Blk.MustWarn) & strlength(Blk.MustWarn) > 0;
warnedUID = uint64(Blk.BlockUID(nFlag));
fprintf('Blocks: %d total, %d flagged (skipped): %s\n', height(Blk), sum(nFlag), ...
	strjoin(unique(Blk.MustWarn(nFlag)), '; '));

%% 2. Per-mouse trial data -> one task per matrix row
T = DS.TableQuery(["Mouse", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T = T(ismember(T.Stimulus, ctxStim), :);
if isempty(T)
	error('CueModel_ALDelayed:NoTrial', 'No trials found for %s.', strjoin(ctxStim, ','));
end
mice = unique(T.Mouse)';

tasks = {};
meta = {};
for m = mice
	X = cell(nCtx, 1);
	nTr = zeros(nCtx, 1);
	cellSets = cell(nCtx, 1);
	for k = 1:nCtx
		tab = TransferLearning.QueryZScoreNts(DS, m, ctxStim(k));
		if isempty(tab)
			continue;
		end
		tab = tab(~ismember(uint64(tab.BlockUID), warnedUID), :);
		tab = tab(~isnan(tab.Behavior), :);
		if isempty(tab)
			continue;
		end
		[X{k}, ~, cellSets{k}] = iToTrialCellTime(tab);
		if isempty(X{k})
			continue;
		end
		nTr(k) = size(X{k}, 1);
	end
	if any(cellfun(@isempty, X))
		continue;
	end

	cu = cellSets{1};
	for k = 2:nCtx
		cu = intersect(cu, cellSets{k});
	end
	if numel(cu) < 5
		continue;
	end
	for k = 1:nCtx
		X{k} = iKeepCells(X{k}, cellSets{k}, cu);
	end

	for r = 1:nCtx
		TaskRow = struct('DS', r, 'Mouse', char(m), 'NCells', numel(cu), 'CellUIDs', cu, ...
			'XTrT', X{r}(:, :, tIdxFull), ...
			'preTr', mean(X{r}(:, :, tPre), 3), ...
			'postTr', mean(X{r}(:, :, tPost), 3));
		c = setdiff(1:nCtx, r);
		Te = struct('Name', "", 'preTe', [], 'postTe', [], 'XTeT', [], 'nTe', 0);
		Te = repmat(Te, numel(c), 1);
		for j = 1:numel(c)
			Te(j) = iTestEntry(char(ctxShort(c(j))), X{c(j)}, tPre, tPost, tIdxFull);
		end
		TaskRow.Tests = Te;
		tasks{end + 1} = TaskRow; %#ok<AGROW>
		meta{end + 1} = struct('Row', r, 'Mouse', char(m), 'Cells', numel(cu), ...
			'Cols', {c}, 'nTr', nTr(r), 'nTe', {[Te.nTe]}); %#ok<AGROW>
	end
	fprintf('%-9s cells=%d | %s %dt | %s %dt |\n', m, numel(cu), ...
		ctxShort(1), nTr(1), ctxShort(2), nTr(2));
end
fprintf('Decodable mice: %d -> %d matrix rows to decode\n', numel(meta) / nCtx, numel(tasks));
if isempty(tasks)
	error('CueModel_ALDelayed:NoTask', 'No decodable mice after filtering.');
end

%% 2. Decode
res = cell(numel(tasks), 1);
parfor i = 1:numel(tasks)
	rng(42 + i);
	res{i} = TransferLearning.DecodeCuePrePostTransfer(tasks{i}, tVec, NPERM);
end
clear tasks;
fprintf('Decoding done (%s)\n', char(datetime('now', 'Format', 'HH:mm:ss')));

%% 3. Assemble matrix
mouseNames = unique(string(cellfun(@(M) M.Mouse, meta, 'UniformOutput', false)), 'stable');
nM = numel(mouseNames);
accM = nan(nCtx, nCtx, nM);
curves = cell(nCtx, nCtx);
nulls = cell(nCtx, nCtx);
nTeCell = nan(nCtx, nCtx, nM);
for i = 1:numel(res)
	R = res{i};
	M = meta{i};
	im = find(mouseNames == string(R.Mouse), 1);
	r = M.Row;
	accM(r, r, im) = R.s1Acc;
	curves{r, r} = iPutCurve(curves{r, r}, im, R.pPostS1T);
	nulls{r, r} = iPutCurve(nulls{r, r}, im, R.null95S1);
	nTeCell(r, r, im) = R.nTr;
	for j = 1:numel(R.Tests)
		K = R.Tests(j);
		c = find(ctxShort == K.name, 1);
		accM(r, c, im) = K.acc;
		curves{r, c} = iPutCurve(curves{r, c}, im, K.pPostByT);
		nulls{r, c} = iPutCurve(nulls{r, c}, im, K.null95);
		nTeCell(r, c, im) = K.nTe;
	end
end

%% 4. Summary + save
fprintf('\n=== Group means (rows=train, cols=read-out) ===\n');
fprintf('%-18s', 'train \ read');
for c = 1:nCtx
	fprintf('%-32s', ctxLabel(c));
end
fprintf('\n');
for r = 1:nCtx
	fprintf('%-16s', char(ctxLabel(r)));
	for c = 1:nCtx
		v = squeeze(accM(r, c, :));
		v = v(isfinite(v));
		fprintf('%-32s', sprintf('%.3f +/- %.3f (n=%d)', mean(v), iSem(v), numel(v)));
	end
	fprintf('\n');
end

save(TransferLearning.CachePath('CueModel_ContextCrossMatrix_ALDelayed_Results.mat'), ...
	'res', 'meta', 'dsName', 'tVec', 'NPERM', 'ctxStim', 'ctxShort', 'ctxLabel', ...
	'accM', 'curves', 'nulls', 'nTeCell', 'mouseNames');
fprintf('\nSaved CueModel_ContextCrossMatrix_ALDelayed_Results.mat\n');
fprintf('Next: run 英文图/FigS2D_Delayed_ContextCrossMatrix.m\n');

%% ========== local functions ==========
function Te = iTestEntry(name, X, tPre, tPost, tIdxFull)
Te = struct('Name', name, ...
	'preTe', mean(X(:, :, tPre), 3), ...
	'postTe', mean(X(:, :, tPost), 3), ...
	'XTeT', X(:, :, tIdxFull), ...
	'nTe', size(X, 1));
end

function C = iPutCurve(C, iRow, v)
if isempty(C) || size(C, 1) < iRow
	C(iRow, 1:numel(v)) = NaN;
end
C(iRow, :) = v(:)';
end

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function [X, trialUIDs, cellUIDs] = iToTrialCellTime(T)
X = [];
trialUIDs = uint64([]);
cellUIDs = uint64([]);
if isempty(T)
	return;
end
trialUIDs = unique(uint64(T.TrialUID), 'stable');
cellUIDs = unique(uint64(T.CellUID), 'stable');
nTr = numel(trialUIDs);
nCell = numel(cellUIDs);
nTime = size(T.TrialSignal, 2);
if nTr < 2 || nCell < 1 || nTime < 1
	return;
end
X = nan(nTr, nCell, nTime);
for iC = 1:nCell
	cid = cellUIDs(iC);
	rows = uint64(T.CellUID) == cid;
	u = uint64(T.TrialUID(rows));
	sig = double(T.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, u);
	if ~all(tf) || any(~isfinite(sig(loc, :)), 'all')
		X(:, iC, :) = NaN;
		continue;
	end
	X(:, iC, :) = sig(loc, :);
end
badCell = squeeze(any(any(~isfinite(X), 3), 1));
X(:, badCell, :) = [];
cellUIDs(badCell) = [];
end

function X2 = iKeepCells(X, allCells, keepCells)
[tf, loc] = ismember(uint64(keepCells), uint64(allCells));
if ~all(tf)
	error('CueModel_ALDelayed:CellAlign', 'Cell intersection alignment failed.');
end
X2 = X(:, loc, :);
end
