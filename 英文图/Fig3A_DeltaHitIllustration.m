% 英文图3A：ΔHit 示意图
%
% 取 Transfer cohort (AudioLightBaseline) 中一只代表性鼠的 LightWater 学习曲线，
% 在图上标注两个相邻会话之间的行为增量 ΔHit。
%
% 执行方式（脚本，直接 F5 或在 MATLAB Editor 中运行）：
%   run('英文图/Fig3A_DeltaHitIllustration.m')

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

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
Sess = iExcludeCeiling(Sess);
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

% --- 3) Choose ONE annotation pair in the rising part
dH = diff(yPerf);
posIdx = find(isfinite(dH) & dH > 0);
if isempty(posIdx)
	annoIdx = max(1, min(numel(yPerf)-1, floor(numel(yPerf)/2)));
else
	[~, sortOrder] = sort(dH(posIdx), 'descend');
	annoIdx = posIdx(sortOrder(1));
end

%% 
% --- 4) Plot
svgName = "English_Fig3A_DeltaHitIllustration.svg";
f = figure('Color', 'w', 'Name', 'English Fig3A ΔHit illustration');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4]; % 45mm x 35mm
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

% Learning curve (no markers on line — annotation scatter provides them)
standardColors = TransferLearning.GroupColors(["Naive", "Continual", "Learned"]);
plot(ax, xSess, yPerf, '-', ...
	'Color', standardColors(2,:), ...
	'LineWidth', 1);

colorPairA = standardColors(2,:);
colorPairB = standardColors(1,:);
colorGuide = standardColors(3,:);

% Session-position markers: Previous block = square ('s' ■), Latter block = triangle ('^' ▲)
% Both pairs share the same shapes; pair identity is indicated by color only.
% These shapes are echoed in Fig3B column titles.
markerPrev = 's';
markerLatt = '^';

% --- 5) Annotate the chosen ΔHit pair
ai = annoIdx;
xA1 = xSess(ai);
xA2 = xSess(ai + 1);
yA1 = yPerf(ai);
yA2 = yPerf(ai + 1);
delta = yA2 - yA1;
aColor = colorPairA;

scatter(ax, xA1, yA1, 25, aColor, markerPrev, 'filled');
scatter(ax, xA2, yA2, 25, aColor, markerLatt, 'filled');

xArrow = xA2 + 0.35;
plot(ax, [xArrow xArrow], [yA1 yA2], '-', 'Color', aColor, 'LineWidth', 1);

tickW = 0.15;
plot(ax, [xArrow - tickW, xArrow + tickW], [yA1 yA1], '-', 'Color', aColor, 'LineWidth', 1);
plot(ax, [xArrow - tickW, xArrow + tickW], [yA2 yA2], '-', 'Color', aColor, 'LineWidth', 1);

plot(ax, [xA1 xArrow], [yA1 yA1], '--', 'Color', colorGuide, 'LineWidth', 0.5);
plot(ax, [xA2 xArrow], [yA2 yA2], '--', 'Color', colorGuide, 'LineWidth', 0.5);

yMid = (yA1 + yA2) / 2;
if delta >= 0
	dhStr = sprintf('\\DeltaHit=+%.0f%%', delta * 100);
else
	dhStr = sprintf('\\DeltaHit=%.0f%%', delta * 100);
end
text(ax, xArrow + 0.2, yMid, dhStr, ...
	'FontSize', 5, 'Color', aColor, ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
	'FontWeight', 'bold');

title(ax, 'Representative mouse', 'FontSize', 6, 'FontWeight', 'normal');
xlabel(ax, 'Block');
ylabel(ax, 'Hit rate');
ylim(ax, [0 1]);
xlim(ax, [0.5, max(xSess) + 2.5]);

% --- 6) Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
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

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(isfinite(p) & p >= 1 - 1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

