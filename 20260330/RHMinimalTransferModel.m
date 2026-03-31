function Result = RHMinimalTransferModel(Options)
% 最小机制模型：把首日迁移优势与后续学习速度拆成两个耦合过程。
arguments
	Options.NMicePerGroup (1,1) double {mustBeInteger,mustBePositive} = 24
	Options.NSessions (1,1) double {mustBeInteger,mustBePositive} = 8
	Options.NTrials (1,1) double {mustBeInteger,mustBePositive} = 80
	Options.NCells23 (1,1) double {mustBeInteger,mustBePositive} = 96
	Options.NCells5 (1,1) double {mustBeInteger,mustBePositive} = 96
	Options.RandomSeed (1,1) double {mustBeInteger} = 20260331
end

rng(Options.RandomSeed, 'twister');

groupNames = ["Naive"; "Transfer"; "THInhibit"];
nGroup = numel(groupNames);
nMice = Options.NMicePerGroup * nGroup;
nCells = Options.NCells23 + Options.NCells5;
nTime = 48;

groupPerMouse = repelem(groupNames, Options.NMicePerGroup, 1);
mouseNames = "M" + compose('%03d', (1:nMice).');
sessionIndex = (1:Options.NSessions).';

reuseScale = zeros(nMice, 1);
reuseScale(groupPerMouse ~= "Naive") = 1;

thalamusScale = ones(nMice, 1);
thalamusScale(groupPerMouse == "THInhibit") = 0.35;

layer = [repmat("L23", Options.NCells23, 1); repmat("L5", Options.NCells5, 1)];
isLayer23 = layer == "L23";
isLayer5 = ~isLayer23;

nExc23 = round(0.8 * Options.NCells23);
nExc5 = round(0.8 * Options.NCells5);
isExc = [true(nExc23, 1); false(Options.NCells23 - nExc23, 1); true(nExc5, 1); false(Options.NCells5 - nExc5, 1)];
cellTypeSign = double(isExc) * 2 - 1;

cueKernel = exp(-0.5 * ((1:nTime) - 32).^2 / 2.2^2);
cueKernel = reshape(cueKernel, 1, nTime, 1);

reuseTemplate = max(0, 0.55 * randn(nCells, nMice) + 0.90 * isExc + 0.35 * isLayer23 + 0.20 * isLayer5);
audioWeight = 0.65 * reuseTemplate + 0.25 * randn(nCells, nMice);
visualWeight = 0.18 * randn(nCells, nMice) + 0.22 * isLayer23 + 0.12 * isLayer5;
thalamusCoupling = (0.32 + 0.18 * isLayer23 + 0.45 * isLayer5 + 0.10 * ~isExc) .* (1 + 0.12 * randn(nCells, nMice));
localDifferentiation = sign(audioWeight + 0.22 * cellTypeSign + 0.08 * randn(nCells, nMice));
baselineSigma = max(0.18, 0.75 + 0.12 * randn(nCells, nMice));

readoutWeight = zeros(nCells, 1);
readoutWeight(isLayer23 & isExc) = 0.55;
readoutWeight(isLayer5 & isExc) = 1.00;
readoutWeight(~isExc) = -0.75;
readoutWeight = readoutWeight / sum(abs(readoutWeight));

learnState = zeros(nMice, 1);

rows = repmat(struct( ...
	'Mouse', "", ...
	'Group', "", ...
	'Session', 0, ...
	'Performance', nan, ...
	'RH23', nan, ...
	'RH5', nan, ...
	'DeltaHit', nan), nMice * Options.NSessions, 1);
rowIdx = 0;

for iSession = 1:Options.NSessions
	sessionReuse = 0.82;
	sessionThalamus = 0.82;
	responseMean = ...
		(0.20 + learnState.') .* visualWeight + ...
		sessionReuse .* reuseScale.' .* (0.42 * reuseTemplate .* localDifferentiation) + ...
		sessionThalamus .* thalamusScale.' .* (0.48 * thalamusCoupling .* (0.70 * localDifferentiation + 0.18 * cellTypeSign)) + ...
		0.08 * (0.7 * isLayer23 + 1.0 * isLayer5) .* localDifferentiation;

	for iMouse = 1:nMice
		raw = baselineSigma(:, iMouse) .* randn(nCells, nTime, Options.NTrials);
		trialModulation = 1 + 0.18 * randn(1, 1, Options.NTrials);
		trialOffset = 0.10 * randn(nCells, 1, Options.NTrials);
		raw = raw + responseMean(:, iMouse) .* cueKernel .* trialModulation + trialOffset;

		z = iZScore(raw);
		z1 = squeeze(z(:, 32, :));

		rh23 = iResponseHeterogeneityFromZ(z1(isLayer23, :));
		rh5 = iResponseHeterogeneityFromZ(z1(isLayer5, :));

		decisionSignal = readoutWeight.' * z1;
		decisionBias = -0.46 + 0.44 * reuseScale(iMouse) + 0.10 * thalamusScale(iMouse) + 0.04 * (iSession - 1) + 1.95 * learnState(iMouse);
		hitProbability = 1 ./ (1 + exp(-(decisionBias + decisionSignal)));
		performance = 100 * mean(hitProbability, 2);
		if performance > 99
			performance = 100;
		end

		rowIdx = rowIdx + 1;
		rows(rowIdx).Mouse = mouseNames(iMouse);
		rows(rowIdx).Group = groupPerMouse(iMouse);
		rows(rowIdx).Session = iSession;
		rows(rowIdx).Performance = performance;
		rows(rowIdx).RH23 = rh23;
		rows(rowIdx).RH5 = rh5;

		if iSession > 1
			prevRow = rowIdx - 1;
			rows(rowIdx).DeltaHit = performance - rows(prevRow).Performance;
		end

		learningIncrement = (1 - performance / 100) * (0.004 + 0.060 * reuseScale(iMouse) + 0.280 * thalamusScale(iMouse) * rh23 + 0.110 * thalamusScale(iMouse) * rh5);
		learnState(iMouse) = learnState(iMouse) + learningIncrement;
		if performance >= 100
			learnState(iMouse) = learnState(iMouse);
		end
	end
end

SessionTable = struct2table(rows);
SessionTable = sortrows(SessionTable, {'Group', 'Mouse', 'Session'});

PerMouseTable = iPerMouseSummary(SessionTable);

[rho23, p23] = corr(PerMouseTable.RH23, PerMouseTable.SlopeAdj, 'Type', 'Spearman', 'Rows', 'complete');
[rho5, p5] = corr(PerMouseTable.RH5, PerMouseTable.SlopeAdj, 'Type', 'Spearman', 'Rows', 'complete');

CorrelationTable = table( ...
	["RH23"; "RH5"], ...
	[rho23; rho5], ...
	[p23; p5], ...
	'VariableNames', {'Metric', 'SpearmanRho', 'PValue'});

Day1Table = SessionTable(SessionTable.Session == 1, {'Mouse', 'Group', 'Performance'});
Day1Table.Properties.VariableNames{'Performance'} = 'Day1Performance';

MeanByGroup = groupsummary(PerMouseTable, 'Group', 'mean', {'Day1Performance', 'Slope', 'SlopeAdj', 'RH23', 'RH5'});

Result = struct;
Result.Options = Options;
Result.SessionTable = SessionTable;
Result.PerMouseTable = PerMouseTable;
Result.Day1Table = Day1Table;
Result.CorrelationTable = CorrelationTable;
Result.GroupSummary = MeanByGroup;
Result.Description = [
	"Transfer 组通过 reuseTemplate 提高首日表现；" ...
	"THInhibit 组保留 reuseTemplate，因此首日近似不变；" ...
	"后续学习增量主要受 RH23 和 RH5 调节，其中 RH23 权重更高，TH 抑制同时降低两层 RH，且因 L5 thalamusCoupling 更强而对 RH5 影响更大。"
];

if nargout == 0
	disp(Result.GroupSummary);
	disp(Result.CorrelationTable);
end
end

function PerMouseTable = iPerMouseSummary(SessionTable)
mouseNames = unique(string(SessionTable.Mouse), 'stable');

nMouse = numel(mouseNames);
group = strings(nMouse, 1);
day1Performance = nan(nMouse, 1);
slope = nan(nMouse, 1);
nSessions = nan(nMouse, 1);
rh23 = nan(nMouse, 1);
rh5 = nan(nMouse, 1);

for iMouse = 1:nMouse
	rows = string(SessionTable.Mouse) == mouseNames(iMouse);
	T = SessionTable(rows, :);
	T = sortrows(T, 'Session');
	group(iMouse) = string(T.Group(1));
	day1Performance(iMouse) = T.Performance(1);
	rh23(iMouse) = mean(T.RH23, 'omitnan');
	rh5(iMouse) = mean(T.RH5, 'omitnan');

	cutoff = find(T.Performance >= 100, 1, 'first');
	if isempty(cutoff)
		keep = true(height(T), 1);
	elseif cutoff == 1
		keep = false(height(T), 1);
	else
		keep = (1:height(T)).' < cutoff;
	end

	Tk = T(keep, :);
	nSessions(iMouse) = height(Tk);
	if height(Tk) < 2
		continue;
	end
	x = double(Tk.Session);
		y = double(Tk.Performance);
		ok = isfinite(x) & isfinite(y);
		if nnz(ok) < 2
			continue;
		end
		p = polyfit(x(ok), y(ok), 1);
		slope(iMouse) = p(1);
	end

PerMouseTable = table(mouseNames, group, day1Performance, slope, nSessions, rh23, rh5, ...
	'VariableNames', {'Mouse', 'Group', 'Day1Performance', 'Slope', 'NSessions', 'RH23', 'RH5'});

okAdj = isfinite(PerMouseTable.Slope) & isfinite(PerMouseTable.Day1Performance);
PerMouseTable.SlopeAdj = nan(height(PerMouseTable), 1);
if nnz(okAdj) >= 2
	X = [ones(nnz(okAdj), 1), double(PerMouseTable.Day1Performance(okAdj))];
	b = X \ double(PerMouseTable.Slope(okAdj));
	PerMouseTable.SlopeAdj(okAdj) = double(PerMouseTable.Slope(okAdj)) - X * b;
end
end

function RH = iResponseHeterogeneityFromZ(Z1)
meanResponse = mean(Z1, 2, 'omitnan');
meanResponse = meanResponse(meanResponse >= -1 & meanResponse <= 1);
if numel(meanResponse) < 2
	RH = nan;
	return;
end
RH = std(meanResponse, 0, 1, 'omitnan');
end

function Z = iZScore(Data)
baseline = Data(:, 1:24, :);
baselineMean = mean(baseline, 2, 'omitnan');
baselineStd = std(baseline, 0, 2, 'omitnan');
baselineStd(baselineStd < eps) = 1;
Z = (Data - baselineMean) ./ baselineStd;
end