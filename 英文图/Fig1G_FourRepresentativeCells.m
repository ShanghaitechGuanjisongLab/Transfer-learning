% 四个代表性细胞信号曲线（Nature风格，单试次）
%
% 严格按 Fig1G 的挑选标准（Learned > Transfer > 两个Naive，
% 峰值和1s处均通过，kSigma=3），各取一条最佳试次。
% 如不足4个则放宽条件增加细胞。
% 2×2 子图布局，四色分条件，参考 Nature 文章 Fig.3 样式
%
% 样式要点（Nature-style）：
%   - 仅保留左/下坐标轴脊线
%   - Arial 字体，7-8pt
%   - 四色区分条件：蓝=Learned, 青=Transfer, 灰=Naive
%   - 纵轴隐藏数值标签
%   - 逐细胞垂直偏移分离，水平对齐cue
%
% Output: \\Data-Server-2\个人数据\杨青宁\202607\Fig1G_FourRepresentativeCells.svg

% --- 0) Project init
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

% --- 1) Load dataset
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -1) & (xsSec < 0);
respMask = (xsSec >= -1) & (xsSec <= 2);
plotMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(plotMask);
kSigma = 3;

% --- 2) Build session/trial index
Tao = DS.TableQuery(["Mouse","DateTime","TrialUID"], Stimulus="AudioOnly");
Tao.Mouse = string(Tao.Mouse); Tao.DateTime = iNormalizeDateTime(Tao.DateTime);
Tlo = DS.TableQuery(["Mouse","DateTime","TrialUID"], Stimulus="LightOnly");
Tlo.Mouse = string(Tlo.Mouse); Tlo.DateTime = iNormalizeDateTime(Tlo.DateTime);
Tlearned = DS.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Learned", Stimulus="AudioWater");
Tlearned.Mouse = string(Tlearned.Mouse); Tlearned.DateTime = iNormalizeDateTime(Tlearned.DateTime);
Ttrans = DS.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Transfer", Stimulus="LightWater");
Ttrans.Mouse = string(Ttrans.Mouse); Ttrans.DateTime = iNormalizeDateTime(Ttrans.DateTime);

dtAoT = groupsummary(Tao, "Mouse", "min", "DateTime"); dtAoT.Properties.VariableNames{end}='DateTimeAO';
dtLoT = groupsummary(Tlo, "Mouse", "min", "DateTime"); dtLoT.Properties.VariableNames{end}='DateTimeLO';
dtLearnedT = groupsummary(Tlearned, "Mouse", "max", "DateTime"); dtLearnedT.Properties.VariableNames{end}='DateTimeLearned';
dtTransT = groupsummary(Ttrans, "Mouse", "min", "DateTime"); dtTransT.Properties.VariableNames{end}='DateTimeTransfer';

Sess = innerjoin(dtAoT(:,["Mouse","DateTimeAO"]), dtLoT(:,["Mouse","DateTimeLO"]), 'Keys','Mouse');
Sess = innerjoin(Sess, dtLearnedT(:,["Mouse","DateTimeLearned"]), 'Keys','Mouse');
Sess = innerjoin(Sess, dtTransT(:,["Mouse","DateTimeTransfer"]), 'Keys','Mouse');

aoJoin = innerjoin(Tao, Sess(:,["Mouse","DateTimeAO"]), 'Keys','Mouse');
aoJoin = aoJoin(aoJoin.DateTime==aoJoin.DateTimeAO,:);
[~,mkAO]=findgroups(aoJoin.Mouse); trialAO=splitapply(@(x){uint64(x)},uint64(aoJoin.TrialUID),findgroups(aoJoin.Mouse));
aoTrialsT=table(mkAO,trialAO,'VariableNames',["Mouse","TrialUIDAO"]);

