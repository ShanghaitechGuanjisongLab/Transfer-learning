%% Sample LightWater learning curves: steepest vs shallowest slope
% 从所有 Light Water 数据中找出 slope 最大和最小的单鼠（至少3个block）
% 绘制各自的 learning curve + sigmoid fit

%% 0. 项目加载
prjRoot = 'd:\Users\杨青宁\Documents\MATLAB\Transfer-learning';
if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
		addpath(prjRoot);
	end
end

%% 1. 加载所有 Light Water 数据
LAB  = TransferLearning.LightAudioBaseline();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();
LAI  = TransferLearning.LAInterspersed();

naiveAnchors = ["Naive","Learned"];
tranAnchors  = ["Transfer","Final"];

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", naiveAnchors(1), naiveAnchors(2));
tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", tranAnchors(1), tranAnchors(2));
tranB  = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA; tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";
allSessions = [naive; tran];
allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

fprintf('Total LightWater sessions: %d\n', height(allSessions));

%% 2. 逐鼠 sigmoid 拟合（至少3个block）
mice = unique(string(allSessions.Mouse));
slopeVec = nan(numel(mice), 1);
nSessVec = zeros(numel(mice), 1);
mouseGroup = strings(numel(mice), 1);

for iM = 1:numel(mice)
	m = mice(iM);
	R = sortrows(allSessions(string(allSessions.Mouse) == m, :), 'DateTime');
	x = double(R.Session);
	y = double(R.Performance);
	ok = isfinite(x) & isfinite(y);
	x = x(ok); y = y(ok);
	nSessVec(iM) = numel(x);
	if numel(x) < 3 || numel(unique(y)) < 2
		continue;
	end
	mouseGroup(iM) = string(R.Group(1));
	% 拟合 lower=0, upper=1 的 sigmoid
	obj = @(p) sum((y - (1 ./ (1 + exp(-abs(p(1)) .* (x - p(2)))))).^2);
	p = fminsearch(obj, [0.5; median(x)], optimset('Display','off'));
	slopeVec(iM) = abs(p(1));
end

%% 3. 找 slope 最大和最小的鼠（至少3个block）
validIdx = find(isfinite(slopeVec) & nSessVec >= 3);
[~, idxMin] = min(slopeVec(validIdx));
[~, idxMax] = max(slopeVec(validIdx));
minMouse = mice(validIdx(idxMin));
maxMouse = mice(validIdx(idxMax));
minSlope = slopeVec(validIdx(idxMin));
maxSlope = slopeVec(validIdx(idxMax));
minGroup = mouseGroup(validIdx(idxMin));
maxGroup = mouseGroup(validIdx(idxMax));

fprintf('\n=== 最值 ===\n');
fprintf('Slope 最小: %s (Group=%s, slope=%.4f, %d sessions)\n', minMouse, minGroup, minSlope, nSessVec(validIdx(idxMin)));
fprintf('Slope 最大: %s (Group=%s, slope=%.4f, %d sessions)\n', maxMouse, maxGroup, maxSlope, nSessVec(validIdx(idxMax)));

% 打印所有斜率
fprintf('\n所有鼠斜率:\n');
for iM = 1:numel(mice)
	if isfinite(slopeVec(iM))
		fprintf('  %s (%s): slope=%.4f, n=%d sessions\n', mice(iM), mouseGroup(iM), slopeVec(iM), nSessVec(iM));
	end
end

%% 4. 绘制 sample 曲线
f = figure('Color','w', 'Name','Sample LightWater curves');
f.Units = 'centimeters';
f.Position(3:4) = [16, 6];
t = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'compact');

colorMin = [0.6 0.3 0.8]; % 紫
colorMax = [0.9 0.5 0.1]; % 橙

