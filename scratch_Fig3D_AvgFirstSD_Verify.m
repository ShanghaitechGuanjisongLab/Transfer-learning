% 验证：Fig3D 逐会话细胞间SD，会话作为统计单位
% 每个会话：per-cell median z@1s → 筛[-1,1] → SD
% 直接用所有会话SD做 ranksum，不按鼠平均
% Naive: LightAudioBaseline + LAInterspersed
%   - 排除含AudioWater回合的会话（纯LW会话）
%   - 按日期取 Naive~Learned 阶段之间（含missing Phase）
%   - 排除 Recall
%   - 排除首个100%及之后
% Transfer: AudioLightBaseline
%   - 按日期取 Transfer~Final 阶段之间（含missing Phase）
%   - 排除 Recall
%   - 排除首个100%及之后

DS_Transfer = TransferLearning.AudioLightBaseline();
DS_Naive1   = TransferLearning.LightAudioBaseline();
DS_Naive2   = TransferLearning.LAInterspersed();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));
minCells = 3;

% --- Transfer: Transfer→Final, 排除Recall+天花板 ---
sdTransfer = iGroupSD(DS_Transfer, idx1s, minCells, "Transfer", "Final", false);

% --- Naive: Naive→Learned, 排除AudioWater混合会话+Recall+天花板 ---
sdNaive1 = iGroupSD(DS_Naive1, idx1s, minCells, "Naive", "Learned", true);
sdNaive2 = iGroupSD(DS_Naive2, idx1s, minCells, "Naive", "Learned", true);

% Naive = pool两个数据集的会话SD（无需按鼠去重，会话级别）
sdNaive    = [sdNaive1.SD(:); sdNaive2.SD(:)];
mouseNaive = [sdNaive1.Mouse(:); sdNaive2.Mouse(:)];
nMiceNaive = numel(unique(mouseNaive));

fprintf('\n=== Fig3D: 逐会话细胞间SD，会话作为统计单位 ===\n');
fprintf('Naive:    n=%d sessions (%d mice), %.4f +/- %.4f\n', numel(sdNaive), nMiceNaive, mean(sdNaive), std(sdNaive)/sqrt(numel(sdNaive)));
fprintf('Transfer: n=%d sessions (%d mice), %.4f +/- %.4f\n', numel(sdTransfer.SD), numel(unique(sdTransfer.Mouse)), mean(sdTransfer.SD), std(sdTransfer.SD)/sqrt(numel(sdTransfer.SD)));

if numel(sdNaive) >= 2 && numel(sdTransfer.SD) >= 2
    p = ranksum(sdNaive, sdTransfer.SD);
    fprintf('ranksum p = %.4g\n', p);
else
    fprintf('样本量不足\n');
end

% === 线性混合模型 (LME): SD ~ Group + (1|Mouse) ===
lmeTbl = table( ...
    [sdNaive; sdTransfer.SD(:)], ...
    [repmat("Naive", numel(sdNaive), 1); repmat("Transfer", numel(sdTransfer.SD), 1)], ...
    [mouseNaive; sdTransfer.Mouse(:)], ...
    'VariableNames', {'SD','Group','Mouse'});
lmeTbl.Group = categorical(lmeTbl.Group);
lmeTbl.Mouse = categorical(lmeTbl.Mouse);

lme = fitlme(lmeTbl, 'SD ~ Group + (1|Mouse)');
disp(lme);
fprintf('\n--- LME fixed-effect p for Group ---\n');
fe = lme.Coefficients;
disp(fe);

%% ===== Local functions =====

function result = iGroupSD(DS, idx1s, minCells, phaseStart, phaseEnd, excludeAudioWater)
% 逐会话细胞间SD，会话作为统计单位（不按鼠平均）
% 每会话：per-cell median z@1s → 筛[-1,1] → SD
Sess = iLWSessions(DS);

if excludeAudioWater
    Sess = iKeepPureLW(DS, Sess);
