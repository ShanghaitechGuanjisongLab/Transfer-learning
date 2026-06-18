function acc = EvaluateClassificationAccuracy(net, X, y, classNames, inputSize, miniBatchSize)
numClasses = numel(classNames);
numSamples = size(X, 1);

useGPU = canUseGPU;

numCorrect = 0;
numTotal = 0;

for startIdx = 1:miniBatchSize:numSamples
    endIdx = min(startIdx + miniBatchSize - 1, numSamples);
    batchIdx = startIdx:endIdx;

    [dlX, dlT] = TransferLearning.PreprocessCifarRows( ...
        X(batchIdx, :), y(batchIdx), inputSize, numClasses);

    if useGPU
        dlX = gpuArray(dlX);
    end

    logits = forward(net, dlX);
    logits = gather(extractdata(logits));
    target = gather(extractdata(dlT));

    [~, predIdx] = max(logits, [], 1);
    [~, trueIdx] = max(target, [], 1);

    numCorrect = numCorrect + nnz(predIdx == trueIdx);
    numTotal = numTotal + numel(trueIdx);
end

acc = numCorrect / numTotal;
end
