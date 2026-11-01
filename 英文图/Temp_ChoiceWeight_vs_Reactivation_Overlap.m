% 探查：S2F 的 choice 大权重(hit-preferring)细胞 与 S1H 口径的 reactivated 细胞 的重叠。
% 在 ALDelayed 上，对每鼠算 hit-preferring 细胞中有多少同时也是 learned-active / reactivated。
DS = TransferLearning.ALDelayed();
data = TransferLearning.BuildChoiceDecoderDataDelayed();
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx15] = min(abs(xsSec - 1.5));
kSigma = 3;
T = DS.TableQuery(["Mouse","DateTime","TrialUID","Stimulus"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus); T.DateTime = datetime(T.DateTime);
res = table(strings(0,1), zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
	'VariableNames', {'Mouse','nHitPref','nHitPrefAlsoReact','nHitPrefAlsoLearnedActive','nReactivated','nLearnedActiveTotal'});
for iM = 1:numel(data.choice)
	m = data.choice{iM}.Mouse;
	cids = data.choice{iM}.cellUIDs;
	w = data.choice{iM}.w1p5;
	hitPref = cids(w > 0);
	Tm = T(T.Mouse==m,:);
	dtL = max(Tm.DateTime(Tm.Stimulus=="AudioLearnWater"));
	dtT = min(Tm.DateTime(Tm.Stimulus=="LightLearnWater"));
	ntsL = DS.QueryNTS(struct('Mouse',m,'Stimulus',"AudioLearnWater",'DateTime',dtL), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsL), ntsL = ntsL{1}; end
	ntsT = DS.QueryNTS(struct('Mouse',m,'Stimulus',["LightLearnWater","LightLearnWaterAlways"],'DateTime',dtT), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsT), ntsT = ntsT{1}; end
	actL = iActiveIDs(ntsL, baseMask, idx15, kSigma);
	actT = iActiveIDs(ntsT, baseMask, idx15, kSigma);
	react = intersect(actL, actT);
	res = [res; table(m, numel(hitPref), numel(intersect(hitPref, react)), numel(intersect(hitPref, actL)), numel(react), numel(actL), ...
		'VariableNames', res.Properties.VariableNames)]; %#ok<AGROW>
end
disp(res);
fprintf('\nTotals: hitPref=%d\n', sum(res.nHitPref));
fprintf('  also learned-active = %d (%.1f%%)\n', sum(res.nHitPrefAlsoLearnedActive), 100*sum(res.nHitPrefAlsoLearnedActive)/sum(res.nHitPref));
fprintf('  also reactivated    = %d (%.1f%%)\n', sum(res.nHitPrefAlsoReact), 100*sum(res.nHitPrefAlsoReact)/sum(res.nHitPref));
fprintf('  total reactivated across mice = %d, total learned-active = %d\n', sum(res.nReactivated), sum(res.nLearnedActiveTotal));
assignin('base','FigS2F_vs_Reactivation_Overlap',res);

function ids = iActiveIDs(nts, baseMask, idxT, kSigma)
ids = uint64([]);
if isempty(nts), return; end
sig = double(nts.TrialSignal);
cid = uint64(nts.CellUID);
allC = unique(cid);
keep = false(numel(allC),1);
for i=1:numel(allC)
	X = sig(cid==allC(i),:);
	baseMu = mean(X(:,baseMask),2,'omitnan');
	baseSd = std(X(:,baseMask),0,2,'omitnan');
	v = X(:,idxT);
	bm = median(baseMu,'omitnan'); bs = median(baseSd,'omitnan'); vv = median(v,'omitnan');
	keep(i) = isfinite(vv)&isfinite(bm)&isfinite(bs)&(vv>bm+kSigma*bs);
end
ids = allC(keep);
end
