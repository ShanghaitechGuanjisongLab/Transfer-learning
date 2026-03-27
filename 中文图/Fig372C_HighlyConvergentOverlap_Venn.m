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
queryXlsx = '\\Data-Server-2\个人数据\张天夫\202512\尝试查询表.xlsx';
Data = Fig372_ConvergenceInheritanceCache(queryXlsx);
chanceText = "(Chance overlap " + MATLAB.SignificantFixedpoint(Data.ChanceOverlap * 100, 2) + "%)";

Fig372_PlotConvergenceVenn(Data.LTMatrix, Data.LTTags, ["Learned 🔊💧", "Transfer Hit 💡💧"], ["Overlap of highly"; "convergent cells"], chanceText, ...
	'中文图372C highly convergent overlap venn', [6, 8], fullfile(outDirUNC, '中文图Fig372C_HighlyConvergentOverlap_Venn.svg'));