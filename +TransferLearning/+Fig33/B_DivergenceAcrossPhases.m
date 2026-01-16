% 图3.3b：散度 across phases（Naive/ Learned / Transfer / Final）
%
% Requirements (from user spec):
% - P-value comparisons:
%   1) NaiveLight vs TransferLight
%   2) NaiveAudio vs LearnedAudio
%   3) TransferLight vs FinalLight
% - Plotting:
%   - Use plot+marker to pair: NaiveAudio-LearnedAudio-TransferLight-FinalLight
%   - NaiveLight cannot be paired: use swarmchart; compare with TransferLight
% - Data sources:
%   - NaiveLight comes from LightAudioBaseline + LAInterspersed
%   - Other conditions come from AudioLightBaseline
% - Divergence per mouse per session:
%   - QueryNTS 1:24 DeltaF
%   - Take 1s sample
%   - sigma: for each cell, variance across all trials; then mean across cells; then sqrt
%   - centroid = mean over trials in cell-space (each trial is a point)
%   - dist0 = norm(centroid)
%   - divergence = sigma / dist0
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   IMPORTANT: MUST REMAIN A SCRIPT.
%   Call via package name:
%     TransferLearning.Fig33.B_DivergenceAcrossPhases

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3b_DivergenceAcrossPhases.svg";

% Optional: keep NaiveLight definition pure (no AudioWater in the same block)
excludeMixedAudioInNaiveLight = true;

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- 1) Load datasets
ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

xs = TransferLearning.Xs;
xsSec = seconds(xs);
[dtMin, idx1_ref] = min(abs(xsSec - 1));
if isempty(idx1_ref) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig3_3b:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end
nT_ref = numel(xsSec);

% --- 2) Compute divergence per mouse-session
rows = table();

% NaiveLight from LAB + LAI
rowsNaiveLight = table();
rowsNaiveLight = [rowsNaiveLight; iComputeConditionSessions(LAB, struct('Phase','Naive','Stimulus','LightWater'), "NaiveLight", "LightAudioBaseline", excludeMixedAudioInNaiveLight, idx1_ref, nT_ref)];
rowsNaiveLight = [rowsNaiveLight; iComputeConditionSessions(LAI, struct('Phase','Naive','Stimulus','LightWater'), "NaiveLight", "LAInterspersed", excludeMixedAudioInNaiveLight, idx1_ref, nT_ref)];
rows = [rows; rowsNaiveLight];

% Others from ALB
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Naive','Stimulus','AudioWater'),  "NaiveAudio",   "AudioLightBaseline", false, idx1_ref, nT_ref)];
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Learned','Stimulus','AudioWater'),"LearnedAudio", "AudioLightBaseline", false, idx1_ref, nT_ref)];
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Transfer','Stimulus','LightWater'),"TransferLight","AudioLightBaseline", false, idx1_ref, nT_ref)];
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Final','Stimulus','LightWater'),  "FinalLight",   "AudioLightBaseline", false, idx1_ref, nT_ref)];

rows.Mouse = string(rows.Mouse);
rows.Condition = string(rows.Condition);
rows.DataSet = string(rows.DataSet);

% Keep NaNs for diagnostics; filters happen at mouse-level / stats.

assignin('base', 'Fig3_3b_SessionRows', rows);

% --- 3) Reduce to one value per mouse per condition for paired plotting
mouseCond = iReduceToMouseLevel(rows);
assignin('base', 'Fig3_3b_MouseRows', mouseCond);

% Paired set for 4-phase line plot
wide4 = iPivot4(mouseCond);
assignin('base', 'Fig3_3b_PairedWide4', wide4);

% --- 4) Statistics (per mouse)
[p_naiveLight_vs_transfer, stats1] = iRanksum(mouseCond, "NaiveLight", "TransferLight");
[p_naiveAudio_vs_learned,  stats2] = iSignrank(mouseCond, "NaiveAudio", "LearnedAudio");
[p_transfer_vs_final,      stats3] = iSignrank(mouseCond, "TransferLight", "FinalLight");

