%% scratch_Div_CellReuse.m
% 展示 Divergence 与细胞群体复用的关系
%
% 分析框架:
%   Div² = TotalNoise / TotalSignal
%        = (NoiseI + NoiseN) / (SignalI + SignalN)
%
%   如果继承组的 SignalFrac > NoiseFrac, 则继承组是"净信号提供者", 拉低整体Div
%
% 分析内容:
%   A) Div 分解: 继承组的 Signal/Noise/Cell 贡献比
%   B) 消融: 移除继承组后 Div 及其预测力变化
%   C) 相关: 继承组比例/信号贡献 vs Div / HitRate
%   D) 继承组"信号杠杆" = SignalFrac - NoiseFrac → 预测命中率

cd('D:/Users/张天夫/Documents/MATLAB/Transfer-learning');

sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s  = idxCue + sampleRate;

layers = ["All", "MOp2/3", "MOp5"];
layerLabels = ["All", "L2/3", "L5"];
nLay = numel(layers);

%% ===== 加载 ALB 数据 =====
DS = TransferLearning.AudioLightBaseline();
CellTbl = DS.Cells;
CellTbl.ZLayer = string(CellTbl.ZLayer);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);

Ttrans = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Transfer");
Ttrans.Mouse = string(Ttrans.Mouse);
Ttrans.Stimulus = string(Ttrans.Stimulus);
Ttrans = Ttrans(Ttrans.Stimulus == "LightWater", :);
Ttrans.DateTime = datetime(Ttrans.DateTime);
try Ttrans.DateTime.TimeZone = ''; catch, end

TlearnAW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TlearnAW.Mouse = string(TlearnAW.Mouse);
TlearnAW.DateTime = datetime(TlearnAW.DateTime);
try TlearnAW.DateTime.TimeZone = ''; catch, end

trMice = unique(Ttrans.Mouse);
nT = numel(trMice);

%% ===== 逐鼠计算消融和分解指标 =====
% 存储
R = struct();
R.Mouse = strings(nT, 1);
R.HitRate = nan(nT, 1);

% 维度: [mouse, layer]
R.Div_all  = nan(nT, nLay);       % 全细胞 Div
R.Div_noInh = nan(nT, nLay);      % 消融继承后 Div
R.Div_inhOnly = nan(nT, nLay);    % 仅继承组 Div

R.CellFrac_inh  = nan(nT, nLay);  % 继承组细胞数占比
R.SignalFrac_inh = nan(nT, nLay);  % 继承组信号功率占比
R.NoiseFrac_inh  = nan(nT, nLay); % 继承组噪声功率占比
R.Leverage_inh = nan(nT, nLay);   % SignalFrac - NoiseFrac

R.Signal_inh_perCell = nan(nT, nLay); % 继承组每细胞信号功率
R.Signal_non_perCell = nan(nT, nLay); % 非继承组每细胞信号功率
R.Noise_inh_perCell  = nan(nT, nLay);
R.Noise_non_perCell  = nan(nT, nLay);

R.nCells_all = nan(nT, nLay);
R.nCells_inh = nan(nT, nLay);

