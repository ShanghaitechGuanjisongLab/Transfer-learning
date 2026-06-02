% 中文图372C：高收敛细胞重叠 Venn 图

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
Data = Fig71_ConvergenceInheritanceCache();
chanceText = "(Chance overlap " + MATLAB.SignificantFixedpoint(Data.ChanceOverlap * 100, 2) + "%)";

Fig71_PlotConvergenceVenn(Data.LTMatrix, Data.LTTags, ["Learned 🔊💧", "Continual Hit 💡💧"], ["Overlap of highly"; "convergent cells"], chanceText, ...
	'中文图71G highly convergent overlap venn', [6, 8], '中文图Fig71G_HighlyConvergentOverlap_Venn.svg');