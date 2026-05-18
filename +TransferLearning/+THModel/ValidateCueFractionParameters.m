function ValidateCueFractionParameters(Params)
fractionFieldNames = ["CueInputGain", "CueInputGainPretrain", "CueModalityCorr"];
for iField = 1:numel(fractionFieldNames)
	fieldName = fractionFieldNames(iField);
	fieldValue = Params.(fieldName);
	if fieldValue < 0 || fieldValue > 1
		error('THModel:InvalidCueFractionParameter', '%s must be in [0, 1] because fixed cue strength now means active-cell fraction.', fieldName);
	end
end
iValidateCuePair(Params.NCueInput, Params.CueInputGainPretrain, Params.CueInputGain, Params.CueModalityCorr);
iValidateCuePair(Params.NIL23, Params.CueInputGainPretrain, Params.CueInputGain, Params.CueModalityCorr);
end

function iValidateCuePair(numCells, pretrainActiveFraction, formalActiveFraction, overlapFraction)
pretrainActiveCount = round(pretrainActiveFraction * numCells);
formalActiveCount = round(formalActiveFraction * numCells);
overlapCount = round(overlapFraction * pretrainActiveCount);
formalUniqueCount = formalActiveCount - overlapCount;
if overlapCount > formalActiveCount || formalUniqueCount > numCells - pretrainActiveCount
	error('THModel:InvalidCuePatternFractions', 'Cue fractions cannot produce the requested pretrain/formal overlap for %d cells.', numCells);
end
end