% Naive 早期光水 block 污染的 sigmoid 斜率敏感性分析。
% 基线沿用主报告的 Undelayed Naive（LAB、LAPureBehavior、LAI）和完整 12 h（ALB、ALPureBehavior），保持上下限 0/1、斜率和中点自由、保留学会后的记录。
% 污染依据为 block 内实际刺激构成和既有 MustWarn 标记，不根据斜率、相关性或 p 值选择排除对象；仅修改 Naive，12 h 保持原始队列。
% 在基线已确定的学习阶段内删除符合规则的 block，保留每会话剩余光水 trial，重新计算命中率并连续编号；这会改变早期起点，结果属于探索性敏感性分析，不自动替换主报告。

ThisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	PrjFile = fullfile(ThisDir, 'Transferlearning.prj');
	if exist(PrjFile, 'file')
		matlab.project.loadProject(PrjFile);
	end
end

NaiveSessions = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingNaive");
ControlSessions = TransferLearning.DelayComparison.CohortBlocks("UndelayedImagingTransfer");
ControlFits = TransferLearning.DelayComparison.FitSigmoidPerMouse(TransferLearning.DelayComparison.AddBlockIndex(ControlSessions), true);
ControlSlopes = double(ControlFits.Slope);
ControlSlopes = ControlSlopes(isfinite(ControlSlopes));

DatasetSpecs = {TransferLearning.LightAudioBaseline(), "LightAudioBaseline"; TransferLearning.LAPureBehavior(), "LAPureBehavior"; TransferLearning.LAInterspersed(), "LAInterspersed"};
AuditParts = cell(size(DatasetSpecs, 1), 1);
for DatasetIndex = 1:size(DatasetSpecs, 1)
	SourceName = DatasetSpecs{DatasetIndex, 2};
	SelectedSessions = NaiveSessions(NaiveSessions.Source == SourceName, {'Mouse', 'DateTime'});
	AuditParts{DatasetIndex} = AuditBlocks(DatasetSpecs{DatasetIndex, 1}, SelectedSessions, SourceName);
end
BlockAudit = vertcat(AuditParts{:});
BlockAudit = BlockAudit(BlockAudit.NLightWater > 0, :);
BaselineSessions = RebuildSessions(BlockAudit);
OriginalCheck = NaiveSessions(:, {'Mouse', 'DateTime', 'Source', 'Performance'});
OriginalCheck.Properties.VariableNames{'Performance'} = 'OriginalPerformance';
RebuiltCheck = BaselineSessions;
RebuiltCheck.Properties.VariableNames{'Performance'} = 'RebuiltPerformance';
BaselineCheck = innerjoin(OriginalCheck, RebuiltCheck, 'Keys', {'Mouse', 'DateTime', 'Source'});
assert(height(BaselineCheck) == height(NaiveSessions) && max(abs(BaselineCheck.OriginalPerformance - BaselineCheck.RebuiltPerformance)) < 1e-12, 'NaiveSensitivity:BaselineMismatch', '逐块汇总未能复现原始会话命中率。');

