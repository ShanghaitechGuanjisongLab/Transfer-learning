% Fig382D six-cell random weights only.
seedValue = 20260520;
numCells = 6;

rng(seedValue, 'twister');

weights = 1-sqrt(1 - rand(numCells, numCells));
weights(1:numCells+1:end) = 0;

disp((1-(weights-weights.'))*100);