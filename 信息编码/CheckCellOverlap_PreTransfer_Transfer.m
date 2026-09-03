%% CheckCellOverlap_PreTransfer_Transfer.m
% Cell alignment check between pre-Transfer AudioWater (Naive + Learned +
% unannotated-phase blocks, EXCLUDING Recall) and Transfer LightWater.
% Determines whether a GLM decoder trained on pre-Transfer data can be
% evaluated on Transfer data with the same cells.

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);

%% 1. Blocks: attach phase (from DateTimes) and define train/test blocks
Blk = DS.Blocks;
Blk.Design = string(Blk.Design);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

blkDT = datetime(Blk.DateTime);
if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
ph = repmat("<missing>", height(Blk), 1);
for i = 1:height(Blk)
    idx = find(DT.DateTime == blkDT(i), 1);
    if ~isempty(idx); ph(i) = DT.Phase(idx); end
end
Blk.Phase = ph;

% training blocks: AudioWater with phase Naive/Learned OR unannotated (no Recall)
trainBlk = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
% test blocks: LightWater Transfer
testBlk = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
fprintf('=== Cell alignment: pre-Transfer AudioWater vs Transfer LightWater ===\n');
fprintf('Train blocks (AudioWater, no Recall): %d   Test blocks (Transfer LW): %d\n', ...
    numel(trainBlk), numel(testBlk));

%% 2. Per-mouse unique cell overlap
miceAll = unique(DT.Mouse);
fprintf('\n%-10s | %-10s | %-10s | %-10s | %-12s | %-10s\n', ...
    'Mouse', 'TrainCells', 'TestCells', 'Overlap', 'Frac(train)', 'Frac(test)');
fprintf('%s\n', repmat('-', 1, 78));
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    trainC = uint64([]); testC = uint64([]);
    try
        r1 = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r1) && ~isempty(r1{1})
            t = r1{1};
            t = t(ismember(uint64(t.BlockUID), uint64(trainBlk)), :);
            trainC = unique(uint64(t.CellUID));
        end
    catch
    end
    try
        r2 = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if ~isempty(r2) && ~isempty(r2{1})
            testC = unique(uint64(r2{1}.CellUID));
        end
    catch
    end
    ov = intersect(trainC, testC);
    fprintf('%-10s | %-10d | %-10d | %-10d | %-12.1f%% | %-10.1f%%\n', ...
        m, numel(trainC), numel(testC), numel(ov), ...
        100*numel(ov)/max(1,numel(trainC)), 100*numel(ov)/max(1,numel(testC)));
end

fprintf('\nDone. Cell alignment check complete.\n');
