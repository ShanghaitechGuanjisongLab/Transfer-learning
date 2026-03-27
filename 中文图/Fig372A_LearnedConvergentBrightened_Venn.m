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
queryXlsx = '\\Data-Server-2\个人数据\张天夫\202512\尝试查询表.xlsx';
Data = Fig372_ConvergenceInheritanceCache(queryXlsx);

Fig372_PlotConvergenceVenn(Data.LearnedMatrix, Data.LearnedTags, ["Convergent", "Brightened"], "Learned 🔊💧", "", ...
	'中文图372A Learned convergent brightened venn', [6, 8], fullfile(outDirUNC, '中文图Fig372A_LearnedConvergentBrightened_Venn.svg'));