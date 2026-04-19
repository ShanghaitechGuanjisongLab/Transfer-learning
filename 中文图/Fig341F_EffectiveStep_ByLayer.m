% 中文图341F：最优方向上的每会话有效步长（分层）

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

Data = TransferLearning.Fig341.BuildStateSpaceSummary(UniExp.Flags.No_special_operation);
[f, summaryTbl] = TransferLearning.Fig341.PlotMetricByLayer(Data, "EffectiveStep", "中文图341F Effective step", "Effective step", "中文图Fig341F_EffectiveStep_ByLayer.svg");
assignin('base', 'Fig341F_Summary', summaryTbl);
assignin('base', 'Fig341F_Metrics', Data.Metrics(:, {'Mouse','Group','Source','ZLayer','NSession','EffectiveStep'}));
