function RunSortedVsShuffledOrder()
% Compare class-sorted vs shuffled order on same 30/class MNIST fixed subset.
% Both start from same CIFAR vw=0.5 pretrained checkpoint.
% 5 seeds, parallel, TaskB only 5 epochs.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmFull, ymFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);

cfg.inputSize = [32 32 3]; cfg.numClasses = 10; cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3; cfg.maxEpochsA = 100; cfg.maxEpochsB = 5;
cfg.samplesPerEpochA = 500; cfg.varWeightA = 0.5;
cfg.layers = ["res2b_relu","res3b_relu","res4b_relu"];
cfg.nTrainPerClass = 30; cfg.nValPerClass = 10;

seeds = 20260661:20260665; nRepeats = numel(seeds);
gpuCount = gpuDeviceCount("available"); nWorkers = min(nRepeats, gpuCount);
fprintf("Sorted vs Shuffled: %d seeds, %d GPUs\n", nRepeats, gpuCount);

pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= nWorkers, delete(pool); end
if isempty(pool), parpool("Processes", nWorkers); end

accSorted = zeros(nRepeats, cfg.maxEpochsB);
accShuffled = zeros(nRepeats, cfg.maxEpochsB);

parfor ri = 1:nRepeats
    task = getCurrentTask(); w = 1; if ~isempty(task), w = task.ID; end
    gpuIdx = mod(w-1, gpuCount) + 1; gpuDevice(gpuIdx);
    seed = seeds(ri);
    fprintf("[repeat %d] seed=%d gpu=%d\n", ri, seed, gpuIdx);

    % Build subset: class-balanced, NOT shuffled (sorted order)
    rng(seed);
    nc = cfg.numClasses; nTr = cfg.nTrainPerClass; nVal = cfg.nValPerClass;
    XTr = zeros(nTr*nc, size(XmFull,2), "uint8"); yTr = zeros(nTr*nc, 1, "uint8");
    XVl = zeros(nVal*nc, size(XmFull,2), "uint8"); yVl = zeros(nVal*nc, 1, "uint8");
    for c = 1:nc
        rows = find(ymFull == c); rows = rows(randperm(numel(rows)));
        XTr((c-1)*nTr+1:c*nTr,:) = XmFull(rows(1:nTr),:);
        yTr((c-1)*nTr+1:c*nTr) = c;
        XVl((c-1)*nVal+1:c*nVal,:) = XmFull(rows(nTr+1:nTr+nVal),:);
        yVl((c-1)*nVal+1:c*nVal) = c;
    end
    % Shuffled copy of same images
    ord = randperm(size(XTr,1));
    XTrSh = XTr(ord,:); yTrSh = yTr(ord);
    ordV = randperm(size(XVl,1));
    XVlSh = XVl(ordV,:); yVlSh = yVl(ordV);

    % Train one shared TaskA checkpoint
    rng(seed);
    [XgA, TgA] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
    netA = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
    netA = trainAonly(netA, XgA, TgA, cfg);

    % TaskB sorted
    [~, aS] = trainBonly(netA, XTr, yTr, XVl, yVl, cfg);

    % TaskB shuffled (clone network to get identical start)
    rng(seed);
    [~, ~] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,nc);
    netA2 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, nc);
    netA2 = trainAonly(netA2, XgA, TgA, cfg); % same weights as netA
    [~, aH] = trainBonly(netA2, XTrSh, yTrSh, XVlSh, yVlSh, cfg);

    accSorted(ri,:) = aS;
    accShuffled(ri,:) = aH;
    fprintf("[repeat %d] sorted: ", ri); fprintf("%.3f ", aS); fprintf("\n");
    fprintf("           shuffled: "); fprintf("%.3f ", aH); fprintf("\n");
end

fprintf("\n=== Epoch-by-epoch: Sorted vs Shuffled (30/class, A vw=0.5) ===\n");
for ep = 1:cfg.maxEpochsB
    d = accShuffled(:,ep) - accSorted(:,ep);
    fprintf("epoch %d: meanDiff=%+.4f pos=%d/%d range=[%+.4f,%+.4f]\n", ...
        ep, mean(d), sum(d>0), nRepeats, min(d), max(d));
end
end

function net = trainAonly(net,Xg,Tg,cfg)
nTr = size(Xg,4); sEp = min(cfg.samplesPerEpochA, nTr);
ta=[]; tsq=[]; iter=0;
for ep = 1:cfg.maxEpochsA
    ord = randperm(nTr, sEp);
    for st = 1:cfg.miniBatchSize:sEp
        e = min(st+cfg.miniBatchSize-1, sEp); idx = ord(st:e); iter=iter+1;
        dlX = dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT = dlarray(Tg(:,idx),"CB");
        [gr,~,~,~] = dlfeval(@lossSimple,net,dlX,dlT,cfg.varWeightA,cfg.layers);
        [net,ta,tsq] = adamupdate(net,gr,ta,tsq,iter,cfg.learnRate);
    end
end
end

function [varVec,accVec] = trainBonly(net,XTr,yTr,XVl,yVl,cfg)
nTr = size(XTr,1);
[Xg,Tg] = TransferLearning.PreUploadCifarToGpu(XTr,yTr,cfg.numClasses);
[dlXv,dlTv] = TransferLearning.PreprocessCifarRows(XVl,yVl,cfg.inputSize,cfg.numClasses);
varVec = zeros(1, cfg.maxEpochsB); accVec = zeros(1, cfg.maxEpochsB);
ta=[]; tsq=[]; iter=0;
for ep = 1:cfg.maxEpochsB
    accVec(ep) = TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,cfg.miniBatchSize);
    ord = 1:nTr; % fixed order (sorted or shuffled externally)
    for st = 1:cfg.miniBatchSize:nTr
        e = min(st+cfg.miniBatchSize-1, nTr); idx = ord(st:e); iter=iter+1;
        dlX = dlarray(single(Xg(:,:,:,idx))/255,"SSCB");
        dlT = dlarray(Tg(:,idx),"CB");
        [gr,~,~,~] = dlfeval(@lossSimple,net,dlX,dlT,0,cfg.layers);
        [net,ta,tsq] = adamupdate(net,gr,ta,tsq,iter,cfg.learnRate);
    end
end
end

function [gr,lo,ce,vt] = lossSimple(net,dlX,dlT,vw,lay)
outputs=["fc_logits",lay]; C=cell(1,numel(lay));
[logits,C{:}] = forward(net,dlX,Outputs=outputs);
p=softmax(logits); ce=crossentropy(p,dlT,TargetCategories="independent");
vv=zeros(1,numel(lay),"like",C{1});
for i=1:numel(lay), f=reshape(stripdims(C{i}),[],size(C{i},4)); vv(i)=mean(var(f,0,2),"all");end
vt=mean(vv,"all"); lo=ce/(1+vw*vt); gr=dlgradient(lo,net.Learnables);
end