statsSummary = table(p_naiveLight_vs_transfer, p_naiveAudio_vs_learned, p_transfer_vs_final, ...
	stats1.Z, stats2.Z, stats3.Z, ...
	'VariableNames', {'P_NaiveLight_vs_TransferLight','P_NaiveAudio_vs_LearnedAudio','P_TransferLight_vs_FinalLight', ...
	'Z_NaiveLight_vs_TransferLight','Z_NaiveAudio_vs_LearnedAudio','Z_TransferLight_vs_FinalLight'});
assignin('base','Fig3_3b_Stats', statsSummary);

% --- 5) Plot
f = figure('Name','Fig3.3b Divergence', 'Color','w');
ax = axes('Parent', f);
hold(ax,'on');
box(ax,'off');
grid(ax,'on');

xPos = struct('NaiveLight',1,'NaiveAudio',2,'LearnedAudio',3,'TransferLight',4,'FinalLight',5);
xticks(ax, 1:5);
xticklabels(ax, {'NaiveLight','NaiveAudio','LearnedAudio','TransferLight','FinalLight'});
xlim(ax, [0.5 5.5]);

% NaiveLight: swarmchart (unpaired)
yNL = iGet(mouseCond, "NaiveLight");
swarmchart(ax, repmat(xPos.NaiveLight, size(yNL)), yNL, 18, 'filled', 'MarkerFaceAlpha', 0.7);

% Paired 4-phase lines (NaiveAudio->LearnedAudio->TransferLight->FinalLight)
if ~isempty(wide4)
	for i = 1:height(wide4)
		y = [wide4.NaiveAudio(i), wide4.LearnedAudio(i), wide4.TransferLight(i), wide4.FinalLight(i)];
		x = [xPos.NaiveAudio, xPos.LearnedAudio, xPos.TransferLight, xPos.FinalLight];
		plot(ax, x, y, '-o', 'Color', [0.45 0.45 0.45], 'MarkerSize', 4, 'LineWidth', 1.0, ...
			'MarkerFaceColor', [0.45 0.45 0.45], 'MarkerEdgeColor', [0.45 0.45 0.45]);
	end
end

ylabel(ax, 'Divergence');

% annotate p-values (only the requested pairs)
iAnnotateP(ax, xPos.NaiveLight,   xPos.TransferLight, p_naiveLight_vs_transfer);
iAnnotateP(ax, xPos.NaiveAudio,   xPos.LearnedAudio,  p_naiveAudio_vs_learned);
iAnnotateP(ax, xPos.TransferLight,xPos.FinalLight,    p_transfer_vs_final);

% --- 6) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local functions

