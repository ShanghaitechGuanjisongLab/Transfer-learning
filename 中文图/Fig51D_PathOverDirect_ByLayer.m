% 中文图51D：状态空间总路程 / 直线距离（分层）

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
[f, summaryTbl] = TransferLearning.Fig51.PlotMetricByLayer(Data, "PathOverDirect", "中文图51D Path over direct", "Path / direct", "中文图Fig51D_PathOverDirect_ByLayer.svg");
TransferLearning.Fig51.PrintStateSpaceUsageCounts("Fig51D", Counts, "Layer");
assignin('base', 'Fig51D_Summary', summaryTbl);
assignin('base', 'Fig51D_Metrics', Data.Metrics(:, {'Mouse','Group','Source','ZLayer','NSession','PathOverDirect'}));
assignin('base', 'Fig51D_Counts', Counts.Layer);
