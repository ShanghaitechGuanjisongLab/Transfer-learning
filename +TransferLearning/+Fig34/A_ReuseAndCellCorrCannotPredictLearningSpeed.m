% 图3.4a：复用率和预训率 P(T|F) 都不能预测 Transfer 学习增量（控前会话命中率）
%
% Spec (from 论文大纲.md 3.3):
% - Within Transfer cohort, show that:
%     * Reuse(1s) does NOT significantly correlate with learning increment (\DeltaHit)
%     * P(T|F) does NOT significantly correlate with learning increment (\DeltaHit)
% - Stratify by layer: MOp2/3 vs MOp5 (4 subplots)
%
% Notes (2026-01-17 updated):
% - One point = one session.
% - Learning increment is forward difference: DeltaHit = Hit(i+1) - Hit(i) within each mouse.
% - Reuse and P(T|F) are computed per session (Mouse×DateTime), not per mouse.
%   * Reuse(session vs Learned) is computed within each LightWater session, referenced to
%     Learned(AudioWater, Learned phase pooled) active cells.
%   * P(T|F)(session) is P(Active_in_this_LW_session@1s | Final_LW_Active@1s), within mouse.
% - Do NOT restrict Phase; use all phases in ALB.
% - Do NOT exclude Performance==0.
% - Exclude ceiling segment (Perf==1 and later) plus the last step into ceiling;
%   enforce 0<=Perf<1.
%
% Stats:
% - Report Spearman and partial Spearman controlling for previous-session hit rate
%   (here: Hit1 of the current session, for DeltaHit forward difference).
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig34.A_ReuseAndCellCorrCannotPredictLearningSpeed

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_4a_ReuseAndPTgivenF_vs_LearningSpeed_DeltaNext_CtrlHit1.svg";

% --- Ensure project loaded (for UniExp)
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

% --- 1) Time indices / baseline mask (Reuse + P(T|F))
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig3_3a:BadTimeMask', 'Baseline(-3~0) has no samples.');
end

[dtMin1, idx1] = min(abs(xsSec - 1));
[dtMin2, idx2] = min(abs(xsSec - 1.5));
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig3_3a:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end
if isempty(idx2) || ~isfinite(dtMin2) || dtMin2 > 0.25
	error('Fig3_3a:No1p5sSample', 'Cannot find a sample close to 1.5s in TransferLearning.Xs.');
end

layerNames = ["MOp2/3","MOp5"];

% --- 2) Session-level learning increment (DeltaHit forward difference) over ALL phases
DS = TransferLearning.AudioLightBaseline();
Sess0 = iTransferTrajectorySessions(DS);
assignin('base', 'Fig3_3a_SessionsRaw', Sess0);

[Sess, diag] = iFilterSessions_Keep0ExcludeCeiling(Sess0);
assignin('base', 'Fig3_3a_SessionsFiltered', Sess);
assignin('base', 'Fig3_3a_FilterDiag', diag);

SessSpeed = iSessionDeltaNextTable(Sess);
assignin('base', 'Fig3_3a_SessionSpeed', SessSpeed);

fprintf('Fig3.4a (DeltaHit forward diff, session-level): sessions raw=%d, after filter=%d (n0=%d, rmCeiling=%d), DeltaHit points=%d\n', ...
	height(Sess0), height(Sess), diag.N0, diag.RmCeiling, height(SessSpeed));

% --- 3) Session-specific Reuse + P(T|F) (one value per session×layer)
learnedCell = iLearnedActiveByCell(DS, baseMask, idx1);
finalCell = iFinalActiveByCell(DS, baseMask, idx1);
SessMetric = iSessionReuseAndPTgivenF(DS, SessSpeed, learnedCell, finalCell, baseMask, idx1, idx2, layerNames);
assignin('base', 'Fig3_3a_SessionMetrics', SessMetric);

% Join: one point = one session(DateTime) × one layer
J = innerjoin(SessMetric, SessSpeed(:, {'Mouse','DateTime','DateTimeNext','Performance','PerformanceNext','Speed_DeltaNext'}), ...
	'Keys', {'Mouse','DateTime'});
assignin('base', 'Fig3_3a_Joined', J);

% --- 3) Plot
f = figure('Color','w', 'Name', 'Fig3.4a Reuse/P(T|F) vs learning increment (Ctrl Hit1)');
try
	MATLAB.Graphics.FigureAspectRatio(3, 2, 3/4);
catch
end

tl = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

axs = gobjects(2,2);

