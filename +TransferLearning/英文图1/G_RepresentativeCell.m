% 英文图1G：代表性细胞信号曲线
%
% 挑选一个细胞满足以下条件：
% - 第一个会话做过 AudioOnly 回合且不活跃
% - Phase=Naive 的 AudioWater 回合略有活跃
% - Phase=Learned 的 AudioWater 回合高活跃
% - Phase=Transfer 的 LightWater 回合也活跃
%
% 用 QueryNTS ZScore 取回合信号，-1~3s
%
% 子图1：Pre-training（AudioOnly, Naive AudioWater, Learned AudioWater）
% 子图2：Transfer（LightWater）
%
% Execution:
%   TransferLearning.英文图1.G_RepresentativeCell

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1G_RepresentativeCell.svg";

% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

% --- 1) Load dataset
DS = TransferLearning.AudioLightBaseline();

% Time axis
xs = TransferLearning.Xs; % duration(48x1): -3~3s
xsSec = seconds(xs);
baseMask = (xsSec >= -1) & (xsSec < 0);  % baseline for activity check
respMask = (xsSec >= 0) & (xsSec <= 3);  % response window 0~3s
plotMask = (xsSec >= -1) & (xsSec <= 3); % plot range
xsPlot = xsSec(plotMask);
kSigma = 3;

% --- 2) Build session/trial index using TableQuery (like Fig3.2A)
% AudioOnly trials (first session)
Tao = DS.TableQuery(["Mouse","DateTime","TrialUID"], Stimulus="AudioOnly");
Tao.Mouse = string(Tao.Mouse);
Tao.DateTime = iNormalizeDateTime(Tao.DateTime);

% Naive AudioWater
Tnaive = DS.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Naive", Stimulus="AudioWater");
Tnaive.Mouse = string(Tnaive.Mouse);
Tnaive.DateTime = iNormalizeDateTime(Tnaive.DateTime);

% Learned AudioWater
Tlearned = DS.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Learned", Stimulus="AudioWater");
Tlearned.Mouse = string(Tlearned.Mouse);
Tlearned.DateTime = iNormalizeDateTime(Tlearned.DateTime);

% Transfer LightWater
Ttrans = DS.TableQuery(["Mouse","DateTime","TrialUID"], Phase="Transfer", Stimulus="LightWater");
Ttrans.Mouse = string(Ttrans.Mouse);
Ttrans.DateTime = iNormalizeDateTime(Ttrans.DateTime);

% Pick representative sessions per mouse
% AudioOnly: first session (earliest)
dtAoT = groupsummary(Tao, "Mouse", "min", "DateTime");
dtAoT.Properties.VariableNames{end} = 'DateTimeAO';
% Naive: first session
dtNaiveT = groupsummary(Tnaive, "Mouse", "min", "DateTime");
dtNaiveT.Properties.VariableNames{end} = 'DateTimeNaive';
% Learned: last session
dtLearnedT = groupsummary(Tlearned, "Mouse", "max", "DateTime");
dtLearnedT.Properties.VariableNames{end} = 'DateTimeLearned';
% Transfer: first session
dtTransT = groupsummary(Ttrans, "Mouse", "min", "DateTime");
dtTransT.Properties.VariableNames{end} = 'DateTimeTransfer';

