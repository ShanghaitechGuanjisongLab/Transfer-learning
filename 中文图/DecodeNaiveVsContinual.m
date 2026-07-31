% 解码分析：Naive vs Continual LightWater 群体活动分类
%
% 对 Naive（初始光水）和 Continual（迁移光水）trial 级钙成像
% 群体活动进行 time-resolved decoding + cross-decoding。
% 使用 PCA 降维 + fitclinear (LASSO) + leave-one-mouse-out CV + 置换检验。
%
% 依赖: UniExp.DataSet, Statistics and Machine Learning Toolbox

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
if exist(prjFile, 'file')
    try, matlab.project.loadProject(prjFile); catch, end
end

%% 0) 参数
winHalf = 2;            % 滑动窗口半宽（采样点）
winStride = 2;          % 窗口步长
sampleRate = 8;
nPc = 50;               % PCA 保留的主成分数
nShuffle = 50;          % 置换检验次数
rng(42);

xs = TransferLearning.Xs;
if ~isduration(xs), xs = seconds(xs); end
xsSec = seconds(xs);
tMask = (xsSec >= -0.5) & (xsSec <= 2);
xsPlot = xsSec(tMask);
nTime = nnz(tMask);
winCenters = 1:winStride:nTime;
nWin = numel(winCenters);

fprintf('=== Naive vs Continual 解码 ===\n');
fprintf('时间 [%.1f,%.1f]s  窗口=%d  步长=%d  %d窗口\n', ...
    xsPlot(1), xsPlot(end), winHalf*2+1, winStride, nWin);
fprintf('PCA=%d  置换=%d次\n', nPc, nShuffle);

%% 1) 加载 trial 级数据
fprintf('--- 加载 Naive LightWater ---\n');
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
[Xn, mn, cn] = iQueryTrialPopulation(LAB, LAI, "Naive", "LightWater", badNaive);

fprintf('--- 加载 Continual LightWater ---\n');
ALB = TransferLearning.AudioLightBaseline();
[Xc, mc, cc] = iQueryTrialPopulation(ALB, [], "Transfer", "LightWater", []);

fprintf('Naive: %d trials, %d cells, %d mice\n', size(Xn,1), size(Xn,2), numel(unique(mn)));
fprintf('Continual: %d trials, %d cells, %d mice\n', size(Xc,1), size(Xc,2), numel(unique(mc)));
if isempty(Xn) || isempty(Xc), error('Decode:NoData','No data'); end

%% 2) 公共细胞 + NaN 填充
common = intersect(cn, cc);
[~,iN] = ismember(common, cn); [~,iC] = ismember(common, cc);
Xn = Xn(:, iN, :); Xc = Xc(:, iC, :);
fprintf('公共细胞: %d\n', numel(common));

% 填充 NaN 为 0（z-score 数据，NaN = 无信号 = 0 变化）
Xn(isnan(Xn)) = 0; Xc(isnan(Xc)) = 0;

% 丢弃在所有时间点都为 0 的 trial（全零 = 无数据）
vn = any(Xn(:, :, 1) ~= 0, 2);
vc = any(Xc(:, :, 1) ~= 0, 2);
Xn = Xn(vn,:,:); Xc = Xc(vc,:,:);
mn = mn(vn); mc = mc(vc);

% 丢弃在所有 trial 中都为零的细胞
nk = any(Xn ~= 0, [1, 3]); ck = any(Xc ~= 0, [1, 3]);
keep = nk(:) & ck(:);
Xn = Xn(:, keep, :); Xc = Xc(:, keep, :);
common = common(keep);
fprintf('有效细胞 (含信号): %d\n', numel(common));

allMice = unique([mn(:); mc(:)]);
nMice = numel(allMice);
fprintf('小鼠: %d\n', nMice);

%% 3) 预计算滑动窗口特征 [nTrials x nCells]
featData = cell(nWin,1);
for iW = 1:nWin
    ct = winCenters(iW); ts = max(1,ct-winHalf); te = min(nTime,ct+winHalf);
    fn = squeeze(mean(Xn(:,:,ts:te),3));
    fc = squeeze(mean(Xc(:,:,ts:te),3));
    s.X = [fn; fc]; s.y = [false(size(fn,1),1); true(size(fc,1),1)];
    s.mouse = [mn(:); mc(:)]; featData{iW} = s;
