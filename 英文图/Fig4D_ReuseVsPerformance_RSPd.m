% English Fig4D: RSPd reuse rate vs transfer performance (per mouse × layer)
%
% Scatter plot with Spearman correlation, following Fig1K style (3×4 cm).
%
% Execution:
%   TransferLearning.英文图4.C_ReuseVsPerformance_RSPd

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask01 = (xsSec >= 0) & (xsSec <= 1);

GLearn = RSP.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTran  = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XLearn = TransferLearning.Fig36.iNtatsData(GLearn.NTATS);
XTran  = TransferLearning.Fig36.iNtatsData(GTran.NTATS);

% --- Reactivation per mouse (all layers pooled)
kSigma = 3;
learnedBaseMu = mean(XLearn(:, baseMask), 2, 'omitnan');
learnedBaseSd = std(XLearn(:, baseMask), 0, 2, 'omitnan');
learnedWinMx  = max(XLearn(:, winMask01), [], 2, 'omitnan');
learnedActive = learnedWinMx > (learnedBaseMu + kSigma .* learnedBaseSd);

tranBaseMu = mean(XTran(:, baseMask), 2, 'omitnan');
tranBaseSd = std(XTran(:, baseMask), 0, 2, 'omitnan');
tranWinMx  = max(XTran(:, winMask01), [], 2, 'omitnan');
tranActive = tranWinMx > (tranBaseMu + kSigma .* tranBaseSd);

C = RSP.Cells;
learnedCell = innerjoin(table(uint64(GLearn.CellUID), learnedActive, 'VariableNames', {'CellUID','LearnedActive'}), ...
	C(:,{'CellUID','Mouse'}), 'Keys','CellUID');
transferCell = table(uint64(GTran.CellUID), tranActive, 'VariableNames', {'CellUID','TransferActive'});
medLT = innerjoin(learnedCell, transferCell, 'Keys','CellUID');
medLT.Mouse = string(medLT.Mouse);

PerfT = RSP.TableQuery(["Mouse","Performance"], Phase="Transfer", Design="LightWater");
PerfT.Mouse = string(PerfT.Mouse);

mice = unique(medLT.Mouse);
x = nan(numel(mice), 1);
y = nan(numel(mice), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	rows = medLT.Mouse == m;
	LA = logical(medLT.LearnedActive(rows));
	TA = logical(medLT.TransferActive(rows));
	if nnz(LA) > 0
		x(iM) = mean(double(TA(LA)), 'omitnan');
	end
	perf = PerfT.Performance(PerfT.Mouse == m);
	y(iM) = mean(double(perf), 'omitnan');
end
use = isfinite(x) & isfinite(y);

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
ax.Toolbar.Visible = 'off';

palette3 = TransferLearning.FigurePalette(3);
scatter(ax, x(use), y(use), 5, palette3(1,:), 'LineWidth', 0.2);

% Fit line
if nnz(use) >= 2 && std(x(use),'omitnan') > 0
	b = polyfit(x(use), y(use), 1);
	xFit = [min(x(use)), max(x(use))];
	yFit = polyval(b, xFit);
	plot(ax, xFit, yFit, '-', 'Color', palette3(2,:), 'LineWidth', 1, 'HandleVisibility','off');
end

[rho, p] = TransferLearning.Fig36.iSpearman(x(use), y(use));
if isfinite(p)
	if p < 0.001, sigLabel = '***';
	elseif p < 0.01, sigLabel = '**';
	elseif p < 0.05, sigLabel = '*';
	else, sigLabel = 'n.s.';
	end
	text(ax, 0.95, 0.95, sigLabel, ...
		'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','top', 'FontSize', 6);
end

box(ax,'off');
grid(ax,'off');
xlabel(ax, 'Reactivation', 'FontSize', 6);
ylabel(ax, 'Transfer hit rate', 'FontSize', 6);

% --- Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
