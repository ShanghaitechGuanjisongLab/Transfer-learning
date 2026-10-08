function Tbl = QueryZScoreNts(DS, Mouse, Stimulus)
% Z-scored trial x cell signal table for one mouse and one stimulus type.
%
% Pipeline identical to 信息编码/CueModel_TransferAudioToLight.m's local
% iQueryZScoreNts (and thus to the English Fig3D pipeline):
%   TableQuery(ResampledSignal) -> drop bad rows -> row-wise z-score over the
%   full trace. Equivalent to DS.QueryNTS with UniExp.Flags.ZScore, but tolerant
% of cells outside the registration range (those rows make QueryNTS throw).
%
% Dropped rows: any-NaN rows and all-zero rows (cells not registered).
%
% Input:
%   DS       - UniExp.DataSet
%   Mouse    - mouse name (char/string)
%   Stimulus - trial stimulus name, e.g. 'AudioOnly' / 'AudioWater'
%
% Output (empty table when the mouse has no such trial):
%   Tbl.CellUID     (uint64, rows)
%   Tbl.TrialUID    (uint64, rows)
%   Tbl.TrialSignal (rows x time, row-wise z-scored)
%   Tbl.Behavior
%   Tbl.BlockUID

	arguments
		DS (1,1) UniExp.DataSet
		Mouse {mustBeTextScalar}
		Stimulus {mustBeTextScalar}
	end

	T = DS.TableQuery(["ResampledSignal", "CellUID", "TrialUID", "Behavior", "BlockUID"], ...
		struct('Mouse', char(Mouse), 'Stimulus', char(Stimulus)));
	if isempty(T) || height(T) == 0
		Tbl = table();
		return;
	end
	Sig = T.ResampledSignal;
	if iscell(Sig)
		Sig = double(vertcat(Sig{:}));
	else
		Sig = double(Sig);
	end
	Bad = any(isnan(Sig), 2) | all(Sig == 0, 2);
	if any(Bad)
		fprintf('    %s %-10s dropped %d bad rows (cells out of registration)\n', ...
			char(Mouse), char(Stimulus), sum(Bad));
		Sig(Bad, :) = [];
		T(Bad, :) = [];
	end
	if height(T) == 0
		Tbl = table();
		return;
	end
	Mu = mean(Sig, 2);
	Sd = std(Sig, 0, 2);
	Sd(Sd == 0) = 1;
	Sig = (Sig - Mu) ./ Sd;
	Tbl = table(uint64(T.CellUID), uint64(T.TrialUID), Sig, ...
		'VariableNames', {'CellUID', 'TrialUID', 'TrialSignal'});
	Tbl.Behavior = T.Behavior;
	Tbl.BlockUID = T.BlockUID;
end
