% Fig1g｜舔水细节：与 Fig1c 完全同口径（直接跟随 LightWaterLearningSessions 的 Session 1）
%
% 只统计 cue 窗口（0–1 s）：
%   undelayed 范式里 cue 前必须不舔（−3~0 s 实测 0.00 帧/试次），
%   cue 后 1.0 s 无条件给水（水后几乎必舔）——这两段由范式决定，不含组间信息。
%   唯一有信息量的是 **cue 期（0–1 s）**：是否在给水前就做出预期性舔水。
%
% 起点口径（与 Fig1c 一致）：
%   naive 组取"该鼠最早含 LightWater 试次的 session"（可能是 LLw / LAuWLw 混合块），
%   Transfer / 7 d 组取纯 LightWater 块的第一个 session。
%   块内一律只统计 Stimulus == LightWater 的试次。
%
% 面板：
%   (i)  cue 内首个舔水的潜伏期，累积分布（分母 = 该组全部光水试次，故曲线在 1 s
%        处的高度即 cue 期舔水率）
%   (ii) 每试次 cue 期舔水帧数（逐鼠散点 + 组均值）
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet','class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off','UniExp:Exception:Block_must_warn');

tWater = 1.0;
tt = linspace(-3,3,48)';
iCue = tt >= 0 & tt < tWater;
iPos = tt >= 0;

groupOrder = ["Naive","Transfer","7dayTransfer"];
cols = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
S1 = Sess(Sess.Session == 1, :);
sources = unique(S1.Source);

