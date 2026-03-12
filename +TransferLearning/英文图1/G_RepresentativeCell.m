% 英文图1G：代表性细胞信号曲线
%
% 挑选一个细胞满足以下条件：
% - 在1s处：Learned AudioWater > Transfer LightWater > 两个Naive泳道
% - 在-1~2s内峰值：Learned AudioWater > Transfer LightWater > 两个Naive泳道
%
% 用 QueryNTS ZScore 取回合信号，-1~2s
%
% 子图1：Naive（AudioOnly, LightOnly）- 两条曲线offset分开
% 子图2：Learned & Transfer（AudioWater, LightWater）- 两条曲线offset分开
%
% Execution:
%   TransferLearning.英文图1.G_RepresentativeCell

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

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
respMask = (xsSec >= -1) & (xsSec <= 2); % response window -1~2s (also peak window)
plotMask = (xsSec >= -1) & (xsSec <= 2); % plot range
xsPlot = xsSec(plotMask);
kSigma = 3;

% --- 2) Build session/trial index using TableQuery
% AudioOnly trials (first session)
Tao = DS.TableQuery(["Mouse","DateTime","TrialUID"], Stimulus="AudioOnly");
Tao.Mouse = string(Tao.Mouse);
Tao.DateTime = iNormalizeDateTime(Tao.DateTime);

% LightOnly trials (first session)
Tlo = DS.TableQuery(["Mouse","DateTime","TrialUID"], Stimulus="LightOnly");
Tlo.Mouse = string(Tlo.Mouse);
Tlo.DateTime = iNormalizeDateTime(Tlo.DateTime);

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
% LightOnly: first session
dtLoT = groupsummary(Tlo, "Mouse", "min", "DateTime");
dtLoT.Properties.VariableNames{end} = 'DateTimeLO';
% Learned: last session
dtLearnedT = groupsummary(Tlearned, "Mouse", "max", "DateTime");
dtLearnedT.Properties.VariableNames{end} = 'DateTimeLearned';
% Transfer: first session
dtTransT = groupsummary(Ttrans, "Mouse", "min", "DateTime");
dtTransT.Properties.VariableNames{end} = 'DateTimeTransfer';

% Mice with all 4 conditions
Sess = innerjoin(dtAoT(:, ["Mouse","DateTimeAO"]), dtLoT(:, ["Mouse","DateTimeLO"]), 'Keys', 'Mouse');
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

