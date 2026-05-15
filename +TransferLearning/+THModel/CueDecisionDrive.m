function drive = CueDecisionDrive(Mouse, Params, usePreCue)
if usePreCue
	cueInputPattern = Mouse.PreCueInputPattern;
	cueGain = Params.CueInputGainPretrain;
else
	cueInputPattern = Mouse.CueInputPattern;
	cueGain = Params.CueInputGain;
end
Probe = TransferLearning.THModel.CueDecisionProbe(Mouse, cueInputPattern, Params, cueGain);
drive = Probe.Drive;
end
