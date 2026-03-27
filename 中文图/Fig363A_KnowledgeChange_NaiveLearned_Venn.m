% 中文图363A：知识增减（Naive→Learned）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
queryXlsx = '\\Data-Server-2\个人数据\张天夫\202512\尝试查询表.xlsx';
Data = Fig363_GlobalKnowledgeChangeCache(queryXlsx);

iPlotKnowledgeVenn(Data.PairStats(1, :), '中文图363A Knowledge change Naive to Learned', [6, 8], fullfile(outDirUNC, '中文图Fig363A_KnowledgeChange_NaiveLearned_Venn.svg'));

function iPlotKnowledgeVenn(pairRow, figureName, figSizeCm, svgPath)
	f = figure('Color', 'w', 'Name', figureName);
	f.Units = 'centimeters';
	f.Position(3:4) = figSizeCm;
	f.PaperUnits = 'centimeters';
	f.PaperPositionMode = 'manual';
	f.PaperPosition = [0, 0, figSizeCm];
	f.PaperSize = figSizeCm;

	ax = axes(f);
	[Circles, Texts] = MATLAB.Graphics.Venn(pairRow.Knowledge{1}, MATLAB.SignificantFixedpoint(pairRow.Knowledge{1}, 2));
	axis(ax, 'off');
	for iCircle = 1:min(2, numel(Circles))
		Circles(iCircle).FaceColor = [1, 0, 0] * (iCircle == 1) + [0, 0, 1] * (iCircle == 2);
		Circles(iCircle).FaceAlpha = 1/3;
		Circles(iCircle).EdgeColor = 'none';
		Circles(iCircle).LineStyle = 'none';
	end
	for iText = 1:numel(Texts)
		if isprop(Texts(iText), 'FontSize')
			Texts(iText).FontSize = 12;
		end
	end
	title(ax, pairRow.Transition, 'FontSize', 12, 'FontWeight', 'normal');
	lgd = legend(Circles(1:2), {char(pairRow.LeftLegend), char(pairRow.RightLegend)}, 'Location', MATLAB.Graphics.OptimizedLegendLocation(Texts(2:end)), 'Box', 'off', 'FontSize', 12);
	lgd.FontName = 'Segoe UI Emoji';
	allText = findall(f, 'Type', 'Text');
	for iText = 1:numel(allText)
		allText(iText).FontSize = 12;
	end

	if ~isfolder(fileparts(svgPath))
		mkdir(fileparts(svgPath));
	end
	TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
	fprintf('Wrote: %s\n', svgPath);
end