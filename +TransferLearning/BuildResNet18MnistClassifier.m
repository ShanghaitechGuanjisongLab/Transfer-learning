function net = BuildResNet18MnistClassifier()
% Build 1-channel ResNet-18 for MNIST 28x28, exactly matching PyTorch baseline.
% conv1: Conv2d(1,64,3,stride=1,padding=1), no pool1, output=10 classes.

lgraph = layerGraph(imagePretrainedNetwork("resnet18"));

% Replace input to 1-channel
lgraph = replaceLayer(lgraph, "data", imageInputLayer([28 28 1], Normalization="none", Name="data"));

% Replace conv1: 1->64 channels, 3x3 stride=1
lgraph = replaceLayer(lgraph, "conv1", convolution2dLayer(3, 64, Stride=1, Padding=1, Name="conv1"));

% Bypass pool1
lgraph = disconnectLayers(lgraph, "conv1_relu", "pool1");
lgraph = disconnectLayers(lgraph, "pool1", "res2a_branch2a");
lgraph = disconnectLayers(lgraph, "pool1", "res2a/in2");
lgraph = removeLayers(lgraph, "pool1");
lgraph = connectLayers(lgraph, "conv1_relu", "res2a_branch2a");
lgraph = connectLayers(lgraph, "conv1_relu", "res2a/in2");

% Replace output to 10 classes
lgraph = replaceLayer(lgraph, "fc1000", fullyConnectedLayer(10, Name="fc_logits"));
lgraph = removeLayers(lgraph, "prob");

net = dlnetwork(lgraph);
end
