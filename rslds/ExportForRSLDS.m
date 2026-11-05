%% ExportForRSLDS.m — 把每个 block 的连续信号导出为 Python 可读的 .mat（v7.3 / HDF5）
%
% 为什么需要这个脚本
%   下一步要用 Python 的 `ssm` 拟合 rSLDS（循环切换线性动力系统）。MATLAB 侧只负责把
%   **原始连续信号**搬出去：任何预处理（漂白去趋势、z-score、因子分析降维）都留在 Python 侧，
%   这样扫预处理方案时不必回头改 MATLAB 代码、也不必反复从数据库取数。
%
% 导出内容（每个 block 一个文件，v7.3 = HDF5）
%   X        single, nCell × nSamp —— 原始钙荧光（**未** z-score、**未**去趋势）
%   CellUID  uint32, nCell × 1
%   zLayerCode uint8, nCell × 1  —— 1=MOp2/3, 2=MOp5, 3=L2（名称见 zLayerNamesCSV）
%   CD1      single, 1 × nSamp     —— cue 标记通道（`Blocks.BlockTags.CD1`）
%   CD2      single, 1 × nSamp     —— 舔水通道（`Blocks.BlockTags.CD2`）
%   idx*     uint32, 1 × n      —— 各类事件的**样本下标**（1 基），已换算到导出后的格点
%   stimCode uint8, 1 × nCue    —— **每个 cue 的刺激类型**（与 idxCue 逐元素对齐）
%   stimNamesCSV               —— stimCode 的名称表（逗号分隔的 char）
%   evCode / evNamesCSV        —— 事件编码与其名称表（逗号分隔的 char）
%   fs, durSec, nCell, nSamp, nSamp0, decimK, cellFiniteFrac, probe
%   mustWarn / performance / blockRI  —— 块级 QC 与重复序号
%   Mouse / Phase / Design / DateTimeISO / blockUID / Cohort
%
% ⚠ idxCue 与 stimCode 的同步
%   两者**必须由同一个 keep 掩膜派生**（见 §2 内注释）。旧版 idxCue 是"过滤后再丢弃掩膜"的，
%   若 stimCode 直接按 trSel 全行生成就会错位。现版本显式保留 keepT 并同时用于两者。
%   被 keepT 剔除的：Tag 非有限、Tag 越界、Stimulus 缺失（实测 47 个）、
%   StartMonitor/StopMonitor 伪 trial（实测 34 个，其 Tag 本就无效）。
%
% ⚠ 为什么要降采样
%   本项目 112 个 block 里有 12 个是 ≈30 Hz（其余 ≈8 Hz）。跨 block 比较时采样率不一致
%   会引入混淆，且 30 Hz 的 block 拟合要多花 4 倍算力（本机无 GPU）。故统一降到 ≈8 Hz：
%   取整数因子 `k = round(fs0/8)`，抽取前用窗长 k 的 `movmean` 抗混叠（钙信号带宽远低于
%   4 Hz，足够）。30 Hz → k = 4 → 7.5 Hz。逐 block 记录真实 `fs`，调用方按 `fs` 解释时间。
%
% ⚠ Python 读取方向（v7.3 是列主序，这是最容易踩的坑）
%   MATLAB 数组 A(m,n) 写进 HDF5 后，`h5py['X'][:]` 的形状是 **(n, m)**，内容等于 A'。
%   即 `h5py['X'][:]` 直接给出 **(时间 × 细胞)** 矩阵 —— 正是建模要的方向。
%   文件里的 `probe = [X(1,1) X(1,end) X(end,1) X(end,end)]` 用来把方向钉死：
%   若 `A = f['X'][:]`，应满足 A[0,0]=probe[0]、A[0,-1]=probe[1]、A[-1,0]=probe[2]、
%   A[-1,-1]=probe[3]。`rslds/CheckExport.py` 会做这个往返校验。
%
% 1) 依赖：MATLAB R2023b+，本项目 +TransferLearning 包（`AlignBlockMeta`、`BlockSampleRate`）
% 2) 前置：`TransferLearning.AudioLightBaseline()` 或 `TransferLearning.THInhibit()`；
%          可在 base 工作区覆盖队列：`ExportCohort = "TH";`、试跑块数 `ExportLimit = 2;`
% 3) 图注：本脚本**不出图**，只产出数据文件与 manifest 表
% 4) 代码

