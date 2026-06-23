function fig = PlotTrainingCurvesCompareVariance(statsWithVar, statsNoVar, labelA, labelB, titleText)
% Compare two training curves on 4 panels. Returns figure handle.
%
% Defaults (Task B: A-had-var vs A-had-no-var):
%   labelA / labelB = "A had variance" / "A had no variance"
%   subtitle = "Task B"
if nargin < 3 || isempty(labelA), labelA = "A had variance"; end
if nargin < 4 || isempty(labelB), labelB = "A had no variance"; end

epochs = 1:numel(statsWithVar.trainLoss);

fig = figure("Position", [100 100 900 700]);

% --- Panel A: Total Loss ---
subplot(2, 2, 1);
plot(epochs, statsWithVar.trainLoss, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainLoss, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Loss");
title("Total Loss (Task B)");
legend(labelA, labelB, "Location", "best"); grid on;

% --- Panel B: Cross-Entropy ---
subplot(2, 2, 2);
plot(epochs, statsWithVar.trainCE, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainCE, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Cross-Entropy");
title("Cross-Entropy Loss (Task B)");
legend(labelA, labelB, "Location", "best"); grid on;

% --- Panel C: Response Variance ---
subplot(2, 2, 3);
plot(epochs, statsWithVar.trainVar, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainVar, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Hidden Var (pool5)");
title("Hidden Response Variance (Task B)");
legend(labelA, labelB, "Location", "best"); grid on;

% --- Panel D: Validation Accuracy ---
subplot(2, 2, 4);
plot(epochs, statsWithVar.valAccuracy * 100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.valAccuracy * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Accuracy (%)");
title("Validation Accuracy (Task B)");
legend(labelA, labelB, "Location", "best");
ylim([0 100]); grid on;

if nargin < 5 || isempty(titleText)
    sgtitle("Task B (MNIST): Effect of Variance in Task A (ResNet-18)", "Interpreter", "none");
else
    sgtitle(titleText, "Interpreter", "none");
end
end
