% 逐鼠诊断：Fig1C penalized sigmoid（FitPenalizedSigmoid, FixLowerZero=true）
% 对 Naive(LAB+LAI) 与 Transfer(ALB) 队列，精确列出每只鼠被排除的原因。
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_T = TransferLearning.AudioLightBaseline();

fprintf('\n===== Naive (LAB+LAI) =====\n');
iDiagnose({DS_LAB, DS_LAI}, "Naive", "Final");
fprintf('\n===== Transfer (ALB) =====\n');
iDiagnose({DS_T}, "Transfer", "Final");

function iDiagnose(DSlist, phaseStart, phaseEnd)
for d = 1:numel(DSlist)
	DS = DSlist{d};
	T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"]);
	T.Mouse=string(T.Mouse); T.Stimulus=string(T.Stimulus); T.Phase=string(T.Phase); T.DateTime=datetime(T.DateTime);
	T = T(T.Stimulus=="LightWater",:);
	for m = unique(T.Mouse)'
		Tm = T(T.Mouse==m,:);
		phS = Tm.DateTime(Tm.Phase==phaseStart);
		phE = Tm.DateTime(Tm.Phase==phaseEnd);
		if isempty(phS)||isempty(phE)
			fprintf('%s: skip - no %s/%s phase\n', m, phaseStart, phaseEnd);
			continue;
		end
		sDT=min(phS); eDT=max(phE);
		Tm = Tm(Tm.DateTime>=sDT & Tm.DateTime<=eDT,:);
		dts = sort(unique(Tm.DateTime));
		block = zeros(height(Tm),1);
		for j=1:numel(dts), block(Tm.DateTime==dts(j))=j; end
		beh = double(Tm.Behavior);
		ok = isfinite(beh);
		nb = numel(unique(block(ok)));
		if nb < 2
			fprintf('%s: EXCLUDE - only %d distinct block(s)\n', m, nb);
			continue;
		end
		try
			fit = TransferLearning.FitPenalizedSigmoid(block(ok), beh(ok), FixLowerZero=true);
			if fit.AtSlopeBoundary
				fprintf('%s: EXCLUDE - AtSlopeBoundary (slope=%.3f, blocks=%d)\n', m, fit.Slope, nb);
			else
				fprintf('%s: OK slope=%.3f (blocks=%d)\n', m, fit.Slope, nb);
			end
		catch e
			fprintf('%s: EXCLUDE - fit error: %s\n', m, e.message);
		end
	end
end
end
