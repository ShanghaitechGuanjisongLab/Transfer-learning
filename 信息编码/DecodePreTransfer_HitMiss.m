%% DecodePreTransfer_HitMiss.m
% Choice (hit/miss) decoder. MAIN task = decode hit/miss (choice/behavior);
% CONTROL = decode cue (audio vs light), computed on the same training data.
%
% Two training schemes:
%   Scheme 1: all pre-Transfer data (AudioWater Naive/Learned/unannotated +
%             AudioOnly + LightOnly from LAu/LAuW; NO Recall)
%   Scheme 2: AudioWater only
% Test on two stages:
%   Stage1 = pre-Transfer (Naive-Learned), 5-fold CV out-of-fold
%   Stage2 = Transfer LightWater, held-out
% Output (per time point): decoded MI (bits), balanced accuracy, and
% tendency P(hit) by behavior (main). Cue control: decoded MI (scheme 1 only;
% N/A for scheme 2 = single cue class).
%
% Methods: (A) linear readout, (B) GLM naive-Gaussian (Bayes).

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
rng(42);
doBaselineNorm = true;   % subtract pre-stimulus baseline per trial-cell (test: remove tonic state)

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs; if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tIdxFull = find((xs >= -1) & (xs <= 1));
tVec = xs(tIdxFull);
nTfull = numel(tVec);

fprintf('=== Pre-Transfer HIT/MISS (choice) decoder ===\n');
fprintf('Time window: %.2f-%.2f s (%d pts)\n', tVec(1), tVec(end), nTfull);

%% 1. Blocks with phase; define training / test blocks
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

trainAW  = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)));
trainAWperf = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)) & ...
    Blk.Performance > 0.5);   % only blocks with hit rate > 50%%
trainAWlow = Blk.BlockUID(Blk.Design == "AudioWater" & ...
    (ismember(Blk.Phase, ["Naive","Learned"]) | ismissing(Blk.Phase)) & ...
    Blk.Performance < 0.6);   % only blocks with hit rate < 60%% (low performance)
testLW   = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
% Calibration test blocks: AudioOnly/LightOnly trials in LAu/LAuW blocks (no Recall/Final)
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu","LAuW"]) & ...
    ~ismember(Blk.Phase, ["Recall","Final"]));
fprintf('Train blocks: AW=%d; AW(Perf>0.5)=%d; AW(Perf<0.6)=%d; Test blocks (Transfer LW)=%d; Calib blocks=%d\n', ...
    numel(trainAW), numel(trainAWperf), numel(trainAWlow), numel(testLW), numel(calBlocks));

