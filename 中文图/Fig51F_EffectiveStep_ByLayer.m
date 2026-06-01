% 中文图51F：最优方向上的每会话有效步长（分层）

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
[f, summaryTbl] = TransferLearning.Fig51.PlotMetricByLayer(Data, "EffectiveStep", "中文图51F Effective step", "Effective step", "中文图Fig51F_EffectiveStep_ByLayer.svg");
TransferLearning.Fig51.PrintStateSpaceUsageCounts("Fig51F", Counts, "Layer");
assignin('base', 'Fig51F_Summary', summaryTbl);
assignin('base', 'Fig51F_Metrics', Data.Metrics(:, {'Mouse','Group','Source','ZLayer','NSession','EffectiveStep'}));
assignin('base', 'Fig51F_Counts', Counts.Layer);
