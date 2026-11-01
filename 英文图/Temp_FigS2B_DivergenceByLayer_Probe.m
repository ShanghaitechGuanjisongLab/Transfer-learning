% 探查脚本（非正式图）：把英文图S2B 的散度按 MOp2/3 与 MOp5 拆开分别计算，
% 看 2/5 层分开后是否出现更多显著对比。会话口径、回合集合、散度公式、时刻取法与
% 英文图/FigS2B_DelayedVsUndelayed_DivergenceBars.m 完全一致，仅细胞集合分层。
% 统计：同一范式内 Naive vs (Learned|Transfer) 配对；光侧（独立鼠群）用 ranksum，
% 声侧（同鼠两阶段）用 signrank；同时给出各层自身的逐鼠散度与层间差异。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
LAD = TransferLearning.LADelayed();
ALD = TransferLearning.ALDelayed();
badNaiveLai = iMiceWithStimulusInPhase(LAI, "AudioWater", "Naive");
sessNU = [iFirstPureLWNaiveSessions(LAB, strings(0, 1)); iFirstPureLWNaiveSessions(LAI, badNaiveLai)];
sessTU = iFirstTransferLWSessions(ALB);
sessAU = iFirstStimSession(ALB, "AudioOnly");
sessAWU = iLastStimSession(ALB, "AudioWater", "Recall");
miceU = intersect(sessAU.Mouse, sessAWU.Mouse);
sessAU = sessAU(ismember(sessAU.Mouse, miceU), :);
sessAWU = sessAWU(ismember(sessAWU.Mouse, miceU), :);
sessND = iFirstLightLearnSessions(LAD);
sessTD = iFirstLightLearnSessions(ALD);
sessAD = iFirstStimSession(ALD, "AudioPreTrainCueOnly");
sessAWD = iLastStimSession(ALD, "AudioLearnWater", "Recall");

paradigmLabels = ["Undelayed", "Delayed"];
Spec = cell(2, 2, 2);
Spec{1, 1, 1} = struct('Sess', sessNU, 'Stim', "LightWater");
Spec{1, 1, 2} = struct('Sess', sessND, 'Stim', ["LightLearnWater", "LightLearnWaterAlways"]);
Spec{1, 2, 1} = struct('Sess', sessTU, 'Stim', "LightWater");
Spec{1, 2, 2} = struct('Sess', sessTD, 'Stim', ["LightLearnWater", "LightLearnWaterAlways"]);
Spec{2, 1, 1} = struct('Sess', sessAU, 'Stim', "AudioOnly");
Spec{2, 1, 2} = struct('Sess', sessAD, 'Stim', "AudioPreTrainCueOnly");
Spec{2, 2, 1} = struct('Sess', sessAWU, 'Stim', "AudioWater");
Spec{2, 2, 2} = struct('Sess', sessAWD, 'Stim', "AudioLearnWater");
tileName = ["Light", "Audio"];
stageName = {["Naive","Transfer"], ["Naive","Learned"]};

% DivL{tile,stage,para} = table(Mouse, DivL23, DivL5)
DivL = cell(2, 2, 2);
for iTile = 1:2
	for iStage = 1:2
		for iPara = 1:2
			sp = Spec{iTile, iStage, iPara};
			idxT = iFindTimeIndex(iPara);
			rows = iSessionDivergenceByLayer(sp.Sess, sp.Stim, idxT);
			DivL{iTile, iStage, iPara} = iCollapseByMouse(rows);
		end
	end
end

fprintf('\n==================== FigS2B divergence split by layer ====================\n');
Results = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
	zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
	'VariableNames', {'Tile','Paradigm','Comparison','Layer','N1','N2','Mean1','Mean2','Median1','Median2','P'});
