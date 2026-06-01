% 中文图51E：状态空间平均步长（分层）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = TransferLearning.Fig51.BuildStateSpaceSummary(false, UniExp.Flags.No_special_operation);
Counts = TransferLearning.Fig51.StateSpaceUsageCounts(Data);
[f, summaryTbl] = TransferLearning.Fig51.PlotMetricByLayer(Data, "AverageStep", "中文图51E Average step", "Mean step", "中文图Fig51E_AverageStep_ByLayer.svg");
TransferLearning.Fig51.PrintStateSpaceUsageCounts("Fig51E", Counts, "Layer");
assignin('base', 'Fig51E_Summary', summaryTbl);
assignin('base', 'Fig51E_Metrics', Data.Metrics(:, {'Mouse','Group','Source','ZLayer','NSession','AverageStep'}));
assignin('base', 'Fig51E_Counts', Counts.Layer);
