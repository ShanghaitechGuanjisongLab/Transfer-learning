% 中文图72F：知识增减（Transfer→Final）

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
Data = Fig72_GlobalKnowledgeChangeCache(queryXlsx);

iPlotKnowledgeVenn(Data.PairStats(3, :), "T-start 💡💧", "T-learned 💡💧", "T-start→T-learned", '中文图72F Knowledge change Transfer to Final', [6, 8], '中文图Fig72F_KnowledgeChange_TransferFinal_Venn.svg');

function iPlotKnowledgeVenn(pairRow, leftLegend, rightLegend, transitionLabel, figureName, figSizeCm, svgPath)
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
	circleColors = [iPhaseColor(pairRow.LeftPhase); iPhaseColor(pairRow.RightPhase)];
	for iCircle = 1:min(2, numel(Circles))
		Circles(iCircle).FaceColor = circleColors(iCircle, :);
		Circles(iCircle).FaceAlpha = 1/3;
		Circles(iCircle).EdgeColor = 'none';
		Circles(iCircle).LineStyle = 'none';
	end
	for iText = 1:numel(Texts)
		if isprop(Texts(iText), 'FontSize')
			Texts(iText).FontSize = 12;
		end
	end
	title(ax, transitionLabel, 'FontSize', 12, 'FontWeight', 'normal');
	lgd = legend(Circles(1:2), {char(leftLegend), char(rightLegend)}, 'Location', 'northoutside', 'Box', 'off', 'FontSize', 12);
	lgd.FontName = 'Segoe UI Emoji';
	allText = findall(f, 'Type', 'Text');
	for iText = 1:numel(allText)
		allText(iText).FontSize = 12;
	end

	svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
	fprintf('Wrote: %s\n', svgPath);
end

function color = iPhaseColor(phaseName)
	phaseName = string(phaseName);
	if contains(phaseName, "Naive")
		color = TransferLearning.NaiveColor;
	elseif contains(phaseName, "Learned")
		color = TransferLearning.LearnedColor;
	elseif contains(phaseName, "Transfer") || contains(phaseName, "Transfer")
		color = TransferLearning.TransferColor;
	elseif contains(phaseName, "Final")
		color = TransferLearning.ColorA;
	else
		color = TransferLearning.GroupColors(phaseName);
	end
end
