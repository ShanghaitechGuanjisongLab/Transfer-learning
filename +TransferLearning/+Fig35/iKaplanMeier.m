function [x, y] = iKaplanMeier(ttc, censored)
% Minimal Kaplan–Meier step function from discrete event times.
% ttc: time to event or last observed (positive numeric)
% censored: true if censored (no event)

x = []; y = [];
if isempty(ttc)
    return;
end

ttc = double(ttc(:));
censored = logical(censored(:));
keep = isfinite(ttc) & ttc > 0;
ttc = ttc(keep);
censored = censored(keep);

if isempty(ttc)
    return;
end

% Sort unique times
[times, ~, idx] = unique(ttc);
[times, order] = sort(times);

n = numel(ttc);
S = 1;
xs = 0;
ys = 1;

for k = 1:numel(times)
    t = times(k);

    atRisk = sum(ttc >= t);
    isTime = (ttc == t);
    d = sum(isTime & ~censored);

    if atRisk <= 0
        continue;
    end

    % Step at t
    xs(end+1,1) = t; %#ok<AGROW>
    ys(end+1,1) = S; %#ok<AGROW>

    if d > 0
        S = S * (1 - d/atRisk);
    end

    xs(end+1,1) = t; %#ok<AGROW>
    ys(end+1,1) = S; %#ok<AGROW>
end

x = xs;
y = ys;
end
