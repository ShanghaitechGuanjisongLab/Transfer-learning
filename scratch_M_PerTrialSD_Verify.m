% 验证：逐回合计算细胞间SD，再平均所有回合作为鼠的代表值
% QueryNTS without Median returns per-trial z-scored data: G{1} is table
%   with CellUID, TrialUID, TrialSignal (nCells*nTrials × nTime)
% For each trial: extract cells' z-score at idx1s, filter [-1,1], compute SD
% Average all trials across sessions → per-mouse SD

DS_Naive    = TransferLearning.LightAudioBaseline();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));

cohorts = {DS_Naive, "Naive", "Learned"; DS_Transfer, "Transfer", "Final"};
sdPerTrialAll = nan(0,1);
slopeAll      = nan(0,1);
groupAll      = string.empty(0,1);

for iC = 1:2
    DS         = cohorts{iC,1};
    phaseStart = cohorts{iC,2};
    phaseEnd   = cohorts{iC,3};

    Sess = iLW(DS);
    Sess = iPhase(DS, Sess, phaseStart, phaseEnd);
    if isempty(Sess), continue; end
    Sess = sortrows(Sess, {'Mouse','DateTime'});
    mice = unique(string(Sess.Mouse));

    for iM = 1:numel(mice)
        m = mice(iM);
        R = sortrows(Sess(string(Sess.Mouse)==m,:), 'DateTime');

        % 排除首次100%及之后
        first100 = find(double(R.Performance) >= 1.0, 1, 'first');
        if ~isempty(first100)
            if first100 == 1, continue; end
            R = R(1:first100-1,:);
        end
        n = height(R);
        if n < 2, continue; end

        % 学习斜率
        yi = double(R.Performance);
        ok = isfinite(yi);
        if nnz(ok) < 2, continue; end
        xi_ok = (1:n)'; xi_ok = xi_ok(ok);
        pFit = polyfit(xi_ok, yi(ok), 1);
        slope = pFit(1);

        % 逐回合算细胞间SD@1s（z-scored via QueryNTS without Median）
        allTrialSDs = nan(0,1);
        for iS = 1:n
            dt = R.DateTime(iS);
            try
                Tdes = DS.TableQuery(["DateTime","Design"], DateTime=dt, Stimulus="LightWater");
                des  = unique(string(Tdes.Design)); des = des(~ismissing(des));
                if numel(des) ~= 1, continue; end
                Graw = DS.QueryNTS(struct('DateTime',dt,'Stimulus','LightWater','Design',char(des(1))), ...
                    UniExp.Flags.ZScore, 1:24);
                if isempty(Graw) || isempty(Graw{1}), continue; end
                tbl = Graw{1};  % CellUID, TrialUID, TrialSignal [nRows × nTime]
                sig = double(tbl.TrialSignal);
                if size(sig,2) < idx1s, continue; end
                col1s = sig(:, idx1s);
                tbl.v1s = col1s;
            catch
                continue;
            end

            trials = unique(uint64(tbl.TrialUID));
            for iT = 1:numel(trials)
                mask  = uint64(tbl.TrialUID) == trials(iT);
                zvals = tbl.v1s(mask);
                zvals = zvals(isfinite(zvals) & zvals >= -1 & zvals <= 1);
                if numel(zvals) >= 3
                    allTrialSDs(end+1, 1) = std(zvals);
                end
            end
        end

        if ~isempty(allTrialSDs)
            sdPerTrialAll(end+1, 1) = mean(allTrialSDs);
            slopeAll(end+1, 1)      = slope;
            groupAll(end+1, 1)      = string(cohorts{iC,2});
        end
    end
end

use = isfinite(sdPerTrialAll) & isfinite(slopeAll);
fprintf('\n=== 验证：逐回合细胞间SD → 平均后与学习斜率 Spearman ===\n');
fprintf('n mice = %d\n', nnz(use));
if nnz(use) >= 3
    [rho, p] = corr(sdPerTrialAll(use), slopeAll(use), 'Type', 'Spearman');
    fprintf('Spearman rho=%.3f, p=%.4g\n', rho, p);
    fprintf('Naive:    n=%d, SD mean=%.4f, slope mean=%.4f\n', ...
        nnz(use & groupAll=="Naive"), mean(sdPerTrialAll(use & groupAll=="Naive")), mean(slopeAll(use & groupAll=="Naive")));
    fprintf('Transfer: n=%d, SD mean=%.4f, slope mean=%.4f\n', ...
        nnz(use & groupAll=="Transfer"), mean(sdPerTrialAll(use & groupAll=="Transfer")), mean(slopeAll(use & groupAll=="Transfer")));
else
    fprintf('样本量不足，无法计算相关\n');
end

%% ===== Local functions =====

function Sess = iLW(DS)
Blocks = DS.Blocks(:,{'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
Blocks.MustWarn = string(Blocks.MustWarn);
DT = DS.DateTimes(:,{'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
Tr = DS.Trials(:,{'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus)=="LightWater",:);
if isempty(TrLW)
    Sess = table(string.empty(0,1),NaT(0,1),nan(0,1),'VariableNames',{'Mouse','DateTime','Performance'});
    return;
end
[G,bu] = findgroups(TrLW.BlockUID);
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
P = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T2 = innerjoin(P, Blocks, 'Keys','BlockUID');
T2 = T2(ismissing(T2.MustWarn)|(T2.MustWarn==""),:);
T2 = innerjoin(T2, DT, 'Keys','DateTime');
[G2,mouse,dt] = findgroups(T2.Mouse, T2.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T2.LWPerf, G2);
Sess = table(mouse, dt, perf2, 'VariableNames',{'Mouse','DateTime','Performance'});
Sess = sortrows(Sess,{'Mouse','DateTime'});
end

function SessOut = iPhase(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut),1);
for iM = 1:numel(mice)
    m = mice(iM);
    dtM = DT(DT.Mouse==m,:);
    startDT = min(dtM.DateTime(dtM.Phase==string(phaseStart)));
    endDT   = max(dtM.DateTime(dtM.Phase==string(phaseEnd)));
    if ismissing(startDT)||ismissing(endDT), continue; end
    keep = keep | (string(SessOut.Mouse)==m & SessOut.DateTime>=startDT & SessOut.DateTime<=endDT);
end
SessOut = SessOut(keep,:);
end
