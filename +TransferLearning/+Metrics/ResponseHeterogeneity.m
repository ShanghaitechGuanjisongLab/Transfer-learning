function T = ResponseHeterogeneity(DS, sessions, stimulus)
%RESPONSEHETEROGENEITY 每只鼠每层的响应异质性（跨细胞 SD of trial-mean z@1 s）
%
%   T = TransferLearning.Metrics.ResponseHeterogeneity(DS, sessions, stimulus)
%
%   sessions：table，至少含 Mouse、DateTime 两列，指定要纳入平均的会话。
%   stimulus：会话内取用的刺激（"LightWater" 或 "AudioWater"）。
%
%   口径（与 Fig1I 一致）：逐细胞、逐会话取 cue +1 s 的 z 分数中位数 →
%   跨会话平均 → 限 |z| ≤ 1 → 跨细胞求 SD；细胞数 < 3 的层不出值。
%
%   输出 T：Mouse | Layer | SD | NCells

arguments
	DS
	sessions table
	stimulus {mustBeTextScalar} = "LightWater"
end

idx1s = iTimeIndex(1);

T = table(strings(0,1), strings(0,1), nan(0,1), zeros(0,1), ...
	'VariableNames', {'Mouse','Layer','SD','NCells'});
if isempty(sessions)
	return;
end

CellTbl = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
CellTbl.Mouse = string(CellTbl.Mouse);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.ZLayer = string(CellTbl.ZLayer);

S = sessions(:, {'Mouse','DateTime'});
S.Mouse = string(S.Mouse);
S.DateTime = iNormDT(datetime(S.DateTime));
[~, iu] = unique(S.DateTime);
S = S(iu, :);

try
	res = DS.QueryNTS(struct('Stimulus', string(stimulus), 'DateTime', S.DateTime), ...
		UniExp.Flags.ZScore, 1:24, 'ExtraColumns', "DateTime");
	raw = iCollapse(res);
catch
	raw = table();
end
if isempty(raw)
	return;
end
raw.CellUID = uint64(raw.CellUID);
raw.DateTime = iNormDT(datetime(raw.DateTime));
raw = iAttachLayer(raw, CellTbl);
[~, loc] = ismember(raw.DateTime, S.DateTime);
raw.Mouse = strings(height(raw), 1);
has = loc > 0;
raw.Mouse(has) = S.Mouse(loc(has));
raw = raw(has, :);

z1s = double(raw.TrialSignal(:, idx1s));
[G, mus, cells, layers] = findgroups(raw.Mouse, raw.CellUID, raw.ZLayer);
med = splitapply(@(x) median(x, 'omitnan'), z1s, G);
medTbl = table(mus, cells, layers, med, 'VariableNames', {'Mouse','CellUID','ZLayer','Med1s'});

lvl = ["MOp2/3"; "MOp5"];
rows = cell(0, 4);
for iM = 1:numel(unique(medTbl.Mouse))
	m = unique(medTbl.Mouse);
	for iL = 1:numel(lvl)
		R = medTbl(medTbl.Mouse == m(iM) & medTbl.ZLayer == lvl(iL), :);
		if isempty(R)
			continue;
		end
		[~, ~, id] = unique(R.CellUID);
		perCell = accumarray(id, R.Med1s, [], @mean);
		vals = perCell(isfinite(perCell) & perCell >= -1 & perCell <= 1);
		if numel(vals) >= 3
			rows(end+1, :) = {m(iM), lvl(iL), std(vals), numel(vals)}; %#ok<AGROW>
		end
	end
end
if isempty(rows)
	return;
end
T = cell2table(rows, 'VariableNames', {'Mouse','Layer','SD','NCells'});
T.Mouse = string(T.Mouse);
T.Layer = string(T.Layer);
T.SD = double(T.SD);
T.NCells = double(T.NCells);
end

function idx = iTimeIndex(tSec)
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[~, idx] = min(abs(xsSec(:) - tSec));
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

function T = iAttachLayer(T, cellMap)
[~, loc] = ismember(T.CellUID, cellMap.CellUID);
T.ZLayer = strings(height(T), 1);
has = loc > 0;
T.ZLayer(has) = cellMap.ZLayer(loc(has));
end

function dt = iNormDT(dt)
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end