layers = ["MOp2/3","MOp5"];
for iL = 1:numel(layers)
	zl = layers(iL);
	R = J(J.ZLayer == zl, :);

	% Left: Reuse(session vs Learned) vs learning increment
	ax = nexttile(tl, (iL-1)*2 + 1);
	axs(iL,1) = ax;
	iScatter(ax, R.Reuse_SessionVsLearned, R.Speed_DeltaNext, R.Performance);
	if iL == 1
		title(ax, 'Reuse', 'Interpreter','none');
	end
	ylabel(ax, zl, 'Interpreter','none');

	% Right: P(T|F)(session) vs learning increment
	ax = nexttile(tl, (iL-1)*2 + 2);
	axs(iL,2) = ax;
	iScatter(ax, R.PTgivenF_SessionVsFinal_1s, R.Speed_DeltaNext, R.Performance);
	if iL == 1
		title(ax, 'P(T|F)', 'Interpreter','none');
	end
	% Hide right-column y axis
	ax.YTickLabel = [];
	ax.YLabel.String = '';
end

% Hide top-row x axis
axs(1,1).XTickLabel = [];
axs(1,1).XLabel.String = '';
axs(1,2).XTickLabel = [];
axs(1,2).XLabel.String = '';

% Bottom-row x labels
xlabel(axs(2,1), 'Reuse', 'Interpreter','none');
xlabel(axs(2,2), 'P(T|F)', 'Interpreter','none');

% Global y label (move from per-axes)
% NOTE: Learning increment is forward difference: DeltaHit = Hit(i+1)-Hit(i) within mouse.
ylabel(tl, 'Learning increment (\DeltaHit)', 'Interpreter','tex');

% Unify X limits (by column)
iUnifyX(axs(:,1));
iUnifyX(axs(:,2));

sgtitle(tl, 'Learning increment vs reuse / P(T|F)', 'Interpreter','none');
tl.Title.String = '';

% --- 4) Export SVG
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	print(f, svgPath, '-dsvg', '-painters');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% ---- local helpers

