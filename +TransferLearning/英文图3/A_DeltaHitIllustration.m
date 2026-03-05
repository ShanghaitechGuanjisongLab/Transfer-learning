% 英文图3B：ΔHit 示意图
%
% 取 Transfer cohort (AudioLightBaseline) 中一只代表性鼠的 LightWater 学习曲线，
% 在图上标注两个相邻会话之间的行为增量 ΔHit。
%
% 执行方式（脚本，直接 F5 或在 MATLAB Editor 中运行）：
%   run('+TransferLearning/英文图3/B_DeltaHitIllustration.m')

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

% --- Preconditions
if ~exist('UniExp.DataSet', 'class')
	error('EnglishFig3B:MissingUniExp', 'UniExp is not on path; load the project first.');
end

DS = TransferLearning.AudioLightBaseline();

% --- 1) Build per-session LightWater hit rate (all phases) for each mouse
Sess = iLightWaterSessions(DS);
if isempty(Sess)
	error('EnglishFig3B:NoSessions', 'No LightWater sessions found.');
end

Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);

% --- 2) Pick a representative mouse: prefer one with ≥5 sessions and non-trivial variation
mice = unique(Sess.Mouse);
bestMouse = "";
bestScore = -Inf;
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	nS = height(R);
	if nS < 5
		continue;
	end
	perf = double(R.Performance);
	% Score: reward more sessions and a nice upward trend
	score = nS + 5 * (perf(end) - perf(1));
	if score > bestScore
		bestScore = score;
		bestMouse = m;
	end
end

if bestMouse == ""
	% Fallback: just pick first mouse with most sessions
	[~, G] = findgroups(Sess.Mouse);
	nPerMouse = splitapply(@height, Sess(:,1), findgroups(Sess.Mouse));
	[~, ix] = max(nPerMouse);
	bestMouse = G(ix);
end

R = Sess(Sess.Mouse == bestMouse, :);
R = sortrows(R, 'Session');
xSess = double(R.Session);
yPerf = double(R.Performance);

% --- 3) Choose TWO annotation pairs in the rising part
dH = diff(yPerf);
posIdx = find(dH > 0);
if numel(posIdx) < 2
	% Fallback: pick two consecutive pairs near the middle
	annoIdx = unique(min([max(1,floor(numel(yPerf)/2)), max(2,floor(numel(yPerf)/2)+1)], numel(yPerf)-1));
else
	% Pick the two largest positive ΔHit pairs (non-overlapping)
	[~, sortOrder] = sort(dH(posIdx), 'descend');
	pick1 = posIdx(sortOrder(1));
	pick2 = [];
	for k = 2:numel(sortOrder)
		cand = posIdx(sortOrder(k));
		if abs(cand - pick1) >= 2
			pick2 = cand;
			break;
		end
	end
	if isempty(pick2)
		pick2 = posIdx(sortOrder(min(2, numel(sortOrder))));
	end
	annoIdx = sort([pick1, pick2]);
end
if isscalar(annoIdx)
	annoIdx = [annoIdx, min(annoIdx+2, numel(yPerf)-1)];
end

% Assign Pair A (较大 ΔHit) and Pair B (较小 ΔHit)
dHAnno = dH(annoIdx);
if dHAnno(1) >= dHAnno(2)
	pairLetters = ["A", "B"];
else
	pairLetters = ["B", "A"];
end

%% 
% --- 4) Plot
svgName = "English_Fig3A_DeltaHitIllustration.svg";
f = figure('Color', 'w', 'Name', 'English Fig3B ΔHit illustration');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4]; % 45mm x 35mm

ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

% Learning curve
plot(ax, xSess, yPerf, '-o', ...
	'Color', [0 0.4470 0.7410], ...
	'MarkerSize', 3, ...
	'MarkerFaceColor', [0 0.4470 0.7410], ...
	'LineWidth', 1);

% Pair colors — match Fig3G
colorPairA = [0.8500 0.3250 0.0980]; % orange
colorPairB = [0 0.4470 0.7410];      % blue

