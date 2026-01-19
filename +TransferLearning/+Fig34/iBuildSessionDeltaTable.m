function Delta = iBuildSessionDeltaTable(Sess)
% Build session-level delta performance table.
% Each row: one session for one mouse with DeltaPerf = Perf(s)-Perf(s-1).
% Rule (per mouse):
%   1) Exclude ALL sessions with Perf==0.
%   2) Exclude the first session where Perf==1 and all sessions after it.
%      (i.e., keep only sessions with 0<Perf<1, before first Perf==1.)
%   3) Compute DeltaPerf between remaining consecutive sessions and drop the
%      first session per mouse (so Delta is defined).

Delta = table();
if isempty(Sess)
    return;
end

need = {'Mouse','Group','DateTime','Session','Performance'};
for k = 1:numel(need)
    if ~ismember(need{k}, Sess.Properties.VariableNames)
        error('iBuildSessionDeltaTable:MissingVar', 'Missing variable %s', need{k});
    end
end

mice = unique(Sess.Mouse);
out = cell(numel(mice),1);
for i = 1:numel(mice)
    m = mice(i);
    S = Sess(Sess.Mouse == m, :);
    if isempty(S)
        continue;
    end
    S = sortrows(S, {'DateTime'});
    perf = double(S.Performance);

    % 1) Drop all-zero sessions anywhere
    keep = (perf ~= 0) & isfinite(perf);
    S = S(keep, :);
    perf = perf(keep);

    % 2) Truncate at first all-correct session (exclude it and after)
    jCut = find(perf == 1, 1, 'first');
    if ~isempty(jCut)
        S = S(1:jCut-1, :);
        perf = perf(1:jCut-1);
    end
    if height(S) < 2
        continue;
    end

    deltaPerf = perf(2:end) - perf(1:end-1);

    T = table();
    T.Mouse = S.Mouse(2:end);
    T.Group = S.Group(2:end);
    T.DateTime = S.DateTime(2:end);
    T.Session = S.Session(2:end);
    T.Performance = perf(2:end);
    T.PrevPerformance = perf(1:end-1);
    T.DeltaPerf = deltaPerf;

    % Safety: keep finite deltas and ensure current performance is strictly between 0 and 1.
    keep = isfinite(T.DeltaPerf) & (T.Performance > 0) & (T.Performance < 1);
    T = T(keep,:);

    out{i} = T;
end

out = out(~cellfun('isempty', out));
if isempty(out)
    Delta = table();
else
    Delta = vertcat(out{:});
end
end
