% ALInterspersed (audio-water -> light-water, INTERLEAVED arm): session / mouse tables
%
% Only tables, no figure. Purpose: document the interleaved design precisely
% (how many AW and LW blocks per session, whether they are mixed within a
% session, when LW performance crosses 50%), so that it can later serve as the
% dt ~ 0 point of Fig 1E.
%
% Outputs (CSV, written next to this file):
%   - ALInterspersed_SessionTable.csv
%   - ALInterspersed_MouseTable.csv
%
% NOTE on phases: this dataset labels only Naive / Learned / Transfer / Final;
% the intermediate AW-learning sessions carry an empty phase and appear as
% "undefined" here.

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');
warning('off', 'UniExp:Exception:No_TagPeaks_found');
warning('off', 'UniExp:Exception:Split_trials_less_than_existing_Trials');
warning('off', 'UniExp:Exception:Split_trials_more_than_existing_Trials');

DS = TransferLearning.ALInterspersed();

Tq = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","BlockIndex"]);
Tq.Mouse = string(Tq.Mouse);
Tq.Stimulus = string(Tq.Stimulus);
Tq.Phase = string(Tq.Phase);
Tq.Phase(ismissing(Tq.Phase) | strlength(Tq.Phase) == 0) = "undefined";

[key, ~, g] = unique(Tq(:, ["Mouse","DateTime"]), 'rows');
nS = height(key);

Sess = table(strings(nS,1), NaT(nS,1), strings(nS,1), zeros(nS,1), zeros(nS,1), zeros(nS,1), ...
	zeros(nS,1), zeros(nS,1), zeros(nS,1), false(nS,1), nan(nS,1), nan(nS,1), zeros(nS,1), ...
	strings(nS,1), ...
	'VariableNames', {'Mouse','DateTime','Phase','NBlocks','NAW','NLW','NAO','NLO','NWO', ...
	'IsMixed','LW_hit','AW_hit','SessionIndex','BlockOrder'});

for i = 1:nS
	m = g == i;
	Sess.Mouse(i) = key.Mouse(i);
	Sess.DateTime(i) = key.DateTime(i);
	ph = unique(Tq.Phase(m));
	Sess.Phase(i) = strjoin(cellstr(ph(:))', '/');
	Sess.NBlocks(i) = nnz(m);
	st = Tq.Stimulus(m);
	Sess.NAW(i) = nnz(st == "AudioWater");
	Sess.NLW(i) = nnz(st == "LightWater");
	Sess.NAO(i) = nnz(st == "AudioOnly");
	Sess.NLO(i) = nnz(st == "LightOnly");
	Sess.NWO(i) = nnz(st == "WaterOnly");
	Sess.IsMixed(i) = Sess.NAW(i) > 0 && Sess.NLW(i) > 0;
	Sess.LW_hit(i) = mean(Tq.Behavior(m & Tq.Stimulus == "LightWater"), 'omitnan');
	Sess.AW_hit(i) = mean(Tq.Behavior(m & Tq.Stimulus == "AudioWater"), 'omitnan');
	Sess.SessionIndex(i) = nnz(Sess.Mouse(1:i) == key.Mouse(i));
	% block order pattern (first 10 blocks of the session, in BlockIndex order)
	idx = find(m);
	stAll = Tq.Stimulus(idx);
	[~, ord] = sort(double(Tq.BlockIndex(idx)));
	seq = stAll(ord);
	seq = seq(seq == "AudioWater" | seq == "LightWater");
	if isempty(seq)
		Sess.BlockOrder(i) = "probe";
	else
		nShow = min(10, numel(seq));
		tok = repmat("A", nShow, 1);
		tok(seq(1:nShow) == "LightWater") = "L";
		Sess.BlockOrder(i) = strjoin(cellstr(tok)', '');
	end
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(Sess.Mouse, 'stable');
MouseT = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), zeros(0,1), 'VariableNames', ...
	{'Mouse','NSessions','NAW_learning','NInterleaved','FirstLW_hit','BestLW_hit','LastLW_hit', ...
	'LW_sessionsTo50','NCells'});
for i = 1:numel(mice)
	mi = mice(i);
	S = Sess(Sess.Mouse == mi, :);
	awLearn = S.NAW > 0 & S.NLW == 0 & S.AW_hit < 0.999;
	inter = S.IsMixed;
	lwSessions = S(S.NLW > 0, :);
	firstLW = NaN; bestLW = NaN; lastLW = NaN; to50 = NaN;
	if ~isempty(lwSessions)
		firstLW = lwSessions.LW_hit(1);
		bestLW = max(lwSessions.LW_hit);
		lastLW = lwSessions.LW_hit(end);
		i50 = find(lwSessions.LW_hit >= 0.5, 1, 'first');
		if ~isempty(i50)
			to50 = i50;
		end
	end
	nCell = nnz(string(DS.Cells.Mouse) == mi);
	MouseT = [MouseT; table(mi, height(S), nnz(awLearn), nnz(inter), firstLW, bestLW, lastLW, ...
		to50, nCell, 'VariableNames', MouseT.Properties.VariableNames)]; %#ok<AGROW>
end

fprintf('\n=== ALInterspersed: session table (%d sessions) ===\n', height(Sess));
fprintf('%-8s %-16s %-9s %4s %3s %3s %3s %3s %3s %4s %6s %6s %6s\n', ...
	'Mouse','DateTime','Phase','Blk','AW','LW','AO','LO','WO','mix','LW_hit','AW_hit','order');
for i = 1:height(Sess)
	fprintf('%-8s %-16s %-9s %4d %3d %3d %3d %3d %3d %4d %6.2f %6.2f %6s\n', ...
		Sess.Mouse(i), string(Sess.DateTime(i), 'yyyy-MM-dd HH:mm'), Sess.Phase(i), ...
		Sess.NBlocks(i), Sess.NAW(i), Sess.NLW(i), Sess.NAO(i), Sess.NLO(i), Sess.NWO(i), ...
		Sess.IsMixed(i), Sess.LW_hit(i), Sess.AW_hit(i), Sess.BlockOrder(i));
end

fprintf('\n=== mouse table ===\n');
for i = 1:height(MouseT)
	fprintf('%-8s sessions=%2d  AWlearn=%d  interleaved=%2d  firstLW=%.2f  best=%.2f  last=%.2f  to50=%s  cells=%d\n', ...
		MouseT.Mouse(i), MouseT.NSessions(i), MouseT.NAW_learning(i), MouseT.NInterleaved(i), ...
		MouseT.FirstLW_hit(i), MouseT.BestLW_hit(i), MouseT.LastLW_hit(i), ...
		string(MouseT.LW_sessionsTo50(i)), MouseT.NCells(i));
end

outDir = fileparts(mfilename('fullpath'));
writetable(Sess, fullfile(outDir, 'ALInterspersed_SessionTable.csv'));
writetable(MouseT, fullfile(outDir, 'ALInterspersed_MouseTable.csv'));
fprintf('\nWrote:\n  %s\n  %s\n', fullfile(outDir, 'ALInterspersed_SessionTable.csv'), ...
	fullfile(outDir, 'ALInterspersed_MouseTable.csv'));

assignin('base', 'ALInterspersed_Sess', Sess);
assignin('base', 'ALInterspersed_Mouse', MouseT);