% Mice with all 4 conditions
Sess = innerjoin(dtAoT(:, ["Mouse","DateTimeAO"]), dtNaiveT(:, ["Mouse","DateTimeNaive"]), 'Keys', 'Mouse');
Sess = innerjoin(Sess, dtLearnedT(:, ["Mouse","DateTimeLearned"]), 'Keys', 'Mouse');
Sess = innerjoin(Sess, dtTransT(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');

if isempty(Sess)
	error('Fig1G:NoMice', 'No mice have all 4 required conditions.');
end

% Collect trial UIDs for each condition
aoJoin = innerjoin(Tao, Sess(:, ["Mouse","DateTimeAO"]), 'Keys', 'Mouse');
aoJoin = aoJoin(aoJoin.DateTime == aoJoin.DateTimeAO, :);
[gAO, mkAO] = findgroups(aoJoin.Mouse);
trialAO = splitapply(@(x){uint64(x)}, uint64(aoJoin.TrialUID), gAO);
aoTrialsT = table(mkAO, trialAO, 'VariableNames', ["Mouse","TrialUIDAO"]);

naiveJoin = innerjoin(Tnaive, Sess(:, ["Mouse","DateTimeNaive"]), 'Keys', 'Mouse');
naiveJoin = naiveJoin(naiveJoin.DateTime == naiveJoin.DateTimeNaive, :);
[gN, mkN] = findgroups(naiveJoin.Mouse);
trialNaive = splitapply(@(x){uint64(x)}, uint64(naiveJoin.TrialUID), gN);
naiveTrialsT = table(mkN, trialNaive, 'VariableNames', ["Mouse","TrialUIDNaive"]);

learnedJoin = innerjoin(Tlearned, Sess(:, ["Mouse","DateTimeLearned"]), 'Keys', 'Mouse');
learnedJoin = learnedJoin(learnedJoin.DateTime == learnedJoin.DateTimeLearned, :);
[gL, mkL] = findgroups(learnedJoin.Mouse);
trialLearned = splitapply(@(x){uint64(x)}, uint64(learnedJoin.TrialUID), gL);
learnedTrialsT = table(mkL, trialLearned, 'VariableNames', ["Mouse","TrialUIDLearned"]);

transJoin = innerjoin(Ttrans, Sess(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');
transJoin = transJoin(transJoin.DateTime == transJoin.DateTimeTransfer, :);
[gT, mkT] = findgroups(transJoin.Mouse);
trialTrans = splitapply(@(x){uint64(x)}, uint64(transJoin.TrialUID), gT);
transTrialsT = table(mkT, trialTrans, 'VariableNames', ["Mouse","TrialUIDTrans"]);

Sess = innerjoin(Sess, aoTrialsT, 'Keys', 'Mouse');
Sess = innerjoin(Sess, naiveTrialsT, 'Keys', 'Mouse');
Sess = innerjoin(Sess, learnedTrialsT, 'Keys', 'Mouse');
Sess = innerjoin(Sess, transTrialsT, 'Keys', 'Mouse');

% Get cell metadata
Cmeta = DS.Cells(:, ["CellUID","Mouse"]);
Cmeta.Mouse = string(Cmeta.Mouse);

% TrialSignals for signal extraction
Ts = DS.TrialSignals;

% --- 3) Find a cell satisfying activity criteria
picked = struct('CellUID', uint64(0), 'Mouse', "", 'Score', -inf);

for iS = 1:height(Sess)
	m = Sess.Mouse(iS);
	aoUIDs = Sess.TrialUIDAO{iS};
	naiveUIDs = Sess.TrialUIDNaive{iS};
	learnedUIDs = Sess.TrialUIDLearned{iS};
	transUIDs = Sess.TrialUIDTrans{iS};
	
	% Get cells for this mouse
	cellUIDs = uint64(Cmeta.CellUID(Cmeta.Mouse == m));
	if isempty(cellUIDs), continue; end
	
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		
		% Get signals
		[Sao, Snaive, Slearned, Strans] = iGetSignals4Cond(Ts, cid, aoUIDs, naiveUIDs, learnedUIDs, transUIDs);
		if isempty(Sao) || isempty(Snaive) || isempty(Slearned) || isempty(Strans)
			continue;
		end
		
		% Z-score normalize
		Zao = iZScoreByBaseline(Sao, baseMask);
		Znaive = iZScoreByBaseline(Snaive, baseMask);
		Zlearned = iZScoreByBaseline(Slearned, baseMask);
		Ztrans = iZScoreByBaseline(Strans, baseMask);
		
		% Compute peak values for each condition
		pkAO = max(median(Zao(:, respMask), 1, 'omitnan'), [], 'omitnan');
		pkNaive = max(median(Znaive(:, respMask), 1, 'omitnan'), [], 'omitnan');
		pkLearned = max(median(Zlearned(:, respMask), 1, 'omitnan'), [], 'omitnan');
		pkTrans = max(median(Ztrans(:, respMask), 1, 'omitnan'), [], 'omitnan');
		
		% Activity criteria: AudioOnly < Naive < Transfer < Learned
		% AudioOnly should be lowest
		if ~isfinite(pkAO) || ~isfinite(pkNaive) || ~isfinite(pkLearned) || ~isfinite(pkTrans)
			continue;
		end
		if pkAO >= pkNaive, continue; end       % AudioOnly < Naive
		if pkNaive >= pkTrans, continue; end    % Naive < Transfer
		if pkTrans >= pkLearned, continue; end  % Transfer < Learned
		
		% Additional: Learned at 1s must exceed baseline mean + 3*std
		% Since z-scored, baseline mean=0, std=1, so need value at 1s > 3
		[~, idx1s] = min(abs(xsSec - 1));
		learnedAt1s = median(Zlearned(:, idx1s), 'omitnan');
		if ~isfinite(learnedAt1s) || learnedAt1s <= 3
			continue;
		end
		
		% Transfer at 1s must also exceed baseline + 3*std
		transAt1s = median(Ztrans(:, idx1s), 'omitnan');
		if ~isfinite(transAt1s) || transAt1s <= 3
			continue;
		end
		
		% Score: prefer larger spread
		sc = pkLearned - pkAO;
		
		if sc > picked.Score
			% Pick single trials that also satisfy peak order: AO < Naive < Trans < Learned
			pkPerTrialAO = max(Zao(:, respMask), [], 2, 'omitnan');
			pkPerTrialNaive = max(Znaive(:, respMask), [], 2, 'omitnan');
			pkPerTrialLearned = max(Zlearned(:, respMask), [], 2, 'omitnan');
			pkPerTrialTrans = max(Ztrans(:, respMask), [], 2, 'omitnan');
			
			% Learned: pick highest peak trial
			[pkL, iLearned] = max(pkPerTrialLearned);
			
			% Transfer: pick highest peak trial that is < Learned peak
			validTrans = find(pkPerTrialTrans < pkL);
			if isempty(validTrans), continue; end
			[pkT, relIdx] = max(pkPerTrialTrans(validTrans));
			iTrans = validTrans(relIdx);
			
			% Naive: pick highest peak trial that is < Transfer peak
			validNaive = find(pkPerTrialNaive < pkT);
			if isempty(validNaive), continue; end
			[pkN, relIdx] = max(pkPerTrialNaive(validNaive));
			iNaive = validNaive(relIdx);
			
			% AudioOnly: pick lowest peak trial that is < Naive peak
			validAO = find(pkPerTrialAO < pkN);
			if isempty(validAO), continue; end
			[~, relIdx] = min(pkPerTrialAO(validAO));
			iAO = validAO(relIdx);
			
			picked.CellUID = cid;
			picked.Mouse = m;
			picked.Score = sc;
			picked.Sig_AudioOnly = Zao(iAO, :);
			picked.Sig_NaiveAW = Znaive(iNaive, :);
			picked.Sig_LearnedAW = Zlearned(iLearned, :);
			picked.Sig_TransferLW = Ztrans(iTrans, :);
		end
	end
end

if picked.CellUID == 0
	error('Fig1G:NoCellFound', 'No cell found satisfying all activity criteria.');
end

fprintf('Selected: Mouse=%s, CellUID=%d\n', picked.Mouse, picked.CellUID);

% --- 4) Prepare signals for plotting (-1~3s)
SigAO = picked.Sig_AudioOnly(plotMask);
SigNaive = picked.Sig_NaiveAW(plotMask);
SigLearned = picked.Sig_LearnedAW(plotMask);
SigTrans = picked.Sig_TransferLW(plotMask);

% Baseline means (for yticks)
baseIdxPlot = (xsPlot >= -1) & (xsPlot < 0);
baseAO = mean(SigAO(baseIdxPlot), 'omitnan');
baseNaive = mean(SigNaive(baseIdxPlot), 'omitnan');
baseLearned = mean(SigLearned(baseIdxPlot), 'omitnan');
baseTrans = mean(SigTrans(baseIdxPlot), 'omitnan');

% Compute offsets to separate traces
% Order from top to bottom: AudioOnly (highest), Naive (middle), Learned (lowest)
maxAO = max(SigAO, [], 'omitnan');
minAO = min(SigAO, [], 'omitnan');
maxNaive = max(SigNaive, [], 'omitnan');
minNaive = min(SigNaive, [], 'omitnan');
maxLearned = max(SigLearned, [], 'omitnan');

gap = 1.5; % gap between traces

offsetLearned = 0;
offsetNaive = (maxLearned - minNaive) + gap;
offsetAO = offsetNaive + (maxNaive - minAO) + gap;

SigAO_shifted = SigAO + offsetAO;
SigNaive_shifted = SigNaive + offsetNaive;
SigLearned_shifted = SigLearned + offsetLearned;

baseAO_shifted = baseAO + offsetAO;
baseNaive_shifted = baseNaive + offsetNaive;
baseLearned_shifted = baseLearned + offsetLearned;

% --- 5) Plot
f = figure('Color','w', 'Name', 'English Fig1G Representative Cell');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.5]; % 45mm x 45mm

