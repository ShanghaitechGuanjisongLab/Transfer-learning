function pattern = DrawBalancedBinaryPattern(numCells)
activeCount = round(numCells / 2);
pattern = TransferLearning.THModel.Zeros([numCells, 1]);
if activeCount > 0
	activeIndices = randperm(numCells, activeCount);
	pattern(activeIndices) = 1;
end
end