function TTC = iTimeToCriterion(Sess, thr)
% Compute time-to-criterion (first session where performance >= thr) per mouse.
% Returns table with variables: Mouse, Group, TTC (session index), Censored.

if nargin < 2 || isempty(thr)
    thr = 0.8;
end

TTC = table();
if isempty(Sess)
    return;
end

mice = unique(Sess.Mouse);
TTC.Mouse = mice;
TTC.Group = strings(numel(mice),1);
TTC.TTC = nan(numel(mice),1);
TTC.Censored = true(numel(mice),1);

for i = 1:numel(mice)
    m = mice(i);
    S = Sess(Sess.Mouse == m, :);
    if isempty(S)
        continue;
    end
    S = sortrows(S, {'DateTime'});
    TTC.Group(i) = string(S.Group(1));

    j = find(double(S.Performance) >= thr, 1, 'first');
    if ~isempty(j)
        TTC.TTC(i) = double(S.Session(j));
        TTC.Censored(i) = false;
    else
        TTC.TTC(i) = double(max(S.Session));
        TTC.Censored(i) = true;
    end
end
end
