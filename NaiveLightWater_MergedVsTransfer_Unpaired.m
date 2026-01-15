%% Merge Naive (LAInterspersed + LightAudioBaseline) vs Transfer (AudioLightBaseline)
% 非配对显著性比较（ranksum），读取已导出的 divergence CSV，并输出汇总结果。
%
% 输出目录（UNC）：\\data-server-2\个人数据\张天夫\202601

outDir = "\\data-server-2\个人数据\张天夫\202601";
naivePath = fullfile(outDir, "NaiveLightWater_PureSession_Divergence.csv");
transferPath = fullfile(outDir, "TransferLightWater_Divergence_AudioLightBaseline_AllMice.csv");
outPath = fullfile(outDir, "NaiveMergedVsTransfer_Divergence_Unpaired.csv");

if ~isfile(naivePath)
    error("Missing input: %s", naivePath);
end
if ~isfile(transferPath)
    error("Missing input: %s", transferPath);
end

Tn = readtable(naivePath);
Tt = readtable(transferPath);

% Defensive: coerce to string
Tn.DataSet = string(Tn.DataSet);
Tn.Mouse = string(Tn.Mouse);
Tt.Mouse = string(Tt.Mouse);

naive = Tn.Divergence;
transfer = Tt.Divergence;

if any(isnan(naive)) || any(isnan(transfer))
    warning("NaN found in divergence values; removing NaNs before stats.");
end
naive = naive(~isnan(naive));
transfer = transfer(~isnan(transfer));

[p, h, stats] = ranksum(naive, transfer); %#ok<ASGLU>

summary = table;
summary.NaiveN = numel(naive);
summary.TransferN = numel(transfer);
summary.NaiveMean = mean(naive);
summary.NaiveMedian = median(naive);
summary.NaiveStd = std(naive);
summary.TransferMean = mean(transfer);
summary.TransferMedian = median(transfer);
summary.TransferStd = std(transfer);
summary.RankSumP = p;
summary.RankSumZ = stats.zval;

% Write: if locked, write timestamped alternative
try
    writetable(summary, outPath);
    fprintf("Wrote: %s\n", outPath);
catch ME
    altPath = fullfile(outDir, "NaiveMergedVsTransfer_Divergence_Unpaired_" + string(datetime('now','Format','yyyyMMdd_HHmmss')) + ".csv");
    warning(ME.identifier, "Failed to write %s (%s). Writing %s instead.", outPath, ME.message, altPath);
    writetable(summary, altPath);
    fprintf("Wrote: %s\n", altPath);
end

fprintf("DONE. ranksum p=%.6g\n", p);
