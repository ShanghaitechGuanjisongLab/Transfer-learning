% Prototype: render the inter-trial divergence as a low-dimensional geometry
%
% The divergence used throughout is
%     div = sqrt( sum_c var_t(X_ct) / sum_c mean_t(X_ct)^2 )        (cue +1 s)
% i.e. it is the norm of the trial-to-trial fluctuation of the population vector
% divided by the norm of the mean population vector. That ratio has a direct 2-D
% picture: plot the trial residuals r_t = x_t - mean(x) in a plane whose first
% axis is the mean direction e1 = mean(x)/|mean(x)| and whose second axis is the
% first principal component of the residuals (orthogonalised to e1), all divided
% by |mean(x)|. The root-mean-square radius of that cloud equals the divergence,
% so the geometry and the scalar are the same quantity.
%
% Output: one figure, one panel per cohort; each mouse contributes its own cloud
% (dots = trials), so the fan/parallel impression is visible per mouse and the
% numbers are comparable across cohorts.

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
xsSec = squeeze(xsSec);
[~, idx1s] = min(abs(xsSec - 1));
baseMask = (xsSec >= -3) & (xsSec < 0);

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
V7 = TransferLearning.Vacation7();

Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
Sess.Mouse = string(Sess.Mouse);
Sess.Source = string(Sess.Source);
first = Sess(Sess.Session == 1, :);

srcName = ["LightAudioBaseline", "LAInterspersed", "AudioLightBaseline", "Vacation7"];
srcDS = {LAB, LAI, ALB, V7};
groupOrder = ["Naive", "Transfer", "7dayTransfer"];
groupColor = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

Cloud = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
	'VariableNames', {'Group','Mouse','Div','RmsRadius','BoxRatio','ThetaMean'});