for i = 1:nT
    m = trMice(i);
    R.Mouse(i) = m;

    Tm = Ttrans(Ttrans.Mouse == m, :);
    dt = min(Tm.DateTime);
    Ts = Tm(Tm.DateTime == dt, :);
    Ts = sortrows(Ts, "TrialIndex");

    beh = double(Ts.Behavior);
    beh = beh(isfinite(beh));
    R.HitRate(i) = mean(beh);

    allUID = unique(uint64(Ts.TrialUID), 'stable');
    if numel(allUID) < 2, continue; end

    ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
    ntsAW = DS.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
    if iscell(ntsLW), ntsLW = ntsLW{1}; end
    if iscell(ntsAW), ntsAW = ntsAW{1}; end
    if isempty(ntsLW), continue; end

    % 继承组定义
    inhUID = uint64([]);
    if ~isempty(ntsAW)
        Ta = TlearnAW(TlearnAW.Mouse == m, :);
        dtA = max(Ta.DateTime);
        Ta = sortrows(Ta(Ta.DateTime == dtA, :), "TrialIndex");
        trialA = unique(uint64(Ta.TrialUID), 'stable');
        [CTT_A, uidA] = iLocalBuildCTT(ntsAW, trialA, sampleRate);
        if ~isempty(CTT_A) && size(CTT_A, 1) >= 3
            ntA = squeeze(mean(CTT_A, 2));
            bsl = ntA(:, 1:24);
            activeA = ntA(:, idx1s) > mean(bsl, 2) + 3 * std(bsl, [], 2);
            inhUID = uidA(activeA);
        end
    end

    % Build CTT for Transfer LW first session
    [CTT, uidLW] = iLocalBuildCTT(ntsLW, allUID, sampleRate);
    if isempty(CTT) || size(CTT, 1) < 3, continue; end

    % Layer info
    mCell = CellTbl(CellTbl.Mouse == m, :);
    [~, loc] = ismember(uidLW, mCell.CellUID);
    cLayers = strings(numel(uidLW), 1);
    cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

    isInh = ismember(uidLW, inhUID);

    for iL = 1:nLay
        if layers(iL) == "All"
            layMask = true(numel(uidLW), 1);
        else
            layMask = cLayers == layers(iL);
        end

        inhMask = layMask & isInh;
        nonMask = layMask & ~isInh;
        allMask = layMask;

        nAll = sum(allMask);
        nInh = sum(inhMask);
        nNon = sum(nonMask);

        if nAll < 3, continue; end

        X = squeeze(CTT(:, :, idx1s));  % Cell × Trial

        % == 全细胞 Div ==
        Xa = X(allMask, :);
        [sigAll, noiseAll, divAll] = iDecompDiv(Xa);
        R.Div_all(i, iL) = divAll;
        R.nCells_all(i, iL) = nAll;
        R.nCells_inh(i, iL) = nInh;

        % == 消融继承组 (仅保留非继承) ==
        if nNon >= 3
            Xn = X(nonMask, :);
            [~, ~, divN] = iDecompDiv(Xn);
            R.Div_noInh(i, iL) = divN;
        end

        % == 仅继承组 ==
        if nInh >= 3
            Xi = X(inhMask, :);
            [~, ~, divI] = iDecompDiv(Xi);
            R.Div_inhOnly(i, iL) = divI;
        end

        % == Div 分解: Signal/Noise 贡献比 ==
        if nInh >= 1 && nNon >= 1
            sigI = sum(mean(X(inhMask, :), 2).^2);
            sigN = sum(mean(X(nonMask, :), 2).^2);
            noI  = sum(var(X(inhMask, :), [], 2));
            noN  = sum(var(X(nonMask, :), [], 2));

            sigTotal = sigI + sigN;
            noTotal  = noI + noN;

            R.CellFrac_inh(i, iL) = nInh / nAll;
            if sigTotal > 0
                R.SignalFrac_inh(i, iL) = sigI / sigTotal;
            end
            if noTotal > 0
                R.NoiseFrac_inh(i, iL) = noI / noTotal;
            end
            R.Leverage_inh(i, iL) = R.SignalFrac_inh(i, iL) - R.NoiseFrac_inh(i, iL);

            % 每细胞平均
            R.Signal_inh_perCell(i, iL) = sigI / nInh;
            R.Signal_non_perCell(i, iL) = sigN / nNon;
            R.Noise_inh_perCell(i, iL)  = noI / nInh;
            R.Noise_non_perCell(i, iL)  = noN / nNon;
        end
    end

    fprintf('Mouse %s: HR=%.3f | CellFrac=%.3f SignFrac=%.3f NoiFrac=%.3f Lev=%.3f | Div all=%.2f noInh=%.2f inh=%.2f\n', ...
        m, R.HitRate(i), R.CellFrac_inh(i,1), R.SignalFrac_inh(i,1), ...
        R.NoiseFrac_inh(i,1), R.Leverage_inh(i,1), ...
        R.Div_all(i,1), R.Div_noInh(i,1), R.Div_inhOnly(i,1));
end

%% ===== Part A: Div 分解 — 继承组在信号和噪声中的比重 =====
fprintf('\n================================================================\n');
fprintf('  Part A: 继承组在 Div 分解中的贡献比\n');
fprintf('================================================================\n');