function out = iComputeConditionSessions(DS, q, condName, dsName, pureNaiveLight, idx1_ref, nT_ref)
	out = table(string.empty(0,1), NaT(0,1), string.empty(0,1), string.empty(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Condition','DataSet','NCells','NTrials','StdAll','CentroidToOrigin','Divergence'});

	T = iQuerySessionTrials(DS, q);
	if isempty(T) || height(T) == 0
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);

	% optional: keep NaiveLight blocks pure (no AudioWater in the same block)
	if pureNaiveLight
		pureMice = iFindPureNaiveLightWaterMice(DS);
		T = T(ismember(T.Mouse, pureMice), :);
		if isempty(T)
			return;
		end
	end

	[g, mKey, dtKey] = findgroups(T.Mouse, T.DateTime);
	sessN = splitapply(@numel, T.TrialUID, g);
	Sess = table(mKey, dtKey, sessN, 'VariableNames', {'Mouse','DateTime','NTrialRows'});
	Sess = sortrows(Sess, {'Mouse','DateTime'});

	for i = 1:height(Sess)
		m = string(Sess.Mouse(i));
		dt = Sess.DateTime(i);
		trialUID = unique(uint64(T.TrialUID(T.Mouse==m & T.DateTime==dt)));
		if numel(trialUID) < 3
			continue;
		end

		try
			[div, stdAll, dist0, nCell, nTrial] = iComputeSessionDivergence(DS, q, m, trialUID, idx1_ref, nT_ref);
		catch
			div = NaN; stdAll = NaN; dist0 = NaN; nCell = NaN; nTrial = NaN;
		end

		out = [out; table(m, dt, string(condName), string(dsName), nCell, nTrial, stdAll, dist0, div, ...
			'VariableNames', {'Mouse','DateTime','Condition','DataSet','NCells','NTrials','StdAll','CentroidToOrigin','Divergence'})]; %#ok<AGROW>
	end
end

function T = iQuerySessionTrials(DS, q)
	% Preferred: direct TrialUID per session
	try
		args = namedargs2cell(q);
		T = DS.TableQuery(["Mouse","DateTime","TrialUID"], args{:});
		return;
	catch
	end

	% Fallback: via BlockUID then Trials
	try
		args = namedargs2cell(rmfield(q, 'Stimulus'));
		Tb = DS.TableQuery(["Mouse","DateTime","BlockUID"], args{:});
		Tb.Mouse = string(Tb.Mouse);
		Tb.DateTime = iNormalizeDateTime(Tb.DateTime);
		Tr = DS.Trials;
		Tr.Stimulus = string(Tr.Stimulus);

		rows = table(string.empty(0,1), NaT(0,1), uint64.empty(0,1), 'VariableNames', {'Mouse','DateTime','TrialUID'});
		for i = 1:height(Tb)
			m = string(Tb.Mouse(i));
			dt = Tb.DateTime(i);
			b = uint64(Tb.BlockUID(i));
			trRows = (uint64(Tr.BlockUID)==b) & (Tr.Stimulus==string(q.Stimulus));
			tu = uint64(Tr.TrialUID(trRows));
			if isempty(tu)
				continue;
			end
			rows = [rows; table(repmat(m, numel(tu), 1), repmat(dt, numel(tu), 1), tu, ...
				'VariableNames', {'Mouse','DateTime','TrialUID'})]; %#ok<AGROW>
		end
		T = rows;
	catch
		T = table();
	end
end

function [div, stdAll, dist0, nCell, nTrial] = iComputeSessionDivergence(DS, q, mouse, trialUID, idx1_ref, nT_ref)
	q2 = q;
	q2.Mouse = mouse;
	if isfield(q2, 'DateTime')
		q2 = rmfield(q2, 'DateTime');
	end

	ntsCell = DS.QueryNTS(q2, UniExp.Flags.DeltaF, 1:24);
	nts = ntsCell{1};
	nts = nts(ismember(uint64(nts.TrialUID), uint64(trialUID)), :);
	if isempty(nts)
		div = NaN; stdAll = NaN; dist0 = NaN; nCell = NaN; nTrial = NaN; return;
	end

	nT = size(nts.TrialSignal, 2);
	if nT == nT_ref
		idx1 = idx1_ref;
	else
		xs2 = linspace(-3, 3, nT);
		[~, idx1] = min(abs(xs2 - 1));
	end

	v1 = nts.TrialSignal(:, idx1);
	cellU = unique(uint64(nts.CellUID));
	trialU = unique(uint64(nts.TrialUID));
	[~, cellIdx] = ismember(uint64(nts.CellUID), cellU);
	[~, trialIdx] = ismember(uint64(nts.TrialUID), trialU);

	Z = nan(numel(cellU), numel(trialU));
	lin = sub2ind(size(Z), cellIdx, trialIdx);
	Z = iAccumMean(Z, lin, v1);

	% sizes as defined by the queried ensemble for this session
	nCell = size(Z,1);
	nTrial = size(Z,2);
	if nCell < 2 || nTrial < 2
		div = NaN; stdAll = NaN; dist0 = NaN; return;
	end
	if ~any(isfinite(Z(:)))
		div = NaN; stdAll = NaN; dist0 = NaN; return;
	end

	% sigma definition (per updated spec):
	% 1) for each cell, compute variance across trials (omit NaNs)
	% 2) take mean variance across cells (omit NaNs)
	% 3) sqrt
	countPerCell = sum(isfinite(Z), 2);
	varPerCell = nan(size(Z,1), 1);
	for ii = 1:size(Z,1)
		if countPerCell(ii) >= 2
			zi = Z(ii, :);
			zi = zi(isfinite(zi));
			varPerCell(ii) = var(zi, 0);
		end
	end
	stdAll = sqrt(mean(varPerCell, 'omitnan'));
	centroid = mean(Z, 2, 'omitnan');
	dist0 = norm(centroid, 2);
	if dist0 <= 0 || ~isfinite(dist0)
		div = NaN;
	else
		div = stdAll / dist0;
	end
