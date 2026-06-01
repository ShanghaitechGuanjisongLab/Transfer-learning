function R = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer(options)
arguments
	options.DataSet = TransferLearning.AudioLightBaseline()
	options.Source string = "AudioLightBaseline"
	options.RequireHitMiss (1, 1) logical = true
end

DS = options.DataSet;

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('iBuildProb:No1s', 'Cannot find sample close to 1 s.');
end
kSigma = 3;

TLearn = DS.TableQuery(["Mouse","DateTime"], ...
	Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
TTran = DS.TableQuery(["Mouse","DateTime","Behavior"], ...
	Phase="Transfer", Stimulus="LightWater", Design="LightWater");

if isempty(TLearn) || isempty(TTran)
	R = iEmptyResult();
	return;
end

TLearn.Mouse = string(TLearn.Mouse);
TLearn.DateTime = iNormalizeDateTime(TLearn.DateTime);
TTran.Mouse = string(TTran.Mouse);
TTran.DateTime = iNormalizeDateTime(TTran.DateTime);

dtLearnT = groupsummary(TLearn, "Mouse", "max", "DateTime");
dtLearnT.Properties.VariableNames{end} = 'DateTimeLearned';
dtTranT = groupsummary(TTran(:, ["Mouse","DateTime"]), "Mouse", "min", "DateTime");
dtTranT.Properties.VariableNames{end} = 'DateTimeTransfer';

Sess = innerjoin(dtLearnT(:, ["Mouse","DateTimeLearned"]), dtTranT(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');
if isempty(Sess)
	R = iEmptyResult();
	return;
end

CellMeta = DS.Cells(:, ["CellUID","ZLayer","Mouse"]);
CellMeta.CellUID = uint64(CellMeta.CellUID);
CellMeta.ZLayer = string(CellMeta.ZLayer);
CellMeta.Mouse = categorical(string(CellMeta.Mouse));

QLearnAll = table(repmat(categorical("Learned"), height(Sess), 1), ...
	repmat(categorical("AudioWater"), height(Sess), 1), repmat(categorical("AudioWater"), height(Sess), 1), ...
	categorical(string(Sess.Mouse)), Sess.DateTimeLearned, ...
	repmat("Learned", height(Sess), 1), ...
	'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
QTranAll = table(repmat(categorical("Transfer"), height(Sess), 1), ...
	repmat(categorical("LightWater"), height(Sess), 1), repmat(categorical("LightWater"), height(Sess), 1), ...
	categorical(string(Sess.Mouse)), Sess.DateTimeTransfer, ...
	repmat("Transfer", height(Sess), 1), ...
	'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});

QTranHMAll = table();
if options.RequireHitMiss
	for iRow = 1:height(Sess)
		mouseName = string(Sess.Mouse(iRow));
		dtTransfer = Sess.DateTimeTransfer(iRow);
		beh = double(TTran.Behavior(TTran.Mouse == mouseName & TTran.DateTime == dtTransfer));
		if any(beh == 1) && any(beh == 0)
			t = table(["Hit"; "Miss"], repmat(categorical("Transfer"), 2, 1), ...
				repmat(categorical("LightWater"), 2, 1), repmat(categorical("LightWater"), 2, 1), ...
				[1; 0], repmat(categorical(mouseName), 2, 1), repmat(dtTransfer, 2, 1), ...
				'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior','Mouse','DateTime'});
			QTranHMAll = [QTranHMAll; t]; %#ok<AGROW>
		end
	end
end

GLearnStruct = DS.QueryNTATS(QLearnAll, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTranStruct = DS.QueryNTATS(QTranAll, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
if options.RequireHitMiss && ~isempty(QTranHMAll)
	GTranHMStruct = DS.QueryNTATS(QTranHMAll, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
else
	GTranHMStruct = struct();
end

[XLearnAll, cellLearnAll] = iExtractNtats2D(GLearnStruct);
[XTranAll, cellTranAll] = iExtractNtats2D(GTranStruct);
if options.RequireHitMiss
	[XHitAll, cellHitAll] = iExtractNtats3D_Index(GTranHMStruct, 1);
	[XMissAll, cellMissAll] = iExtractNtats3D_Index(GTranHMStruct, 2);
end

Rows = repmat(iEmptyResult(), 0, 1);

for iRow = 1:height(Sess)
	mouseName = string(Sess.Mouse(iRow));
	dtLearned = Sess.DateTimeLearned(iRow);
	dtTransfer = Sess.DateTimeTransfer(iRow);

	beh = double(TTran.Behavior(TTran.Mouse == mouseName & TTran.DateTime == dtTransfer));
	
	mouseCells = CellMeta.CellUID(string(CellMeta.Mouse) == mouseName);
	if isempty(mouseCells)
		continue;
	end

	[~, idxL_mouse] = intersect(cellLearnAll, mouseCells, 'stable');
	XLearn = XLearnAll(idxL_mouse, :);
	cellLearn = cellLearnAll(idxL_mouse);

	[~, idxT_mouse] = intersect(cellTranAll, mouseCells, 'stable');
	XTran = XTranAll(idxT_mouse, :);
	cellTran = cellTranAll(idxT_mouse);

	if options.RequireHitMiss
		hasHitMiss = any(beh == 1) && any(beh == 0);
		if ~hasHitMiss
			continue;
		end

		[~, idxHit_mouse] = intersect(cellHitAll, mouseCells, 'stable');
		XHitData = XHitAll(idxHit_mouse, :);
		cellHit = cellHitAll(idxHit_mouse);

		[~, idxMiss_mouse] = intersect(cellMissAll, mouseCells, 'stable');
		XMissData = XMissAll(idxMiss_mouse, :);
		cellMiss = cellMissAll(idxMiss_mouse);

		if isempty(XLearn) || isempty(XTran) || isempty(XHitData) || isempty(XMissData)
			continue;
		end

		[commonLT, idxL, idxT] = intersect(cellLearn, cellTran, 'stable');
		[commonLT_Hit, idxLT1, idxHit] = intersect(commonLT, cellHit, 'stable');
		[commonCells, idxLT2, idxMiss] = intersect(commonLT_Hit, cellMiss, 'stable');
		if isempty(commonCells)
			continue;
		end

		XLearn = XLearn(idxL(idxLT1(idxLT2)), :);
		XTran = XTran(idxT(idxLT1(idxLT2)), :);
		XHit = XHitData(idxHit(idxLT2), :);
		XMiss = XMissData(idxMiss, :);
	else
		if isempty(XLearn) || isempty(XTran)
			continue;
		end
		[commonCells, idxL, idxT] = intersect(cellLearn, cellTran, 'stable');
		if isempty(commonCells)
			continue;
		end
		XLearn = XLearn(idxL, :);
		XTran = XTran(idxT, :);
	end
	cellLayers = iMapLayer(CellMeta, commonCells);

	learnedActive = iIsActiveAt1s(XLearn, baseMask, idx1s, kSigma);
	transferActive = iIsActiveAt1s(XTran, baseMask, idx1s, kSigma);

	mask23 = iIsLayer23(cellLayers);
	mask5 = iIsLayer5(cellLayers);

	[n23, prob23] = iConditionalProb(learnedActive, transferActive, mask23);
	[n5, prob5] = iConditionalProb(learnedActive, transferActive, mask5);
	if options.RequireHitMiss
		transferActiveHit = iIsActiveAt1s(XHit, baseMask, idx1s, kSigma);
		transferActiveMiss = iIsActiveAt1s(XMiss, baseMask, idx1s, kSigma);
		[~, probHit23] = iConditionalProb(learnedActive, transferActiveHit, mask23);
		[~, probHit5] = iConditionalProb(learnedActive, transferActiveHit, mask5);
		[~, probMiss23] = iConditionalProb(learnedActive, transferActiveMiss, mask23);
		[~, probMiss5] = iConditionalProb(learnedActive, transferActiveMiss, mask5);
	else
		probHit23 = NaN;
		probHit5 = NaN;
		probMiss23 = NaN;
		probMiss5 = NaN;
	end

	transferHitRate = mean(beh, 'omitnan');

	Rows = [Rows; table(mouseName, dtLearned, dtTransfer, transferHitRate, ...
		n23, n5, prob23, prob5, probHit23, probHit5, probMiss23, probMiss5, string(options.Source), ...
		'VariableNames', iEmptyResult().Properties.VariableNames)]; %#ok<AGROW>
end

R = Rows;
end

function T = iEmptyResult()
T = table(strings(0, 1), NaT(0, 1), NaT(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
	nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), ...
	'VariableNames', {'Mouse','DateTimeLearned','DateTimeTransfer','TransferHitRate', ...
	'NLearnedActive23','NLearnedActive5','Prob23','Prob5','ProbHit23','ProbHit5','ProbMiss23','ProbMiss5','Source'});
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
function [X, cellUID] = iExtractNtats3D(G)
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
if ndims(X) ~= 3
	error('iBuildProb:BadHMShape', 'Expected hit/miss NTATS to be 3-D.');
end
end

function [X, cellUID] = iExtractNtats3D_Index(G, dim3Index)
[X3, cellUID] = iExtractNtats3D(G);
X = [];
if ~isempty(X3)
	X = X3(:, :, dim3Index);
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