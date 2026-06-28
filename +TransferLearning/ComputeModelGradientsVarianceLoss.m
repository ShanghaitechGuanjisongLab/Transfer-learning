function [gradients, loss, ceLoss, varTerm, logits] = ComputeModelGradientsVarianceLoss(net, dlX, dlT, varWeight)
[logits, r3] = forward(net, dlX, Outputs=["fc_logits","res3b_relu"]);
probs = softmax(logits);

ceLoss = crossentropy(probs, dlT, TargetCategories="independent");

varTerm = layerVar(r3);

loss = ceLoss / (1 + varWeight * varTerm);
gradients = dlgradient(loss, net.Learnables);
end

function v = layerVar(X)
Xflat = reshape(stripdims(X), [], size(X, 4));
v = mean(var(Xflat, 0, 2), "all");
end