for iL = 1:nLay
    k = isfinite(R.CellFrac_inh(:, iL));
    n = sum(k);
    if n < 3, continue; end
    fprintf('\n[%s] n=%d\n', layerLabels(iL), n);
    fprintf('  CellFrac  (继承组占比): %.1f%% ± %.1f%%\n', ...
        100*mean(R.CellFrac_inh(k, iL)), 100*std(R.CellFrac_inh(k, iL))/sqrt(n));
    fprintf('  SignalFrac (信号功率占比): %.1f%% ± %.1f%%\n', ...
        100*mean(R.SignalFrac_inh(k, iL)), 100*std(R.SignalFrac_inh(k, iL))/sqrt(n));
    fprintf('  NoiseFrac  (噪声功率占比): %.1f%% ± %.1f%%\n', ...
        100*mean(R.NoiseFrac_inh(k, iL)), 100*std(R.NoiseFrac_inh(k, iL))/sqrt(n));
    fprintf('  Leverage  (Sig-Noi): %+.1f%% ± %.1f%%\n', ...
        100*mean(R.Leverage_inh(k, iL)), 100*std(R.Leverage_inh(k, iL))/sqrt(n));

    % 配对检验: SignalFrac vs CellFrac
    p1 = signrank(R.SignalFrac_inh(k, iL), R.CellFrac_inh(k, iL));
    fprintf('  SignalFrac vs CellFrac: p=%.4g\n', p1);
    % 配对检验: NoiseFrac vs CellFrac
    p2 = signrank(R.NoiseFrac_inh(k, iL), R.CellFrac_inh(k, iL));
    fprintf('  NoiseFrac vs CellFrac: p=%.4g\n', p2);
    % 配对检验: SignalFrac vs NoiseFrac
    p3 = signrank(R.SignalFrac_inh(k, iL), R.NoiseFrac_inh(k, iL));
    fprintf('  SignalFrac vs NoiseFrac: p=%.4g\n', p3);

    % 每细胞信号/噪声比较
    fprintf('\n  每细胞信号功率: Inh = %.4f, Non = %.4f\n', ...
        mean(R.Signal_inh_perCell(k, iL)), mean(R.Signal_non_perCell(k, iL)));
    p4 = signrank(R.Signal_inh_perCell(k, iL), R.Signal_non_perCell(k, iL));
    fprintf('  Inh vs Non per-cell Signal: p=%.4g\n', p4);
    fprintf('  每细胞噪声功率: Inh = %.4f, Non = %.4f\n', ...
        mean(R.Noise_inh_perCell(k, iL)), mean(R.Noise_non_perCell(k, iL)));
    p5 = signrank(R.Noise_inh_perCell(k, iL), R.Noise_non_perCell(k, iL));
    fprintf('  Inh vs Non per-cell Noise: p=%.4g\n', p5);

    % 信号/噪声 ratio per cell
    snr_inh = R.Signal_inh_perCell(k, iL) ./ R.Noise_inh_perCell(k, iL);
    snr_non = R.Signal_non_perCell(k, iL) ./ R.Noise_non_perCell(k, iL);
    fprintf('  每细胞 SNR (Signal/Noise): Inh = %.3f, Non = %.3f\n', ...
        mean(snr_inh), mean(snr_non));
    p6 = signrank(snr_inh, snr_non);
    fprintf('  Inh vs Non per-cell SNR: p=%.4g\n', p6);
end

%% ===== Part B: 消融检验 — 移除继承组后 Div 及预测力变化 =====
fprintf('\n================================================================\n');
fprintf('  Part B: 消融继承组后 Div 变化 + Spearman 预测力变化\n');
fprintf('================================================================\n');

