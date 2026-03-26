% 中文图341D：状态空间总路程 / 直线距离（分层）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = TransferLearning.Fig341.BuildStateSpaceSummary(true, UniExp.Flags.No_special_operation);
[f, summaryTbl] = TransferLearning.Fig341.PlotMetricByLayer(Data, "PathOverDirect", "中文图341D Path over direct", "Path / direct", "中文图Fig341D_PathOverDirect_ByLayer.svg");
assignin('base', 'Fig341D_Summary', summaryTbl);
assignin('base', 'Fig341D_Metrics', Data.Metrics(:, {'Mouse','Group','Source','ZLayer','NSession','PathOverDirect'}));