% Pair markers: Pair A = square ('s'  ■), Pair B = triangle ('^'  ▲)
% These same markers are echoed in Fig3B row labels (Pair A/B)
markerPairA = 's';
markerPairB = '^';

% --- 5) Annotate each ΔHit pair
for iA = 1:numel(annoIdx)
	ai = annoIdx(iA);
	xA1 = xSess(ai);
	xA2 = xSess(ai + 1);
	yA1 = yPerf(ai);
	yA2 = yPerf(ai + 1);
	delta = yA2 - yA1;
	if pairLetters(iA) == "A"
		aColor = colorPairA;
		aMarker = markerPairA;
	else
		aColor = colorPairB;
		aMarker = markerPairB;
	end

	% Highlight sessions with pair-specific marker
	scatter(ax, [xA1 xA2], [yA1 yA2], 25, aColor, aMarker, 'filled');

	% Bracket position: stagger right so two brackets don't overlap
	xArrow = xA2 + 0.35 + (iA - 1) * 0.2;

	% Vertical line
	plot(ax, [xArrow xArrow], [yA1 yA2], '-', 'Color', aColor, 'LineWidth', 1);

	% Horizontal ticks
	tickW = 0.15;
	plot(ax, [xArrow - tickW, xArrow + tickW], [yA1 yA1], '-', 'Color', aColor, 'LineWidth', 1);
	plot(ax, [xArrow - tickW, xArrow + tickW], [yA2 yA2], '-', 'Color', aColor, 'LineWidth', 1);

	% Dashed guides
	plot(ax, [xA1 xArrow], [yA1 yA1], '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
	plot(ax, [xA2 xArrow], [yA2 yA2], '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);

	% Label with pair letter and numeric value
	yMid = (yA1 + yA2) / 2;
	if delta >= 0
		dhStr = sprintf('\\DeltaHit=+%.0f%%', delta * 100);
	else
		dhStr = sprintf('\\DeltaHit=%.0f%%', delta * 100);
	end
	lblStr = {sprintf('Pair %s', pairLetters(iA)), dhStr};
	text(ax, xArrow + 0.2, yMid, lblStr, ...
		'FontSize', 5, 'Color', aColor, ...
		'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
		'FontWeight', 'bold');
end

title(ax, 'Representative mouse', 'FontSize', 6, 'FontWeight', 'normal');
xlabel(ax, 'Block');
ylabel(ax, 'Hit rate');
ylim(ax, [0 1]);
xlim(ax, [0.5, max(xSess) + 2.5]);

% --- 6) Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ---- local helpers (no try-catch)

function Sess = iLightWaterSessions(DS)
vars = ["Mouse","DateTime","BlockUID","Phase"];
Tblk = DS.TableQuery(vars);
if isempty(Tblk)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end

if ~isprop(DS, 'Trials')
	error('EnglishFig3B:MissingTrials', 'DataSet has no Trials table.');
end
Tr = DS.Trials;
need = {'BlockUID','Stimulus','Behavior'};
if ~all(ismember(need, Tr.Properties.VariableNames))
	error('EnglishFig3B:TrialsMissingFields', 'Trials table lacks required fields.');
end

TrStim = string(Tr.Stimulus);
TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

Tblk.Mouse = string(Tblk.Mouse);
Tblk.DateTime = datetime(Tblk.DateTime);
if isdatetime(Tblk.DateTime) && ~isempty(Tblk.DateTime.TimeZone)
	Tblk.DateTime.TimeZone = '';
end

blkUID64 = uint64(Tblk.BlockUID);
[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
Tblk = Tblk(tf, :);
Tblk.LWPerf = perfByBlock.LWPerf(loc(tf));

[G2, mouse, dt] = findgroups(string(Tblk.Mouse), Tblk.DateTime);
perf = splitapply(@(x) mean(double(x),'omitnan'), Tblk.LWPerf, G2);
nBlocks = splitapply(@numel, Tblk.LWPerf, G2);
Sess = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse','DateTime'});
[G, ~] = findgroups(T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end
