function colors = FigurePalette(nColors)
arguments
	nColors (1,1) double {mustBeInteger, mustBePositive}
end

baseColors = [1, 0, 0; 0, 0, 1; 0, 0.6809, 0];
if nColors > size(baseColors, 1)
	error('TransferLearning:FigurePalette:TooManyColors', 'Only 1-3 standard colors are defined.');
end
colors = baseColors(1:nColors, :);
end