function pattern = DrawCuePattern(numCells, activeFraction, Params)
activeCount = round(activeFraction * numCells);
pattern = TransferLearning.THModel.Zeros([numCells, 1]);
if activeCount > 0
	activeIndices = randperm(numCells, activeCount);
	pattern(activeIndices) = Params.ResponseScale;
end
end