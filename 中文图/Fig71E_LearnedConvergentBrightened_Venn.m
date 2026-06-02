% 中文图372A：Learned 阶段收敛与增亮 Venn 图

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

Fig71_PlotConvergenceVenn(Data.LearnedMatrix, Data.LearnedTags, ["Convergent", "Brightened"], "Learned 🔊💧", "", ...
	'中文图71E Learned convergent brightened venn', [6, 8], '中文图Fig71E_LearnedConvergentBrightened_Venn.svg');