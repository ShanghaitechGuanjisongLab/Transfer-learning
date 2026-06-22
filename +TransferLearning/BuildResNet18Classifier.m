function net = BuildResNet18Classifier(inputSize, numClasses)
% Build a ResNet-18 classifier using imagePretrainedNetwork, outputting logits.

lgraph = layerGraph(imagePretrainedNetwork("resnet18"));

lgraph = replaceLayer(lgraph, "data", imageInputLayer(inputSize, Normalization="none", Name="data"));

if isequal(inputSize(1:2), [32 32])
    lgraph = replaceLayer(lgraph, "conv1", convolution2dLayer(3, 64, Stride=1, Padding=1, Name="conv1"));
    lgraph = disconnectLayers(lgraph, "conv1_relu", "pool1");
    lgraph = disconnectLayers(lgraph, "pool1", "res2a_branch2a");
    lgraph = disconnectLayers(lgraph, "pool1", "res2a/in2");
    lgraph = removeLayers(lgraph, "pool1");
    lgraph = connectLayers(lgraph, "conv1_relu", "res2a_branch2a");
    lgraph = connectLayers(lgraph, "conv1_relu", "res2a/in2");
end

lgraph = replaceLayer(lgraph, "fc1000", fullyConnectedLayer(numClasses, Name="fc_logits"));
lgraph = removeLayers(lgraph, "prob");

net = dlnetwork(lgraph);
end
