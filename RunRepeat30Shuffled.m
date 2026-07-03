function RunRepeat30Shuffled()
% Retest 30/class with SHUFFLED fixed subset (matching the fix in sample-size sweep).
% TaskA: CIFAR vw=0 vs vw=0.5 res2-4. TaskB: MNIST 30/class, 10/val, B vw=0.
% Metric: epoch 3 accuracy diff. 5 seeds, parallel.

dataRoot = "D:\训练数据";
PrepareOfficialCIFAR10TaskAB();
TransferLearning.PrepareOfficialMNIST();
dataset = TransferLearning.LoadCifar10TaskABInMemory(dataRoot);
[XmFull, ymFull] = TransferLearning.LoadMnistAsCifarFormat(dataRoot, "train", 0, 20260616);

cfg.inputSize = [32 32 3]; cfg.numClasses = 10; cfg.miniBatchSize = 128;
cfg.learnRate = 1e-3; cfg.maxEpochsA = 100; cfg.maxEpochsB = 4;
cfg.samplesPerEpochA = 500; cfg.varWeightA = 0.5; cfg.varWeightB = 0;
cfg.nTrainPerClass = 30; cfg.nValPerClass = 10;
cfg.layers = ["res2b_relu","res3b_relu","res4b_relu"];

seeds = 20260651:20260655; nRepeats = numel(seeds);
gpuCount = gpuDeviceCount("available"); nWorkers = min(nRepeats, gpuCount);
fprintf("30/class shuffled: %d seeds, %d GPUs, %d workers\n", nRepeats, gpuCount, nWorkers);

pool = gcp("nocreate");
if ~isempty(pool) && pool.NumWorkers ~= nWorkers, delete(pool); end
if isempty(pool), parpool("Processes", nWorkers); end

accB0 = zeros(nRepeats, cfg.maxEpochsB);
accB1 = zeros(nRepeats, cfg.maxEpochsB);

parfor ri = 1:nRepeats
    task = getCurrentTask(); workerIdx = 1; if ~isempty(task), workerIdx = task.ID; end
    gpuIdx = mod(workerIdx-1, gpuCount)+1; gpuDevice(gpuIdx);
    seed = seeds(ri);
    fprintf("[repeat %d/%d] seed=%d gpu=%d\n", ri, nRepeats, seed, gpuIdx);

    [XTr, yTr, XVl, yVl] = makeShuffledSubset(XmFull, ymFull, cfg.numClasses, cfg.nTrainPerClass, cfg.nValPerClass, seed);

    rng(seed);
    [Xg0,Tg0] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,cfg.numClasses);
    net0 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    sA0 = trainAquick(net0,Xg0,Tg0,dataset.taskA.valX,dataset.taskA.valY,cfg,0);
    [~,a0] = trainBquick(sA0.netFinal,XTr,yTr,XVl,yVl,cfg,cfg.varWeightB);

    rng(seed);
    [Xg1,Tg1] = TransferLearning.PreUploadCifarToGpu(dataset.taskA.trainX,dataset.taskA.trainY,cfg.numClasses);
    net1 = TransferLearning.BuildResNet18Classifier(cfg.inputSize, cfg.numClasses);
    sA1 = trainAquick(net1,Xg1,Tg1,dataset.taskA.valX,dataset.taskA.valY,cfg,cfg.varWeightA);
    [~,a1] = trainBquick(sA1.netFinal,XTr,yTr,XVl,yVl,cfg,cfg.varWeightB);

    accB0(ri,:) = a0; accB1(ri,:) = a1;
    fprintf("[repeat %d] acc: B0=", ri); fprintf("%.3f ", a0); fprintf("B1="); fprintf("%.3f ", a1);
    fprintf("| ep3 diff=%+.3f\n", a1(3)-a0(3));
end

fprintf("\n=== Epoch 3 accuracy diff (shuffled 30/class) ===\n");
ep3diff = accB1(:,3) - accB0(:,3);
for i=1:nRepeats
    fprintf("repeat %d seed=%d: B0=%.3f B1=%.3f diff=%+.3f\n", i, seeds(i), accB0(i,3), accB1(i,3), ep3diff(i));
end
fprintf("Positive: %d/%d, mean=%+.4f, median=%+.4f, range=[%+.4f,%+.4f]\n", sum(ep3diff>0), nRepeats, mean(ep3diff), median(ep3diff), min(ep3diff), max(ep3diff));
end

