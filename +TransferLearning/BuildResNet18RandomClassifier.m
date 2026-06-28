function net = BuildResNet18RandomClassifier(inputSize, numClasses)
% Build randomly initialized ResNet-18-style network for image classification.
% Uses the same block layout as ResNet-18, with CIFAR/MNIST-friendly stem.

layers = [
    imageInputLayer(inputSize, Normalization="none", Name="data")
    convolution2dLayer(3, 64, Stride=1, Padding=1, Name="conv1")
    batchNormalizationLayer(Name="bn_conv1")
    reluLayer(Name="conv1_relu")
    ];

lgraph = layerGraph(layers);

[lgraph, current] = addBasicBlock(lgraph, "conv1_relu", "res2a", 64, 1, false);
[lgraph, current] = addBasicBlock(lgraph, current, "res2b", 64, 1, false);

[lgraph, current] = addBasicBlock(lgraph, current, "res3a", 128, 2, true);
[lgraph, current] = addBasicBlock(lgraph, current, "res3b", 128, 1, false);

[lgraph, current] = addBasicBlock(lgraph, current, "res4a", 256, 2, true);
[lgraph, current] = addBasicBlock(lgraph, current, "res4b", 256, 1, false);

[lgraph, current] = addBasicBlock(lgraph, current, "res5a", 512, 2, true);
[lgraph, current] = addBasicBlock(lgraph, current, "res5b", 512, 1, false);

head = [
    globalAveragePooling2dLayer(Name="pool5")
    fullyConnectedLayer(numClasses, Name="fc_logits")
    ];
lgraph = addLayers(lgraph, head);
lgraph = connectLayers(lgraph, current, "pool5");

net = dlnetwork(lgraph);
end

function [lgraph, outputName] = addBasicBlock(lgraph, inputName, blockName, numFilters, stride, useProjection)
mainLayers = [
    convolution2dLayer(3, numFilters, Stride=stride, Padding=1, Name=blockName + "_branch2a")
    batchNormalizationLayer(Name="bn" + extractAfter(blockName, "res") + "_branch2a")
    reluLayer(Name=blockName + "_branch2a_relu")
    convolution2dLayer(3, numFilters, Stride=1, Padding=1, Name=blockName + "_branch2b")
    batchNormalizationLayer(Name="bn" + extractAfter(blockName, "res") + "_branch2b")
    additionLayer(2, Name=blockName)
    reluLayer(Name=blockName + "_relu")
    ];

lgraph = addLayers(lgraph, mainLayers);
lgraph = connectLayers(lgraph, inputName, blockName + "_branch2a");

if useProjection
    projLayers = [
        convolution2dLayer(1, numFilters, Stride=stride, Name=blockName + "_branch1")
        batchNormalizationLayer(Name="bn" + extractAfter(blockName, "res") + "_branch1")
        ];
    lgraph = addLayers(lgraph, projLayers);
    lgraph = connectLayers(lgraph, inputName, blockName + "_branch1");
    lgraph = connectLayers(lgraph, "bn" + extractAfter(blockName, "res") + "_branch1", blockName + "/in2");
else
    lgraph = connectLayers(lgraph, inputName, blockName + "/in2");
end

outputName = blockName + "_relu";
end
