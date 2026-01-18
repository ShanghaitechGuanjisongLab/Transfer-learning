function T = iAddSessionIndex(T)
T.Session = nan(height(T),1);
mice = unique(T.Mouse);
for i = 1:numel(mice)
    m = mice(i);
    rows = (T.Mouse == m);
    [~, ord] = sort(T.DateTime(rows));
    idx = find(rows);
    T.Session(idx(ord)) = (1:numel(ord))';
end
end
