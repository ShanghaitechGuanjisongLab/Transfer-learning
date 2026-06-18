function acc = EvaluateClassificationAccuracyDlarray(net, dlXval, dlTval, miniBatchSize)
numSamples = size(dlXval, 4);

numCorrect = 0;
numTotal = 0;

for startIdx = 1:miniBatchSize:numSamples
    endIdx = min(startIdx + miniBatchSize - 1, numSamples);

    dlXbatch = dlXval(:, :, :, startIdx:endIdx);
    dlTbatch = dlTval(:, startIdx:endIdx);

    logits = forward(net, dlXbatch);
    [~, predIdx] = max(logits, [], 1);
    [~, trueIdx] = max(dlTbatch, [], 1);

    predIdx = gather(extractdata(predIdx));
    trueIdx = gather(extractdata(trueIdx));

    numCorrect = numCorrect + nnz(predIdx == trueIdx);
    numTotal = numTotal + numel(trueIdx);
end

acc = numCorrect / numTotal;
end
