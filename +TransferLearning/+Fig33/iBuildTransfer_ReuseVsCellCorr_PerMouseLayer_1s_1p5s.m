function T = iBuildTransfer_ReuseVsCellCorr_PerMouseLayer_1s_1p5s()
% Build Transfer-only table for Fig3.2e (panels 3/4): Reuse(1s) vs CellCorr(1s,1.5s).
%
% Operational definition (matches legacy Scratch implementation):
% - Reuse(1s) is computed in ALB by pooling phases:
%     Reuse(1s) = P(TransferLight active at 1s | LearnedAudio active at 1s)
%   Active(1s) is defined on Median NTATS ZScore:
%     Z(1s) > mean(Z(-3~0)) + 3*std(Z(-3~0))
% - CellCorr is computed from latest Transfer LightWater session per mouse
%   (excluding mixed sessions): Pearson corr across cells between 1s and 1.5s.
%
% Returns table with variables:
%   Mouse, ZLayer, NCellsReuse, Reuse, TransferDateTime, NCellsCorr, CellCorr_1s1p5s
%
% Execution:
%   TransferLearning.Fig33.iBuildTransfer_ReuseVsCellCorr_PerMouseLayer_1s_1p5s

DS = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig32:iBuildTransfer_ReuseVsCellCorr_1s1p5:BadTimeMask', 'Baseline(-3~0) has no samples.');
end

[dtMin1, idx1] = min(abs(xsSec - 1));
[dtMin2, idx2] = min(abs(xsSec - 1.5));
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig32:iBuildTransfer_ReuseVsCellCorr_1s1p5:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end
if isempty(idx2) || ~isfinite(dtMin2) || dtMin2 > 0.25
	error('Fig32:iBuildTransfer_ReuseVsCellCorr_1s1p5:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end

kSigma = 3;
layerNames = string(["MOp2/3","MOp5"]);

% --- A) Reuse per mouse×layer (phase pooled)
GLearn = iQueryNTATSOrEmpty(DS, struct('Stimulus','AudioWater','Phase','Learned'));
GTran  = iQueryNTATSOrEmpty(DS, struct('Stimulus','LightWater','Phase','Transfer'));
if isempty(GLearn) || isempty(GTran)
	error('Fig32:iBuildTransfer_ReuseVsCellCorr_1s1p5:MissingGroups', 'QueryNTATS empty for Learned(AudioWater) or Transfer(LightWater).');
end

XLearn = iNtatsData(GLearn.NTATS);
XTran  = iNtatsData(GTran.NTATS);

learnAct = iActiveAt1s(XLearn, baseMask, idx1, kSigma);
tranAct  = iActiveAt1s(XTran,  baseMask, idx1, kSigma);

C = DS.Cells;
learnedCell = table(uint64(GLearn.CellUID), double(learnAct), 'VariableNames', {'CellUID','LearnedActive'});
transferCell = table(uint64(GTran.CellUID), double(tranAct), 'VariableNames', {'CellUID','TransferActive'});
learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
transferCell = innerjoin(transferCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
learnedCell.Mouse = string(learnedCell.Mouse);
transferCell.Mouse = string(transferCell.Mouse);
learnedCell.ZLayer = string(learnedCell.ZLayer);
transferCell.ZLayer = string(transferCell.ZLayer);

LT = innerjoin(learnedCell(:,{'Mouse','ZLayer','CellUID','LearnedActive'}), transferCell(:,{'Mouse','ZLayer','CellUID','TransferActive'}), ...
	'Keys', {'Mouse','ZLayer','CellUID'});

reuseRows = table;
mouseLayer = unique(LT(:,{'Mouse','ZLayer'}));
for i = 1:height(mouseLayer)
	m = string(mouseLayer.Mouse(i));
	zl = string(mouseLayer.ZLayer(i));
	if ~any(zl == layerNames)
		continue;
	end
	idx = (LT.Mouse==m) & (LT.ZLayer==zl);
	if nnz(idx) < 10
		continue;
	end
	LA = logical(LT.LearnedActive(idx));
	TA = logical(LT.TransferActive(idx));
	if nnz(LA) < 1
		continue;
	end
	reuse = mean(double(TA(LA)), 'omitnan');
	reuseRows = [reuseRows; table(m, zl, nnz(idx), reuse, 'VariableNames', {'Mouse','ZLayer','NCellsReuse','Reuse'})]; %#ok<AGROW>
end

% --- B) CellCorr per mouse×layer from latest Transfer session
SessT = iGetSessions(DS, Phase="Transfer", Stimulus="LightWater");
SessT = iDropMixedSessions(DS, SessT);
SessT = iKeepLatestPerMouse(SessT);

corrRows = table;
for i = 1:height(SessT)
	m = string(SessT.Mouse(i));
	dt = SessT.DateTime(i);
	for iZ = 1:numel(layerNames)
		zl = layerNames(iZ);
		[r, nCell] = iCellCorrSessionByLayer(DS, m, dt, idx1, idx2, zl);
		corrRows = [corrRows; table(m, zl, dt, nCell, r, 'VariableNames', {'Mouse','ZLayer','TransferDateTime','NCellsCorr','CellCorr_1s1p5s'})]; %#ok<AGROW>
	end
end

T = innerjoin(reuseRows, corrRows, 'Keys', {'Mouse','ZLayer'});
T.Mouse = string(T.Mouse);
T.ZLayer = string(T.ZLayer);
T = sortrows(T, {'ZLayer','Reuse'});

end

%% --- local helpers

function G = iQueryNTATSOrEmpty(DS, query)
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function act = iActiveAt1s(X, baseMask, idx1, kSigma)
	base = X(:, baseMask);
	mu = mean(base, 2, 'omitnan');
	sd = std(base, 0, 2, 'omitnan');
	thr = mu + kSigma .* sd;
	v = X(:, idx1);
	act = v > thr;
end

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
	key = Sess.Mouse + "|" + string(Sess.DateTime,'yyyy-MM-dd HH:mm:ss');
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

function [r, nCell] = iCellCorrSessionByLayer(DS, mouse, dt, idx1, idx2, zLayer)
	r = NaN; nCell = NaN;
	try
		q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
			return;
		end
		M = iNtatsData(G.NTATS);
		v1 = double(M(:, idx1));
		v2 = double(M(:, idx2));
		uid = uint64(G.CellUID);
		mask = isfinite(v1) & isfinite(v2);

		C = DS.Cells;
		C.CellUID = uint64(C.CellUID);
		CZ = innerjoin(table(uid, 'VariableNames', {'CellUID'}), C(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
		zl = string(CZ.ZLayer);
		mask = mask & (zl == string(zLayer));

		nCell = nnz(mask);
		if nCell < 3 || std(v1(mask))==0 || std(v2(mask))==0
			r = NaN;
			return;
		end
		r = corr(v1(mask), v2(mask), 'Type','Pearson');
	catch
		r = NaN; nCell = NaN;
	end
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
