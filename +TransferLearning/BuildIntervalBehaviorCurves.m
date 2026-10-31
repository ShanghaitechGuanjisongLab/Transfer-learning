function [Curves, Trials] = BuildIntervalBehaviorCurves()
% Light-water learning curves for Naive, interspersed, 12-h, and 7-d cohorts.
% Sequential datasets include all blocks from Transfer/Naive to Final/Learned,
% including unlabelled intermediate blocks. Interspersed datasets use only
% Transfer-phase blocks. Each output row is one mouse x DateTime session.

parts = { ...
	TransferLearning.LightAudioBaseline(), "Naive", "Naive", "Learned", true; ...
	TransferLearning.LAPureBehavior(), "Naive", "Naive", "Learned", true; ...
	TransferLearning.LAInterspersed(), "Naive", "Naive", "Learned", true; ...
	TransferLearning.ALInterspersed(), "Interspersed", "Transfer", "Final", false; ...
	TransferLearning.AudioLightBaseline(), "12h", "Transfer", "Final", false; ...
	TransferLearning.ALPureBehavior(), "12h", "Transfer", "Final", false; ...
	TransferLearning.Vacation7(), "7d", "Transfer", "Final", false};

Curves = table();
Trials = table();
sourceNames = ["LightAudioBaseline","LAPureBehavior","LAInterspersed", ...
	"ALInterspersed","AudioLightBaseline","ALPureBehavior","Vacation7"];
for i = 1:size(parts,1)
	DS = parts{i,1};
	group = parts{i,2};
	startPhase = parts{i,3};
	endPhase = parts{i,4};
	isNaive = parts{i,5};
	source = sourceNames(i);
	DT = DS.DateTimes(:, {'Mouse','DateTime','Phase'});
	DT.Mouse = string(DT.Mouse);
	DT.Phase = string(DT.Phase);
	DT.DateTime = iNormDT(DT.DateTime);
	B = DS.Blocks(:, {'BlockUID','DateTime'});
	B.BlockUID = uint64(B.BlockUID);
	B.DateTime = iNormDT(B.DateTime);
	T = DS.Trials(:, {'TrialUID','BlockUID','TrialIndex','Stimulus','Behavior'});
	T.BlockUID = uint64(T.BlockUID);
	T.Stimulus = string(T.Stimulus);
	T.Behavior = double(T.Behavior);
	T = innerjoin(T, B, 'Keys', 'BlockUID');
	T = innerjoin(T, DT, 'Keys', 'DateTime');
	T = T(T.Stimulus == "LightWater" | T.Stimulus == "AudioWater", :);
	mice = unique(DT.Mouse(DT.Phase == startPhase));
	for m = mice.'
		Q = T(T.Mouse == m, :);
		Dm = DT(DT.Mouse == m, :);
		startDT = min(Dm.DateTime(Dm.Phase == startPhase));
		endCandidates = Dm.DateTime(Dm.Phase == endPhase & Dm.DateTime >= startDT);
		if isempty(endCandidates) && isNaive
			endDT = max(Dm.DateTime(Dm.Phase == startPhase));
		elseif isempty(endCandidates)
			endDT = max(Q.DateTime(Q.Stimulus == "LightWater"));
		else
			endDT = max(endCandidates);
		end
		Q = Q(Q.DateTime >= startDT & Q.DateTime <= endDT, :);
		Q = Q(isfinite(Q.Behavior), :);
		if isNaive && i == 3 && any(Q.Phase == "Naive" & Q.Stimulus == "AudioWater")
			% Keep the established exclusion for contaminated Naive LAI mice.
			continue;
		end
		if isNaive
			% No other task is allowed in a Naive light-water learning session.
			dtAW = unique(Q.DateTime(Q.Stimulus == "AudioWater"));
			Q = Q(~ismember(Q.DateTime, dtAW), :);
		end
		Q = Q(Q.Stimulus == "LightWater", :);
		if isempty(Q)
			continue;
		end
		[G, dt] = findgroups(Q.DateTime);
		perf = splitapply(@mean, Q.Behavior, G);
		n = splitapply(@numel, Q.Behavior, G);
		block = (1:numel(dt)).';
		Part = table(repmat(group,numel(dt),1), repmat(m,numel(dt),1), ...
			repmat(source,numel(dt),1), dt, block, perf, n, ...
			'VariableNames', {'Group','Mouse','Source','DateTime','Block','Performance','NTrial'});
		Curves = [Curves; Part]; %#ok<AGROW>
		Q.Group = repmat(group,height(Q),1);
		Q.Source = repmat(source,height(Q),1);
		Trials = [Trials; Q]; %#ok<AGROW>
	end
end
Curves = sortrows(Curves, {'Group','Mouse','DateTime'});
end

function dt = iNormDT(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end