%% 0. 参数
targetFs    = 8;                % 目标采样率（Hz），实际取最接近的整数抽取因子
skipPhase   = "Recall";         % 跳过的阶段；Recall 是回忆测试，任务结构与学习序列不可比
outRoot     = fullfile(fileparts(mfilename('fullpath')), 'data');

%% 1. Setup
if ~exist('ExportCohort', 'var'); ExportCohort = "ALB"; end
if ~exist('ExportLimit', 'var'); ExportLimit = Inf; end
% 只导 `ExportPhases` 里的阶段；空 = 不筛（导全部非 Recall 的 block）
if ~exist('ExportPhases', 'var'); ExportPhases = strings(1, 0); end
% 只导 `B` 行号落在 [lo, hi] 的 block。单次 MCP 调用很久会超时，故分块跑
if ~exist('ExportRange', 'var'); ExportRange = [1, Inf]; end
% 只导这些 BlockUID（非空时逐块筛）——用于"只导 Naive 光水的那一个会话"这类精选取
if ~exist('ExportBlockUIDs', 'var'); ExportBlockUIDs = uint32([]); end
% 只导这些鼠（string 数组）；空 = 不筛。用于"只取 LAB 里 naive 设计为 LightWater 的 4 只"
if ~exist('ExportMice', 'var'); ExportMice = strings(1, 0); end
thisDir = fileparts(mfilename('fullpath'));
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end

switch ExportCohort
	case "TH"; DS = TransferLearning.THInhibit();
	case "LightAudioBaseline"; DS = TransferLearning.LightAudioBaseline();
	case "LAInterspersed"; DS = TransferLearning.LAInterspersed();
	otherwise;  DS = TransferLearning.AudioLightBaseline();