end
Sess = iExcludeRecall(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
Sess = iExcludeCeiling(Sess);

if isempty(Sess)
    result = struct('Mouse', string.empty(0,1), 'SD', nan(0,1)); return;
end

allDTs = unique(Sess.DateTime);
q = struct('Stimulus', 'LightWater', 'DateTime', allDTs);
try
    ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
    result = struct('Mouse', string.empty(0,1), 'SD', nan(0,1)); return;
end
if isempty(ntsCell) || isempty(ntsCell{1})
    result = struct('Mouse', string.empty(0,1), 'SD', nan(0,1)); return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID  = uint64(rawTbl.CellUID);
rawTbl.DateTime = datetime(rawTbl.DateTime);
if ~isempty(rawTbl.DateTime.TimeZone), rawTbl.DateTime.TimeZone = ''; end

sig = double(rawTbl.TrialSignal);
if size(sig, 2) < idx1s
    result = struct('Mouse', string.empty(0,1), 'SD', nan(0,1)); return;
end
z1s = sig(:, idx1s);

% 向量化: per-cell per-session median
[G1, cellU, dtU] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

% DateTime → Mouse 映射
Sess.Mouse = string(Sess.Mouse);
dtMouseMap = Sess(:, {'DateTime','Mouse'});
[~, iU] = unique(dtMouseMap.DateTime);
dtMouseMap = dtMouseMap(iU, :);

medTbl = table(cellU, dtU, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
medTbl = innerjoin(medTbl, dtMouseMap, 'Keys', 'DateTime');

% 向量化: per-session SD（筛[-1,1], 至少minCells个有效细胞）
[G2, dtU2, mouseU2] = findgroups(medTbl.DateTime, medTbl.Mouse);
sessSD = splitapply(@(x) iSessSD(x, minCells), medTbl.Med1s, G2);

keep = isfinite(sessSD);
nSess = nnz(keep);
mice  = unique(string(mouseU2(keep)));
fprintf('  %d sessions from %d mice\n', nSess, numel(mice));

result = struct('Mouse', string(mouseU2(keep)), 'SD', sessSD(keep));
end

function s = iSessSD(z, minCells)
z = z(isfinite(z) & z >= -1 & z <= 1);
if numel(z) >= minCells
    s = std(z);
else
    s = NaN;
end
end

function [sdAll, miceAll] = iMergeNaive(r1, r2)
% 合并两个Naive数据集，按鼠名去重（取第一个出现的）
mAll = [r1.Mouse(:); r2.Mouse(:)];
sAll = [r1.SD(:);    r2.SD(:)];
[miceAll, ia] = unique(mAll, 'first');
sdAll = sAll(ia);
end

function Sess = iLWSessions(DS)
blkVars = string(DS.Blocks.Properties.VariableNames);
if ismember("MustWarn", blkVars)
    Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
    Blocks.MustWarn = string(Blocks.MustWarn);
else
    Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
    Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", :);
if isempty(TrLW)
    Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), ...
        'VariableNames', {'Mouse','DateTime','Performance'}); return;
end
[G, bu] = findgroups(TrLW.BlockUID);
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
P = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(P, Blocks, 'Keys', 'BlockUID');
T = T(ismissing(T.MustWarn) | (T.MustWarn == ""), :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
Sess = table(mouse, dt, perf2, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
    rows = find(SessOut.Mouse == m);
    p = double(SessOut.Performance(rows));
    i100 = find(p >= 1 - 1e-12, 1, 'first');
    if ~isempty(i100), remove(rows(i100:end)) = true; end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function SessOut = iKeepPureLW(DS, SessIn)
% 排除含 AudioWater 回合的会话
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", :);
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iExcludeRecall(DS, SessIn)
% 排除 Phase == "Recall" 的会话
SessOut = SessIn;
if isempty(SessOut), return; end
if ~ismember('Phase', DS.DateTimes.Properties.VariableNames), return; end
DT = DS.DateTimes(:, {'DateTime','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Phase = string(DT.Phase);
recallDTs = unique(DT.DateTime(DT.Phase == "Recall"));
if isempty(recallDTs), return; end
SessOut = SessOut(~ismember(SessOut.DateTime, recallDTs), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
% 按日期范围保留：min(phaseStart dates) ~ max(phaseEnd dates)
% 包含该范围内 Phase 为 missing 的会话
SessOut = SessIn;
if isempty(SessOut), return; end
if ~ismember('Phase', DS.DateTimes.Properties.VariableNames), return; end
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
SessOut.Mouse = string(SessOut.Mouse);

mice = unique(SessOut.Mouse);
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
    m = mice(iM);
    dtM = DT(DT.Mouse == m, :);
    startDates = dtM.DateTime(dtM.Phase == string(phaseStart));
    endDates   = dtM.DateTime(dtM.Phase == string(phaseEnd));
    if isempty(startDates) || isempty(endDates), continue; end
    startDT = min(startDates);
    endDT   = max(endDates);
    if ismissing(startDT) || ismissing(endDT), continue; end
    keep = keep | (SessOut.Mouse == m & SessOut.DateTime >= startDT & SessOut.DateTime <= endDT);
end
SessOut = SessOut(keep, :);
end