end

%% 4) PCA 降维 + 滑动窗口解码
fprintf('\n=== 滑动窗口解码 (PCA+LASSO) ===\n');

accWin = nan(nWin,1); pValWin = nan(nWin,1);
shufMn = nan(nWin,1); shufSd = nan(nWin,1);

for iW = 1:nWin
    s = featData{iW};
    % PCA 降维
    nPcActual = min([nPc, size(s.X,1) - 1, size(s.X,2) - 1]);
    if nPcActual < 2, continue; end
    try
        [coeff, ~, ~, ~, ~, mu] = pca(s.X, 'NumComponents', nPcActual);
        Xp = (s.X - mu) * coeff;
    catch
        continue;
    end
    
    accWin(iW) = iLomoCv(Xp, s.y, s.mouse, allMice);
    sa = zeros(nShuffle,1);
    for iS = 1:nShuffle
        sa(iS) = iLomoCv(Xp, s.y(randperm(numel(s.y))), s.mouse, allMice);
    end
    shufMn(iW) = mean(sa); shufSd(iW) = std(sa);
    pValWin(iW) = (nnz(sa >= accWin(iW)) + 1) / (nShuffle + 1);
    if mod(iW,3)==0 || iW==nWin
        fprintf('  Win %d/%d @%.2fs: acc=%.3f p=%.4f\n', ...
            iW, nWin, xsPlot(winCenters(iW)), accWin(iW), pValWin(iW));
    end
end

%% 5) 跨条件解码（0-1s 窗口 + PCA）
fprintf('\n=== 交叉解码 ===\n');
idxPost = (xsPlot >= 0) & (xsPlot <= 1);
fnPost = squeeze(mean(Xn(:,:,idxPost),3));
fcPost = squeeze(mean(Xc(:,:,idxPost),3));

% PCA 降维（数据已无 NaN，被填为 0）
nPcActual = min([nPc, size(fnPost,1)+size(fcPost,1), size(fnPost,2)]) - 1;
[coeffP, ~, ~, ~, ~, muP] = pca([fnPost; fcPost], 'NumComponents', nPcActual);
fnPc = (fnPost - muP) * coeffP;
fcPc = (fcPost - muP) * coeffP;

S = struct('Name',{},'Xtr',{},'ytr',{},'mtr',{},'Xte',{},'yte',{},'mte',{});
S(1).Name='Naive->Naive';   S(1).Xtr=fnPc; S(1).ytr=false(size(fnPc,1),1); S(1).mtr=mn;
                            S(1).Xte=fnPc; S(1).yte=S(1).ytr; S(1).mte=S(1).mtr;
S(2).Name='Cont->Cont';     S(2).Xtr=fcPc; S(2).ytr=true(size(fcPc,1),1); S(2).mtr=mc;
                            S(2).Xte=fcPc; S(2).yte=S(2).ytr; S(2).mte=S(2).mtr;
S(3).Name='Naive->Cont';    S(3).Xtr=fnPc; S(3).ytr=false(size(fnPc,1),1); S(3).mtr=mn;
                            S(3).Xte=fcPc; S(3).yte=true(size(fcPc,1),1); S(3).mte=mc;
S(4).Name='Cont->Naive';    S(4).Xtr=fcPc; S(4).ytr=true(size(fcPc,1),1); S(4).mtr=mc;
                            S(4).Xte=fnPc; S(4).yte=false(size(fnPc,1),1); S(4).mte=mn;

crossNames = strings(4,1);
crossTrAcc = zeros(4,1);
crossTeAcc = zeros(4,1);
crossPVal = zeros(4,1);
crossKappa = zeros(4,1);

