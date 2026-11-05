% 阶段演进群体轨迹 PCA（cue 后 0–8 s）：4 行 × 4 列
%   行1 = ALB（声→光，AudioLightBaseline，无间隔）
%   行2 = TH （声→光，THInhibit，丘脑抑制组）
%   行3 = V7 （声→光，Vacation7，声水学会后停训 7.5–16.1 d 再转光水）
%   行4 = LAB（光→声，LightAudioBaseline）
%   列 = Naive → Learned → Transfer → Final
%
% 阶段口径（用户 2026-10-31 指定）：
%   Naive    = 该阶段"训练线索"的首个学习会话
%              ALB / TH / V7: Phase=="Naive" 且含 AudioWater 的最早会话（首个声水学习场）
%              LAB: Phase=="Naive" 且含 LightWater 的最早会话（首个光水学习场，沿用英文图1D 口径）
%   Learned  = Phase=="Learned" 的会话（学会后），线索同上（ALB/TH/V7: AW / LAB: LW）
%   Transfer = Phase=="Transfer" 的最早会话，换到新线索（ALB/TH/V7: LightWater / LAB: AudioWater）
%   Final    = Phase=="Final" 的会话（迁移后巩固，线索同 Transfer）
%   ⇒ 每只鼠必须四个阶段齐全才纳入（ALB n=10，TH n=5，V7 n=6，LAB n=5）。
%
% 时间窗：cue 上升沿后 0–8 s。
%   ⚠ 库内 TrialSignals 只保留 cue ±3 s（TrialSignal 49 帧 / ResampledSignal 48 帧），
%     取不到 8 s，QueryNTS 也只能给 48 帧。因此本脚本直接从 BlockSignals（每细胞每 block
%     的连续迹，帧周期 = DateTimes.SeriesInterval）按 Trials.SampleRange.Tag
%     （= cue 在 block 内的帧下标，已验证与 CD1 上升沿一致，差 ≤1 帧）截窗。
%   ⚠ 实测 ResampledSignal 与 TrialSignal（Tag±3 s 原窗）并不是同一时轴：前 1/3 相关 0.98、
%     后 1/3 仅 0.38（被拉伸/重采样过），故本脚本不依赖 ResampledSignal，全部从 BlockSignals 重算。
%
% 归一化：逐回合 z-score，mu = cue 前 3 s 基线均值；sd = max(基线段 sd, 0.5×全 block sd)，
%   后者防止基线异常平坦 / 慢漂移大的细胞把 z 除到爆炸（正常细胞两值接近，≈标准 z-score）。
%   基线取 cue 前 24 帧，与 QueryNTS 的 F0Samples 1:24 同口径。
% 剔除：cue 未检出（Tag=0）或 0–8 s 窗超出 block 末尾的回合整回合剔除（只剔回合，不剔细胞）。
% 细胞：只取 ZLayer=="MOp2/3"（同英文图1D / FigS2A；改 LayerKeep 可切换）。
% 超鼠口径：每细胞把该阶段全部回合按 TrialUID 顺序尽量均分成 nLines 组（组间最多差 1 回合），
%   组内平均 → 每细胞 nLines 条轨迹；再跨鼠汇总。
% PCA：同一行（同一数据集）4 个阶段**合并拟合一次**，于是 4 个 tile 共用同一 PC 空间，
%   可以直接看"轨迹形态/幅度随阶段如何演变"；轴标签给出该行 PC1/PC2 的解释方差。
%   行内 4 个 tile 统一轴跨度（UnifyAxesLims 的 Range 模式）。
% 着色：线内时间渐变（cue 端近白 → 8 s 端为阶段色）；
%   阶段色：Naive=NaiveColor(紫) / Learned=ColorA(近黑) / Transfer=TransferColor(橙) / Final=ColorB(绿)。
%
% Outputs (SVG):
%   - English_PCA_StageProgression_4cohorts_0to8s_rowscale.svg
%   - English_PCA_StageProgression_4cohorts_0to8s_tilescale.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

