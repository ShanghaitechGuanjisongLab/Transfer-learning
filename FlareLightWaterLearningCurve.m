% FLARE 鼠光水任务学习曲线
% - 数据来源：TransferLearning.scFLARE (vtf0451.UniExp.mat)
% - 指标口径：UniExp.DataSet.TableQuery(...).Performance + UniExp.LearningSummarize

% 每次启动 MATLAB 后通常需要先打开 Transferlearning 工程，才能确保 UniExp 等包在路径上。
% 这里做兜底：若 UniExp 未在路径上，则自动加载本目录下的 Transferlearning.prj。
iEnsureTransferLearningProjectLoaded();

% 从 TransferLearning 载入数据库很慢：尽量复用已载入的数据集对象（跨脚本复用）
[Flare, Ctrl] = iGetWorkspaceCachedDataSets();

% 统一口径：取 LightWater 的 block/session（每行一个 block/session）
FlareSession = sortrows(Flare.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater"), "DateTime");
CtrlSession = sortrows(Ctrl.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater"), "DateTime");

FlareSummary = UniExp.LearningSummarize(FlareSession);
CtrlSummary = UniExp.LearningSummarize(CtrlSession);

[flareMean, flareSem] = iUnpackLearningSummary(FlareSummary);
[ctrlMean, ctrlSem] = iUnpackLearningSummary(CtrlSummary);

flareMean = double(flareMean(:));
ctrlMean = double(ctrlMean(:));
flareSem = double(flareSem(:));
ctrlSem = double(ctrlSem(:));
if isempty(flareSem), flareSem = zeros(size(flareMean)); end
if isempty(ctrlSem), ctrlSem = zeros(size(ctrlMean)); end

maxN = max(numel(flareMean), numel(ctrlMean));
x = (1:maxN).';

padTo = @(v,n) [v(:); nan(max(0,n-numel(v)),1)];
MeanMat = [padTo(flareMean,maxN), padTo(ctrlMean,maxN)];
SemMat = [padTo(flareSem,maxN), padTo(ctrlSem,maxN)];

Fig = figure('Color','w');
ax = axes(Fig);
hold(ax,'on');

% 不允许使用 plot：一律使用 MultiShadowedLines
axes(ax);

% 避开白色背景（两条线）
EdgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
Patches = MATLAB.Graphics.MultiShadowedLines(MeanMat, SemMat, EdgeColors=EdgeColors(1:2,:));

% 鼠的个数写在 legend（不是标题）
nFlareMice = numel(unique(FlareSession.Mouse));
nCtrlMice = numel(unique(CtrlSession.Mouse));
labels = compose(["FLARE hM4D(Gi)全程化学抑制 (n=%d)", "声转光对照 (n=%d)"], [nFlareMice, nCtrlMice]);
assert(numel(Patches) >= 2, 'MultiShadowedLines 返回的图元数量不足以生成 legend。');
legend(ax, Patches(1:2), labels, 'Location', 'southeast');

xlabel(ax,'Blocks');
ylabel(ax,'Hit rate');
flareMouse = "FLARE";
flareMouse = string(unique(FlareSession.Mouse));
if numel(flareMouse) > 1
	flareMouse = strjoin(flareMouse, ",");
end
box(ax,'off');
ylim(ax,[0 1]);
title(ax, sprintf('Light-water learning curve: FLARE(%s) vs 声转光对照', flareMouse));

% legend 已在 MultiShadowedLines 后设置；此处不再兜底调用，避免覆盖句柄

% 参考 Fig1 的版式设置（若相关工具存在则启用）
MATLAB.Graphics.FigureAspectRatio(1,1,MATLAB.Flags.Narrow);

% 导出到共享路径（UNC）并使用中文文件名
outDir = "\\Data-Server-2\个人数据\张天夫\202512";
if ~isfolder(outDir)
	mkdir(outDir);
end
outSvg = fullfile(outDir, "FLARE与对照光水任务学习曲线.svg");
outPng = fullfile(outDir, "FLARE与对照光水任务学习曲线.png");

% 导出时隐藏坐标区工具栏（避免 SVG 中出现 toolbar）
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

print(Fig, outSvg, '-dsvg');
print(Fig, outPng, '-dpng', '-r300');

fprintf('Saved: %s\n', outSvg);
fprintf('Saved: %s\n', outPng);

function [meanCurve, semCurve] = iUnpackLearningSummary(summary)
	if ~istable(summary)
		if isstruct(summary) && isfield(summary, 'MeanCurve') && isfield(summary, 'SemCurve')
			meanCurve = summary.MeanCurve;
			semCurve = summary.SemCurve;
			return;
		end
		summary = struct2table(summary);
	end

	if height(summary) >= 1
		meanCurve = summary.MeanCurve(1);
		semCurve = summary.SemCurve(1);
	else
		meanCurve = [];
		semCurve = [];
		return;
	end

	if iscell(meanCurve) && numel(meanCurve) == 1
		meanCurve = meanCurve{1};
	end
	if iscell(semCurve) && numel(semCurve) == 1
		semCurve = semCurve{1};
	end
end

function iEnsureTransferLearningProjectLoaded()
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjPath = fullfile(thisDir, 'Transferlearning.prj');
	if ~isfile(prjPath)
		error('未找到工程文件: %s', prjPath);
	end

	matlab.project.loadProject(prjPath);

end

function [Flare, Ctrl] = iGetWorkspaceCachedDataSets()
	% 在 base 工作区中缓存已加载/预处理的 DataSet，便于不同脚本之间复用
	cacheVar = 'TransferLearning_DataSetCache';

	vars = evalin('base', 'who');
	cacheExists = any(strcmp(vars, cacheVar));
	if cacheExists
		cache = evalin('base', cacheVar);
	else
		cache = struct();
	end

	if isstruct(cache) && isfield(cache, 'Flare') && isfield(cache, 'Ctrl')
		Flare = cache.Flare;
		Ctrl = cache.Ctrl;
		return;
	end

	% 缓存不存在或不可用：重新载入并写回 base 工作区
		% 确保路径已就绪（尤其是 UniExp.DataSet）
		iEnsureTransferLearningProjectLoaded();
		cache = struct();
		cache.Flare = TransferLearning.scFLARE;
		cache.Ctrl = TransferLearning.AudioLightBaseline; % 正常声转光迁移任务对照
		cache.CreatedAt = datetime('now');
		assignin('base', cacheVar, cache);

	Flare = cache.Flare;
	Ctrl = cache.Ctrl;
end
