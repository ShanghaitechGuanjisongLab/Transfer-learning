% 图3.6d：RSPd 命中/错失的前向复用率（配对，鼠×层）
%
% 每脚本一张子图，SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.D_HitMissReuse_RSPd

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6d_RSPd_HitMiss_Reuse_Paired.svg";

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
	error('Fig3_6d:NoHitMiss', 'Hit/Miss reuse is not available in summary.');
end

f = figure('Color','w', 'Name', 'Fig3.6d hit vs miss reuse');
ax = axes(f);
hold(ax,'on');
box(ax,'off');
grid(ax,'on');

layers = ["RSPd2/3","RSPd5"];
cols = lines(2);
xpos = [1 2];

Summary.ZLayer = string(Summary.ZLayer);

for iL = 1:2
	zl = layers(iL);
	R = Summary(Summary.ZLayer==zl, :);
	hit = double(R.ReuseRate_Hit);
	miss = double(R.ReuseRate_Miss);
	mask = isfinite(hit) & isfinite(miss);
	hit = hit(mask);
	miss = miss(mask);
	
	x = xpos + (iL-1)*2.8;
	lineCol = cols(iL,:)*0.55 + 0.45;
	for i = 1:numel(hit)
		plot(ax, x, [hit(i) miss(i)], '-', 'Color', lineCol, 'LineWidth', 1);
	end
	scatter(ax, repmat(x(1), size(hit)), hit, 28, 'filled', 'MarkerFaceAlpha', 0.85, 'MarkerFaceColor', cols(iL,:));
	scatter(ax, repmat(x(2), size(miss)), miss, 28, 'filled', 'MarkerFaceAlpha', 0.85, 'MarkerFaceColor', cols(iL,:));
	
	p = TransferLearning.Fig36.iSignrankRight(hit, miss);
	text(ax, mean(x), max([hit;miss],[],'omitnan'), sprintf('%s p=%.2g', zl, p), ...
		'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Color', cols(iL,:), 'Interpreter','none');
end

ax.XTick = [xpos xpos+2.8];
ax.XTickLabel = {'Hit','Miss','Hit','Miss'};
ylabel(ax, 'Reuse rate', 'Interpreter','none');
title(ax, 'Fig3.6d RSPd Hit vs Miss forward reuse (paired)', 'Interpreter','none');

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType','vector');
fprintf('Wrote: %s\n', svgPath);
