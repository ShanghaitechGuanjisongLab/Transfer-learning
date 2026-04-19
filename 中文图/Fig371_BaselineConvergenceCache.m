function Data = Fig371_BaselineConvergenceCache(varargin)
if nargin > 1
	error('Fig371:BadInput', 'Expected at most one input.');
end

persistent Cache

if isempty(Cache)
	Cache = iBuildCache();
end

Data = Cache;
end

function Cache = iBuildCache()
	iEnsureProjectLoaded();

	MB = TransferLearning.MOpBaseline();
	infoQuery = iBuildInternalInfoQuery();
	groupNts = MB.QueryNTS(infoQuery, ExtraColumns="TrialRI");
	xSec = iXsSeconds(25);
	phaseNames = ["LearnedAudio", "NaiveLight", "TransferLightHit", "TransferLightMiss"];
	legendLabels = ["Learned", "Naive", "Continual hit", "Continual miss"];
	barLabels = ["Learned", "Naive", "C-hit", "C-miss"];
	phaseColors = [1, 0, 0; 0, 0, 1; 0, 0, 0; 0, 0.6809, 0];
	compareGroup = table(["NaiveLight", "TransferLightHit"; "NaiveLight", "LearnedAudio"; "TransferLightHit", "TransferLightMiss"], 'VariableNames', {'GroupPair'});

	phase = struct();
	deviationMean = nan(numel(xSec), numel(phaseNames));
	deviationSem = nan(numel(xSec), numel(phaseNames));
	convergenceRate = cell(1, numel(phaseNames));
	fluorescenceDelta = cell(1, numel(phaseNames));

	for iPhase = 1:numel(phaseNames)
		phaseName = phaseNames(iPhase);
		if ~isfield(groupNts, phaseName)
			error('Fig371:MissingPhase', 'Phase %s is missing from QueryNTS result.', phaseName);
		end

		rows = sortrows(groupNts.(phaseName), ["CellUID", "TrialRI"]);
		cellSummary = groupsummary(rows, "CellUID", ["var", "median"], "TrialSignal");
		varMat = iVarianceMatrix(cellSummary);
		stdMat = sqrt(max(varMat, 0));
		medianMat = cellSummary.median_TrialSignal;

		[deviationMean(:, iPhase), deviationSem(:, iPhase)] = MATLAB.DataFun.MeanSem( ...
			log2(stdMat(:, 1:25) ./ stdMat(:, 25)), 1);
		convergenceRate{iPhase} = double(log2(stdMat(:, 1) ./ stdMat(:, 22)));
		fluorescenceDelta{iPhase} = double(medianMat(:, 22) ./ medianMat(:, 1) - 1);

		phase.(phaseName) = struct( ...
			'Rows', rows, ...
			'CellSummary', cellSummary, ...
			'StdMatrix', stdMat, ...
			'MedianMatrix', medianMat, ...
			'DeviationMean', deviationMean(:, iPhase), ...
			'DeviationSem', deviationSem(:, iPhase), ...
			'ConvergenceRate', convergenceRate{iPhase}, ...
			'FluorescenceDelta', fluorescenceDelta{iPhase});
	end

	learnedRows = phase.LearnedAudio.Rows;
	learnedSummary = phase.LearnedAudio.CellSummary;
	keepCellUID = learnedSummary.CellUID(learnedSummary.GroupCount == 30);
	sampleSignal = learnedRows.TrialSignal(ismember(learnedRows.CellUID, keepCellUID), 1:25);
	if mod(size(sampleSignal, 1), 30) ~= 0
		error('Fig371:InvalidLearnedTrials', 'LearnedAudio rows cannot be reshaped into 30-trial stacks.');
	end
	sampleSignal = permute(reshape(sampleSignal, 30, [], 25), [3, 1, 2]);
	[coeff, ~, explained] = UniExp.DimensionalPca(sampleSignal([1, 25], :, :), [false, false, true], 2);
	trialPc1 = reshape(pagemtimes(reshape(sampleSignal, [], size(sampleSignal, 3)), coeff(:, 1)), size(sampleSignal, 1), size(sampleSignal, 2));

	Cache = struct();
	Cache.QuerySource = "internal";
	Cache.Phases = phaseNames;
	Cache.LegendLabels = legendLabels;
	Cache.BarLabels = barLabels;
	Cache.PhaseColors = phaseColors;
	Cache.CompareGroup = compareGroup;
	Cache.XSec = xSec;
	Cache.DeviationMean = deviationMean;
	Cache.DeviationSem = deviationSem;
	Cache.ConvergenceRate = convergenceRate;
	Cache.FluorescenceDelta = fluorescenceDelta;
	Cache.ConvergenceRateStruct = iCellToStruct(convergenceRate, phaseNames);
	Cache.FluorescenceDeltaStruct = iCellToStruct(fluorescenceDelta, phaseNames);
	Cache.Phase = phase;
	Cache.LearnedAudioPC1 = double(trialPc1);
	Cache.LearnedAudioExplained = double(explained(:).');
	Cache.TrialOrder = (1:size(trialPc1, 2)).';
	Cache.TrialColormap = iTrialColormap(size(trialPc1, 2));
end

function infoQuery = iBuildInternalInfoQuery()
	groupName = ["NaiveLight"; "LearnedLight"; "TransferLight"; "TransferLightHit"; "TransferLightMiss"; "FinalLight"; ...
		"NaiveAudio"; "LearnedAudio"; "TransferAudio"; "TransferAudioHit"; "TransferAudioMiss"; "FinalAudio"];
	stimulus = ["LightWater"; "LightWater"; "LightWater"; "LightWater"; "LightWater"; "LightWater"; ...
		"AudioWater"; "AudioWater"; "AudioWater"; "AudioWater"; "AudioWater"; "AudioWater"];
	phase = ["Naive"; "Learned"; "Transfer"; "Transfer"; "Transfer"; "Final"; ...
		"Naive"; "Learned"; "Transfer"; "Transfer"; "Transfer"; "Final"];
	paradigm = ["光声无穿插"; "光声无穿插"; "声光无穿插"; "声光无穿插"; "声光无穿插"; "声光无穿插"; ...
		"声光无穿插"; "声光无穿插"; "光声无穿插"; "光声无穿插"; "光声无穿插"; "光声无穿插"];
	behavior = {[]; []; []; 1; 0; []; []; []; []; 1; 0; []};
	infoQuery = table(groupName, stimulus, phase, paradigm, behavior, ...
		'VariableNames', {'GroupName', 'Stimulus', 'Phase', 'Paradigm', 'Behavior'});
end

function iEnsureProjectLoaded()
	if exist('UniExp.DataSet', 'class')
		return;
	end
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

function xSec = iXsSeconds(nPoint)
	x = TransferLearning.Xs(1:nPoint);
	if isduration(x)
		x = seconds(x);
	end
	xSec = double(x(:));
end

function varMat = iVarianceMatrix(cellSummary)
	if any(strcmp(cellSummary.Properties.VariableNames, 'var_TrialSignal'))
		varName = "var_TrialSignal";
	elseif any(strcmp(cellSummary.Properties.VariableNames, 'std_TrialSignal'))
		varName = "std_TrialSignal";
	else
		error('Fig371:MissingVariance', 'groupsummary output does not contain var_TrialSignal or std_TrialSignal.');
	end
	varMat = double(cellSummary.(varName));
	if varName == "std_TrialSignal"
		varMat = varMat .^ 2;
	end
end

function cmap = iTrialColormap(nTrial)
	if nTrial <= 1
		cmap = [0.15, 0.75, 0.20];
		return;
	end
	startColor = [0.15, 0.75, 0.20];
	endColor = [0.90, 0.05, 0.95];
	mix = linspace(0, 1, nTrial).';
	cmap = (1 - mix) .* startColor + mix .* endColor;
end

function out = iCellToStruct(values, names)
	out = struct();
	for iName = 1:numel(names)
		out.(names(iName)) = values{iName};
	end
end