end
B = DS.Blocks; BS = DS.BlockSignals; DT = DS.DateTimes;
outDir = fullfile(outRoot, char(ExportCohort));
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('=== ExportForRSLDS：队列 %s，%d 个 block ===\n', ExportCohort, height(B));
[bMouse, bPhase, bDesign] = TransferLearning.AlignBlockMeta(B, DT);
fs0 = TransferLearning.BlockSampleRate(DS, B, bMouse);
fprintf('采样率分布：%s\n', mat2str(unique(round(fs0, 2))'));
fprintf('输出目录：%s\n\n', outDir);

%% 2. 逐 block 导出
rows = {};
nDone = 0;
for i = 1:height(B)
	if nDone >= ExportLimit; break; end
	if i < ExportRange(1) || i > ExportRange(2); continue; end
	if bMouse(i) == ""; continue; end
	if ~isempty(ExportMice) && ~ismember(bMouse(i), string(ExportMice)); continue; end
	if bPhase(i) == skipPhase; continue; end
	if ~isempty(ExportPhases) && ~ismember(bPhase(i), ExportPhases); continue; end

	uid = B.BlockUID(i);
	if ~isempty(ExportBlockUIDs) && ~ismember(uid, ExportBlockUIDs); continue; end
	rowIdx = find(BS.BlockUID == uid);
	if isempty(rowIdx); continue; end

	[X, CellUID] = iCellMatrix(BS, rowIdx);
	if isempty(X); continue; end
	[nCell, nSamp0] = size(X);

	% 模拟通道：与钙**同格**（长度必须完全一致），否则整块丢弃
	bt = B.BlockTags{i};
	if ~istable(bt) || height(bt) ~= nSamp0; continue; end
	vn = string(bt.Properties.VariableNames);
	if ~all(ismember(["CD1", "CD2"], vn)); continue; end
	CD1 = single(bt.CD1(:)');
	CD2 = single(bt.CD2(:)');

	% 事件下标（1 基，块内样本号）
	[evSample, evCode, evNamesCSV] = iEventIdx(DS, B, i, nSamp0, fs0(i));
	if isempty(evSample)
		warning('block %d（%s %s）没有可用事件时间', i, bMouse(i), bPhase(i));
	end

	% 整点抽取到 ≈ targetFs
	decimK = uint8(max(1, round(fs0(i) / targetFs)));
	k = double(decimK);
	if k > 1
		X   = single(iDecim(double(X),   k));
		CD1 = single(iDecim(double(CD1), k));
		CD2 = single(iDecim(double(CD2), k));
		evSample = uint32(round(double(evSample) / k));
		nSamp = size(X, 2);
		keep = evSample >= 1 & evSample <= nSamp;
		evSample = evSample(keep);
		evCode   = evCode(keep);
	else
		nSamp = nSamp0;
	end
	fs = fs0(i) / k;

	% 元数据
	Mouse = char(bMouse(i));
	Phase = char(bPhase(i));
	Design = char(bDesign(i));
	DateTimeISO = char(string(B.DateTime(i), 'yyyy-MM-dd''T''HH:mm:ss'));
	blockUID = uint32(uid);
	Cohort = char(ExportCohort);
	durSec = nSamp / fs;
	cellFiniteFrac = single(mean(isfinite(X), 2));
	probe = single([X(1,1), X(1,end), X(end,1), X(end,end)]);

	% 事件按名称拆开存（名称表只切一次）
	evNameList = split(evNamesCSV, ',');
	idxGiveWater  = evSample(evCode == find(evNameList == "给水"));
	idxHit        = evSample(evCode == find(evNameList == "命中"));
	idxMiss       = evSample(evCode == find(evNameList == "错失"));
	idxTrialStart = evSample(evCode == find(evNameList == "回合开始"));
	idxSoundOn    = evSample(evCode == find(evNameList == "声音响"));
	idxLightOn    = evSample(evCode == find(evNameList == "灯光亮"));

	% 权威 cue 帧号：来自 Trials.SampleRange.Tag（每个 trial 在连续信号里的样本下标，
	% 实测与 CD1 上升沿完全一致）。EventLog 派生下标**不可**用于对齐钙数据
	% （数据库由成像记录与行为学记录合并，二者时钟逐会话不同，详见笔记"时间基陷阱"）。
	% stimCode 必须与 idxCue **由同一个 keepT 掩膜派生**，否则两者错位。
	trSel = DS.Trials.BlockUID == uid;
	trRows = find(trSel);
	idxCue = zeros(0, 1, 'uint32');
	stimCode = zeros(0, 1, 'uint8');
	stimNamesCSV = '';
	if ~isempty(trRows)
		stim = string(DS.Trials.Stimulus(trRows));
		stim = stim(:);
		tag = nan(numel(trRows), 1);
		if ismember('SampleRange', DS.Trials.Properties.VariableNames)
			sr = DS.Trials.SampleRange(trRows, :);
			if istable(sr) && ismember('Tag', sr.Properties.VariableNames)
				tag = double(sr.Tag(:));
			end
		end
		tag = round(tag / k);          % 与 X 同格
		keepT = isfinite(tag) & tag >= 1 & tag <= nSamp ...
			& ~ismissing(stim) ...
			& ~ismember(stim, ["StartMonitor", "StopMonitor"]);
		idxCue = uint32(tag(keepT));
		stimKeep = stim(keepT);
		if isempty(stimKeep)
			stimCode = zeros(0, 1, 'uint8');
		else
			[stimNames, ~, icStim] = unique(stimKeep);
			stimNames = string(stimNames(:))';
			stimCode = uint8(icStim(:));
			stimNamesCSV = char(strjoin(cellstr(stimNames), ','));
		end
	end

	% 每细胞的 ZLayer（编码 1=MOp2/3, 2=MOp5, 3=L2；名称表固定写在 zLayerNamesCSV）
	zLayerKey = ["MOp2/3", "MOp5", "L2"];
	zLayerNamesCSV = char(strjoin(cellstr(zLayerKey), ','));
	zLayerCode = zeros(numel(CellUID), 1, 'uint8');
	[cellsOK, locCell] = ismember(double(CellUID), double(DS.Cells.CellUID));
	if any(cellsOK)
		zl = string(DS.Cells.ZLayer(locCell(cellsOK)));
		for jz = 1:numel(zLayerKey)
			hitZ = (zl == zLayerKey(jz));
			tmp = zLayerCode(cellsOK);
			tmp(hitZ) = uint8(jz);
			zLayerCode(cellsOK) = tmp;
		end
	end

	% 块级 QC / 序号
	% ⚠ 必须转成 char 再存：MATLAB 的 string 对象在 v7.3 里存成 uint32 引用结构
	% （MATLAB_class='string'），Python 侧无法直接解码。char 才是 uint16 码元。
	mwStr = string(B.MustWarn(i));
	if ismissing(mwStr); mwStr = ""; end
	mustWarn = char(mwStr);
	performance = double(B.Performance(i));
	blockRI = uint8(B.BlockRI(i));

	fName = sprintf('%s_%s_%s_%s.mat', char(ExportCohort), Mouse, ...
		char(string(B.DateTime(i), 'yyyyMMdd-HHmm')), Design);
	fPath = fullfile(outDir, fName);
	save(fPath, 'X', 'CellUID', 'zLayerCode', 'zLayerNamesCSV', 'CD1', 'CD2', 'fs', 'durSec', ...
		'nCell', 'nSamp', 'nSamp0', 'decimK', 'cellFiniteFrac', 'probe', 'evSample', 'evCode', ...
		'evNamesCSV', 'idxGiveWater', 'idxHit', 'idxMiss', 'idxTrialStart', ...
		'idxSoundOn', 'idxLightOn', 'idxCue', 'stimCode', 'stimNamesCSV', ...
		'mustWarn', 'performance', 'blockRI', 'Mouse', 'Phase', 'Design', 'DateTimeISO', ...
		'blockUID', 'Cohort', '-v7.3');

	nDone = nDone + 1;
	rows(end+1, :) = {fName, Mouse, Phase, Design, DateTimeISO, fs, durSec, ...
		nCell, mean(cellFiniteFrac), min(cellFiniteFrac), numel(idxGiveWater), ...
		numel(idxCue), numel(unique(stimCode)), performance, mustWarn}; %#ok<SAGROW>
	fprintf('[%3d] %-44s %-9s %-11s fs=%5.2f %5.1fmin nC=%3d cue=%3d stim=%d perf=%.2f %s\n', ...
		i, fName, Mouse, Phase, fs, durSec/60, nCell, numel(idxCue), ...
		numel(unique(stimCode)), performance, mustWarn);
end

%% 3. manifest
man = cell2table(rows, 'VariableNames', {'file', 'mouse', 'phase', 'design', ...
	'datetime', 'fsHz', 'durSec', 'nCell', 'cellFiniteFracMean', 'cellFiniteFracMin', ...
	'nGiveWater', 'nCue', 'nStimTypes', 'performance', 'mustWarn'});
man.durMin = man.durSec / 60;
man.durSec = [];
manFile = fullfile(outDir, "manifest_" + ExportCohort + ".csv");
writetable(man, manFile, 'Encoding', 'UTF-8');
fprintf('\n=== 本次导出：%d 个 block（行号区间 %d~%d）===\n', height(man), ExportRange(1), ExportRange(2));
fprintf('manifest：%s\n', manFile);
fprintf('时长合计 %.1f h；细胞数 中位 %d（%d~%d）\n', sum(man.durMin)/60, ...
	round(median(man.nCell)), min(man.nCell), max(man.nCell));
fprintf('散落 NaN 的 block（有细胞非全程有限）：%d 个\n', sum(man.cellFiniteFracMin < 1));
fprintf('\n⚠ 下一步在 Python 侧跑往返校验（会核对 probe，把矩阵方向钉死）：\n');
fprintf('   .venv\\Scripts\\python rslds\\CheckExport.py\n');
fprintf('\nDone.\n');

%% ===== Local functions =====
function [X, cellUID] = iCellMatrix(BS, rowIdx)
% 取一个 block 的 细胞×时间 矩阵（single）。长度与首个细胞不一致的细胞整行丢弃。
% 返回 [] 的条件：没有可用细胞。
nSamp = numel(BS.BlockSignal{rowIdx(1)});
M = nan(numel(rowIdx), nSamp, 'single');
uid = zeros(numel(rowIdx), 1, 'uint32');
keep = false(numel(rowIdx), 1);
for i = 1:numel(rowIdx)
	v = double(BS.BlockSignal{rowIdx(i)});
	if numel(v) ~= nSamp; continue; end
	M(i, :) = single(v(:)');
	uid(i) = uint32(BS.CellUID(rowIdx(i)));
	keep(i) = true;
end
X = M(keep, :);
cellUID = uid(keep);
if isempty(X); X = []; cellUID = []; end
end

function [evSample, evCode, evNamesCSV] = iEventIdx(DS, B, iB, nSamp, fs0)
% 事件样本下标（1 基，块内样本号）。
%   · 时间源 = `Blocks.EventLog{iB}` 的 timetable 行时间。**实测 112/112 个 block 的
%     `RowTimes` 都是 duration**（块内已流逝秒数，最大 ~1720 s，与 20~30 min 的块长吻合），
%     不是绝对 datetime，故直接 `seconds()` 即可，不要再减 `B.DateTime`。
%   · cue 起点另有权威来源 `Trials.SampleRange.Tag`（实测与 `CD1` 上升沿完全一致），
%     本函数只把 `EventLog` 的"回合开始"收进来，不做交叉校验。
evNames = ["回合开始", "声音响", "灯光亮", "给水", "命中", "错失"];
evSample = zeros(0, 1); evCode = zeros(0, 1, 'uint8');
t = zeros(0, 1); c = zeros(0, 1, 'uint8');

el = B.EventLog{iB};
if istimetable(el) && ismember('Event', el.Properties.VariableNames)
	rt = el.Properties.RowTimes;
	assert(isduration(rt), 'Blocks.EventLog{%d} 的时间轴不是 duration', iB);
	tt = seconds(rt);
	eva = string(el.Event);
	for j = 1:numel(evNames)
		sel = find(eva == evNames(j));
		t = [t; tt(sel)]; %#ok<AGROW>
		c = [c; repmat(uint8(j), numel(sel), 1)]; %#ok<AGROW>
	end
end
if ~isempty(t)
	idx = round(t * fs0) + 1;
	ok = idx >= 1 & idx <= nSamp;
	t = idx(ok); c = c(ok);
end
evSample = uint32(t); evCode = c;
evNamesCSV = char(strjoin(evNames, ','));
end

function Y = iDecim(X, k)
% 按整数因子 k 整点抽取：先窗长 k 的均值抗混叠，再每 k 个取最后一个样本。
% 保留的原始样本号是 k, 2k, ...；故原始样本 j 对应的新下标是 round(j/k)。
if k <= 1; Y = X; return; end
Y = movmean(X, k, 2, 'omitnan');
Y = Y(:, k:k:end);
end
