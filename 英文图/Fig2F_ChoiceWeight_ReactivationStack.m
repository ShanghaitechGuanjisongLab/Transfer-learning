% Fig2F（英文图）：全细胞 choice 解码器权重分布 + 子群堆叠直方图，双 tile。
%   左 tile = AudioLightBaseline（12 h），右 tile = Vacation7（7 d）。
% 底 histogram = 全细胞 choice 权重 w（+1 s，w>0 偏 hit / w<0 偏 miss）；
% 每柱内 reactivated 堆最底、learned-active（未 reactivated）居中、其它细胞在顶。
% 活跃判定沿用 FigS1H 口径：QueryNTATS Median 跨 trial 后，+1 s 处 z > 基线(-3~0 s)均值+3σ。
% reactivated = learned-active ∩ transfer-active（learned=最后非 Recall AudioWater 会话，
% transfer=首个 Transfer LightWater 会话）。
% 权重：ALB 用 BuildCueChoiceDecoderData 的平衡权重 w1s；Vacation7 无现成解码器，
% 按同一公式 w=(m1-m0)/sp² 在 +1 s 对 AudioWater(非 Recall) 回合计算（类别平衡下采样 100 次取平均）。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx1s] = min(abs(xsSec - 1.0));
kSigma = 3;

% ---- 左：ALB ----
ALB = TransferLearning.AudioLightBaseline();
dataALB = TransferLearning.BuildCueChoiceDecoderData();
WALB = struct('w',[],'g',[]);
for iM = 1:numel(dataALB.choice)
	m = string(dataALB.choice{iM}.Mouse);
	cids = uint64(dataALB.choice{iM}.cellUIDs(:));
	w = double(dataALB.choice{iM}.w1s(:));
	[g, ok] = iGroupForMouse(ALB, m, cids, baseMask, idx1s, kSigma);
	if ~ok, continue; end
	WALB.w = [WALB.w; w]; WALB.g = [WALB.g; g]; %#ok<AGROW>
end

% ---- 右：Vacation7 ----
V7 = TransferLearning.Vacation7();
miceV7 = unique(string(V7.Cells.Mouse));
WV7 = struct('w',[],'g',[]);
wStrm = RandStream('Threefry','Seed',42);
for iM = 1:numel(miceV7)
	m = miceV7(iM);
	[w, cids, okW] = iChoiceWeightV7(V7, m, idx1s, wStrm);
	if ~okW, continue; end
	[g, ok] = iGroupForMouse(V7, m, cids, baseMask, idx1s, kSigma);
	if ~ok, continue; end
	WV7.w = [WV7.w; w]; WV7.g = [WV7.g; g]; %#ok<AGROW>
end

fprintf('ALB: cells=%d, LA=%d, react=%d\n', numel(WALB.w), nnz(WALB.g>=1), nnz(WALB.g==2));
fprintf('V7:  cells=%d, LA=%d, react=%d\n', numel(WV7.w), nnz(WV7.g>=1), nnz(WV7.g==2));
%% 

% ---- 双 tile 堆叠直方图（共享固定 bin 边界，样式沿用 Temp 手动调整） ----
edges = linspace(-2, 2, 41);
f = figure('Color','w','Name','🔊→12h→💡  vs  🔊→7d→💡');
f.Units='centimeters'; f.Position(3:4)=[21,8];
tlo = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
sets = {WALB, 'AudioLightBaseline (12 h)'; WV7, 'Vacation7 (7 d)'};
colReact = [0.0001 0.0045 0.3319];   % reactivated 深蓝（底）
colLA = [1.0000 0.4567 0.2322];      % learned-active 橙（中）
colOther = [0.0000 0.7809 0.0000];   % other 绿（顶）
for iT = 1:2
	W = sets{iT,1};
	ax = nexttile(tlo);
	hold(ax,'on');
	nReact = histcounts(W.w(W.g==2), edges);
	nLA = histcounts(W.w(W.g==1), edges);
	nOther = histcounts(W.w(W.g==0), edges);
	counts = [nReact(:), nLA(:), nOther(:)];
	h = bar(ax, edges(1:end-1)+diff(edges)/2, counts, 1, 'stacked','EdgeColor','none');
	h(1).FaceColor = colReact;
	h(2).FaceColor = colLA;
	h(3).FaceColor = colOther;
	xline(ax,0,':','HandleVisibility','off');
	box(ax,'off');
	title(ax, sets{iT,2});
	if iT==1
		legend(ax, h, {'reactivated','learned-active','other'}, 'Box','off','Location','northwest');
	end
