% 图3.3b（替代指标预览）：全细胞 1s 标准差 across phases
%
% Purpose:
% - Preview what Fig3.3b would look like if the per-mouse metric is changed to:
%     StdCells1s = std( ZScoreMedianNTATS(:, t≈1s) )
%   i.e., standard deviation across all cells at 1s.
%
% Data / matching rules (keep identical to Fig3.3b spec):
% - NaiveLight: LightAudioBaseline + LAInterspersed (Phase=Naive, Stimulus=LightWater)
% - Others: AudioLightBaseline
% - Mouse-level: for each mouse & condition, use the latest session
%
% Statistics (same pairing rules as Fig3.3b):
% - NaiveLight vs TransferLight: ranksum (unpaired)
% - NaiveAudio vs LearnedAudio: signrank (paired by mouse)
% - TransferLight vs FinalLight: signrank (paired by mouse)
%
% Plotting:
% - NaiveLight: swarmchart (unpaired)
% - Paired line: NaiveAudio -> LearnedAudio -> TransferLight -> FinalLight
% - TransferLight should NOT also be swarmchart (it already appears in paired lines)
%
% Signal:
% - Use NTATS Median ZScore: DS.QueryNTATS(..., UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   IMPORTANT: MUST REMAIN A SCRIPT.
%   Call via package name:
%     TransferLearning.Fig33.C_VarCells1sAcrossPhases

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3b_StdCells1sAcrossPhases.svg";

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

xsSec = seconds(TransferLearning.Xs);
[dtMin, idx1_ref] = min(abs(xsSec - 1));
if isempty(idx1_ref) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig3_3bVar:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end

% --- 2) Compute metric per mouse-session
rows = table();

% NaiveLight from LAB + LAI
rows = [rows; iComputeConditionSessions(LAB, struct('Phase','Naive','Stimulus','LightWater'), "NaiveLight", "LightAudioBaseline", excludeMixedAudioInNaiveLight, idx1_ref)];
rows = [rows; iComputeConditionSessions(LAI, struct('Phase','Naive','Stimulus','LightWater'), "NaiveLight", "LAInterspersed",     excludeMixedAudioInNaiveLight, idx1_ref)];

% Others from ALB
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Naive',  'Stimulus','AudioWater'),  "NaiveAudio",    "AudioLightBaseline", false, idx1_ref)];
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Learned','Stimulus','AudioWater'),  "LearnedAudio",  "AudioLightBaseline", false, idx1_ref)];
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Transfer','Stimulus','LightWater'), "TransferLight", "AudioLightBaseline", false, idx1_ref)];
rows = [rows; iComputeConditionSessions(ALB, struct('Phase','Final',  'Stimulus','LightWater'), "FinalLight",    "AudioLightBaseline", false, idx1_ref)];

rows.Mouse = string(rows.Mouse);
rows.Condition = string(rows.Condition);
rows.DataSet = string(rows.DataSet);

assignin('base', 'Fig3_3bVar_SessionRows', rows);

% --- 3) Reduce to mouse-level latest session per condition
mouseCond = iReduceToMouseLevel(rows);
assignin('base', 'Fig3_3bVar_MouseRows', mouseCond);

wide4 = iPivot4(mouseCond);
assignin('base', 'Fig3_3bVar_PairedWide4', wide4);

% --- 4) Stats
[p_naiveLight_vs_transfer, stats1] = iRanksum(mouseCond, "NaiveLight", "TransferLight");
[p_naiveAudio_vs_learned,  stats2] = iSignrank(mouseCond, "NaiveAudio", "LearnedAudio");
[p_transfer_vs_final,      stats3] = iSignrank(mouseCond, "TransferLight", "FinalLight");

statsSummary = table(p_naiveLight_vs_transfer, p_naiveAudio_vs_learned, p_transfer_vs_final, ...
	stats1.Z, stats2.Z, stats3.Z, ...
	'VariableNames', {'P_NaiveLight_vs_TransferLight','P_NaiveAudio_vs_LearnedAudio','P_TransferLight_vs_FinalLight', ...
	'Z_NaiveLight_vs_TransferLight','Z_NaiveAudio_vs_LearnedAudio','Z_TransferLight_vs_FinalLight'});
