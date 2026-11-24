function R = iBuildReactivationFirstBlock(options)
% 通用版：跨条件"再激活率 × Transfer 首个 block 命中率"。
% 再激活率 = P(Transfer 活跃 | Learned 活跃)，在 cue 后 +1 s 判定
%   （活跃 = 该细胞 1 s 处 z 分数 > 基线 −3~0 s 均值 + 3 SD）。
% Transfer 首个 block 命中率 = Transfer 首个会话中 BlockIndex 最小的
%   block 里、指定刺激试次的 Behavior 均值。
%
% 与 iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer 的区别：
%   1) 刺激/设计可切换（支持 光→声 与 声→光 两个方向）；
%   2) 额外给出 Transfer 首个 block 的命中率，而不只是整会话命中率。
arguments
	options.DataSet
	options.Source string = ""
	options.LearnedPhase string = "Learned"
	options.LearnedStimulus string = "AudioWater"
	options.LearnedDesign string = ""
	options.TransferPhase string = "Transfer"
	options.TransferStimulus string = "LightWater"
	options.TransferDesign string = ""
end

DS = options.DataSet;
learnedDesign = options.LearnedDesign;   % 空 => 不按 Design 过滤
transferDesign = options.TransferDesign; % 空 => 不按 Design 过滤
learnedDesignTag = learnedDesign;
transferDesignTag = transferDesign;
if strlength(learnedDesignTag) == 0
	learnedDesignTag = options.LearnedStimulus;
end
if strlength(transferDesignTag) == 0
	transferDesignTag = options.TransferStimulus;
end

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('iBuildRFB:No1s', 'Cannot find sample close to 1 s.');
end
kSigma = 3;

% ---------- 会话选择 ----------
% Design 为空 => 只按 Phase + Stimulus 过滤（同一队列里 Design 命名可能不一致）
if strlength(learnedDesign) > 0
	TLearn = DS.TableQuery(["Mouse", "DateTime"], ...
		Phase = options.LearnedPhase, Stimulus = options.LearnedStimulus, ...
		Design = learnedDesign);
else
	TLearn = DS.TableQuery(["Mouse", "DateTime"], ...
		Phase = options.LearnedPhase, Stimulus = options.LearnedStimulus);
end
if strlength(transferDesign) > 0
	TTran = DS.TableQuery(["Mouse", "DateTime", "Behavior"], ...
		Phase = options.TransferPhase, Stimulus = options.TransferStimulus, ...
		Design = transferDesign);
else
	TTran = DS.TableQuery(["Mouse", "DateTime", "Behavior"], ...
		Phase = options.TransferPhase, Stimulus = options.TransferStimulus);
end
if isempty(TLearn) || isempty(TTran)
	R = iEmptyResult();
	return;
end

TLearn.Mouse = string(TLearn.Mouse);
TLearn.DateTime = iNormalizeDateTime(TLearn.DateTime);
TTran.Mouse = string(TTran.Mouse);
TTran.DateTime = iNormalizeDateTime(TTran.DateTime);

miceL = unique(TLearn.Mouse, 'stable');
Sess = table(strings(0,1), NaT(0,1), NaT(0,1), 'VariableNames', ...
	{'Mouse','DateTimeLearned','DateTimeTransfer'});
for i = 1:numel(miceL)
	m = miceL(i);
	dL = TLearn.DateTime(TLearn.Mouse == m);
	if isempty(dL) || ~any(TTran.Mouse == m)
		continue;
	end
	dT = TTran.DateTime(TTran.Mouse == m);
	Sess = [Sess; table(m, max(dL), min(dT), ...
		'VariableNames', {'Mouse','DateTimeLearned','DateTimeTransfer'})]; %#ok<AGROW>
end
if isempty(Sess)
	R = iEmptyResult();
	return;
end

