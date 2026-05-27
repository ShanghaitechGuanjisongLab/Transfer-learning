% 中文图341D：状态空间总路程 / 直线距离（分层）

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
[f, summaryTbl] = TransferLearning.Fig341.PlotMetricByLayer(Data, "PathOverDirect", "中文图341D Path over direct", "Path / direct", "中文图Fig341D_PathOverDirect_ByLayer.svg");
TransferLearning.Fig341.PrintStateSpaceUsageCounts("Fig341D", Counts, "Layer");
assignin('base', 'Fig341D_Summary', summaryTbl);
assignin('base', 'Fig341D_Metrics', Data.Metrics(:, {'Mouse','Group','Source','ZLayer','NSession','PathOverDirect'}));
assignin('base', 'Fig341D_Counts', Counts.Layer);
