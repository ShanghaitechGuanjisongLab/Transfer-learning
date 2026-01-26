% 图3.6b：提示后起始时延（迁移光水）RSPd vs MOp
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
baseMask = (xsSec >= -3) & (xsSec < 0);

GRSP = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GMOp = MOp.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XRSP = TransferLearning.Fig36.iNtatsData(GRSP.NTATS);
XMOp = TransferLearning.Fig36.iNtatsData(GMOp.NTATS);

onRSP = TransferLearning.Fig36.iOnsetByCell(XRSP, xsSec, baseMask);
onMOp = TransferLearning.Fig36.iOnsetByCell(XMOp, xsSec, baseMask);

CRSP = innerjoin(table(uint64(GRSP.CellUID), onRSP, 'VariableNames', {'CellUID','OnsetSec'}), RSP.Cells(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
CMOp = innerjoin(table(uint64(GMOp.CellUID), onMOp, 'VariableNames', {'CellUID','OnsetSec'}), MOp.Cells(:,{'CellUID','ZLayer'}), 'Keys','CellUID');
CRSP.ZLayer = string(CRSP.ZLayer);
CMOp.ZLayer = string(CMOp.ZLayer);

% assemble groups
G = [repmat("RSPd2/3", sum(isfinite(CRSP.OnsetSec(CRSP.ZLayer=="RSPd2/3"))), 1);
	 repmat("MOp2/3",  sum(isfinite(CMOp.OnsetSec(CMOp.ZLayer=="MOp2/3"))), 1);
	 repmat("RSPd5",   sum(isfinite(CRSP.OnsetSec(CRSP.ZLayer=="RSPd5"))), 1);
	 repmat("MOp5",    sum(isfinite(CMOp.OnsetSec(CMOp.ZLayer=="MOp5"))), 1)];

Y = [CRSP.OnsetSec(CRSP.ZLayer=="RSPd2/3" & isfinite(CRSP.OnsetSec));
	 CMOp.OnsetSec(CMOp.ZLayer=="MOp2/3" & isfinite(CMOp.OnsetSec));
	 CRSP.OnsetSec(CRSP.ZLayer=="RSPd5" & isfinite(CRSP.OnsetSec));
	 CMOp.OnsetSec(CMOp.ZLayer=="MOp5" & isfinite(CMOp.OnsetSec))];

cats = categorical(cellstr(G), {'RSPd2/3','MOp2/3','RSPd5','MOp5'});

f = figure('Color','w', 'Name', 'Fig3.6b onset compare');
ax = axes(f);
hold(ax,'on');
box(ax,'off');
grid(ax,'on');

try
	boxchart(ax, cats, Y, 'MarkerStyle','none');
catch
	plot(ax, double(cats), Y, 'k.');
end
scatter(ax, double(cats)+0.08*(rand(size(Y))-0.5), Y, 10, 'filled', 'MarkerFaceAlpha', 0.25, 'MarkerEdgeAlpha', 0);

ylabel(ax, 'Onset latency (s)', 'Interpreter','none');
title(ax, 'Fig3.6b Onset latency: RSPd vs MOp (Transfer LightWater)', 'Interpreter','none');

% simple p-values (rank-sum) within layer
try
	p23 = ranksum(CRSP.OnsetSec(CRSP.ZLayer=="RSPd2/3"), CMOp.OnsetSec(CMOp.ZLayer=="MOp2/3"));
	p5  = ranksum(CRSP.OnsetSec(CRSP.ZLayer=="RSPd5"),  CMOp.OnsetSec(CMOp.ZLayer=="MOp5"));
	text(ax, 0.02, 0.95, sprintf('Layer2/3 ranksum p=%.2g', p23), 'Units','normalized', 'Interpreter','none');
	text(ax, 0.02, 0.86, sprintf('Layer5   ranksum p=%.2g', p5),  'Units','normalized', 'Interpreter','none');
catch
end

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType','vector');
fprintf('Wrote: %s\n', svgPath);