% ---------- 每鼠的实际 Design 标签（Design 命名在不同鼠间可能不一致）----------
learnedDesignRow = repmat("", height(Sess), 1);
transferDesignRow = repmat("", height(Sess), 1);
if strlength(learnedDesign) == 0 || strlength(transferDesign) == 0
	Bmeta = DS.Blocks(:, {'DateTime', 'Design'});
	Bmeta.DateTime = iNormalizeDateTime(Bmeta.DateTime);
	Bmeta.Design = string(Bmeta.Design);
	Dmeta = DS.DateTimes(:, {'DateTime', 'Mouse', 'Phase'});
	Dmeta.DateTime = iNormalizeDateTime(Dmeta.DateTime);
	Dmeta.Mouse = string(Dmeta.Mouse);
	Dmeta.Phase = string(Dmeta.Phase);
	KB = innerjoin(Bmeta, Dmeta, 'Keys', 'DateTime');
	KB = KB(KB.Design ~= "", :);
	for iRow = 1:height(Sess)
		m = string(Sess.Mouse(iRow));
		if strlength(learnedDesign) == 0
			cand = unique(KB.Design(KB.Mouse == m & KB.Phase == options.LearnedPhase), 'stable');
			cand = iPrefer(cand, options.LearnedStimulus);
			if ~isempty(cand)
				learnedDesignRow(iRow) = cand(1);
			end
		else
			learnedDesignRow(iRow) = learnedDesign;
		end
		if strlength(transferDesign) == 0
			cand = unique(KB.Design(KB.Mouse == m & KB.Phase == options.TransferPhase), 'stable');
			cand = iPrefer(cand, options.TransferStimulus);
			if ~isempty(cand)
				transferDesignRow(iRow) = cand(1);
			end
		else
			transferDesignRow(iRow) = transferDesign;
		end
	end
	keep = learnedDesignRow ~= "" & transferDesignRow ~= "";
	Sess = Sess(keep, :);
	learnedDesignRow = learnedDesignRow(keep);
	transferDesignRow = transferDesignRow(keep);
	if isempty(Sess)
		R = iEmptyResult();
		return;
	end
end

% ---------- 细胞元数据 ----------
CellMeta = DS.Cells(:, ["CellUID", "ZLayer", "Mouse"]);
CellMeta.CellUID = uint64(CellMeta.CellUID);
CellMeta.ZLayer = string(CellMeta.ZLayer);
CellMeta.Mouse = string(CellMeta.Mouse);

