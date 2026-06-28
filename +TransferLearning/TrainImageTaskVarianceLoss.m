function [net, stats] = TrainImageTaskVarianceLoss(net, XTrain, yTrain, XVal, yVal, classNames, inputSize, maxEpochs, miniBatchSize, learnRate, varWeight, gpuIndices, samplesPerEpoch)
if nargin < 12 || isempty(gpuIndices)
    gpuIndices = 1;
end
if nargin < 13 || isempty(samplesPerEpoch)
    samplesPerEpoch = size(XTrain, 1);
end

gpuIndices = unique(gpuIndices(:)');
numGpuRequested = numel(gpuIndices);

if numGpuRequested > 1
    [net, stats] = trainMultiGpu(net, XTrain, yTrain, XVal, yVal, classNames, inputSize, maxEpochs, miniBatchSize, learnRate, varWeight, gpuIndices, samplesPerEpoch);
    return;
end

numClasses = numel(classNames);
numTrain = size(XTrain, 1);

useGPU = canUseGPU;
if useGPU
    currentDev = gpuDevice();
    if currentDev.Index ~= gpuIndices(1)
        gpuDevice(gpuIndices(1));
    end
end

trailingAvg = [];
trailingAvgSq = [];
iteration = 0;

gradDecay = 0.9;
sqGradDecay = 0.999;

stats.trainLoss = zeros(maxEpochs, 1);
stats.trainCE = zeros(maxEpochs, 1);
stats.trainVar = zeros(maxEpochs, 1);
stats.valAccuracy = zeros(maxEpochs, 1);

[dlXval, dlTval] = TransferLearning.PreprocessCifarRows( ...
    XVal, yVal, inputSize, numClasses);

[XsmallTrainGpu, TfullGpu] = TransferLearning.PreUploadCifarToGpu( ...
    XTrain, yTrain, numClasses);

disp("CIFAR data pre-uploaded to GPU (32x32 cache).");

for epoch = 1:maxEpochs
    stats.valAccuracy(epoch) = TransferLearning.EvaluateClassificationAccuracyDlarray( ...
        net, dlXval, dlTval, miniBatchSize);

    order = randperm(numTrain);

    if useGPU
        epochLossGpu = gpuArray(single(0));
        epochCEGpu = gpuArray(single(0));
        epochVarGpu = gpuArray(single(0));
    else
        epochLossGpu = single(0);
        epochCEGpu = single(0);
        epochVarGpu = single(0);
    end
    batchCount = 0;

    for startIdx = 1:miniBatchSize:samplesPerEpoch
        iteration = iteration + 1;
        batchCount = batchCount + 1;

        endIdx = min(startIdx + miniBatchSize - 1, samplesPerEpoch);
        batchOrder = order(startIdx:endIdx);

        dlX = dlarray(single(XsmallTrainGpu(:, :, :, batchOrder)) / 255, "SSCB");
        dlT = dlarray(TfullGpu(:, batchOrder), "CB");

        [gradients, loss, ceLoss, varTerm] = dlfeval( ...
            @TransferLearning.ComputeModelGradientsVarianceLoss, net, dlX, dlT, varWeight);

        [net, trailingAvg, trailingAvgSq] = adamupdate( ...
            net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate, gradDecay, sqGradDecay);

        epochLossGpu = epochLossGpu + extractdata(loss);
        epochCEGpu = epochCEGpu + extractdata(ceLoss);
        epochVarGpu = epochVarGpu + extractdata(varTerm);
    end

    epochLoss = double(gather(epochLossGpu));
    epochCE = double(gather(epochCEGpu));
    epochVar = double(gather(epochVarGpu));

    stats.trainLoss(epoch) = epochLoss / batchCount;
    stats.trainCE(epoch) = epochCE / batchCount;
    stats.trainVar(epoch) = epochVar / batchCount;

    fprintf("Epoch %d/%d | loss=%.4f (ce=%.4f, var=%.4f) | valAcc=%.4f\n", ...
        epoch, maxEpochs, stats.trainLoss(epoch), stats.trainCE(epoch), stats.trainVar(epoch), stats.valAccuracy(epoch));
end

stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracyDlarray( ...
    net, dlXval, dlTval, miniBatchSize);
fprintf("Final post-training valAcc=%.4f\n", stats.finalValAccuracy);
end

function [netOut, stats] = trainMultiGpu(netIn, XTrain, yTrain, XVal, yVal, classNames, inputSize, maxEpochs, miniBatchSize, learnRate, varWeight, gpuIndices, samplesPerEpoch)
pool = gcp("nocreate");
if isempty(pool) || pool.NumWorkers ~= numel(gpuIndices)
    if ~isempty(pool)
        delete(pool);
    end
    parpool("Processes", numel(gpuIndices));
end

numClasses = numel(classNames);
numTrain = size(XTrain, 1);
samplesPerEpoch = min(samplesPerEpoch, numTrain);

stats.trainLoss = zeros(maxEpochs, 1);
stats.trainCE = zeros(maxEpochs, 1);
stats.trainVar = zeros(maxEpochs, 1);
stats.valAccuracy = zeros(maxEpochs, 1);

spmd
    gpuDevice(gpuIndices(spmdIndex));

    net = netIn;
    trailingAvg = [];
    trailingAvgSq = [];
    iteration = 0;

    gradDecay = 0.9;
    sqGradDecay = 0.999;

    for epoch = 1:maxEpochs
        if spmdIndex == 1
            stats.valAccuracy(epoch) = TransferLearning.EvaluateClassificationAccuracy( ...
                net, XVal, yVal, classNames, inputSize, miniBatchSize);
        end
        stats = spmdBroadcast(1, stats);

        order = randperm(numTrain, samplesPerEpoch);

        epochLossLocal = 0;
        epochCELocal = 0;
        epochVarLocal = 0;
        batchCountLocal = 0;

        for startIdx = 1:miniBatchSize:samplesPerEpoch
            endIdx = min(startIdx + miniBatchSize - 1, samplesPerEpoch);
            batchIdx = order(startIdx:endIdx);

            countAll = numel(batchIdx);
            startLocal = floor((spmdIndex - 1) * countAll / spmdSize) + 1;
            endLocal = floor(spmdIndex * countAll / spmdSize);

            if endLocal >= startLocal
                localIdx = batchIdx(startLocal:endLocal);
                [dlX, dlT] = TransferLearning.PreprocessCifarRows( ...
                    XTrain(localIdx, :), yTrain(localIdx), inputSize, numClasses);

                dlX = gpuArray(dlX);
                dlT = gpuArray(dlT);

                [gradients, loss, ceLoss, varTerm] = dlfeval( ...
                    @TransferLearning.ComputeModelGradientsVarianceLoss, net, dlX, dlT, varWeight);

                sampleCount = double(numel(localIdx));
                for gi = 1:height(gradients)
                    gradients.Value{gi} = gradients.Value{gi} * sampleCount;
                end

                lossLocal = double(gather(extractdata(loss))) * sampleCount;
                ceLocal = double(gather(extractdata(ceLoss))) * sampleCount;
                varLocal = double(gather(extractdata(varTerm))) * sampleCount;
            else
                gradients = net.Learnables;
                for gi = 1:height(gradients)
                    gradients.Value{gi} = zeros(size(gradients.Value{gi}), "like", gradients.Value{gi});
                end
                sampleCount = 0;
                lossLocal = 0;
                ceLocal = 0;
                varLocal = 0;
            end

            for gi = 1:height(gradients)
                gradients.Value{gi} = spmdPlus(gradients.Value{gi});
            end
            totalCount = spmdPlus(sampleCount);

            if totalCount > 0
                for gi = 1:height(gradients)
                    gradients.Value{gi} = gradients.Value{gi} / totalCount;
                end
            end

            iteration = iteration + 1;
            [net, trailingAvg, trailingAvgSq] = adamupdate( ...
                net, gradients, trailingAvg, trailingAvgSq, iteration, learnRate, gradDecay, sqGradDecay);

            epochLossLocal = epochLossLocal + spmdPlus(lossLocal) / max(totalCount, 1);
            epochCELocal = epochCELocal + spmdPlus(ceLocal) / max(totalCount, 1);
            epochVarLocal = epochVarLocal + spmdPlus(varLocal) / max(totalCount, 1);
            batchCountLocal = batchCountLocal + 1;
        end

        epochLossGlobal = spmdPlus(epochLossLocal);
        epochCEGlobal = spmdPlus(epochCELocal);
        epochVarGlobal = spmdPlus(epochVarLocal);
        batchCountGlobal = spmdPlus(batchCountLocal);

        if spmdIndex == 1
            stats.trainLoss(epoch) = epochLossGlobal / batchCountGlobal;
            stats.trainCE(epoch) = epochCEGlobal / batchCountGlobal;
            stats.trainVar(epoch) = epochVarGlobal / batchCountGlobal;

            fprintf("Epoch %d/%d | loss=%.4f (ce=%.4f, var=%.4f) | valAcc=%.4f\n", ...
                epoch, maxEpochs, stats.trainLoss(epoch), stats.trainCE(epoch), stats.trainVar(epoch), stats.valAccuracy(epoch));
        end

        stats = spmdBroadcast(1, stats);
    end

    if spmdIndex == 1
        stats.finalValAccuracy = TransferLearning.EvaluateClassificationAccuracy( ...
            net, XVal, yVal, classNames, inputSize, miniBatchSize);
        fprintf("Final post-training valAcc=%.4f\n", stats.finalValAccuracy);
    end
    stats = spmdBroadcast(1, stats);

    netOutSpmd = net;
end

netOut = netOutSpmd{1};
stats = stats{1};
end
