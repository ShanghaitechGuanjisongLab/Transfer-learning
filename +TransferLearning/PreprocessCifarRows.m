function [dlX, dlT] = PreprocessCifarRows(XRows, y, inputSize, numClasses)
miniBatch = size(XRows, 1);

if isa(XRows, "gpuArray")
    Xgpu = single(XRows) / 255;
else
    Xsmall = zeros([32 32 3 miniBatch], "single");
    for i = 1:miniBatch
        Xsmall(:, :, :, i) = TransferLearning.DecodeCifarRowToImage(XRows(i, :));
    end
    Xgpu = gpuArray(single(Xsmall) / 255);
end

dlTgpu = gpuArray(zeros(numClasses, miniBatch, "single"));
linearIdx = sub2ind([numClasses miniBatch], y(:)', 1:miniBatch);
dlTgpu(linearIdx) = 1;

dlX = dlarray(Xgpu, "SSCB");
dlT = dlarray(dlTgpu, "CB");
end
