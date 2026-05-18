function drive = CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue)
if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	l23InhibitoryCuePattern = Mouse.PreCueL23InhibitoryPattern;
else
	cueInputPattern = Mouse.CueInputPattern;
	l23InhibitoryCuePattern = Mouse.CueL23InhibitoryPattern;
end
Probe = TransferLearning.THModel.CueDecisionProbeNoLocalInh(Mouse, cueInputPattern, Params, 1, l23InhibitoryCuePattern);
drive = Probe.Drive;
end
