% 中文图333E：迁移光水散度与重激活率的相关性（全细胞单 tile）

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

ALB = TransferLearning.AudioLightBaseline();
R = iBuildTransferReactivationTable(ALB);
if isempty(R)
	error('Fig333E:EmptyReuse', 'No valid mice for reactivation summary.');
end

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok0 || ~ok1s
	error('Fig333E:TimeIndexMissing', 'Cannot find 0 s or 1 s sample in TransferLearning.Xs.');
end

Div = iBuildTransferDivergenceTable(ALB, string(R.Mouse), R.DateTimeTransfer, idx0, idx1s);
M = outerjoin(R(:, {'Mouse','DateTimeTransfer','Reactivation'}), Div, 'Keys', 'Mouse', 'MergeKeys', true, 'Type', 'left');

palette3 = TransferLearning.FigurePalette(3);
dotColor = palette3(2, :);
fitColor = palette3(3, :);

f = figure('Color', 'w', 'Name', 'Fig333E Transfer divergence vs reactivation');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

tl = tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tl, 'Divergence', 'FontSize', 6);
ylabel(tl, 'Reactivation', 'FontSize', 6);

Stats = table("All", nan, nan, nan, 'VariableNames', {'Panel','Rho','PValue','N'});

ax = nexttile(tl, 1);
hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

x = double(M.Divergence);
y = double(M.Reactivation);
use = isfinite(x) & isfinite(y);
if nnz(use) < 3
	error('Fig333E:TooFewPoints', 'Too few valid mice after filtering.');
end

scatter(ax, x(use), y(use), 5, dotColor, 'o', 'filled', 'LineWidth', 0.2);
if nnz(use) >= 2 && std(x(use)) > 0
	pFit = polyfit(x(use), y(use), 1);
	xFit = [min(x(use)), max(x(use))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'Color', fitColor, 'LineWidth', 1);
end
if std(x(use)) > 0 && std(y(use)) > 0
	[rho, p] = corr(x(use), y(use), 'Type', 'Spearman');
else
	rho = NaN;
	p = NaN;
end
text(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);

Stats.Rho(1) = rho;
Stats.PValue(1) = p;
Stats.N(1) = nnz(use);

fprintf('\n=== Fig333E All ===\n');
fprintf('n=%d, rho=%.3f, p=%.4g\n', nnz(use), rho, p);

svgPath = '中文图Fig333E_TransferDivergenceVsReactivation_ByLayer.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig333E_PerMouseData', M);
assignin('base', 'Fig333E_Stats', Stats);

function R = iBuildTransferReactivationTable(DS)
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig333E:No1s', 'Cannot find sample close to 1 s.');
end

TLearn = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
TTran = DS.TableQuery(["Mouse","DateTime","Behavior"], Phase="Transfer", Stimulus="LightWater", Design="LightWater");
if isempty(TLearn) || isempty(TTran)
	R = iEmptyReactivationResult();
	return;
end

TLearn.Mouse = string(TLearn.Mouse);
TLearn.DateTime = iNormalizeDateTime(TLearn.DateTime);
TTran.Mouse = string(TTran.Mouse);
TTran.DateTime = iNormalizeDateTime(TTran.DateTime);

dtLearnT = groupsummary(TLearn, "Mouse", "max", "DateTime");
dtLearnT.Properties.VariableNames{end} = 'DateTimeLearned';
dtTranT = groupsummary(TTran(:, ["Mouse","DateTime"]), "Mouse", "min", "DateTime");
dtTranT.Properties.VariableNames{end} = 'DateTimeTransfer';

