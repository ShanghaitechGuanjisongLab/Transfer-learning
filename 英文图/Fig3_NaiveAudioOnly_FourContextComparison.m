% Naive声线索解码器的四情境配对比较，同时保留原1 s和新0.3 s版本。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	PrjFile = fullfile(ThisDir, '..', 'Transferlearning.prj');
	if exist(PrjFile, 'file')
		matlab.project.loadProject(PrjFile);
	end
end
PostDurations = [1, 0.3];
Fig3_FourContextStats = cell(2, 1);
CombinedPairwise = table();
FriedmanRawP = nan(2, 1);
for VersionIndex = 1:2
	Fig3_FourContextStats{VersionIndex} = TransferLearning.CompareNaiveAudioCueContexts(PostDurations(VersionIndex));
	VersionPairwise = Fig3_FourContextStats{VersionIndex}.Pairwise;
	VersionPairwise.PostDuration = repmat(PostDurations(VersionIndex), height(VersionPairwise), 1);
	CombinedPairwise = [CombinedPairwise; VersionPairwise];
	FriedmanRawP(VersionIndex) = Fig3_FourContextStats{VersionIndex}.FriedmanP;
end
assert(isequal(Fig3_FourContextStats{1}.Mice, Fig3_FourContextStats{2}.Mice), 'NaiveAudioContexts:DifferentMice', '两个时间窗版本必须使用同一批鼠。');
CombinedPairwise.PValueHolmBothVersions = HolmAdjust(CombinedPairwise.PValue);
Omnibus = table(PostDurations', FriedmanRawP, HolmAdjust(FriedmanRawP), 'VariableNames', {'PostDuration', 'FriedmanP', 'FriedmanPHolmBothVersions'});
CacheDir = fileparts(TransferLearning.CachePath('NaiveAudioFourContexts.mat'));
writetable(CombinedPairwise, fullfile(CacheDir, 'NaiveAudioOnly_FourContexts_BothVersions_Pairwise.csv'));
writetable(Omnibus, fullfile(CacheDir, 'NaiveAudioOnly_FourContexts_BothVersions_Omnibus.csv'));
assignin('base', 'Fig3_FourContextStats', Fig3_FourContextStats);
assignin('base', 'Fig3_FourContextPairwise', CombinedPairwise);
assignin('base', 'Fig3_FourContextOmnibus', Omnibus);
fprintf('\n两种时间窗的总体检验及12项配对检验的联合Holm校正：\n');
disp(Omnibus);
disp(CombinedPairwise);

function Adjusted = HolmAdjust(P)
[Sorted, Order] = sort(P);
Adjusted = nan(size(P));
Adjusted(Order) = min(cummax((numel(P):-1:1)' .* Sorted), 1);
end