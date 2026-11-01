% 严格 S1H 口径（median 跨 trial 后再判活跃）的重叠复核
DS = TransferLearning.ALDelayed();
data = TransferLearning.BuildChoiceDecoderDataDelayed();
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx15] = min(abs(xsSec - 1.5));
kSigma = 3;
T = DS.TableQuery(["Mouse","DateTime","TrialUID","Stimulus"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus); T.DateTime = datetime(T.DateTime);
tot = struct('hit',0,'hitReact',0,'hitLA',0,'react',0,'LA',0);
for iM = 1:numel(data.choice)
	m = data.choice{iM}.Mouse;
	cids = data.choice{iM}.cellUIDs; w = data.choice{iM}.w1p5;
	hitPref = cids(w>0);
	Tm = T(T.Mouse==m,:);
	dtL = max(Tm.DateTime(Tm.Stimulus=="AudioLearnWater"));
	dtT = min(Tm.DateTime(Tm.Stimulus=="LightLearnWater"));
	GL = DS.QueryNTATS(struct('Mouse',m,'Stimulus',"AudioLearnWater",'DateTime',dtL), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	GT = DS.QueryNTATS(struct('Mouse',m,'Stimulus',["LightLearnWater","LightLearnWaterAlways"],'DateTime',dtT), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	actL = iActiveFromNtats(GL, baseMask, idx15, kSigma);
	actT = iActiveFromNtats(GT, baseMask, idx15, kSigma);
	react = intersect(actL, actT);
	tot.hit = tot.hit + numel(hitPref);
	tot.hitLA = tot.hitLA + numel(intersect(hitPref,actL));
	tot.hitReact = tot.hitReact + numel(intersect(hitPref,react));
	tot.react = tot.react + numel(react);
	tot.LA = tot.LA + numel(actL);
	fprintf('%s: hitPref=%d, LA=%d, react=%d, hit∩LA=%d, hit∩react=%d\n', m, numel(hitPref), numel(actL), numel(react), numel(intersect(hitPref,actL)), numel(intersect(hitPref,react)));
end
fprintf('\nTOTAL: hitPref=%d, hit∩LA=%d (%.1f%%), hit∩react=%d (%.1f%%), totalReact=%d, totalLA=%d\n', ...
	tot.hit, tot.hitLA, 100*tot.hitLA/tot.hit, tot.hitReact, 100*tot.hitReact/tot.hit, tot.react, tot.LA);

function ids = iActiveFromNtats(G, baseMask, idxT, kSigma)
ids = uint64([]);
if isempty(G), return; end
S = UniExp.NtatsCellStrip(struct('Q',G));
nt = S.NTATS;
try, X = nt.Data.Data; catch, X = nt{:,:,:}.Data; end
if size(X,3)>1, XL = squeeze(X(:,:,1)); else, XL = squeeze(X); end
baseMu = mean(XL(:,baseMask),2,'omitnan');
baseSd = std(XL(:,baseMask),0,2,'omitnan');
v = XL(:,idxT);
isAct = isfinite(v)&isfinite(baseMu)&isfinite(baseSd)&(v>baseMu+kSigma*baseSd);
ids = uint64(S.CellUID(isAct));
end