% ---------- 可调参数 ----------
nLines   = 10;            % 每细胞把回合平均成多少条轨迹
LayerKeep = "MOp2/3";     % 细胞层筛选；置为 "" 则不筛选
tWin      = [0, 8];       % 分析窗（cue 后，秒）
tBase     = [-3, 0];      % z-score 基线窗（cue 前，秒）
nOut      = 65;           % 重采样后时间点数（0:0.125:8）
nGradSeg  = nOut - 1;     % 线内渐变分段数：必须 ≥ nOut-1，否则折线顶点少于采样点 → 出现折角
% 仅供显示的帧平滑（0/1 = 不平滑）。PCA 本身永远用未平滑数据；
% tile 版把局部放大后帧间捣动会很明显（实测二阶差分 std 占跨度 1–7%），觉得脏就设 3（0.375 s）。
SmoothFrames = 1;   % 仅显示：0/1 = 不平滑（实测 3 帧平滑几乎改变不了观感，帧间捣动是真实的 ~1–2 Hz 群体涨落）
% 输出版本（一次生成两张图）：
%   "row"  = 一行 4 块共用同一 xlim/ylim ⇒ 行内位置/幅度可直接比
%   "tile" = 每块按自己的轨迹自适应 ⇒ 每个阶段的形状得到最大展现，但子图间不可比
AxisModes = ["row", "tile"];
ExportSvg = true;

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
addpath(fullfile(thisDir, '..'));

stageNames  = ["Naive", "Learned", "Transfer", "Final"];
stageColors = [TransferLearning.NaiveColor; TransferLearning.ColorA; ...
	TransferLearning.TransferColor; TransferLearning.ColorB];

DSnames   = ["ALB", "TH", "V7", "LAB"];
DSlist    = {TransferLearning.AudioLightBaseline(), TransferLearning.THInhibit(), ...
	TransferLearning.Vacation7(), TransferLearning.LightAudioBaseline()};
rowLabels = ["ALB  声→光", "TH  声→光 (丘脑抑制)", "V7  声→光 (7 d 间隔)", "LAB  光→声"];
% 每个阶段用哪个刺激（行 = 数据集，列 = 阶段）
StimByStage = ["AudioWater", "AudioWater", "LightWater", "LightWater"; ...
	"AudioWater", "AudioWater", "LightWater", "LightWater"; ...
	"AudioWater", "AudioWater", "LightWater", "LightWater"; ...
	"LightWater", "LightWater", "AudioWater", "AudioWater"];
nDS = numel(DSnames);
stimShort = @(x) string(regexprep(regexprep(regexprep(x, "AudioWater", "AW"), "LightWater", "LW"), ...
	["AudioOnly", "LightOnly"], ["AO", "LO"]));

%% ---------- 取数 ----------
G = cell(nDS, 4);       % 每阶段 super-mouse 数据表
Info = cell(nDS, 4);    % 每阶段描述
for iDS = 1:nDS
	DS = DSlist{iDS};
	Tq = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus", "TrialUID", "BlockUID"]);
	Tq.Mouse = string(Tq.Mouse);
	Tq.Phase = string(Tq.Phase);
	Tq.Phase(ismissing(Tq.Phase)) = "<none>";
	Tq.Stimulus = string(Tq.Stimulus);
	Tq.Stimulus(ismissing(Tq.Stimulus)) = "<none>";
	sessKey = Tq.Mouse + "|" + string(Tq.DateTime);

	% 1) 每阶段每鼠的会话键（取最早符合条件的会话）
	keysByStage = cell(1, 4);
	for iS = 1:4
		keysByStage{iS} = iStageSessionKeys(Tq, sessKey, stageNames(iS), StimByStage(iDS, iS));
	end
	% 2) 四阶段齐全的鼠
	keptMice = unique(extractBefore(string(keysByStage{1}), "|"));
	for iS = 2:4
		keptMice = intersect(keptMice, unique(extractBefore(string(keysByStage{iS}), "|")));
	end
	keptMice = unique(keptMice);
	fprintf('\n=== %s：%d 只鼠（四阶段齐全）\n', DSnames(iDS), numel(keptMice));
	for iS = 1:4
		keysByStage{iS} = keysByStage{iS}(ismember(extractBefore(keysByStage{iS}, "|"), keptMice));
	end

	% 3) 逐阶段抽数据
	for iS = 1:4
		stim = StimByStage(iDS, iS);
		inKey = ismember(sessKey, keysByStage{iS});
		sel = inKey & Tq.Stimulus == stim;
		trials = Tq(sel, ["TrialUID", "BlockUID", "Mouse"]);
		S = iExtractTrials0to8s(DS, trials, LayerKeep, nOut, tWin, tBase);
		GN = iSuperMouse(S, nLines);
		G{iDS, iS} = GN;
		Info{iDS, iS} = sprintf('%s %s: %d 鼠, %d 细胞, %d 回合', ...
			DSnames(iDS), stageNames(iS), numel(unique(string(GN.Mouse))), height(GN), height(trials));
		fprintf('   %s\n', Info{iDS, iS});
	end
