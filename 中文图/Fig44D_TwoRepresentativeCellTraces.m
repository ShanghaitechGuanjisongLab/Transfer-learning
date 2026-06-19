xsSec = seconds(TransferLearning.Xs);

plotMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(plotMask);
[~, idx1s] = min(xsSec-1, [], ComparisonMethod='abs');

ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
[naiveRep, transferRep] = iPickRepresentatives(LAB, LAI, ALB, (xsSec >= -3) & (xsSec < 0), idx1s, 3); %[output:839089ef]

traceColors = TransferLearning.GroupColors(["Naive", "Learned", "Continual"]);
colorNaive = traceColors(1, :);
colorLearned = traceColors(2, :);
colorTransfer = traceColors(3, :);

f = figure('Name', '中文图44D 两个代表性细胞回合曲线', Units='centimeters'); %[output:858f9d83]
f.Position(3:4) = [9, 4]; %[output:858f9d83]

tlo = tiledlayout(f, 1, 3, TileSpacing='tight', Padding='tight'); %[output:858f9d83]

ax1 = nexttile(tlo, 1); %[output:858f9d83]
iPlotTrialSet(ax1, xsPlot, naiveRep.Signals(:, plotMask), colorNaive); %[output:858f9d83]
title(ax1, sprintf('Naive\nCell %u', naiveRep.CellUID)); %[output:858f9d83]
ylabel(ax1, 'z-score'); %[output:858f9d83]

ax2 = nexttile(tlo, 2); %[output:858f9d83]
iPlotTrialSet(ax2, xsPlot, transferRep.LearnedSignals(:, plotMask), colorLearned); %[output:858f9d83]
title(ax2, sprintf('Learned\nCell %u', transferRep.CellUID)); %[output:858f9d83]
ax2.YAxis.Visible = false; %[output:858f9d83]

ax3 = nexttile(tlo, 3); %[output:858f9d83]
iPlotTrialSet(ax3, xsPlot, transferRep.TransferSignals(:, plotMask), colorTransfer); %[output:858f9d83]
title(ax3, sprintf('Continual\nCell %u', transferRep.CellUID)); %[output:858f9d83]
ax3.YAxis.Visible = false; %[output:858f9d83]

allAxes = [ax1, ax2, ax3];
for ax = allAxes
	ax.FontName = 'Segoe UI Emoji'; %[output:858f9d83]
	ax.TickDir = "in";
	xline(ax, 0, '--', 'LineWidth', 2);
	xline(ax, 1, '--', 'LineWidth', 2);
	xlim(ax, [-1, 2]);
end

xlabel(tlo, 'Time (s)'); %[output:858f9d83]

ax1.XTickLabel(ismember(ax1.XTick, [0, 1])) = {"💡", "💧"}; %[output:858f9d83]
ax2.XTickLabel(ismember(ax2.XTick, [0, 1])) = {"🔊", "💧"}; %[output:858f9d83]
ax3.XTickLabel(ismember(ax3.XTick, [0, 1])) = {"💡", "💧"}; %[output:858f9d83]

MATLAB.Graphics.UnifyAxesLims(allAxes, @ylim); %[output:858f9d83]

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig44D_TwoRepresentativeCellTraces.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath); %[output:858f9d83]
fprintf('Wrote: %s\n', svgPath); %[output:4aae92ea]

assignin('base', 'Fig44D_NaiveRepresentative', naiveRep);
assignin('base', 'Fig44D_TransferRepresentative', transferRep);

function [naiveRep, transferRep] = iPickRepresentatives(LAB, LAI, ALB, baseMask, idx1s, kSigma)
naiveCandidates = iListNaiveCandidates(LAB, LAI, baseMask, idx1s, kSigma);
transferCandidates = iListTransferCandidates(ALB, baseMask, idx1s, kSigma);

bestScore = -inf;
naiveRep = struct();
transferRep = struct();
for iT = 1:numel(transferCandidates)
	tCand = transferCandidates(iT);
	naiveMeans = [naiveCandidates.Mean1s];
	maxOtherTrial1s = max([tCand.LearnedV1Selected(:); tCand.TransferV1Selected(:)], [], 'omitnan');
	naivePeak1s = arrayfun(@(c) max(c.V1Selected, [], 'omitnan'), naiveCandidates);
	validNaive = naiveMeans < tCand.TransferMean1s & naiveMeans < tCand.LearnedMean1s & tCand.TransferMean1s < tCand.LearnedMean1s & naivePeak1s > maxOtherTrial1s;
	if ~any(validNaive)
		continue;
	end
	idxNaive = find(validNaive);
	for iN = reshape(idxNaive, 1, [])
		nCand = naiveCandidates(iN);
		score = nCand.Score + tCand.Score + 2 * (tCand.LearnedMean1s - nCand.Mean1s) + (tCand.TransferMean1s - nCand.Mean1s);
		if score > bestScore
			bestScore = score;
			naiveRep = nCand;
			transferRep = tCand;
		end
	end
end

if ~isfield(naiveRep, 'CellUID') || ~isfield(transferRep, 'CellUID')
	error('Fig44D:NoOrderedRepresentatives', 'Cannot find representatives satisfying Naive 1 s mean < Transfer 1 s mean < Learned 1 s mean.');
end
end

function candidates = iListTransferCandidates(DS, baseMask, idx1s, kSigma)
Learn = iRepresentativeSessionNTS(DS, struct('Phase', 'Learned', 'Stimulus', 'AudioWater'), "latest");
Tran = iRepresentativeSessionNTS(DS, struct('Phase', 'Transfer', 'Stimulus', 'LightWater'), "earliest");

commonCells = intersect(unique(uint64(Learn.CellUID)), unique(uint64(Tran.CellUID)));
if isempty(commonCells)
	error('Fig44D:NoTransferCommonCells', 'No common cells across Learned AudioWater and Transfer LightWater sessions.');
end

candidates = repmat(iEmptyTransferCandidate(), 0, 1);
for cellUID = reshape(commonCells, 1, [])
	rowsL = uint64(Learn.CellUID) == cellUID;
	rowsT = uint64(Tran.CellUID) == cellUID;
	sigL = double(Learn.TrialSignal(rowsL, :));
	sigT = double(Tran.TrialSignal(rowsT, :));
	if size(sigL, 1) < 3 || size(sigT, 1) < 3
		continue;
	end
	actL = iActiveTrials(sigL, baseMask, idx1s, kSigma);
	actT = iActiveTrials(sigT, baseMask, idx1s, kSigma);
	if sum(actL) < 3 || sum(actT) < 3
		continue;
	end
	v1L = sigL(:, idx1s);
	v1T = sigT(:, idx1s);
	idxPickL = iTopK(v1L, actL, 3, 'descend');
	idxPickT = iTopK(v1T, actT, 3, 'descend');
	learnedMean1s = mean(v1L(idxPickL), 'omitnan');
	transferMean1s = mean(v1T(idxPickT), 'omitnan');
	if ~(learnedMean1s > transferMean1s)
		continue;
	end
	rep = iEmptyTransferCandidate();
	rep.CellUID = uint64(cellUID);
	rep.Mouse = string(Learn.Mouse(find(rowsL, 1, 'first')));
	rep.LearnedDateTime = Learn.DateTime(find(rowsL, 1, 'first'));
	rep.TransferDateTime = Tran.DateTime(find(rowsT, 1, 'first'));
	rep.LearnedTrialUID = uint64(Learn.TrialUID(rowsL));
	rep.TransferTrialUID = uint64(Tran.TrialUID(rowsT));
	rep.LearnedPickedTrialUID = uint64(Learn.TrialUID(find(rowsL))); rep.LearnedPickedTrialUID = rep.LearnedPickedTrialUID(idxPickL);
	rep.TransferPickedTrialUID = uint64(Tran.TrialUID(find(rowsT))); rep.TransferPickedTrialUID = rep.TransferPickedTrialUID(idxPickT);
	rep.LearnedSignals = sigL(idxPickL, :);
	rep.TransferSignals = sigT(idxPickT, :);
	rep.LearnedV1Selected = v1L(idxPickL);
	rep.TransferV1Selected = v1T(idxPickT);
	rep.LearnedMean1s = learnedMean1s;
	rep.TransferMean1s = transferMean1s;
	rep.Score = learnedMean1s + transferMean1s;
	candidates(end + 1) = rep; %#ok<AGROW>
