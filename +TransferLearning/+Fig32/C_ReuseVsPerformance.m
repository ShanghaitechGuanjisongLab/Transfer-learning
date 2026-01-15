% 图3.2c：复用率与迁移阶段行为表现的相关性（transfer cohort 内）
%
% Required computation:
% - Median per-cell response must come from QueryNTATS:
%     DS.QueryNTATS(..., UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median)
%
% Metric (per mouse):
%   Reuse = P(TransferLight active | LearnedAudio active)
% where Learned/Transfer are pooled at the phase level:
%   Learned:  Phase=Learned,  Stimulus=AudioWater
%   Transfer: Phase=Transfer, Stimulus=LightWater
%
% Behavior (y-axis):
%   Transfer phase performance = mean(Performance) from DataSet field
%   (matched to AudioLightMedianNTATSReuseFigureExport.m).
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   IMPORTANT: MUST REMAIN A SCRIPT (do not convert to a function).
%   Call it like a function via the package name (do NOT use run):
%     TransferLearning.Fig32.C_ReuseVsPerformance

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2c_ReuseVsPerformance.svg";
excludeMice = string([]);

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

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);
kSigma = 3;
layerNames = string(["MOp2/3","MOp5"]);

% --- Strictly match AudioLightMedianNTATSReuseFigureExport.m
GLearn = iQueryNTATSOrEmpty(DS, struct('Stimulus','AudioWater','Phase','Learned'));
GTran  = iQueryNTATSOrEmpty(DS, struct('Stimulus','LightWater','Phase','Transfer'));
if isempty(GLearn) || isempty(GTran)
	error('Fig3_2c:MissingGroups', 'QueryNTATS empty for Learned(AudioWater) or Transfer(LightWater).');
end

XLearn = iNtatsData(GLearn.NTATS);
XTran  = iNtatsData(GTran.NTATS);

learnAct = iMedianActive(XLearn, baseMask, winMask, kSigma);
tranAct  = iMedianActive(XTran,  baseMask, winMask, kSigma);

C = DS.Cells;
learnedCell = table(uint64(GLearn.CellUID), double(learnAct), 'VariableNames', {'CellUID','LearnedActiveMed'});
transferCell = table(uint64(GTran.CellUID), double(tranAct), 'VariableNames', {'CellUID','TransferActiveMed'});

learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
transferCell = innerjoin(transferCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');

learnedCell.Mouse = string(learnedCell.Mouse);
transferCell.Mouse = string(transferCell.Mouse);
learnedCell.ZLayer = string(learnedCell.ZLayer);
transferCell.ZLayer = string(transferCell.ZLayer);

learnedCell = learnedCell(~ismember(learnedCell.Mouse, excludeMice), :);
transferCell = transferCell(~ismember(transferCell.Mouse, excludeMice), :);

medLT = innerjoin(learnedCell(:,{'Mouse','ZLayer','CellUID','LearnedActiveMed'}), ...
	transferCell(:,{'Mouse','ZLayer','CellUID','TransferActiveMed'}), 'Keys', {'Mouse','ZLayer','CellUID'});

% Performance: use dataset Performance field (same as AudioLightMedianNTATSReuseFigureExport)
PerfT = DS.TableQuery(["Mouse","Performance"], Design="LightWater", Phase="Transfer");
PerfT.Mouse = string(PerfT.Mouse);
[gM, mKeys] = findgroups(PerfT.Mouse);
perfByMouse = table(mKeys, splitapply(@(p) mean(p, 'omitnan'), PerfT.Performance, gM), ...
	'VariableNames', {'Mouse','TransferPerformance'});

mouseLayer = unique(medLT(:,{'Mouse','ZLayer'}));
rows = table;
for i = 1:height(mouseLayer)
	m = string(mouseLayer.Mouse(i));
	zl = string(mouseLayer.ZLayer(i));
	if ~any(zl == layerNames)
		continue;
	end
	idx = (medLT.Mouse==m) & (medLT.ZLayer==zl);
	if nnz(idx) < 10
		continue;
	end
	LA = logical(medLT.LearnedActiveMed(idx));
	TA = logical(medLT.TransferActiveMed(idx));
	den = LA;
	if nnz(den) < 1
		continue;
	end
	reuse = mean(double(TA(den)), 'omitnan');

	perf = perfByMouse.TransferPerformance(perfByMouse.Mouse==m);
	if isempty(perf)
		perf = NaN;
	else
		perf = perf(1);
	end

	rows = [rows; table(m, zl, nnz(idx), perf, reuse, ...
		'VariableNames', {'Mouse','ZLayer','NCellsUsed','TransferPerformance','Reuse'})]; %#ok<AGROW>
end

if isempty(rows)
	error('Fig3_2c:NoValidMice', 'No mice passed requirements.');
end

rows = sortrows(rows, {'ZLayer','Reuse'});
assignin('base','Fig3_2c_ReuseVsPerformance_Summary', rows);

% Spearman correlation by layer
for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	R = rows(rows.ZLayer == zl, :);
	x = R.Reuse;
	y = R.TransferPerformance;
	mask = isfinite(x) & isfinite(y);
	rho = NaN; p = NaN;
	if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rho, p] = corr(x(mask), y(mask), 'type','Spearman');
	end
	fprintf('Fig3.2c (%s) Spearman rho=%.3f, p=%.4g (n=%d)\n', zl, rho, p, nnz(mask));
end

% Plot
f = figure('Color','w', 'Name','Fig3.2c Reuse vs Performance (by layer)');
MATLAB.Graphics.FigureAspectRatio(10,4,1/2);
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

axesList = gobjects(0,1);

for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	R = rows(rows.ZLayer == zl, :);
	x = R.Reuse;
	y = R.TransferPerformance;
	mask = isfinite(x) & isfinite(y);
	rho = NaN; p = NaN;
	if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rho, p] = corr(x(mask), y(mask), 'type','Spearman');
	end

	ax = nexttile(TL, iZ);
	axesList(end+1,1) = ax; %#ok<AGROW>
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	scatter(ax, x(mask), y(mask), 50, 'filled');
	text(ax, x(mask), y(mask), R.Mouse(mask), 'FontSize', 8, 'VerticalAlignment','bottom', 'HorizontalAlignment','left');

	xlabel(ax, 'Reuse: P(Transfer active | Learned active)');
	ylabel(ax, 'Transfer phase performance');
	ylim(ax, [0 1]);
	grid(ax,'on');
	box(ax,'on');
	if isfinite(p)
		title(ax, sprintf('%s | Spearman \\rho=%.3f, p=%.3g (n=%d)', zl, rho, p, nnz(mask)), 'Interpreter','none');
	else
		title(ax, sprintf('%s | Spearman (n=%d)', zl, nnz(mask)), 'Interpreter','none');
	end
end

% Do not force xlim; unify across layers for comparability
try
	MATLAB.Graphics.UnifyAxesLims(axesList, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

sgtitle(TL, 'Reuse vs Transfer performance by ZLayer', 'Interpreter','none');

% Export (SVG only)
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

function G = iQueryNTATSOrEmpty(DS, query)
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
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


function act = iMedianActive(X, baseMask, winMask, kSigma)
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	winMx = max(X(:, winMask), [], 2, 'omitnan');
	act = winMx > (baseMu + kSigma .* baseSd);
end
