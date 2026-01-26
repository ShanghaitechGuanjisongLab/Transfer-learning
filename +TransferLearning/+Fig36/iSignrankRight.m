function p = iSignrankRight(hit, miss)
% TransferLearning.Fig36.iSignrankRight
p = NaN;
try
	if numel(hit) >= 4
		p = signrank(hit, miss, 'tail', 'right');
	end
catch
end
end
