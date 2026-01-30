% 图3.6b：MultiShadowedLines 叠加比较（迁移光水）RSPd vs MOp 全细胞平均 NTATS（不分层）
%
% 每脚本一张子图，SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.B_OnsetCompare_RSPd_vs_MOp

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6b_Onset_RSPd_vs_MOp_TransferLW.svg";

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
MOp = TransferLearning.AudioLightBaseline();
xsSec = seconds(TransferLearning.Xs);

GRSP = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GMOp = MOp.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XRSP = TransferLearning.Fig36.iNtatsData(GRSP.NTATS);
XMOp = TransferLearning.Fig36.iNtatsData(GMOp.NTATS);

meanRSP = mean(XRSP, 1, 'omitnan');
meanMOp = mean(XMOp, 1, 'omitnan');
semRSP  = std(XRSP, 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XRSP), 1)));
semMOp  = std(XMOp, 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(XMOp), 1)));

f = figure('Color','w', 'Name', 'Fig3.6b mean NTATS overlay');
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

cols = [0.20 0.40 0.85; 0.85 0.35 0.20];
meanCells = {meanRSP(:), meanMOp(:)};
semCells  = {semRSP(:),  semMOp(:)};

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, X=xsSec(:), EdgeColors=cols);

% cue/water lines first; legend MUST be after this
TransferLearning.DrawCueWaterLines(ax);

try
	legend([Patches(1).Edge, Patches(2).Edge], {'RSPd','MOp'}, 'Location','best', 'Box','off');
catch
	legend({'RSPd','MOp'}, 'Location','best', 'Box','off');
end

xlabel(ax, 'Time from cue(:) water(|) (s)', 'Interpreter','none');
ylabel(ax, 'Mean z-score', 'Interpreter','none');
title(ax, 'Mean NTATS (Transfer LW): RSPd vs MOp', 'Interpreter','none');

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