function iScatter(ax, x, y, hit1)
	x = double(x);
	y = double(y);
	hit1 = double(hit1);
	use = isfinite(x) & isfinite(y);

	hold(ax,'on');
	box(ax,'off');
	grid(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	scatter(ax, x(use), y(use), 28, 'filled', 'MarkerFaceAlpha', 0.75);

	% Fit line segment (linear)
	if nnz(use) >= 2 && std(x(use),'omitnan') > 0
		b = polyfit(x(use), y(use), 1);
		xLine = [min(x(use)), max(x(use))];
		yLine = polyval(b, xLine);
		plot(ax, xLine, yLine, 'k-', 'LineWidth', 1);
	end

	[~, ~, ~] = iSpearman(x, y);
	[rhoC, pC, ~] = iPartialSpearmanCtrl(x, y, hit1);
	subtitle(ax, sprintf('\\rho=%.2f, p=%.3g', rhoC, pC), 'Interpreter','tex');
end

function iUnifyX(axs)
	try
		MATLAB.Graphics.UnifyAxesLims(axs, 'x');
		return;
	catch
	end
	try
		xl = nan(numel(axs),2);
		for i = 1:numel(axs)
			xl(i,:) = xlim(axs(i));
		end
		xl = [min(xl(:,1),[],'omitnan') max(xl(:,2),[],'omitnan')];
		for i = 1:numel(axs)
			xlim(axs(i), xl);
		end
	catch
	end
end

function [rho, p, n] = iSpearman(x, y)
	rho = NaN;
	p = NaN;
	x = double(x(:));
	y = double(y(:));
	use = isfinite(x) & isfinite(y);
	n = nnz(use);
	if n < 5
		return;
	end
	if std(x(use),'omitnan') <= 0 || std(y(use),'omitnan') <= 0
		return;
	end
	try
		[rho, p] = corr(x(use), y(use), 'Type','Spearman');
	catch
		rho = NaN;
		p = NaN;
	end
end

function [rho, p, n] = iPartialSpearmanCtrl(x, y, z)
	% Partial Spearman correlation controlling for z (Hit1 / Perf_i).
	% Implemented as: rank-transform then correlate residuals after regressing
	% out rank(z) from rank(x) and rank(y).
	rho = NaN;
	p = NaN;
	x = double(x(:));
	y = double(y(:));
	z = double(z(:));
	use = isfinite(x) & isfinite(y) & isfinite(z);
	n = nnz(use);
	if n < 5
		return;
	end
	try
		rx = tiedrank(x(use));
		ry = tiedrank(y(use));
		rz = tiedrank(z(use));
		X = [ones(n,1), rz];
		bx = X \ rx;
		by = X \ ry;
		ex = rx - X*bx;
		ey = ry - X*by;
		[rho, p] = corr(ex, ey, 'Type','Pearson');
	catch
		rho = NaN;
		p = NaN;
	end
end

function Sess = iTransferTrajectorySessions(DS)
	% Build per-session LightWater-only performance (ALB), over ALL phases.
	Tblk = iQueryAllBlocksWithLWPerf(DS);
	if isempty(Tblk)
		Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
		return;
	end
	Tblk.Mouse = string(Tblk.Mouse);
	Tblk.Phase = string(Tblk.Phase);
	Tblk.DateTime = iNormalizeDateTime(Tblk.DateTime);
	Tblk = Tblk(Tblk.HasLW, :);
	if isempty(Tblk)
		Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
		return;
	end

	TblkLW2 = table(Tblk.Mouse, Tblk.DateTime, Tblk.LWPerf, Tblk.BlockUID, ...
		'VariableNames', {'Mouse','DateTime','Performance','BlockUID'});
	Sess = iSessionizeByDateTime(TblkLW2);
	Sess.Mouse = string(Sess.Mouse);
	Sess.DateTime = iNormalizeDateTime(Sess.DateTime);
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	Sess = iAddSessionIndex(Sess);
end

function [SessOut, diag] = iFilterSessions_Keep0ExcludeCeiling(SessIn)
	SessOut = SessIn;
	diag = struct('N0',0,'RmCeiling',0);
	if isempty(SessOut)
		return;
	end
	SessOut.Mouse = string(SessOut.Mouse);
	SessOut = sortrows(SessOut, {'Mouse','DateTime'});

	% Keep Perf==0 (0%) sessions; just count them for diagnostics.
	perf = double(SessOut.Performance);
	diag.N0 = nnz(isfinite(perf) & (perf <= 1e-12));

	% Exclude ceiling segment: Perf==1 (100%) and later, plus last step into ceiling
	if isempty(SessOut)
		return;
	end
	remove = false(height(SessOut), 1);
	mice = unique(string(SessOut.Mouse));
	for mi = 1:numel(mice)
		m = mice(mi);
		rows = find(SessOut.Mouse == m);
		p = double(SessOut.Performance(rows));
		i100 = find(isfinite(p) & p >= (1 - 1e-12), 1, 'first');
		if isempty(i100)
			continue;
		end
		if i100 <= 1
			remove(rows(1:end)) = true;
		else
			remove(rows(i100-1:end)) = true;
		end
	end
	diag.RmCeiling = nnz(remove);
	SessOut(remove,:) = [];

	% Enforce 0<=Perf<1
	perf = double(SessOut.Performance);
	keep = isfinite(perf) & (perf >= -1e-12) & (perf < (1 - 1e-12));
	SessOut = SessOut(keep, :);
end

function SessSpeed = iSessionDeltaNextTable(Sess)
	% One point per session: forward difference (DeltaHit) = Hit(i+1) - Hit(i)
	SessSpeed = table(string.empty(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
	if isempty(Sess)
		return;
	end
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	Sess.Mouse = string(Sess.Mouse);

	mice = unique(string(Sess.Mouse));
	outMouse = strings(0,1);
	outDT = NaT(0,1);
	outPerf = nan(0,1);
	outDT2 = NaT(0,1);
	outPerf2 = nan(0,1);
	outDN = nan(0,1);

	for mi = 1:numel(mice)
		m = mice(mi);
		R = Sess(Sess.Mouse == m, :);
		perf = double(R.Performance);
		dt = R.DateTime;
		use = isfinite(perf) & ~ismissing(dt);
		perf = perf(use);
		dt = dt(use);
		if numel(perf) < 2
			continue;
		end
		dn = diff(perf);
		outMouse = [outMouse; repmat(string(m), numel(dn), 1)]; %#ok<AGROW>
		outDT = [outDT; dt(1:end-1)]; %#ok<AGROW>
		outPerf = [outPerf; perf(1:end-1)]; %#ok<AGROW>
		outDT2 = [outDT2; dt(2:end)]; %#ok<AGROW>
		outPerf2 = [outPerf2; perf(2:end)]; %#ok<AGROW>
		outDN = [outDN; dn(:)]; %#ok<AGROW>
	end

	SessSpeed = table(outMouse, outDT, outPerf, outDT2, outPerf2, outDN, ...
		'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end

function learnedCell = iLearnedActiveByCell(DS, baseMask, idx1)
	% LearnedActive is pooled at phase level (Learned, AudioWater), per cell
	kSigma = 3;
	try
		G = DS.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch ME
		error('Fig3_3a:LearnedQueryFailed', 'QueryNTATS Learned(AudioWater) failed: %s', ME.message);
	end
	if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
		error('Fig3_3a:LearnedEmpty', 'QueryNTATS Learned(AudioWater) empty.');
	end
	X = iNtatsData(G.NTATS);
	act = iActiveAt1s(X, baseMask, idx1, kSigma);
	C = DS.Cells;
	learnedCell = table(uint64(G.CellUID), logical(act), 'VariableNames', {'CellUID','LearnedActive'});
	learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
	learnedCell.Mouse = string(learnedCell.Mouse);
	learnedCell.ZLayer = string(learnedCell.ZLayer);
end

function finalCell = iFinalActiveByCell(DS, baseMask, idx1)
	% FinalActive is per mouse (Final, LightWater, pooled), per cell
	% NOTE: For P(T|F) we only use FinalActive within each mouse.
	kSigma = 3;
	try
		G = DS.QueryNTATS(struct('Stimulus','LightWater','Phase','Final'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch ME
		error('Fig3_3a:FinalQueryFailed', 'QueryNTATS Final(LightWater) failed: %s', ME.message);
	end
	if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
		error('Fig3_3a:FinalEmpty', 'QueryNTATS Final(LightWater) empty.');
	end
	X = iNtatsData(G.NTATS);
	act = iActiveAt1s(X, baseMask, idx1, kSigma);
	C = DS.Cells;
	finalCell = table(uint64(G.CellUID), logical(act), 'VariableNames', {'CellUID','FinalActive'});
	finalCell = innerjoin(finalCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
	finalCell.Mouse = string(finalCell.Mouse);
	finalCell.ZLayer = string(finalCell.ZLayer);
end

function Tout = iSessionReuseAndPTgivenF(DS, SessSpeed, learnedCell, finalCell, baseMask, idx1, ~, layerNames)
	% Compute per session×layer:
	% - Reuse_SessionVsLearned: P(Active_in_this_LW_session@1s | LearnedActive@1s)
	% - PTgivenF_SessionVsFinal_1s: P(Active_in_this_LW_session@1s | FinalActive@1s)
	kSigma = 3;
	if isempty(SessSpeed)
		Tout = table(string.empty(0,1), string.empty(0,1), NaT(0,1), ...
			nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
			nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','ZLayer','DateTime', ...
			'NCellsReuse','Reuse_SessionVsLearned', ...
			'NCellsPTgivenF','PTgivenF_SessionVsFinal_1s'});
		return;
	end

	SessSpeed.Mouse = string(SessSpeed.Mouse);
	SessSpeed.DateTime = iNormalizeDateTime(SessSpeed.DateTime);
	SessKey = unique(SessSpeed(:,{'Mouse','DateTime'}), 'rows');

	rows = table;
	for i = 1:height(SessKey)
		m = string(SessKey.Mouse(i));
		dt = SessKey.DateTime(i);

		% Drop mixed sessions (sessions that also contain AudioWater)
		if iIsMixedAudioSession(DS, m, dt)
			continue;
		end

		% Query this LightWater session NTATS
		try
			q = struct('Mouse', m, 'DateTime', dt, 'Stimulus', 'LightWater');
			G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		catch
			G = [];
		end
		if isempty(G) || ~all(ismember(["CellUID","NTATS"], string(G.Properties.VariableNames)))
			continue;
		end

		M = iNtatsData(G.NTATS);
		uid = uint64(G.CellUID);
		tranAct = iActiveAt1s(M, baseMask, idx1, kSigma);
		tranCell = table(uid, logical(tranAct), 'VariableNames', {'CellUID','TransferActive'});

		LT = innerjoin(learnedCell(:,{'CellUID','Mouse','ZLayer','LearnedActive'}), tranCell, 'Keys','CellUID');
		LT.Mouse = string(LT.Mouse);
		LT.ZLayer = string(LT.ZLayer);
		LT = LT(LT.Mouse == m, :);

		FT = innerjoin(finalCell(:,{'CellUID','Mouse','ZLayer','FinalActive'}), tranCell, 'Keys','CellUID');
		FT.Mouse = string(FT.Mouse);
		FT.ZLayer = string(FT.ZLayer);
		FT = FT(FT.Mouse == m, :);

		if isempty(LT) || isempty(FT)
			continue;
		end

		for iZ = 1:numel(layerNames)
			zl = string(layerNames(iZ));
			idxL = (LT.ZLayer == zl);
			if nnz(idxL) < 10
				continue;
			end
			LA = logical(LT.LearnedActive(idxL));
			TA = logical(LT.TransferActive(idxL));
			den = LA;
			if nnz(den) < 1
				continue;
			end
			reuse = mean(double(TA(den)), 'omitnan');

				idxF = (FT.ZLayer == zl);
				FA = logical(FT.FinalActive(idxF));
				TA2 = logical(FT.TransferActive(idxF));
				den2 = FA;
				if nnz(den2) < 1
					continue;
				end
				pt = mean(double(TA2(den2)), 'omitnan');

				rows = [rows; table(m, zl, dt, nnz(idxL), reuse, nnz(idxF), pt, ...
					'VariableNames', {'Mouse','ZLayer','DateTime', ...
					'NCellsReuse','Reuse_SessionVsLearned', ...
					'NCellsPTgivenF','PTgivenF_SessionVsFinal_1s'})]; %#ok<AGROW>
		end
	end

	Tout = rows;
	if ~isempty(Tout)
		Tout = sortrows(Tout, {'ZLayer','Mouse','DateTime'});
	end
end

function tf = iIsMixedAudioSession(DS, mouse, dt)
	% True if this Mouse×DateTime has any AudioWater blocks.
	tf = false;
	try
		Ta = DS.TableQuery(["Mouse","DateTime","Stimulus"], Mouse=mouse, DateTime=dt, Stimulus="AudioWater");
		if ~isempty(Ta)
			tf = true;
		end
	catch
		tf = false;
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

function act = iActiveAt1s(X, baseMask, idx1, kSigma)
	base = X(:, baseMask);
	mu = mean(base, 2, 'omitnan');
	sd = std(base, 0, 2, 'omitnan');
	thr = mu + kSigma .* sd;
	v = X(:, idx1);
	act = v > thr;
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

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Mouse','DateTime'});
	[G, ~] = findgroups(T.Mouse);
	T.Session = zeros(height(T), 1);
	ug = unique(G);
	for gi = 1:numel(ug)
		rows = (G == ug(gi));
		T.Session(rows) = (1:sum(rows)).';
	end
end

function Tblk = iQueryAllBlocksWithLWPerf(DS)
	% Returns block-level rows with fields:
	%   Mouse, DateTime, BlockUID, Phase, HasLW, LWPerf
	vars = ["Mouse","DateTime","BlockUID","Phase"];
	try
		Tblk = DS.TableQuery(vars);
	catch ME
		error('Fig3_3a:BlockQueryFailed', 'Block query failed for %s: %s', class(DS), ME.message);
	end
	if isempty(Tblk)
		Tblk = table();
		return;
	end

	if ~isprop(DS, 'Trials')
		error('Fig3_3a:MissingTrials', 'DataSet %s has no Trials; cannot compute LightWater-only performance.', class(DS));
	end
	Tr = DS.Trials;
	need = {'BlockUID','Stimulus','Behavior'};
	if ~all(ismember(need, Tr.Properties.VariableNames))
		error('Fig3_3a:TrialsMissingFields', 'Trials table for %s lacks required fields: %s', class(DS), strjoin(setdiff(need, Tr.Properties.VariableNames), ','));
	end

	TrStim = string(Tr.Stimulus);
	TrLW = Tr(TrStim == "LightWater", {'BlockUID','Stimulus','Behavior'});
	Tblk.HasLW = false(height(Tblk), 1);
	Tblk.LWPerf = nan(height(Tblk), 1);
	if isempty(TrLW)
		return;
	end

	[G, bu] = findgroups(uint64(TrLW.BlockUID));
	lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
	perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

	blkUID64 = uint64(Tblk.BlockUID);
	[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
	Tblk.HasLW(tf) = true;
	Tblk.LWPerf(tf) = perfByBlock.LWPerf(loc(tf));
end

function T = iSessionizeByDateTime(T)
	% Input must contain Mouse, DateTime, Performance, BlockUID (block-level rows)
	T.DateTime = datetime(T.DateTime);
	try
		T.DateTime.TimeZone = '';
	catch
	end
	[G, mouse, dt] = findgroups(string(T.Mouse), T.DateTime);
	perf = splitapply(@(x) mean(x,'omitnan'), double(T.Performance), G);
	nBlocks = splitapply(@numel, double(T.Performance), G);
	T = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
end