end

%% ---------- 每行（每个数据集）合并拟合一次 PCA ----------
P = cell(nDS, 4);       % 作图数据：2×nOut×nLines
expVar = zeros(nDS, 2); % 每行 PC1/PC2 解释方差(%)
for iDS = 1:nDS
	% 取四阶段共有的细胞，并按 CellUID 排序对齐
	common = G{iDS, 1}.CellUID;
	for iS = 2:4
		common = intersect(common, G{iDS, iS}.CellUID);
	end
	common = sort(unique(common));
	nCell = numel(common);
	data = nan(nCell, nOut, 4 * nLines);
	for iS = 1:4
		GN = G{iDS, iS};
		[ok, loc] = ismember(common, GN.CellUID);
		assert(all(ok), 'PCA_Stage:CellMismatch', 'Cell set mismatch in %s stage %s.', DSnames(iDS), stageNames(iS));
		d = GN.NTATS.Data(loc, :, :);
		data(:, :, (iS - 1) * nLines + (1:nLines)) = d;
	end
	PcaTable = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), 2, true);
	expVar(iDS, :) = PcaTable.Explained(1:2)';   % pca 的 explained 已是百分数
	fprintf('%s: %d 细胞, PC1=%.1f%%, PC2=%.1f%%\n', DSnames(iDS), nCell, expVar(iDS, 1), expVar(iDS, 2));
	score = PcaTable.Score.Data;   % 2 × nOut × (4*nLines)
	for iS = 1:4
		P{iDS, iS} = score(:, :, (iS - 1) * nLines + (1:nLines));
	end
end

%% ---------- 作图（两个版本） ----------
assignin('base', 'PCAstage_G', G);
assignin('base', 'PCAstage_P', P);
assignin('base', 'PCAstage_Info', Info);

for iMode = 1:numel(AxisModes)
	axisMode = AxisModes(iMode);
	f = figure('Color', 'w', 'Name', sprintf('PCA stage progression 4 cohorts 0-8s [%s]', axisMode));
	f.Units = 'centimeters';
	f.Position(3:4) = [22, 20];
	f.PaperUnits = 'centimeters';
	f.PaperPositionMode = 'manual';
	f.PaperPosition = [0, 0, 22, 20];
	f.PaperSize = [22, 20];

	tlo = tiledlayout(f, nDS, 4, 'TileSpacing', 'compact', 'Padding', 'tight');
	axAll = gobjects(nDS, 4);
	for iDS = 1:nDS
		for iS = 1:4
			ax = nexttile(tlo);
			iPlotGradient(ax, P{iDS, iS}, stageColors(iS, :), nGradSeg, SmoothFrames);
			title(ax, sprintf('%s · %s', stageNames(iS), stimShort(StimByStage(iDS, iS))));
			ax.FontSize = 12;
			ax.LineWidth = 1;
			box(ax, 'off');
			if iS == 1
				ylabel(ax, sprintf('%s\nPC2 (%.1f%%)', rowLabels(iDS), expVar(iDS, 2)));
			end
			if iS == 4
				xlabel(ax, sprintf('PC1 (%.1f%%)', expVar(iDS, 1)));
			end
			axAll(iDS, iS) = ax;
		end
		if axisMode == "row"
			% 行内四块完全共用同一坐标框
			iUnifyRowLims(axAll(iDS, :));
		else
			% 每块自动按自己的轨迹定轴（形状最大化）
			for iS = 1:4
				iApplyTileLims(axAll(iDS, iS), P{iDS, iS});
			end
		end
	end

	TransferLearning.ApplyStandardExportStyle(f, 2);
	if ExportSvg
		svgPath = TransferLearning.ExportStandardFigure(f, 2, ...
			sprintf('English_PCA_StageProgression_4cohorts_0to8s_%sscale.svg', axisMode));
		fprintf('Wrote: %s\n', svgPath);
	end