%% 2. Per-mouse trial data
miceAll = unique(DT.Mouse);
resAll = cell(numel(miceAll), 1);
nUsed = 0;
fprintf('\n========== Data loading ==========\n');
for iM = 1:numel(miceAll)
    m = miceAll(iM);
    % --- test: Transfer LightWater (Stage2) ---
    testTbl = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightWater','Phase','Transfer'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        testTbl = r{1};
        testTbl = testTbl(ismember(uint64(testTbl.BlockUID), uint64(testLW)), :);
    end
    if isempty(testTbl) || ~ismember('TrialSignal', string(testTbl.Properties.VariableNames)); continue; end
    % --- Calibration held-out test: AudioOnly + LightOnly (LAu/LAuW, no Recall/Final) ---
    teA = table(); teL = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioOnly'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        teA = r{1};
        teA = teA(ismember(uint64(teA.BlockUID), uint64(calBlocks)), :);
    end
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','LightOnly'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        teL = r{1};
        teL = teL(ismember(uint64(teL.BlockUID), uint64(calBlocks)), :);
    end
    if ~isempty(teA); teA = teA(~isnan(teA.Behavior), :); end
    if ~isempty(teL); teL = teL(~isnan(teL.Behavior), :); end
    % --- Scheme1 training: AudioWater + AudioOnly + LightOnly (no Recall) ---
    tr1 = table();
    for st = ["AudioWater","AudioOnly","LightOnly"]
        r = DS.QueryNTS(struct('Mouse',m,'Stimulus',st), ...
            UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
        if isempty(r) || isempty(r{1}); continue; end
        t = r{1};
        if st == "AudioWater"; t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :); end
        if isempty(t); continue; end
        t.Cue = zeros(height(t),1) + double(st == "LightOnly");
        tr1 = [tr1; t]; %#ok<AGROW>
    end
    if isempty(tr1) || ~ismember('TrialSignal', string(tr1.Properties.VariableNames)); continue; end
    % --- Scheme2 training: AudioWater only ---
    tr2 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1};
        t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr2 = t; end
    end
    if isempty(tr2) || ~ismember('TrialSignal', string(tr2.Properties.VariableNames)); continue; end
    % --- Scheme3 training: AudioWater with block Performance > 0.5 only ---
    tr3 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1};
        t = t(ismember(uint64(t.BlockUID), uint64(trainAWperf)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr3 = t; end
    end
    if isempty(tr3) || ~ismember('TrialSignal', string(tr3.Properties.VariableNames)); continue; end
    % --- Scheme4 training: AudioWater with block Performance < 0.6 only (optional) ---
    tr4 = table();
    r = DS.QueryNTS(struct('Mouse',m,'Stimulus','AudioWater'), ...
        UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns',["Behavior","BlockUID"]);
    if ~isempty(r) && ~isempty(r{1})
        t = r{1};
        t = t(ismember(uint64(t.BlockUID), uint64(trainAWlow)), :);
        if ~isempty(t); t.Cue = zeros(height(t),1); tr4 = t; end
    end

    % keep trials with valid behavior (needed for hit/miss labels)
    tr1 = tr1(~isnan(tr1.Behavior), :);
    tr2 = tr2(~isnan(tr2.Behavior), :);
    tr3 = tr3(~isnan(tr3.Behavior), :);
    if ~isempty(tr4) && ismember('Behavior', tr4.Properties.VariableNames)
        tr4 = tr4(~isnan(tr4.Behavior), :);
    end
    if isempty(tr1) || isempty(tr2) || isempty(tr3); continue; end

    cellUIDs = uint64(unique([tr1.CellUID; tr2.CellUID; tr3.CellUID; testTbl.CellUID]));
    if ~isempty(tr4); cellUIDs = uint64(unique([cellUIDs; tr4.CellUID])); end
    if ~isempty(teA) && ismember('TrialSignal', string(teA.Properties.VariableNames))
        cellUIDs = uint64(unique([cellUIDs; teA.CellUID]));
    end
    if ~isempty(teL) && ismember('TrialSignal', string(teL.Properties.VariableNames))
        cellUIDs = uint64(unique([cellUIDs; teL.CellUID]));
    end
    nCell = numel(cellUIDs);
    if nCell < 10; continue; end
    Xtr1 = iBuildTrialMatrix(tr1, cellUIDs, tIdxFull);
    Xtr2 = iBuildTrialMatrix(tr2, cellUIDs, tIdxFull);
    Xtr3 = iBuildTrialMatrix(tr3, cellUIDs, tIdxFull);
    Xte  = iBuildTrialMatrix(testTbl, cellUIDs, tIdxFull);
    if isempty(teA) || ~ismember('TrialSignal', string(teA.Properties.VariableNames))
        XteA = []; behTeA = [];
    else
        XteA = iBuildTrialMatrix(teA, cellUIDs, tIdxFull);
        behTeA = iTrialLabel(teA, 'Behavior');
    end
    if isempty(teL) || ~ismember('TrialSignal', string(teL.Properties.VariableNames))
        XteL = []; behTeL = [];
    else
        XteL = iBuildTrialMatrix(teL, cellUIDs, tIdxFull);
        behTeL = iTrialLabel(teL, 'Behavior');
    end
    if isempty(tr4)
        Xtr4 = []; behTr4 = []; cueTr4 = [];
    else
        Xtr4 = iBuildTrialMatrix(tr4, cellUIDs, tIdxFull);
        behTr4 = iTrialLabel(tr4, 'Behavior');
        cueTr4 = zeros(numel(behTr4),1);
    end
    if isempty(Xtr1) || isempty(Xtr2) || isempty(Xtr3) || isempty(Xte); continue; end
    if doBaselineNorm
        baseIdx = find(tVec < 0);
        Xtr1 = iBaselineNorm(Xtr1, baseIdx);
        Xtr2 = iBaselineNorm(Xtr2, baseIdx);
        Xtr3 = iBaselineNorm(Xtr3, baseIdx);
        Xte  = iBaselineNorm(Xte, baseIdx);
        if ~isempty(Xtr4); Xtr4 = iBaselineNorm(Xtr4, baseIdx); end
        if ~isempty(XteA); XteA = iBaselineNorm(XteA, baseIdx); end
        if ~isempty(XteL); XteL = iBaselineNorm(XteL, baseIdx); end
    end
    behTr1 = iTrialLabel(tr1, 'Behavior');   % hit=1, miss=0
    behTr2 = iTrialLabel(tr2, 'Behavior');
    behTr3 = iTrialLabel(tr3, 'Behavior');
    cueTr1 = iTrialLabel(tr1, 'Cue');        % audio=0, light=1
    cueTr2 = zeros(numel(behTr2),1);         % AudioWater only -> all audio
    cueTr3 = zeros(numel(behTr3),1);
    behTe  = iTrialLabel(testTbl, 'Behavior');
    cueTe  = ones(numel(behTe),1);           % all =1 (light)
    if sum(behTr1==1) < 3 || sum(behTr1==0) < 3; continue; end

    nUsed = nUsed + 1;
    res = struct('Mouse',m,'NCells',nCell, ...
        'Xtr1',Xtr1,'Xtr2',Xtr2,'Xtr3',Xtr3,'Xtr4',Xtr4,'Xte',Xte, ...
        'XteA',XteA,'XteL',XteL, ...
        'behTr1',behTr1,'behTr2',behTr2,'behTr3',behTr3,'behTr4',behTr4, ...
        'cueTr1',cueTr1,'cueTr2',cueTr2,'cueTr3',cueTr3,'cueTr4',cueTr4, ...
        'behTe',behTe,'cueTe',cueTe,'behTeA',behTeA,'behTeL',behTeL);
    resAll{nUsed} = res;
    if isempty(behTeA); hA=0; mA=0; else; hA=sum(behTeA==1); mA=sum(behTeA==0); end
    if isempty(behTeL); hL=0; mL=0; else; hL=sum(behTeL==1); mL=sum(behTeL==0); end
    fprintf('  %-9s cells=%3d  S1=%d(h%d/m%d) S2=%d(h%d/m%d) S3=%d(h%d/m%d) S4=%d(h%d/m%d) test=%d  calibA=%d(h%d/m%d) calibL=%d(h%d/m%d)\n', ...
        m, nCell, size(Xtr1,1), sum(behTr1==1), sum(behTr1==0), ...
        size(Xtr2,1), sum(behTr2==1), sum(behTr2==0), ...
        size(Xtr3,1), sum(behTr3==1), sum(behTr3==0), ...
        size(Xtr4,1), sum(behTr4==1), sum(behTr4==0), size(Xte,1), ...
        numel(behTeA), hA, mA, numel(behTeL), hL, mL);
end
resAll = resAll(1:nUsed);
nValid = nUsed;
fprintf('Valid mice: %d\n', nValid);
if nValid == 0; fprintf('No valid mice.\n'); return; end

%% 3. Decode: main hit/miss + control cue, per scheme / method / time
methods = {'linear','glm'};
schemes = {'allPre','AudioWater','AudioWaterPerf50','AudioWaterLowPerf'};
K = 5;
% main hit/miss: (nValid, method, scheme, stage, time)
miMain = nan(nValid, 2, 4, 2, nTfull);
balMain = nan(nValid, 2, 4, 2, nTfull);
% control cue (scheme 1 only): (nValid, method, stage, time)
miCtrl = nan(nValid, 2, 2, nTfull);
balCtrl = nan(nValid, 2, 2, nTfull);
% tendency P(hit) by behavior (main): (nValid, method, scheme, stage, beh hit/miss, time)
pMain = nan(nValid, 2, 4, 2, 2, nTfull);
% tendency P(audio) by cue (control, scheme1): (nValid, method, stage, cue audio/light, time)
pCtrl = nan(nValid, 2, 2, 2, nTfull);
% in-sample Stage1 (train+test on ALL training data): (nValid, method, scheme, time)
miIS = nan(nValid, 2, 4, nTfull);
balIS = nan(nValid, 2, 4, nTfull);
% calibration held-out (scheme2 decoder) on AudioOnly/LightOnly: (nValid, method, [AO,LO], time)
miCal = nan(nValid, 2, 2, nTfull);
balCal = nan(nValid, 2, 2, nTfull);
% tendency P(hit) by behavior (calibration): (nValid, method, [AO,LO], [hit,miss], time)
pCal = nan(nValid, 2, 2, 2, nTfull);

for i = 1:nValid
    r = resAll{i};
    Xte = r.Xte; behTe = r.behTe;
    for sc = 1:4
        if sc == 1
            Xtr = r.Xtr1; beh = r.behTr1; cue = r.cueTr1;
        elseif sc == 2
            Xtr = r.Xtr2; beh = r.behTr2; cue = r.cueTr2;
        elseif sc == 3
            Xtr = r.Xtr3; beh = r.behTr3; cue = r.cueTr3;
        else
            Xtr = r.Xtr4; beh = r.behTr4; cue = r.cueTr4;
        end
        okB = ~isnan(beh); okC = ~isnan(cue);
        % skip scheme if hit/miss unbalanced beyond usability
        if sum(beh(okB)==1) < 3 || sum(beh(okB)==0) < 3; continue; end
        for iT = 1:nTfull
            Ftr = Xtr(:, :, iT); Fte = Xte(:, :, iT);
            for met = 1:2
                % ---------- MAIN: hit/miss ----------
                Fb = Ftr(okB,:); yb = beh(okB);
                [sB1, pB1] = iCvPredict(Fb, yb, K, met);       % Stage1 OOF
                miMain(i,met,sc,1,iT) = iMIFromLabels(pB1, yb);
                balMain(i,met,sc,1,iT) = iBalAcc(pB1, yb);
                balTr = iBalanceTrain(yb);
                if met == 1
                    [sB2, pB2] = iLinDecode(Fb(balTr,:), yb(balTr), Fte);
                else
                    [sB2, pB2] = iGlmDecode(Fb(balTr,:), yb(balTr), Fte);
                end
                miMain(i,met,sc,2,iT) = iMIFromLabels(pB2, behTe);
                balMain(i,met,sc,2,iT) = iBalAcc(pB2, behTe);
                % P(hit) tendency by behavior
                pB1L = 1./(1+exp(-sB1));
                pB2L = 1./(1+exp(-sB2));
                pMain(i,met,sc,1,1,iT) = mean(pB1L(yb==1));
                pMain(i,met,sc,1,2,iT) = mean(pB1L(yb==0));
                pMain(i,met,sc,2,1,iT) = mean(pB2L(behTe==1));
                pMain(i,met,sc,2,2,iT) = mean(pB2L(behTe==0));
                % ---------- CALIBRATION held-out (scheme2 decoder): AudioOnly / LightOnly ----------
                if sc == 2
                    for ci = 1:2
                        if ci == 1; Xcal = r.XteA; bcal = r.behTeA;
                        else;        Xcal = r.XteL; bcal = r.behTeL; end
                        if isempty(Xcal) || isempty(bcal); continue; end
                        okCa = ~isnan(bcal);
                        if sum(bcal(okCa)==1) < 2 || sum(bcal(okCa)==0) < 2; continue; end
                        Fcal = Xcal(okCa, :, iT);
                        if met == 1
                            [sCal, pCalT] = iLinDecode(Fb(balTr,:), yb(balTr), Fcal);
                        else
                            [sCal, pCalT] = iGlmDecode(Fb(balTr,:), yb(balTr), Fcal);
                        end
                        miCal(i,met,ci,iT) = iMIFromLabels(pCalT, bcal(okCa));
                        balCal(i,met,ci,iT) = iBalAcc(pCalT, bcal(okCa));
                        pCalL = 1./(1+exp(-sCal));
                        pCal(i,met,ci,1,iT) = mean(pCalL(bcal(okCa)==1));
                        pCal(i,met,ci,2,iT) = mean(pCalL(bcal(okCa)==0));
                    end
                end
                % ---------- IN-SAMPLE (train+test on ALL training data) ----------
                if met == 1
                    [sIS, pIS] = iLinDecode(Fb, yb, Fb);
                else
                    [sIS, pIS] = iGlmDecode(Fb, yb, Fb);
                end
                miIS(i,met,sc,iT) = iMIFromLabels(pIS, yb);
                balIS(i,met,sc,iT) = iBalAcc(pIS, yb);
                % ---------- CONTROL: cue (scheme 1 only) ----------
                if sc == 1
                    Fc = Ftr(okC,:); yc = cue(okC);
                    if sum(yc==1) >= 3 && sum(yc==0) >= 3
                        [sC1, pC1] = iCvPredict(Fc, yc, K, met);   % Stage1 OOF
                        miCtrl(i,met,1,iT) = iMIFromLabels(pC1, yc);
                        balCtrl(i,met,1,iT) = iBalAcc(pC1, yc);
                        balTr2 = iBalanceTrain(yc);
                        if met == 1
                            [sC2, pC2] = iLinDecode(Fc(balTr2,:), yc(balTr2), Fte);
                        else
                            [sC2, pC2] = iGlmDecode(Fc(balTr2,:), yc(balTr2), Fte);
                        end
                        miCtrl(i,met,2,iT) = iMIFromLabels(pC2, r.cueTe);  % ~0 (all light)
                        balCtrl(i,met,2,iT) = iBalAcc(pC2, r.cueTe);
                        % P(audio) tendency by cue (Stage1)
                        pC1A = 1./(1+exp(sC1));   % higher score -> light -> P(audio) low
                        pCtrl(i,met,1,1,iT) = mean(pC1A(yc==0));
                        pCtrl(i,met,1,2,iT) = mean(pC1A(yc==1));
                        % P(audio) on Transfer by behavior (cue control, Stage2)
                        pC2A = 1./(1+exp(sC2));
                        pCtrl(i,met,2,1,iT) = mean(pC2A(behTe==1));
                        pCtrl(i,met,2,2,iT) = mean(pC2A(behTe==0));
                    end
                end
            end
        end
    end
end

%% 4. Figure (Scheme 2, GLM only): 2x2 = [Stage1 MI, Stage2 MI; Stage1 tendency, Stage2 tendency]
% Scheme2 = AudioWater (hit/miss only). Only GLM is displayed; linear results are
% computed but HIDDEN (no linear figures). Cue control (scheme1) is NOT overlaid
% here (different training set, inconsistent sources). Schemes 1/3/4 computed but NOT plotted.
snames = {'Stage1 (pre-Transfer, CV)','Stage2 (Transfer)'};
met = 2;   % GLM only
axMI = []; axTend = [];
f = figure('Name','Hit/miss decoder (AudioWater, GLM) - hit/miss only','Color','w','Position',[60 60 1120 860]);
% ---- Row 1: decoded MI (hit/miss, scheme2/AudioWater), GLM ----
for st = 1:2
    ax = subplot(2,2,st); hold(ax,'on');
    vals = squeeze(miMain(:,met,2,st,:));
    mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color', [0 0 0], 'LineWidth', 1.8, ...
        'MarkerSize',3, 'DisplayName', 'hit/miss');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoded MI (bits)');
    title(ax, [snames{st} ' - MI'],'FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize = 8;
    axMI(end+1) = ax; %#ok<AGROW>
end
% ---- Row 2: tendency, P(hit) by behavior (scheme2/AudioWater), GLM ----
bcols = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
bnames = {'hit','miss'};
for st = 1:2
    ax = subplot(2,2,2+st); hold(ax,'on');
    for b = 1:2   % P(hit) by behavior
        vals = squeeze(pMain(:,met,2,st,b,:));
        if all(isnan(vals(:))); continue; end
        mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
        % Stage1 = AudioWater (audio hit/miss); Stage2 = Transfer light (light hit/miss)
        if st == 1
            dn = sprintf('audio %s (%d)', bnames{b}, 2-b);
        else
            dn = sprintf('light %s (%d)', bnames{b}, 2-b);
        end
        errorbar(ax, tVec, mn, se, '-', 'Color', bcols{b}, 'LineWidth', 1.6, ...
            'MarkerSize',2, 'DisplayName', dn);
    end
    yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Tendency (0-1)');
    title(ax, [snames{st} ' - tendency'],'FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',6);
    box(ax,'off'); ax.FontSize = 8;
    axTend(end+1) = ax; %#ok<AGROW>
end
% ---- align axes of the same type ----
ymaxMI = 0;
for k = 1:numel(axMI); yl = get(axMI(k),'YLim'); ymaxMI = max(ymaxMI, yl(2)); end
for k = 1:numel(axMI); set(axMI(k),'YLim',[0 ymaxMI]); end
for k = 1:numel(axTend); set(axTend(k),'YLim',[0 1]); end

%% 4b. Overfitting check: CV (out-of-fold) vs IN-SAMPLE Stage1 hit/miss MI
fprintf('\n=== CV vs IN-SAMPLE (Stage1 hit/miss) ===\n');
for sc = 1:4
    fprintf('Scheme %d (%s):\n', sc, schemes{sc});
    for met = 1:2
        if met == 1; metnm = 'linear'; else; metnm = 'glm'; end
        vC = squeeze(miMain(:,met,sc,1,:)); vI = squeeze(miIS(:,met,sc,:));
        mC = mean(vC,1,'omitnan'); mI = mean(vI,1,'omitnan');
        fprintf('  %-6s CV MI mean=%.4f peak=%.4f | in-sample MI mean=%.4f peak=%.4f | ratio=%.1fx | balacc CV=%.3f vs in-sample=%.3f\n', ...
            metnm, mean(mC), max(mC), mean(mI), max(mI), mean(mI)/mean(mC), ...
            mean(mean(squeeze(balMain(:,met,sc,1,:)),1,'omitnan')), ...
            mean(mean(squeeze(balIS(:,met,sc,:)),1,'omitnan')));
    end
end
% figure: scheme2 Stage1 CV vs in-sample MI (GLM only)
met = 2;
f = figure('Name','Hit/miss Stage1 MI: CV vs in-sample (scheme2, GLM)','Color','w','Position',[60 80 1120 430]);
ax = subplot(1,1,1); hold(ax,'on');
vals = squeeze(miMain(:,met,2,1,:));
mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
errorbar(ax, tVec, mn, se, '-', 'Color',[0 0 0],'LineWidth',1.8,'MarkerSize',3,'DisplayName','CV (out-of-fold)');
vals = squeeze(miIS(:,met,2,:));
mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
errorbar(ax, tVec, mn, se, '--', 'Color',[0.85 0.33 0.10],'LineWidth',1.8,'MarkerSize',3,'DisplayName','in-sample');
xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoded MI (bits)');
title(ax,'Stage1 hit/miss MI (GLM): CV vs in-sample','FontSize',9,'FontWeight','normal');
legend(ax,'Location','northwest','Box','off','FontSize',7);
box(ax,'off'); ax.FontSize = 8;

%% 4c. Permutation null test: is hit/miss MI (scheme2) significantly > 0?
% Full re-decode permutation: within each mouse, shuffle hit/miss labels, rerun
% the same decoding, recompute MI for BOTH Stage1 (CV) and Stage2 (Transfer).
% Null = "no predictive power". Tests (per method & stage):
%   - per-time-point p (uncorrected) + n significant time points (p<0.05)
%   - max-statistic p over ALL time  -> "any time point significant"
%   - max-statistic p over pre-cue (t<0) and post-cue (t>0) separately
sc = 2; Nperm = 100;
rng(234);
obsMI1 = squeeze(mean(miMain(:, :, sc, 1, :), 1, 'omitnan'));   % (method, time)
obsMI2 = squeeze(mean(miMain(:, :, sc, 2, :), 1, 'omitnan'));
obsMax1 = max(obsMI1, [], 2); obsMax2 = max(obsMI2, [], 2);
obsPre1  = max(obsMI1(:, tVec<0), [], 2); obsPost1 = max(obsMI1(:, tVec>0), [], 2);
obsPre2  = max(obsMI2(:, tVec<0), [], 2); obsPost2 = max(obsMI2(:, tVec>0), [], 2);
null1 = nan(Nperm, 2, nTfull);
null2 = nan(Nperm, 2, nTfull);
fprintf('\n=== Permutation null test (scheme2, hit/miss MI, Stage1 & Stage2) ===\n');
for p = 1:Nperm
    if mod(p, 25) == 0; fprintf('  perm %d/%d\n', p, Nperm); end
    m1 = nan(nValid, 2, nTfull);
    m2 = nan(nValid, 2, nTfull);
    for i = 1:nValid
        r = resAll{i};
        Xtr = r.Xtr2; beh = r.behTr2; Xte = r.Xte; behTe = r.behTe;
        okB = ~isnan(beh);
        Fb = Xtr(okB, :, :); yb = beh(okB);
        ybp = yb(randperm(numel(yb)));   % shuffle labels (no predictive power)
        for iT = 1:nTfull
            for met = 1:2
                % Stage1 null: CV on shuffled labels
                [~, pp1] = iCvPredict(Fb(:, :, iT), ybp, K, met);
                m1(i, met, iT) = iMIFromLabels(pp1, ybp);
                % Stage2 null: train on shuffled labels, test Transfer (real labels)
                bal = iBalanceTrain(ybp);
                if met == 1
                    [~, pp2] = iLinDecode(Fb(bal,:,iT), ybp(bal), Xte(:,:,iT));
                else
                    [~, pp2] = iGlmDecode(Fb(bal,:,iT), ybp(bal), Xte(:,:,iT));
                end
                m2(i, met, iT) = iMIFromLabels(pp2, behTe);
            end
        end
    end
    null1(p, :, :) = squeeze(mean(m1, 1, 'omitnan'));
    null2(p, :, :) = squeeze(mean(m2, 1, 'omitnan'));
end
for met = 1:2
    if met == 1; metnm = 'linear'; else; metnm = 'glm'; end
    fprintf('  [%s]\n', metnm);
    for st = 1:2
        if st == 1; obsMI = obsMI1; N = null1; OMax=obsMax1; OPre=obsPre1; OPost=obsPost1;
        else;        obsMI = obsMI2; N = null2; OMax=obsMax2; OPre=obsPre2; OPost=obsPost2; end
        pT = zeros(1, nTfull);
        for iT = 1:nTfull
            pT(iT) = (1 + sum(N(:, met, iT) >= obsMI(met, iT))) / (Nperm+1);
        end
        pMax  = (1 + sum(max(N(:, met, :), [], 3) >= OMax(met))) / (Nperm+1);
        pPre  = (1 + sum(max(squeeze(N(:, met, tVec<0)), [], 2) >= OPre(met))) / (Nperm+1);
        pPost = (1 + sum(max(squeeze(N(:, met, tVec>0)), [], 2) >= OPost(met))) / (Nperm+1);
        fprintf('    Stage%d: peak=%.4f | p-any=%.3f p-pre=%.3f p-post=%.3f | nSigTime(p<.05)=%d\n', ...
            st, OMax(met), pMax, pPre, pPost, sum(pT<0.05));
    end
end
% ---- figure: observed MI vs null 95% (Stage1 & Stage2 side-by-side), GLM ----
met = 2;
f = figure('Name','Hit/miss MI permutation null test (scheme2, Stage1 & Stage2, GLM)','Color','w','Position',[60 80 1120 430]);
axP = [];
for st = 1:2
    ax = subplot(1,2,st); hold(ax,'on');
    if st == 1; N = null1; else; N = null2; end
    v = squeeze(miMain(:, met, sc, st, :));   % (mouse, time)
    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color',[0 0 0],'LineWidth',1.6,'MarkerSize',3,'DisplayName','observed MI (glm)');
    null95 = prctile(squeeze(N(:, met, :)), 95, 1);
    plot(ax, tVec, null95, '--', 'Color',[0.65 0.65 0.65],'LineWidth',1.3,'DisplayName','null 95% (glm)');
    sig = mn > null95;
    if any(sig)
        plot(ax, tVec(sig), mn(sig), 'o', 'MarkerSize', 8, 'LineWidth', 1.4, ...
            'Color', [0.75 0.05 0.05], 'MarkerFaceColor', [1 0.35 0.35], 'HandleVisibility','off');
    end
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoded MI (bits)');
    title(ax, sprintf('Stage%d - GLM', st),'FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize = 8;
    axP(end+1) = ax; %#ok<AGROW>
end
% ---- align MI panels to a common y-axis ----
ymaxP = 0;
for k = 1:numel(axP); yl = get(axP(k),'YLim'); ymaxP = max(ymaxP, yl(2)); end
for k = 1:numel(axP); set(axP(k),'YLim',[0 ymaxP]); end

%% 4d. Calibration held-out: scheme2 (AudioWater) decoder on AudioOnly / LightOnly
fprintf('\n=== Calibration held-out (scheme2 decoder): AudioOnly / LightOnly ===\n');
calnames = {'AudioOnly','LightOnly'};
for ci = 1:2
    fprintf('  %s:\n', calnames{ci});
    for met = 1:2
        if met == 1; metnm = 'linear'; else; metnm = 'glm'; end
        vMI = squeeze(miCal(:,met,ci,:)); vB = squeeze(balCal(:,met,ci,:));
        nM = sum(~isnan(vMI(:,1)));
        mMI = mean(vMI,1,'omitnan'); mB = mean(vB,1,'omitnan');
        fprintf('    %-6s MI mean=%.4f peak=%.4f | balacc mean=%.4f peak=%.4f | mice=%d\n', ...
            metnm, mean(mMI), max(mMI), mean(mB), max(mB), nM);
    end
end
% figure: 2x2 = [MI AO, MI LO; tendency AO, tendency LO], GLM only
axCalMI = []; axCalT = [];
met = 2;
f = figure('Name','Hit/miss decoder (AudioWater, GLM) on AudioOnly/LightOnly calib','Color','w','Position',[60 60 1120 860]);
for ci = 1:2
    ax = subplot(2,2,ci); hold(ax,'on');
    vals = squeeze(miCal(:,met,ci,:));
    mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color',[0 0 0],'LineWidth',1.8,'MarkerSize',3,'DisplayName','hit/miss');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoded MI (bits)');
    title(ax, sprintf('%s (calib) - MI', calnames{ci}),'FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize = 8; axCalMI(end+1) = ax; %#ok<AGROW>
end
bcols = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
bnames = {'hit','miss'};
for ci = 1:2
    ax = subplot(2,2,2+ci); hold(ax,'on');
    for b = 1:2
        vals = squeeze(pCal(:,met,ci,b,:));
        if all(isnan(vals(:))); continue; end
        mn = mean(vals,1,'omitnan'); se = std(vals,0,1,'omitnan')/sqrt(sum(~isnan(vals(:,1))));
        if ci == 1; cueW = 'audio'; else; cueW = 'light'; end
        dn = sprintf('%s %s (%d)', cueW, bnames{b}, 2-b);
        errorbar(ax, tVec, mn, se, '-', 'Color',bcols{b},'LineWidth',1.6,'MarkerSize',2,'DisplayName',dn);
    end
    yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Tendency (0-1)');
    title(ax, sprintf('%s (calib) - tendency', calnames{ci}),'FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',6);
    box(ax,'off'); ax.FontSize = 8; axCalT(end+1) = ax; %#ok<AGROW>
end
% align calibration panels
ymaxC = 0;
for k = 1:numel(axCalMI); yl = get(axCalMI(k),'YLim'); ymaxC = max(ymaxC, yl(2)); end
for k = 1:numel(axCalMI); set(axCalMI(k),'YLim',[0 ymaxC]); end
for k = 1:numel(axCalT); set(axCalT(k),'YLim',[0 1]); end

%% 4e. Permutation null test: is calibration held-out MI (scheme2) > chance?
% Null: within each mouse, shuffle the AudioWater hit/miss TRAINING labels, retrain
% the same decoder, decode AudioOnly/LightOnly (REAL labels), recompute MI.
% Same rationale as the Stage1/Stage2 null in 4c. Tests per method & condition:
%   - per-time-point p (uncorrected) + n significant time points (p<0.05)
%   - max-statistic p over ALL / pre-cue (t<0) / post-cue (t>0)
NpermC = 100;
rng(345);
obsCalA = squeeze(mean(miCal(:, :, 1, :), 1, 'omitnan'));   % (method, time)
obsCalL = squeeze(mean(miCal(:, :, 2, :), 1, 'omitnan'));
obsMaxCA = max(obsCalA, [], 2); obsMaxCL = max(obsCalL, [], 2);
obsPreCA  = max(obsCalA(:, tVec<0), [], 2); obsPostCA = max(obsCalA(:, tVec>0), [], 2);
obsPreCL  = max(obsCalL(:, tVec<0), [], 2); obsPostCL = max(obsCalL(:, tVec>0), [], 2);
nullCalA = nan(NpermC, 2, nTfull);
nullCalL = nan(NpermC, 2, nTfull);
fprintf('\n=== Permutation null test (scheme2 decoder, calibration held-out MI) ===\n');
for p = 1:NpermC
    if mod(p, 25) == 0; fprintf('  perm %d/%d\n', p, NpermC); end
    mA = nan(nValid, 2, nTfull);
    mL = nan(nValid, 2, nTfull);
    for i = 1:nValid
        r = resAll{i};
        Xtr = r.Xtr2; beh = r.behTr2;
        okB = ~isnan(beh);
        Fb = Xtr(okB, :, :); yb = beh(okB);
        ybp = yb(randperm(numel(yb)));   % shuffle training labels once per mouse
        for iT = 1:nTfull
            for met = 1:2
                bal = iBalanceTrain(ybp);
                if ~isempty(r.XteA) && ~isempty(r.behTeA)
                    okCa = ~isnan(r.behTeA);
                    if sum(r.behTeA(okCa)==1) >= 2 && sum(r.behTeA(okCa)==0) >= 2
                        if met == 1
                            [~, ppA] = iLinDecode(Fb(bal,:,iT), ybp(bal), r.XteA(okCa,:,iT));
                        else
                            [~, ppA] = iGlmDecode(Fb(bal,:,iT), ybp(bal), r.XteA(okCa,:,iT));
                        end
                        mA(i, met, iT) = iMIFromLabels(ppA, r.behTeA(okCa));
                    end
                end
                if ~isempty(r.XteL) && ~isempty(r.behTeL)
                    okCl = ~isnan(r.behTeL);
                    if sum(r.behTeL(okCl)==1) >= 2 && sum(r.behTeL(okCl)==0) >= 2
                        if met == 1
                            [~, ppL] = iLinDecode(Fb(bal,:,iT), ybp(bal), r.XteL(okCl,:,iT));
                        else
                            [~, ppL] = iGlmDecode(Fb(bal,:,iT), ybp(bal), r.XteL(okCl,:,iT));
                        end
                        mL(i, met, iT) = iMIFromLabels(ppL, r.behTeL(okCl));
                    end
                end
            end
        end
    end
    nullCalA(p, :, :) = squeeze(mean(mA, 1, 'omitnan'));
    nullCalL(p, :, :) = squeeze(mean(mL, 1, 'omitnan'));
end
for met = 1:2
    if met == 1; metnm = 'linear'; else; metnm = 'glm'; end
    fprintf('  [%s]\n', metnm);
    for ci = 1:2
        if ci == 1; obsMI = obsCalA; N = nullCalA; OMax=obsMaxCA; OPre=obsPreCA; OPost=obsPostCA; nm = 'AudioOnly';
        else;       obsMI = obsCalL; N = nullCalL; OMax=obsMaxCL; OPre=obsPreCL; OPost=obsPostCL; nm = 'LightOnly'; end
        nM = sum(~isnan(squeeze(miCal(:,met,ci,1))));
        pT = zeros(1, nTfull);
        for iT = 1:nTfull
            pT(iT) = (1 + sum(N(:, met, iT) >= obsMI(met, iT))) / (NpermC+1);
        end
        pMax  = (1 + sum(max(N(:, met, :), [], 3) >= OMax(met))) / (NpermC+1);
        pPre  = (1 + sum(max(squeeze(N(:, met, tVec<0)), [], 2) >= OPre(met))) / (NpermC+1);
        pPost = (1 + sum(max(squeeze(N(:, met, tVec>0)), [], 2) >= OPost(met))) / (NpermC+1);
        fprintf('    %s: peak=%.4f | p-any=%.3f p-pre=%.3f p-post=%.3f | nSigTime(p<.05)=%d | mice=%d\n', ...
            nm, OMax(met), pMax, pPre, pPost, sum(pT<0.05), nM);
    end
end
% ---- figure: observed vs null 95% (AudioOnly & LightOnly side-by-side), GLM ----
met = 2;
f = figure('Name','Hit/miss calibration MI permutation null test (scheme2, AudioOnly & LightOnly, GLM)','Color','w','Position',[60 80 1120 430]);
axCalP = [];
for ci = 1:2
    ax = subplot(1,2,ci); hold(ax,'on');
    if ci == 1; N = nullCalA; else; N = nullCalL; end
    v = squeeze(miCal(:, met, ci, :));
    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color',[0 0 0],'LineWidth',1.6,'MarkerSize',3,'DisplayName','observed MI (glm)');
    null95 = prctile(squeeze(N(:, met, :)), 95, 1);
    plot(ax, tVec, null95, '--', 'Color',[0.65 0.65 0.65],'LineWidth',1.3,'DisplayName','null 95% (glm)');
    sig = mn > null95;
    if any(sig)
        plot(ax, tVec(sig), mn(sig), 'o', 'MarkerSize', 8, 'LineWidth', 1.4, ...
            'Color', [0.75 0.05 0.05], 'MarkerFaceColor', [1 0.35 0.35], 'HandleVisibility','off');
    end
    xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
    xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoded MI (bits)');
    title(ax, sprintf('%s - GLM', calnames{ci}),'FontSize',9,'FontWeight','normal');
    legend(ax,'Location','northwest','Box','off','FontSize',7);
    box(ax,'off'); ax.FontSize = 8;
    axCalP(end+1) = ax; %#ok<AGROW>
end
ymaxCP = 0;
for k = 1:numel(axCalP); yl = get(axCalP(k),'YLim'); ymaxCP = max(ymaxCP, yl(2)); end
for k = 1:numel(axCalP); set(axCalP(k),'YLim',[0 ymaxCP]); end

%% 4f. Cue-invariance of the choice decoder: does the hit/miss decoder decode cue?
% The scheme2 decoder is trained ONLY on AudioWater hit/miss labels (single cue:
% audio), so by construction it cannot represent cue identity. Test empirically on
% the POOLED AudioOnly+LightOnly calibration data (both cues, both behaviors,
% held-out): does the decoder's output carry cue (audio vs light) information
% beyond behavior? Clean test = within MISS trials (abundant, ~balanced audio/light):
% a pure behavior decoder must give cue|miss MI ~ 0.
fprintf('\n=== Cue-invariance: does the choice (scheme2) decoder decode cue? (pooled AudioOnly+LightOnly calib) ===\n');
% metrics: (mouse, method, time, metric)
%  1 MI(pred,cue) marginal  2 MI(pred,cue|miss)  3 MI(pred,cue|hit)
%  4 MI(pred,behavior) ref  5 balacc(cue)  6 balacc(cue|miss)  7 balacc(behavior)
miCueInv = nan(nValid, 2, nTfull, 7);
for i = 1:nValid
    r = resAll{i};
    if isempty(r.XteA) || isempty(r.XteL); continue; end
    okA = ~isnan(r.behTeA); okL = ~isnan(r.behTeL);
    Fpool = cat(1, r.XteA(okA,:,:), r.XteL(okL,:,:));
    cueP = [zeros(sum(okA),1); ones(sum(okL),1)];
    behP = [r.behTeA(okA); r.behTeL(okL)];
    okv = ~isnan(behP);
    Fpool = Fpool(okv,:,:); cueP = cueP(okv); behP = behP(okv);
    if sum(cueP==0) < 2 || sum(cueP==1) < 2; continue; end
    if sum(behP==0) < 2 || sum(behP==1) < 2; continue; end
    okB = ~isnan(r.behTr2);
    Fb = r.Xtr2(okB,:,:); yb = r.behTr2(okB);
    for iT = 1:nTfull
        for met = 1:2
            bal = iBalanceTrain(yb);
            if met == 1
                [sC, ~] = iLinDecode(Fb(bal,:,iT), yb(bal), Fpool(:,:,iT));
            else
                [sC, ~] = iGlmDecode(Fb(bal,:,iT), yb(bal), Fpool(:,:,iT));
            end
            pC = double(sC >= 0);
            miCueInv(i,met,iT,1) = iMIFromLabels(pC, cueP);
            miCueInv(i,met,iT,4) = iMIFromLabels(pC, behP);
            ms = behP==0;
            if sum(cueP(ms)==0) >= 2 && sum(cueP(ms)==1) >= 2
                miCueInv(i,met,iT,2) = iMIFromLabels(pC(ms), cueP(ms));
                miCueInv(i,met,iT,6) = iBalAcc(pC(ms), cueP(ms));
            end
            hs = behP==1;
            if sum(cueP(hs)==0) >= 2 && sum(cueP(hs)==1) >= 2
                miCueInv(i,met,iT,3) = iMIFromLabels(pC(hs), cueP(hs));
            end
            miCueInv(i,met,iT,5) = iBalAcc(pC, cueP);
            miCueInv(i,met,iT,7) = iBalAcc(pC, behP);
        end
    end
end
qnames = {'cue(marginal)','cue|miss','cue|hit','behavior(ref)'};
for met = 1:2
    if met == 1; metnm = 'linear'; else; metnm = 'glm'; end
    fprintf('  [%s]\n', metnm);
    for q = 1:4
        v = squeeze(miCueInv(:,met,:,q));
        nM = sum(~isnan(v(:,1)));
        mv = mean(v,1,'omitnan');
        fprintf('    %-14s MI mean=%.4f peak=%.4f | mice=%d\n', qnames{q}, mean(mv), max(mv), nM);
    end
    for q = 5:7
        v = squeeze(miCueInv(:,met,:,q));
        mv = mean(v,1,'omitnan');
        if q==5; nm2='balacc cue'; elseif q==6; nm2='balacc cue|miss'; else; nm2='balacc behavior'; end
        fprintf('    %-14s balacc mean=%.3f peak=%.3f\n', nm2, mean(mv), max(mv));
    end
end
% permutation null for cue|miss (clean test): shuffle cue labels within miss trials
NpermQ = 100; rng(567);
obsQM = squeeze(mean(miCueInv(:,:,:,2), 1, 'omitnan'));   % (method,time)
obsQMax = max(obsQM, [], 2);
nullQ = nan(NpermQ, 2, nTfull);
for p = 1:NpermQ
    if mod(p,25)==0; fprintf('  permQ %d/%d\n', p, NpermQ); end
    mq = nan(nValid, 2, nTfull);
    for i = 1:nValid
        r = resAll{i};
        if isempty(r.XteA) || isempty(r.XteL); continue; end
        okA = ~isnan(r.behTeA); okL = ~isnan(r.behTeL);
        Fpool = cat(1, r.XteA(okA,:,:), r.XteL(okL,:,:));
        cueP = [zeros(sum(okA),1); ones(sum(okL),1)];
        behP = [r.behTeA(okA); r.behTeL(okL)];
        okv = ~isnan(behP);
        Fpool = Fpool(okv,:,:); cueP = cueP(okv); behP = behP(okv);
        ms = behP==0;
        if sum(ms) < 8; continue; end
        cm = cueP(ms); cm = cm(randperm(numel(cm)));   % shuffle cue within miss (once per mouse)
        okB = ~isnan(r.behTr2);
        Fb = r.Xtr2(okB,:,:); yb = r.behTr2(okB);
        for iT = 1:nTfull
            for met = 1:2
                bal = iBalanceTrain(yb);
                if met == 1
                    [sC, ~] = iLinDecode(Fb(bal,:,iT), yb(bal), Fpool(:,:,iT));
                else
                    [sC, ~] = iGlmDecode(Fb(bal,:,iT), yb(bal), Fpool(:,:,iT));
                end
                pC = double(sC >= 0);
                if sum(cm==0) >= 2 && sum(cm==1) >= 2
                    mq(i,met,iT) = iMIFromLabels(pC(ms), cm);
                end
            end
        end
    end
    nullQ(p,:,:) = squeeze(mean(mq,1,'omitnan'));
end
for met = 1:2
    if met == 1; metnm='linear'; else; metnm='glm'; end
    pTc = zeros(1,nTfull);
    for iT = 1:nTfull
        pTc(iT) = (1 + sum(nullQ(:,met,iT) >= obsQM(met,iT))) / (NpermQ+1);
    end
    pMaxQ = (1 + sum(max(nullQ(:,met,:),[],3) >= obsQMax(met))) / (NpermQ+1);
    fprintf('  [%s] cue|miss: peak=%.4f | p-any=%.3f | nSigTime(p<.05)=%d\n', metnm, obsQMax(met), pMaxQ, sum(pTc<0.05));
end
% permutation nulls for cue(marginal) and cue|hit: shuffle cue labels within the relevant subset
% cue marginal -> shuffle over ALL pooled trials; cue|hit -> shuffle within HIT trials.
NpermQ2 = 100; rng(678);
obsQMm = squeeze(mean(miCueInv(:,:,:,1), 1, 'omitnan'));   % (method,time) cue marginal
obsQMh = squeeze(mean(miCueInv(:,:,:,3), 1, 'omitnan'));   % cue|hit
obsQMaxm = max(obsQMm, [], 2); obsQMaxh = max(obsQMh, [], 2);
nullQm = nan(NpermQ2, 2, nTfull);
nullQh = nan(NpermQ2, 2, nTfull);
fprintf('  permM/H %d perms (cue marginal & cue|hit)\n', NpermQ2);
for p = 1:NpermQ2
    if mod(p,25)==0; fprintf('    permQ2 %d/%d\n', p, NpermQ2); end
    mm = nan(nValid, 2, nTfull);
    mh = nan(nValid, 2, nTfull);
    for i = 1:nValid
        r = resAll{i};
        if isempty(r.XteA) || isempty(r.XteL); continue; end
        okA = ~isnan(r.behTeA); okL = ~isnan(r.behTeL);
        Fpool = cat(1, r.XteA(okA,:,:), r.XteL(okL,:,:));
        cueP = [zeros(sum(okA),1); ones(sum(okL),1)];
        behP = [r.behTeA(okA); r.behTeL(okL)];
        okv = ~isnan(behP);
        Fpool = Fpool(okv,:,:); cueP = cueP(okv); behP = behP(okv);
        if sum(behP==0) < 2 || sum(behP==1) < 2; continue; end
        hs = behP==1;
        if sum(cueP(hs)==0) < 2 || sum(cueP(hs)==1) < 2; continue; end
        cM = cueP(randperm(numel(cueP)));          % shuffle over all trials
        cH = cueP(hs); cH = cH(randperm(numel(cH))); % shuffle within hit trials
        okB = ~isnan(r.behTr2);
        Fb = r.Xtr2(okB,:,:); yb = r.behTr2(okB);
        for iT = 1:nTfull
            for met = 1:2
                bal = iBalanceTrain(yb);
                if met == 1
                    [sC, ~] = iLinDecode(Fb(bal,:,iT), yb(bal), Fpool(:,:,iT));
                else
                    [sC, ~] = iGlmDecode(Fb(bal,:,iT), yb(bal), Fpool(:,:,iT));
                end
                pC = double(sC >= 0);
                if sum(cM==0) >= 2 && sum(cM==1) >= 2
                    mm(i,met,iT) = iMIFromLabels(pC, cM);
                end
                if sum(cH==0) >= 2 && sum(cH==1) >= 2
                    mh(i,met,iT) = iMIFromLabels(pC(hs), cH);
                end
            end
        end
    end
    nullQm(p,:,:) = squeeze(mean(mm,1,'omitnan'));
    nullQh(p,:,:) = squeeze(mean(mh,1,'omitnan'));
end
for met = 1:2
    if met == 1; metnm='linear'; else; metnm='glm'; end
    pQm = zeros(1,nTfull);
    for iT = 1:nTfull
        pQm(iT) = (1 + sum(nullQm(:,met,iT) >= obsQMm(met,iT))) / (NpermQ2+1);
    end
    pMaxM = (1 + sum(max(nullQm(:,met,:),[],3) >= obsQMaxm(met))) / (NpermQ2+1);
    pQh = zeros(1,nTfull);
    for iT = 1:nTfull
        pQh(iT) = (1 + sum(nullQh(:,met,iT) >= obsQMh(met,iT))) / (NpermQ2+1);
    end
    pMaxH = (1 + sum(max(nullQh(:,met,:),[],3) >= obsQMaxh(met))) / (NpermQ2+1);
    fprintf('  [%s] cue(marginal): peak=%.4f | p-any=%.3f | nSigTime(p<.05)=%d\n', metnm, obsQMaxm(met), pMaxM, sum(pQm<0.05));
    fprintf('  [%s] cue|hit:       peak=%.4f | p-any=%.3f | nSigTime(p<.05)=%d\n', metnm, obsQMaxh(met), pMaxH, sum(pQh<0.05));
end
% figure: MI time courses of the cue-invariance metrics (single panel, GLM).
% For the 3 cue metrics, observed = solid, null 95% = dashed (same color), so the
% cue|hit peak is visually shown to sit below its own null 95% (not above chance).
met = 2;
f = figure('Name','Cue-invariance of choice decoder (scheme2, GLM) on pooled calib','Color','w','Position',[60 80 1120 430]);
qcol = {[0.85 0.33 0.10], [0.10 0.45 0.70], [0.30 0.60 0.30], [0 0 0]};
ax = subplot(1,1,1); hold(ax,'on');
for q = 1:3   % cue metrics with null 95% dashed overlay
    v = squeeze(miCueInv(:,met,:,q));
    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
    errorbar(ax, tVec, mn, se, '-', 'Color',qcol{q},'LineWidth',1.6,'MarkerSize',2,'DisplayName',qnames{q});
    if q==1; Nq = nullQm; elseif q==2; Nq = nullQ; else; Nq = nullQh; end
    n95 = prctile(squeeze(Nq(:,met,:)),95,1);
    plot(ax, tVec, n95, '--', 'Color',qcol{q},'LineWidth',1.0,'HandleVisibility','off');
end
% behavior reference (no cue null)
v = squeeze(miCueInv(:,met,:,4));
mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
errorbar(ax, tVec, mn, se, '-', 'Color',qcol{4},'LineWidth',1.6,'MarkerSize',2,'DisplayName',qnames{4});
xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
xlabel(ax,'Time from stimulus (s)'); ylabel(ax,'Decoded MI (bits)');
title(ax,'Cue-invariance of the choice decoder (GLM); dashed = null 95% (same color)','FontSize',9,'FontWeight','normal');
legend(ax,'Location','northwest','Box','off','FontSize',6);
box(ax,'off'); ax.FontSize = 8;

fprintf('\nDone. Pre-Transfer HIT/MISS decoder complete.\n');

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
    bal = iBalanceTrain(y(tr));
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

function bal = iBalAcc(pred, lab)
a0 = mean(pred(lab==0)==0); a1 = mean(pred(lab==1)==1);
bal = mean([a0, a1], 'omitnan');
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