Sess = innerjoin(dtLearnT(:, ["Mouse","DateTimeLearned"]), dtTranT(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');
if isempty(Sess)
	R = iEmptyReactivationResult();
	return;
end

rows = repmat(iEmptyReactivationResult(), 0, 1);
for iRow = 1:height(Sess)
	mouseName = string(Sess.Mouse(iRow));
	dtLearned = Sess.DateTimeLearned(iRow);
	dtTransfer = Sess.DateTimeTransfer(iRow);

	GLearn = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dtLearned, ...
		'Phase', 'Learned', 'Stimulus', 'AudioWater', 'Design', 'AudioWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	GTran = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dtTransfer, ...
		'Phase', 'Transfer', 'Stimulus', 'LightWater', 'Design', 'LightWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

	[XLearn, cellLearn] = iExtractNtats2D(GLearn);
	[XTran, cellTran] = iExtractNtats2D(GTran);
	if isempty(XLearn) || isempty(XTran)
		continue;
	end

	[commonCells, idxL, idxT] = intersect(cellLearn, cellTran, 'stable');
	if isempty(commonCells)
		continue;
	end

	XLearn = XLearn(idxL, :);
	XTran = XTran(idxT, :);
	learnedActive = iIsActiveAt1s(XLearn, baseMask, idx1s, 3);
	transferActive = iIsActiveAt1s(XTran, baseMask, idx1s, 3);
	[nLearnedActive, reactivation] = iConditionalProb(learnedActive, transferActive);

	beh = double(TTran.Behavior(TTran.Mouse == mouseName & TTran.DateTime == dtTransfer));
	transferHitRate = mean(beh, 'omitnan');
	rows = [rows; table(mouseName, dtLearned, dtTransfer, transferHitRate, nLearnedActive, reactivation, "AudioLightBaseline", ...
		'VariableNames', iEmptyReactivationResult().Properties.VariableNames)]; %#ok<AGROW>
	end

	R = rows;
end

function T = iEmptyReactivationResult()
T = table(strings(0, 1), NaT(0, 1), NaT(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), ...
	'VariableNames', {'Mouse','DateTimeLearned','DateTimeTransfer','TransferHitRate','NLearnedActive','Reactivation','Source'});
end

function Div = iBuildTransferDivergenceTable(DS, mice, dateTimes, idx0, idx1s)
Div = table(strings(0, 1), nan(0, 1), 'VariableNames', {'Mouse','Divergence'});
for i = 1:numel(mice)
	m = string(mice(i));
	dt = iNormalizeDateTime(dateTimes(i));
	T = DS.TableQuery(["TrialUID","TrialIndex","Mouse","DateTime","Stimulus","Phase"], Mouse=m, DateTime=dt, Stimulus="LightWater", Phase="Transfer");
	if isempty(T)
		continue;
	end
	T = sortrows(T, 'TrialIndex');
	trialUIDs = unique(uint64(T.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
	if iscell(nts)
		nts = nts{1};
	end
	if isempty(nts)
		continue;
	end
	[ctt, ~] = iBuildCTT(nts, trialUIDs, idx0);
	if isempty(ctt) || size(ctt, 2) < 2
		continue;
	end
	xAt1 = ctt(:, :, idx1s);
	divValue = iAllCellDivergence(xAt1);
	Div = [Div; table(m, divValue, 'VariableNames', Div.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function div = iAllCellDivergence(xAt1)
if size(xAt1, 1) < 3
	div = NaN;
	return;
end
X = xAt1;
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function [ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0)
ctt = [];
cellUIDs = uint64([]);
keepTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts = nts(keepTrial, :);
if isempty(nts)
	return;
end
trialUIDs = trialUIDs(ismember(trialUIDs, unique(uint64(nts.TrialUID), 'stable')));
if numel(trialUIDs) < 2
	return;
end
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rows = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rows));
	sig = double(nts.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	ordered = sig(loc, :);
	if any(~isfinite(ordered), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traceCell{nKeep} = ordered;
	keepUID(nKeep) = cid;
end
if nKeep < 1
	return;
end
traceCell = traceCell(1:nKeep);
keepUID = keepUID(1:nKeep);
nTrial = size(traceCell{1}, 1);
nTime = size(traceCell{1}, 2);
ctt = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	ctt(iC, :, :) = traceCell{iC};
end
ctt = ctt - ctt(:, :, idx0);
cellUIDs = keepUID;
end

function [X, cellUID] = iExtractNtats2D(G)
cellUID = uint64([]);
X = [];
if isempty(G)
	return;
end
nt = G.NTATS;
cellUID = uint64(G.CellUID);
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data;
else
	X = nt;
end
X = double(X);
if ndims(X) == 3
	X = squeeze(X(:, :, 1));
end
end

function active = iIsActiveAt1s(X, baseMask, idx1s, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
active = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma .* baseSd));
end

function [nLearned, prob] = iConditionalProb(learnedActive, transferActive)
use = learnedActive;
	nLearned = nnz(use);
	if nLearned < 1
		prob = NaN;
	else
		prob = mean(double(transferActive(use)), 'omitnan');
	end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function txt = iPLabel(p)
if ~isfinite(p)
	txt = 'p = NaN';
elseif p < 0.001
	txt = 'p < 0.001';
elseif p < 0.01
	txt = sprintf('p = %.3f', p);
else
	txt = sprintf('p = %.2f', p);
end
end

