function [perMouse, pSlopeAdj] = iPerMouseSlopeAdj(Sess, groupPair)
% Compute per-mouse growth slope with baseline adjustment (Fig3.1d style).
%
% Inputs
%   Sess: table with at least Mouse, Group, DateTime, Performance.
%         Session index will be recomputed per mouse after filtering.
%   groupPair (optional): string(1,2) specifying the two groups to compare.
%         If omitted, uses the two unique groups found in perMouse.Group.
%
% Outputs
%   perMouse: table with Mouse, Group, Slope, SlopeAdj, BaselinePerf, NSessions
%   pSlopeAdj: ranksum p-value comparing SlopeAdj between the two groups.

if nargin < 2
	groupPair = strings(0,2);
end

perMouse = table();
pSlopeAdj = NaN;
if isempty(Sess)
	return;
end

need = {"Mouse","Group","DateTime","Performance"};
for k = 1:numel(need)
	if ~ismember(need{k}, Sess.Properties.VariableNames)
		error('Fig34:iPerMouseSlopeAdj:MissingVar', 'Missing variable %s', need{k});
	end
end

T = Sess(:, intersect(Sess.Properties.VariableNames, {'Mouse','Group','DateTime','Performance'}, 'stable'));
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T.DateTime = TransferLearning.Fig34.iNormalizeDateTime(T.DateTime);
T.Performance = double(T.Performance);
T = sortrows(T, {'Group','Mouse','DateTime'});

% Apply Fig3.3-style filtering per mouse: drop 0, trim ceiling segment,
% remove last step into ceiling, keep 0<Perf<1.
T = iFilter0AndCeiling(T);
if isempty(T)
	return;
end

% Re-index sessions within each mouse
[G, ~] = findgroups(T.Group, T.Mouse);
T.Session = zeros(height(T), 1);
ug = unique(G);
for gi = 1:numel(ug)
	rows = (G == ug(gi));
	T.Session(rows) = (1:sum(rows)).';
end

mice = unique(T.Mouse);
slopes = nan(numel(mice), 1);
b0 = nan(numel(mice), 1);
ns = nan(numel(mice), 1);
grp = strings(numel(mice), 1);

for i = 1:numel(mice)
	m = mice(i);
	Sm = T(T.Mouse == m, :);
	if isempty(Sm)
		continue;
	end
	Sm = sortrows(Sm, 'Session');
	grp(i) = string(Sm.Group(1));
	x = double(Sm.Session);
	y = double(Sm.Performance);
	ok = isfinite(x) & isfinite(y);
	x = x(ok);
	y = y(ok);
	ns(i) = numel(x);
	if isempty(y)
		continue;
	end
	b0(i) = y(1);
	if numel(x) < 2
		continue;
	end
	p = polyfit(x, y, 1);
	slopes(i) = p(1);
end

perMouse = table(mice, grp, slopes, ns, b0, 'VariableNames', {'Mouse','Group','Slope','NSessions','BaselinePerf'});

% Baseline-adjust like Fig3.1d: residualize slope against baseline perf
perMouse.SlopeAdj = nan(height(perMouse), 1);
okAdj = isfinite(perMouse.Slope) & isfinite(perMouse.BaselinePerf);
if any(okAdj)
	if exist('robustfit','file')
		b = robustfit(double(perMouse.BaselinePerf(okAdj)), double(perMouse.Slope(okAdj)));
		perMouse.SlopeAdj(okAdj) = double(perMouse.Slope(okAdj)) - (b(1) + b(2) * double(perMouse.BaselinePerf(okAdj)));
	else
		adjMdl = fitlm(perMouse(okAdj, :), 'Slope ~ 1 + BaselinePerf');
		perMouse.SlopeAdj(okAdj) = adjMdl.Residuals.Raw;
	end
end

% Compute ranksum p
if isempty(groupPair)
	gs = unique(string(perMouse.Group));
	if numel(gs) == 2
		groupPair = gs(:)';
	end
end

if ~isempty(groupPair) && size(groupPair,2) == 2
	g1 = string(groupPair(1));
	g2 = string(groupPair(2));
	x1 = perMouse.SlopeAdj(string(perMouse.Group) == g1);
	x2 = perMouse.SlopeAdj(string(perMouse.Group) == g2);
	x1 = x1(isfinite(x1));
	x2 = x2(isfinite(x2));
	if ~isempty(x1) && ~isempty(x2)
		pSlopeAdj = ranksum(x1, x2);
	end
end

end

function T = iFilter0AndCeiling(T)
% Per mouse: drop Perf==0; trim from first Perf==1 onward, plus last step into ceiling.
if isempty(T)
	return;
end

zTol = 1e-12;
oneTol = 1 - 1e-12;

T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
ug = unique(G);
out = cell(numel(ug), 1);

for gi = 1:numel(ug)
	rows = (G == ug(gi));
	S = T(rows, :);
	S = sortrows(S, 'DateTime');
	perf = double(S.Performance);

	% 1) Drop Perf==0
	keep = isfinite(perf) & (perf > zTol);
	S = S(keep, :);
	perf = perf(keep);
	if height(S) < 2
		continue;
	end

	% 2) Trim ceiling segment and the last step into ceiling
	i100 = find(isfinite(perf) & (perf >= oneTol), 1, 'first');
	if ~isempty(i100)
		if i100 <= 2
			continue;
		end
		S = S(1:i100-2, :);
		perf = perf(1:i100-2);
	end
	if height(S) < 2
		continue;
	end

	% 3) Enforce (0,1)
	keep2 = isfinite(perf) & (perf > zTol) & (perf < oneTol);
	S = S(keep2, :);
	if height(S) < 2
		continue;
	end

	out{gi} = S;
end

out = out(~cellfun('isempty', out));
if isempty(out)
	T = table();
	return;
end

T = vertcat(out{:});
T = sortrows(T, {'Group','Mouse','DateTime'});
end