for iTile = 1:2
	for iPara = 1:2
		A = DivL{iTile, 1, iPara};   % Naive
		B = DivL{iTile, 2, iPara};   % Transfer (light) / Learned (audio)
		for iLayer = 1:2
			layerName = iif(iLayer==1, "MOp2/3", "MOp5");
			a = A.(iif(iLayer==1,"DivL23","DivL5"));
			b = B.(iif(iLayer==1,"DivL23","DivL5"));
			aM = A.Mouse; bM = B.Mouse;
			if iTile == 2
				% 声侧：同鼠两阶段配对
				[cm, ia, ib] = intersect(aM, bM, 'stable');
				av = a(ia); bv = b(ib);
				ok = isfinite(av) & isfinite(bv);
				av = av(ok); bv = bv(ok);
				p = iSafeSignrank(av, bv);
				na = sum(ok); nb = na;
			else
				% 光侧：独立鼠群
				av = a(isfinite(a)); bv = b(isfinite(b));
				p = iSafeRanksum(av, bv);
				na = numel(av); nb = numel(bv);
			end
			Results = [Results; table(tileName(iTile), paradigmLabels(iPara), ...
				stageName{iTile}(1)+" vs "+stageName{iTile}(2), layerName, na, nb, ...
				mean(av,'omitnan'), mean(bv,'omitnan'), median(av,'omitnan'), median(bv,'omitnan'), p, ...
				'VariableNames', Results.Properties.VariableNames)]; %#ok<AGROW>
			fprintf('%-5s %-9s %-18s %-6s  Naive/1st=%.3f (n=%d)  vs  2nd=%.3f (n=%d)   p=%.4g %s\n', ...
				tileName(iTile), paradigmLabels(iPara), stageName{iTile}(1)+" vs "+stageName{iTile}(2), layerName, ...
				mean(av,'omitnan'), na, mean(bv,'omitnan'), nb, p, iStars(p));
		end
	end
end

% 汇总：层间差异（同组内 2/3 层 vs 5 层，同鼠配对）
fprintf('\n---- within-group layer difference (L2/3 - L5, paired by mouse) ----\n');
for iTile = 1:2
	for iStage = 1:2
		for iPara = 1:2
			R = DivL{iTile, iStage, iPara};
			ok = isfinite(R.DivL23) & isfinite(R.DivL5);
			d = R.DivL23(ok) - R.DivL5(ok);
			if numel(d) >= 3
				p = iSafeSignrank(R.DivL23(ok), R.DivL5(ok));
				fprintf('%-5s %-9s %-9s  mean(L23-L5)=%+.3f  (n=%d)  signrank p=%.4g %s\n', ...
					tileName(iTile), paradigmLabels(iPara), stageName{iTile}(iStage), mean(d), numel(d), p, iStars(p));
			end
		end
	end
end

assignin('base', 'FigS2B_ByLayer_Div', DivL);
assignin('base', 'FigS2B_ByLayer_Results', Results);
disp(Results);

%% ========== local functions ==========
function rows = iSessionDivergenceByLayer(sessTable, stimNames, idxT)
rows = table(strings(0,1), nan(0,1), nan(0,1), 'VariableNames', {'Mouse','DivL23','DivL5'});
for iS = 1:height(sessTable)
	DS = sessTable.DS(iS);
	m = sessTable.Mouse(iS);
	dt = sessTable.DateTime(iS);
	ntsCell = DS.QueryNTS(struct('Stimulus', stimNames, 'Mouse', m, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsCell), nts = ntsCell{1}; else, nts = ntsCell; end
	if isempty(nts), continue; end
	trialUIDs = unique(uint64(nts.TrialUID), 'stable');
	if numel(trialUIDs) < 2, continue; end
	[CTT, cellUIDs] = iBuildCtt(nts, trialUIDs);
	if isempty(CTT) || size(CTT,1) < 3, continue; end
	X = CTT(:, :, idxT);
	CellTbl = DS.Cells;
	CellTbl.CellUID = uint64(CellTbl.CellUID);
	CellTbl.Mouse = string(CellTbl.Mouse);
	CellTbl.ZLayer = string(CellTbl.ZLayer);
	cellMeta = CellTbl(CellTbl.Mouse == m, {'CellUID','ZLayer'});
	[tf, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs),1);
	layers(tf) = cellMeta.ZLayer(loc(tf));
	mask23 = layers == "MOp2/3";
	mask5 = layers == "MOp5";
	d23 = NaN; d5 = NaN;
	if sum(mask23) >= 3, d23 = iDivFromX(X(mask23,:)); end
	if sum(mask5) >= 3, d5 = iDivFromX(X(mask5,:)); end
	rows = [rows; table(string(m), d23, d5, 'VariableNames', {'Mouse','DivL23','DivL5'})]; %#ok<AGROW>
end
end