end

%% ========== local functions ==========
function iUnifyRowLims(axRow)
% 把一行内四块统一成**完全相同的** xlim/ylim（取并集）⇒ 位置与幅度都可比
xl = reshape([axRow.XLim], 2, []);
yl = reshape([axRow.YLim], 2, []);
xlNew = [min(xl(1, :)), max(xl(2, :))];
ylNew = [min(yl(1, :)), max(yl(2, :))];
for k = 1:numel(axRow)
	axRow(k).XLim = xlNew;
	axRow(k).YLim = ylNew;
end
end

function iApplyTileLims(ax, PcaData)
% 每块按自己的轨迹自动定轴：留 8%% 余量，让该阶段的形状尽量撑满面板
x = reshape(PcaData(1, :, :), [], 1);
y = reshape(PcaData(2, :, :), [], 1);
x = x(isfinite(x));
y = y(isfinite(y));
if isempty(x) || isempty(y)
	return;
end
sx = max(x) - min(x);
sy = max(y) - min(y);
if ~(isfinite(sx) && sx > 0)
	sx = 1;
end
if ~(isfinite(sy) && sy > 0)
	sy = 1;
end
ax.XLim = [min(x) - 0.08 * sx, max(x) + 0.08 * sx];
ax.YLim = [min(y) - 0.08 * sy, max(y) + 0.08 * sy];
end

function s = dateTimeStr(x)
% 统一成去时区的字符串，用于跨表匹配（各表 DateTime 的时区/格式可能不一致）
x = datetime(x);
if ~isempty(x.TimeZone)
	x.TimeZone = '';
end
s = string(x);
end

function keys = iStageSessionKeys(Tq, sessKey, stage, stim)
% 该阶段中给过指定刺激的会话键，按鼠只保留最早的一个。
m = Tq.Phase == stage & Tq.Stimulus == stim;
k = unique(sessKey(m));
if isempty(k)
	keys = strings(0, 1);
	return;
end
mouseOf = extractBefore(k, "|");
keys = strings(0, 1);
uMice = unique(mouseOf);
for i = 1:numel(uMice)
	kk = sort(k(mouseOf == uMice(i)));
	keys(end+1, 1) = kk(1); %#ok<AGROW>
end
end

function S = iExtractTrials0to8s(DS, trials, layerKeep, nOut, tWin, tBase)
% 从 BlockSignals 截取 cue 后 tWin 段，逐回合 z-score（基线 tBase）。
% 返回 struct：CellUID(n×1 uint64), Mouse(n×1 string), Sig(n×1 cell of nTrial×nOut)
cellsTbl = DS.Cells;
cellsTbl.CellUID = uint64(cellsTbl.CellUID);
cellsTbl.ZLayer = string(cellsTbl.ZLayer);
cellsTbl.Mouse = string(cellsTbl.Mouse);
if strlength(layerKeep) > 0
	keepMaskCells = cellsTbl.ZLayer == layerKeep;
else
	keepMaskCells = true(height(cellsTbl), 1);
end
cellUIDset = cellsTbl.CellUID(keepMaskCells);
cellMouse = cellsTbl.Mouse(keepMaskCells);

% cue 帧下标（block 内）来自 Trials.SampleRange.Tag
trAll = DS.Trials;
[isIn, loc] = ismember(uint64(trials.TrialUID), uint64(trAll.TrialUID));
assert(all(isIn), 'PCA_Stage:MissingTrial', 'Some trials are not in DS.Trials.');
cue = double(trAll.SampleRange.Tag(loc));
blk = double(trAll.BlockUID(loc));
dates = DS.DateTimes;
dates.DateTime = dateTimeStr(dates.DateTime);
dtAll = seconds(dates.SeriesInterval);
dtMed = median(dtAll(isfinite(dtAll) & dtAll > 0));
% block → 采样周期（个别会话 30 Hz，必须逐 block 用各自的 dt）
blocksTbl = DS.Blocks;
dtOfBlock = containers.Map('KeyType', 'double', 'ValueType', 'double');
for iD = 1:height(dates)
	bIds = blocksTbl.BlockUID(dateTimeStr(blocksTbl.DateTime) == dates.DateTime(iD));
	if isfinite(dtAll(iD)) && dtAll(iD) > 0
		dB = dtAll(iD);
	else
		dB = dtMed;
	end
	for j = 1:numel(bIds)
		dtOfBlock(double(bIds(j))) = dB;
	end
