% 图3.6a：RSPd 任务区分（Learned AudioWater vs Transfer LightWater）
%
% 每脚本一张子图，SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.A_TaskDiscrimination

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6a_RSPd_TaskDiscrimination_Peak01s.svg";

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
winMask01 = (xsSec >= 0) & (xsSec <= 1);

GLearn = RSP.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTran  = RSP.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

XLearn = TransferLearning.Fig36.iNtatsData(GLearn.NTATS);
XTran  = TransferLearning.Fig36.iNtatsData(GTran.NTATS);

peakLearn = max(XLearn(:, winMask01), [], 2, 'omitnan');
peakTran  = max(XTran(:,  winMask01), [], 2, 'omitnan');

C_RSP = RSP.Cells(:, {'CellUID','ZLayer'});
TL = table(uint64(GLearn.CellUID), double(peakLearn), 'VariableNames', {'CellUID','PeakLearned01'});
TT = table(uint64(GTran.CellUID),  double(peakTran),  'VariableNames', {'CellUID','PeakTransfer01'});
Jpk = innerjoin(innerjoin(TL, TT, 'Keys','CellUID'), C_RSP, 'Keys','CellUID');
Jpk.ZLayer = string(Jpk.ZLayer);

f = figure('Color','w', 'Name', 'Fig3.6a RSPd task discrimination');
ax = axes(f);

hold(ax,'on');
box(ax,'off');
grid(ax,'on');

layers = ["RSPd2/3","RSPd5"];
cols = lines(2);
for iL = 1:2
	zl = layers(iL);
	R = Jpk(Jpk.ZLayer==zl & isfinite(Jpk.PeakLearned01) & isfinite(Jpk.PeakTransfer01), :);
	scatter(ax, R.PeakLearned01, R.PeakTransfer01, 12, 'filled', 'MarkerFaceAlpha', 0.55, 'MarkerFaceColor', cols(iL,:));
	[rho,p] = TransferLearning.Fig36.iSpearman(R.PeakLearned01, R.PeakTransfer01);
	text(ax, 0.02, 0.95-(iL-1)*0.10, sprintf('%s: \\rho=%.2f p=%.2g', zl, rho, p), ...
		'Units','normalized', 'Interpreter','tex', 'Color', cols(iL,:));
end

% diagonal
xl = xlim(ax); yl = ylim(ax);
mm = [min([xl yl]) max([xl yl])];
plot(ax, mm, mm, 'k:', 'LineWidth', 1);

xlabel(ax, 'Peak z-score (Learned AudioWater, 0-1s)', 'Interpreter','none');
ylabel(ax, 'Peak z-score (Transfer LightWater, 0-1s)', 'Interpreter','none');
title(ax, 'Fig3.6a RSPd task discrimination (cell peak, 0–1s)', 'Interpreter','none');
legend(ax, layers, 'Location','southeast', 'Box','off');

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType','vector');
fprintf('Wrote: %s\n', svgPath);
