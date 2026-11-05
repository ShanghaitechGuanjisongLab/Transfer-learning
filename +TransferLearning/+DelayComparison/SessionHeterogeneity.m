function T = SessionHeterogeneity(DS, Sess, Stimulus, TimeSec, Layer)
%SESSIONHETEROGENEITY Per-mouse response heterogeneity (SD across cells).
%   T = SessionHeterogeneity(DS, Sess, Stimulus, TimeSec, Layer) pools all
%   sessions of Sess (Mouse, DateTime), takes each cell's median response at
%   TimeSec per session, averages those over sessions, and returns the SD
%   across cells of one ZLayer. Same definition as Fig1H_SlopeVsHeterogeneity.
arguments
	DS
	Sess table
	Stimulus (1,1) string
	TimeSec (1,1) double
	Layer (1,1) string
end
xs = seconds(TransferLearning.Xs);
[idxT, okT] = iFindTimeIndex(xs, TimeSec, 0.25);
if ~okT
	error('DelayComparison:TimeIndexMissing', 'Cannot find %g s sample in TransferLearning.Xs.', TimeSec);
end

mice = unique(string(Sess.Mouse));
T = table(strings(0,1), nan(0,1), zeros(0,1), 'VariableNames', {'Mouse','Heterogeneity','NCell'});
if isempty(Sess)
	return;
end

dts = unique(Sess.DateTime);
q = struct('Stimulus', Stimulus, 'DateTime', dts);
nts = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', "DateTime");
if iscell(nts)
	nts = nts{1};
end
if isempty(nts)
	return;
end
nts.CellUID = uint64(nts.CellUID);
nts.DateTime = iNormalizeDateTime(nts.DateTime);

cells = DS.Cells(:, {'CellUID','ZLayer'});
cells.CellUID = uint64(cells.CellUID);
cells.ZLayer = string(cells.ZLayer);
[~, loc] = ismember(nts.CellUID, cells.CellUID);
zLayer = strings(height(nts), 1);
has = loc > 0;
zLayer(has) = cells.ZLayer(loc(has));
nts = nts(zLayer == Layer, :);
if isempty(nts)
	return;
end

sig = double(nts.TrialSignal);
sig = sig(:, idxT);
[G, cellList, dtList] = findgroups(nts.CellUID, nts.DateTime);
medAtT = splitapply(@(x) median(x, 'omitnan'), sig, G);
medTbl = table(cellList, dtList, medAtT, 'VariableNames', {'CellUID','DateTime','Med'});

for i = 1:numel(mice)
	rowsSess = Sess(string(Sess.Mouse) == mice(i), :);
	sub = medTbl(ismember(medTbl.DateTime, rowsSess.DateTime), :);
	if isempty(sub)
		continue;
	end
	[~, ~, ic] = unique(sub.CellUID);
	perCell = accumarray(ic, sub.Med, [], @mean);
	vals = perCell(isfinite(perCell) & perCell >= -1 & perCell <= 1);
	if numel(vals) >= 3
		T = [T; table(mice(i), std(vals), numel(vals), ...
			'VariableNames', {'Mouse','Heterogeneity','NCell'})]; %#ok<AGROW>
	end
end
end

function [idx, ok] = iFindTimeIndex(xs, tSec, tolSec)
[d, idx] = min(abs(xs(:) - tSec));
ok = isfinite(d) && d <= tolSec;
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end