end

if isempty(candidates)
	error('Fig44D:NoTransferRepresentative', 'Cannot find a transfer-group cell whose Learned 1 s mean exceeds its Transfer 1 s mean while keeping 3 active trials in both sessions.');
end
end

function candidates = iListNaiveCandidates(LAB, LAI, baseMask, idx1s, kSigma)
joinedLAB = iRepresentativeSessionNTS(LAB, struct('Phase', 'Naive', 'Stimulus', 'LightWater'), "earliest");
joinedLAB.Source = repmat("LAB", height(joinedLAB), 1);

badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
qNaiveLAI = struct('Phase', 'Naive', 'Stimulus', 'LightWater');
qNaiveLAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badNaive);
joinedLAI = iRepresentativeSessionNTS(LAI, qNaiveLAI, "earliest");
joinedLAI.Source = repmat("LAI", height(joinedLAI), 1);

joined = [joinedLAB; joinedLAI];
allCells = unique(uint64(joined.CellUID));
if isempty(allCells)
	error('Fig44D:NoNaiveCells', 'No Naive LightWater cells found.');
end

candidates = repmat(iEmptyNaiveCandidate(), 0, 1);
for cellUID = reshape(allCells, 1, [])
	rows = uint64(joined.CellUID) == cellUID;
	sig = double(joined.TrialSignal(rows, :));
	if size(sig, 1) < 3
		continue;
	end
	act = iActiveTrials(sig, baseMask, idx1s, kSigma);
	v1 = sig(:, idx1s);
	neg = isfinite(v1) & (v1 < 0);
	if ~any(act) || ~any(neg)
		continue;
	end
	idxPick = iPickNaiveTrials(v1, act, neg);
	if numel(idxPick) < 3
		continue;
	end
	rep = iEmptyNaiveCandidate();
	rep.CellUID = uint64(cellUID);
	rep.Mouse = string(joined.Mouse(find(rows, 1, 'first')));
	rep.DateTime = joined.DateTime(find(rows, 1, 'first'));
	rep.Source = string(joined.Source(find(rows, 1, 'first')));
	trialUID = uint64(joined.TrialUID(rows));
	rep.PickedTrialUID = trialUID(idxPick);
	rep.Signals = sig(idxPick, :);
	rep.V1Selected = v1(idxPick);
	rep.Mean1s = mean(v1(idxPick), 'omitnan');
	rep.IsMeanInactive = iIsMeanInactive(rep.Signals, baseMask, idx1s, kSigma);
	rep.Score = max(v1(act), [], 'omitnan') - min(v1(neg), [], 'omitnan') + range(v1(idxPick));
	if ~rep.IsMeanInactive
		continue;
	end
	candidates(end + 1) = rep; %#ok<AGROW>
end

if isempty(candidates)
	error('Fig44D:NoNaiveRepresentative', 'Cannot find a Naive LightWater cell with at least one active and one negative-1s trial in the same session.');
end
end

function joined = iRepresentativeSessionNTS(DS, queryStruct, pickMode)
T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex"], queryStruct);
if isempty(T)
	joined = T;
	joined.TrialSignal = zeros(0, numel(TransferLearning.Xs));
	joined.CellUID = uint64.empty(0, 1);
	return;
end
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
if pickMode == "latest"
	DT = groupsummary(T(:, ["Mouse", "DateTime"]), "Mouse", "max", "DateTime");
	DT.Properties.VariableNames{end} = 'PickedDateTime';
else
	DT = groupsummary(T(:, ["Mouse", "DateTime"]), "Mouse", "min", "DateTime");
	DT.Properties.VariableNames{end} = 'PickedDateTime';
end
T = innerjoin(T, DT, 'Keys', 'Mouse');
T = T(T.DateTime == T.PickedDateTime, ["Mouse", "DateTime", "TrialUID", "TrialIndex"]);

ntsCell = DS.QueryNTS(queryStruct, UniExp.Flags.ZScore, 1:24);
nts = ntsCell{1};
joined = innerjoin(nts, T, 'Keys', 'TrialUID');
joined = sortrows(joined, ["Mouse", "DateTime", "TrialIndex", "CellUID"]);
end

function mask = iActiveTrials(sig, baseMask, idx1s, kSigma)
baseMu = mean(sig(:, baseMask), 2, 'omitnan');
baseSd = std(sig(:, baseMask), 0, 2, 'omitnan');
v1 = sig(:, idx1s);
mask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end

function idxPick = iTopK(values, mask, k, direction)
idx = find(mask);
v = values(idx);
[~, ord] = sort(v, direction, 'MissingPlacement', 'last');
idxPick = idx(ord(1:k));
end

function idxPick = iPickNaiveTrials(v1, act, neg)
idxAct = find(act);
[~, ordAct] = sort(v1(idxAct), 'descend', 'MissingPlacement', 'last');
idxNeg = find(neg);
[~, ordNeg] = sort(v1(idxNeg), 'ascend', 'MissingPlacement', 'last');
idxPick = unique([idxAct(ordAct(1)); idxNeg(ordNeg(1))], 'stable');
idxPick = idxPick(:);
remain = setdiff(find(isfinite(v1)), idxPick, 'stable');
if isempty(remain)
	return;
end
[~, ordRemain] = sort(abs(v1(remain)), 'descend', 'MissingPlacement', 'last');
extraIdx = remain(ordRemain(1:min(2, numel(ordRemain))));
idxPick = [idxPick; extraIdx(:)];
idxPick = idxPick(1:min(3, numel(idxPick)));
end

function iPlotTrialSet(ax, xsPlot, sig, colorMain)
hold(ax, 'on');
trialColor = 1 - (1 - colorMain) * 0.45;
for i = 1:size(sig, 1)
	h = plot(ax, xsPlot, sig(i, :), '-', 'Color', trialColor, 'LineWidth', 0.5);
	setappdata(h, 'TransferLearningPreserveLineWidth', true);
end
hMean = plot(ax, xsPlot, mean(sig, 1, 'omitnan'), '-', 'Color', colorMain, 'LineWidth', 1);
setappdata(hMean, 'TransferLearningPreserveLineWidth', true);
ax.YTick = [];
end


function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
if isempty(T)
	mice = string.empty(0, 1);
	return;
end
mice = unique(string(T.Mouse));
mice = mice(~ismember(mice, string(excludeMice(:))));
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
T = DS.TableQuery(["Mouse", "BlockUID"], Phase=phaseName);
if isempty(T)
	badMice = strings(0, 1);
	return;