for iL = 1:nLay
    fprintf('\n[%s]\n', layerLabels(iL));

    % Div 变化: all vs noInh (配对)
    k = isfinite(R.Div_all(:, iL)) & isfinite(R.Div_noInh(:, iL));
    n = sum(k);
    if n >= 4
        p = signrank(R.Div_all(k, iL), R.Div_noInh(k, iL));
        fprintf('  Div(all) = %.3f±%.3f vs Div(noInh) = %.3f±%.3f  n=%d  p=%.4g\n', ...
            mean(R.Div_all(k,iL)), std(R.Div_all(k,iL))/sqrt(n), ...
            mean(R.Div_noInh(k,iL)), std(R.Div_noInh(k,iL))/sqrt(n), n, p);
        deltaDiv = R.Div_noInh(k, iL) - R.Div_all(k, iL);
        fprintf('  ΔDiv (noInh - all) = %+.3f±%.3f (正值=消融后Div更高)\n', ...
            mean(deltaDiv), std(deltaDiv)/sqrt(n));
    end

    % Spearman: Div_all vs HitRate
    k1 = isfinite(R.Div_all(:, iL)) & isfinite(R.HitRate);
    if sum(k1) >= 5
        [rho1, p1] = corr(R.Div_all(k1, iL), R.HitRate(k1), 'type', 'Spearman');
        fprintf('  Spearman Div(all) vs HR: ρ=%+.3f p=%.4g n=%d\n', rho1, p1, sum(k1));
    end

    % Spearman: Div_noInh vs HitRate
    k2 = isfinite(R.Div_noInh(:, iL)) & isfinite(R.HitRate);
    if sum(k2) >= 5
        [rho2, p2] = corr(R.Div_noInh(k2, iL), R.HitRate(k2), 'type', 'Spearman');
        fprintf('  Spearman Div(noInh) vs HR: ρ=%+.3f p=%.4g n=%d\n', rho2, p2, sum(k2));
    end

    % Spearman: Div_inhOnly vs HitRate
    k3 = isfinite(R.Div_inhOnly(:, iL)) & isfinite(R.HitRate);
    if sum(k3) >= 5
        [rho3, p3] = corr(R.Div_inhOnly(k3, iL), R.HitRate(k3), 'type', 'Spearman');
        fprintf('  Spearman Div(inhOnly) vs HR: ρ=%+.3f p=%.4g n=%d\n', rho3, p3, sum(k3));
    end
end

%% ===== Part C: 继承组贡献指标 vs Div / HitRate 相关 =====
fprintf('\n================================================================\n');
fprintf('  Part C: 继承组细胞比例 / 信号贡献 vs Div / HitRate\n');
fprintf('================================================================\n');

corrPairs = {
    'CellFrac_inh', 'Div_all', '继承占比 vs Div';
    'CellFrac_inh', 'HitRate', '继承占比 vs HR';
    'SignalFrac_inh', 'Div_all', '信号贡献 vs Div';
    'SignalFrac_inh', 'HitRate', '信号贡献 vs HR';
    'Leverage_inh', 'Div_all', '信号杠杆 vs Div';
    'Leverage_inh', 'HitRate', '信号杠杆 vs HR';
};

for iL = 1:nLay
    fprintf('\n[%s]\n', layerLabels(iL));
    for j = 1:size(corrPairs, 1)
        fX = corrPairs{j, 1};
        fY = corrPairs{j, 2};
        lab = corrPairs{j, 3};

        if strcmp(fY, 'HitRate')
            y = R.HitRate;
        else
            y = R.(fY)(:, iL);
        end
        x = R.(fX)(:, iL);

        k = isfinite(x) & isfinite(y);
        n = sum(k);
        if n < 5, continue; end
        [rho, p] = corr(x(k), y(k), 'type', 'Spearman');
        sig = '';
        if p < 0.05, sig = ' *'; end
        if p < 0.01, sig = ' **'; end
        fprintf('  %s: ρ=%+.3f p=%.4g n=%d%s\n', lab, rho, p, n, sig);
    end
end

%% ===== Part D: 偏 Spearman — Div vs HR 控制继承占比 =====
fprintf('\n================================================================\n');
fprintf('  Part D: 偏相关 — Div vs HitRate 控制继承占比后\n');
fprintf('================================================================\n');