RuleKeys = ["Baseline", "NoMixed", "NoWarnings", "NoMixedNoWarnings", "NoAudioNoWarnings"];
RuleLabels = ["原始纳入规则", "剔除所有混刺激 block", "仅剔除 MustWarn block", "剔除混刺激和 MustWarn block", "仅剔除 AudioWater 混入及 MustWarn block"];
RemovedByRule = {false(height(BlockAudit), 1), BlockAudit.NOther > 0, BlockAudit.HasWarning, BlockAudit.NOther > 0 | BlockAudit.HasWarning, BlockAudit.NAudioWater > 0 | BlockAudit.HasWarning};
Results = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), strings(0, 1), 'VariableNames', {'Rule', 'RemovedBlocks', 'RemovedSessions', 'NControl', 'NNaive', 'ControlMean', 'NaiveMean', 'NaiveSEM', 'MeanDifference', 'RankSumP', 'Conclusion', 'ExcludedFitMice'});
FitsByRule = struct();
RemovedBlocksByRule = struct();
for RuleIndex = 1:numel(RuleKeys)
	Removed = RemovedByRule{RuleIndex};
	CleanSessions = RebuildSessions(BlockAudit(~Removed, :));
	NaiveFits = TransferLearning.DelayComparison.FitSigmoidPerMouse(TransferLearning.DelayComparison.AddBlockIndex(CleanSessions), true);
	NaiveFits = NaiveFits(isfinite(NaiveFits.Slope), :);
	NaiveSlopes = double(NaiveFits.Slope);
	PValue = ranksum(ControlSlopes, NaiveSlopes);
	Difference = mean(ControlSlopes) - mean(NaiveSlopes);
	if PValue < 0.05 && Difference > 0
		Conclusion = "12 h 更高，原始 p 显著";
	elseif PValue < 0.05 && Difference < 0
		Conclusion = "12 h 更低，原始 p 显著";
	else
		Conclusion = "不显著";
	end
	ExcludedFitMice = strjoin(setdiff(unique(string(NaiveSessions.Mouse)), string(NaiveFits.Mouse)), ', ');
	Results = [Results; table(RuleLabels(RuleIndex), nnz(Removed), height(NaiveSessions) - height(CleanSessions), numel(ControlSlopes), numel(NaiveSlopes), mean(ControlSlopes), mean(NaiveSlopes), std(NaiveSlopes) / sqrt(numel(NaiveSlopes)), Difference, PValue, Conclusion, ExcludedFitMice, 'VariableNames', Results.Properties.VariableNames)];
	NaiveFits.Source = strings(height(NaiveFits), 1);
	for MouseIndex = 1:height(NaiveFits)
		MouseRows = string(CleanSessions.Mouse) == string(NaiveFits.Mouse(MouseIndex));
		NaiveFits.Source(MouseIndex) = CleanSessions.Source(find(MouseRows, 1));
	end
	FitsByRule.(RuleKeys(RuleIndex)) = NaiveFits;
	RemovedBlocksByRule.(RuleKeys(RuleIndex)) = BlockAudit(Removed, :);
end

assert(Results.NControl(1) == 22 && Results.NNaive(1) == 27 && abs(Results.RankSumP(1) - 0.29126823) < 1e-6, 'NaiveSensitivity:BaselineChanged', '当前数据无法复现主报告的基线鼠数或 p 值。');
fprintf('\nNaive block 清洗敏感性分析；12 h 固定 n=%d，斜率均值=%.6f。\n', numel(ControlSlopes), mean(ControlSlopes));
for RuleIndex = 1:height(Results)
	fprintf('%s：删除 %d 个 block、%d 个完整会话；n=%d/%d；Naive=%.6f ± %.6f；差值（12 h−Naive）=%+.6f；双侧秩和 p=%.8g；%s。\n', Results.Rule(RuleIndex), Results.RemovedBlocks(RuleIndex), Results.RemovedSessions(RuleIndex), Results.NControl(RuleIndex), Results.NNaive(RuleIndex), Results.NaiveMean(RuleIndex), Results.NaiveSEM(RuleIndex), Results.MeanDifference(RuleIndex), Results.RankSumP(RuleIndex), Results.Conclusion(RuleIndex));
	fprintf('排除的拟合鼠（数据不足或恒定）：%s\n', Results.ExcludedFitMice(RuleIndex));
	disp(groupcounts(unique(FitsByRule.(RuleKeys(RuleIndex))(:, {'Source', 'Mouse'})), 'Source'));
end
fprintf('上述规则由污染类型定义，属于多规则探索性分析；未校正 p 值不能用于按显著性选择清洗规则。\n');
fprintf('注意：成像警告不一定代表行为记录无效；删除早期 block 后连续编号也会移动学习曲线起点。\n');