loJoin = innerjoin(Tlo, Sess(:,["Mouse","DateTimeLO"]), 'Keys','Mouse');
loJoin = loJoin(loJoin.DateTime==loJoin.DateTimeLO,:);
[~,mkLO]=findgroups(loJoin.Mouse); trialLO=splitapply(@(x){uint64(x)},uint64(loJoin.TrialUID),findgroups(loJoin.Mouse));
loTrialsT=table(mkLO,trialLO,'VariableNames',["Mouse","TrialUIDLO"]);

learnedJoin = innerjoin(Tlearned, Sess(:,["Mouse","DateTimeLearned"]), 'Keys','Mouse');
learnedJoin = learnedJoin(learnedJoin.DateTime==learnedJoin.DateTimeLearned,:);
[~,mkL]=findgroups(learnedJoin.Mouse); trialLearned=splitapply(@(x){uint64(x)},uint64(learnedJoin.TrialUID),findgroups(learnedJoin.Mouse));
learnedTrialsT=table(mkL,trialLearned,'VariableNames',["Mouse","TrialUIDLearned"]);

transJoin = innerjoin(Ttrans, Sess(:,["Mouse","DateTimeTransfer"]), 'Keys','Mouse');
transJoin = transJoin(transJoin.DateTime==transJoin.DateTimeTransfer,:);
[~,mkT]=findgroups(transJoin.Mouse); trialTrans=splitapply(@(x){uint64(x)},uint64(transJoin.TrialUID),findgroups(transJoin.Mouse));
transTrialsT=table(mkT,trialTrans,'VariableNames',["Mouse","TrialUIDTrans"]);

Sess = innerjoin(Sess, aoTrialsT, 'Keys','Mouse');
Sess = innerjoin(Sess, loTrialsT, 'Keys','Mouse');
Sess = innerjoin(Sess, learnedTrialsT, 'Keys','Mouse');
Sess = innerjoin(Sess, transTrialsT, 'Keys','Mouse');

Cmeta = DS.Cells(:,["CellUID","Mouse"]); Cmeta.Mouse = string(Cmeta.Mouse);
Ts = DS.TrialSignals;

% --- 3) Collect qualifying cells — exact Fig1G strict single-trial criteria
allCandidates = struct('CellUID',{}, 'Mouse',{}, 'Score',{}, ...
    'Sig_AO',{}, 'Sig_LO',{}, 'Sig_Learned',{}, 'Sig_Trans',{});

