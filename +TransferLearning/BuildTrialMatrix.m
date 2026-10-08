function X = BuildTrialMatrix(RawTbl, CellUIDs)
% Build a trials x cells x time matrix from a QueryZScoreNts-style table.
%
% Identical to 信息编码/CueModel_TransferAudioToLight.m's local iBuildTrialMatrix,
% so a matrix built here is comparable to the English Fig3D decoder input.
%
% Input:
%   RawTbl   - table with CellUID / TrialUID / TrialSignal (rows x time)
%   CellUIDs - uint64 row vector fixing the cell order (columns of X)
%
% Output:
%   X (nTrials x nCells x nTime); rows ordered by ascending unique TrialUID.
%   (trial, cell) pairs absent from RawTbl stay 0. Empty when RawTbl holds no
%   cell of CellUIDs.

	RawTbl = RawTbl(:, ["CellUID", "TrialUID", "TrialSignal"]);
	RawTbl.CellUID = uint64(RawTbl.CellUID);
	RawTbl.TrialUID = uint64(RawTbl.TrialUID);
	Sig = double(RawTbl.TrialSignal);
	SigCell = cell(size(Sig, 1), 1);
	for i = 1:size(Sig, 1)
		SigCell{i} = Sig(i, :);
	end
	RawTbl.Signal = SigCell;
	RawTbl = RawTbl(ismember(RawTbl.CellUID, uint64(CellUIDs)), :);
	if isempty(RawTbl)
		X = [];
		return;
	end
	CellUIDs = uint64(CellUIDs);
	TU = unique(RawTbl.TrialUID);
	X = zeros(numel(TU), numel(CellUIDs), size(Sig, 2));
	for iT = 1:numel(TU)
		Rows = RawTbl(RawTbl.TrialUID == TU(iT), :);
		[~, Loc] = ismember(Rows.CellUID, CellUIDs);
		for iR = 1:height(Rows)
			ci = Loc(iR);
			if ci > 0
				X(iT, ci, :) = Rows.Signal{iR};
			end
		end
	end
end
