function [pretrainPattern, formalPattern] = DrawCuePatternPair(numCells, pretrainActiveFraction, formalActiveFraction, overlapFraction, Params)
pretrainActiveCount = round(pretrainActiveFraction * numCells);
formalActiveCount = round(formalActiveFraction * numCells);
overlapCount = round(overlapFraction * pretrainActiveCount);
formalUniqueCount = formalActiveCount - overlapCount;
if overlapCount > formalActiveCount || formalUniqueCount > numCells - pretrainActiveCount
	error('THModel:InvalidCuePatternFractions', 'Cue fractions cannot produce the requested pretrain/formal overlap for %d cells.', numCells);
end

pretrainPattern = TransferLearning.THModel.Zeros([numCells, 1]);
formalPattern = TransferLearning.THModel.Zeros([numCells, 1]);
allIndices = 1:numCells;
pretrainIndices = randperm(numCells, pretrainActiveCount);
if overlapCount > 0
	overlapSelection = randperm(pretrainActiveCount, overlapCount);
	overlapIndices = pretrainIndices(overlapSelection);
else
	overlapIndices = [];
end
availableFormalIndices = setdiff(allIndices, pretrainIndices);
if formalUniqueCount > 0
	formalUniqueSelection = randperm(numel(availableFormalIndices), formalUniqueCount);
	formalUniqueIndices = availableFormalIndices(formalUniqueSelection);
else
	formalUniqueIndices = [];
end
formalIndices = [overlapIndices(:); formalUniqueIndices(:)];
pretrainPattern(pretrainIndices) = Params.ResponseScale;
formalPattern(formalIndices) = Params.ResponseScale;
end