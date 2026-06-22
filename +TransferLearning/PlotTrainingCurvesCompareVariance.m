function fig = PlotTrainingCurvesCompareVariance(statsWithVar, statsNoVar)
% Compare Task B training curves: with variance vs without variance.
% Overlay on 4 panels. Returns the figure handle for ExportStandardFigure export.

epochs = 1:numel(statsWithVar.trainLoss);

fig = figure("Position", [100 100 900 700]);

% --- Panel A: Total Loss ---
subplot(2, 2, 1);
plot(epochs, statsWithVar.trainLoss, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainLoss, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Loss");
title("Total Loss (Task B)");
legend("With Variance", "No Variance", "Location", "best");
grid on;

% --- Panel B: Cross-Entropy ---
subplot(2, 2, 2);
plot(epochs, statsWithVar.trainCE, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainCE, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Cross-Entropy");
title("Cross-Entropy Loss (Task B)");
legend("With Variance", "No Variance", "Location", "best");
grid on;

% --- Panel C: Response Variance ---
subplot(2, 2, 3);
plot(epochs, statsWithVar.trainVar, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainVar, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Hidden Var (pool5)");
title("Hidden Response Variance (Task B)");
legend("With Variance", "No Variance", "Location", "best");
grid on;

% --- Panel D: Validation Accuracy ---
subplot(2, 2, 4);
plot(epochs, statsWithVar.valAccuracy * 100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.valAccuracy * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Accuracy (%)");
title("Validation Accuracy (Task B)");
legend("With Variance", "No Variance", "Location", "best");
ylim([0 100]);
grid on;

sgtitle("Task B (MNIST): Variance vs No Variance (ResNet-18)", "Interpreter", "none");
end