TL = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Subplot 1: Pre-training
ax1 = nexttile(TL);
hold(ax1, 'on');
plot(ax1, xsPlot, SigAO_shifted, 'k-', 'LineWidth', 1);
plot(ax1, xsPlot, SigNaive_shifted, 'b-', 'LineWidth', 1);
plot(ax1, xsPlot, SigLearned_shifted, 'r-', 'LineWidth', 1);
xline(ax1, 0, ':k');
xlim(ax1, [-1 3]);
title(ax1, {sprintf('Cell#%u', picked.CellUID); 'Pre-training'}, 'FontSize', 6);

% yticks at baseline positions (from smallest to largest)
ytickVals = sort([baseLearned_shifted, baseNaive_shifted, baseAO_shifted]);
ytickLabels = ["🔊💧", "🔊💧", "🔊"]; % from smallest to largest: Learned, Naive, AudioOnly
ax1.YTick = ytickVals;
ax1.YTickLabel = ytickLabels;
ax1.FontSize = 6;
ax1.FontName = 'Segoe UI Emoji';
box(ax1, 'off');

try ax1.Toolbar.Visible = 'off'; catch, end

% --- Subplot 2: Transfer
ax2 = nexttile(TL);
hold(ax2, 'on');
plot(ax2, xsPlot, SigTrans, 'Color', [0.5 0 0.5], 'LineWidth', 1);
xline(ax2, 0, ':k');
xlim(ax2, [-1 3]);
title(ax2, {'Transfer'; '🔊💧→💡💧'}, 'FontSize', 6, 'FontName', 'Segoe UI Emoji');