for iS = 1:4
    s = S(iS);
    accTr = iLomoCv(s.Xtr, s.ytr, s.mtr, unique(s.mtr));
    try
        mdl = fitclinear(s.Xtr, s.ytr, 'Learner','logistic', ...
            'Regularization','lasso','Lambda',0.01,'Solver','dual');
        pTe = predict(mdl, s.Xte);
    catch
        pTe = false(size(s.yte));
    end
    accTe = mean(pTe == s.yte);
    sa2 = zeros(50,1);
    for iS2 = 1:50
        ysh = s.yte(randperm(numel(s.yte)));
        try, sa2(iS2)=mean(predict(mdl,s.Xte)==ysh); catch, end
    end
    pv = (nnz(sa2 >= accTe) + 1) / 51;
    cm = confusionmat(s.yte, pTe);
    if all(size(cm)==[2,2])
        po=(cm(1,1)+cm(2,2))/sum(cm,'all');
        pe=(sum(cm(1,:))*sum(cm(:,1))+sum(cm(2,:))*sum(cm(:,2)))/sum(cm,'all')^2;
        kp=(po-pe)/(1-pe);
    else, kp=NaN; end
    crossNames(iS)=s.Name; crossTrAcc(iS)=accTr; crossTeAcc(iS)=accTe;
    crossPVal(iS)=pv; crossKappa(iS)=kp;
    fprintf('  %s: train=%.3f test=%.3f p=%.4f k=%.3f\n', s.Name, accTr, accTe, pv, kp);
end

%% 6) 绘图
f = figure('Color','w','Name','Decode Naive vs Continual');
f.Units = 'centimeters'; f.Position(3:4) = [14, 6];
L = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');

ax1 = nexttile(L,1); hold(ax1,'on');
tSec = xsPlot(winCenters);
fill(ax1, [tSec(:); flipud(tSec(:))], [shufMn-shufSd; flipud(shufMn+shufSd)], ...
    [0.7 0.7 0.7], 'FaceAlpha',0.3, 'EdgeColor','none');
plot(ax1, tSec, shufMn, '--', 'Color',[0.5 0.5 0.5], 'LineWidth',1);
plot(ax1, tSec, accWin, 'k-', 'LineWidth',1.5);
sig = pValWin < 0.05 & isfinite(pValWin);
if any(sig), scatter(ax1, tSec(sig), accWin(sig), 15, ...
        'MarkerFaceColor',[0.8 0.2 0.2],'MarkerEdgeColor','none'); end
xline(ax1,0,'--','Color',[0.5 0.5 0.5]); xline(ax1,1,'--','Color',[0.5 0.5 0.5]);
yline(ax1,0.5,':k'); xlabel(ax1,'Time (s)'); ylabel(ax1,'Accuracy');
title(ax1,sprintf('Naive vs Continual (PCA-%d)',nPc));
legend(ax1,{'Shuffle +/-1SD','Shuffle','Accuracy','p<0.05'},'Location','southeast','FontSize',8);
ylim(ax1,[0.3 1]); ax1.FontSize = 10; box(ax1,'on');

ax2 = nexttile(L,2);
clr = [0.6 0.6 0.6; 0.4 0.4 0.4; TransferLearning.NaiveColor; TransferLearning.ContinualColor];
b = bar(ax2, 1:4, crossTeAcc, 'FaceColor','flat');
for iB = 1:4, b.CData(iB,:) = clr(iB,:); end
hold(ax2,'on');
for iB = 1:4
    if crossPVal(iB) < 0.05
        text(ax2,iB,crossTeAcc(iB)+0.02,'*','HorizontalAlignment','center',...
            'FontSize',14,'FontWeight','bold');
    end
end
yline(ax2,0.5,'--k'); ax2.XTick = 1:4; ax2.XTickLabel = crossNames
ax2.XTickLabelRotation = 20; ylabel(ax2,'Test accuracy');
title(ax2,sprintf('Cross-decoding (PCA-%d)',nPc)); ax2.FontSize = 10; box(ax2,'on');

%% 7) 导出
outDir = fullfile('\\Data-Server-2\个人数据', getenv('USERNAME'), char(datetime('now','Format','yyyyMM')));
if ~isfolder(outDir), mkdir(outDir); end
fpath = TransferLearning.ExportStandardFigure(f,2,'DecodeNaiveVsContinual.svg');
fprintf('\n导出: %s\n', fpath);

