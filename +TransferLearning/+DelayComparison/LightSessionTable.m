function T = LightSessionTable(DS, Stimuli, StartPhase, EndPhase)
%LIGHTSESSIONTABLE Per-session hit rate for light-cue learning trials.
%   T = LightSessionTable(DS, Stimuli) keeps every session containing at
%   least one trial whose Stimulus is in Stimuli.
%   T = LightSessionTable(DS, Stimuli, StartPhase, EndPhase) additionally
%   keeps, per mouse, the sessions from the first StartPhase session through
%   the matching EndPhase session (or through the last session when the
%   EndPhase session does not exist).
%
%   Columns: Mouse, DateTime, Performance, NTrial, Phase.
arguments
	DS
	Stimuli (1,:) string
	StartPhase (1,1) string = ""
	EndPhase (1,1) string = ""
end

vars = ["Mouse","DateTime","Stimulus","Behavior"];
try
	R = DS.TableQuery([vars, "Phase"], Stimulus=Stimuli);
catch
	R = DS.TableQuery(vars, Stimulus=Stimuli);
	R.Phase = repmat("", height(R), 1);
end
if isempty(R)
	T = table(strings(0,1), NaT(0,1), nan(0,1), zeros(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NTrial','Phase'});
	return;
end

R.Mouse = string(R.Mouse);
R.Stimulus = string(R.Stimulus);
R.Phase = string(R.Phase);
R.Phase(ismissing(R.Phase)) = "";
R.DateTime = iNormalizeDateTime(R.DateTime);
R = R(ismember(R.Stimulus, Stimuli), :);

[G, mouseList, dtList] = findgroups(R.Mouse, R.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), R.Behavior, G);
nTrial = splitapply(@(x) sum(isfinite(double(x))), R.Behavior, G);
phase = splitapply(@iMainPhase, R.Phase, G);

T = table(mouseList, dtList, perf, nTrial, phase, ...
	'VariableNames', {'Mouse','DateTime','Performance','NTrial','Phase'});
T = sortrows(T, {'Mouse','DateTime'});

if StartPhase ~= ""
	T = iKeepPhaseRange(T, StartPhase, EndPhase);
end
end

function T = iKeepPhaseRange(T, startPhase, endPhase)
mice = unique(T.Mouse);
keep = false(height(T), 1);
for i = 1:numel(mice)
	idx = find(T.Mouse == mice(i));
	ph = T.Phase(idx);
	st = find(ph == startPhase, 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == endPhase & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keep(idx(st:ed)) = true;
end
T = T(keep, :);
end

function ph = iMainPhase(phases)
phases = string(phases);
phases = phases(phases ~= "");
if isempty(phases)
	ph = "";
	return;
end
[u, ~, ic] = unique(phases);
counts = accumarray(ic, 1);
[~, ix] = max(counts);
ph = u(ix);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end
