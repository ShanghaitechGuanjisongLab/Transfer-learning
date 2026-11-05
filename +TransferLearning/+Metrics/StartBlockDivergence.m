function T = StartBlockDivergence(DS, startPhase, stimulus, sampleRate)
%STARTBLOCKDIVERGENCE 每只鼠在首个 startPhase 会话中，指定刺激的试次间相对散度
%
%   T = TransferLearning.Metrics.StartBlockDivergence(DS, startPhase, stimulus)
%   T = TransferLearning.Metrics.StartBlockDivergence(DS, startPhase, stimulus, sampleRate)
%
%   散度定义（与 Fig1E 一致）：取 cue 后 1 s 的群体响应矩阵 X(细胞 × 试次)，
%   sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )，按层分别计算。
%
%   输出 T：Mouse | DateTime | DivL23 | DivL5 | NCellsL23 | NCellsL5

arguments
	DS
	startPhase {mustBeTextScalar}
	stimulus {mustBeTextScalar} = "LightWater"
	sampleRate (1,1) double {mustBePositive} = 8
end

idx1s = 4 * sampleRate;

Tq = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Phase","Stimulus"]);
Tq.Mouse = string(Tq.Mouse);
Tq.Phase = string(Tq.Phase);
Tq.Stimulus = string(Tq.Stimulus);
Tq.DateTime = iNormDT(datetime(Tq.DateTime));

CellTbl = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
CellTbl.Mouse = string(CellTbl.Mouse);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.ZLayer = string(CellTbl.ZLayer);

mice = unique(Tq.Mouse);
selMouse = strings(0, 1);
selDT = NaT(0, 1);
trialSets = cell(0, 1);
for iM = 1:numel(mice)
	Tm = Tq(Tq.Mouse == mice(iM), :);
	startRows = Tm(Tm.Phase == string(startPhase) & Tm.Stimulus == string(stimulus), :);
	if isempty(startRows)
		continue;
	end
	startDT = min(startRows.DateTime);
	sessRows = Tm(Tm.DateTime == startDT, :);
	stimRows = sortrows(sessRows(sessRows.Stimulus == string(stimulus), :), 'TrialIndex');
	trialUIDs = unique(uint64(stimRows.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	selMouse(end+1, 1) = mice(iM); %#ok<AGROW>
	selDT(end+1, 1) = startDT; %#ok<AGROW>
	trialSets{end+1, 1} = trialUIDs; %#ok<AGROW>
end

if isempty(selMouse)
	T = iEmptyTable();
	return;
end

Q = table(selMouse, selDT, repmat(string(stimulus), numel(selMouse), 1), ...
	'VariableNames', {'Mouse','DateTime','Stimulus'});
ntsRaw = iQueryBatch(DS, Q);
if isempty(ntsRaw)
	T = iEmptyTable();
	return;
end
ntsRaw.Mouse = string(ntsRaw.Mouse);
ntsRaw.DateTime = iNormDT(datetime(ntsRaw.DateTime));
ntsRaw.CellUID = uint64(ntsRaw.CellUID);
ntsRaw.TrialUID = uint64(ntsRaw.TrialUID);

n = numel(selMouse);
divL23 = nan(n, 1);
divL5 = nan(n, 1);
nL23 = zeros(n, 1);
nL5 = zeros(n, 1);
for i = 1:n
	rawRows = ntsRaw(ntsRaw.Mouse == selMouse(i) & ntsRaw.DateTime == selDT(i), :);
	if isempty(rawRows)
		continue;
	end
	[CTT, cellUIDs] = iBuildTrialCellTime(rawRows, trialSets{i}, sampleRate);
	if isempty(CTT)
		continue;
	end
	X = CTT(:, :, idx1s);
	cellMeta = CellTbl(CellTbl.Mouse == selMouse(i), :);
	[has, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs), 1);
	layers(has) = cellMeta.ZLayer(loc(has));
	mask23 = layers == "MOp2/3";
	mask5 = layers == "MOp5";
	if sum(mask23) >= 3
		divL23(i) = iDivergence(X(mask23, :));
		nL23(i) = sum(mask23);
	end
	if sum(mask5) >= 3
		divL5(i) = iDivergence(X(mask5, :));
		nL5(i) = sum(mask5);
	end
end

T = table(selMouse, selDT, divL23, divL5, nL23, nL5, ...
	'VariableNames', {'Mouse','DateTime','DivL23','DivL5','NCellsL23','NCellsL5'});
end

function T = iEmptyTable()
T = table(strings(0,1), NaT(0,1), nan(0,1), nan(0,1), zeros(0,1), zeros(0,1), ...
	'VariableNames', {'Mouse','DateTime','DivL23','DivL5','NCellsL23','NCellsL5'});
end

function ntsRaw = iQueryBatch(DS, Q)
ntsRaw = table();
try
	res = DS.QueryNTS(Q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime","Mouse"]);
	ntsRaw = iCollapse(res);
catch
	parts = cell(height(Q), 1);
	for i = 1:height(Q)
		parts{i} = iCollapse(DS.QueryNTS(Q(i, :), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime","Mouse"]));
	end
	parts = parts(~cellfun(@isempty, parts));
	if ~isempty(parts)
		ntsRaw = vertcat(parts{:});
	end
end
end

function tbl = iCollapse(res)
tbl = table();
if isempty(res)
	return;
end
if istable(res)
	tbl = res;
elseif iscell(res)
	parts = res(~cellfun(@isempty, res));
	if ~isempty(parts) && istable(parts{1})
		tbl = vertcat(parts{:});
	end
end
end

function [CTT, cellUIDs] = iBuildTrialCellTime(rawRows, trialUIDs, sampleRate)
CTT = [];
cellUIDs = uint64([]);
rawRows = rawRows(ismember(uint64(rawRows.TrialUID), trialUIDs), :);
if isempty(rawRows)
	return;
end
allCells = unique(uint64(rawRows.CellUID));
traces = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	rows = uint64(rawRows.CellUID) == allCells(iC);
	uid = uint64(rawRows.TrialUID(rows));
	sig = double(rawRows.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	so = sig(loc, :);
	if size(so, 2) < sampleRate || any(~isfinite(so), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepUID(nKeep) = allCells(iC);
end
if nKeep < 3
	return;
end
traces = traces(1:nKeep);
cellUIDs = keepUID(1:nKeep);
CTT = nan(nKeep, numel(trialUIDs), size(traces{1}, 2));
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, numel(trialUIDs), size(traces{iC}, 2));
end
end

function div = iDivergence(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function dt = iNormDT(dt)
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end
