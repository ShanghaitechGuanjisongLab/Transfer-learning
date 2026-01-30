% Fig3.7E：比较 放假7天组 vs 对照组 的 P(T|F)
%
% 参考：Fig3.6H（分组口径） + Fig3.3D（P(T|F)口径）
% - F: Final LightWater（每鼠最后纯光水，会话内禁止混入 AudioWater）
% - T: Transfer LightWater（每鼠首个纯光水，会话内禁止混入 AudioWater）
% - P(T|F)=P(TransferLight active@1s | FinalLight active@1s)
% - 按层分别统计：MOp2/3 与 MOp5
%
% Output:
% - SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig37.E_PTgivenL_Vacation7VsCtrl

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_7e_Vacation7VsCtrl_PTgivenL_Reuse_1s.svg";

% --- ensure project loaded
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

CtrlDS = TransferLearning.AudioLightBaseline();
ExpDS  = TransferLearning.Vacation7();

RCtrl = TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer('DataSet', CtrlDS, 'Source', "AudioLightBaseline");
RExp  = TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer('DataSet', ExpDS,  'Source', "Vacation7");
if isempty(RCtrl) || isempty(RExp)
	error('Fig3_7e:EmptyBuild', 'Empty rows from P(T|F) builder.');
end

RCtrl.Group = repmat("Ctrl", height(RCtrl), 1);
RExp.Group  = repmat("Vac7", height(RExp), 1);

RCtrl = RCtrl(:, {'Group','Mouse','DateTimeTransfer','Prob23','Prob5'});
RExp  = RExp(:,  {'Group','Mouse','DateTimeTransfer','Prob23','Prob5'});
R = [RCtrl; RExp];

R.Mouse = string(R.Mouse);
R.ZKey = strings(height(R), 1);
R.PTgivenF = nan(height(R), 1);
R.ZKey(:) = "MOp23";
R.PTgivenF(:) = double(R.Prob23);
R2 = R;
R2.ZKey(:) = "MOp5";
R2.PTgivenF(:) = double(R2.Prob5);
R = [R; R2];

R = R(:, {'Group','Mouse','DateTimeTransfer','ZKey','PTgivenF'});
if isempty(R)
	error('Fig3_7e:Empty', 'No valid mice for reuse analysis.');
end

% Exclude yqn1130：信号差且缺少5层（会导致 MOp5 子图不可比）
try
	R.Mouse = string(R.Mouse);
	R = R(R.Mouse ~= "yqn1130", :);
catch
end

assignin('base','Fig3_7e_Vac7VsCtrl_Rows', R);

Stats = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), 'VariableNames', {'ZKey','NCtrl','NExp','P_Ranksum_PTgivenF'});
for zKey = ["MOp23","MOp5"]
	A = R(R.Group=="Ctrl" & R.ZKey==zKey, :);
	B = R(R.Group=="Vac7" & R.ZKey==zKey, :);
	pa = double(A.PTgivenF); pb = double(B.PTgivenF);
	pa = pa(isfinite(pa)); pb = pb(isfinite(pb));
	p = NaN;
	if numel(pa) >= 3 && numel(pb) >= 3
		try
			p = ranksum(pa, pb);
		catch
			p = NaN;
		end
	end
	Stats = [Stats; table(string(zKey), double(numel(pa)), double(numel(pb)), double(p), 'VariableNames', Stats.Properties.VariableNames)]; %#ok<AGROW>
end
assignin('base','Fig3_7e_Vac7VsCtrl_Stats', Stats);

% Plot
f = figure('Color','w', 'Name','Fig3.7E P(T|F) Vacation7 vs Ctrl');
try
	MATLAB.Graphics.FigureAspectRatio(1,1,2/3);
catch
end

tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');
zKeys = ["MOp23","MOp5"]; zLabels = ["MOp2/3","MOp5"];
axList = gobjects(1, numel(zKeys));
pLineAll = matlab.graphics.primitive.Line.empty(0,1);
pTextAll = matlab.graphics.primitive.Text.empty(0,1);
for iZ = 1:numel(zKeys)
	zKey = zKeys(iZ);
	ax = nexttile(tl, iZ);
	axList(iZ) = ax;
	hold(ax,'on'); grid(ax,'on'); box(ax,'off');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	A = R(R.Group=="Ctrl" & R.ZKey==zKey, :);
	B = R(R.Group=="Vac7" & R.ZKey==zKey, :);
	pa = double(A.PTgivenF); pb = double(B.PTgivenF);
	pa = pa(isfinite(pa)); pb = pb(isfinite(pb));

	iJitterScatter(ax, 1, pa, [0.2 0.2 0.2]);
	iJitterScatter(ax, 2, pb, [0.2 0.5 0.9]);
	try
		boxchart(ax, ones(size(pa)), pa, 'BoxFaceColor',[0.85 0.85 0.85], 'MarkerStyle','none', 'BoxWidth',0.45);
		boxchart(ax, 2*ones(size(pb)), pb, 'BoxFaceColor',[0.80 0.90 1.00], 'MarkerStyle','none', 'BoxWidth',0.45);
	catch
	end
	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('Ctrl'), sprintf('Vac7')};
	ylabel(ax, 'P(T|F) @1 s', 'Interpreter','none');
	title(ax, zLabels(iZ), 'Interpreter','none');

	st = Stats(Stats.ZKey==zKey, :);
	if ~isempty(st)
		[ln, tx] = iPLineRanksum(ax, pa, pb, st.P_Ranksum_PTgivenF);
		try
			if ~isempty(ln); pLineAll(end+1:end+numel(ln),1) = ln(:); end %#ok<AGROW>
			if ~isempty(tx); pTextAll(end+1:end+numel(tx),1) = tx(:); end %#ok<AGROW>
		catch
		end
	end
	try
		ax.YGrid = 'off';
		ax.YMinorGrid = 'off';
	catch
	end
end

% If we hide right-panel Y axis, y-lims must be unified across tiles
try
	MATLAB.Graphics.UnifyAxesLims(axList, @ylim);
catch
end

% PLine needs retune after y-lims change
try
	MATLAB.Graphics.PLineRetune(pLineAll, pTextAll);
catch
end

% Hide right-panel Y axis
try
	axs = findobj(f, 'Type','axes');
	if numel(axs) >= 2
		axs = flipud(axs(:));
		axs(2).YTickLabel = [];
		axs(2).YLabel.String = '';
		axs(2).YTick = [];
		axs(2).YAxis.Visible = 'off';
	end
catch
end
sgtitle(tl, 'Vac7 vs Ctrl: P(T|F) @1s', 'Interpreter','none');

% ensure all text uses automatic font sizing
iSetFontSizeAuto(f);

% Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% --- local helpers

function iJitterScatter(ax, x0, y, color)
y = double(y(:));
use = isfinite(y);
y = y(use);
if isempty(y)
	return;
end

x = x0 + (rand(size(y)) - 0.5) * 0.18;
scatter(ax, x, y, 18, 'filled', 'MarkerFaceColor', color, 'MarkerFaceAlpha', 0.65);
end

function [pLines, pTexts] = iPLineRanksum(ax, y1, y2, p)
pLines = matlab.graphics.primitive.Line.empty(0,1);
pTexts = matlab.graphics.primitive.Text.empty(0,1);
if ~isfinite(p)
	return;
end
y1 = double(y1(:)); y2 = double(y2(:));
y1 = y1(isfinite(y1)); y2 = y2(isfinite(y2));
if isempty(y1) || isempty(y2)
	return;
end
try
	X = [ones(numel(y1),1); 2*ones(numel(y2),1)];
	Y = [y1; y2];
	S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end
	Descriptors = table(S, 0, 0, ("p=" + sprintf('%.3g', p)), 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	[pLines, pTexts] = MATLAB.Graphics.PLine(Descriptors);
	try, delete(S); catch, end
catch
end
end

function iSetFontSizeAuto(fig)
try
	objs = findall(fig, '-property', 'FontSizeMode');
	set(objs, 'FontSizeMode', 'auto');
catch
end
end