% ---------- NTATS ----------
QLearnAll = table(repmat(categorical(options.LearnedPhase), height(Sess), 1), ...
	repmat(categorical(options.LearnedStimulus), height(Sess), 1), ...
	categorical(learnedDesignRow), ...
	categorical(string(Sess.Mouse)), Sess.DateTimeLearned, ...
	repmat("Learned", height(Sess), 1), ...
	'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
QTranAll = table(repmat(categorical(options.TransferPhase), height(Sess), 1), ...
	repmat(categorical(options.TransferStimulus), height(Sess), 1), ...
	categorical(transferDesignRow), ...
	categorical(string(Sess.Mouse)), Sess.DateTimeTransfer, ...
	repmat("Transfer", height(Sess), 1), ...
	'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});

GLearnStruct = DS.QueryNTATS(QLearnAll, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTranStruct = DS.QueryNTATS(QTranAll, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

[XLearnAll, cellLearnAll] = iExtractNtats2D(GLearnStruct);
[XTranAll, cellTranAll] = iExtractNtats2D(GTranStruct);

% ---------- 首 block 命中率所需的行为表 ----------
Bs = DS.Blocks(:, {'BlockUID', 'DateTime', 'BlockIndex'});
Bs.BlockUID = uint64(Bs.BlockUID);
Bs.DateTime = iNormalizeDateTime(Bs.DateTime);
Ts = DS.Trials(:, {'BlockUID', 'Stimulus', 'Behavior'});
Ts.BlockUID = uint64(Ts.BlockUID);
Ts.Stimulus = string(Ts.Stimulus);
Ts.Behavior = double(Ts.Behavior);

Rows = repmat(iEmptyResult(), 0, 1);
for iRow = 1:height(Sess)
	mouseName = string(Sess.Mouse(iRow));
	dtLearned = Sess.DateTimeLearned(iRow);
	dtTransfer = Sess.DateTimeTransfer(iRow);

	mouseCells = CellMeta.CellUID(CellMeta.Mouse == mouseName);
	if isempty(mouseCells)
		continue;
	end

	[~, idxL_mouse] = intersect(cellLearnAll, mouseCells, 'stable');
	XLearn = XLearnAll(idxL_mouse, :);
	cellLearn = cellLearnAll(idxL_mouse);

	[~, idxT_mouse] = intersect(cellTranAll, mouseCells, 'stable');
	XTran = XTranAll(idxT_mouse, :);
	cellTran = cellTranAll(idxT_mouse);

	if isempty(XLearn) || isempty(XTran)
		continue;
	end
	[commonCells, idxL, idxT] = intersect(cellLearn, cellTran, 'stable');
	if isempty(commonCells)
		continue;
	end
	XLearn = XLearn(idxL, :);
	XTran = XTran(idxT, :);
	cellLayers = iMapLayer(CellMeta, commonCells);

	learnedActive = iIsActiveAt1s(XLearn, baseMask, idx1s, kSigma);
	transferActive = iIsActiveAt1s(XTran, baseMask, idx1s, kSigma);

	mask23 = iIsLayer23(cellLayers);
	mask5 = iIsLayer5(cellLayers);
	[n23, prob23] = iConditionalProb(learnedActive, transferActive, mask23);
	[n5, prob5] = iConditionalProb(learnedActive, transferActive, mask5);

	% 整会话命中率（与 Fig1K 口径一致）
	beh = TTran.Behavior(TTran.Mouse == mouseName & TTran.DateTime == dtTransfer);
	sessHit = mean(beh, 'omitnan');

	% Transfer 首个 block 命中率
	selB = Bs.DateTime == dtTransfer;
	firstBlockHit = NaN;
	nFirstTrials = 0;
	if any(selB)
		bi = Bs.BlockIndex(selB);
		firstIdx = min(bi);
		uids = Bs.BlockUID(selB & bi == firstIdx);
		selT = ismember(Ts.BlockUID, uids) & Ts.Stimulus == options.TransferStimulus;
		nFirstTrials = nnz(selT);
		firstBlockHit = mean(Ts.Behavior(selT), 'omitnan');
	end

	Rows = [Rows; table(mouseName, dtLearned, dtTransfer, sessHit, firstBlockHit, ...
		nFirstTrials, n23, n5, prob23, prob5, string(options.Source), ...
		'VariableNames', iEmptyResult().Properties.VariableNames)]; %#ok<AGROW>
end

R = Rows;
end

%% ------------------------------------------------------------------
function T = iEmptyResult()
T = table(strings(0,1), NaT(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTimeLearned','DateTimeTransfer','SessionHitRate', ...
	'FirstBlockHitRate','NFirstBlockTrials','NLearnedActive23','NLearnedActive5', ...
	'Prob23','Prob5','Source'});
end

function [X, cellUID] = iExtractNtats2D(G)
cellUID = uint64([]);
X = [];
if isempty(G)
	return;
end
nt = G.NTATS;
cellUID = uint64(G.CellUID);
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data;
else
	X = nt;
end
X = double(X);
if ndims(X) == 3
	X = squeeze(X(:, :, 1));
end
end

function active = iIsActiveAt1s(X, baseMask, idx1s, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
active = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma .* baseSd));
end

function [nLearned, prob] = iConditionalProb(learnedActive, transferActive, layerMask)
use = layerMask & learnedActive;
nLearned = nnz(use);
if nLearned < 1
	prob = NaN;
else
	prob = mean(double(transferActive(use)), 'omitnan');
end
end

function cand = iPrefer(cand, stimulus)
% 优先选中与目标刺激同名的设计标签
if numel(cand) > 1
	hit = cand == stimulus;
	if any(hit)
		cand = [cand(hit); cand(~hit)];
	end
end
end

function layers = iMapLayer(CellMeta, cellUID)
[tf, loc] = ismember(cellUID, CellMeta.CellUID);
layers = strings(size(cellUID));
layers(tf) = CellMeta.ZLayer(loc(tf));
end

function tf = iIsLayer23(layers)
layers = lower(strtrim(layers));
tf = contains(layers, "2/3") | contains(layers, "23");
end

function tf = iIsLayer5(layers)
layers = lower(strtrim(layers));
tf = contains(layers, "5");
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end