for iS = 1:height(Sess)
    m = Sess.Mouse(iS);
    aoUIDs = Sess.TrialUIDAO{iS};
    loUIDs = Sess.TrialUIDLO{iS};
    learnedUIDs = Sess.TrialUIDLearned{iS};
    transUIDs = Sess.TrialUIDTrans{iS};
    cellUIDs = uint64(Cmeta.CellUID(Cmeta.Mouse == m));
    if isempty(cellUIDs), continue; end
    
    for iC = 1:numel(cellUIDs)
        cid = cellUIDs(iC);
        [Sao, Slo, Slearned, Strans] = iGetSignals4Cond(Ts, cid, aoUIDs, loUIDs, learnedUIDs, transUIDs);
        if isempty(Sao)||isempty(Slo)||isempty(Slearned)||isempty(Strans), continue; end
        
        Zao = iZScoreByBaseline(Sao, baseMask);
        Zlo = iZScoreByBaseline(Slo, baseMask);
        Zlearned = iZScoreByBaseline(Slearned, baseMask);
        Ztrans = iZScoreByBaseline(Strans, baseMask);
        [~, idx1s] = min(abs(xsSec - 1));
        
        % Cell-level filter (median across trials): Learned > Transfer > both Naive
        pkAO = max(median(Zao(:,respMask),1,'omitnan'),[],'omitnan');
        pkLO = max(median(Zlo(:,respMask),1,'omitnan'),[],'omitnan');
        pkLearned = max(median(Zlearned(:,respMask),1,'omitnan'),[],'omitnan');
        pkTrans = max(median(Ztrans(:,respMask),1,'omitnan'),[],'omitnan');
        if ~isfinite(pkAO)||~isfinite(pkLO)||~isfinite(pkLearned)||~isfinite(pkTrans), continue; end
        if pkLearned <= pkTrans || pkTrans <= pkAO || pkTrans <= pkLO, continue; end
        
        learnedAt1s = median(Zlearned(:,idx1s),'omitnan');
        transAt1s = median(Ztrans(:,idx1s),'omitnan');
        aoAt1s = median(Zao(:,idx1s),'omitnan');
        loAt1s = median(Zlo(:,idx1s),'omitnan');
        if ~isfinite(learnedAt1s)||~isfinite(transAt1s)||~isfinite(aoAt1s)||~isfinite(loAt1s), continue; end
        if learnedAt1s<=transAt1s||transAt1s<=aoAt1s||transAt1s<=loAt1s, continue; end
        if learnedAt1s<=kSigma||transAt1s<=kSigma, continue; end
        
        % Best single-trial combo search (exact Fig1G logic)
        sc = pkLearned - max(pkAO, pkLO);
        pkPerTrialL = max(Zlearned(:,respMask),[],2,'omitnan');
        pkPerTrialT = max(Ztrans(:,respMask),[],2,'omitnan');
        pkPerTrialA = max(Zao(:,respMask),[],2,'omitnan');
        pkPerTrialO = max(Zlo(:,respMask),[],2,'omitnan');
        v1s_L = Zlearned(:,idx1s);
        v1s_T = Ztrans(:,idx1s);
        v1s_A = Zao(:,idx1s);
        v1s_O = Zlo(:,idx1s);
        
        bestComboScore = -inf; bestCombo = [];
        for iL = 1:size(Zlearned,1)
            if ~isfinite(pkPerTrialL(iL))||~isfinite(v1s_L(iL))||v1s_L(iL)<=kSigma, continue; end
            for iT = 1:size(Ztrans,1)
                if ~isfinite(pkPerTrialT(iT))||~isfinite(v1s_T(iT))||v1s_T(iT)<=kSigma, continue; end
                if pkPerTrialL(iL)<=pkPerTrialT(iT)||v1s_L(iL)<=v1s_T(iT), continue; end
                for iA = 1:size(Zao,1)
                    if ~isfinite(pkPerTrialA(iA))||~isfinite(v1s_A(iA)), continue; end
                    if pkPerTrialT(iT)<=pkPerTrialA(iA)||v1s_T(iT)<=v1s_A(iA), continue; end
                    for iO = 1:size(Zlo,1)
                        if ~isfinite(pkPerTrialO(iO))||~isfinite(v1s_O(iO)), continue; end
                        if pkPerTrialT(iT)<=pkPerTrialO(iO)||v1s_T(iT)<=v1s_O(iO), continue; end
                        cs = v1s_L(iL) - max(v1s_A(iA),v1s_O(iO));
                        if cs > bestComboScore
                            bestComboScore = cs; bestCombo = [iL,iT,iA,iO];
                        end
                    end
                end
            end
        end
        if isempty(bestCombo), continue; end
        
        idx = numel(allCandidates) + 1;
        allCandidates(idx).CellUID = cid;
        allCandidates(idx).Mouse = m;
        allCandidates(idx).Score = sc;
        allCandidates(idx).Sig_AO = Zao(bestCombo(3), :);
        allCandidates(idx).Sig_LO = Zlo(bestCombo(4), :);
        allCandidates(idx).Sig_Learned = Zlearned(bestCombo(1), :);
        allCandidates(idx).Sig_Trans = Ztrans(bestCombo(2), :);
    end
end

