function CheckForwardOutputs()
gpuDevice(3);
net = TransferLearning.BuildResNet18Classifier([32 32 3], 10);
dlX = gpuArray(dlarray(single(rand(32,32,3,4)), "SSCB"));
try
    [logits, features] = forward(net, dlX, Outputs=["fc_logits", "pool5"]);
    fprintf("multi-output OK: logits %s, features %s\n", mat2str(size(logits)), mat2str(size(features)));
catch ME
    fprintf("multi-output failed: %s\n", ME.message);
    try
        features = forward(net, dlX, Outputs="pool5");
        logits = forward(net, dlX);
        fprintf("single-output fallback OK: logits %s, features %s\n", mat2str(size(logits)), mat2str(size(features)));
    catch ME2
        fprintf("fallback failed: %s\n", ME2.message);
    end
end
end