assignin('base','Decode_AccWin',accWin); assignin('base','Decode_PValWin',pValWin);
assignin('base','Decode_ShufMn',shufMn); assignin('base','Decode_ShufSd',shufSd);
assignin('base','Decode_WinCenters',winCenters); assignin('base','Decode_XsPlot',xsPlot);
assignin('base','Decode_CrossNames',crossNames);
assignin('base','Decode_CrossTrAcc',crossTrAcc);
assignin('base','Decode_CrossTeAcc',crossTeAcc);
assignin('base','Decode_CrossPVal',crossPVal);
assignin('base','Decode_CrossKappa',crossKappaossNames);
assignin('base','Decode_CrossTrAcc',crossTrAcc);
assignin('base','Decode_CrossTeAcc',crossTeAcc);
assignin('base','Decode_CrossPVal',crossPVal);
assignin('base','Decode_CrossKappa',crossKappa);
assignin('base','Decode_Mice',allMice); assignin('base','Decode_NCells',numel(common));

fprintf('\n=== 完成 ===\n细胞 %d  小鼠 %d\n', numel(common), nMice);
if all(isnan(accWin)), fprintf('警告: 所有窗口解码失败\n');
else, [~,mi] = max(accWin,[],'omitnan');
    fprintf('峰值准确率: %.3f @ %.2fs\n', accWin(mi), tSec(mi));
end

%% ===== 局部函数 =====

function acc = iLomoCv(X, y, mouse, allMice)
% Leave-one-mouse-out CV with LASSO logistic regression
pred = false(size(y));
for iM = 1:numel(allMice)
    te = (mouse == allMice(iM)); tr = ~te;
    if nnz(tr) < 10 || nnz(te) < 2, continue; end
    try
        m = fitclinear(X(tr,:), y(tr), 'Learner','logistic', ...
            'Regularization','lasso','Lambda',0.01,'Solver','dual');
        pred(te) = predict(m, X(te,:));
    catch, end
end
acc = mean(pred == y);
end

function [X, mLbl, cUID] = iQueryTrialPopulation(DS1, DS2, ph, stim, excl)
% 查询 trial 级群体活动矩阵 [nTrials × nCells × nTime]
% 允许细胞在部分 trial 缺失（NaN），只丢弃全 NaN 的细胞和 trial。
if nargin < 5, excl = strings(0,1); end
if nargin < 4 || isempty(DS2), DL = {DS1}; else, DL = {DS1, DS2}; end
xsG = TransferLearning.Xs;
if ~isduration(xsG), xsG = seconds(xsG); end
tM = seconds(xsG) >= -0.5 & seconds(xsG) <= 2;
nTp = nnz(tM);
allX = {}; allM = {}; allC = {};
for iD = 1:numel(DL)
    DS = DL{iD};
    try
        nc = DS.QueryNTS(struct('Stimulus',string(stim),'Phase',string(ph)), ...
                UniExp.Flags.ZScore, 1:24);
    catch ME
        warning('QT:NTSfail','DS%d QueryNTS failed: %s', iD, ME.message);
        continue;
    end
    if isempty(nc), continue; end
    if iscell(nc)
        nc = nc(~cellfun(@isempty,nc));
        if isempty(nc), continue; end
        nt = nc{1};
    else
        nt = nc;
    end
    if ~istable(nt) || height(nt)==0, continue; end
    
    cm = DS.Cells(:,["CellUID","Mouse"]);
    cm.CellUID = uint64(cm.CellUID); cm.Mouse = string(cm.Mouse);
    
    au = uint64(nt.CellUID);
    at = uint64(nt.TrialUID);
    
    % TrialSignal 可能有多列（如 TrialSignal + DateTime）
    % 取第一列或名为 TrialSignal 的列
    if any(strcmp(nt.Properties.VariableNames, 'TrialSignal'))
        tsCol = nt.TrialSignal;
    else
        vn = nt.Properties.VariableNames;
        numCols = vn(varfun(@isnumeric, nt, 'OutputFormat','uniform'));
        if isempty(numCols)
            warning('QT:NoNumeric','DS%d: no numeric columns', iD);
            continue;
        end
        tsCol = nt.(numCols{1});
    end
    if istable(tsCol)
        sg = double(table2array(tsCol));
    elseif iscell(tsCol)
        sg = double(cell2mat(tsCol));
    else
        sg = double(tsCol);
    end
    if size(sg,1) ~= numel(au)
        warning('QT:DimMismatch','DS%d: signal rows(%d) != CellUID rows(%d)', ...
            iD, size(sg,1), numel(au));
        continue;
    end
    
    % 排除小鼠
    if ~isempty(excl)
        kr = true(size(au));
        for iE = 1:numel(excl)
            bc = uint64(cm.CellUID(cm.Mouse == string(excl(iE))));
            kr = kr & ~ismember(au, bc);
        end
        au = au(kr); at = at(kr); sg = sg(kr,:);
    end
    if isempty(au), continue; end
    
    % 时间裁剪
    if size(sg,2) > nTp
        if nnz(tM) <= size(sg,2)
            sg = sg(:, tM);
        else
            sg = sg(:, 1:nTp);
        end
    elseif size(sg,2) < nTp
        nTp = size(sg,2);
    end
    
    ut = unique(at);
    uc = unique(au);
    nTr = numel(ut); nCel = numel(uc);
    
    Xp = nan(nTr, nCel, nTp);
    mp = strings(nTr, 1);
    
    for iT = 1:nTr
        tm = at == ut(iT);
        tc = au(tm);
        [~,ci] = ismember(tc, uc);
        ts = sg(tm, :);
        % 鼠标名从第一个匹配的 cell 获取
        fi = find(uint64(cm.CellUID) == tc(1), 1);
        if ~isempty(fi), mp(iT) = cm.Mouse(fi); end
        for iC = 1:numel(ci)
            if ci(iC) > 0 && ci(iC) <= nCel
                Xp(iT, ci(iC), :) = ts(iC, :);
            end
        end
    end
    allX{end+1}=Xp; allM{end+1}=mp; allC{end+1}=uc;
