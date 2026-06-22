function fig = PlotTrainingCurves(stats, titleText)
% Plot training curves: loss, CE, variance, and validation accuracy vs epoch.
% Returns the figure handle for ExportStandardFigure export.

epochs = 1:numel(stats.trainLoss);

fig = figure("Position", [100 100 900 700]);

% --- Panel A: Loss ---
subplot(2, 2, 1);
plot(epochs, stats.trainLoss, "b-o", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Loss");
title("Total Loss");
grid on;

% --- Panel B: Cross-Entropy ---
subplot(2, 2, 2);
plot(epochs, stats.trainCE, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Cross-Entropy");
title("Cross-Entropy Loss");
grid on;

% --- Panel C: Variance ---
subplot(2, 2, 3);
plot(epochs, stats.trainVar, "g-^", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Hidden Var (pool5)");
title("Hidden Response Variance");
grid on;

% --- Panel D: Validation Accuracy ---
subplot(2, 2, 4);
plot(epochs, stats.valAccuracy * 100, "m-d", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Accuracy (%)");
title("Validation Accuracy");
ylim([0 100]);
grid on;

sgtitle(titleText, "Interpreter", "none");
end
