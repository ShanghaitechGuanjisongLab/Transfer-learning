function fig = PlotTrainingCurvesCompare(statsA, statsB, labelA, labelB, titleText)
% Plot two training stats curves on 4 panels for comparison.
% Returns the figure handle for ExportStandardFigure export.
%
% Default labels:
%   labelA = "Continual B"
%   labelB = "Naive B"
if nargin < 3 || isempty(labelA), labelA = "Continual B"; end
if nargin < 4 || isempty(labelB), labelB = "Naive B"; end
if nargin < 5 || isempty(titleText), titleText = "Continual vs Naive Learning: Task B (MNIST)"; end

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
legend(labelA, labelB, "Location", "best");
grid on;

% --- Panel B: Cross-Entropy ---
subplot(2, 2, 2);
plot(epochsA, statsA.trainCE, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochsB, statsB.trainCE, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Cross-Entropy");
title("Cross-Entropy Loss");
legend(labelA, labelB, "Location", "best");
grid on;

% --- Panel C: Response Variance ---
subplot(2, 2, 3);
plot(epochsA, statsA.trainVar, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochsB, statsB.trainVar, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Hidden Var (pool5)");
title("Hidden Response Variance");
legend(labelA, labelB, "Location", "best");
grid on;

% --- Panel D: Validation Accuracy ---
subplot(2, 2, 4);
plot(epochsA, statsA.valAccuracy * 100, "b-o", "LineWidth", 1.2, "MarkerSize", 4); hold on;
plot(epochsB, statsB.valAccuracy * 100, "r-s", "LineWidth", 1.2, "MarkerSize", 4);
xlabel("Epoch");
ylabel("Accuracy (%)");
title("Validation Accuracy");
legend(labelA, labelB, "Location", "best");
ylim([0 100]);
grid on;

sgtitle(titleText, "Interpreter", "none");
end
