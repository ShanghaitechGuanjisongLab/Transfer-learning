
function G_TargetDrop_PosContribTopHalf
% 图3.2g（按论文大纲口径）：
% 剔除 Learned 阶段对相关性正贡献最高的 Top50% 细胞后，Transfer 相关性显著下降，且强于随机剔除对照（按层）。
%
% 数据来源（scratch 输出）：
% - Scratch_TargetDrop_PosContribTopHalf_1s1p5_ByLayer
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig32.G_TargetDrop_PosContribTopHalf

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2g_TargetDrop_PosContribTop50_1s1p5_ByLayer.svg";

% --- Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% --- Ensure scratch exists
TransferLearning.Scratch.Transfer_CellCorr_Attribution_PosContribTopHalf_1s_1p5s_ByLayer();

if evalin('base', "exist('Scratch_TargetDrop_PosContribTopHalf_1s1p5_ByLayer','var')") ~= 1
	error('Fig3_2g_TargetDrop:Missing', 'Missing base var Scratch_TargetDrop_PosContribTopHalf_1s1p5_ByLayer.');
end

rows = evalin('base','Scratch_TargetDrop_PosContribTopHalf_1s1p5_ByLayer');
rows.ZLayer = string(rows.ZLayer);

layerNames = string(["MOp2/3","MOp5"]);

f = figure('Color','w', 'Name','Fig3.2g Target drop');
try
	MATLAB.Graphics.FigureAspectRatio(8,3.6,1/2);
catch
end
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

ylabel(TL,'Δz = atanh(r_{all}) - atanh(r_{drop})');

axList = gobjects(1,2);
for i = 1:2
	ax = nexttile(TL, i); hold(ax,'on'); iHideToolbar(ax);
	iPanel(ax, rows, layerNames(i));
	axList(i) = ax;
	if i == 2
		ax.YAxis.Visible = 'off';
	end
end

% Unify Y across panels + hide right Y axis
try
	MATLAB.Graphics.UnifyAxesLims(axList, @ylim);
catch
end

% Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end
svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers

function iPanel(ax, rows, zLayer)
	R = rows(rows.ZLayer==string(zLayer), :);
	dTarget = double(R.DeltaZ_Target);
	dRand = double(R.DeltaZ_RandMean);
	use = isfinite(dTarget) & isfinite(dRand);

	title(ax, string(zLayer));
	xticks(ax,[1 2]);
	xlim(ax,[0.5 2.5]);
	xticklabels(ax, {'Random(mean)','Target(Top50%)'});
	grid(ax,'on'); box(ax,'on');

	if nnz(use) == 0
		return;
	end

	% paired lines per mouse
	for k = 1:height(R)
		if ~(isfinite(dTarget(k)) && isfinite(dRand(k)))
			continue;
		end
		plot(ax, [1 2], [dRand(k) dTarget(k)], '-', 'Color',[0.7 0.7 0.7]);
	end
	scatter(ax, ones(nnz(use),1), dRand(use), 26, 'filled');
	scatter(ax, 2*ones(nnz(use),1), dTarget(use), 26, 'filled');

	d = dTarget(use) - dRand(use);
	p = NaN;
	if nnz(isfinite(d)) >= 4
		p = signrank(d(isfinite(d)), 0, 'tail','right');
	end
	try
		iPValuePLineScatter(ax, 1, 2, dRand(use), dTarget(use), p);
	catch
	end

	fprintf('Fig3.2g %s: signrank(Target-Rand>0) p=%.4g (n=%d)\n', zLayer, p, nnz(use));
end

function iPValuePLineScatter(ax, x1, x2, y1, y2, p, extraOffset)
	if nargin < 7 || isempty(extraOffset)
		extraOffset = 0;
	end
	if ~isfinite(p)
		return;
	end
	y1 = y1(:);
	y2 = y2(:);
	y1 = y1(isfinite(y1));
	y2 = y2(isfinite(y2));
	if isempty(y1) || isempty(y2)
		return;
	end

	X = [x1*ones(numel(y1),1); x2*ones(numel(y2),1)];
	Y = [y1; y2];
	S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end

	Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), extraOffset, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		MATLAB.Graphics.PLine(Descriptors);
	catch
	end

	try
		delete(S);
	catch
	end
end

function iHideToolbar(ax)
	try
		set(ax.Toolbar, 'Visible', 'off');
	catch
	end
end

end
