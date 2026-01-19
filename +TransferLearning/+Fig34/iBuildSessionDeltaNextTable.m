function Delta = iBuildSessionDeltaNextTable(Sess)
% Build session-level forward-difference performance table.
% Each row corresponds to one (mouse, session) with:
%   DeltaPerf = Perf(next) - Perf(current)
%
% This matches the Fig3.3 "DeltaNext" convention (forward difference), while
% keeping the column name DeltaPerf for consistent downstream plotting.
%
% Filtering rule (per mouse; consistent with Fig3.3 session filtering):
%   1) Drop ALL sessions with Perf==0.
%   2) Find first session where Perf==1, and drop that session AND all later
%      sessions, PLUS the last step into ceiling (the session immediately
%      before the first Perf==1).
%   3) Enforce 0<Perf<1 after filtering.
%   4) Compute forward differences between remaining consecutive sessions.
%
% Required columns in Sess:
%   Mouse, Group, DateTime, Session, Performance

Delta = table();
if isempty(Sess)
    return;
end

need = {"Mouse","Group","DateTime","Session","Performance"};
for k = 1:numel(need)
    if ~ismember(need{k}, Sess.Properties.VariableNames)
        error('iBuildSessionDeltaNextTable:MissingVar', 'Missing variable %s', need{k});
    end
end

Sess.Mouse = string(Sess.Mouse);
Sess.Group = string(Sess.Group);

mice = unique(Sess.Mouse);
out = cell(numel(mice),1);

zTol = 1e-12;
oneTol = 1 - 1e-12;

for i = 1:numel(mice)
    m = mice(i);
    S = Sess(Sess.Mouse == m, :);
    if isempty(S)
        continue;
    end

    S = sortrows(S, 'DateTime');
    dt = datetime(S.DateTime);
    if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
    perf = double(S.Performance);

    % 1) Drop Perf==0
    keep = isfinite(perf) & (perf > zTol);
    S = S(keep, :);
    dt = dt(keep);
    perf = perf(keep);
    if height(S) < 2
        continue;
    end

    % 2) Drop ceiling segment: first Perf==1 and later, plus the last step into ceiling
    i100 = find(isfinite(perf) & (perf >= oneTol), 1, 'first');
    if ~isempty(i100)
        if i100 <= 1
            % first remaining session is already ceiling -> drop all
            continue;
        end
        % drop from (i100-1) onward
        S = S(1:i100-2, :);
        dt = dt(1:i100-2);
        perf = perf(1:i100-2);
    end
    if height(S) < 2
        continue;
    end

    % 3) Enforce 0<Perf<1
    keep = isfinite(perf) & (perf > zTol) & (perf < oneTol);
    S = S(keep, :);
    dt = dt(keep);
    perf = perf(keep);
    if height(S) < 2
        continue;
    end

    % 4) Forward difference
    d = diff(perf); % Perf(next)-Perf(current)

    T = table();
    T.Mouse = S.Mouse(1:end-1);
    T.Group = S.Group(1:end-1);
    T.DateTime = dt(1:end-1);
    T.Session = S.Session(1:end-1);
    T.Performance = perf(1:end-1);
    T.DateTimeNext = dt(2:end);
    T.PerformanceNext = perf(2:end);
    T.DeltaPerf = d(:);

    % Safety: keep finite and keep both current and next strictly within (0,1)
    keep = isfinite(T.DeltaPerf) & (T.Performance > zTol) & (T.Performance < oneTol) & ...
        (T.PerformanceNext > zTol) & (T.PerformanceNext < oneTol);
    T = T(keep, :);

    out{i} = T;
end

out = out(~cellfun('isempty', out));
if isempty(out)
    Delta = table();
else
    Delta = vertcat(out{:});
end
end
