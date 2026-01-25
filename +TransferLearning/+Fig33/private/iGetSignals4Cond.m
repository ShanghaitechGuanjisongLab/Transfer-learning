function [S0, S1, S2, S3] = iGetSignals4Cond(Ts, cellUID, tuNaive, tuLearn, tuHit, tuMiss)
% One-pass extraction from TrialSignals for a single cell
cellUID = uint64(cellUID);
tuNaive = uint64(tuNaive(:));
tuLearn = uint64(tuLearn(:));
tuHit = uint64(tuHit(:));
tuMiss = uint64(tuMiss(:));
allUID = unique([tuNaive; tuLearn; tuHit; tuMiss]);
mask = (uint64(Ts.CellUID) == cellUID) & ismember(uint64(Ts.TrialUID), allUID);
if ~any(mask)
	S0 = []; S1 = []; S2 = []; S3 = [];
	return;
end
uid = uint64(Ts.TrialUID(mask));
sig = double(Ts.ResampledSignal(mask, :));
S0 = sig(ismember(uid, tuNaive), :);
S1 = sig(ismember(uid, tuLearn), :);
S2 = sig(ismember(uid, tuHit), :);
S3 = sig(ismember(uid, tuMiss), :);
end