for i = 1:height(first)
	m = first.Mouse(i);
	dt = first.DateTime(i);
	ph = first.Phase(i);
	src = first.Source(i);
	k = find(srcName == src, 1);
	if isempty(k), continue; end
	DS = srcDS{k};

	[X, ok] = iTrialMatrixAt1s(DS, m, dt, ph, idx1s);
	if ~ok, continue; end
	mv = mean(X, 2, 'omitnan');
	r = X - mv;
	okTrial = all(isfinite(r), 1);
	r = r(:, okTrial);
	if size(r, 2) < 3, continue; end

	div = sqrt(sum(var(X(:, okTrial), [], 2), 'omitnan') / sum(mv.^2, 'omitnan'));

	% 2-D basis: e1 along the mean vector, e2 = leading residual direction
	e1 = mv / norm(mv);
	[U, ~, ~] = svd(r, 'econ');
	e2 = U(:, 1);
	e2 = e2 - (e2' * e1) * e1;
	if norm(e2) < eps
		e2 = U(:, min(2, size(U, 2)));
		e2 = e2 - (e2' * e1) * e1;
	end
	e2 = e2 / norm(e2);
	scale = norm(mv);
	z1 = (r' * e1) / scale;
	z2 = (r' * e2) / scale;

	rms = sqrt(mean(z1.^2 + z2.^2));
	boxRatio = (prctile(z2, 75) - prctile(z2, 25)) / max(eps, prctile(z1, 75) - prctile(z1, 25));

	% direction of each trial relative to the block mean vector: cos(theta). The
	% divergence is a monotone function of this angle (div ~ sqrt(2(1-cos))), so the
	% angular spread is the same statement as the divergence, just more readable.
	cs = (mv' * X(:, okTrial)) ./ (norm(mv) .* vecnorm(X(:, okTrial)));
	cs = min(max(cs, -1), 1);
	thetaDeg = acosd(cs);
	thetaDeg = thetaDeg(:);

	% Convergence of the running mean across trials: how far the mean of the
	% first k trials still is from the mean of the whole block, normalised by the
	% block mean. Large and slowly decaying in naive, small and flat in transfer.
	Xk = X(:, okTrial);
	T = size(Xk, 2);
	converge = nan(T, 1);
	for kk = 2:T
		mk = mean(Xk(:, 1:kk), 2, 'omitnan');
		converge(kk) = norm(mk - mv) / norm(mv);
	end

	Cloud = [Cloud; table(first.Group(i), m, div, rms, boxRatio, mean(thetaDeg), ...
		'VariableNames', Cloud.Properties.VariableNames)]; %#ok<AGROW>
	assignin('base', sprintf('TH_%d', height(Cloud)), thetaDeg); %#ok<NASGU,AGROW>
	assignin('base', sprintf('CV_%d', height(Cloud)), converge); %#ok<NASGU,AGROW>
end

fprintf('\n=== divergence and running-mean convergence ===\n');
fprintf('%-14s %-10s %7s %7s %9s %9s %9s\n', 'Group', 'Mouse', 'div', 'rms2D', 'thetaDeg', 'c(k=5)', 'c(k=15)');
for i = 1:height(Cloud)
	th = evalin('base', sprintf('TH_%d', i));
	cv = evalin('base', sprintf('CV_%d', i));
	fprintf('%-14s %-10s %7.3f %7.3f %9.1f %9.3f %9.3f\n', Cloud.Group(i), Cloud.Mouse(i), ...
		Cloud.Div(i), Cloud.RmsRadius(i), Cloud.ThetaMean(i), cv(5), cv(15));
end

f = figure('Color', 'w', 'Name', 'Trial-to-trial convergence of the population response');
f.Units = 'centimeters';
f.Position(3:4) = [22, 8];
tlo = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

%% panel 1: convergence curves
ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
curves = cell(1, numel(groupOrder));
Tmin = 30;
for g = 1:numel(groupOrder)
	idx = find(Cloud.Group == groupOrder(g));
	M = nan(numel(idx), 30);
	for k = 1:numel(idx)
		cv = evalin('base', sprintf('CV_%d', idx(k)));
		cv = cv(:).';
		nn = min(numel(cv), 30);
		M(k, 1:nn) = cv(1:nn);
		if nn < Tmin, Tmin = nn; end
	end
	curves{g} = M;
end
kShow = 2:Tmin;
for g = 1:numel(groupOrder)
	M = curves{g};
	medC = median(M(:, kShow), 1, 'omitnan');
	q25 = prctile(M(:, kShow), 25);
	q75 = prctile(M(:, kShow), 75);
	patch(ax1, [kShow, fliplr(kShow)], [q25, fliplr(q75)], groupColor(g, :), ...
		'FaceAlpha', 0.13, 'EdgeColor', 'none');
	plot(ax1, kShow, medC, '-', 'Color', groupColor(g, :), 'LineWidth', 2.0);
end
xlabel(ax1, 'Trials accumulated within the first light-water block');
ylabel(ax1, '||mean(k) - mean(all)|| / ||mean(all)||');
xlim(ax1, [2, Tmin]);
ylim(ax1, [0, 3.4]);
title(ax1, 'Convergence within the first light-water block', 'FontWeight', 'normal', 'FontSize', 9);
legend(ax1, {'Naive', 'Transfer (12 h)', 'Transfer (7 d)'}, 'Box', 'off', 'Location', 'northeast', 'FontSize', 7);
box(ax1, 'off');

%% panel 2: per-mouse value at k = 5
ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
kEval = 5;
vals = cell(1, numel(groupOrder));
for g = 1:numel(groupOrder)
	idx = find(Cloud.Group == groupOrder(g));
	v = zeros(numel(idx), 1);
	for k = 1:numel(idx)
		cv = evalin('base', sprintf('CV_%d', idx(k)));
		v(k) = cv(kEval);
	end
	vals{g} = v;
	x = g + 0.16 * (rand(size(v)) - 0.5);
	scatter(ax2, x, v, 14, groupColor(g, :), 'filled', 'MarkerFaceAlpha', 0.75);
	plot(ax2, g + [-0.28, 0.28], median(v) * [1 1], '-', 'Color', groupColor(g, :) * 0.7, 'LineWidth', 2);
end
pT1 = ranksum(vals{1}, vals{2});
pT2 = ranksum(vals{2}, vals{3});
set(ax2, 'XTick', 1:3, 'XTickLabel', {'Naive', '12 h', '7 d'}, 'FontSize', 8, 'TickDir', 'out');
xlim(ax2, [0.5, 3.5]);
ylim(ax2, [0.8, 2.6]);
ylabel(ax2, 'relative deviation at k = 5');
title(ax2, sprintf('Convergence at k = 5 (naive-12 h p = %.2g; 12 h-7 d p = %.2g)', pT1, pT2), ...
	'FontWeight', 'normal', 'FontSize', 9);
box(ax2, 'off');

fprintf('\nConvergence at k = 5: Naive %.2f, 12 h %.2f, 7 d %.2f\n', ...
	median(vals{1}), median(vals{2}), median(vals{3}));

outDir = fileparts(mfilename('fullpath'));
figPath = fullfile(outDir, 'Fig2_DivergenceManifold.fig');
savefig(f, figPath);
fprintf('Saved: %s\n', figPath);

assignin('base', 'DivManifold_Cloud', Cloud);

%% ------------------------------------------------------------------
function [X, ok] = iTrialMatrixAt1s(DS, mouse, dt, phase, idx1s)
X = [];
ok = false;
q = table(categorical(string(mouse)), dt, "LightWater", ...
	'VariableNames', {'Mouse','DateTime','Stimulus'});
try
	res = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime","Mouse"]);
catch
	return;
end
raw = iCollapse(res);
if isempty(raw), return; end
raw.CellUID = uint64(raw.CellUID);
raw.TrialUID = uint64(raw.TrialUID);

Tq = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Phase","Stimulus"]);
Tq.Mouse = string(Tq.Mouse);
Tq.Phase = string(Tq.Phase);
Tq.Stimulus = string(Tq.Stimulus);
Tq.DateTime = iNormDT(datetime(Tq.DateTime));
dt = iNormDT(dt);
sel = Tq.Mouse == string(mouse) & Tq.DateTime == dt & Tq.Stimulus == "LightWater";
trialUIDs = unique(uint64(Tq.TrialUID(sel)), 'stable');
if numel(trialUIDs) < 3, return; end

allCells = unique(raw.CellUID);
keep = cell(numel(allCells), 1);
n = 0;
for iC = 1:numel(allCells)
	rows = raw.CellUID == allCells(iC);
	uid = raw.TrialUID(rows);
	sig = double(raw.TrialSignal(rows, idx1s));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf) || any(~isfinite(sig(loc)))
		continue;
	end
	n = n + 1;
	keep{n} = sig(loc);
end
if n < 3, return; end
X = zeros(n, numel(trialUIDs));
for iC = 1:n
	X(iC, :) = keep{iC}(:).';
end
ok = true;
end

function dt = iNormDT(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function tbl = iCollapse(res)
tbl = table();
if isempty(res), return; end
if istable(res)
	tbl = res;
elseif isstruct(res)
	tbl = struct2table(res);
elseif iscell(res)
	parts = res(~cellfun(@isempty, res));
	if isempty(parts)
		return;
	end
	if istable(parts{1})
		tbl = vertcat(parts{:});
	elseif isstruct(parts{1})
		asTbl = cellfun(@struct2table, parts, 'UniformOutput', false);
		tbl = vertcat(asTbl{:});
	end
end
end
