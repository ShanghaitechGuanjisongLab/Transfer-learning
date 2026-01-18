function perMouse = iAddFirstTransferPerf(perMouse, Sess)
perMouse.TransferFirstPerf = nan(height(perMouse),1);
perMouse.TransferFirstSession = nan(height(perMouse),1);
if ~ismember('Phase', Sess.Properties.VariableNames)
    return;
end
for i = 1:height(perMouse)
    m = perMouse.Mouse(i);
    S = Sess(Sess.Mouse == m, :);
    if isempty(S)
        continue;
    end
    S = sortrows(S, {'DateTime'});
    isTr = string(S.Phase) == "Transfer";
    j = find(isTr, 1, 'first');
    if ~isempty(j)
        perMouse.TransferFirstPerf(i) = double(S.Performance(j));
        perMouse.TransferFirstSession(i) = double(S.Session(j));
    end
end
end
