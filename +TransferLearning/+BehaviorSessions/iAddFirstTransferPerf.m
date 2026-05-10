function PerMouse = iAddFirstTransferPerf(PerMouse, Sess)
Sess.Group = string(Sess.Group);
Sess.Mouse = string(Sess.Mouse);
if ~ismember('Session', Sess.Properties.VariableNames)
	Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);
end
if ~ismember('Phase', Sess.Properties.VariableNames)
	Sess.Phase = repmat("", height(Sess), 1);
end
Sess.Phase = string(Sess.Phase);

PerMouse.Group = string(PerMouse.Group);
PerMouse.Mouse = string(PerMouse.Mouse);
transferFirstPerf = nan(height(PerMouse), 1);
for i = 1:height(PerMouse)
	rows = Sess.Group == PerMouse.Group(i) & Sess.Mouse == PerMouse.Mouse(i);
	S1 = sortrows(Sess(rows, :), {'Session','DateTime'});
	transferRows = S1.Phase == "Transfer";
	if any(transferRows)
		ix = find(transferRows, 1, 'first');
	else
		ix = find(S1.Session == 1, 1, 'first');
	end
	if ~isempty(ix)
		transferFirstPerf(i) = double(S1.Performance(ix));
	end
end
PerMouse.TransferFirstPerf = transferFirstPerf;
end