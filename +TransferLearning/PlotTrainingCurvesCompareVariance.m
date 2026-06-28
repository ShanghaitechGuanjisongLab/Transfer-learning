function fig = PlotTrainingCurvesCompareVariance(statsWithVar, statsNoVar, labelA, labelB, titleText, maxEpochs)
% Compare two training curves on 4 panels. Returns figure handle.
%
% Defaults (Task B: A-had-var vs A-had-no-var):
%   labelA / labelB = "A had variance" / "A had no variance"
%   subtitle = "Task B"
if nargin < 3 || isempty(labelA), labelA = "A had variance"; end
if nargin < 4 || isempty(labelB), labelB = "A had no variance"; end
if nargin < 6 || isempty(maxEpochs), maxEpochs = 10; end

n = min(numel(statsWithVar.trainLoss), maxEpochs);
epochs = (1:n)';

fig = figure("Position", [100 100 900 700]);

% --- Panel A: Total Loss ---
subplot(2, 2, 1);
plot(epochs, statsWithVar.trainLoss(1:n), "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainLoss(1:n), "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Loss");
title("Total Loss (Task B)");
legend(labelA, labelB, "Location", "best"); grid on;

% --- Panel B: Cross-Entropy ---
subplot(2, 2, 2);
plot(epochs, statsWithVar.trainCE(1:n), "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainCE(1:n), "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Cross-Entropy");
title("Cross-Entropy Loss (Task B)");
legend(labelA, labelB, "Location", "best"); grid on;

% --- Panel C: Response Variance ---
subplot(2, 2, 3);
plot(epochs, statsWithVar.trainVar(1:n), "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.trainVar(1:n), "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch"); ylabel("Hidden Var (res2-4)");
title("Hidden Response Variance (Task B)");
legend(labelA, labelB, "Location", "best"); grid on;

% --- Panel D: Validation Accuracy ---
subplot(2, 2, 4);
plot(epochs, statsWithVar.valAccuracy(1:n) * 100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochs, statsNoVar.valAccuracy(1:n) * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
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