end
Tr = DS.Trials;
TrStim = string(Tr.Stimulus);
TrBU = uint64(Tr.BlockUID);
T.Mouse = string(T.Mouse);
blkBU = uint64(T.BlockUID);
mice = unique(T.Mouse);
bad = false(size(mice));
for i = 1:numel(mice)
	bu = blkBU(T.Mouse == mice(i));
	rows = ismember(TrBU, bu);
	bad(i) = any(TrStim(rows) == "AudioWater");
end
badMice = mice(bad);
end

function dt = iNormalizeDateTime(dt)
if isdatetime(dt)
	if ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
	return;
end
if isduration(dt)
	dt = datetime(dt);
else
	dt = datetime(dt, 'ConvertFrom', 'datenum');
end
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function tf = iIsMeanInactive(sig, baseMask, idx1s, kSigma)
meanTrace = mean(sig, 1, 'omitnan');
baseMu = mean(meanTrace(baseMask), 'omitnan');
baseSd = std(meanTrace(baseMask), 0, 2, 'omitnan');
thr = baseMu + kSigma * baseSd;
tf = isfinite(meanTrace(idx1s)) && isfinite(thr) && (meanTrace(idx1s) <= thr);
end

function rep = iEmptyTransferCandidate()
rep = struct( ...
	'CellUID', uint64(0), ...
	'Mouse', "", ...
	'LearnedDateTime', NaT, ...
	'TransferDateTime', NaT, ...
	'LearnedTrialUID', uint64.empty(0, 1), ...
	'TransferTrialUID', uint64.empty(0, 1), ...
	'LearnedPickedTrialUID', uint64.empty(0, 1), ...
	'TransferPickedTrialUID', uint64.empty(0, 1), ...
	'LearnedSignals', zeros(0, 0), ...
	'TransferSignals', zeros(0, 0), ...
	'LearnedV1Selected', zeros(0, 1), ...
	'TransferV1Selected', zeros(0, 1), ...
	'LearnedMean1s', NaN, ...
	'TransferMean1s', NaN, ...
	'Score', NaN);
end

function rep = iEmptyNaiveCandidate()
rep = struct( ...
	'CellUID', uint64(0), ...
	'Mouse', "", ...
	'DateTime', NaT, ...
	'Source', "", ...
	'PickedTrialUID', uint64.empty(0, 1), ...
	'Signals', zeros(0, 0), ...
	'V1Selected', zeros(0, 1), ...
	'Mean1s', NaN, ...
	'IsMeanInactive', false, ...
	'Score', NaN);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:839089ef]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID       MustWarn   \n    ________    ______________\n\n      111       \"2\/5层亮度反相\"\n"}}
