% 图3.3a：复用率和 1s/1.5s 相关性都不能预测 Transfer 学习速率
%
% Spec (from 论文大纲.md 3.3):
% - Within Transfer cohort, show that:
%     * Reuse(1s) does NOT significantly correlate with learning speed
%     * CellCorr(1s,1.5s) does NOT significantly correlate with learning speed
% - Stratify by layer: MOp2/3 vs MOp5 (4 subplots)
%
% Notes:
% - Reuse & CellCorr are computed by:
%     TransferLearning.Scratch.Transfer_ReuseVsCellCorr_1s_1p5s
% - Learning speed here is computed per mouse within Transfer trajectory
%   (Transfer->Final, LightWater-only performance), as slope of Performance
%   vs SessionIndex.
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig33.A_ReuseAndCellCorrCannotPredictLearningSpeed

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3a_ReuseAndCellCorr_CannotPredictTransferLearningSpeed.svg";

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

% --- 1) Reuse + CellCorr table (per mouse×layer)
TransferLearning.Scratch.Transfer_ReuseVsCellCorr_1s_1p5s;
T0 = evalin('base', 'Scratch_T_ReuseVsCellCorr_PerMouseLayer_1s1p5');
T0.Mouse = string(T0.Mouse);
T0.ZLayer = string(T0.ZLayer);

% --- 2) Per-mouse learning speed in Transfer trajectory
DS = TransferLearning.AudioLightBaseline();
Sess = iTransferTrajectorySessions(DS);
perMouse = iPerMouseSlope(Sess);
assignin('base', 'Fig3_3a_TransferPerMouseSpeed', perMouse);

% Join (one speed per mouse, duplicated for two layers)
J = innerjoin(T0, perMouse(:, {'Mouse','Slope','NSessions','BaselinePerf'}), 'Keys', 'Mouse');
assignin('base', 'Fig3_3a_ReuseCellCorrVsSpeed_Joined', J);

% --- 3) Plot
f = figure('Color','w', 'Name', 'Fig3.3a reuse/cellcorr vs learning speed');
try
	MATLAB.Graphics.FigureAspectRatio(10, 6, 1/2);
catch
end

tl = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

layers = ["MOp2/3","MOp5"];
for iL = 1:numel(layers)
	zl = layers(iL);
	R = J(J.ZLayer == zl, :);

	% Left: Reuse vs slope
	ax = nexttile(tl, (iL-1)*2 + 1);
	iScatter(ax, R.Reuse, R.Slope, sprintf('%s | Reuse(1s)', zl));

	% Right: CellCorr vs slope
	ax = nexttile(tl, (iL-1)*2 + 2);
	iScatter(ax, R.CellCorr_1s1p5s, R.Slope, sprintf('%s | CellCorr(1s,1.5s)', zl));
end

sgtitle(tl, 'Transfer cohort: reuse / 1s–1.5s correlation vs learning speed', 'Interpreter','none');

% --- 4) Export SVG
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

%% ---- local helpers

function iScatter(ax, x, y, ttl)
	x = double(x);
	y = double(y);
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
	xlabel(ax, 'Metric');
	ylabel(ax, 'Learning speed (slope)');

	[rho, p] = iSpearman(x(use), y(use));
	title(ax, sprintf('%s\nSpearman \rho=%.2f, p=%.3g, n=%d', ttl, rho, p, nnz(use)), 'Interpreter','none');
end

function [rho, p] = iSpearman(x, y)
	rho = NaN; p = NaN;
	if numel(x) < 4 || numel(y) < 4
		return;
	end
	if std(x,'omitnan') <= 0 || std(y,'omitnan') <= 0
		return;
	end
	try
		[rho, p] = corr(double(x(:)), double(y(:)), 'Type','Spearman', 'Rows','complete');
	catch
	end
end

function Sess = iTransferTrajectorySessions(DS)
	% Build per-session LightWater-only performance for Transfer cohort (ALB),
	% using phases Transfer/Final.
	Tblk = iQueryAllBlocksWithLWPerf(DS);
	if isempty(Tblk)
		Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
		return;
	end
	Tblk.Mouse = string(Tblk.Mouse);
	Tblk.Phase = string(Tblk.Phase);
	Tblk.DateTime = iNormalizeDateTime(Tblk.DateTime);
	Tblk = Tblk(ismember(Tblk.Phase, ["Transfer","Final"]) & Tblk.HasLW, :);
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

function perMouse = iPerMouseSlope(Sess)
	if isempty(Sess)
		perMouse = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Slope','NSessions','BaselinePerf'});
		return;
	end

	mice = unique(string(Sess.Mouse));
	perMouse = table;
	perMouse.Mouse = mice;
	perMouse.Slope = nan(numel(mice),1);
	perMouse.NSessions = zeros(numel(mice),1);
	perMouse.BaselinePerf = nan(numel(mice),1);

	for i = 1:numel(mice)
		m = mice(i);
		R = Sess(Sess.Mouse==m, :);
		R = sortrows(R, 'Session');
		x = double(R.Session);
		y = double(R.Performance);
		use = isfinite(x) & isfinite(y);
		perMouse.NSessions(i) = nnz(use);
		if nnz(use) >= 1
			perMouse.BaselinePerf(i) = y(find(use,1,'first'));
		end
		if nnz(use) >= 2
			b = polyfit(x(use), y(use), 1);
			perMouse.Slope(i) = b(1);
		else
			perMouse.Slope(i) = 0;
		end
	end
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
