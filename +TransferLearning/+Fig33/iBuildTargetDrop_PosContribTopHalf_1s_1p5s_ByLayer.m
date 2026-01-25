function rowsOut = iBuildTargetDrop_PosContribTopHalf_1s_1p5s_ByLayer(varargin)
% Build per-mouse-layer table for Fig3.2g: targeted drop vs random drop.
%
% This is a non-Scratch replacement for the legacy Scratch implementation.
%
% Parameters (Name-Value):
%   'FracTop' (default 0.5)
%   'NPerm'   (default 2000)
%   'Seed'    (default 1)
%
% Returns table with variables (superset of what Fig3.2g needs):
%   Mouse, DateTime_Transfer, DateTime_Learned, ZLayer,
%   NCellsLearnedLayer, NPosContribLearned, NDropTarget, NEligibleTransferLayer,
%   CellCorr_All, CellCorr_DropTarget,
%   DeltaZ_Target, DeltaZ_RandMean, DeltaZ_RandStd, P_perm_target_gt_rand
%
% Execution:
%   TransferLearning.Fig32.iBuildTargetDrop_PosContribTopHalf_1s_1p5s_ByLayer

p = inputParser;
p.addParameter('FracTop', 0.5, @(x) isscalar(x) && isfinite(x) && x > 0 && x <= 1);
p.addParameter('NPerm', 2000, @(x) isscalar(x) && isfinite(x) && x >= 10);
p.addParameter('Seed', 1, @(x) isscalar(x) && isfinite(x));
p.parse(varargin{:});

fracTop = double(p.Results.FracTop);
nPerm = double(p.Results.NPerm);
seed = double(p.Results.Seed);

layerNames = string(["MOp2/3","MOp5"]);

DS = TransferLearning.AudioLightBaseline();

