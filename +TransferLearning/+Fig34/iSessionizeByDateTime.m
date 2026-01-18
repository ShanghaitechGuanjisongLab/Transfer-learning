function Sess = iSessionizeByDateTime(T)
% Input columns: Mouse, DateTime, Performance, Group (block-level rows)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T.DateTime = datetime(T.DateTime);
T.DateTime.TimeZone = '';

[G, mouse, dt, grp] = findgroups(T.Mouse, T.DateTime, T.Group);
perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
nBlk = splitapply(@numel, T.Performance, G);
Sess = table(mouse, dt, grp, perf, nBlk, 'VariableNames', {'Mouse','DateTime','Group','Performance','NBlocksInSession'});

if ismember('Phase', T.Properties.VariableNames)
    ph = splitapply(@iFirstNonmissingString, string(T.Phase), G);
    Sess.Phase = ph;
end
end

function s = iFirstNonmissingString(x)
x = string(x);
x = x(~ismissing(x));
if isempty(x)
    s = "";
else
    s = x(1);
end
end
