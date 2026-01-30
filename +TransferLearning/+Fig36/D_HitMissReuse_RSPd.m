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
	MATLAB.Graphics.FigureAspectRatio(3,2,3/4);
ax = axes(f);

% Avoid exporting axes toolbar icons
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end
hold(ax,'on');
box(ax,'off');
grid(ax,'on');

layers = ["RSPd2/3","RSPd5"];
cols = lines(2);
% mimic Fig3.3a spacing: keep layer groups away from far-left and insert a gap
xpos23 = [2 3];
xpos5  = [5 6];

Summary.ZLayer = string(Summary.ZLayer);

for iL = 1:2
	zl = layers(iL);
	R = Summary(Summary.ZLayer==zl, :);
	hit = double(R.ReuseRate_Hit);
	miss = double(R.ReuseRate_Miss);
	mask = isfinite(hit) & isfinite(miss);
	hit = hit(mask);
	miss = miss(mask);
	
	if iL == 1
		x = xpos23;
	else
		x = xpos5;
	end
	lineCol = cols(iL,:)*0.55 + 0.45;
	for i = 1:numel(hit)
		plot(ax, x, [hit(i) miss(i)], '-', 'Color', lineCol, 'LineWidth', 1);
	end
	scatter(ax, repmat(x(1), size(hit)), hit, 28, 'filled', 'MarkerFaceAlpha', 0.85, 'MarkerFaceColor', cols(iL,:));
	scatter(ax, repmat(x(2), size(miss)), miss, 28, 'filled', 'MarkerFaceAlpha', 0.85, 'MarkerFaceColor', cols(iL,:));

	% p-value line (paired signrank) via MATLAB.Graphics.PLine
	p = TransferLearning.Fig36.iSignrankRight(hit, miss);
	if isfinite(p)
		S = scatter(ax, [repmat(x(1), numel(hit), 1); repmat(x(2), numel(miss), 1)], [hit(:); miss(:)], ...
			1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
		try
			if isprop(S, 'HitTest'); S.HitTest = 'off'; end
			if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
			if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
		catch
		end
		Descriptors = table(S, 0, 0, (zl + " p=" + sprintf('%.3g', p)), 0, ...
			'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
		try
			MATLAB.Graphics.PLine(Descriptors);
		catch
		end
		try
			delete(S);
		catch
		end
	end
end

ax.XTick = [xpos23 xpos5];
ax.XTickLabel = {'Hit','Miss','Hit','Miss'};
xlim(ax, [1.3 6.7]);
ylabel(ax, 'Reuse rate', 'Interpreter','none');
title(ax, 'RSPd Hit vs Miss forward reuse (paired)', 'Interpreter','none');

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