end

bs = DS.BlockSignals;
bs.CellUID = uint64(bs.CellUID);
Map = containers.Map('KeyType', 'uint64', 'ValueType', 'any');
nBadTrial = 0;
nTrialAll = 0;

uB = unique(blk);
for iB = 1:numel(uB)
	b = uB(iB);
	rTrial = find(blk == b);
	cueB = cue(rTrial);
	if isKey(dtOfBlock, b)
		dtB = dtOfBlock(b);
	else
		dtB = dtMed;
	end
	% 帧下标矩阵（block 内）
	off = round(linspace(tWin(1), tWin(2), nOut) / dtB);
	idxWin = cueB(:) + off;
	nBase = max(1, round(diff(tBase) / dtB));
	baseOff = round(linspace(tBase(1), tBase(2) - dtB, nBase) / dtB);
	idxBase = cueB(:) + baseOff;
	% 逐 block 载入细胞迹
	rowsB = find(bs.BlockUID == b);
	if isempty(rowsB)
		continue;
	end
	lenB = numel(bs.BlockSignal{rowsB(1)});
	% 越界回合（如 cue 未检出 = 0，或窗超出 block 末尾）整回合剔除，但保留该细胞
	validTrial = all(idxWin >= 1, 2) & all(idxWin <= lenB, 2) & all(idxBase >= 1, 2);
	nTrialAll = nTrialAll + numel(validTrial);
	nBadTrial = nBadTrial + sum(~validTrial);
	if ~any(validTrial)
		continue;
	end
	for r = 1:numel(rowsB)
		cid = bs.CellUID(rowsB(r));
		if ~any(cellUIDset == cid)
			continue;
		end
		full = double(bs.BlockSignal{rowsB(r)});
		full = full(:)';
		ok = validTrial & all(idxWin <= numel(full), 2);
		if ~any(ok)
			continue;
		end
		cellSd = std(full(isfinite(full)));
		if ~isfinite(cellSd) || cellSd < 1e-6
			continue;   % 死细胞
		end
		W = full(idxWin(ok, :));            % nTrial × nOut
		B = full(idxBase(ok, :));           % nTrial × nBase
		mu = mean(B, 2, 'omitnan');
		sd = std(B, 0, 2, 'omitnan');
		% 稳健尺度：局部基线段 sd 与「全 block sd 的一半」取大。
		% 正常细胞两者接近（≈标准 z-score）；基线异常平坦 / 慢漂移大的细胞不会被除到爆炸。
		sdFloor = 0.5 * cellSd;
		sd = max(sd, sdFloor);
		sd(~isfinite(sd)) = cellSd;
		Z = (W - mu) ./ sd;
		if isKey(Map, cid)
			Map(cid) = [Map(cid); Z];
		else
			Map(cid) = Z;
		end
	end
end
fprintf('      （越界回合剔除 %d / %d）\n', nBadTrial, nTrialAll);

ks = Map.keys;
n = numel(ks);
Sig = cell(n, 1);
uidOut = zeros(n, 1, 'uint64');
mouseOut = strings(n, 1);
for i = 1:n
	uidOut(i) = ks{i};
	Sig{i} = Map(ks{i});
	[ok, l] = ismember(uidOut(i), cellUIDset);
	if ok
		mouseOut(i) = cellMouse(l);
	else
		mouseOut(i) = "<unknown>";
	end
end
S = struct('CellUID', uidOut, 'Mouse', mouseOut, 'Sig', {Sig});
end