function [XTr,yTr,XVl,yVl] = makeShuffledSubset(XFull,yFull,nc,nTrC,nValC,seed)
rng(seed);
XTr = zeros(nTrC*nc,size(XFull,2),"uint8"); yTr = zeros(nTrC*nc,1,"uint8");
XVl = zeros(nValC*nc,size(XFull,2),"uint8"); yVl = zeros(nValC*nc,1,"uint8");
for c=1:nc
    rows = find(yFull==c); rows = rows(randperm(numel(rows)));
    XTr((c-1)*nTrC+1:c*nTrC,:) = XFull(rows(1:nTrC),:);
    yTr((c-1)*nTrC+1:c*nTrC) = c;
    XVl((c-1)*nValC+1:c*nValC,:) = XFull(rows(nTrC+1:nTrC+nValC),:);
    yVl((c-1)*nValC+1:c*nValC) = c;
end
ord = randperm(size(XTr,1)); XTr=XTr(ord,:); yTr=yTr(ord);
ord = randperm(size(XVl,1)); XVl=XVl(ord,:); yVl=yVl(ord);
end

function s = trainAquick(net,Xg,Tg,Xv,yv,cfg,vw)
nTr=size(Xg,4); sEp=min(cfg.samplesPerEpochA,nTr);
[dlXv,dlTv]=TransferLearning.PreprocessCifarRows(Xv,yv,cfg.inputSize,cfg.numClasses);
s=struct(); s.trainVar=zeros(cfg.maxEpochsA,1);
ta=[];tsq=[];iter=0;
for ep=1:cfg.maxEpochsA
    TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,cfg.miniBatchSize);
    ord=randperm(nTr,sEp); epV=0;nb=0;
    for st=1:cfg.miniBatchSize:sEp
        e=min(st+cfg.miniBatchSize-1,sEp);idx=ord(st:e);iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@loss,net,dlX,dlT,vw,cfg.layers);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,cfg.learnRate);
        epV=epV+double(extractdata(vt));nb=nb+1;
    end
    s.trainVar(ep)=epV/nb;
end
s.netFinal=net;
end

function [varVec,accVec]=trainBquick(net,XTr,yTr,XVl,yVl,cfg,vw)
nTr=size(XTr,1);
[Xg,Tg]=TransferLearning.PreUploadCifarToGpu(XTr,yTr,cfg.numClasses);
[dlXv,dlTv]=TransferLearning.PreprocessCifarRows(XVl,yVl,cfg.inputSize,cfg.numClasses);
varVec=zeros(1,cfg.maxEpochsB);accVec=zeros(1,cfg.maxEpochsB);
ta=[];tsq=[];iter=0;
for ep=1:cfg.maxEpochsB
    accVec(ep)=TransferLearning.EvaluateClassificationAccuracyDlarray(net,dlXv,dlTv,cfg.miniBatchSize);
    ord=1:nTr; epV=0;nb=0;
    for st=1:cfg.miniBatchSize:nTr
        e=min(st+cfg.miniBatchSize-1,nTr);idx=ord(st:e);iter=iter+1;
        dlX=dlarray(single(Xg(:,:,:,idx))/255,"SSCB");dlT=dlarray(Tg(:,idx),"CB");
        [gr,~,~,vt]=dlfeval(@loss,net,dlX,dlT,vw,cfg.layers);
        [net,ta,tsq]=adamupdate(net,gr,ta,tsq,iter,cfg.learnRate);
        epV=epV+double(extractdata(vt));nb=nb+1;
    end
    varVec(ep)=epV/nb;
end
end

function [gr,lo,ce,vt]=loss(net,dlX,dlT,vw,lay)
outputs=["fc_logits",lay];C=cell(1,numel(lay));
[logits,C{:}]=forward(net,dlX,Outputs=outputs);
p=softmax(logits);ce=crossentropy(p,dlT,TargetCategories="independent");
vv=zeros(1,numel(lay),"like",C{1});
for i=1:numel(lay), f=reshape(stripdims(C{i}),[],size(C{i},4)); vv(i)=mean(var(f,0,2),"all"); end
vt=mean(vv,"all"); lo=ce/(1+vw*vt); gr=dlgradient(lo,net.Learnables);
end