function [CTT, cellUIDs] = iBuildCtt(nts, trialUIDs)
allCells = unique(uint64(nts.CellUID));
traces = cell(numel(allCells),1);
keepUID = zeros(numel(allCells),1,'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rowsC = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rowsC));
	sig = double(nts.TrialSignal(rowsC, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf), continue; end
	so = sig(loc, :);
	if any(~isfinite(so), 'all'), continue; end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepUID(nKeep) = cid;
end
if nKeep < 3, CTT = []; cellUIDs = uint64([]); return; end
traces = traces(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = numel(trialUIDs);
nTime = size(traces{1}, 2);
CTT = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, nTrial, nTime);
end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0, div = sqrt(totalNoise / totalSignal); else, div = NaN; end
end

function rows = iCollapseByMouse(rows)
if isempty(rows), return; end
[G, mouseU] = findgroups(rows.Mouse);
d23 = splitapply(@(v) mean(v,'omitnan'), rows.DivL23, G);
d5 = splitapply(@(v) mean(v,'omitnan'), rows.DivL5, G);
rows = table(mouseU, d23, d5, 'VariableNames', {'Mouse','DivL23','DivL5'});
end

function idx = iFindTimeIndex(iPara)
if iPara == 2, targetSec = 1.5; else, targetSec = 1; end
xsSec = seconds(TransferLearning.Xs);
[~, idx] = min(abs(xsSec(:) - targetSec));
end

function p = iSafeRanksum(a, b)
a = a(isfinite(a)); b = b(isfinite(b));
if numel(a) < 2 || numel(b) < 2, p = NaN; else, p = ranksum(a, b); end
end

function p = iSafeSignrank(a, b)
ok = isfinite(a) & isfinite(b);
a = a(ok); b = b(ok);
if numel(a) < 3 || all(a == b), p = NaN; else, p = signrank(a, b); end
end

function s = iStars(p)
if ~isfinite(p), s = ""; elseif p < 0.001, s = "***"; elseif p < 0.01, s = "**"; elseif p < 0.05, s = "*"; else, s = "n.s."; end
end

function out = iif(cond, a, b)
if cond, out = a; else, out = b; end
end

% ---------- 会话取法（同 FigS2B） ----------
function mice = iMiceWithStimulusInPhase(DS, stimulusName, phaseName)
T = DS.TableQuery(["Mouse", "Stimulus", "Phase"], Phase=phaseName);
if isempty(T), mice = strings(0,1); return; end
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus);
mice = unique(T.Mouse(T.Stimulus == stimulusName));
end

function sess = iFirstPureLWNaiveSessions(DS, excludeMice)
sess = iEmptySessTable(DS);
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Naive");
if isempty(T), return; end
T = iTidyTrialTable(T);
if ~isempty(excludeMice), T = T(~ismember(T.Mouse, string(excludeMice)), :); end
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sessDates = sort(unique(Tm.DateTime), 'ascend');
	for s = 1:numel(sessDates)
		Tss = Tm(Tm.DateTime == sessDates(s), :);
		if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
			sess = [sess; table(DS, mice(i), sessDates(s), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
			break;
		end
	end
end
end

function sess = iFirstTransferLWSessions(DS)
sess = iEmptySessTable(DS);
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Transfer");
if isempty(T), return; end
T = iTidyTrialTable(T);
T = T(T.Stimulus == "LightWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iFirstLightLearnSessions(DS)
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T), return; end
T = T(T.Stimulus == "LightLearnWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iFirstStimSession(DS, stim)
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T), return; end
T = T(ismember(T.Stimulus, stim), :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iLastStimSession(DS, stim, excludePhases)
sess = iEmptySessTable(DS);
T = iTrialTable(DS);
if isempty(T), return; end
T = T(ismember(T.Stimulus, stim), :);
if ~isempty(excludePhases) && ismember('Phase', T.Properties.VariableNames)
	T = T(~ismember(T.Phase, excludePhases), :);
end
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), max(Tm.DateTime), 'VariableNames', {'DS','Mouse','DateTime'})]; %#ok<AGROW>
end
end

function sess = iEmptySessTable(DS)
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS','Mouse','DateTime'});
end

function T = iTrialTable(DS)
vars = ["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"];
if any(strcmp('Phase', DS.DateTimes.Properties.VariableNames))
	vars(end+1) = "Phase";
end
T = DS.TableQuery(vars);
if isempty(T), return; end
T = iTidyTrialTable(T);
end

function T = iTidyTrialTable(T)
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
if ismember('Phase', T.Properties.VariableNames), T.Phase = string(T.Phase); end
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone), T.DateTime.TimeZone = ''; end
end
