function fig = PlotTrainingCurvesCompare(statsA, statsB)
% Plot Task A vs Task B training curves on 4 panels for comparison.
% Returns the figure handle for ExportStandardFigure export.

epochsA = 1:numel(statsA.trainLoss);
epochsB = 1:numel(statsB.trainLoss);

fig = figure("Position", [100 100 900 700]);

% --- Panel A: Total Loss ---
subplot(2, 2, 1);
plot(epochsA, statsA.trainLoss, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochsB, statsB.trainLoss, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Loss");
title("Total Loss");
legend("Task A (train split)", "Task B (test split)", "Location", "best");
grid on;

% --- Panel B: Cross-Entropy ---
subplot(2, 2, 2);
plot(epochsA, statsA.trainCE, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochsB, statsB.trainCE, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Cross-Entropy");
title("Cross-Entropy Loss");
legend("Task A (train split)", "Task B (test split)", "Location", "best");
grid on;

% --- Panel C: Response Variance ---
subplot(2, 2, 3);
plot(epochsA, statsA.trainVar, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochsB, statsB.trainVar, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Hidden Var (pool5)");
title("Hidden Response Variance");
legend("Task A (train split)", "Task B (test split)", "Location", "best");
grid on;

% --- Panel D: Validation Accuracy ---
subplot(2, 2, 4);
plot(epochsA, statsA.valAccuracy * 100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochsB, statsB.valAccuracy * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Accuracy (%)");
title("Validation Accuracy");
legend("Task A (train split)", "Task B (test split)", "Location", "best");
ylim([0 100]);
grid on;

sgtitle("Task A vs Task B Training Comparison (ResNet-18 + CIFAR-10)", "Interpreter", "none");
end