if numel(allCandidates) < 4
    warning('Only %d cells passed strict Fig1G criteria. Need 4.', numel(allCandidates));
    % Relaxation: collect more cells with L>1>T criteria (single-trial for all 4)
    for iS = 1:height(Sess)
        m = Sess.Mouse(iS);
        aoUIDs = Sess.TrialUIDAO{iS};
        loUIDs = Sess.TrialUIDLO{iS};
        learnedUIDs = Sess.TrialUIDLearned{iS};
        transUIDs = Sess.TrialUIDTrans{iS};
        cellUIDs = uint64(Cmeta.CellUID(Cmeta.Mouse == m));
        if isempty(cellUIDs), continue; end
        for iC = 1:numel(cellUIDs)
            cid = cellUIDs(iC);
            if any([allCandidates.CellUID] == cid), continue; end
            [Sao,Slo,Slearned,Strans] = iGetSignals4Cond(Ts,cid,aoUIDs,loUIDs,learnedUIDs,transUIDs);
            if isempty(Sao)||isempty(Slo)||isempty(Slearned)||isempty(Strans), continue; end
            Zao = iZScoreByBaseline(Sao,baseMask);
            Zlo = iZScoreByBaseline(Slo,baseMask);
            Zlearned = iZScoreByBaseline(Slearned,baseMask);
            Ztrans = iZScoreByBaseline(Strans,baseMask);
            [~,idx1s]=min(abs(xsSec-1));
            % Find any single trial where Learned > Transfer, both active,
            % Transfer > both Naive at 1s
            bestS=-inf; bestI=[];
            for iL=1:size(Zlearned,1)
                if Zlearned(iL,idx1s)<=kSigma, continue; end
                for iT=1:size(Ztrans,1)
                    if Ztrans(iT,idx1s)<=2, continue; end
                    if Zlearned(iL,idx1s)<=Ztrans(iT,idx1s), continue; end
                    for iA=1:size(Zao,1)
                        if Ztrans(iT,idx1s)<=Zao(iA,idx1s), continue; end
                        for iO=1:size(Zlo,1)
                            if Ztrans(iT,idx1s)<=Zlo(iO,idx1s), continue; end
                            cs=Zlearned(iL,idx1s)-max(Zao(iA,idx1s),Zlo(iO,idx1s));
                            if cs>bestS
                                bestS=cs; bestI=[iL,iT,iA,iO];
                            end
                        end
                    end
                end
            end
            if isempty(bestI), continue; end
            idx=numel(allCandidates)+1;
            allCandidates(idx).CellUID=cid;
            allCandidates(idx).Mouse=m;
            allCandidates(idx).Score=bestS;
            allCandidates(idx).Sig_AO=Zao(bestI(3),:);
            allCandidates(idx).Sig_LO=Zlo(bestI(4),:);
            allCandidates(idx).Sig_Learned=Zlearned(bestI(1),:);
            allCandidates(idx).Sig_Trans=Ztrans(bestI(2),:);
            if numel(allCandidates)>=4, break; end
        end
        if numel(allCandidates)>=4, break; end
    end
end

if isempty(allCandidates)
    error('No cells found satisfying criteria.');
end

% Sort by score, pick top 4
scores = [allCandidates.Score];
[~, sortIdx] = sort(scores, 'descend');
nPick = min(4, numel(allCandidates));
pickIdx = sortIdx(1:nPick);
picked = allCandidates(pickIdx);

fprintf('Selected %d cells (Fig1G single-trial criteria):\n', nPick);
for i = 1:nPick
    fprintf('  %d. Mouse=%s, CellUID=%d, Score=%.2f\n', i, picked(i).Mouse, picked(i).CellUID, picked(i).Score);
end

% --- 4) Prepare signals & compute offsets per cell
% Nature-style color palette
%   Learned (AudioWater) — deep blue
%   Transfer (LightWater) — teal
%   AudioOnly — dark grey
%   LightOnly — light grey
colorLearned = [0.06 0.30 0.57]; % #0F4D92
colorTrans   = [0.26 0.58 0.62]; % #42949E
colorAO      = [0.35 0.35 0.35]; % dark grey  — AudioOnly
colorLO      = [0.70 0.70 0.70]; % light grey — LightOnly

gap = 1.5; % separation between traces within a subplot

% Pre-compute shifted signals for each cell
cellData = struct('SigAO_shift',{}, 'SigLO_shift',{}, 'SigLearned_shift',{}, 'SigTrans_shift',{}, ...
    'yLim',{}, 'CellUID',{}, 'Mouse',{});