end

function mice = iFindPureNaiveLightWaterMice(DS)
	T = DS.TableQuery(["Mouse","BlockUID"], Phase="Naive", Stimulus="LightWater");
	T.Mouse = string(T.Mouse);
	BTu = unique(T(:, ["Mouse","BlockUID"]), 'rows');
	Tr = DS.Trials;
	Tr.Stimulus = string(Tr.Stimulus);

	allM = unique(BTu.Mouse);
	keep = false(size(allM));
	for i = 1:numel(allM)
		m = allM(i);
		rowsM = BTu.Mouse==m;
		bu = unique(uint64(BTu.BlockUID(rowsM)));
		hasAudio = false;
		for j = 1:numel(bu)
			b = bu(j);
			trB = (uint64(Tr.BlockUID) == b);
			if any(Tr.Stimulus(trB) == "AudioWater")
				hasAudio = true;
				break;
			end
		end
		keep(i) = ~hasAudio;
	end
	mice = allM(keep);
end

function dt = iNormalizeDateTime(dt)
	try
		if iscell(dt)
			dt = cellfun(@(x) x, dt);
		end
		if isduration(dt)
			dt = datetime(dt, 'ConvertFrom', 'datenum');
		end
		if isdatetime(dt)
			try
				if ~isempty(dt.TimeZone)
					dt.TimeZone = '';
				end
			catch
			end
		end
	catch
	end
end

function Z = iAccumMean(Z, linIdx, values)
	[linU, ~, g] = unique(linIdx);
	mu = splitapply(@(x) mean(x, 'omitnan'), values, g);
	Z(linU) = mu;
end

function mouseCond = iReduceToMouseLevel(rows)
	if isempty(rows)
		mouseCond = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
			'VariableNames', {'Mouse','Condition','DateTime','Divergence','NCells','NTrials','DataSet'});
		return;
	end
	rows = rows(isfinite(rows.Divergence), :);
	rows.Mouse = string(rows.Mouse);
	rows.Condition = string(rows.Condition);
	rows.DateTime = iNormalizeDateTime(rows.DateTime);
	rows = rows(~ismissing(rows.Mouse) & ~ismissing(rows.Condition) & ~isnat(rows.DateTime), :);
	rows = rows(rows.Mouse ~= "" & rows.Condition ~= "", :);
	if isempty(rows)
		mouseCond = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
			'VariableNames', {'Mouse','Condition','DateTime','Divergence','NCells','NTrials','DataSet'});
		return;
	end

	% pick the latest session per mouse per condition
	[g, mKey, cKey] = findgroups(rows.Mouse, rows.Condition);
	dtMax = splitapply(@(x) max(x), rows.DateTime, g);
	mouseCond = table(mKey, cKey, dtMax, 'VariableNames', {'Mouse','Condition','DateTime'});
	mouseCond.Divergence = nan(height(mouseCond),1);
	mouseCond.NCells = nan(height(mouseCond),1);
	mouseCond.NTrials = nan(height(mouseCond),1);
	mouseCond.DataSet = strings(height(mouseCond),1);

	for i = 1:height(mouseCond)
		m = mouseCond.Mouse(i);
		c = mouseCond.Condition(i);
		dt = mouseCond.DateTime(i);
		idx = (rows.Mouse==m) & (rows.Condition==c) & (rows.DateTime==dt);
		if ~any(idx)
			continue;
		end
		R = rows(find(idx,1,'first'), :);
		mouseCond.Divergence(i) = R.Divergence;
		mouseCond.NCells(i) = R.NCells;
		mouseCond.NTrials(i) = R.NTrials;
		mouseCond.DataSet(i) = string(R.DataSet);
	end
	mouseCond.DataSet = string(mouseCond.DataSet);
