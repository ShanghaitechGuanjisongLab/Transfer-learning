function slicedHistory = SliceInhibitoryHistory(inhibitoryHistory, historyCount)
slicedHistory.L23 = iSliceHistoryField(inhibitoryHistory.L23, historyCount);
slicedHistory.L5RewardRecv = iSliceHistoryField(inhibitoryHistory.L5RewardRecv, historyCount);
slicedHistory.L5Read = iSliceHistoryField(inhibitoryHistory.L5Read, historyCount);
end

function slicedField = iSliceHistoryField(historyField, historyCount)
if ndims(historyField) <= 2
	slicedField = historyField(:, 1:historyCount);
else
	slicedField = historyField(:, :, 1:historyCount);
end
end