loJoin = innerjoin(Tlo, Sess(:, ["Mouse","DateTimeLO"]), 'Keys', 'Mouse');
loJoin = loJoin(loJoin.DateTime == loJoin.DateTimeLO, :);
[gLO, mkLO] = findgroups(loJoin.Mouse);
trialLO = splitapply(@(x){uint64(x)}, uint64(loJoin.TrialUID), gLO);
loTrialsT = table(mkLO, trialLO, 'VariableNames', ["Mouse","TrialUIDLO"]);

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
Sess = innerjoin(Sess, loTrialsT, 'Keys', 'Mouse');
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
	loUIDs = Sess.TrialUIDLO{iS};
	learnedUIDs = Sess.TrialUIDLearned{iS};
	transUIDs = Sess.TrialUIDTrans{iS};
	
	% Get cells for this mouse
	cellUIDs = uint64(Cmeta.CellUID(Cmeta.Mouse == m));
	if isempty(cellUIDs), continue; end
	
	for iC = 1:numel(cellUIDs)
		cid = cellUIDs(iC);
		
		% Get signals
		[Sao, Slo, Slearned, Strans] = iGetSignals4Cond(Ts, cid, aoUIDs, loUIDs, learnedUIDs, transUIDs);
		if isempty(Sao) || isempty(Slo) || isempty(Slearned) || isempty(Strans)
			continue;
		end
		
		% Z-score normalize
		Zao = iZScoreByBaseline(Sao, baseMask);
		Zlo = iZScoreByBaseline(Slo, baseMask);
		Zlearned = iZScoreByBaseline(Slearned, baseMask);
		Ztrans = iZScoreByBaseline(Strans, baseMask);
		
		% Compute peak values for each condition (in -1~2s)
		pkAO = max(median(Zao(:, respMask), 1, 'omitnan'), [], 'omitnan');
		pkLO = max(median(Zlo(:, respMask), 1, 'omitnan'), [], 'omitnan');
		pkLearned = max(median(Zlearned(:, respMask), 1, 'omitnan'), [], 'omitnan');
		pkTrans = max(median(Ztrans(:, respMask), 1, 'omitnan'), [], 'omitnan');
		
		% Activity criteria: Learned > Transfer > both Naive
		if ~isfinite(pkAO) || ~isfinite(pkLO) || ~isfinite(pkLearned) || ~isfinite(pkTrans)
			continue;
		end
		if pkLearned <= pkTrans, continue; end      % Learned > Transfer
		if pkTrans <= pkAO, continue; end           % Transfer > AudioOnly
		if pkTrans <= pkLO, continue; end           % Transfer > LightOnly
		
		% Additional: check at 1s
		[~, idx1s] = min(abs(xsSec - 1));
		learnedAt1s = median(Zlearned(:, idx1s), 'omitnan');
		transAt1s = median(Ztrans(:, idx1s), 'omitnan');
		aoAt1s = median(Zao(:, idx1s), 'omitnan');
		loAt1s = median(Zlo(:, idx1s), 'omitnan');
		
		if ~isfinite(learnedAt1s) || ~isfinite(transAt1s) || ~isfinite(aoAt1s) || ~isfinite(loAt1s)
			continue;
		end
		if learnedAt1s <= transAt1s, continue; end
		if transAt1s <= aoAt1s, continue; end
		if transAt1s <= loAt1s, continue; end
		
		% Learned at 1s must exceed baseline + 3*std
		if learnedAt1s <= kSigma, continue; end
		
		% Transfer at 1s must also exceed baseline + 3*std
		if transAt1s <= kSigma, continue; end
		
		% Score: prefer larger spread
		sc = pkLearned - max(pkAO, pkLO);
		
		if sc > picked.Score
			% Pick single trials that satisfy both peak and 1s criteria:
			% Learned > Transfer > both Naive (at peak AND at 1s)
			pkPerTrialAO = max(Zao(:, respMask), [], 2, 'omitnan');
			pkPerTrialLO = max(Zlo(:, respMask), [], 2, 'omitnan');
			pkPerTrialLearned = max(Zlearned(:, respMask), [], 2, 'omitnan');
			pkPerTrialTrans = max(Ztrans(:, respMask), [], 2, 'omitnan');
			
			% Also get 1s values for each trial
			v1s_AO = Zao(:, idx1s);
			v1s_LO = Zlo(:, idx1s);
			v1s_Learned = Zlearned(:, idx1s);
			v1s_Trans = Ztrans(:, idx1s);
			
			% Find best combination satisfying both peak and 1s criteria
			bestComboScore = -inf;
			bestCombo = [];
			
			for iL = 1:size(Zlearned, 1)
				pkL = pkPerTrialLearned(iL);
				v1sL = v1s_Learned(iL);
				if ~isfinite(pkL) || ~isfinite(v1sL), continue; end
				% Learned at 1s must be "active" (> kSigma for z-scored data)
				if v1sL <= kSigma, continue; end
				
				for iT = 1:size(Ztrans, 1)
					pkT = pkPerTrialTrans(iT);
					v1sT = v1s_Trans(iT);
					if ~isfinite(pkT) || ~isfinite(v1sT), continue; end
					% Transfer at 1s must also be "active" (> kSigma)
					if v1sT <= kSigma, continue; end
					
					% Check Learned > Transfer at both peak and 1s
					if pkL <= pkT || v1sL <= v1sT, continue; end
					
					for iA = 1:size(Zao, 1)
						pkA = pkPerTrialAO(iA);
						v1sA = v1s_AO(iA);
						if ~isfinite(pkA) || ~isfinite(v1sA), continue; end
						
						% Check Transfer > AO at both peak and 1s
						if pkT <= pkA || v1sT <= v1sA, continue; end
						
						for iO = 1:size(Zlo, 1)
							pkO = pkPerTrialLO(iO);
							v1sO = v1s_LO(iO);
							if ~isfinite(pkO) || ~isfinite(v1sO), continue; end
							
							% Check Transfer > LO at both peak and 1s
							if pkT <= pkO || v1sT <= v1sO, continue; end
							
							% This combination satisfies all criteria
							% Score: prefer larger spread at 1s
							comboScore = v1sL - max(v1sA, v1sO);
							if comboScore > bestComboScore
								bestComboScore = comboScore;
								bestCombo = [iL, iT, iA, iO];
							end
						end
					end
				end
			end
			
			if isempty(bestCombo), continue; end
			
			iLearned = bestCombo(1);
			iTrans = bestCombo(2);
			iAO = bestCombo(3);
			iLO = bestCombo(4);
			
			picked.CellUID = cid;
			picked.Mouse = m;
			picked.Score = sc;
			picked.Sig_AudioOnly = Zao(iAO, :);
			picked.Sig_LightOnly = Zlo(iLO, :);
			picked.Sig_LearnedAW = Zlearned(iLearned, :);
			picked.Sig_TransferLW = Ztrans(iTrans, :);
		end
	end