R = table(); Lat = struct();
for s = 1:numel(sources)
	DS = iGetDS(char(sources(s)));
	if isempty(DS), continue; end
	T = DS.TableQuery(["Mouse","DateTime","BlockUID","Stimulus","Behavior"]);
	T.Mouse = string(T.Mouse);
	hasLW = string(T.Stimulus) == "LightWater";
	T = T(hasLW & ~isnan(T.Behavior), :);
	Tkey = string(T.DateTime, 'yyyyMMddHHmm');

	S = S1(S1.Source == sources(s), :);
	for k = 1:height(S)
		mu = S.Mouse(k);
		r = T.Mouse == mu & Tkey == string(S.DateTime(k), 'yyyyMMddHHmm');
		bu = unique(T.BlockUID(r));
		if isempty(bu)
			fprintf('   %-10s 该 session 无可用光水试次，跳过\n', mu);
			continue;
		end
		onAll = {}; cueAll = {}; hitAll = {};
		for b = bu(:)'
			sel = DS.Trials.BlockUID == b & string(DS.Trials.Stimulus) == "LightWater";
			Tb = DS.Trials(sel, :);
			tags = Tb.ResampledTags; ok = cellfun(@(x) isa(x,'table'), tags);
			if ~any(ok), continue; end
			Lk = TransferLearning.LickTrace(tags(ok), Window=[-3 3]);
			if isempty(Lk), continue; end
			[~, j1] = max(Lk & iPos', [], 2);
			hasL = any(Lk & iPos', 2);
			on = tt(j1); on(~hasL) = NaN;
			on(on > tWater) = NaN;
			onAll{end+1}  = on;                    %#ok<SAGROW>
			cueAll{end+1} = sum(Lk(:, iCue), 2);   %#ok<SAGROW>
			hitAll{end+1} = Tb.Behavior(ok);       %#ok<SAGROW>
		end
		if isempty(onAll)
			fprintf('   %-10s 起始块缺行为 tag，跳过\n', mu);
			continue;
		end
		on = vertcat(onAll{:}); cue = vertcat(cueAll{:}); beh = vertcat(hitAll{:});
		R = [R; table(string(mu), sources(s), S.Group(k), numel(beh), mean(beh,'omitnan'), ...
			median(on,'omitnan'), mean(cue), median(cue), ...
			'VariableNames',{'Mouse','Source','Group','N','Hit','LatMed','CueMean','CueMed'})]; %#ok<AGROW>
		Lat.(matlab.lang.makeValidName(string(mu))) = on;
	end
end

fprintf('\n%-14s %-5s %-5s %-7s %-8s %-9s %-9s\n', ...
	'Group','nMice','nTr','Hit','latMed','cueMean','cueMed');
for g = groupOrder
	S = R(R.Group == g, :);
	if isempty(S), continue; end
	fprintf('%-14s %-5d %-5d %-7.2f %-8.2f %-9.2f %-9.2f\n', g, ...
		height(S), sum(S.N), mean(S.Hit), median(S.LatMed,'omitnan'), ...
		mean(S.CueMean), median(S.CueMed));
end
iPair('cue 期舔水率    ', R, 'Hit');
iPair('cue 内首舔潜伏期', R, 'LatMed');
iPair('cue 期舔水帧数  ', R, 'CueMean');
assignin('base','LickDetail', R);
assignin('base','LickLatency', Lat);

%% ---------------- 出图 ----------------
f = figure('Color','w');
f.Units = 'centimeters'; f.Position(3:4) = [16 6.2];

ax1 = axes(f,'Position',[0.085 0.19 0.40 0.66]); hold(ax1,'on');
xe = 0:0.05:tWater;
for k = 1:numel(groupOrder)
	S = R(R.Group == groupOrder(k), :);
	v = [];
	for i = 1:height(S)
		fn = matlab.lang.makeValidName(S.Mouse(i));
		if isfield(Lat, fn), v = [v; Lat.(fn)]; end %#ok<AGROW>
	end
	if isempty(v), continue; end
	cdf = arrayfun(@(e) mean(v <= e), xe);
	plot(ax1, xe, cdf, '-', 'Color', cols(k,:), 'LineWidth', 1.6);
end
xlim(ax1,[0 tWater]); ylim(ax1,[0 0.6]);
xticks(ax1, 0:0.2:1);
xlabel(ax1,'First lick latency from cue (s)');
ylabel(ax1,'Cumulative fraction of trials');
title(ax1,'First cue-period lick','FontWeight','normal','FontSize',8.5);
lg = legend(ax1, cellstr(groupOrder), 'Location','northwest','FontSize',6.5); lg.Box='off';
box(ax1,'off');

ax2 = axes(f,'Position',[0.60 0.19 0.36 0.66]); hold(ax2,'on');
M = nan(3,1);
for k = 1:3
	S = R(R.Group == groupOrder(k), :);
	M(k) = mean(S.CueMean);
end
bar(ax2, M, 0.55, 'FaceColor', [0.72 0.72 0.72], 'EdgeColor','none');
for k = 1:3
	S = R(R.Group == groupOrder(k), :);
	plot(ax2, k + 0.05*(rand(height(S),1)-0.5), S.CueMean, 'o', 'MarkerSize', 2.5, ...
		'MarkerFaceColor', cols(k,:), 'MarkerEdgeColor','none');
	sem = std(S.CueMean)/sqrt(height(S));
	plot(ax2, [k k], M(k)+[-1 1]*sem, '-', 'Color',[0.2 0.2 0.2], 'LineWidth',0.9);
end
set(ax2,'XTick',1:3,'XTickLabel',cellstr(groupOrder),'FontSize',7.5);
ylim(ax2,[0 4]);
ylabel(ax2,'Lick frames in 0-1 s');
title(ax2,'Cue-period licking','FontWeight','normal','FontSize',8.5);
box(ax2,'off');

outDir = fileparts(mfilename('fullpath'));
exportgraphics(f, fullfile(outDir,'_g.png'), 'Resolution', 150);
savefig(f, fullfile(outDir,'Fig1g_LickKinematics.fig'));

%% ---------------------------------------------------------------
function DS = iGetDS(src)
switch string(src)
	case "LightAudioBaseline"
		if evalin('base','exist(''DS_LAB'',''var'')'), DS = evalin('base','DS_LAB');
		else, DS = TransferLearning.LightAudioBaseline(); assignin('base','DS_LAB',DS); end
	case "LAInterspersed"
		if evalin('base','exist(''DS_LAI'',''var'')'), DS = evalin('base','DS_LAI');
		else, DS = TransferLearning.LAInterspersed(); assignin('base','DS_LAI',DS); end
	case "AudioLightBaseline"
		if evalin('base','exist(''DS_ALB'',''var'')'), DS = evalin('base','DS_ALB');
		else, DS = TransferLearning.AudioLightBaseline(); assignin('base','DS_ALB',DS); end
	case "Vacation7"
		if evalin('base','exist(''DS_V7'',''var'')'), DS = evalin('base','DS_V7');
		else, DS = TransferLearning.Vacation7(); assignin('base','DS_V7',DS); end
	otherwise, DS = [];
end
end

function p = iPair(name, R, v)
a = R.(v)(R.Group == "Naive"); b = R.(v)(R.Group == "Transfer"); c = R.(v)(R.Group == "7dayTransfer");
fprintf('%-18s N-T %.3f | T-7d %.3f | N-7d %.3f\n', name, iRS(a,b), iRS(b,c), iRS(a,c));
end

function p = iRS(a, b)
a = a(isfinite(a)); b = b(isfinite(b));
if numel(a) < 2 || numel(b) < 2, p = NaN; return; end
p = ranksum(a, b);
end
