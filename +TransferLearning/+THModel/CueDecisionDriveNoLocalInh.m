function drive = CueDecisionDriveNoLocalInh(Mouse, Params, usePreCue)
if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	cueGain = Params.CueInputGainPretrain;
else
	cueInputPattern = Mouse.CueInputPattern;
	cueGain = Params.CueInputGain;
end
Probe = TransferLearning.THModel.CueDecisionProbeNoLocalInh(Mouse, cueInputPattern, Params, cueGain);
drive = Probe.Drive;
end
