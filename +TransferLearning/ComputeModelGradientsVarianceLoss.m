function [gradients, loss, ceLoss, varTerm, logits] = ComputeModelGradientsVarianceLoss(net, dlX, dlT, varWeight)
logits = forward(net, dlX);
probs = softmax(logits);

ceLoss = crossentropy(probs, dlT, TargetCategories="independent");

varPerClass = var(probs, 0, 2);
varTerm = mean(varPerClass, "all");

loss = ceLoss / (1 + varWeight * varTerm);
gradients = dlgradient(loss, net.Learnables);
end
