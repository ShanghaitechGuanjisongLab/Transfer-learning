% 图3.6e：RSPd 0.3s 细胞间 SD 与学习速度（ΔNext）
%
% 每脚本一张子图，SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.E_SD0p3sVsLearningSpeed_RSPd

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6e_RSPd_SD0p3s_vs_LearningSpeed_DeltaNext.svg";

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
[idx0p3, ok0p3] = TransferLearning.Fig36.iFindTimeIndex(xsSec, 0.3, 0.25);
if ~ok0p3
	error('Fig3_6e:No0p3', 'Cannot find sample close to 0.3s in TransferLearning.Xs.');
end

Sess = TransferLearning.Fig36.iRSPdTransferSessionSpeed(RSP);
SessSD = TransferLearning.Fig36.iRSPdSessionSD(RSP, Sess, idx0p3, []);

f = figure('Color','w', 'Name', 'Fig3.6e SD@0.3 vs speed');
ax = axes(f);
hold(ax,'on');
box(ax,'off');
grid(ax,'on');

x23 = SessSD.StdCells0p3_RSPd23;
x5  = SessSD.StdCells0p3_RSPd5;
y = SessSD.Speed_DeltaNext;

cols = lines(2);

m23 = isfinite(x23) & isfinite(y);
m5  = isfinite(x5)  & isfinite(y);

scatter(ax, x23(m23), y(m23), 20, 'filled', 'MarkerFaceAlpha', 0.65, 'MarkerFaceColor', cols(1,:));
scatter(ax, x5(m5),  y(m5),  20, 'filled', 'MarkerFaceAlpha', 0.65, 'MarkerFaceColor', cols(2,:));

[r23,p23] = TransferLearning.Fig36.iSpearman(x23(m23), y(m23));
[r5,p5]   = TransferLearning.Fig36.iSpearman(x5(m5),  y(m5));

text(ax, 0.02, 0.95, sprintf('RSPd2/3: \\rho=%.2f p=%.2g', r23, p23), 'Units','normalized', 'Interpreter','tex', 'Color', cols(1,:));
text(ax, 0.02, 0.85, sprintf('RSPd5:   \\rho=%.2f p=%.2g', r5, p5),  'Units','normalized', 'Interpreter','tex', 'Color', cols(2,:));

xlabel(ax, 'Inter-cell SD @0.3s', 'Interpreter','none');
ylabel(ax, 'Learning speed ΔNext', 'Interpreter','none');
title(ax, 'Fig3.6e RSPd SD@0.3s vs learning speed (Transfer)', 'Interpreter','none');
legend(ax, {'RSPd2/3','RSPd5'}, 'Location','best', 'Box','off');

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType','vector');
fprintf('Wrote: %s\n', svgPath);