for i = 1:nPick
    c = picked(i);
    SigAO = c.Sig_AO(plotMask);
    SigLO = c.Sig_LO(plotMask);
    SigLearned = c.Sig_Learned(plotMask);
    SigTrans = c.Sig_Trans(plotMask);
    
    % Order from top to bottom: Learned, Transfer, AO, LO
    % Offset: Learned highest, then Transfer, then AO, then LO at baseline 0
    maxTrans = max(SigTrans, [], 'omitnan');
    minLearned = min(SigLearned, [], 'omitnan');
    offsetTrans = 0;
    offsetLearned = (maxTrans - minLearned) + gap;
    
    % AO below Trans
    maxAO = max(SigAO, [], 'omitnan');
    minTrans = min(SigTrans, [], 'omitnan');
    offsetAO = offsetTrans - (maxAO - minTrans) - gap;
    
    % LO below AO
    maxLO = max(SigLO, [], 'omitnan');
    minAO_sub = min(SigAO, [], 'omitnan');
    offsetLO = offsetAO - (maxLO - minAO_sub) - gap;
    
    % Store shifted signals
    cellData(i).SigLearned_shift = SigLearned + offsetLearned;
    cellData(i).SigTrans_shift   = SigTrans + offsetTrans;
    cellData(i).SigAO_shift      = SigAO + offsetAO;
    cellData(i).SigLO_shift      = SigLO + offsetLO;
    cellData(i).CellUID = c.CellUID;
    cellData(i).Mouse = c.Mouse;
    
    % Y limits with padding
    allY = [cellData(i).SigLearned_shift, cellData(i).SigTrans_shift, ...
            cellData(i).SigAO_shift, cellData(i).SigLO_shift];
    yPad = 0.3 * range(allY, 'all');
    cellData(i).yLim = [min(allY, [], 'all') - yPad, max(allY, [], 'all') + yPad];
end

% Unify y-limits across all cells so the z-score scale bar is visually identical
allYlims = vertcat(cellData.yLim);
commonYlim = [min(allYlims(:,1)), max(allYlims(:,2))];
for i = 1:nPick
    cellData(i).yLim = commonYlim;
end

% --- 5) Plot — Nature-style 2×2 grid
f = figure('Color', 'w', 'Name', 'Fig1G Four Representative Cells');
f.Units = 'centimeters';
f.Position(3:4) = [8.5, 8.5]; % 85mm × 85mm square

TL = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

panelLabels = {'a', 'b', 'c', 'd'};