end

if picked.CellUID == 0
	error('Fig1G:NoCellFound', 'No cell found satisfying all activity criteria.');
end

fprintf('Selected: Mouse=%s, CellUID=%d\n', picked.Mouse, picked.CellUID);

% Debug: print values at 1s for selected trials
[~, idx1s_debug] = min(abs(xsSec - 1));
v1s_AO_sel = picked.Sig_AudioOnly(idx1s_debug);
v1s_LO_sel = picked.Sig_LightOnly(idx1s_debug);
v1s_Learned_sel = picked.Sig_LearnedAW(idx1s_debug);
v1s_Trans_sel = picked.Sig_TransferLW(idx1s_debug);
fprintf('Values at 1s: Learned=%.2f, Transfer=%.2f, AO=%.2f, LO=%.2f\n', ...
	v1s_Learned_sel, v1s_Trans_sel, v1s_AO_sel, v1s_LO_sel);
fprintf('Check: Learned>Transfer=%d, Transfer>AO=%d, Transfer>LO=%d\n', ...
	v1s_Learned_sel > v1s_Trans_sel, v1s_Trans_sel > v1s_AO_sel, v1s_Trans_sel > v1s_LO_sel);

% --- 4) Prepare signals for plotting (-1~2s)
SigAO = picked.Sig_AudioOnly(plotMask);
SigLO = picked.Sig_LightOnly(plotMask);
SigLearned = picked.Sig_LearnedAW(plotMask);
SigTrans = picked.Sig_TransferLW(plotMask);

% Baseline means (for yticks)
baseIdxPlot = (xsPlot >= -1) & (xsPlot < 0);
baseAO = mean(SigAO(baseIdxPlot), 'omitnan');
baseLO = mean(SigLO(baseIdxPlot), 'omitnan');
baseLearned = mean(SigLearned(baseIdxPlot), 'omitnan');
baseTrans = mean(SigTrans(baseIdxPlot), 'omitnan');

% Compute offsets with constraints:
% 1. Traces within same tile must not touch (gap between them)
% 2. AO baseline aligns with Learned baseline
% 3. LO baseline aligns with Trans baseline

gap = 1.5; % gap between traces

% --- Right tile first: compute offsets for Learned (upper) and Trans (lower)
% Start Trans at 0, then place Learned above it with gap
maxTrans = max(SigTrans, [], 'omitnan');
minLearned = min(SigLearned, [], 'omitnan');

offsetTrans = 0;
offsetLearned = (maxTrans - minLearned) + gap;

SigTrans_shifted = SigTrans + offsetTrans;
SigLearned_shifted = SigLearned + offsetLearned;

