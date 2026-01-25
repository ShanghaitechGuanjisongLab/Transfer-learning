function rows = iBuildNVST_CellCorr_Sessions_1s_1p5s_ByLayer()
% Build session-level CellCorr(1s,1.5s) table for Fig3.2e/f.
%
% Operational definition (matches legacy Scratch implementation):
% - For each session (Mouse+DateTime), Stimulus==LightWater, compute:
%     v1 = Median NTATS ZScore across cells at t≈1s
%     v2 = Median NTATS ZScore across cells at t≈1.5s
%     CellCorr_1s1p5s = corr(v1, v2, 'Type','Pearson', 'Rows','complete')
% - Exclude mixed sessions: drop LightWater sessions that also contain any AudioWater trials.
% - Naive group: Phase==Naive, from LightAudioBaseline + LAInterspersed.
% - Transfer group: Phase==Transfer, from AudioLightBaseline.
%
% Returns:
%   rows table with variables:
%     Mouse, DateTime, Group, Source, ZLayer, NCells, CellCorr_1s1p5s
%
% Execution:
%   TransferLearning.Fig32.iBuildNVST_CellCorr_Sessions_1s_1p5s_ByLayer

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

xsSec = seconds(TransferLearning.Xs);
[dtMin1, idx1] = min(abs(xsSec - 1));
[dtMin2, idx2] = min(abs(xsSec - 1.5));
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig32:iBuildNVST_CellCorr_1s1p5:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end
if isempty(idx2) || ~isfinite(dtMin2) || dtMin2 > 0.25
	error('Fig32:iBuildNVST_CellCorr_1s1p5:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end

layerNames = string(["AllCells","MOp2/3","MOp5"]);

rows = table;
rows = [rows; iCollectSessionsWithCorr(LAB, "LightAudioBaseline", "Naive", idx1, idx2, layerNames)];
rows = [rows; iCollectSessionsWithCorr(LAI, "LAInterspersed",     "Naive", idx1, idx2, layerNames)];
rows = [rows; iCollectSessionsWithCorr(ALB, "AudioLightBaseline", "Transfer", idx1, idx2, layerNames)];

rows.Mouse = string(rows.Mouse);
rows.Group = string(rows.Group);
rows.Source = string(rows.Source);
rows.ZLayer = string(rows.ZLayer);
rows = sortrows(rows, {'ZLayer','Group','Mouse','DateTime'});

end

%% --- local helpers

function out = iCollectSessionsWithCorr(DS, sourceName, phaseName, idx1, idx2, layerNames)
	out = table(string.empty(0,1), NaT(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Group','Source','ZLayer','NCells','CellCorr_1s1p5s'});

	T = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Phase","Stimulus"], Stimulus="LightWater");
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Phase = string(T.Phase);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = T(T.Phase==string(phaseName), :);
	if isempty(T)
		return;
	end

	Sess = unique(T(:,{'Mouse','DateTime'}), 'rows');
	Sess = iDropMixedSessions(DS, Sess);
	for i = 1:height(Sess)
		mouse = string(Sess.Mouse(i));
		dt = Sess.DateTime(i);
		for j = 1:numel(layerNames)
			zl = string(layerNames(j));
			[r, nCell] = iCellCorrSession(DS, mouse, dt, idx1, idx2, zl);
			out = [out; table(mouse, dt, string(phaseName), string(sourceName), zl, nCell, r, ...
				'VariableNames', out.Properties.VariableNames)]; %#ok<AGROW>
		end
	end
end

function Sess = iDropMixedSessions(DS, Sess)
	Ta = iTableQueryOrEmpty(DS, ["Mouse","DateTime","Stimulus"], Stimulus="AudioWater");
	if isempty(Ta) || isempty(Sess)
		return;
	end
	Ta.Mouse = string(Ta.Mouse);
	Ta.DateTime = iNormalizeDateTime(Ta.DateTime);
	badKey = unique(Ta.Mouse + "|" + string(Ta.DateTime,'yyyy-MM-dd HH:mm:ss'));
	key = string(Sess.Mouse) + "|" + string(iNormalizeDateTime(Sess.DateTime),'yyyy-MM-dd HH:mm:ss');
	Sess = Sess(~ismember(key, badKey), :);
end

function [r, nCell] = iCellCorrSession(DS, mouse, dt, idx1, idx2, zLayer)
	r = NaN; nCell = NaN;
	try
		q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
			return;
		end
		M = iNtatsData(G.NTATS);
		v1 = double(M(:, idx1));
		v2 = double(M(:, idx2));
		mask = isfinite(v1) & isfinite(v2);

		if string(zLayer) ~= "AllCells"
			uid = uint64(G.CellUID);
			C = DS.Cells;
			C.CellUID = uint64(C.CellUID);
			CZ = innerjoin(table(uid, 'VariableNames', {'CellUID'}), C(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
			zl = string(CZ.ZLayer);
			mask = mask & (zl == string(zLayer));
		end

		nCell = nnz(mask);
		if nCell < 3 || std(v1(mask))==0 || std(v2(mask))==0
			r = NaN;
			return;
		end
		r = corr(v1(mask), v2(mask), 'Type','Pearson');
	catch
		r = NaN; nCell = NaN;
	end
end

function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	if ismember('DateTime', T.Properties.VariableNames)
		T.DateTime = iNormalizeDateTime(T.DateTime);
	end
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function dt = iNormalizeDateTime(dt)
	try
		dt = datetime(dt);
		if isdatetime(dt) && ~isempty(dt.TimeZone)
			dt.TimeZone = '';
		end
	catch
	end
end