end % iD

if isempty(allX), error('QT:NoData','No QueryNTS data returned for any dataset'); end

% 合并多数据源：取细胞超集（不强制交集），缺失位置为 NaN
if numel(allX) == 1
    X = allX{1}; mLbl = allM{1}; cUID = allC{1};
else
    cU = unique(vertcat(allC{:}));  % 细胞超集（统一为列向量）
    cUID = cU;
    nCel = numel(cU);
    X = []; mLbl = strings(0,1);
    for i = 1:numel(allX)
        [~, ix] = ismember(cU, allC{i});
        Xp = nan(size(allX{i},1), nCel, size(allX{i},3));
        for j = 1:nCel
            if ix(j) > 0
                Xp(:, j, :) = allX{i}(:, ix(j), :);
            end
        end
        X = [X; Xp];
        mLbl = [mLbl; allM{i}];
    end
end

% 只丢弃所有时间点都 NaN 的 trial
vt = any(isfinite(X(:,:,1)), 2);
if nnz(vt) < 2
    error('QT:NoValid','<2 valid trials after NaN filtering (n=%d)', nnz(vt));
end
X = X(vt,:,:); mLbl = mLbl(vt);

% 丢弃在所有 trial 中都 NaN 的细胞
keepCel = any(isfinite(X), 1);
keepCel = squeeze(keepCel(:,:,1)); % [1 x nCel]
X = X(:, keepCel, :); cUID = cUID(keepCel);

fprintf('  iQueryTrialPopulation: %d trials, %d cells\n', size(X,1), numel(cUID));
end

function bm = iFindMiceWithAudioWaterInPhase(DS, ph)
T = DS.TableQuery(["Mouse","BlockUID"], Phase=ph);
if isempty(T), bm = strings(0,1); return; end
tr = DS.Trials; ts = string(tr.Stimulus); tb = uint64(tr.BlockUID);
T.Mouse = string(T.Mouse); bu = uint64(T.BlockUID); mu = unique(T.Mouse);
bd = false(size(mu));
for iM = 1:numel(mu)
    mbu = bu(T.Mouse == mu(iM));
    bd(iM) = any(ts(ismember(tb, mbu)) == "AudioWater");
end
bm = mu(bd);
end
