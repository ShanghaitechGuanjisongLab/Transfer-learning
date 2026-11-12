% Learned声水解码器的四情境配对比较：OOF自测、Naive声、Naive光和12 h光水，分别采用1 s与0.3 s后段。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	PrjFile = fullfile(ThisDir, '..', 'Transferlearning.prj');
	if exist(PrjFile, 'file')
		matlab.project.loadProject(PrjFile);
	end
end
PostDurations = [1, 0.3];
Fig3_LearnedAudioFourContextStats = cell(2, 1);
LearnedCombinedPairwise = table();
LearnedFriedmanRawP = nan(2, 1);
for VersionIndex = 1:2
	Fig3_LearnedAudioFourContextStats{VersionIndex} = TransferLearning.CompareNaiveAudioCueContexts(PostDurations(VersionIndex), "LearnedAudioWater");
	VersionPairwise = Fig3_LearnedAudioFourContextStats{VersionIndex}.Pairwise;
	VersionPairwise.PostDuration = repmat(PostDurations(VersionIndex), height(VersionPairwise), 1);
	LearnedCombinedPairwise = [LearnedCombinedPairwise; VersionPairwise];
	LearnedFriedmanRawP(VersionIndex) = Fig3_LearnedAudioFourContextStats{VersionIndex}.FriedmanP;
end
assert(isequal(Fig3_LearnedAudioFourContextStats{1}.Mice, Fig3_LearnedAudioFourContextStats{2}.Mice), 'LearnedAudioContexts:DifferentMice', '两个时间窗版本必须使用同一批鼠。');
LearnedCombinedPairwise.PValueHolmBothVersions = HolmAdjust(LearnedCombinedPairwise.PValue);
LearnedOmnibus = table(PostDurations', LearnedFriedmanRawP, HolmAdjust(LearnedFriedmanRawP), 'VariableNames', {'PostDuration', 'FriedmanP', 'FriedmanPHolmBothVersions'});
CacheDir = fileparts(TransferLearning.CachePath('LearnedAudioFourContexts.mat'));
writetable(LearnedCombinedPairwise, fullfile(CacheDir, 'LearnedAudioWater_FourContexts_BothVersions_Pairwise.csv'));
writetable(LearnedOmnibus, fullfile(CacheDir, 'LearnedAudioWater_FourContexts_BothVersions_Omnibus.csv'));
assignin('base', 'Fig3_LearnedAudioFourContextStats', Fig3_LearnedAudioFourContextStats);
assignin('base', 'Fig3_LearnedAudioFourContextPairwise', LearnedCombinedPairwise);
assignin('base', 'Fig3_LearnedAudioFourContextOmnibus', LearnedOmnibus);
fprintf('\nLearned声水训练：两个总体检验及两版合计12项配对检验的联合Holm校正。\n');
disp(LearnedOmnibus);
disp(LearnedCombinedPairwise);

function Adjusted = HolmAdjust(P)
[Sorted, Order] = sort(P);
Adjusted = nan(size(P));
Adjusted(Order) = min(cummax((numel(P):-1:1)' .* Sorted), 1);
end