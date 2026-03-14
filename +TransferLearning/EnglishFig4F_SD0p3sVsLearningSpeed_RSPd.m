function EnglishFig4F_SD0p3sVsLearningSpeed_RSPd()
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);

kSigma = 3;
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('EnglishFig4F:BadBaselineMask', 'Baseline window has too few samples.');
end

[idx1, ok1] = TransferLearning.Fig36.iFindTimeIndex(xsSec, 1, 0.25);
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

meanL = mean(X(:,:,1), 1, 'omitnan');
meanH = mean(X(:,:,2), 1, 'omitnan');
meanM = mean(X(:,:,3), 1, 'omitnan');
semL = std(X(:,:,1), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(X(:,:,1)), 1)));
semH = std(X(:,:,2), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(X(:,:,2)), 1)));
semM = std(X(:,:,3), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(X(:,:,3)), 1)));

f = figure('Color','w', 'Name','English Fig4F Learned-active curves');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 6;
ax.Toolbar.Visible = 'off';

% Reference palette from 范例 SVGs: #e60012, #0070c0, #f39800
cols = [243/255, 152/255, 0;        % Learned AW   – #f39800 orange
        0,       112/255, 192/255;  % Transfer Hit – #0070c0 blue
        230/255, 0,       18/255];  % Transfer Miss – #e60012 crimson
meanCells = {meanL(:), meanH(:), meanM(:)};
semCells  = {semL(:),  semH(:),  semM(:)};

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 0.2, X=xsSec(:), EdgeColors=cols);

xline(ax, 0, ':k');
xline(ax, 1, '-k');

box(ax,'off');
grid(ax,'off');
xlabel(ax, 'Time (s)', 'FontSize', 6);
ylabel(ax, 'z-score', 'FontSize', 6);

labels = {'🔊💧', '💡💧 Hit', '💡💧 Miss'};
legend(Patches, labels, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Patches), 'Box','off', 'FontSize', 6);
title('🔊💧 active cells', 'FontSize', 6, 'FontWeight', 'normal');

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgName = "English_Fig4F_RSPd_LearnedActive_Curves.svg";
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
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