for iPlot = 1:2
	if iPlot == 1
		m = minMouse; grp = minGroup; clr = colorMin; titleStr = sprintf('Shallowest slope (%.3f)', minSlope);
	else
		m = maxMouse; grp = maxGroup; clr = colorMax; titleStr = sprintf('Steepest slope (%.3f)', maxSlope);
	end
	R = sortrows(allSessions(string(allSessions.Mouse) == m, :), 'DateTime');
	x = double(R.Session);
	y = double(R.Performance);

	nexttile(t);
	hold on;
	% 散点
	plot(x, y, 'o', 'Color', clr, 'MarkerFaceColor', clr, 'MarkerSize', 8, 'LineWidth', 1.5);
	% sigmoid 拟合线
	xFit = linspace(0.5, max(x)+1, 200);
	obj = @(p) sum((y - (1 ./ (1 + exp(-abs(p(1)) .* (x - p(2)))))).^2);
	p = fminsearch(obj, [0.5; median(x)], optimset('Display','off'));
	yFit = 1 ./ (1 + exp(-abs(p(1)) .* (xFit - p(2))));
	plot(xFit, yFit, '-', 'Color', clr, 'LineWidth', 2);

	xlabel('Block'); ylabel('Hit rate');
	xlim([0.5, max(x)+1]); ylim([0 1.02]);
	title(titleStr, 'FontWeight','normal');
	box off; grid off;
	set(gca, 'FontSize', 12, 'LineWidth', 1.5);
	text(mean(xlim), 0.95, sprintf('Mouse: %s\nGroup: %s\nSlope: %.3f', m, grp, abs(p(1))), ...
		'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', 10);
end

title(t, 'Sample LightWater learning curves', 'FontWeight','normal');
svgPath = fullfile('\\Data-Server-2\个人数据\杨青宁\202607', 'SampleLightWaterCurves.svg');
exportgraphics(f, svgPath, 'ContentType','vector');
fprintf('Wrote: %s\n', svgPath);

%% 本地函数（从 Fig33B 移植）
function out = iLightWaterSessionsByMouse(DS, sourceName, startPhase, endPhase)
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Performance'});
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	out = T(:, {'Mouse','DateTime','Performance'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, startPhase, endPhase)
	if string(startPhase) == "Naive" || string(endPhase) == "Naive"
		badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
	else
		badMice = string.empty(0,1);
	end
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Performance'});
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isempty(badMice), T = T(~ismember(T.Mouse, badMice), :); end
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	out = T(:, {'Mouse','DateTime','Performance'});
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end
end

function T = iQueryLightWaterBehaviorAll(DS)
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus="LightWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="LightWater");
	end
	if isempty(T), return; end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
end

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	startPhase = string(startPhase); endPhase = string(endPhase);
	if isempty(S), return; end
	S.Mouse = string(S.Mouse); S.Phase = string(S.Phase);
	S = sortrows(S, {'Mouse','DateTime'});
	mice = unique(S.Mouse);
	keepRows = false(height(S),1);
	for i = 1:numel(mice)
		idx = find(S.Mouse == mice(i));
		st = find(S.Phase(idx) == startPhase, 1, 'first');
		if isempty(st), continue; end
		ed = find(S.Phase(idx) == endPhase & (1:numel(idx))' >= st, 1, 'first');
		if isempty(ed), ed = numel(idx); end
		keepRows(idx(st:ed)) = true;
	end
	S = S(keepRows, :);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	badMice = string.empty(0,1);
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = unique(string(Ta.Mouse));
	end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', T.Properties.VariableNames), T.Phase = repmat(missing, height(T), 1); end
	if useBehavior
		T = T(:, {'Mouse','DateTime','Behavior','Phase'});
	else
		T = T(:, {'Mouse','DateTime','Performance','Phase'});
	end
	T.Mouse = string(T.Mouse); T = sortrows(T, {'Mouse','DateTime'});
	if useBehavior, val = double(T.Behavior); else, val = double(T.Performance); end
	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
	S = table(mouseKeys, dtKeys, perf, phaseSession, 'VariableNames', {'Mouse','DateTime','Performance','Phase'});
end

function ph = iPickSessionPhase(phases)
	[u,~,ic] = unique(phases); counts = accumarray(ic, 1); [~,ix] = max(counts); ph = u(ix);
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end