assignin('base','Fig3_3bVar_Stats', statsSummary);

% --- 5) Plot
f = figure('Name','Fig3.3b StdCells@1s (preview)', 'Color','w');
ax = axes('Parent', f);
hold(ax,'on');
box(ax,'off');
grid(ax,'on');

xPos = struct('NaiveLight',1,'NaiveAudio',2,'LearnedAudio',3,'TransferLight',4,'FinalLight',5);
xticks(ax, 1:5);
xticklabels(ax, {'NaiveLight','NaiveAudio','LearnedAudio','TransferLight','FinalLight'});
xlim(ax, [0.5 5.5]);

% NaiveLight swarm (unpaired)
yNL = iGet(mouseCond, "NaiveLight");
swarmchart(ax, repmat(xPos.NaiveLight, size(yNL)), yNL, 18, 'filled', 'MarkerFaceAlpha', 0.7);

% Paired lines (NaiveAudio->LearnedAudio->TransferLight->FinalLight)
if ~isempty(wide4)
	for i = 1:height(wide4)
		y = [wide4.NaiveAudio(i), wide4.LearnedAudio(i), wide4.TransferLight(i), wide4.FinalLight(i)];
		x = [xPos.NaiveAudio, xPos.LearnedAudio, xPos.TransferLight, xPos.FinalLight];
		plot(ax, x, y, '-o', 'Color', [0.45 0.45 0.45], 'MarkerSize', 4, 'LineWidth', 1.0, ...
			'MarkerFaceColor', [0.45 0.45 0.45], 'MarkerEdgeColor', [0.45 0.45 0.45]);
	end
end

ylabel(ax, 'StdAcrossCells@1s (NTATS Median ZScore)');

% annotate p-values (only requested pairs)
iAnnotateP(ax, xPos.NaiveLight,    xPos.TransferLight, p_naiveLight_vs_transfer);
iAnnotateP(ax, xPos.NaiveAudio,    xPos.LearnedAudio,  p_naiveAudio_vs_learned);
iAnnotateP(ax, xPos.TransferLight, xPos.FinalLight,    p_transfer_vs_final);

% --- 6) Export SVG
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

function out = iComputeConditionSessions(DS, q, condName, dsName, pureNaiveLight, idx1)
	out = table(string.empty(0,1), NaT(0,1), string.empty(0,1), string.empty(0,1), ...
		nan(0,1), nan(0,1), string.empty(0,1), ...
		'VariableNames', {'Mouse','DateTime','Condition','DataSet','StdCells1s','NCells','Error'});

	T = iQuerySessionBlocks(DS, q);
	if isempty(T) || height(T) == 0
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);

	if pureNaiveLight
		pureMice = iFindPureNaiveLightWaterMice(DS);
		T = T(ismember(T.Mouse, pureMice), :);
		if isempty(T)
			return;
		end
	end

	[g, mKey, dtKey] = findgroups(T.Mouse, T.DateTime);
	Sess = table(mKey, dtKey, 'VariableNames', {'Mouse','DateTime'});
	Sess = unique(Sess, 'rows');
	Sess = sortrows(Sess, {'Mouse','DateTime'});

	for i = 1:height(Sess)
		m = string(Sess.Mouse(i));
		dt = Sess.DateTime(i);
		try
			[v1, nCell, errMsg] = iComputeStdCells1s(DS, q, m, dt, idx1);
		catch ME
			v1 = NaN; nCell = NaN;
			errMsg = "ERROR: " + string(ME.identifier) + ": " + string(ME.message);
		end
		out = [out; table(m, dt, string(condName), string(dsName), v1, nCell, string(errMsg), ...
			'VariableNames', {'Mouse','DateTime','Condition','DataSet','StdCells1s','NCells','Error'})]; %#ok<AGROW>
	end
end

function T = iQuerySessionBlocks(DS, q)
	try
		args = namedargs2cell(q);
		T = DS.TableQuery(["Mouse","DateTime","BlockUID"], args{:});
		return;
	catch
		T = table();
	end
end

