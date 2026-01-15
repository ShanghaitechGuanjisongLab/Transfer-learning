function Validate_Fig31A_FirstSessionPerformance_FromTrials()
% Validate Fig3.1a: ensure FirstSession performance is computed from LightWater trials only.
%
% This validation recomputes per-mouse first-session performance using Trials
% (Stimulus == "LightWater") and compares it to the current Fig31.A output.

close all;

% 1) Current A output (what the figure uses)
[rawA, ~] = TransferLearning.Fig31.A_FirstSessionPerformance();
rawA.Mouse = string(rawA.Mouse);
rawA.Source = string(rawA.Source);

% 2) Load datasets
LAB  = TransferLearning.LightAudioBaseline();
LAI  = TransferLearning.LAInterspersed();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();

% 3) Use A's own inclusion as whitelist for Naive cohort to preserve
%    the existing purity rule (e.g. LAInterspersed mixed AudioWater in Naive)
naiveWhitelist_LAB  = rawA.Mouse(rawA.Source=="LightAudioBaseline" & rawA.Group=="Naive");
naiveWhitelist_LAI  = rawA.Mouse(rawA.Source=="LAInterspersed" & rawA.Group=="Naive");
naiveWhitelist_LAPB = rawA.Mouse(rawA.Source=="LAPureBehavior" & rawA.Group=="Naive");

naiveA2 = firstFromTrials(LAB,  "LightAudioBaseline", true,  "Naive",   naiveWhitelist_LAB);
naiveB2 = firstFromTrials(LAI,  "LAInterspersed",     true,  "Naive",   naiveWhitelist_LAI);
naiveC2 = firstFromTrials(LAPB, "LAPureBehavior",     false, "Naive",   naiveWhitelist_LAPB);
tranA2  = firstFromTrials(ALB,  "AudioLightBaseline", true,  "Transfer", strings(0,1));
tranB2  = firstFromTrials(ALPB, "ALPureBehavior",     false, "Transfer", strings(0,1));

naive2 = [naiveA2; naiveB2; naiveC2];
tran2  = [tranA2; tranB2];
naive2.Group(:) = "Naive";
tran2.Group(:)  = "Transfer";
raw2 = [naive2; tran2];

% 4) Compare rawA vs raw2 by (Mouse, Source)
keyA = rawA.Mouse + "|" + rawA.Source;
key2 = raw2.Mouse + "|" + raw2.Source;

[common, ia, ib] = intersect(keyA, key2);

delta = rawA.FirstPerformance(ia) - raw2.FirstPerformance(ib);
absd = abs(delta);

fprintf('A-validate: rawA rows=%d, recomputed rows=%d, common=%d\n', height(rawA), height(raw2), numel(common));
fprintf('A-validate: max |delta| = %.6g, mean |delta| = %.6g\n', max(absd,[],'omitnan'), mean(absd,'omitnan'));

bad = find(isfinite(absd) & absd > 1e-10);
fprintf('A-validate: mismatched entries (>1e-10): %d\n', numel(bad));

if ~isempty(bad)
    [~, ord] = sort(absd(bad), 'descend');
    show = bad(ord(1:min(15, numel(ord))));

    report = table(...
        rawA.Mouse(ia(show)), rawA.Source(ia(show)), rawA.Group(ia(show)), ...
        rawA.FirstPerformance(ia(show)), raw2.FirstPerformance(ib(show)), delta(show), ...
        'VariableNames', {'Mouse','Source','Group','Perf_Current','Perf_FromTrials','Delta'});

    disp(report);
end

% Coverage: find keys present in A but missing in recompute (should be none)
missingIn2 = setdiff(keyA, key2);
if ~isempty(missingIn2)
    fprintf('A-validate: WARNING %d entries in current A missing in recompute. Showing first 10 keys:\n', numel(missingIn2));
    disp(missingIn2(1:min(10,end)));
end

missingInA = setdiff(key2, keyA);
if ~isempty(missingInA)
    fprintf('A-validate: WARNING %d entries in recompute missing in current A. Showing first 10 keys:\n', numel(missingInA));
    disp(missingInA(1:min(10,end)));
end

end

function out = firstFromTrials(DS, sourceName, imagingCohort, phaseName, mouseWhitelist)
% Recompute per-mouse first-session performance using Trials where Stimulus=="LightWater".

Tblk = DS.TableQuery(["Mouse","DateTime","BlockUID","Phase"], Phase=phaseName);

if isempty(Tblk)
    out = emptyOut();
    return;
end

Tblk.Mouse = string(Tblk.Mouse);
Tblk.DateTime = datetime(Tblk.DateTime); Tblk.DateTime.TimeZone = '';

if ~isempty(mouseWhitelist)
    Tblk = Tblk(ismember(Tblk.Mouse, string(mouseWhitelist)), :);
end

if isempty(Tblk)
    out = emptyOut();
    return;
end

if ~isprop(DS,'Trials')
    error('ValidateFig31A:MissingTrials', 'Dataset %s has no Trials.', class(DS));
end

Tr = DS.Trials;
need = { 'BlockUID','Stimulus','Behavior' };
if ~all(ismember(need, Tr.Properties.VariableNames))
    error('ValidateFig31A:TrialsMissingFields', 'Dataset %s Trials missing fields: %s', class(DS), strjoin(setdiff(need, Tr.Properties.VariableNames), ','));
end

TrStim = string(Tr.Stimulus);
TrLW = Tr(TrStim=="LightWater", {'BlockUID','Behavior'});

if isempty(TrLW)
    out = emptyOut();
    return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
perf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), perf, 'VariableNames', {'BlockUID64','LWPerf'});

blkUID64 = uint64(Tblk.BlockUID);
[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
Tblk = Tblk(tf, :);

if isempty(Tblk)
    out = emptyOut();
    return;
end

Tblk.LWPerf = perfByBlock.LWPerf(loc(tf));

mice = unique(Tblk.Mouse);
firstDT = NaT(numel(mice),1);
firstPerf = nan(numel(mice),1);
nBlocks = nan(numel(mice),1);

for i=1:numel(mice)
    m = mice(i);
    rowsM = (Tblk.Mouse==m);
    dt0 = min(Tblk.DateTime(rowsM));
    rows0 = rowsM & (Tblk.DateTime==dt0);

    firstDT(i) = dt0;
    firstPerf(i) = mean(Tblk.LWPerf(rows0), 'omitnan');
    nBlocks(i) = sum(rows0);
end

out = table(...
    mice, repmat(string(sourceName), numel(mice), 1), repmat(logical(imagingCohort), numel(mice), 1), ...
    firstDT, firstPerf, nBlocks, ...
    'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});

end

function t = emptyOut()
t = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
end
