function DiagnoseTaskB()
fprintf('=== DiagnoseTaskB start ===\n');

dataRoot = "D:\训练数据";
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot, 0.1, 0.8, 20260616);
inputSize = [32 32 3]; numClasses = 10;

% ---- Step 1: tiny Task A train ----
gpuDevice([]); pause(1); gpuDevice(1);
fprintf('Step1: train tiny Task A (2 epochs, batch=16)...\n');
net = TransferLearning.BuildResNet50Classifier(inputSize, numClasses);
[net, ~] = TransferLearning.TrainImageTaskVarianceLoss(...
    net, dataset.taskA.trainX, dataset.taskA.trainY, ...
    dataset.taskA.valX, dataset.taskA.valY, ...
    dataset.classNames, inputSize, 2, 16, 1e-3, 0.02, 1);
fprintf('Step1 OK. GPU free: %.1f GB\n', gpuDevice().AvailableMemory/1e9);

% ---- Step 2: check if net weights are still valid ----
fprintf('Step2: test forward with same Task A data...\n');
[Xa, Ta] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX, dataset.taskA.trainY, numClasses);
dlXa = dlarray(single(Xa(:,:,:,1:4))/255, 'SSCB');
dlTa = dlarray(Ta(:,1:4), 'CB');
try
    y = forward(net, dlXa);
    fprintf('Step2 OK. forward output size: %dx%d\n', size(y,1), size(y,2));
catch ME
    fprintf('Step2 FAIL: %s\n', ME.message);
end

% ---- Step 3: upload Task B data ----
fprintf('Step3: preupload Task B data...\n');
try
    [Xb, Tb] = TransferLearning.PreUploadCifarToGpu(dataset.taskB.trainX, dataset.taskB.trainY, numClasses);
    fprintf('Step3 OK. Xb class=%s, GPU free: %.1f GB\n', class(Xb), gpuDevice().AvailableMemory/1e9);
catch ME
    fprintf('Step3 FAIL: %s\n', ME.message);
    return;
end

% ---- Step 4: forward with Task B data ----
fprintf('Step4: forward on Task B data...\n');
dlXb = dlarray(single(Xb(:,:,:,1:4))/255, 'SSCB');
dlTb = dlarray(Tb(:,1:4), 'CB');
try
    yb = forward(net, dlXb);
    fprintf('Step4 OK. output: %dx%d\n', size(yb,1), size(yb,2));
catch ME
    fprintf('Step4 FAIL: %s\n', ME.message);
end

% ---- Step 5: dlfeval + adamupdate on Task B ----
fprintf('Step5: one dlfeval+adamupdate on Task B...\n');
try
    trailingAvg=[]; trailingAvgSq=[];
    [gr,loss,ce,vt] = dlfeval(@TransferLearning.ComputeModelGradientsVarianceLoss, net, dlXb, dlTb, 0.02);
    [net, trailingAvg, trailingAvgSq] = adamupdate(net, gr, trailingAvg, trailingAvgSq, 1, 1e-3);
    fprintf('Step5 OK. loss=%.4f\n', double(gather(extractdata(loss))));
catch ME
    fprintf('Step5 FAIL: %s\n', ME.message);
end

% ---- Step 6: mini Task B training ----
fprintf('Step6: tiny Task B training (1 epoch, batch=16)...\n');
try
    [net, statsB] = TransferLearning.TrainImageTaskVarianceLoss(...
        net, dataset.taskB.trainX, dataset.taskB.trainY, ...
        dataset.taskB.valX, dataset.taskB.valY, ...
        dataset.classNames, inputSize, 1, 16, 1e-3, 0.02, 1);
    fprintf('Step6 OK. valAcc=%.4f\n', statsB.valAccuracy(end));
catch ME
    fprintf('Step6 FAIL: %s\n', ME.message);
end

fprintf('=== DiagnoseTaskB done ===\n');
end
