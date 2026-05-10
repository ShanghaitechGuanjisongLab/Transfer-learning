function ph = iPickSessionPhase(phases)
phases = string(phases);
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	ph = "";
	return;
end
[uniquePhases, ~, phaseIndex] = unique(phases);
counts = accumarray(phaseIndex, 1);
[~, ix] = max(counts);
ph = uniquePhases(ix);
end