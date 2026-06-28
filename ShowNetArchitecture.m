function ShowNetArchitecture()
% Display the current ResNet-18 network architecture used for CIFAR/MNIST training.
% Uses MATLAB's built-in analyzeNetwork for interactive visualization.

inputSize = [32 32 3];
numClasses = 10;
net = TransferLearning.BuildResNet18Classifier(inputSize, numClasses);

fprintf("Network: ResNet-18 (CIFAR/MNIST stem)\n");
fprintf("  Input: 32x32x3\n");
fprintf("  Output: %d classes (logits)\n", numClasses);
fprintf("  Learnables: %d\n", height(net.Learnables));
fprintf("\nOpening analyzeNetwork interactive window...\n");

% Also print text summary
fprintf("\n=== Layer List ===\n");
fprintf("%-4s %-30s %-30s\n", "#", "Name", "Type");
fprintf("%s\n", repmat("-", 1, 68));

lgraph = layerGraph(imagePretrainedNetwork("resnet18"));
lgraph = replaceLayer(lgraph, "data", imageInputLayer(inputSize, Normalization="none", Name="data"));
lgraph = replaceLayer(lgraph, "conv1", convolution2dLayer(3, 64, Stride=1, Padding=1, Name="conv1"));
lgraph = disconnectLayers(lgraph, "conv1_relu", "pool1");
lgraph = disconnectLayers(lgraph, "pool1", "res2a_branch2a");
lgraph = disconnectLayers(lgraph, "pool1", "res2a/in2");
lgraph = removeLayers(lgraph, "pool1");
lgraph = connectLayers(lgraph, "conv1_relu", "res2a_branch2a");
lgraph = connectLayers(lgraph, "conv1_relu", "res2a/in2");
lgraph = replaceLayer(lgraph, "fc1000", fullyConnectedLayer(numClasses, Name="fc_logits"));
lgraph = removeLayers(lgraph, "prob");

layers = lgraph.Layers;
for i = 1:numel(layers)
    fprintf("%-4d %-30s %s\n", i, layers(i).Name, class(layers(i)));
end

analyzeNetwork(net);
end
