function X = iNtatsData(NT)
% TransferLearning.Fig36.iNtatsData
if isa(NT, 'MATLAB.DataTypes.NDTable')
	X = NT.Data;
else
	X = NT;
end
end