function [v1, nCell, errMsg] = iComputeStdCells1s(DS, q, mouse, dt, idx1)
	q2 = q;
	q2.Mouse = mouse;
	q2.DateTime = dt;
	errMsg = "";

	G = DS.QueryNTATS(q2, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	if isempty(G)
		v1 = NaN; nCell = NaN;
		errMsg = "Empty/Bad QueryNTATS";
		return;
	end
	vnames = string(G.Properties.VariableNames);
	if ~all(ismember(["CellUID","NTATS"], vnames))
		v1 = NaN; nCell = NaN;
		errMsg = "Empty/Bad QueryNTATS";
		return;
	end

	NT = G.NTATS;
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
	if size(X,2) < idx1
		v1 = NaN; nCell = NaN;
		errMsg = "Bad NTATS dims: " + string(mat2str(size(X)));
		return;
	end
	x1 = X(:, idx1);
	nCell = sum(isfinite(x1));
	if nCell < 2
		v1 = NaN;
		errMsg = "Too few finite cells";
	else
		v1 = std(x1, 0, 'omitnan');
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

function mouseCond = iReduceToMouseLevel(rows)
	if isempty(rows)
		mouseCond = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
			'VariableNames', {'Mouse','Condition','DateTime','Metric','NCells','DataSet'});
		return;
	end
	rows = rows(isfinite(rows.StdCells1s), :);
	rows.Mouse = string(rows.Mouse);
	rows.Condition = string(rows.Condition);
	rows.DateTime = iNormalizeDateTime(rows.DateTime);
	rows = rows(~ismissing(rows.Mouse) & ~ismissing(rows.Condition) & ~isnat(rows.DateTime), :);
	rows = rows(rows.Mouse ~= "" & rows.Condition ~= "", :);
	if isempty(rows)
		mouseCond = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), string.empty(0,1), ...
			'VariableNames', {'Mouse','Condition','DateTime','Metric','NCells','DataSet'});
		return;
	end

	% latest session per mouse per condition
	[g, mKey, cKey] = findgroups(rows.Mouse, rows.Condition);
	dtMax = splitapply(@(x) max(x), rows.DateTime, g);
	mouseCond = table(mKey, cKey, dtMax, 'VariableNames', {'Mouse','Condition','DateTime'});
	mouseCond.Metric = nan(height(mouseCond),1);
	mouseCond.NCells = nan(height(mouseCond),1);
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
		mouseCond.Metric(i) = R.StdCells1s;
		mouseCond.NCells(i) = R.NCells;
		mouseCond.DataSet(i) = string(R.DataSet);
	end
	mouseCond.DataSet = string(mouseCond.DataSet);
end

function wide = iPivot4(mouseCond)
	cond4 = ["NaiveAudio","LearnedAudio","TransferLight","FinalLight"];
	wide = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','NaiveAudio','LearnedAudio','TransferLight','FinalLight'});
	if isempty(mouseCond)
		return;
	end
	mouseCond = mouseCond(ismember(mouseCond.Condition, cond4), :);
	if isempty(mouseCond)
		return;
	end
	mice = unique(mouseCond.Mouse);
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
			row(j) = mouseCond.Metric(find(idx,1,'first'));
		end
		if ok && all(isfinite(row))
			wide = [wide; table(m, row(1), row(2), row(3), row(4), 'VariableNames', {'Mouse','NaiveAudio','LearnedAudio','TransferLight','FinalLight'})]; %#ok<AGROW>
		end
	end
end

function y = iGet(mouseCond, condName)
	idx = mouseCond.Condition == string(condName);
	y = mouseCond.Metric(idx);
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
	m1 = mouseCond(mouseCond.Condition==string(c1), {'Mouse','Metric'});
	m2 = mouseCond(mouseCond.Condition==string(c2), {'Mouse','Metric'});
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
		x(i) = m1.Metric(find(m1.Mouse==mi,1,'first'));
		y(i) = m2.Metric(find(m2.Mouse==mi,1,'first'));
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
	off = 0.04 * range(yL);
	y = y + off;
	plot(ax, [x1 x1 x2 x2], [y y+off y+off y], 'k-', 'LineWidth', 1.0);
	text(ax, mean([x1 x2]), y+off, sprintf('p=%.3g', p), 'HorizontalAlignment','center', 'VerticalAlignment','bottom');
	ylim(ax, [yL(1) y+3*off]);
end