end
xlabel(tlo,'Choice decoder weight');
ylabel(tlo,'Cell count');

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2F_ChoiceWeight_ReactivationStack.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base','Fig2F_Stack', struct('edges',edges,'ALB',WALB,'V7',WV7));

%% ========== local functions ==========
function [g, ok] = iGroupForMouse(DS, m, cids, baseMask, idx1s, kSigma)
% 每鼠 learned/transfer 活跃与 reactivated 分组：2=reactivated,1=learned-active 未 reactivated,0=其它
g = zeros(numel(cids),1); ok = false;
T = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus"]);
T.Mouse=string(T.Mouse); T.Stimulus=string(T.Stimulus); T.Phase=string(T.Phase); T.DateTime=datetime(T.DateTime);
Tm = T(T.Mouse==m,:);
aw = Tm(Tm.Stimulus=="AudioWater" & Tm.Phase~="Recall",:);
lw = Tm(Tm.Stimulus=="LightWater" & Tm.Phase=="Transfer",:);
if isempty(aw) || isempty(lw), return; end
dtL = max(aw.DateTime); dtT = min(lw.DateTime);
GL = DS.QueryNTATS(struct('Mouse',m,'Stimulus',"AudioWater",'DateTime',dtL), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GT = DS.QueryNTATS(struct('Mouse',m,'Stimulus',"LightWater",'DateTime',dtT), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
actL = iActiveFromNtats(GL, baseMask, idx1s, kSigma);
actT = iActiveFromNtats(GT, baseMask, idx1s, kSigma);
react = intersect(actL, actT);
laOnly = setdiff(actL, react);
g(ismember(cids, laOnly)) = 1;
g(ismember(cids, react)) = 2;
ok = true;
end

function [w, cids, ok] = iChoiceWeightV7(DS, m, idx1s, strm)
% Vacation7 无现成解码器：AudioWater(非 Recall) +1 s，w=(m1-m0)/sp²，类别平衡 100 次平均
w = []; cids = uint64([]); ok = false;
% NaN 已降级为警告，QueryNTS 可正常返回；事后剔除基线为 0 的坏 trial
% （vtf1005 TrialUID 2071 整 trial 无信号，见 2026-11-01 核查）
r = DS.QueryNTS(struct('Mouse',m,'Stimulus',"AudioWater"), UniExp.Flags.ZScore, 1:48, 'ExtraColumns',["Behavior","Phase"]);
if iscell(r), r = r{1}; end
if isempty(r), return; end
r = r(uint64(r.TrialUID) ~= 2071, :);
r = r(string(r.Phase)~="Recall",:);
r.CellUID = uint64(r.CellUID); r.TrialUID = uint64(r.TrialUID);
cids = unique(r.CellUID);
if numel(cids) < 10, return; end
[F, beh] = iTrialCellBehavior(r, cids, idx1s);
okB = isfinite(beh) & all(isfinite(F),2);
F = F(okB,:); beh = beh(okB);
if sum(beh==1)<3 || sum(beh==0)<3, return; end
w = iWeightBalanced(F, beh, strm, 100).';
ok = true;
end

function [F, beh] = iTrialCellBehavior(t, cids, idxT)
tu = unique(t.TrialUID);
F = nan(numel(tu), numel(cids));
beh = nan(numel(tu),1);
sig = double(t.TrialSignal);
b = double(t.Behavior);
for iR = 1:height(t)
	ci = find(cids == t.CellUID(iR));
	ti = find(tu == t.TrialUID(iR));
	if ~isempty(ci) && ~isempty(ti)
		F(ti,ci) = sig(iR, idxT);
		beh(ti) = b(iR);
	end
end
end

function w = iWeightBalanced(F, y, strm, nDraws)
% 与 BuildCueChoiceDecoderData 相同：多数类下采样到少数类，w=(m1-m0)/sp²
n1 = sum(y==1); n0 = sum(y==0);
w = zeros(1, size(F,2));
for d = 1:nDraws
	i1 = find(y==1); i0 = find(y==0);
	if n1 > n0
		i1 = i1(randperm(strm, n1, n0));
	elseif n0 > n1
		i0 = i0(randperm(strm, n0, n1));
	end
	idx = [i1; i0];
	Fb = F(idx,:); yb = y(idx);
	m1 = mean(Fb(yb==1,:),1); m0 = mean(Fb(yb==0,:),1);
	sp = std(Fb,0,1);
	w = w + (m1 - m0) ./ max(sp.^2, eps);
end
w = w / nDraws;
end

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
