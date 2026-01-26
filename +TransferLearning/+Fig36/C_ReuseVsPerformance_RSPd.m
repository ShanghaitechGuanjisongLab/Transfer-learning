% 图3.6c：RSPd 复用率与迁移表现（鼠×层）
%
% 每脚本一张子图，SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.C_ReuseVsPerformance_RSPd

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6c_RSPd_Reuse_vs_Performance.svg";

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

f = figure('Color','w', 'Name', 'Fig3.6c reuse vs performance');
MATLAB.Graphics.FigureAspectRatio(8,5,1/2);
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

Summary.ZLayer = string(Summary.ZLayer);

layers = ["RSPd2/3","RSPd5"];
cols = lines(2);

hScat = gobjects(1,2);

for iL = 1:2
	zl = layers(iL);
	R = Summary(Summary.ZLayer==zl, :);
	x = double(R.ReuseRate);
	y = double(R.TransferPerformance);
	use = isfinite(x) & isfinite(y);
	hScat(iL) = scatter(ax, x(use), y(use), 40, 'filled', 'MarkerFaceAlpha', 0.75, 'MarkerFaceColor', cols(iL,:));
	
	% trend line segment
	if nnz(use) >= 2 && std(x(use),'omitnan') > 0
		b = polyfit(x(use), y(use), 1);
		xLine = [min(x(use)), max(x(use))];
		yLine = polyval(b, xLine);
		hLine = plot(ax, xLine, yLine, '-', 'Color', cols(iL,:)*0.75 + 0.25, 'LineWidth', 1.5);
		try
			hLine.HandleVisibility = 'off';
		catch
		end
	end
	[rho,p] = TransferLearning.Fig36.iSpearman(R.ReuseRate, R.TransferPerformance);
	text(ax, 0.02, 0.95-(iL-1)*0.10, sprintf('%s: \\rho=%.2f p=%.2g', zl, rho, p), ...
		'Units','normalized', 'Interpreter','tex', 'Color', cols(iL,:));
end

xlabel(ax, 'Reuse rate P(TransferActive | LearnedActive)', 'Interpreter','none');
ylabel(ax, 'Transfer performance', 'Interpreter','none');
title(ax, 'RSPd reuse vs performance', 'Interpreter','none');
try
	legend(ax, hScat, layers, 'Location','southeast', 'Box','off');
catch
	legend(ax, layers, 'Location','southeast', 'Box','off');
end

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType','vector');
fprintf('Wrote: %s\n', svgPath);
