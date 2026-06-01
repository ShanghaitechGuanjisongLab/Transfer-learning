% English Fig4D: RSPd reactivation vs first-session transfer performance
%
% Scatter plot with Spearman correlation, aligned to manuscript Fig 3-5-1D.
%
% Execution:
%   TransferLearning.英文图4.D_ReuseVsPerformance_RSPd

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('EnglishFig4D:No1s', 'Cannot find sample close to 1 s.');
end
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('EnglishFig4D:BadBaseline', 'Baseline window (-3~0 s) has too few samples.');
end

learnedCell = iLearnedActiveByCell(RSP, baseMask, idx1s);
firstPerf = iFirstTransferSessionPerformance(RSP);
firstReuse = iFirstTransferSessionReuse(RSP, firstPerf(:, {'Mouse','DateTime'}), learnedCell, baseMask, idx1s);

J = innerjoin(firstPerf, firstReuse, 'Keys', {'Mouse','DateTime'});
x = double(J.Reactivation);
y = double(J.Performance);
use = isfinite(x) & isfinite(y);
if nnz(use) < 1
	error('EnglishFig4D:NoValidData', 'No valid mouse-level data for Fig4D.');
end

% --- Plot
svgName = "English_Fig4D_RSPd_Reuse_vs_Performance.svg";
f = figure('Color','w', 'Name','English Fig4D Reuse vs Perf');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 6;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

scatterColor = TransferLearning.ColorA;
fitColor = [0, 0, 0];
scatter(ax, x(use), y(use), 8, scatterColor, 'filled', ...
	'MarkerEdgeColor', scatterColor, 'LineWidth', 0.2);

if nnz(use) >= 2 && std(x(use), 'omitnan') > 0
	b = polyfit(x(use), y(use), 1);
	xFit = [min(x(use)), max(x(use))];
	yFit = polyval(b, xFit);
	plot(ax, xFit, yFit, '-', 'Color', fitColor, 'LineWidth', 1, 'HandleVisibility','off');
end

[rho, p] = iSpearman(x(use), y(use));
if isfinite(p)
	if p < 0.001, sigLabel = '***';
	elseif p < 0.01, sigLabel = '**';
	elseif p < 0.05, sigLabel = '*';
	else, sigLabel = 'n.s.';
	end
	iText(ax, 0.95, 0.95, sigLabel, ...
		'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','top', 'FontSize', 6);
end

box(ax,'off');
grid(ax,'off');
xlabel(ax, 'Reactivation', 'FontSize', 6);
ylabel(ax, '💡💧 hit rate', 'FontSize', 6);

svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);
fprintf('Spearman rho = %.4f, p = %.4g, n = %d\n', rho, p, nnz(use));

function learnedCell = iLearnedActiveByCell(DS, baseMask, idx1s)
kSigma = 3;
G = DS.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater'), ...
	UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
X = iNtatsData(G.NTATS);
act = iActiveAt1s(X, baseMask, idx1s, kSigma);
C = DS.Cells;
learnedCell = table(uint64(G.CellUID), logical(act), 'VariableNames', {'CellUID','LearnedActive'});
learnedCell = innerjoin(learnedCell, C(:, {'CellUID','Mouse'}), 'Keys', 'CellUID');
learnedCell.Mouse = string(learnedCell.Mouse);
end

function Tout = iFirstTransferSessionPerformance(DS)
T = DS.TableQuery(["Mouse","DateTime","Performance"], Phase="Transfer", Design="LightWater");
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = sortrows(T, {'Mouse','DateTime'});

mice = unique(T.Mouse, 'stable');
outMouse = strings(numel(mice), 1);
outDT = NaT(numel(mice), 1);
outPerf = nan(numel(mice), 1);
for iM = 1:numel(mice)
	rows = T(T.Mouse == mice(iM), :);
	firstDT = rows.DateTime(1);
	outMouse(iM) = mice(iM);
	outDT(iM) = firstDT;
	outPerf(iM) = mean(double(rows.Performance(rows.DateTime == firstDT)), 'omitnan');
end
Tout = table(outMouse, outDT, outPerf, 'VariableNames', {'Mouse','DateTime','Performance'});
end

function Tout = iFirstTransferSessionReuse(DS, SessKey, learnedCell, baseMask, idx1s)
kSigma = 3;
SessKey.Mouse = string(SessKey.Mouse);
SessKey.DateTime = iNormalizeDateTime(SessKey.DateTime);
SessKey = unique(SessKey(:, {'Mouse','DateTime'}), 'rows');

outMouse = strings(0,1);
outDT = NaT(0,1);
outReuse = nan(0,1);

for i = 1:height(SessKey)
	q = struct('Mouse', SessKey.Mouse(i), 'DateTime', SessKey.DateTime(i), 'Stimulus', 'LightWater');
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
	if isempty(ntsCell) || isempty(ntsCell{1})
		continue;
	end
	[uid, transferActive] = iTransferActiveFromSessionNtsMedian(ntsCell{1}, baseMask, idx1s, kSigma);
	if isempty(uid)
		continue;
	end
	transferCell = table(uid, logical(transferActive), 'VariableNames', {'CellUID','TransferActive'});
	LT = innerjoin(learnedCell, transferCell, 'Keys', 'CellUID');
	LT = LT(LT.Mouse == SessKey.Mouse(i), :);
	den = logical(LT.LearnedActive);
	if nnz(den) < 1
		continue;
	end
	reuse = mean(double(LT.TransferActive(den)), 'omitnan');

	outMouse(end+1,1) = SessKey.Mouse(i); %#ok<AGROW>
	outDT(end+1,1) = SessKey.DateTime(i); %#ok<AGROW>
	outReuse(end+1,1) = reuse; %#ok<AGROW>
end

Tout = table(outMouse, outDT, outReuse, 'VariableNames', {'Mouse','DateTime','Reactivation'});
end

function act = iActiveAt1s(X, baseMask, idx1s, kSigma)
base = X(:, baseMask);
mu = mean(base, 2, 'omitnan');
sd = std(base, 0, 2, 'omitnan');
thr = mu + kSigma .* sd;
v1 = X(:, idx1s);
act = v1 > thr;
end

function [cellUIDs, active] = iTransferActiveFromSessionNtsMedian(nts, baseMask, idx1s, kSigma)
cellUIDs = unique(uint64(nts.CellUID));
active = false(numel(cellUIDs), 1);
for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	rows = (uint64(nts.CellUID) == cid);
	sig = double(nts.TrialSignal(rows, :));
	med = median(sig, 1, 'omitnan');
	mu = mean(med(baseMask), 2, 'omitnan');
	sd = std(med(baseMask), 0, 2, 'omitnan');
	v1 = med(idx1s);
	active(iC) = isfinite(v1) && isfinite(mu) && isfinite(sd) && (v1 > (mu + kSigma * sd));
	end
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function X = iNtatsData(NT)
if isa(NT, 'MATLAB.DataTypes.NDTable')
	X = NT.Data;
else
	X = NT;
end
X = squeeze(X);
end

function [rho, p] = iSpearman(x, y)
if numel(x) < 2
	rho = NaN;
	p = NaN;
	return;
end
[rho, p] = corr(x(:), y(:), 'Type', 'Spearman', 'Rows', 'complete');
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function h = iText(varargin)
h = text(varargin{:});
end

