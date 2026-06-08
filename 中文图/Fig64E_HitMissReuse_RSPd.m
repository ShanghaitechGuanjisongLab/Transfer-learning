% English Fig4E: RSPd Hit vs Miss reactivation rate (paired, layers merged)
%
% Reactivation = P(Transfer active at 1 s | Learned AudioWater active at 1 s)
% compared between transfer Hit and Miss trials.
%
% Execution:
%   TransferLearning.英文图4.E_HitMissReuse_RSPd

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('EnglishFig4E:No1s', 'Cannot find sample close to 1 s.');
end
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('EnglishFig4E:BadBaseline', 'Baseline window (-3~0 s) has too few samples.');
end

learnedCell = iLearnedActiveByCell(RSP, baseMask, idx1s);
[mice, hitAll, missAll] = iHitMissReactivationByMouse(RSP, learnedCell, baseMask, idx1s);
mask = isfinite(hitAll) & isfinite(missAll);
hit = hitAll(mask);
miss = missAll(mask);
if nnz(mask) < 1
	error('EnglishFig4E:NoValidData', 'No valid mouse-level data for Fig4E.');
end

% --- Plot (mimic Fig1J: 3×4 cm, paired, FontSize 6)
svgName = "中文图Fig64E_RSPd_HitMiss_Reuse.svg";
f = figure('Color','w', 'Name','English Fig4E Hit vs Miss Reuse');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

p = NaN;
if numel(hit) >= 4
	p = signrank(hit, miss, 'tail','right');
end

Y = [hit(:), miss(:)];
hitColor = TransferLearning.ColorA;
missColor = TransferLearning.ColorB;
plot(ax, Y', '-', 'LineWidth', 0.5, 'Color', [0, 0, 0]);
scatter(ax, ones(numel(hit),1), hit, 15, hitColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', hitColor);
scatter(ax, 2*ones(numel(miss),1), miss, 15, missColor, 'filled', 'LineWidth', 0.2, 'MarkerEdgeColor', missColor);
set(ax, 'XLim',[0.5 2.5], 'XTick',[1 2], 'XTickLabel',{'Hit','Miss'});
grid(ax,'off');
box(ax,'off');
if isprop(ax, 'FontName')
	ax.FontName = 'Segoe UI Emoji';
end
ylabel(ax, 'Reactivation', 'FontSize', 6);
title(ax, '💡💧', 'FontSize', 6, 'FontWeight', 'normal');

if isfinite(p)
	S = scatter(ax, [ones(numel(hit),1); 2*ones(numel(miss),1)], [hit(:); miss(:)], ...
		1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	if isprop(S, 'HitTest'), S.HitTest = 'off'; end
	if isprop(S, 'PickableParts'), S.PickableParts = 'none'; end
	if isprop(S, 'AffectAutoLimits'), S.AffectAutoLimits = false; end
	pText = TransferLearning.Style.iFormatPText(p);
	Descriptors = table(S, 0, 0, pText, 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	[pLines, pTexts] = MATLAB.Graphics.PLine(Descriptors);
	for pl = pLines(:)'
		pl.LineWidth = 1;
		pl.Tag = 'PLine';
	end
	for pt = pTexts(:)'
		pt.FontSize = 6;
		pt.Tag = 'PText';
	end
	delete(S);
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
fprintf('Wrote: %s\n', svgPath);
fprintf('Hit mean = %.4f, Miss mean = %.4f, signrank p = %.4g, n = %d\n', ...
	mean(hit, 'omitnan'), mean(miss, 'omitnan'), p, nnz(mask));

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

function [mice, hit, miss] = iHitMissReactivationByMouse(DS, learnedCell, baseMask, idx1s)
kSigma = 3;
QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), ...
	categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
	'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});
GTranHM = DS.QueryNTATS(QT_HM, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
XTranHM = iNtatsData(GTranHM.NTATS);
XTranHit = XTranHM(:,:,1);
XTranMiss = XTranHM(:,:,2);

tranActiveHit = iActiveAt1s(XTranHit, baseMask, idx1s, kSigma);
tranActiveMiss = iActiveAt1s(XTranMiss, baseMask, idx1s, kSigma);

	hitCell = table(uint64(GTranHM.CellUID), logical(tranActiveHit), 'VariableNames', {'CellUID','TransferActiveHit'});
	missCell = table(uint64(GTranHM.CellUID), logical(tranActiveMiss), 'VariableNames', {'CellUID','TransferActiveMiss'});
	LT = innerjoin(learnedCell, hitCell, 'Keys', 'CellUID');
	LT = innerjoin(LT, missCell, 'Keys', 'CellUID');
	LT.Mouse = string(LT.Mouse);

	mice = unique(LT.Mouse, 'stable');
	hit = nan(numel(mice), 1);
	miss = nan(numel(mice), 1);
	for iM = 1:numel(mice)
		sub = LT(LT.Mouse == mice(iM), :);
		den = logical(sub.LearnedActive);
		if nnz(den) < 1
			continue;
		end
		hit(iM) = mean(double(sub.TransferActiveHit(den)), 'omitnan');
		miss(iM) = mean(double(sub.TransferActiveMiss(den)), 'omitnan');
	end
end

function act = iActiveAt1s(X, baseMask, idx1s, kSigma)
base = X(:, baseMask);
mu = mean(base, 2, 'omitnan');
sd = std(base, 0, 2, 'omitnan');
thr = mu + kSigma .* sd;
v1 = X(:, idx1s);
act = v1 > thr;
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