OutDir = fileparts(TransferLearning.CachePath('NaiveSigmoidSensitivity.mat'));
writetable(Results, fullfile(OutDir, 'NaiveSigmoid_BlockSensitivity_Results.csv'));
writetable(BlockAudit, fullfile(OutDir, 'NaiveSigmoid_BlockAudit.csv'));
assignin('base', 'NaiveSigmoid_SensitivityResults', Results);
assignin('base', 'NaiveSigmoid_BlockAudit', BlockAudit);
assignin('base', 'NaiveSigmoid_FitsByRule', FitsByRule);
assignin('base', 'NaiveSigmoid_RemovedBlocksByRule', RemovedBlocksByRule);
fprintf('已保存审计与敏感性统计：%s\n', OutDir);

function Audit = AuditBlocks(DS, SelectedSessions, SourceName)
Trials = DS.TableQuery(["Mouse", "DateTime", "BlockUID", "TrialUID", "Stimulus", "Behavior", "Design"]);
Trials.Mouse = string(Trials.Mouse);
Trials.DateTime = datetime(Trials.DateTime);
Trials.DateTime.TimeZone = '';
Trials.Stimulus = string(Trials.Stimulus);
Trials.Design = string(Trials.Design);
SelectedSessions.Mouse = string(SelectedSessions.Mouse);
SelectedSessions.DateTime = datetime(SelectedSessions.DateTime);
SelectedSessions.DateTime.TimeZone = '';
Trials = innerjoin(Trials, unique(SelectedSessions), 'Keys', {'Mouse', 'DateTime'});
[BlockGroups, Mice, Dates, BlockUIDs] = findgroups(Trials.Mouse, Trials.DateTime, uint64(Trials.BlockUID));
IsLightWater = Trials.Stimulus == "LightWater";
NAll = splitapply(@numel, Trials.TrialUID, BlockGroups);
NLightWater = splitapply(@sum, IsLightWater, BlockGroups);
NAudioWater = splitapply(@sum, Trials.Stimulus == "AudioWater", BlockGroups);
NValidLightWater = splitapply(@sum, IsLightWater & isfinite(double(Trials.Behavior)), BlockGroups);
Performance = splitapply(@(Behavior, Mask) mean(double(Behavior(Mask)), 'omitnan'), Trials.Behavior, IsLightWater, BlockGroups);
Designs = splitapply(@(Names) string(Names(1)), Trials.Design, BlockGroups);
StimulusSets = splitapply(@(Names) strjoin(unique(string(Names)), ', '), Trials.Stimulus, BlockGroups);
Warnings = strings(numel(BlockUIDs), 1);
if ismember('MustWarn', DS.Blocks.Properties.VariableNames)
	[Found, Locations] = ismember(BlockUIDs, uint64(DS.Blocks.BlockUID));
	Warnings(Found) = string(DS.Blocks.MustWarn(Locations(Found)));
	Warnings(ismissing(Warnings)) = "";
end
Audit = table(repmat(SourceName, numel(BlockUIDs), 1), Mice, Dates, BlockUIDs, Designs, StimulusSets, NAll, NLightWater, NAll - NLightWater, NAudioWater, NValidLightWater, Performance, Warnings, strlength(strtrim(Warnings)) > 0, 'VariableNames', {'Source', 'Mouse', 'DateTime', 'BlockUID', 'Design', 'Stimuli', 'NAll', 'NLightWater', 'NOther', 'NAudioWater', 'NValidLightWater', 'Performance', 'MustWarn', 'HasWarning'});
end

function Sessions = RebuildSessions(Audit)
Valid = Audit.NValidLightWater > 0 & isfinite(Audit.Performance);
Audit = Audit(Valid, :);
[SessionGroups, Sources, Mice, Dates] = findgroups(Audit.Source, Audit.Mouse, Audit.DateTime);
Performance = splitapply(@(Values, Counts) sum(Values .* Counts) / sum(Counts), Audit.Performance, Audit.NValidLightWater, SessionGroups);
Sessions = table(Mice, Dates, Performance, Sources, 'VariableNames', {'Mouse', 'DateTime', 'Performance', 'Source'});
Sessions = sortrows(Sessions, {'Mouse', 'DateTime'});
end