for iL = 1:nLay
    fprintf('\n[%s]\n', layerLabels(iL));
    d = R.Div_all(:, iL);
    h = R.HitRate;
    c = R.CellFrac_inh(:, iL);
    k = isfinite(d) & isfinite(h) & isfinite(c);
    n = sum(k);
    if n < 6, continue; end

    % Full Spearman
    [rho0, p0] = corr(d(k), h(k), 'type', 'Spearman');
    fprintf('  Div vs HR (full): ρ=%+.3f p=%.4g\n', rho0, p0);

    % Partial Spearman: rank-based residualize
    rd = tiedrank(d(k));
    rh = tiedrank(h(k));
    rc = tiedrank(c(k));
    % Residualize rd on rc, rh on rc
    rd_res = rd - rc * (rc \ rd);
    rh_res = rh - rc * (rc \ rh);
    [rhoP, pP] = corr(rd_res, rh_res, 'type', 'Pearson');
    fprintf('  Div vs HR (partial, ctrl CellFrac): ρ=%+.3f p=%.4g\n', rhoP, pP);

    % Also control for SignalFrac
    c2 = R.SignalFrac_inh(:, iL);
    k2 = isfinite(d) & isfinite(h) & isfinite(c2);
    if sum(k2) >= 6
        rd2 = tiedrank(d(k2));
        rh2 = tiedrank(h(k2));
        rc2 = tiedrank(c2(k2));
        rd2_res = rd2 - rc2 * (rc2 \ rd2);
        rh2_res = rh2 - rc2 * (rc2 \ rh2);
        [rhoP2, pP2] = corr(rd2_res, rh2_res, 'type', 'Pearson');
        fprintf('  Div vs HR (partial, ctrl SignalFrac): ρ=%+.3f p=%.4g\n', rhoP2, pP2);
    end
end

%% ===== Part E: ΔDiv (消融效应) vs HitRate =====
fprintf('\n================================================================\n');
fprintf('  Part E: ΔDiv (消融增量) vs HitRate — 消融效应预测行为表现\n');
fprintf('================================================================\n');

for iL = 1:nLay
    fprintf('\n[%s]\n', layerLabels(iL));
    deltaD = R.Div_noInh(:, iL) - R.Div_all(:, iL);
    h = R.HitRate;
    k = isfinite(deltaD) & isfinite(h);
    n = sum(k);
    if n < 5, continue; end
    [rho, p] = corr(deltaD(k), h(k), 'type', 'Spearman');
    sig = '';
    if p < 0.05, sig = ' *'; end
    if p < 0.01, sig = ' **'; end
    fprintf('  ΔDiv(noInh-all) vs HR: ρ=%+.3f p=%.4g n=%d%s\n', rho, p, n, sig);
    fprintf('  方向: ΔDiv>0 = 消融后Div更高 = 继承组曾在拉低Div\n');
    fprintf('  ρ>0 → 继承组拉低Div越多的鼠, HR越高\n');
end

%% ===== local functions =====

function [totalSignal, totalNoise, div] = iDecompDiv(X)
% X: Cell × Trial at a specific time point
signalVec = mean(X, 2);        % per-cell mean across trials
noiseVec  = var(X, [], 2);     % per-cell variance across trials
totalSignal = sum(signalVec.^2);
totalNoise  = sum(noiseVec);
if totalSignal > 0
    div = sqrt(totalNoise / totalSignal);
else
    div = NaN;
end
end

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate)
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs) < 2
    return;
end
inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial, :);
if isempty(nts2), return; end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2, return; end
allC = unique(uint64(nts2.CellUID));
nAllC = numel(allC);
traces = cell(nAllC, 1);
keepU = zeros(nAllC, 1, 'uint64');
nKeep = 0;
for ci = 1:nAllC
    cid = allC(ci);
    rows = (uint64(nts2.CellUID) == cid);
    if sum(rows) < numel(trialUIDs), continue; end
    uid = uint64(nts2.TrialUID(rows));
    sig = double(nts2.TrialSignal(rows, :));
    [tf, loc] = ismember(trialUIDs, uid);
    if ~all(tf), continue; end
    so = sig(loc, :);
    if any(~isfinite(so), 'all'), continue; end
    nKeep = nKeep + 1;
    traces{nKeep} = so;
    keepU(nKeep) = cid;
end
if nKeep < 1, return; end
traces = traces(1:nKeep);
keepU = keepU(1:nKeep);
nTr = size(traces{1}, 1);
nTi = size(traces{1}, 2);
CTT = nan(nKeep, nTr, nTi);
for ci = 1:nKeep
    CTT(ci, :, :) = traces{ci};
end
idx0 = 3 * sampleRate;
CTT = CTT - CTT(:, :, idx0);
cellUIDs = keepU;
end