xsSec = seconds(TransferLearning.Xs);
[dtMin1, idx1] = min(abs(xsSec - 1));
[dtMin2, idx2] = min(abs(xsSec - 1.5));
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig32:iBuildTargetDropTopHalf:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end
if isempty(idx2) || ~isfinite(dtMin2) || dtMin2 > 0.25
	error('Fig32:iBuildTargetDropTopHalf:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end

SessT = iGetSessions(DS, Phase="Transfer", Stimulus="LightWater");
SessL = iGetSessions(DS, Phase="Learned",  Stimulus="AudioWater");
SessT = iDropMixedSessions(DS, SessT);
SessT = iKeepLatestPerMouse(SessT);
SessL = iKeepLatestPerMouse(SessL);

mice = intersect(string(SessT.Mouse), string(SessL.Mouse));
mice = sort(mice);

rng(seed);

rowsOut = table();

for iMouse = 1:numel(mice)
	mouseId = string(mice(iMouse));
	rowT = SessT(string(SessT.Mouse)==mouseId, :);
	rowL = SessL(string(SessL.Mouse)==mouseId, :);
	if isempty(rowT) || isempty(rowL)
		continue;
	end
	dtT = rowT.DateTime(1);
	dtL = rowL.DateTime(1);

	for iLayer = 1:numel(layerNames)
		zLayer = layerNames(iLayer);
		[topUID, nCellsLearnedLayer, nPos] = iTopPosCells(DS, mouseId, dtL, zLayer, idx1, idx2, fracTop);

		[rAll, rDrop, dzObs, dzRand, dzRandMean, dzRandStd, nEligible] = iEvalDrop(DS, mouseId, dtT, zLayer, idx1, idx2, topUID, nPerm);

		pPerm = NaN;
		if isfinite(dzObs) && any(isfinite(dzRand))
			pPerm = (1 + nnz(dzRand >= dzObs)) / (1 + nnz(isfinite(dzRand)));
		end

		one = table();
		one.Mouse = mouseId;
		one.DateTime_Transfer = dtT;
		one.DateTime_Learned = dtL;
		one.ZLayer = zLayer;
		one.NCellsLearnedLayer = nCellsLearnedLayer;
		one.NPosContribLearned = nPos;
		one.NDropTarget = numel(topUID);
		one.NEligibleTransferLayer = nEligible;
		one.CellCorr_All = rAll;
		one.CellCorr_DropTarget = rDrop;
		one.DeltaZ_Target = dzObs;
		one.DeltaZ_RandMean = dzRandMean;
		one.DeltaZ_RandStd = dzRandStd;
		one.P_perm_target_gt_rand = pPerm;

		rowsOut = [rowsOut; one]; %#ok<AGROW>
	end
end

rowsOut.Mouse = string(rowsOut.Mouse);
rowsOut.ZLayer = string(rowsOut.ZLayer);

end

%% --- local helpers

function Sess = iGetSessions(DS, varargin)
	T = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Phase","Stimulus"], varargin{:});
	if isempty(T)
		Sess = table(string.empty(0,1), NaT(0,1), 'VariableNames', {'Mouse','DateTime'});
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	Sess = unique(table(T.Mouse, T.DateTime, 'VariableNames', {'Mouse','DateTime'}), 'rows');
	Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function Sess = iDropMixedSessions(DS, Sess)
	Ta = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Stimulus"], Stimulus="AudioWater");
	if isempty(Ta) || isempty(Sess)
		return;
	end
	Ta.Mouse = string(Ta.Mouse);
	Ta.DateTime = iNormalizeDateTime(Ta.DateTime);
	badKey = unique(Ta.Mouse + "|" + string(Ta.DateTime,'yyyy-MM-dd HH:mm:ss'));
	key = string(Sess.Mouse) + "|" + string(iNormalizeDateTime(Sess.DateTime),'yyyy-MM-dd HH:mm:ss');
	Sess = Sess(~ismember(key, badKey), :);
end

function Sess = iKeepLatestPerMouse(Sess)
	if isempty(Sess)
		return;
	end
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	mice = unique(Sess.Mouse);
	out = table(string.empty(0,1), NaT(0,1), 'VariableNames', Sess.Properties.VariableNames);
	for i = 1:numel(mice)
		m = mice(i);
		rowsM = Sess(Sess.Mouse==m, :);
		out = [out; rowsM(end,:)]; %#ok<AGROW>
	end
	Sess = out;
end

function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	if ismember('DateTime', T.Properties.VariableNames)
		T.DateTime = iNormalizeDateTime(T.DateTime);
	end
end

function dt = iNormalizeDateTime(dt)
	try
		dt = datetime(dt);
		dt.TimeZone = '';
	catch
	end
end

function [topUID, nCellsLayer, nPos] = iTopPosCells(ALB, mouseId, dateTime, zLayer, idx1, idx2, fracTop)
	topUID = string.empty(0,1);
	nCellsLayer = 0;
	nPos = 0;
	try
		q = struct('Mouse', string(mouseId), 'DateTime', dateTime, 'Stimulus', 'AudioWater');
		G = ALB.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
			return;
		end
		M = iNtatsToDouble(G.NTATS);
		if isempty(M) || idx1<1 || idx2<1 || idx1>size(M,2) || idx2>size(M,2)
			return;
		end
		v1 = double(M(:, idx1));
		v2 = double(M(:, idx2));
		uid = uint64(G.CellUID);
		mask = isfinite(v1) & isfinite(v2);
		mask = mask & iMaskByZLayer(ALB, uid, zLayer);
		nCellsLayer = nnz(mask);
		if nCellsLayer < 3
			return;
		end
		uid = uid(mask);
		x = v1(mask);
		y = v2(mask);

		xz = iZScore(x);
		yz = iZScore(y);
		contrib = xz .* yz;

		pos = contrib > 0 & isfinite(contrib);
		nPos = nnz(pos);
		if nPos == 0
			return;
		end
		contribPos = contrib(pos);
		uidPos = uid(pos);

		k = max(1, round(fracTop * numel(contribPos)));
		[~, ord] = sort(contribPos, 'descend');
		ord = ord(1:k);
		topUID = string(uidPos(ord));
	catch
		topUID = string.empty(0,1);
		nCellsLayer = 0;
		nPos = 0;
	end
end

function z = iZScore(x)
	x = double(x(:));
	mu = mean(x, 'omitnan');
	sd = std(x, 0, 'omitnan');
	if ~isfinite(sd) || sd == 0
		z = zeros(size(x));
		return;
	end
	z = (x - mu) ./ sd;
end

function [rAll, rDrop, dzObs, dzRand, dzRandMean, dzRandStd, nEligible] = iEvalDrop(ALB, mouseId, dateTime, zLayer, idx1, idx2, topUID, nPerm)
	rAll = NaN; rDrop = NaN; dzObs = NaN;
	dzRand = NaN(nPerm,1); dzRandMean = NaN; dzRandStd = NaN; nEligible = 0;
	try
		q = struct('Mouse', string(mouseId), 'DateTime', dateTime, 'Stimulus', 'LightWater');
		G = ALB.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
			return;
		end
		M = iNtatsToDouble(G.NTATS);
		if isempty(M) || idx1<1 || idx2<1 || idx1>size(M,2) || idx2>size(M,2)
			return;
		end
		v1 = double(M(:, idx1));
		v2 = double(M(:, idx2));
		uid = uint64(G.CellUID);
		mask = isfinite(v1) & isfinite(v2);
		mask = mask & iMaskByZLayer(ALB, uid, zLayer);
		x = v1(mask);
		y = v2(mask);
		cellUID = string(uid(mask));

		nEligible = numel(cellUID);
		if nEligible < 4
			return;
		end

		rAll = corr(x, y);
		zAll = iAtanhSafe(rAll);

		topUID = string(topUID);
		dropMask = ismember(cellUID, topUID);
		k = nnz(dropMask);
		if k == 0
			rDrop = rAll;
			dzObs = 0;
			dzRand = zeros(nPerm,1);
			dzRandMean = 0;
			dzRandStd = 0;
			return;
		end
		if nEligible - k < 4
			rDrop = NaN;
			dzObs = NaN;
			return;
		end

		xDrop = x(~dropMask);
		yDrop = y(~dropMask);
		rDrop = corr(xDrop, yDrop);
		zDrop = iAtanhSafe(rDrop);
		dzObs = zAll - zDrop;

		idxAll = 1:nEligible;
		for ii = 1:nPerm
			idxDrop = idxAll(randperm(nEligible, k));
			keep = true(nEligible,1);
			keep(idxDrop) = false;
			if nnz(keep) < 4
				continue;
			end
			rR = corr(x(keep), y(keep));
			zR = iAtanhSafe(rR);
			dzRand(ii) = zAll - zR;
		end

		useR = isfinite(dzRand);
		if any(useR)
			dzRandMean = mean(dzRand(useR));
			dzRandStd = std(dzRand(useR));
		end
	catch
		return;
	end
end

function mask = iMaskByZLayer(DS, uid, zLayer)
	mask = true(size(uid));
	try
		C = DS.Cells;
		C.CellUID = uint64(C.CellUID);
		CZ = innerjoin(table(uint64(uid(:)), 'VariableNames', {'CellUID'}), C(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
		zl = string(CZ.ZLayer);
		switch string(zLayer)
			case "MOp2/3"
				mask = zl == "MOp2/3";
			case "MOp5"
				mask = zl == "MOp5";
			otherwise
				mask = true(size(zl));
		end
	catch
		mask = true(size(uid));
	end
end

function z = iAtanhSafe(r)
	z = NaN;
	if ~isfinite(r)
		return;
	end
	r = max(min(r, 0.999999), -0.999999);
	z = atanh(r);
end

function M = iNtatsToDouble(A)
	if isempty(A)
		M = [];
		return;
	end
	if isa(A, 'MATLAB.DataTypes.NDTable')
		M = double(A{:, :});
	else
		M = double(A);
	end
	M = squeeze(M);
end
