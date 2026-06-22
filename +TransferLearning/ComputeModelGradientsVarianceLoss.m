function [gradients, loss, ceLoss, varTerm, logits] = ComputeModelGradientsVarianceLoss(net, dlX, dlT, varWeight)
[logits, features] = forward(net, dlX, Outputs=["fc_logits", "pool5"]);
probs = softmax(logits);

ceLoss = crossentropy(probs, dlT, TargetCategories="independent");

featureMatrix = reshape(stripdims(features), [], size(features, 4));
varPerFeature = var(featureMatrix, 0, 2);
varTerm = mean(varPerFeature, "all");

loss = ceLoss / (1 + varWeight * varTerm);
gradients = dlgradient(loss, net.Learnables);
end