baseTrans_shifted = baseTrans + offsetTrans;
baseLearned_shifted = baseLearned + offsetLearned;

% --- Left tile: align AO to Learned, LO to Trans
% offsetAO chosen so that baseAO + offsetAO = baseLearned_shifted
offsetAO = baseLearned_shifted - baseAO;
% offsetLO chosen so that baseLO + offsetLO = baseTrans_shifted
offsetLO = baseTrans_shifted - baseLO;

SigAO_shifted = SigAO + offsetAO;
SigLO_shifted = SigLO + offsetLO;

baseAO_shifted = baseAO + offsetAO;
baseLO_shifted = baseLO + offsetLO;

% Check if left tile traces overlap, adjust if needed
minAO_shifted = min(SigAO_shifted, [], 'omitnan');
maxLO_shifted = max(SigLO_shifted, [], 'omitnan');
if maxLO_shifted >= minAO_shifted - gap
	% Need to push AO up more
	extraShift = (maxLO_shifted - minAO_shifted) + gap;
	offsetAO = offsetAO + extraShift;
	SigAO_shifted = SigAO + offsetAO;
	baseAO_shifted = baseAO + offsetAO;
end

% --- 5) Plot
svgName = "English_Fig1G_RepresentativeCell.svg";
f = figure('Color','w', 'Name', 'English Fig1G Representative Cell');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.0]; % 45mm x 40mm

TL = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Subplot 1: Naive (AudioOnly, LightOnly)
ax1 = nexttile(TL);
hold(ax1, 'on');
plot(ax1, xsPlot, SigAO_shifted, 'k-', 'LineWidth', 1);
plot(ax1, xsPlot, SigLO_shifted, 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
xline(ax1, 0, ':k');
xlim(ax1, [-1 2]);
title(ax1, {sprintf('Cell#%u', picked.CellUID); 'Naive'}, 'FontSize', 6);

% yticks at baseline positions
ytickVals = sort([baseLO_shifted, baseAO_shifted]);
ytickLabels = ["💡", "🔊"]; % from smallest to largest: LO, AO
ax1.YTick = ytickVals;
ax1.YTickLabel = ytickLabels;
% Modify xticklabel: replace 0 with "Cue"
xt1 = ax1.XTick;
xtl1 = string(ax1.XTickLabel);
idx0 = find(xt1 == 0);
if ~isempty(idx0)
	xtl1(idx0) = "Cue";
end
ax1.XTickLabel = xtl1;
ax1.FontSize = 6;
ax1.FontName = 'Segoe UI Emoji';
box(ax1, 'off');

try ax1.Toolbar.Visible = 'off'; catch, end

% --- Subplot 2: Learned & Transfer
ax2 = nexttile(TL);
hold(ax2, 'on');
plot(ax2, xsPlot, SigLearned_shifted, 'r-', 'LineWidth', 1);
plot(ax2, xsPlot, SigTrans_shifted, 'Color', [0.5 0 0.5], 'LineWidth', 1);
xline(ax2, 0, ':k');
xline(ax2, 1, '-k');
xlim(ax2, [-1 2]);
title(ax2, '🔊💧→💡💧', 'FontSize', 6, 'FontName', 'Segoe UI Emoji');

% yticks at baseline positions
ytickVals2 = sort([baseTrans_shifted, baseLearned_shifted]);
ytickLabels2 = ["💡💧", "🔊💧"]; % from smallest to largest: Trans, Learned
ax2.YTick = ytickVals2;
ax2.YTickLabel = ytickLabels2;
% Modify xticklabel: replace 0 with "Cue", 1 with "💧"
xt2 = ax2.XTick;
xtl2 = string(ax2.XTickLabel);
idx0_2 = find(xt2 == 0);
idx1_2 = find(xt2 == 1);
if ~isempty(idx0_2)
	xtl2(idx0_2) = "Cue";
end
if ~isempty(idx1_2)
	xtl2(idx1_2) = "💧";
end
ax2.XTickLabel = xtl2;
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