end

function wide = iPivot4(mouseCond)
	cond4 = ["NaiveAudio","LearnedAudio","TransferLight","FinalLight"];
	if isempty(mouseCond)
		wide = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','NaiveAudio','LearnedAudio','TransferLight','FinalLight'});
		return;
	end
	mouseCond = mouseCond(ismember(mouseCond.Condition, cond4), :);
	if isempty(mouseCond)
		wide = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','NaiveAudio','LearnedAudio','TransferLight','FinalLight'});
		return;
	end
	mice = unique(mouseCond.Mouse);

	wide = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','NaiveAudio','LearnedAudio','TransferLight','FinalLight'});

	for i = 1:numel(mice)
		m = mice(i);
		row = nan(1,4);
		ok = true;
		for j = 1:4
			c = cond4(j);
			idx = (mouseCond.Mouse==m) & (mouseCond.Condition==c);
			if ~any(idx)
				ok = false; break;
			end
			row(j) = mouseCond.Divergence(find(idx,1,'first'));
		end
		if ok && all(isfinite(row))
			wide = [wide; table(m, row(1), row(2), row(3), row(4), 'VariableNames', {'Mouse','NaiveAudio','LearnedAudio','TransferLight','FinalLight'})]; %#ok<AGROW>
		end
	end
end

function y = iGet(mouseCond, condName)
	idx = mouseCond.Condition == string(condName);
	y = mouseCond.Divergence(idx);
	y = y(isfinite(y));
end

function [p, st] = iRanksum(mouseCond, c1, c2)
	x = iGet(mouseCond, c1);
	y = iGet(mouseCond, c2);
	if isempty(x) || isempty(y)
		p = NaN; st = struct('Z', NaN); return;
	end
	[p, ~, stats] = ranksum(x, y);
	if isstruct(stats) && isfield(stats, 'zval')
		st = struct('Z', stats.zval);
	else
		st = struct('Z', NaN);
	end
end

function [p, st] = iSignrank(mouseCond, c1, c2)
	m1 = mouseCond(mouseCond.Condition==string(c1), {'Mouse','Divergence'});
	m2 = mouseCond(mouseCond.Condition==string(c2), {'Mouse','Divergence'});
	m1.Mouse = string(m1.Mouse);
	m2.Mouse = string(m2.Mouse);
	m = intersect(m1.Mouse, m2.Mouse);
	if isempty(m)
		p = NaN; st = struct('Z', NaN); return;
	end
	x = nan(numel(m),1);
	y = nan(numel(m),1);
	for i = 1:numel(m)
		mi = m(i);
		x(i) = m1.Divergence(find(m1.Mouse==mi,1,'first'));
		y(i) = m2.Divergence(find(m2.Mouse==mi,1,'first'));
	end
	mask = isfinite(x) & isfinite(y);
	x = x(mask); y = y(mask);
	if isempty(x)
		p = NaN; st = struct('Z', NaN); return;
	end
	[p, ~, stats] = signrank(x, y);
	if isstruct(stats) && isfield(stats, 'zval')
		st = struct('Z', stats.zval);
	else
		st = struct('Z', NaN);
	end
end

function iAnnotateP(ax, x1, x2, p)
	if ~isfinite(p)
		return;
	end
	yL = ylim(ax);
	y = yL(2);
	% incremental stacking based on distance
	off = 0.04 * range(yL);
	y = y + off;
	plot(ax, [x1 x1 x2 x2], [y y+off y+off y], 'k-', 'LineWidth', 1.0);
	text(ax, mean([x1 x2]), y+off, sprintf('p=%.3g', p), 'HorizontalAlignment','center', 'VerticalAlignment','bottom');
	ylim(ax, [yL(1) y+3*off]);
end
