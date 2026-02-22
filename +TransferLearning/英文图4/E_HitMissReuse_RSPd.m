% English Fig4E: RSPd Hit vs Miss forward reuse rate (paired, layers merged)
%
% Mimic Fig1J style: 3×4cm, paired dots+lines, signrank asterisks, FontSize 6.
%
% Execution:
%   TransferLearning.英文图4.D_HitMissReuse_RSPd

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask01 = (xsSec >= 0) & (xsSec <= 1);

GLearn = RSP.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTran  = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XLearn = TransferLearning.Fig36.iNtatsData(GLearn.NTATS);
XTran  = TransferLearning.Fig36.iNtatsData(GTran.NTATS);

Summary = TransferLearning.Fig36.iRSPdReuseSummary(RSP, GLearn, GTran, XLearn, XTran, xsSec, baseMask, winMask01);

if ~ismember('ReuseRate_Hit', Summary.Properties.VariableNames)
	error('EnglishFig4E:NoHitMiss', 'Hit/Miss reuse not available.');
end

% --- Merge layers: average 2/3 and 5 per mouse
Summary.ZLayer = string(Summary.ZLayer);
Summary.Mouse = string(Summary.Mouse);
mice = unique(Summary.Mouse);
hitAll = nan(numel(mice), 1);
missAll = nan(numel(mice), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	R = Summary(Summary.Mouse == m, :);
	hitAll(iM) = mean(R.ReuseRate_Hit, 'omitnan');
	missAll(iM) = mean(R.ReuseRate_Miss, 'omitnan');
end
mask = isfinite(hitAll) & isfinite(missAll);
hit = hitAll(mask);
miss = missAll(mask);

% --- Plot (mimic Fig1J: 3×4cm, paired, FontSize 6)
svgName = "English_Fig4E_RSPd_HitMiss_Reuse.svg";
f = figure('Color','w', 'Name','English Fig4E Hit vs Miss Reuse');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 6;
ax.Toolbar.Visible = 'off';

p = NaN;
if numel(hit) >= 4
	p = signrank(hit, miss, 'tail','right');
end

Y = [hit(:), miss(:)];
plot(ax, Y', '-', 'LineWidth', 0.75, 'Color', [0.5 0.5 0.5]);
scatter(ax, ones(numel(hit),1), hit, 15, [0 0.4470 0.7410], 'filled');
scatter(ax, 2*ones(numel(miss),1), miss, 15, [0 0.4470 0.7410], 'filled');
set(ax, 'XLim',[0.5 2.5], 'XTick',[1 2], 'XTickLabel',{'Hit','Miss'});

grid(ax,'off');
box(ax,'off');
ylabel(ax, 'Reuse rate', 'FontSize', 6);

% p-value asterisk via PLine (mimic Fig1J)
if isfinite(p)
	S = scatter(ax, [ones(numel(hit),1); 2*ones(numel(miss),1)], [hit(:); miss(:)], ...
		1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	if isprop(S, 'HitTest'), S.HitTest = 'off'; end
	if isprop(S, 'PickableParts'), S.PickableParts = 'none'; end
	if isprop(S, 'AffectAutoLimits'), S.AffectAutoLimits = false; end

	if p < 0.001, pText = "***";
	elseif p < 0.01, pText = "**";
	elseif p < 0.05, pText = "*";
	else, pText = "n.s.";
	end
	Descriptors = table(S, 0, 0, pText, 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	[~, pTexts] = MATLAB.Graphics.PLine(Descriptors);
	for pt = pTexts(:)'
		pt.FontSize = 6;
	end
	delete(S);
end

text(ax, 0.02, 0.98, sprintf('n=%d', numel(hit)), 'Units','normalized', ...
	'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 6);

% --- Export
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
