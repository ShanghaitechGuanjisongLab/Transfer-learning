function Fig4F_SD0p3sVsLearningSpeed_RSPd()
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);
xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);

kSigma = 3;
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('EnglishFig4F:BadBaselineMask', 'Baseline window has too few samples.');
end

[idx1, ok1] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1
	error('EnglishFig4F:No1s', 'Cannot find sample close to 1s.');
end

qLearnedAudio = struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater');
QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), ...
	categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
	'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});

G = struct();
G.LearnedAudio = RSP.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit  = RSP.QueryNTATS(QT_HM(1,:), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = RSP.QueryNTATS(QT_HM(2,:), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

XL = double(squeeze(X(:,:,1)));
baseMu = mean(XL(:, baseMask), 2, 'omitnan');
baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
val1 = XL(:, idx1);
keep = isfinite(val1) & (val1 > (baseMu + kSigma .* baseSd));
X = X(keep, :, :);

XPlot = X(:, xMask, :);
meanL = mean(XPlot(:,:,1), 1, 'omitnan');
meanH = mean(XPlot(:,:,2), 1, 'omitnan');
meanM = mean(XPlot(:,:,3), 1, 'omitnan');
semL = std(XPlot(:,:,1), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XPlot(:,:,1)), 1)));
semH = std(XPlot(:,:,2), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XPlot(:,:,2)), 1)));
semM = std(XPlot(:,:,3), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XPlot(:,:,3)), 1)));

f = figure('Color','w', 'Name','English Fig4F Learned-active curves');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 12;
ax.FontName = 'Segoe UI Emoji';
ax.LineWidth = 2;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end

cols = [TransferLearning.LearnedColor; TransferLearning.ColorA; TransferLearning.ColorB];
meanCells = {meanL(:), meanH(:), meanM(:)};
semCells  = {semL(:),  semH(:),  semM(:)};

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 0.2, X=xsPlot(:), EdgeColors=cols);
for iPatch = 1:numel(Patches)
	if isprop(Patches(iPatch), 'LineWidth')
		Patches(iPatch).LineWidth = 2;
	end
	setappdata(Patches(iPatch), 'TransferLearningPreserveLineWidth', true);
	if isprop(Patches(iPatch), 'FaceAlpha')
		Patches(iPatch).FaceAlpha = 1/3;
	end
end

xline(ax, 0, '--', 'LineWidth', 2);
xline(ax, 1, '--', 'LineWidth', 2);

box(ax,'off');
grid(ax,'off');
ax.TickLabelInterpreter = 'none';
ax.XTick = [0 1];
ax.XTickLabel = {"🔊/💡", "💧"};
if isprop(ax.XAxis, 'FontName')
	ax.XAxis.FontName = 'Segoe UI Emoji';
end
if isprop(ax.YAxis, 'FontName')
	ax.YAxis.FontName = 'Arial';
end
ylabel(ax, 'z-score', 'FontSize', 12);

xlabel(ax, 'Time (s)', 'FontSize', 12);

labels = {'🔊', '💡 Hit', '💡 Miss'};
lgd = legend(Patches, labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box','off', 'FontSize', 12);
lgd.FontName = 'Segoe UI Emoji';
title('🔊💧 active cells', 'FontSize', 12, 'FontWeight', 'normal');

allText = findall(f, 'Type', 'Text');
for iText = 1:numel(allText)
	allText(iText).FontSize = 12;
end

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgName = "English_Fig4F_RSPd_LearnedActive_Curves.svg";
svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'English_Fig4F_nCells', size(X,1));
end

function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S,'NTATS')
	nt = S.NTATS;
else
	nt = S;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end
if isnumeric(nt) && ndims(nt) == 3
	X = nt;
	return;
end
error('EnglishFig4F:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

