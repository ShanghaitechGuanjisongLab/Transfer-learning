function D = LightWaterMetricData(options)
%LIGHTWATERMETRICDATA 三组学习速度指标的缓存数据（会话表 + 汇总 + 逐 trial 斜率）
%
%   D = TransferLearning.Metrics.LightWaterMetricData()
%   D = TransferLearning.Metrics.LightWaterMetricData(ForceRebuild = true)
%
%   为什么要缓存：
%   三个来源都要从网络盘整份载入 4 个成像数据集（UniExp.DataSet 会先复制到 tempdir），
%   一次约 1–3 分钟；而画图本身只要 1–2 秒。所以这里把结果落盘，
%   改字号/配色/排版时直接读缓存，几秒出图。
%
%   返回 struct：
%     Sess  会话表（LightWaterLearningSessions）
%     Summ  每鼠汇总（FirstPerf / BlocksToHalf）
%     Slope 逐 trial 惩罚 sigmoid 斜率（每鼠一行）
%     Built 生成时间
%
%   缓存位置：TransferLearning.CachePath（数据服务器个人缓存目录，不进 git）。
%   数据结构改动后记得 ForceRebuild=true 重建。

arguments
	options.ForceRebuild (1,1) logical = false
end

cacheFile = TransferLearning.CachePath('LightWaterMetricData.mat');
if ~options.ForceRebuild && isfile(cacheFile)
	S = load(cacheFile);
	if isfield(S, 'D') && all(isfield(S.D, {'Sess','Summ','Slope','Built'}))
		D = S.D;
		fprintf('[cache] 命中 %s（%s 生成）\n', cacheFile, datestr(D.Built, 'yyyy-mm-dd HH:MM'));
		return;
	end
	fprintf('[cache] 文件不完整，重建\n');
end

fprintf('[cache] 未命中，重新读数据（约 1–3 分钟）...\n');
Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
Summ = TransferLearning.Metrics.PerMouseSessionSummary(Sess);
Slope = TransferLearning.Metrics.TrialLevelSlopePerMouse(Sess);
D = struct('Sess', Sess, 'Summ', Summ, 'Slope', Slope, 'Built', datetime('now'));
save(cacheFile, 'D');
fprintf('[cache] 已写入 %s\n', cacheFile);
end
