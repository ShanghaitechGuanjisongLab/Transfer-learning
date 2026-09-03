%% ExplainMIvsTendency.m
% Why does MI stay ~0 at t<0 while Stage1 tendency (audio only vs light only)
% seemed to separate (old code, before bugfix)?
% ANSWER (after fixing the balanced-sampling index bug in iCvPredict):
%   There was NO real pre-stimulus separation at t<0. The old "strong
%   separation (sep ~0.5-0.68)" was an ARTIFACT of `F(tr(bal),:)` indexing:
%   bal is a relative index into y(tr), but was applied to the logical `tr`,
%   selecting wrong trial rows, corrupting class balance and biasing training
%   to the first rows -> spurious separation and NaN for imbalanced mice.
% After fix: at t<0 tendency AO/LO both ~0.5, balacc ~0.5, MI ~0 (all
% consistent). Real cue information only appears after stimulus onset
% (t>+0.32 s), where MI rises and tendency separates in the same direction.
% So MI and tendency do NOT contradict: both measure the same signal, and
% both are near chance before the stimulus.
% Test: per-trial OOF at pre vs post, report tendency sep, balacc, MI.
% Run via MATLAB MCP.

%% 0. Setup (same as CompareCueTrainData cfg1)
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
rng(42);
doBaselineNorm = true;
met = 2; K = 5;
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);

Blk = DS.Blocks; Blk.Design = string(Blk.Design);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone); DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse); DT.Phase = string(DT.Phase);
blkDT = datetime(Blk.DateTime);
if ~isempty(blkDT.TimeZone); blkDT.TimeZone = ''; end
ph = repmat("<missing>", height(Blk), 1);
for i = 1:height(Blk)
    idx = find(DT.DateTime == blkDT(i), 1);
    if ~isempty(idx); ph(i) = DT.Phase(idx); end
end
Blk.Phase = ph;
trainAW   = Blk.BlockUID(Blk.Design == "AudioWater" & (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ~ismember(Blk.Phase, ["Recall","Final"]));

miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    s1 = table();
    for st = ["AudioWater","AudioOnly","LightOnly"]
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus',st), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if isempty(r) || isempty(r{1}); continue; end
        t = r{1};
        if st == "AudioWater"; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
        else;                   t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :); end
        if isempty(t); continue; end
        t.Cue = zeros(height(t),1) + double(st == "LightOnly");
        t.Type = zeros(height(t),1) + double(st == "AudioOnly") + 2*double(st == "LightOnly");
        s1 = [s1; t]; %#ok<AGROW>
    end
    if isempty(s1) || ~ismember('TrialSignal', string(s1.Properties.VariableNames)); continue; end
    s1 = s1(~isnan(s1.Behavior), :);   % keep trials with valid behavior (like CompareCueTrainData)
    if isempty(s1); continue; end
    cellUIDs = uint64(unique(s1.CellUID));
    if numel(cellUIDs) < 10; continue; end
    X1 = iBuildTrialMatrix(s1, cellUIDs, tIdxFull);
    if isempty(X1); continue; end
    if doBaselineNorm; X1 = iBaselineNorm(X1, find(tVec<0)); end
    y1 = iTrialLabel(s1, 'Cue');
    typ = iTrialLabel(s1, 'Type');
    if sum(typ==1)<3 || sum(typ==2)<3; continue; end
    ok1 = ~isnan(y1) & ~isnan(typ);
    nUsed = nUsed + 1;
    resAll{nUsed} = struct('Mouse',m,'X1',X1,'y1',y1,'typ',typ,'ok1',ok1);
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);

%% 1. Per-time decomposition
fprintf('\n=== cfg1 OOF: per-time tendency sep vs balacc vs MI ===\n');
fprintf(' t     | tend.AO tend.LO | sep   | balacc | MI\n');
fprintf('-------+----------------+-------+--------+------\n');
for iT = 1:nTfull
    mA = []; mL = []; b = []; mi = [];
    for i = 1:nValid
        r = resAll{i};
        ok1 = r.ok1;
        [sOOF, pOOF] = iCvPredict(r.X1(ok1,:,iT), r.y1(ok1), K, met);
        pA = 1./(1+exp(sOOF));   % P(audio) per trial
        y1 = r.y1(ok1); typ = r.typ(ok1);
        ao = pA(typ==1); lt = pA(typ==2);
        if numel(ao)>=3 && numel(lt)>=3
            mA(end+1) = mean(ao,'omitnan'); mL(end+1) = mean(lt,'omitnan'); %#ok<AGROW>
            pred = double(pA < 0.5);   % 1 = light
            lab = y1;                  % 0 = audio, 1 = light
            a0 = mean(pred(lab==0)==0,'omitnan'); a1 = mean(pred(lab==1)==1,'omitnan');
            b(end+1) = mean([a0 a1],'omitnan'); %#ok<AGROW>
            mi(end+1) = iMIFromLabels(pred, lab); %#ok<AGROW>
        end
    end
    fprintf('%+5.2f | %5.3f %5.3f | %.3f | %.3f  | %.3f\n', tVec(iT), ...
        mean(mA), mean(mL), abs(mean(mA)-mean(mL)), mean(b), mean(mi));
