function Sess = iRSPdTransferSessionSpeed(RSP)
% TransferLearning.Fig36.iRSPdTransferSessionSpeed
% Session-level DeltaNext across LightWater sessions (do NOT restrict Phase)
% (match Fig3.3a logic: use the full LightWater learning trajectory)
T = RSP.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");
if isempty(T)
	Sess = table();
	return;
end
T.Mouse = string(T.Mouse);
try
	T.DateTime.TimeZone = '';
catch
end
T = sortrows(T, {'Mouse','DateTime'});

maxRows = height(T);
Mouse = strings(maxRows,1);
DateTime = NaT(maxRows,1);
Performance = nan(maxRows,1);
PerformanceNext = nan(maxRows,1);
Speed_DeltaNext = nan(maxRows,1);
rowN = 0;

mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM);
	R = T(T.Mouse==m, :);
	perf = double(R.Performance);
	% Strict filter for EF:
	% - Exclude 0% sessions
	% - Exclude 100% session and any sessions after the first ceiling
	% - Only keep sessions with 0<Perf<1
	keepSess = isfinite(perf) & (perf > 0) & (perf < 1);

	% Exclude ceiling segment (Perf==1 and later) plus the last step into ceiling
	idxCeil = find(perf >= 1, 1, 'first');
	if ~isempty(idxCeil)
		keepSess(idxCeil:end) = false;
	end

	for i = 1:(height(R)-1)
		p = double(R.Performance(i));
		pn = double(R.Performance(i+1));
		if ~(isfinite(p) && isfinite(pn))
			continue;
		end
		% DeltaNext points: both sessions must be strictly 0<Perf<1
		if ~(keepSess(i) && keepSess(i+1))
			continue;
		end
		rowN = rowN + 1;
		Mouse(rowN) = m;
		DateTime(rowN) = R.DateTime(i);
		Performance(rowN) = p;
		PerformanceNext(rowN) = pn;
		Speed_DeltaNext(rowN) = pn - p;
	end
end

Sess = table(Mouse(1:rowN), DateTime(1:rowN), Performance(1:rowN), PerformanceNext(1:rowN), Speed_DeltaNext(1:rowN), ...
	'VariableNames', {'Mouse','DateTime','Performance','PerformanceNext','Speed_DeltaNext'});
end
