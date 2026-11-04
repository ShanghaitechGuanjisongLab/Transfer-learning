% Layer sensitivity analysis for English Fig3B local-window decoder.
% Retain every task, trial, feature, CV, and null setting; split only cells
% by DS.Cells.ZLayer into MOp2/3 and MOp5 before training. Accuracy is the
% pre/post classification accuracy, not hit/miss behavioral decoding.
% Per-mouse paired layer differences are tested by two-sided sign-rank.

cacheName = 'CueModel_LocalWindow250ms_LayerDecoder_Results.mat';
matPath = TransferLearning.CachePath(cacheName);
if isfile(matPath)
	S = load(matPath);
else
	base = load(TransferLearning.CachePath( ...
		'CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat'));
	DSs = {TransferLearning.AudioLightBaseline(),TransferLearning.Vacation7()};
	layers = ["MOp2/3","MOp5"];
	results = table();
	for i=1:numel(base.tasks)
		T = base.tasks{i};
		DS = DSs{T.DS};
		C = DS.Cells(:,{'Mouse','CellUID','ZLayer'});
		C.Mouse = string(C.Mouse);
		C.CellUID = uint64(C.CellUID);
		C.ZLayer = string(C.ZLayer);
		C = C(C.Mouse==string(T.Mouse),:);
		for layer=layers
			keepCells = C.CellUID(C.ZLayer==layer);
			[keep,loc] = ismember(keepCells,uint64(T.CellUIDs));
			loc = loc(keep);
			if numel(loc)<5
				continue;
			end
			Q = T;
			Q.CellUIDs = T.CellUIDs(loc);
			Q.NCells = numel(loc);
			Q.preTr = T.preTr(:,loc);
			Q.postTr = T.postTr(:,loc);
			Q.preTe = T.preTe(:,loc);
			Q.postTe = T.postTe(:,loc);
			Q.XTrT = T.XTrT(:,loc,:);
			Q.XTeT = T.XTeT(:,loc,:);
			rng(42000+i,'twister');
			R = TransferLearning.DecodeCuePrePostTransfer(Q,base.tVec,200);
			results = [results;table(T.DS,string(T.Mouse),layer,numel(loc), ...
				R.s1Acc,R.s2Acc,R.s1p,R.s2p, ...
				'VariableNames',{'DS','Mouse','Layer','NCells','AudioAccuracy', ...
				'TransferAccuracy','AudioPermutationP','TransferPermutationP'})]; %#ok<AGROW>
			fprintf('%s %s %s: cells=%d, audio=%.3f, transfer=%.3f\n', ...
				string(T.DS),T.Mouse,layer,numel(loc),R.s1Acc,R.s2Acc);
		end
	end
	S = struct('results',results,'tVec',base.tVec,'halfWindow',base.halfWindow);
	save(matPath,'-struct','S');
end
R = S.results;
Summary = table();
Paired = table();
for iDS=1:2
	for stage=["Audio","Transfer"]
		v23 = R.(stage+"Accuracy")(R.DS==iDS&R.Layer=="MOp2/3");
		v5 = R.(stage+"Accuracy")(R.DS==iDS&R.Layer=="MOp5");
		Summary = [Summary;table(iDS,stage,"MOp2/3",numel(v23),mean(v23), ...
			std(v23)/sqrt(numel(v23)),'VariableNames', ...
			{'DS','Stage','Layer','N','Mean','SEM'}); ...
			table(iDS,stage,"MOp5",numel(v5),mean(v5),std(v5)/sqrt(numel(v5)), ...
			'VariableNames',{'DS','Stage','Layer','N','Mean','SEM'})]; %#ok<AGROW>
		W = unstack(R(R.DS==iDS,{'Mouse','Layer',char(stage+"Accuracy")}), ...
			stage+"Accuracy",'Layer','VariableNamingRule','preserve');
		valid = isfinite(W.("MOp2/3"))&isfinite(W.MOp5);
		d = W.("MOp2/3")(valid)-W.MOp5(valid);
		p = signrank(d);
		Paired = [Paired;table(iDS,stage,numel(d),mean(d),median(d),p, ...
			'VariableNames',{'DS','Stage','NPairs','MeanL23MinusL5', ...
			'MedianL23MinusL5','SignRankP'})]; %#ok<AGROW>
	end
end
LayerDecoderAccuracy = struct('PerMouse',R,'Summary',Summary,'Paired',Paired);
disp('=== Layer-specific decoder accuracy ===');
disp(Summary);
disp('=== Paired L2/3 minus L5 accuracy ===');
disp(Paired);
assignin('base','Fig3B_LayerDecoderAccuracy',LayerDecoderAccuracy);
