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

if options.RequireHitMiss
	QAll = table(categorical(["Learned"; "TransferHit"; "TransferMiss"]), ...
		categorical(["Learned"; "Transfer"; "Transfer"]), ...
		categorical(["AudioWater"; "LightWater"; "LightWater"]), ...
		categorical(["AudioWater"; "LightWater"; "LightWater"]), ...
		{[]; 1; 0}, ...
		'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});
else
	QAll = table(categorical(["Learned"; "Transfer"]), ...
		categorical(["Learned"; "Transfer"]), ...
		categorical(["AudioWater"; "LightWater"]), ...
		categorical(["AudioWater"; "LightWater"]), ...
		{[]; []}, ...
		'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});
end

GAllStruct = DS.QueryNTATS(QAll, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
if options.RequireHitMiss
	[XLearnAll, cellLearnAll] = iExtractGroupNtats(GAllStruct, "Learned", 1);
	[XHitAll, cellHitAll] = iExtractGroupNtats(GAllStruct, "TransferHit", 2);
	[XMissAll, cellMissAll] = iExtractGroupNtats(GAllStruct, "TransferMiss", 3);
else
	[XLearnAll, cellLearnAll] = iExtractGroupNtats(GAllStruct, "Learned", 1);
	[XTranAll, cellTranAll] = iExtractGroupNtats(GAllStruct, "Transfer", 2);
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

	[~, idxLMouse] = intersect(cellLearnAll, mouseCells, 'stable');
	XLearn = XLearnAll(idxLMouse, :);
	cellLearn = cellLearnAll(idxLMouse);

	if options.RequireHitMiss
		hasHitMiss = any(beh == 1) && any(beh == 0);
		if ~hasHitMiss
			continue;
		end

		[~, idxHitMouse] = intersect(cellHitAll, mouseCells, 'stable');
		XHitMouse = XHitAll(idxHitMouse, :);
		cellHit = cellHitAll(idxHitMouse);

		[~, idxMissMouse] = intersect(cellMissAll, mouseCells, 'stable');
		XMissMouse = XMissAll(idxMissMouse, :);
		cellMiss = cellMissAll(idxMissMouse);

		if isempty(XLearn) || isempty(XHitMouse) || isempty(XMissMouse)
			continue;
		end

		[commonLearnHit, idxLearnHit, idxHit] = intersect(cellLearn, cellHit, 'stable');
		[commonCells, idxLearnHitMiss, idxMiss] = intersect(commonLearnHit, cellMiss, 'stable');
		if isempty(commonCells)
			continue;
		end
		XLearn = XLearn(idxLearnHit(idxLearnHitMiss), :);
		XHit = XHitMouse(idxHit(idxLearnHitMiss), :);
		XMiss = XMissMouse(idxMiss, :);
	else
		[~, idxTMouse] = intersect(cellTranAll, mouseCells, 'stable');
		XTran = XTranAll(idxTMouse, :);
		cellTran = cellTranAll(idxTMouse);
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
	if options.RequireHitMiss
		transferActiveHit = iIsActiveAt1s(XHit, baseMask, idx1s, kSigma);
		transferActiveMiss = iIsActiveAt1s(XMiss, baseMask, idx1s, kSigma);
		transferActive = transferActiveHit | transferActiveMiss;
	else
		transferActive = iIsActiveAt1s(XTran, baseMask, idx1s, kSigma);
	end

	mask23 = iIsLayer23(cellLayers);
	mask5 = iIsLayer5(cellLayers);

	[n23, prob23] = iConditionalProb(learnedActive, transferActive, mask23);
	[n5, prob5] = iConditionalProb(learnedActive, transferActive, mask5);
	if options.RequireHitMiss
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

function [X, cellUID] = iExtractGroupNtats(G, groupName, groupIndex)
fieldName = char(groupName);
if isstruct(G) && isfield(G, fieldName)
	[X, cellUID] = iExtractNtats2D(G.(fieldName));
	return;
end

[XAll, cellUID] = iExtractNtatsArray(G);
if ndims(XAll) == 3
	X = XAll(:, :, groupIndex);
else
	X = XAll;
end
end

function [X, cellUID] = iExtractNtats2D(G)
[X, cellUID] = iExtractNtatsArray(G);
if ndims(X) == 3
	if size(X, 3) ~= 1
		error('iBuildProb:BadGroupShape', 'Expected a single group NTATS array.');
	end
	X = X(:, :, 1);
end
end

function [X, cellUID] = iExtractNtatsArray(G)
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