for i = 1:nPick
    ax = nexttile(TL);
    hold(ax, 'on');
    
    % Plot — LO first (backmost), then AO, Trans, Learned (frontmost)
    hLO = plot(ax, xsPlot, cellData(i).SigLO_shift,      'Color', colorLO,      'LineWidth', 0.7);
    hAO = plot(ax, xsPlot, cellData(i).SigAO_shift,      'Color', colorAO,      'LineWidth', 0.7);
    pTrans = plot(ax, xsPlot, cellData(i).SigTrans_shift,    'Color', colorTrans,    'LineWidth', 0.9);
    pLearned = plot(ax, xsPlot, cellData(i).SigLearned_shift, 'Color', colorLearned,  'LineWidth', 0.9);
    
    % Vertical lines: cue at 0, water at 1
    xline(ax, 0, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.4);
    xline(ax, 1, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.4);
    
    xlim(ax, [-1, 2]);
    ylim(ax, cellData(i).yLim);
    
    % Hide all axes — L-shaped scale bars instead
    ax.Visible = 'off';
    ax.XColor = 'none';
    ax.YColor = 'none';
    ax.Box = 'off';
    
    % Panel label
    text(ax, -0.08, 1.02, panelLabels{i}, 'Units', 'normalized', ...
        'FontName', 'Arial', 'FontSize', 8, 'FontWeight', 'bold');
    
    % Cell ID in top-right corner
    text(ax, 0.98, 0.98, sprintf('#%u', cellData(i).CellUID), 'Units', 'normalized', ...
        'FontName', 'Arial', 'FontSize', 6, 'Color', [0.5 0.5 0.5], ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'cap');
    
    % — L-shaped scale bars (data coordinates, bottom-right corner)
    yL = cellData(i).yLim;
    xR = 2; % right edge of plot
    
    % Horizontal scale bar (0.5 s) at bottom-right
    tBarLen = 0.5; % 0.5 second
    tBarX = [xR - tBarLen, xR];
    tBarY = yL(1) + 0.08 * diff(yL); % inset from bottom
    line(ax, tBarX, [tBarY, tBarY], 'Color', 'k', 'LineWidth', 1.0, 'Clipping', 'off');
    text(ax, mean(tBarX), tBarY, '0.5 s', 'FontName', 'Arial', 'FontSize', 6, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    
    % Vertical scale bar (10 z) anchored at same corner
    zStep = 10; % fixed z-score step across all cells
    vBarX = xR;
    vBarY0 = tBarY;
    vBarY1 = tBarY + zStep;
    line(ax, [vBarX, vBarX], [vBarY0, vBarY1], 'Color', 'k', 'LineWidth', 1.0, 'Clipping', 'off');
    text(ax, vBarX + 0.03*diff(xlim(ax)), mean([vBarY0, vBarY1]), '10 z', ...
        'FontName', 'Arial', 'FontSize', 6, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
    
    try ax.Toolbar.Visible = 'off'; catch, end
end

% Shared legend (using last axis handles, placed below grid)
L = legend([pLearned, pTrans, hAO, hLO], ...
    'Learned (A→W)', 'Transfer (L→W)', 'Naive (A-only)', 'Naive (L-only)', ...
    'Location', 'southoutside', 'NumColumns', 2, 'Box', 'off', ...
    'FontName', 'Arial', 'FontSize', 6);
L.ItemTokenSize = [12 4];

% --- 6) Export
svgName = "Fig1G_FourRepresentativeCells.svg";
try
    svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
    fprintf('Exported: %s\n', svgPath);
catch ME
    warning(ME.identifier, 'ExportStandardFigure failed: %s', ME.message);
    try
        svgPath = fullfile('\\Data-Server-2\个人数据\杨青宁\202607', svgName);
        if ~isfolder(fileparts(svgPath)), mkdir(fileparts(svgPath)); end
        saveas(f, svgPath, 'svg');
        fprintf('Fallback wrote: %s\n', svgPath);
    catch ME2
        warning(ME2.identifier, 'Fallback also failed: %s', ME2.message);
    end
end

assignin('base', 'Fig1G_FourCells', picked);

%% --- Local helpers
function dt = iNormalizeDateTime(dt)
dt = datetime(dt); dt.TimeZone = '';
end

function [S0,S1,S2,S3] = iGetSignals4Cond(Ts, cellUID, tu0, tu1, tu2, tu3)
cellUID = uint64(cellUID);
tu0 = uint64(tu0(:)); tu1 = uint64(tu1(:)); tu2 = uint64(tu2(:)); tu3 = uint64(tu3(:));
allUID = unique([tu0; tu1; tu2; tu3]);
mask = (uint64(Ts.CellUID) == cellUID) & ismember(uint64(Ts.TrialUID), allUID);
if ~any(mask); S0=[];S1=[];S2=[];S3=[]; return; end
uid = uint64(Ts.TrialUID(mask));
sig = double(Ts.ResampledSignal(mask,:));
S0 = sig(ismember(uid,tu0),:);
S1 = sig(ismember(uid,tu1),:);
S2 = sig(ismember(uid,tu2),:);
S3 = sig(ismember(uid,tu3),:);
end

function Z = iZScoreByBaseline(S, baseMask)
mu = mean(S(:,baseMask),2,'omitnan');
sd = std(S(:,baseMask),0,2,'omitnan');
sd(sd<eps)=1;
Z = (S-mu)./sd;
end
