function perMouse = iPerMouseTable(Sess)
mice = unique(Sess.Mouse);
perMouse = table();
perMouse.Mouse = mice;
perMouse.Group = strings(numel(mice),1);
perMouse.BaselinePerf = nan(numel(mice),1);
perMouse.NSessions = nan(numel(mice),1);
perMouse.Slope = nan(numel(mice),1);

for i = 1:numel(mice)
    m = mice(i);
    S = Sess(Sess.Mouse == m, :);
    S = sortrows(S, 'Session');
    perMouse.Group(i) = string(S.Group(1));
    perMouse.NSessions(i) = max(S.Session);
    perMouse.BaselinePerf(i) = S.Performance(find(S.Session==1,1,'first'));

    ok = isfinite(S.Session) & isfinite(S.Performance);
    if nnz(ok) >= 2
        x = double(S.Session(ok));
        y = double(S.Performance(ok));
        p = polyfit(x, y, 1);
        perMouse.Slope(i) = p(1);
    end
end
perMouse.Mouse = string(perMouse.Mouse);
perMouse.Group = string(perMouse.Group);
end
