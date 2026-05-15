function recurrentWeights = ZeroSelfProjection(recurrentWeights)
numCells = size(recurrentWeights, 1);
recurrentWeights(1:numCells+1:end) = 0;
end
