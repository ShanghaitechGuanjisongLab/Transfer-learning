function [XsmallGpu, TfullGpu] = PreUploadCifarToGpu(XTrain, yTrain, numClasses)
numTrain = size(XTrain, 1);
XsmallCpu = zeros([32 32 3 numTrain], "single");
for i = 1:numTrain
    XsmallCpu(:, :, :, i) = TransferLearning.DecodeCifarRowToImage(XTrain(i, :));
end
XsmallGpu = gpuArray(XsmallCpu);

TfullGpu = gpuArray(zeros(numClasses, numTrain, "single"));
linearIdx = sub2ind([numClasses numTrain], yTrain(:)', 1:numTrain);
TfullGpu(linearIdx) = 1;
end