end

% ==================== Local Functions ====================

function X = iBuildTrialMatrix(rawTbl, cellUIDs, tIdx)
sig = double(rawTbl.TrialSignal);
sig = sig(:, tIdx);
nts = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), 'VariableNames',{'CellUID','TrialUID'});
sigCell = cell(size(sig,1),1);
for i = 1:size(sig,1); sigCell{i} = sig(i,:); end %#ok<AGROW>
nts.Signal = sigCell;
nts = nts(ismember(nts.CellUID, cellUIDs), :);
if isempty(nts); X=[]; return; end
tu = unique(nts.TrialUID);
X = zeros(numel(tu), numel(cellUIDs), size(sig,2));
for iT = 1:numel(tu)
    rows = nts(nts.TrialUID == tu(iT), :);
    [~, loc] = ismember(rows.CellUID, cellUIDs);
    for iR = 1:height(rows)
        ci = loc(iR);
        if ci > 0; X(iT, ci, :) = rows.Signal{iR}; end
    end
end
end

function X = iBaselineNorm(X, baseIdx)
mu = mean(X(:, :, baseIdx), 3);
X = X - mu;
end

function y = iTrialLabel(rawTbl, varName)
tu = unique(uint64(rawTbl.TrialUID));
y = nan(numel(tu),1);
for iT = 1:numel(tu)
    v = rawTbl.(varName)(uint64(rawTbl.TrialUID)==tu(iT));
    y(iT) = mode(v);
end
end

function [sOOF, pOOF] = iCvPredict(F, y, K, met)
n = size(F,1);
sOOF = nan(n,1); pOOF = nan(n,1);
perm = randperm(n);
foldSize = ceil(n/K);
for k = 1:K
    te = false(n,1);
    idx = (k-1)*foldSize+1 : min(k*foldSize, n);
    te(perm(idx)) = true;
    tr = ~te;
    if sum(y(te)==1) < 1 || sum(y(te)==0) < 1
        maj = mode(y(tr));
        sOOF(te) = 2*maj-1; pOOF(te) = maj; continue;
    end
    bal = iBalanceTrain(y(tr));          % bal indexes into y(tr), i.e. 1..numel(idxTr)
    idxTr = find(tr);
    if met == 1
        [sOOF(te), pOOF(te)] = iLinDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:));
    else
        [sOOF(te), pOOF(te)] = iGlmDecode(F(idxTr(bal),:), y(idxTr(bal)), F(te,:));
    end
end
end

function bal = iBalanceTrain(y)
idx1 = find(y==1); idx0 = find(y==0);
n = min(numel(idx1), numel(idx0));
idx1 = idx1(randperm(numel(idx1), n));
idx0 = idx0(randperm(numel(idx0), n));
bal = [idx1; idx0];
end

function [score, pred] = iLinDecode(Ftr, ytr, Fte)
mu = mean(Ftr,1); sd = std(Ftr,0,1); sd(sd==0)=1;
Ftrs = (Ftr-mu)./sd; Ftes = (Fte-mu)./sd;
w = pinv([ones(size(Ftrs,1),1), Ftrs])*(2*ytr-1);
score = [ones(size(Ftes,1),1), Ftes]*w;
pred = double(score >= 0);
end

function [score, pred] = iGlmDecode(Ftr, ytr, Fte)
m0 = mean(Ftr(ytr==0,:),1); m1 = mean(Ftr(ytr==1,:),1);
s0 = std(Ftr(ytr==0,:),0,1); s1 = std(Ftr(ytr==1,:),0,1);
sp = sqrt((s0.^2 + s1.^2)/2); sp(sp==0)=1;
score = sum((Fte - m0).^2./(2*sp.^2) - (Fte - m1).^2./(2*sp.^2), 2);
pred = double(score >= 0);
end

function mi = iMIFromLabels(pred, lab)
n = numel(lab);
if n < 4 || numel(unique(lab)) < 2; mi = 0; return; end
joint = accumarray([pred(:)+1, lab(:)+1], 1, [2 2]);
mi = iMIFromJoint(joint, n);
end

function mi = iMIFromJoint(joint, n)
joint(sum(joint,2)==0,:) = [];
if isempty(joint); mi=0; return; end
p = joint/sum(joint(:));
px = sum(p,2); py = sum(p,1);
miRaw = 0;
for i=1:size(p,1)
    for j=1:size(p,2)
        if p(i,j)>0 && px(i)>0 && py(j)>0
            miRaw = miRaw + p(i,j)*log2(p(i,j)/(px(i)*py(j)));
        end
    end
end
Mx = size(p,1); My = size(p,2);
mi = max(0, miRaw - (Mx-1)*(My-1)/(2*n*log(2)));
end