function GN = iSuperMouse(S, nLines)
% 每细胞的全部回合按顺序均分成 nLines 组取平均 → 细胞 × 时间 × nLines
nCell = numel(S.Sig);
nOut = size(S.Sig{1}, 2);
data = nan(nCell, nOut, nLines);
cellUID = zeros(nCell, 1, 'uint64');
mouse = strings(nCell, 1);
nExtreme = 0;
maxZ = cellfun(@(x) max(abs(x(:))), S.Sig);
fprintf('      max|z| 分位数: 50%%=%.1f 90%%=%.1f 99%%=%.1f 99.9%%=%.1f max=%.3g\n', ...
	prctile(maxZ, 50), prctile(maxZ, 90), prctile(maxZ, 99), prctile(maxZ, 99.9), max(maxZ));
zLimit = 1e3;   % 只剔除真正的伪迹（基线几乎为零导致 z 爆掉）
for i = 1:nCell
	sig = S.Sig{i};
	% 极端幅值（z 绝对值过大）视为伪迹
	if max(abs(sig(:))) > zLimit
		nExtreme = nExtreme + 1;
		continue;
	end
	meanSig = iAverageIntoNLines(sig, nLines);
	if isempty(meanSig)
		continue;
	end
	data(i, :, 1:size(meanSig, 1)) = reshape(meanSig.', [1, size(meanSig, 2), size(meanSig, 1)]);
	cellUID(i) = S.CellUID(i);
	mouse(i) = S.Mouse(i);
end
if nExtreme > 0
	fprintf('      （剔除 %d 个幅值异常细胞）\n', nExtreme);
end
ok = squeeze(all(all(isfinite(data), 2), 3));
data = data(ok, :, :);
cellUID = cellUID(ok);
mouse = mouse(ok);
GN = table(MATLAB.DataTypes.NDTable(data), cellUID, mouse, ...
	'VariableNames', ["NTATS", "CellUID", "Mouse"]);
end

function meanSig = iAverageIntoNLines(sig, nLines)
% 把 sig（nTrial × nTime）按回合顺序尽量均分成 nLines 组，组内平均；组间最多差 1，靠前的组多 1。
nTrial = size(sig, 1);
nTime = size(sig, 2);
if nTrial < 1 || nTime < 1
	meanSig = [];
	return;
end
nLines = min(nLines, nTrial);
q = floor(nTrial / nLines);
nExtra = nTrial - q * nLines;
groupSize = ones(1, nLines) * q;
groupSize(1:nExtra) = groupSize(1:nExtra) + 1;
boundEnd = cumsum(groupSize);
boundStart = [1, boundEnd(1:end - 1) + 1];
meanSig = nan(nLines, nTime);
for k = 1:nLines
	meanSig(k, :) = mean(sig(boundStart(k):boundEnd(k), :), 1, 'omitnan');
end
end

function iPlotGradient(ax, PcaData, baseColor, nSeg, smoothFrames)
% 线内时间渐变：cue 端浅（88% 白，仍可见）→ 8 s 端为基色；一次 patch 画完所有轨迹。
if nargin >= 5 && smoothFrames > 1
	PcaData = movmean(PcaData, smoothFrames, 2);   % 只影响显示，PCA 不变
end
nLines = size(PcaData, 3);
nTime = size(PcaData, 2);
tt = linspace(1, nTime, nSeg + 1);
w = linspace(0, 1, nSeg + 1)';
startC = 0.88;                                 % 起点不要纯白，否则前段在白色背景上看不见
cv = startC + w * (baseColor(:)' - startC);
X = nan(nSeg + 2, nLines);
Y = nan(nSeg + 2, nLines);
for iLine = 1:nLines
	xy = squeeze(PcaData(:, :, iLine));
	X(1:nSeg + 1, iLine) = interp1(1:nTime, xy(1, :), tt);
	Y(1:nSeg + 1, iLine) = interp1(1:nTime, xy(2, :), tt);
end
C = repmat(reshape(cv, [nSeg + 1, 1, 3]), 1, nLines, 1);
C(end + 1, :, :) = repmat(reshape(cv(end, :), [1, 1, 3]), 1, nLines, 1);
hold(ax, 'on');
patch(ax, X, Y, C, 'EdgeColor', 'flat', 'FaceColor', 'none', 'LineWidth', 1.5);
view(ax, 2);
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
end
