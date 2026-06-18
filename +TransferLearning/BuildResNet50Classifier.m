function net = BuildResNet50Classifier(inputSize, numClasses)
% Build a ResNet-50 classifier head that outputs logits for custom classes.

assert(exist("resnet50", "file") == 2, ...
    "resnet50 is unavailable. Install Deep Learning Toolbox Model for ResNet-50 Network.");

baseNet = resnet50;
lgraph = layerGraph(baseNet);

lgraph = replaceLayer(lgraph, "input_1", imageInputLayer(inputSize, Normalization="none", Name="input_1"));

if isequal(inputSize(1:2), [32 32])
    lgraph = replaceLayer(lgraph, "conv1", convolution2dLayer(3, 64, Stride=1, Padding=1, Name="conv1"));
    lgraph = disconnectLayers(lgraph, "activation_1_relu", "max_pooling2d_1");
    lgraph = disconnectLayers(lgraph, "max_pooling2d_1", "res2a_branch2a");
    lgraph = disconnectLayers(lgraph, "max_pooling2d_1", "res2a_branch1");
    lgraph = removeLayers(lgraph, "max_pooling2d_1");
    lgraph = connectLayers(lgraph, "activation_1_relu", "res2a_branch2a");
    lgraph = connectLayers(lgraph, "activation_1_relu", "res2a_branch1");
end

lgraph = replaceLayer(lgraph, "fc1000", fullyConnectedLayer(numClasses, Name="fc_logits"));
if any(strcmp({lgraph.Layers.Name}, "fc1000_softmax"))
    lgraph = removeLayers(lgraph, "fc1000_softmax");
end
if any(strcmp({lgraph.Layers.Name}, "ClassificationLayer_fc1000"))
    lgraph = removeLayers(lgraph, "ClassificationLayer_fc1000");
end

net = dlnetwork(lgraph);
end
