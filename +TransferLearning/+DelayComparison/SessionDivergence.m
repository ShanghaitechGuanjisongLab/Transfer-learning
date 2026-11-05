function T = SessionDivergence(DS, Sess, Stimulus, TimeSec)
%SESSIONDIVERGENCE Inter-trial divergence in one light session per mouse.
%   T = SessionDivergence(DS, Sess, Stimulus, TimeSec) uses the rows of Sess
%   (Mouse, DateTime) as the session to analyse, takes the population
%   response at TimeSec (relative to cue onset) and returns
%   div = sqrt(sum(var(cells)) / sum(mean(cells).^2)) over all cells.
arguments
	DS
	Sess table
	Stimulus (1,1) string
	TimeSec (1,1) double
end
xs = seconds(TransferLearning.Xs);
[idx0, ok0] = iFindTimeIndex(xs, 0, 0.25);
[idxT, okT] = iFindTimeIndex(xs, TimeSec, 0.25);
if ~ok0 || ~okT
	error('DelayComparison:TimeIndexMissing', 'Cannot find 0 s or %g s sample in TransferLearning.Xs.', TimeSec);
end

mice = unique(string(Sess.Mouse));
T = table(strings(0,1), nan(0,1), 'VariableNames', {'Mouse','Divergence'});
for i = 1:numel(mice)
	dt = Sess.DateTime(string(Sess.Mouse) == mice(i));
	q = struct('Stimulus', Stimulus, 'Mouse', mice(i), 'DateTime', dt(1));
	nts = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
	if iscell(nts)
		nts = nts{1};
	end
	if isempty(nts)
		continue;
	end
	T = [T; table(mice(i), iDivergence(nts, idx0, idxT), 'VariableNames', {'Mouse','Divergence'})]; %#ok<AGROW>
end
end

function div = iDivergence(nts, idx0, idxT)
uids = unique(uint64(nts.TrialUID), 'stable');
cells = unique(uint64(nts.CellUID), 'stable');
if numel(cells) < 3 || numel(uids) < 2
	div = NaN;
	return;
end
X = nan(numel(cells), numel(uids));
for iC = 1:numel(cells)
	rows = uint64(nts.CellUID) == cells(iC);
	uid = uint64(nts.TrialUID(rows));
	sig = double(nts.TrialSignal(rows, :));
	[tf, loc] = ismember(uids, uid);
	if ~all(tf)
		continue;
	end
	ordered = sig(loc, :);
	if any(~isfinite(ordered), 'all')
		continue;
	end
	X(iC, :) = ordered(:, idxT) - ordered(:, idx0);
end
X = X(all(isfinite(X), 2), :);
if size(X, 1) < 3
	div = NaN;
	return;
end
signal = sum(mean(X, 2).^2);
noise = sum(var(X, [], 2));
if signal > 0
	div = sqrt(noise / signal);
else
	div = NaN;
end
end

function [idx, ok] = iFindTimeIndex(xs, tSec, tolSec)
[d, idx] = min(abs(xs(:) - tSec));
ok = isfinite(d) && d <= tolSec;
end
