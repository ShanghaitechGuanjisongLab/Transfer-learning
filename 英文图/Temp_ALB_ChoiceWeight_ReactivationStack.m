% 英文图（探查/草图）：ALB 全细胞 choice 解码器权重分布 + 子群堆叠直方图。
% 底 histogram = 全细胞 choice 权重 w1s（BuildCueChoiceDecoderData，+1 s，w>0 偏 hit / w<0 偏 miss）；
% 每柱内把 learned-active（未 reactivated）与 reactivated 细胞对应计数用不同颜色堆叠。
% 活跃判定沿用 FigS1H 口径：QueryNTATS Median 跨 trial 后，+1 s 处 z > 基线(-3~0 s)均值+3σ。
% learned = Learned AudioWater（每鼠最后 AudioWater 非 Recall 会话）；transfer = 首个 Transfer LightWater。
% reactivated = learned-active ∩ transfer-active。
% 目的：直观展示 hit 大权重细胞中只有少数是 reactivated，而 reactivated 细胞几乎都偏 hit。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
data = TransferLearning.BuildCueChoiceDecoderData();
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx1s] = min(abs(xsSec - 1.0));
kSigma = 3;

% 每鼠 learned / transfer 会话锚点
T = DS.TableQuery(["Mouse","DateTime","TrialUID","Phase","Stimulus"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus); T.Phase = string(T.Phase); T.DateTime = datetime(T.DateTime);

allW = [];
grpReact = [];   % 与 allW 对齐：2=reactivated, 1=learned-active 未 reactivated, 0=其它
tot = struct('all',0,'LA',0,'react',0,'hitAll',0,'hitLA',0,'hitReact',0);
for iM = 1:numel(data.choice)
	m = string(data.choice{iM}.Mouse);
	cids = uint64(data.choice{iM}.cellUIDs(:));
	w = double(data.choice{iM}.w1s(:));
	Tm = T(T.Mouse==m,:);
	aw = Tm(Tm.Stimulus=="AudioWater" & Tm.Phase~="Recall",:);
	if isempty(aw), continue; end
	dtL = max(aw.DateTime);
	lw = Tm(Tm.Stimulus=="LightWater" & Tm.Phase=="Transfer",:);
	if isempty(lw), continue; end
	dtT = min(lw.DateTime);
	GL = DS.QueryNTATS(struct('Mouse',m,'Stimulus',"AudioWater",'DateTime',dtL), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	GT = DS.QueryNTATS(struct('Mouse',m,'Stimulus',"LightWater",'DateTime',dtT), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	actL = iActiveFromNtats(GL, baseMask, idx1s, kSigma);
	actT = iActiveFromNtats(GT, baseMask, idx1s, kSigma);
	react = intersect(actL, actT);
	laOnly = setdiff(actL, react);
	g = zeros(numel(cids),1);
	g(ismember(cids, laOnly)) = 1;
	g(ismember(cids, react)) = 2;
	allW = [allW; w]; %#ok<AGROW>
	grpReact = [grpReact; g]; %#ok<AGROW>
	tot.all = tot.all + numel(w);
	tot.LA = tot.LA + nnz(g>=1);
	tot.react = tot.react + nnz(g==2);
	tot.hitAll = tot.hitAll + nnz(w>0);
	tot.hitLA = tot.hitLA + nnz(w>0 & g>=1);
	tot.hitReact = tot.hitReact + nnz(w>0 & g==2);
end
fprintf('Cells total=%d, learned-active=%d (%.1f%%), reactivated=%d (%.1f%%)\n', tot.all, tot.LA, 100*tot.LA/tot.all, tot.react, 100*tot.react/tot.all);
fprintf('hit(w>0): all=%d, LA=%d, react=%d\n', tot.hitAll, tot.hitLA, tot.hitReact);
%% 

% ---- 堆叠直方图 ----
edges = linspace(-2, 2, 41);
nOther = histcounts(allW(grpReact==0), edges);
nLA = histcounts(allW(grpReact==1), edges);
nReact = histcounts(allW(grpReact==2), edges);
%% 

f = figure('Color','w','Name','🔊→12h→💡');
f.Units='centimeters'; f.Position(3:4)=[12,8];
ax = axes(f); hold(ax,'on');
% 堆叠顺序：reactivated 在最底，learned-active 居中，其它细胞在顶
counts = [nReact(:), nLA(:), nOther(:)];
h = bar(ax, edges(1:end-1)+diff(edges)/2, counts, 1, 'stacked','EdgeColor','none');
h(1).FaceColor = [0.0001	0.0045	0.3319];   % reactivated
h(2).FaceColor = [1.0000	0.4567	0.2322];   % learned-active 未 reactivated 绿（中）
h(3).FaceColor = [0.0000	0.7809	0.0000];   % 其它细胞 灰（顶）
xline(ax,0,':','HandleVisibility','off');
xlabel(ax,'Choice decoder weight');
ylabel(ax,'Cell count');
legend(ax, h, {'reactivated','learned-active','other'}, 'Box','off','Location','northwest');
title(ax,'ALB: choice-weight distribution, reactivated subset stacked');
box(ax,'off');

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_ALB_ChoiceWeight_ReactivationStack.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base','ALB_WeightReactivationStack', struct('edges',edges,'nOther',nOther,'nLA',nLA,'nReact',nReact,'tot',tot));

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
