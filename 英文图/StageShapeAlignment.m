% 跨队列"形状一致性"图：Procrustes 对齐后叠加 + 形状距离矩阵
%
% 目的：一眼看出各队列的轨迹形状在四个阶段上与 ALB 是否一致。
%
% ⚠ 口径（重要）：PC 的符号在独立 PCA 里是任意的，因此形状比较必须允许"镜像"。
%   本脚本用 procrustes(X,Y,'Scaling',true)（默认 Reflection='best'，即在旋转+镜像里取最优）；
%   不要用 'Reflection',false —— 那会把"PC 符号相反"误算成形状差异（实测同一形状会得到 d≈0.85）。
%
% 数据：tempdir/PCAstage_G.mat（ALB/TH/V7/LAB 的每阶段 super-mouse 表）
%       tempdir/PCAstage_G_delayed.mat（ALD，由 PCA_StageProgression_Delayed_0to8s.m 生成，首次约 35 s）
%
% Output: English_StageShapeAlignment.svg  +  English_StageShapeAlignment_d.csv

thisDir = fileparts(mfilename('fullpath'));
nComp = 3;
B = 1000;    % 鼠 bootstrap 次数

%% ---------- 取数据 ----------
mainCache = fullfile(tempdir, 'PCAstage_G.mat');
dlyCache  = fullfile(tempdir, 'PCAstage_G_delayed.mat');
if exist(mainCache, 'file') ~= 2
	run(fullfile(thisDir, 'PCA_StageProgression_ALBvsLAB_0to8s.m'));
	save(mainCache, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
end
C = load(mainCache, 'PCAstage_G', 'DSnames', 'stageNames', 'nDS');
G4 = C.PCAstage_G; names4 = string(C.DSnames(:)); stageNames = string(C.stageNames(:));

if exist(dlyCache, 'file') ~= 2
	fprintf('第一次需要生成延迟组数据（约 35 s）...\n');
	run(fullfile(thisDir, 'PCA_StageProgression_Delayed_0to8s.m'));
	save(dlyCache, 'G', 'DSnames', 'stageNames');
end
Dz = load(dlyCache, 'G', 'DSnames');
G = [G4; {Dz.G{1, 1}, Dz.G{1, 2}, Dz.G{1, 3}, Dz.G{1, 4}}];
names = [names4; "ALD"];
nDS = numel(names);

rowColor = [TransferLearning.ColorA; TransferLearning.TransferColor; ...
	TransferLearning.ColorB; TransferLearning.NaiveColor; [0.13 0.52 0.60]];
iALB = find(names == "ALB", 1);

%% ---------- 每队列×阶段：群体轨迹（细胞加权）+ 每鼠轨迹 ----------
PC = cell(nDS, 4); PM = cell(nDS, 4);
for iDS = 1:nDS
	for iS = 1:4
		data = double(G{iDS, iS}.NTATS.Data);
		mouse = string(G{iDS, iS}.Mouse);
		nC = size(data, 1); nT = size(data, 2); nL = size(data, 3);
		T = UniExp.LinearPca(MATLAB.DataTypes.NDTable(data), nComp, true);
		co = double(T.Coeff); S = double(T.Score.Data);
		PC{iDS, iS} = double(squeeze(mean(S(1:2, :, :), 3))');
		Xall = reshape(data, nC, [])';
		uM = unique(mouse);
		PM{iDS, iS} = cell(numel(uM), 1);
		for i = 1:numel(uM)
			cols = (mouse == uM(i))';
			Ssub = Xall(:, cols) * co(:, cols)';
			Sm = reshape(Ssub, nT, nL, nComp);
			mT = double(squeeze(mean(Sm, 2)));
			PM{iDS, iS}{i} = mT(:, 1:2);
		end
	end
end

%% ---------- 对齐到同阶段 ALB（允许旋转+镜像）+ d 的鼠 bootstrap CI ----------
Aligned = cell(nDS, 4); dMat = nan(nDS, 4); CI = nan(nDS, 4, 2);
for iS = 1:4
	for iDS = 1:nDS
		if iDS == iALB
			dMat(iDS, iS) = 0; Aligned{iDS, iS} = PC{iDS, iS}; CI(iDS, iS, :) = [0 0];
			continue
		end
		[dMat(iDS, iS), Aligned{iDS, iS}] = procrustes(PC{iALB, iS}, PC{iDS, iS}, 'Scaling', true);
		db = zeros(B, 1);
		NA = numel(PM{iALB, iS}); NB = numel(PM{iDS, iS});
		for t = 1:B
			tA = mean(cat(3, PM{iALB, iS}{randi(NA, NA, 1)}), 3);
			tB = mean(cat(3, PM{iDS, iS}{randi(NB, NB, 1)}), 3);
			db(t) = procrustes(tA, tB, 'Scaling', true);
		end
		CI(iDS, iS, :) = prctile(db, [2.5 97.5]);
	end
end

fprintf('\n=== 对齐到同阶段 ALB 的 Procrustes d [95%% CI]（允许旋转+镜像）===\n');
fprintf('%-9s', '阶段');
for iDS = 1:nDS, fprintf('%22s', names(iDS)); end; fprintf('\n');
for iS = 1:4
	fprintf('%-9s', stageNames(iS));
	for iDS = 1:nDS
		if iDS == iALB
			fprintf('%22s', '—(参照)');
		else
			fprintf('%10.3f [%.3f,%.3f]', dMat(iDS, iS), CI(iDS, iS, 1), CI(iDS, iS, 2));
		end
	end
	fprintf('\n');
end

%% ---------- 作图 ----------
f = figure('Color', 'w', 'Name', 'Stage shape alignment across cohorts');
f.Units = 'centimeters';
f.Position(3:4) = [22, 15];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 22, 15];
f.PaperSize = [22, 15];

% 图例条
axLeg = axes(f, 'Position', [0.045 0.925 0.91 0.04]);
axis(axLeg, 'off'); hold(axLeg, 'on');
xlim(axLeg, [0 1]); ylim(axLeg, [0 1]);
for iDS = 1:nDS
	x0 = 0.0 + (iDS - 1) * 0.135;
	lw = 2.0; if iDS == iALB, lw = 3.0; end
	plot(axLeg, [x0 x0 + 0.03], [0.5 0.5], '-', 'Color', rowColor(iDS, :), 'LineWidth', lw);
	text(axLeg, x0 + 0.04, 0.5, names(iDS), 'Color', rowColor(iDS, :), 'FontWeight', 'bold', ...
		'FontSize', 10, 'VerticalAlignment', 'middle', 'Interpreter', 'none');
end
plot(axLeg, 0.72, 0.5, 'o', 'Color', [0.4 0.4 0.4], 'MarkerFaceColor', 'w', 'MarkerSize', 5);
text(axLeg, 0.74, 0.5, 'cue (0 s)', 'FontSize', 8, 'Color', [0.4 0.4 0.4], 'VerticalAlignment', 'middle');
plot(axLeg, 0.85, 0.5, 's', 'Color', [0.4 0.4 0.4], 'MarkerFaceColor', [0.4 0.4 0.4], 'MarkerSize', 5);
text(axLeg, 0.87, 0.5, '8 s', 'FontSize', 8, 'Color', [0.4 0.4 0.4], 'VerticalAlignment', 'middle');

% 四个阶段 tile
w = 0.215; h = 0.36; yb = 0.455;
xs = 0.035 + (0:3) * 0.238;
axTop = gobjects(1, 4);
for k = 1:4
	ax = axes(f, 'Position', [xs(k) yb w h]);
	hold(ax, 'on');
	for iDS = 1:nDS
		xy = Aligned{iDS, k};
		lw = 2.0; if iDS == iALB, lw = 3.0; end
		plot(ax, xy(:, 1), xy(:, 2), '-', 'Color', rowColor(iDS, :), 'LineWidth', lw, ...
			'HandleVisibility', 'off');
		plot(ax, xy(1, 1), xy(1, 2), 'o', 'Color', rowColor(iDS, :), 'MarkerSize', 4, ...
			'MarkerFaceColor', 'w', 'HandleVisibility', 'off');
		plot(ax, xy(end, 1), xy(end, 2), 's', 'Color', rowColor(iDS, :), 'MarkerSize', 4, ...
			'MarkerFaceColor', rowColor(iDS, :), 'HandleVisibility', 'off');
	end
	title(ax, stageNames(k));
	box(ax, 'off');
	ax.FontSize = 10;
	axTop(k) = ax;
end
% 四个 tile 统一轴范围（按盒子长宽比，形状不变形）
boxAR = (w * f.Position(3)) / (h * f.Position(4));
Xa = []; Ya = [];
for k = 1:4
	for iDS = 1:nDS
		xy = Aligned{iDS, k};
		Xa = [Xa; xy(:, 1)]; %#ok<AGROW>
		Ya = [Ya; xy(:, 2)]; %#ok<AGROW>
	end
end
S = max((max(Xa) - min(Xa)) / boxAR, max(Ya) - min(Ya)) * 1.08;
xspan = S * boxAR;
cx = (max(Xa) + min(Xa)) / 2; cy = (max(Ya) + min(Ya)) / 2;
for k = 1:4
	axTop(k).XLim = cx + [-1 1] * xspan / 2;
	axTop(k).YLim = cy + [-1 1] * S / 2;
end
xlabel(axTop(2), 'aPC1 (aligned)');
ylabel(axTop(1), 'aPC2 (aligned)');

%% 形状距离矩阵（阶段 × 队列）
axH = axes(f, 'Position', [0.30 0.07 0.27 0.25]);
keepRows = setdiff(1:nDS, iALB);
dShow = dMat(keepRows, :);                % 队列（不含 ALB）× 阶段
imagesc(axH, dShow);
colormap(axH, flipud(gray(256)) * 0.55 + 0.45);   % 0 = 浅灰，1 = 深
caxis(axH, [0 1]);
set(axH, 'XTick', 1:4, 'XTickLabel', stageNames, 'YTick', 1:numel(keepRows), ...
	'YTickLabel', names(keepRows), 'TickLength', [0 0], 'XTickLabelRotation', 25);
for i = 1:size(dShow, 1)
	for j = 1:size(dShow, 2)
		v = dShow(i, j);
		tc = [0 0 0]; if v > 0.55, tc = [1 1 1]; end
		text(axH, j, i, sprintf('%.2f', v), 'HorizontalAlignment', 'center', ...
			'FontSize', 9, 'Color', tc, 'FontWeight', 'bold');
	end
end
axH.FontSize = 9;
title(axH, 'shape distance d to same-stage ALB');
cb = colorbar(axH);
cb.Label.String = 'Procrustes d (0 = identical)';
cb.FontSize = 8;

TransferLearning.ApplyStandardExportStyle(f, 2);
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_StageShapeAlignment.svg');
fprintf('Wrote: %s\n', svgPath);

% 数值表
csvPath = fullfile(thisDir, 'English_StageShapeAlignment_d.csv');
fid = fopen(csvPath, 'w');
fprintf(fid, 'Stage,Cohort,d,CI_lo,CI_hi\n');
for iS = 1:4
	for iDS = 1:nDS
		if iDS == iALB, continue; end
		fprintf(fid, '%s,%s,%.4f,%.4f,%.4f\n', stageNames(iS), names(iDS), ...
			dMat(iDS, iS), CI(iDS, iS, 1), CI(iDS, iS, 2));
	end
end
fclose(fid);
fprintf('Wrote: %s\n', csvPath);
