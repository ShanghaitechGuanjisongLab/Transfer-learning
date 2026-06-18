function net = BuildSmallResNet(inputSize, numClasses)
% Build a compact ResNet-style model that outputs logits.

layers = [
    imageInputLayer(inputSize, Normalization="none", Name="input")

    convolution2dLayer(7, 32, Stride=2, Padding="same", Name="stem_conv")
    batchNormalizationLayer(Name="stem_bn")
    reluLayer(Name="stem_relu")
    maxPooling2dLayer(3, Stride=2, Padding="same", Name="stem_pool")

    convolution2dLayer(3, 32, Padding="same", Name="b1_conv1")
    batchNormalizationLayer(Name="b1_bn1")
    reluLayer(Name="b1_relu1")
    convolution2dLayer(3, 32, Padding="same", Name="b1_conv2")
    batchNormalizationLayer(Name="b1_bn2")
    additionLayer(2, Name="b1_add")
    reluLayer(Name="b1_out")

    convolution2dLayer(3, 64, Stride=2, Padding="same", Name="b2_conv1")
    batchNormalizationLayer(Name="b2_bn1")
    reluLayer(Name="b2_relu1")
    convolution2dLayer(3, 64, Padding="same", Name="b2_conv2")
    batchNormalizationLayer(Name="b2_bn2")

    additionLayer(2, Name="b2_add")
    reluLayer(Name="b2_out")

    globalAveragePooling2dLayer(Name="gap")
    fullyConnectedLayer(numClasses, Name="fc_logits")
    ];

lgraph = layerGraph(layers);

lgraph = connectLayers(lgraph, "stem_pool", "b1_add/in2");

projLayers = [
    convolution2dLayer(1, 64, Stride=2, Name="b2_proj_conv")
    batchNormalizationLayer(Name="b2_proj_bn")
    ];

lgraph = addLayers(lgraph, projLayers);
lgraph = connectLayers(lgraph, "b1_out", "b2_proj_conv");
lgraph = connectLayers(lgraph, "b2_proj_bn", "b2_add/in2");

net = dlnetwork(lgraph);
end