%---
%[output:858f9d83]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAVQAAACXCAYAAABKmaMbAAAQAElEQVR4AeydCXhV1bWAV0ISCaMghMFgEcUJLHV8IFUcKB20fM9+WktVHKgDbX1VwQkqGvqJtkifiIq1QCs429eidaiIQBwYVFRqwKniQERImAkgSYB3\/p3scHLuPObcexe67j5n77WntXP\/rD2ck\/x9+k8toBZQC6gFkmKBfNF\/agG1gFpALZAUCyhQk2JGLUQtoBZQC4g0A2q2GaSiokJmzZoldXV1pmvcI+bG9fHPf\/5TFi9e7IrRy3RagDFBUl1nVVWVzJ07N9XV5ET5n3\/+udxxxx1y8803y8KFC6Puc21trThza0nkOzd\/\/nxBoq40jYpZDdR169ZJeXm5EWzKPcK1W3784x\/LKaec4o7S6zRagDFB0lilVpWABT7++GN56qmn5Prrr5e77rpLTj311KhKq6mpkWnTpsmOHTskW79zWQ1URvncc8813md1dTW3RpYvXy7Tp0+X3\/72t\/L666+b33YvvfSSTJkyRTZt2iRr1qyRBx54QF577TWZOHGi3H777bJgwQKTVz9SbwGv3V944QX5y1\/+IjfeeKPwZcY7+dWvfiVPPPGEPPzwwzJp0iTzRX3wwQeFLy33jO\/48eNl69atcvfdd8tDDz1kxpwvc+p7kN01LFmyRH74wx9KcXGx6WhBQYF88MEHxlt92BmPcePGyfbt2wPGZunSpeZ7NHv2bHnxxRfN946xvNnxcplJ8l1bu3at+R5SMGmI9\/tKml8lNFD92uIY29WuXTsZPnx4s6net7\/9bTnhhBOka9eu5gtKka1atZKjjjpK3n\/\/fXnrrbfkxBNPNFOZo48+2sS\/8cYbqKmk2AL19fUBdj\/ttNPk8MMPN1\/gL7\/80rTgnHPOkZ\/97GeSl5cnZ599tlx22WXG83nnnXdkz549csghhwhjumzZMmnTpo1ceeWVRueAAw4w+fUjfgts2LBBOnbs2KwAlsxGjRoll1xyiQwaNEhWrFgRMDbHHnusnHnmmTJy5EgpLCxsyj9kyBC5\/PLLpW3btrJ58+ameHsR7Ptq0\/wWZj1QMfiAAQOELxK\/6bj\/61\/\/KnxxGUjiiUNOPvlkWblypaxfv16OPPJI4Tfv8ccfb34IfvOb36CikmILAEO33X\/5y18KnmdJSUmzqaX9QgLN\/Pz9P8as0R166KFy0kknyTXXXCO9evUyY0+zd+\/ebWDLtUr8FsC+3jVvbOv+LlG6d2yICyZ2LEmzY8k6K\/dIqO8raX6T\/T+JfmtZEtuTl5cnTP2BJcUWFRXJq6++Ko888ojwg0Ac0qVLFzNVwbvhNzBe6owZM+T5558XpivoqKTGAnPmzBGmimwaue3+5ptvml9+LLkwxY9Ue\/\/+\/eXf\/\/632fR48sknpXPnzuYX5H333WfGm1+kkcrQ9PAWGDZsmJnF4WTccsstZvp+xhlnmGUXpvzM8r7zne8EFNK6dWvZtm2bzJs3r2mj2KvUoUMHk8YvUTveob6v3rx+uI8SqH5oauxtGDp0qCDkbN++vbB2wz3TEtZtWFtjqkEckpeXJzfddJOZQpKHH5w777zTTBW5Jk4l+RbA9nwRWfu84IILBFtbu7NWx1iNHj1a+OWGrhVacuGFFwpTSZZ2xowZI927d5c\/\/OEPwvTz17\/+tXTr1s2AmuuysjJBn3wq8VsAW992220ydepUYZwYI5bGJk+eLHy3+MWIDrZ2jw1OCmPwk5\/8xKzB2nEkpDWM38EHHyze8aZM4rzfV\/L4TbIaqH4ztrZHLaAWyG4LKFCze3y1d2oBtUAaLRAPUNPYPK1KLaAWUAtkjgUUqJkzVtpStYBawOcWyBqgcu5twoQJwq6j90gHY8ABYeTRRx81Z02JQzjXyNMebGTYw\/8c3WFnn0Pk6HCEg8Pm9tgVh8fZheQgMgea0VGJzwLxjhtjdc8995hD\/RwGp3YbRzy7yd5xs+lsftk85FOJzwI6doF2SxiogUWmP4annThew84jXxZ2HKNtRY8ePeSGG26Q73\/\/++b4x65du+Tee+8VyrNHqniKg2M79tAxR6i+9a1vydVXX22OgERbl+o1t0Ai48ZTOldddZWMGDFCHnvsMWHcOMVx0UUXybXXXiscv\/GOmzdP89boXSwW0LELbq2MBypeCIDjyRkOEufl5ZknZPAo8SAjPTbKQWIeN\/3kk08ESPKlu+666+SII44Q+48jOIMHD7a30rNnT3MO7+WXX5Y+ffo0xetF9BZIdNw4lsNYcZD\/oIMOks8++0w4r\/jee+\/JqlWrhPK94+bNE31rVdNtAWybyHfOOw7ZNHYZD9SdO3cKXyoeL7SDzuFt3oCDp3rUUUdJuMdGycsSweeffy579+61RYQN0WNZgLcX8Ww4P2BhM2higAUSHTcK5Jcgh\/fPO+888wQUvxgHDhxonhfnEVR0vOLO403T++gsoGMX2k7JBWroelKWwvO\/HNpfvXp1Ux3Azv34Ik90NCV6LvByeMoDb4Yvmyc56C2wvvTSS4XD4l999ZVs2bIlqJ5GhrZAouPG+h3TTtbMGX9mJzwSiffD7II1VG\/t3jzedL2PzgI6dqHtlPFApWu8JIO3EbEWyhuJmPK5H19keoJeMGHzaebMmebpmt69ewdTCYjr16+feXvR\/fffb168wRc6QEkjIlogkXFjg5AXn7Bu\/uc\/\/9m8DIUZA2+Zwjtl\/L0N8Oaxa+RePb2PbAEdu+A2ygqg8tYoNpJ49I3d+uOOO67Z44s8ysjjbYh9HM6agzcV4Z3yCB16Nt6rR16EdN6Ygz6bHzwSiTdMvEpsFkhk3HhkmJMWbEJeccUVgmc6duxYYTx4TNH+kmPMEFrmzeN9mQc6KtFZQMcuuJ1SCNTgFWqsWkAtoBbIVgsoULN1ZLVfagG1QNotoEBNu8m1QrWAWiBbLRAXUHltV4wGSYn6s88+m5JyYy3UL+2Itd0tpe8ne\/mpLS01HrHU6yd7+akt1oYKVGuJBEI\/DmwC3Ul5Vj\/Zy09tSbnhk1CBn+zlp7ZY08YFVJtZQ7WAWkAtoBbYb4EWAer+6vVKLaAWUAtkjwUUqNkzltoTtYBaoIUtkNFA5W8MtbD9TPV+aYdpTAZ8+MlefmpLBgyd+btefmmnH8eu5YHql9HRdqgF1AJqgQgWWLX0I0FCqSlQQ1lG49UCagG1QKMFqis3ytP\/+6wQIo3RAYECNcAkGqEWUAuoBfZbAIAuevoN6TfoSBly3ilStWbD\/kTPlc+A6mmd3qoF1AJqgRa0ANN7YHr6+YPlmIFHmpYAVuLNjedDgeoxiN6qBdQCagEsADRXLvlIgGnX0oOIMtK1tIsQb248HxkN1F\/84hee7rTMrV\/a0TK9j71WP9nLT22J3ZLpz+Ene6WqLYCU9VKse\/51w8UNU+K4L+nVJejmlJ+BSttV1AJqAbVAWizAWqkbpHaKH6xyoBosXoEazCoapxZQC+ScBbxrpeEMAGyDTfsVqOGspmlqAbVATlig\/G+LzS5+KM8zmBGCbU5lDFCDdUjj1AJqAbVAohZgqs9RKLzORMtSoCZqQc2vFlALZLQF2IRiJz\/WTgBg77RfgRqrFVVfLaAWyBoL4J3SmVim+uhb8U77MxOotjcaqgXUAmqBBCzARhSeZrxFePMqUOO1pOZTC6gFMtoCTPU5Txqvd2o774aqAtVaRUO1gFogZyzAVJ\/1T57NT2answCoyTSHlqUWUAvkggWqKzeYY1LJ7mtGA9UvL5j1SzuS\/cORqvL8ZC8\/tSVV9k5muX6yVyJtwTvlmfxk2oayMhqodEBFLaAWUAvEYoHqyo2SjLXTYHVmG1CD9VHj1AJqAbVAkwXYjHJvJDUlJOFCgZoEI2oRagG1QGZYAO+Ulia6s08ZwUSBGswqGqcWUAtkpQVS6Z1isIwGaqT3IdLBdIhf2pGOviajDj\/Zy09tSYZtU12Gn+wVa1tS7Z1i+4wGKh1QUQuoBdQC0Vgg1d4pbVCgYgUVtYBaIKstkA7vFAPmDlDprUpOWODpT7cJUrmjPif6q50MbwE800Sf2Q9fw\/5UBep+W+hVFlhgyfpdpheDureRp\/6zVey9idSPnLMAMMU75fV8qdrZdxtVgeq2hl5ntAXwSJes2ynnH9ZBStsWyE8P7yiVNXUKVcnNf7yFn57zvH46YEpdOQpUuq6STRYApnikQNT2C6gCV4WqtUhuhHil\/LE9IJqqA\/yhLKlADWUZjc8oC+CZMs0Hot6GA1XidPqPFbJbgKmd4qcbplhWgYoVVDLaAhaUg7oVh+0H0A2roIkZawFAildKB9I5xac+tyhQRdz2iOm6omaJPP71lJjyqHJyLQBMAaX1QkOVDmzxYNEPpaPxmWkBYNqSXqnbakGBWldXJ9XV1ULoVvbb9YwZM1q0Se9vX2zqn\/TA7SbUj+gskKxxA47A1L1uGq4FQBV9t06y2uIuM5uv\/WSv639xg\/jBK3WPdwBQa2pqZPLkyTJ79mxZtWqVPPzww7Jp0yZ3Hr12LIB32u2AXnJs+1OkqnaNE6P\/p9MCbpgGWzcN1Rb1UkNZJrPiW8orXVG+MqyhAoCKZ3rYYYfJ4MGDJT8\/XwoLC2Xr1q2SK\/+i7ScQ7d\/uFOnfbpBYTzXavKqXmAXihSm1BvNSiVfJHAsAU1qbqrVSoInMnvikIGPOmiDI0IKfOOGtjkwQ0mmDVwKAWlpaKmvWrJG5c+fK008\/Le+\/\/750797dmy+n76tqK03\/S4pKTYinisdqbvQjpRZIBKa2YdF4qRzD4mmrP67YKG6hfluOhum3AGulSLJ38AEnsh+atxqYAs4BQ\/oJMnLCBTLlld+ZTo85qyHd3Lg+AoC6a9cuOfnkk+XGG2+Ua6+9ViZNmiTFxeF3T13l5cRlRc1iwTu1nS0p6mUvNUyhBSzMrh9wkDm4H29V1ksFmIAzWDmstZa2KxTqcoueaQ1mrfTF4Z0mE6YAE5Ai9MJCc3793wWZ8spEIc4KYLVx5EHIZyUAqEzzP\/zwQ\/nmm2+kU6dOkpeXZ3VzLwzSY693iopO+7FC6gSQ4iVSAzAkTEQsRNfU1JnHU71g5R6YBqvLeLfrdootI5F2aN7YLABMydG19CCChAQQIniaFGSBSQg0iQsn6E1xvFXKAMpWNwCoe\/fulc2bN8t9990n48ePl9\/\/\/veybds2q++rMNb3ISaj8V7vlDJpB5tTFTVLuFWJYAHsFUGlKRmYcoOXGAxwpMUi5Wt3yiMfb5GSNg2Ppj53x\/UmOx4pILX1haqLDTALVZMxxz5iGbtkmoZpPn9Yz+2dxtoWwAcAhzproYS0DzBa4T4WAbxAldDmCwBqhw4d5LLLLpN+\/frJgAEDZPTo0UKczZDLYTDvNJftkeq+4wUyxQ4Ft2jrL3u7WvIfXGnkjGc\/k3HL1svIVyqN9OlQ2KwY6ovmTCserIVvswL0JiUWwDvtN+hIicY7BZZA0yt4o6QBUKbzhEgiDXbDlHICgIp3ev\/995t11OOPP954C5TzKAAAEABJREFUqtu3b0c3x0WkwrN26jaITvvd1kjONV4j4Iq3NAvSsrer5LYTS2Th8ENl0n91k9lnlZrrRWt3yMdbaxtepuKsl1JPtPUBedqnUMVqqRW8U2qw3ilQxNvctmm72W3nmjgEiBICSrxHr1iQUl4qJACoW7ZskWOOOUb69u1rpE+fPlJZ2bCrnYoGZFOZOu1P7miyxgm4Yi21rNEjLWsE6d6r+zlA7SqHdSySwzoUyUV9O8qQnm0MVD\/eslvKHH3qwTMFktHWl8tT\/2htlAw9vFM3TAEm3uaqJR8JIUIcYAWkFpp4j15JRnvClREA1K5duwqbUsuWLZOlS5eaY1O9evUKV0bOpK3fvUZKihqOSuVMp1uoo0z3ezV6jbE0ATiWeUBq8wNLIGjvgeoRBx7gALXKkWoTTXq0XicQjkXfVKAfMVkA75RpPgI0EQvNgWefaI4x7fdCJ5od+ZgqSLJyAFDbtWtnjkzV1taaR09vueUWIS7J9WZccayfct60seFBA6b9HPgPmqiRMVnAC79oMpc5nmZZI0xvO7FrsywWkmwquROOcLxWlgPIV+bkB5LU7dYJd231bfnhdDUtdgvgna79dJ3jiU4w50KBJ0AlvmbzDik8oEC2VG81AnxjryG5OQKAypNSzzzzjJx66qlG5s2bZ3b9k1tt9pZWUtTLWWvV3f5ERhjvlPxe+BEXSoBhWQiYksdCEvDZ3XxbD\/C1UD3z2c8lVq8TfepQSa4FAOSK8gq565KpUl25Qa6afKkBp31+39bGcgACZHmpNKGV6sqNTt6NVjXlYQBQOdjvrpX7DRs2uKNy8hrPE1hG6jxeqj6KGslK4dOBXyyQKnM8y7IQMAWanGFl+cBuONmyWaO1LQGqbFqxUTX4H6uFo1U2jbDM1FEtALd87U6imgQvlRtgTaiSHAvMf7Rcnp3+LzONn\/3RA8Iuf9WaDVLSq4uBZLtObQWQshyA8Cgq9xyvQoApYOXvSQFhYJucloUuJQCoPXv2NJtQnEOdOnWqfPHFF9K7d+\/QJeRISjigek2gm1Nei0R\/DwDRjtY7bQBdldlgAorktUJZT\/1nq7kFooAPoWxCwL15916Tzgdrqmxgnd6zrUxfucnAk\/I5clXmAHvJ+p2yZkedcPQqGFgpj3JilSXrd+mfafEYDZjOHP+IDBjS3wAVMAJJ\/jYU4ASgm77e7MklDmgbgHv+dcObjliRByEPYAW0ARmTFBEA1IKCAhk7dqyMHDlSLr74YmENlRekJKm+nCjGeqkVetA\/5vEGStaTjJQZqAG6hcMPNbv2bn0gBUzxTBEg6k7nGsgSemXB8N5y24klsmjtDnnkky0yrFc7efJ7vUwcdXH0yg1W8gNoyqNe7qMRdPGe0SU\/Ya4JoPQCjns2n4DplFcmCjoWpkARG+GJFrUuErfXiR55Aa7VQY94hGvAyrU7H7rRCGVbCaUfANSqqiqZO3eu8Bq\/cePGye23326uQxXQkvEz0vg+1HA7\/MHagZeqU\/\/gPx3B7GU1mYZHgku5M+XGayQPHiWeJddWABVgBnCUx3Eom+YOqWfw2MlBvUO83bsHdZfRx3Q2IKUM9AHzzcd1kU9G9DXnWRc50C1zlgMol3TqxTMOJ7SPdVweIuBdruQjfyZIuLGLtf2AjTyEeI5AjmuOQRE\/8JwTzftOvTAlDXni\/x43Xih5AB16xww8kqQmAcAAlpA60EXHfY8y+Umzwj1i78nL0kG1s5ZLHG2tdtZnyeuWAKDW19eb958uWrRIrrjiCjn66KPN26fcmXLtOpod\/iabNF7gpQLVaLxUykcas+ZsAGjwJsMZoNyBKVNupuV4km5d8luPj0dVARZQdet4r8OlUwYSCnicZ8WTLXOWA2y5ABKoRhL0gTSA5jrXBCgBJOAG8M6\/brgxARtQZlf\/oV8JcVYAoFHwfJCfKMrD+wynR1noo0vdrMUC4f2w3L95hQ6CHuWTFyE\/7SUk3QvWAKD26NFDSktLzbtQOeDfpUsX0XOomDR2AaqRvFSA+8rGJ6WiZrH5cyoLNj3lXOfeKQE8OiAUDnBljicITIGYG6aAFI+PESI\/AKQ8cx\/h70yhS71WnzyxCJ4s+rSNEEACylCCDm3Ec+Y6FwUQASrAZPtPHGumwHTUHRc5a6f9bFLEELhRVtcoXpqCDrrk4ZqNLkAJjKkIwCJcW+la2sVeNoXkpZymiMaLAKDm5eXJsGHDpHPnzsK0f+jQoTl\/DhXYRbPD32jTZgFeKpAM5oFWOGusAPesgy6QMzv\/VEb0GCO8FpANsFz7W1VADdAApGYGbLwBWGWOJwhMLcRIAoTkZd0VOCLEE0d5XEcS9BIBHG2ibZHqIZ16aCN18ouAuFwSwBkMptYzHT76BzL0wiEpNwlABKoIlXEPIIErQjxCfMNUf7\/3ij59wLMlHSEOCQAqkcjOnTtl3759XKo4FogPqOIAcpAjp0iDF7rf83TDtKRo\/9NXXANXQIyOU3XW\/w8U6SSgIfRKmeOZloWA6VPOLj7TbHdeQAVgQ8HZWz55AbA3Ptp7AM9jrWVOO8PloV294nj6K1yZmZQGTGkv4CJEAJOF6c0P\/8bxTPubdVHSWlKAJAJU8V5pO0KbaDOQxbslnTgrIYF60kknSfv27a2eL8NYX98VbyfYkAqXN1I7gCTeJ54n3iqg5Jo40oKVbZcL0A2WnslxXnsBMzy2YH0CUmVBYIquzWfBCZibpv4RpvrkR2xbqB\/gERetUB+C\/kV9DxTaWRYGqqzpzquscfSqZd6aGqH95M0ksfaKpc2ACG+OPG4AEc8GFNP8Ka\/8TgoPKDTnStGLRuJpSzTlenUAK78EAClrpqFgSr4AoPLu08WLF5s\/e8Kb+pcvX+7b96HSgXRJKPDFUj+eZ0lRL5OFa3MR5gMvlSWBMCoZn2SBZKHo7hBwKgsBU8CJF4p3SR5giLfqjiM+WqEcgEc54fKQjrD5BRCNrN8leKmjju4UMiv9nPnhZpn5wWYpNycDqgS4UlbITBmeYAFEN\/DyLExtvPVMgWnPw7oLh\/aBF\/p+FKBKH9x98bYzAKi8qf+5556Tu+66yzxyyt+XIs6bMVfuWfuM9Ax\/lLYwanieiLmJ8IEeUM1GL9V2HQjiHdp7G5Y5nl5ZDDAFbN6pvy0r2pCNJKAKrL15AB8QtfHs\/qMPwKmb+NK2hY732fCiFU4jWClz+nLInI8Er5T1VjbUOM\/KPULebBI8TwRPDkACIUL6aOPtBhQw5Y1Q1ZUNB\/LR8bPQDyRUGwOAiiJ\/U+rKK68UnpTijVPEqbSMBYAqywPZCFUgxZpiaduCZsYFQGUhYEoelPEoubaQA3DectCLVSwk3VClHkBrgU3dtlyu+YWADl4qwKTtnEawwj0PB3BmFh3ycnYWqJLGAwrEZboASzu1py92c4drd9rS594WO80HpqSzsw54uc5kCQAq66asn\/Iav1tvvVXY5W\/dunUm9zGhtlfULBZ23hMqJMHM1A9U96+\/ViZYYstnZwqMZweM3K0pc7y5sjAwBWx4hW6QAjV3GYleUx51AFVbjwGtB\/y2HvTpC\/cAk6eqeCiA8MuLj2x6yop0twBVnrpa5CwBlK9t\/n4At14mXLO2SDvtdNjCsbpyo3nSiTQ2cWaOf1R44Yn1TIlHhzOh4Tw\/9DJBAoDKuunBBx9s2t6qVSsDVP0TKMYcSf2IpbCSolJzrAqwkg\/Ic6wKwLIkQVymCQDC43N7lWVRwNT2E48UkNn7ZIeUDUSjrYdfDHiptIN8pm\/Ojj5LGsThiRN6ZUjPtuavCAzp2cablDH3wBQYAlFC23C8Uqb9K8pXytvz3pP\/+e4tATBFFz3ycp3pEgDUTO9QstvPDj9AS3a58ZRHO1gCYEOLEwIA1sK1omaJZApcv965R\/AAY4EpAOYMJ\/mAXTz2S2Ue2kQbbR30jTiADGC5t2nuEJ2i\/Dx3VMZc41kyxQeibiASf+81D5n3l\/7phr\/KzPGPOCBdaV5ywtv07TSfjqJLSBmEmS4K1DAj6HdAAVjgyoMBLAmE6YpvkqwXB0hoFF4pz+Wz882aIlNm4q3YpQHu8QJtPu79JrTP9s+2jfYj9j5YiPcaSSdYvpaMA4R4n0zjLUx5oQkyovcV5rV7eKW8DJrp\/ZRXJhqgetucTd4pfVOgYoUwkswd\/pDVJJhgwUqYYFEpzQ408OI6HdDwY8dmTFnjeik7395pL3BiygxwgJWfYYrhaB\/9M\/1cv0tYf+UeMddOHHpewevG+\/bG+\/UeCLphCkSHFvzEeKS0GYjiiSJcuz1S0q1QDtfZ4p3Sl4afbK5UAiyQKV5fQMN9GgFYAGPrVnlS5qyXLnI2Y6xXaiEERBE2hNAHpgAHWPm0W82axdopvwSItNN9pvzEs6FGv+gr6VboG\/209+kOARseZzT18mdH0LM7+MAUOXHYd+Te1+80XigQRSec2DqHnHdKOLWMS1OghhkygMo6ZRgVTYrSAoDEgnHj7j0OUKuEg\/DLq\/d7chQFRBF0gRAABjikZYKwVgpIvW0mHrDSH4CLPfjFYeFKekv0z4KNkM2lUGAlnfVS2uid4gPQu16YEPVTTtSRLceksIdbMhqoM2bMMBsx7HizKePuWDqvaUfy6suukgAG010AaSHzzOCxwrPvw0rbNXWWKS8gxVMzIO1WLEAGaVJKwUW6x47+GOB2b9jVp8\/YBzuloHsBRQJGt+Bd\/u5nd8sXq9YYIJIGOIEroRUK4kgU7yDlbfpM8dm9n\/LK74xXSj4EWKIbTuxyQdco3g4Vrpx0j124tti0jAYqnaioWSw8TcS1PUZECGQT3VTy7vC\/u61cEOpSaW4BvK3mMSJA4qn\/bBW8MgtT1k3R48XNQBR4AhgreHFAB51sFvqITegvfec+Vf0FdAhwtHUAQ44xsXHEdB2w8ijogV07CuDEC2Vab4V7AAhM0cMrneJsNLE+Stl4nJTNNfUA5GBwJd69kUWebJKMBirABHocJUJKinqZtzoxQOx8e9\/wRHy0UlGzRCyobZ5frzpdkMFL8+SaVWfIrMoyBaxjHDN9XbfTbMJwbcULU7tuOrpfZyeXCDBNJUhMJVn0AawAEsJ1MGARj6AD2BBrAuAIGIEoR5kA6a1PjJUfXj5UeG0eerysBGhyTflWKPPmH000f4EUmCKk2fJt2ayJAmTyk4d0twBl2kB6NkpKgAqMrAC9VBmuwuWdUgdQJfxn1UwHdIuEs5qsg+KxEh+tVDgwJZ8tj3wA9PgOp8t9xywyQty72xY1Ayw67zpeLGlJEl8XgwfKdBVPEy8UQNoGc4\/nhRdGHDAtc3b0eQSTt+0ztVeYYpnoBRBZAWYAC3ByjQAuWxp6QA7hGiFtzFkTzG48MAWKABDhHaSj7rjQTN+BLWCdcuX98vjv\/88IHiwgJg9C3XbqbsumfARoUiZC\/W7x6qKfTZJUoAIixP2GJLzEaKEK+JiqU0YkI57l2m8AABAASURBVFOm9U6t7l2rfyH3fTFW3twyTyb+52J5acMj5gkjPFfKtnrhQsql\/e7NKCD5jgPPy0tvl+M6DDEy7ZiFgrgBS7l4sLMcz5XrbBam+Hig9BGQAk4AyRSWONYG0UHKnB39srerzB+7G3VUJ7EARk8lNgsAKwRYMT2v211ngAf46mvrpW53vVkLRcdbMjBdUV5hvFGg6IYb10zb8VZJ61raxZT17PR\/NTtTShrwRhdQks9bTy7fJw2obgjiGeLdIUy9KxxPssLx+sIZ2qYzzQZo4XRJq3DKfPG373Jppt5Mw\/FMRznQe2PgPiEEqsCNdgDVightoDB+AdDmkqJSbo3Mqrxd8E6BqYlwfRB3\/\/VzDFynOZCl3pmO\/qwMgKr1MIGe7RLXTNkJSbfx7pA0gNmrXaFsr9srvJKOw\/msj5av3SlAFQ+VPIAU4aUh\/zr7W0TJG3ffYDaczE0Lf6TrnZrJ6OaK8pXGu8RbZFMIL5L1TAs961k2gHNlsyqJq67cYGCKNxoMhKxtrlr6kfFSWR9F5tf\/XZApjZtP2AsdO61vVkmab2hLmquMWF1SgGq9P8CFuGsFTDzNwxQaPTxAdzrXgI509MgPVNElPpjHassoymstTLMB2MkHDpN\/HL9GLi+9jSJN6IYb5QJqykSBkHLcQp3UTZvRQdzeKfeRhPrd9UbSJx340g\/q4j6UJDMeKOJhAj7gCESZvlMHcZyZJJ14wIo+wj36vMvzgpfXmONP5AGYhLxhCbB+urXWvK6O19ORxhNQlIOOPdjPtUr0FljheJfAlBxM2Vn3vGrypYKwFkpIHOAEtkAUfeBL3I+v\/oF5I34wmFIm8Xi2AJN7t7D5xP2mrzebN+qjx71KcwskDFTAVFLUSwBW86Kb3wFL9PAAARcgQ4P8gI4ptgULnuWDX44z0\/Z\/rJ8u\/9owR8iDPlLheKfoVzgeJ1PxCYfPkR+XjJKSogavkrIRN9wAVv2+WlMWkLblVDhl0SaEONpCOvUhsxxvE0DiiZIejbjrjQTJWY4nyy8EymW5gHZGyoNuIgIYyc8aJ+Gn22pl0dodckLXYqnds0+AIV4m6cAVgKKHp8lLkscuWWdgCSjtK+kAJk87cVAfXcCKPvekEUc5lMe1SuwW6HlYdwGcxe2LjReJp8m0GwGGeI0DhvQXwGnBClDJRxw1slRAGEooh+l8deXGABULWnQCEjXCWCAhoFY4QDOlOB\/Xffh94y0CBIQpuFeuqjhFFm9+Tr765lOzGw+wABiPd85ywAVYjnM2fn7Q5WI5uPVhRro5sP7HuukCYOesvVNsnc85G09b6zYKMN1Ut95pgZi\/GgoM8XYBJLrAjXVOFCiDsmjDnxxg1+2tFdZh8UpZpgD6hAjAZi0WYFMG+aMVYH5OySjTfiAZKt+sRpjSPpYLCNElD2lcJ1uAKc\/N4zn2ffwTGfyP1TJ95SYjQNBK\/oMrBRn5SqVJQ488g7q1ETdIve3j8VHACmgR7tGhXkLWWQlVYrcAfyKEt9ozNQdqiC0FjxEBmKT36NNd+OuhgJW\/1cTr8QCu1Q8Xkh94suGFAFcE0LbrtP\/scLgycjUtbqACK2CI94hHCXwwYkF+kbNpc7pZw8Szw3O8+pBJgpzbfbSsr11j4IjnCaze3DpPbv34ArHrn8CL6Tv5yH+Vk9eCBiACXeoi7N3mKAGmALnEAS9rnw0wHNRshx\/vEmC94aytUhZtQGj3F7s+kGDeNcCmTbSbvtK3SFJVW2mgXuF4vQh5ycMvGK\/XyT19oI+0Dz1C2kkbSQsH1VkOjMOlU14wAYrjlq03U3X+DhJwXDj8UEF4NyfCNcJ1Uas8WbOjzmwovXFuH\/N0E084BSs7VBxTfbxTvN5QOhof2QIA1Hqj4bTRA4oA9n+mXdmkyn3TTZgL8gNmQtRWOeuq7OgD5KLWhUSphLBA3EClPGCIx4cX+YYDK2AAIIpbtZOTnTVNwm8VHy0FeQ2QxfM8t9to41WSh7zAkTzkB6YVjtcLqPEQAR3XH+542+ShTPQBHcDNk3zBu8SzRLekqGHKL43\/iC8p6tUIuSVm2cCWRTuol7LcwANSeNYAjfSLe94ieLy0q7HYkEGFA1LbHupGgON655eI1+vk\/vgOp5u1Xm+BgJW6aQPt8aYTRxribrtXL9g9R5YAJS9ABoxMx\/EiAeeQnm3lsA5FwrWR\/Dzjjc4+s1RmnN7wjlzAiLDeynoqsAxWjzsOfU4CuOP0OnYLRAtESgaGeJV4mHiW3BMfi1AfYEUAOfex5M9F3biBCtgQvviA1Gs8QAhc8B7xHAEeQhxe5a3OuiewIT8gJX9FI0zRL2mEIx4nQl508XKZ5gPq9gWdhHjyhhLSKY\/0EgeutizaAaBpA2kAzg1SC3jSACP9oX3cB5MqxzslnvoIrQBH2ku7LQCBIDANZjebD5vQX\/Lgzdp4C1PajRBP24nnOpJU7aoXwAng2HRiKg4YycfRJ9Y42ZDi3qyhdisW4pmqE+JlIiatexvzlzvJHwqslE9Z5CdUSZ8FAKFdIlAYpsfucQOV5vGF54vPNUCxwAFaQAyAAaOSov2eI8ABZqxxHuysk5KffKx9Ug553frEWSEvXi5Apoz2rTrZpLAh5ZEXsYpcA0mAB9iAE\/1xg9TqEtIf9Okn916hP3jV3njuqYt2\/6n\/Ym6FpQ7OtJqbMB\/YhjYBTNSAJoClrbQboe2jSm8X4t3gRT+YAEPACOCAIjru5+yJtzqkhZMm3RBgBbJ4p5QXrhxNS50F8Czj8U5T16LsLjluoPJlRzAPQAQoXAMPQiCGcO0VdAAiediYIh1gEc91OEEnWt1w5ZBGG2g718DJ9od7r9AX6qXNNo\/V2Vj3tVAWOjbOG9JugIxnDrSpDx3KwgZWvMC2bcKrBZoWpu58vdscLXjA\/IKizFgEuCKx5PHqhgIrMMUT9urrvVogWy0QN1AxCF9qt2cJNIiPRtAFUHh1XIeDkbe8WHS9eb33rI9640LdUy8eNHkAIPBD0KcPhOEE6JLX6mA\/7htscIoQVjjrsNiU8q0eEMWrxVsFxBXO0ghp6FsZ2XNc07Ex0lpCvGDF8yWuJdqidaoFWsICcQPVfqkBTDQwCdY5AIUES0tHHO3m2JTtS7R1NixjNLyIBY+Vtdxo8lIfesASaHLdUFapgSG24B6blhTt30wDoni1eKvkJR9llRTtz8c18SLS4gEQZZqfqOfb4h3RBqgFYrRA3EDlC43EWF9S1WfMmJFweXiN8RRC3\/GwkdkzH4m6CPKVOLAkH9ehMpKGDh4sEAX6QJi8pIXKlwnxyRi3ZPXTT21JVp9SWY6f7OWntlibxw1UW0Cmh8CJtc1I\/QBoFmxWt6TRQ7T30YbUSd5I+ujgsZY4AAaswJ+8kfJpulpALdAyFsh5oGJ2QAUwufYK8YiFrg29eqm8B6KAlTDWelRfLaAWSJ8FFKiOrQGVG5RsNAFRxMazrgnUOFdLvJNN\/1cLqAXUAs0soEBtNAdeKlN61ikrnJ32xmjzCCvAtfdMv+11skIAjiSrPC1HLaAWaBkLZDRQk\/k+RKDJESTriTbcDwoYFeLxWisajy6hkEg7ACknBRB3mZQbToB\/LPqmLJ98JGKvZHfBT21Jdt9SUZ6f7OWntlhbZzRQbSeSFZY4m0zRlIU3G41eNDoVjjfMMoLd0a9wgTpUfiBMmhfsxKmoBdQCLWcBBWoctg\/mpdpiLOzsfaSQc7B4xsCcNVp28\/E+w+WrcCBMHsAOVMPpappaQC2QPgsoUOO0NTBzZ61wPEu7\/sq1Oy3UNfDFOwWmVgeolhT1anrvq413h0C4xPGmATvtiLY+dxkieqcWUAsk2wIK1DgtCsysd7h9z2bhGrgBRK6jKbai0dP06lI2nmqFA2lvmoWwjS9x4BttfTaPhmoBtUBqLKBATcCuABSvlCLYzAKEXBMfDIakWQGMXJc4niahV0pCgLLCA+ESJ3809XnL13u1gFog+RZQoCZgUwDKZpL3NYLER\/IavWD0NoMyvKAMBWF0I9XnLd9zr7dqAbVAEiygQE3QiHiIwYrwwtCtEwqMbh2uvaAMB2Hqs+WSV0UtoBZIvwUUqCmyuYVhMMiFA6O3OYCyonEt1W5GeXW4p75QcCddRS2gFki9BTIaqJ999lnqLRRFDaHaAQzZXLJFAEYkHBitrg0BJdN5jlJxIsDGBwunTp0aLLopLlK6VUx1GMpeqa43WPl+aUuksYmUHqxvqYjzi73om1\/a4h6buIA6cOBA6dOnT4sLBvVzO4Z\/+0Kz+z\/phTHmDwU+++rfBOOPH3x\/TLZbMOstAcKTrpwWNt+yZcv4OQsppPvZXi3RNr\/8DDE2IQfOSSC9JezjrdMv9qJdfmkLY+MMkfk\/LqA+9thjsnr1apUobMCm1fDTzjPvBBj3oyny5\/FPxGw38nCKYP7fXgubl3Exoxrig3QdN3\/+3DI2IYbNRJOuY+f\/sYsLqGaE9SMqC7CuybQ9KmU\/Kmmb1AJqgagtoECN2lSqqBZQC6gFwltAgRrePpqqFlALqAWitkBmArWqXGTFGJHK2SI7v4i6s6lS\/N9Fq2Xel\/WpKt5H5WZXU3TcYhxPH33v\/Dp2cQF137598tprr8ny5ctjHJEkqFcvFllVJtJmu0iPH4nUv+nI1iQUHF8RX27+RirbdpOl+wpk6+74ykhGLnY8J02aJNOmTZPt2x3bBCm0RcetsT0bN2yUBfMXypefrTUx9725y4Tp\/vDLuNHvjBg7H33v\/Dx2cQF11qxZsmDBAtm8eTM\/D+mV6nKR4mLHM80T+WyKSN1nzvUH6W2Dq7bH3t0gecVtRRxL\/v0rV0KaLw888EC56aab5IQTTpBnnnkmaO0tOW5vvvmOvPP2Cnn3rX9LYV6xtGnbRjbu2iv9O+2TaW\/uDNreVEb6Zdzoo9\/HjjaKj753fh47BwPGXDF9jBo1SgYPHhxTnqQpt+stsmefI86XcHu1yKb\/iBR0TlrxsRS0fPV2WXfAQSJ7RVo5Gb8uFPkiuHPopKb2\/06dOkmrVq2krq5OuA5WW5LHLVgVoePq90lRQWtpV9zRaWeh7N27T\/bW1sqCrW2kdi\/WC5012Sl+Gjf6xnj5euxopE++d34fu3xsFUnwROfNmycLFy6UXbtaZorW1MZDRoh0PNrxSreL1FSJHHCsSJsjmpLTefHCW7tk3x7HW3aAum+PSH4rkblfOrBPZyNcdS1evFjeeecdGTZsmIn107jl5xdIQUGh5DtSkF8gtd\/Uy46NG6XjznrZubnWtDddH34bN\/rt57GjfeKT753fxy4qoPIblC\/pGWecIcVMt42FW\/CjnzPV35cnUthB5JBrWqwhtXWdJX+DyB7nd8w320TqHdnpOM0t0aD58+fLhg0b5Nprr5XCwkLTBD+N2z7nl86eunwpbNUA1vq6PdK6U4kU7Ngqq+sa2itp+uencaPLfh872mjEB9\/rXpuyAAADxklEQVQ7v49dvjFUhn1843jJ8z74rry\/Y2SLtry0uEDyq5wmfOEs5a4R2fXRPmm7rWU81FdffVUWLVok48ePlyeffNJpVHr\/j1Tb4UccKl26tpda2SV7nP\/q62ule6dC+WJ3a\/n9aY5rH6mAJKb7adzolt\/HjjYifvje+X3s4gbq0KFDBcHQ6RbHN5XawqPkvRUtAy\/b3xHfFznIsWDBVyL7Ptwnrav2yqVnOhFWIY3hxIkT5Y9\/\/KOw03\/BBReErJkxQ0IqpCihU5cO0q30IPmvQcdL\/+P6SvuOxaamP\/53Wyk5sFDS+c9P40a\/\/T52tBHxw\/fO72PXMt9+RicBOcBZdjjnsrPl4usdoiVQTqJZO7QTGXelyOQxIn8Ykye3XtFKiEu03GzPX1zcWrr17Npi3WSMdNxiN78fvnd+H7uMBGrsPwqaI60W0MrUAjlqAQVqjg68dlstoBZIvgUUqMm3qZaoFlAL5KgFFKg5OvDp67bWpBbIHQsoUHNnrLWnagG1QIotoEBNsYG1eLWAWiB3LKBAzZ2x9kNPA9rw+uuvy2mnndYkZ599tjzwwAPywQfxv\/Dmq6++Mi\/vEc8\/XuhDmidab9UCSbOAAjVpptSC4rHAd7\/7XeFJoZ\/\/\/OcyYcIEef755+WSSy6Rww8\/XGpqasyrCKurq81LXwh3795tqtmzZ49wj46JaPzgFYWU0bdvX7E627ZtM6nHHnus8E4KdEyEfqgFkmwBBWqSDarFJW6BuXPnyocffih33nmnPPTQQzJ9+nThTVkvvviijB07VtatW2fg+\/LLL5snw9577z2x\/0gDoD169JB77rlHysvL5bbbbpOlS5dKly5dZOPGjSa\/1ddQLZBMCyhQk2lNLSsmC0RS7tChg5x\/\/vly7rnnyllnnSUjR46U3r17y0cffWS8144dO8ohhxwiL730kth\/vCCma9eu0qpVK8ET5e1bPIp70kknSV5engBadKy+hmqBZFpAgZpMa2pZSbVAQUGBtG7dWvjHNSECLAEpkPze974nP\/3pT4luEvuKyREjRsh1110nq1atkkcffdSk19fXm1A\/1AKpsIACNRVW1TJTaoFDDz3UrKnOmTNHpk6dKkzxbYUHH3yw7Nixw6yfPv744+ZPwrDB1adPHwGmeKfoWH0N1QLJtIACNZnW1LLitsDVV1\/d9PayCy+8UNhAGjNmjJSUlJhr4sT5RxxAvPnmm4Xre++9VwYMGOCkNPzfuXNnQT799FOz3sqbnCZPnixsfn399ddmyk96g7Z+qgWSa4H\/BwAA\/\/+U7\/QdAAAABklEQVQDAKLASv6QPFQ0AAAAAElFTkSuQmCC","height":151,"width":340}}
%---
%[output:4aae92ea]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202606\\中文图Fig44D_TwoRepresentativeCellTraces.svg\n","truncated":false}}
%---
