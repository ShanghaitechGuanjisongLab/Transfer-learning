function Delta = iBuildSessionDeltaTable(Sess)
% Build session-level delta performance table.
% Each row: one session for one mouse with DeltaPerf = Perf(s)-Perf(s-1).
% Rule: exclude sessions with Perf==0 or 1 and all sessions after the first
% occurrence of Perf==0 or 1 (per mouse). Also drops the first session per mouse.

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

    % Find first all-correct/all-wrong session; cut at that point (exclude it and after)
    jCut = find(perf == 0 | perf == 1, 1, 'first');
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

    % Exclude sessions where current perf is 0 or 1 (shouldn't happen after cut, but keep safe)
    keep = isfinite(T.DeltaPerf) & T.Performance ~= 0 & T.Performance ~= 1;
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
