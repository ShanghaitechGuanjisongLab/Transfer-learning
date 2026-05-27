% 中文图341E：状态空间平均步长（分层）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = TransferLearning.Fig341.BuildStateSpaceSummary(false, UniExp.Flags.No_special_operation);
Counts = TransferLearning.Fig341.StateSpaceUsageCounts(Data);
[f, summaryTbl] = TransferLearning.Fig341.PlotMetricByLayer(Data, "AverageStep", "中文图341E Average step", "Mean step", "中文图Fig341E_AverageStep_ByLayer.svg");
TransferLearning.Fig341.PrintStateSpaceUsageCounts("Fig341E", Counts, "Layer");
assignin('base', 'Fig341E_Summary', summaryTbl);
assignin('base', 'Fig341E_Metrics', Data.Metrics(:, {'Mouse','Group','Source','ZLayer','NSession','AverageStep'}));
assignin('base', 'Fig341E_Counts', Counts.Layer);