ax2.YTick = baseTrans;
ax2.YTickLabel = "💡💧";
ax2.FontSize = 6;
ax2.FontName = 'Segoe UI Emoji';
box(ax2, 'off');

try ax2.Toolbar.Visible = 'off'; catch, end

% Unify ylim across both axes
MATLAB.Graphics.UnifyAxesLims([ax1, ax2], @ylim);

% Shared xlabel on tiledlayout
xlabel(TL, 'Time (s)', 'FontSize', 6);

% --- 6) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

assignin('base', 'Fig1G_Picked', picked);

%% --- Local helper functions

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
dt.TimeZone = '';
end

function [S0, S1, S2, S3] = iGetSignals4Cond(Ts, cellUID, tu0, tu1, tu2, tu3)
% One-pass extraction from TrialSignals for a single cell
cellUID = uint64(cellUID);
tu0 = uint64(tu0(:)); tu1 = uint64(tu1(:)); tu2 = uint64(tu2(:)); tu3 = uint64(tu3(:));
allUID = unique([tu0; tu1; tu2; tu3]);
mask = (uint64(Ts.CellUID) == cellUID) & ismember(uint64(Ts.TrialUID), allUID);
if ~any(mask)
	S0 = []; S1 = []; S2 = []; S3 = [];
	return;
end
uid = uint64(Ts.TrialUID(mask));
sig = double(Ts.ResampledSignal(mask, :));
S0 = sig(ismember(uid, tu0), :);
S1 = sig(ismember(uid, tu1), :);
S2 = sig(ismember(uid, tu2), :);
S3 = sig(ismember(uid, tu3), :);
end

function Z = iZScoreByBaseline(S, baseMask)
% Z-score normalize using baseline period
mu = mean(S(:, baseMask), 2, 'omitnan');
sd = std(S(:, baseMask), 0, 2, 'omitnan');
sd(sd < eps) = 1;
Z = (S - mu) ./ sd;
end

function tf = iIsActive(Z, respMask, k)
% Check if median response exceeds baseline + k*std
medZ = median(Z, 1, 'omitnan');
baseMu = 0; % z-scored baseline has mean 0
baseSd = 1; % z-scored baseline has std 1
pk = max(medZ(respMask), [], 'omitnan');
tf = isfinite(pk) && (pk > baseMu + k * baseSd);
end
