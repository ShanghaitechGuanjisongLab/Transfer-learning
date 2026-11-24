% 论点④ 的行为混淆对照（简版：模式相关，不做 PCA 轨迹）
%
% 问题：V7 的 Transfer hit 率 0.13（ALB 0.52）。所以 V7 的 L→T 相似性低
%       有两种解释：(i) 复用机制失效；(ii) 根本没学会。
%
% 三个条件对比（都以 Learned(hit) 的平均模式 vL 为参照）：
%   r_LT_hit  = corr(vL, Transfer 的 hit 试次)
%   r_LT_all  = corr(vL, Transfer 全部试次)
%   r_LF_hit  = corr(vL, Final  的 hit 试次)      ← 此时行为已恢复（hit≈1）
%
% 判读：
%   · V7: r_LT_hit 明显高于 r_LT_all ⇒ 行为失败是主因
%   · V7: r_LF_hit 仍低 ⇒ 即使重新学会，复用也不恢复 ⇒ 延迟改变了机制
%   · V7: r_LF_hit 高 ⇒ 复用可恢复，只是被行为拖累
%
% 口径：QueryNTS(ZScore)，0–1.5 s 平均；逐鼠算，跨细胞 Pearson r。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');
warning('off', 'UniExp:Exception:NaN_appears_after_normalization');

tAll = linspace(-3, 3, 48)';
iW = find(tAll >= 0 & tAll <= 1.5);
LayerSel = "MOp2/3";

cohorts = ["ALB", "V7"];
DSs = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
Rows = {};
logMsg = strings(0, 1);

for ic = 1:2
	DS = DSs{ic};
	T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
	T.Mouse = string(T.Mouse); T.Phase = string(T.Phase); T.Stimulus = string(T.Stimulus);
	Tb = DS.TableQuery(["TrialUID", "Behavior"]);
	uT = uint64(Tb.TrialUID); bAll = double(Tb.Behavior);
	Cx = DS.Cells; Cx.CellUID = uint64(Cx.CellUID); Cx.ZLayer = string(Cx.ZLayer);
	layerUID = Cx.CellUID(Cx.ZLayer == LayerSel);

	for m = unique(T.Mouse, 'stable')'
		spec = {"Learned", "AudioWater"; "Transfer", "LightWater"; "Final", "LightWater"};
		dt = NaT(3, 1);
		for j = 1:3
			sel = T.Mouse == m & T.Phase == spec{j, 1} & T.Stimulus == spec{j, 2};
			if any(sel), dt(j) = T.DateTime(find(sel, 1)); end
		end
		if any(isnat(dt))
			logMsg(end + 1, 1) = cohorts(ic) + " " + m + " 缺 session"; %#ok<SAGROW>
			continue;
		end
		M = cell(3, 1); B = cell(3, 1); ok = true;
		for j = 1:3
			try
				nts = DS.QueryNTS(struct('Mouse', m, 'DateTime', dt(j), 'Stimulus', spec{j, 2}), ...
					UniExp.Flags.ZScore, 1:24);
				if iscell(nts), nts = nts{1}; end
				if isempty(nts), ok = false; break; end
				M{j} = iMat(nts, layerUID, iW);
				B{j} = iBeh(nts, uT, bAll);
			catch
				ok = false; break;
			end
		end
		if ~ok
			logMsg(end + 1, 1) = cohorts(ic) + " " + m + " 提取失败"; %#ok<SAGROW>
			continue;
		end

		iLh = find(B{1} == 1);
		iTh = find(B{2} == 1);
		iTa = 1:numel(B{2});
		iFh = find(B{3} == 1);
		if numel(iLh) < 5 || numel(iFh) < 5
			logMsg(end + 1, 1) = cohorts(ic) + " " + m + sprintf(" 试次不足 Lh=%d Th=%d Fh=%d", ...
				numel(iLh), numel(iTh), numel(iFh)); %#ok<SAGROW>
			continue;
		end

		good = all(all(isfinite(M{1}(:, iLh, :)), 2), 3) & ...
			all(all(isfinite(M{2}(:, iTa, :)), 2), 3) & ...
			all(all(isfinite(M{3}(:, iFh, :)), 2), 3);
		if sum(good) < 50
			logMsg(end + 1, 1) = cohorts(ic) + " " + m + sprintf(" 细胞不足 %d", sum(good)); %#ok<SAGROW>
			continue;
		end

		vL  = mean(mean(M{1}(good, iLh, :), 3, 'omitnan'), 2, 'omitnan');
		vTh = mean(mean(M{2}(good, iTh, :), 3, 'omitnan'), 2, 'omitnan');
		vTa = mean(mean(M{2}(good, iTa, :), 3, 'omitnan'), 2, 'omitnan');
		vFh = mean(mean(M{3}(good, iFh, :), 3, 'omitnan'), 2, 'omitnan');

		Rows(end + 1, :) = {cohorts(ic), string(m), sum(good), numel(iLh), ...
			numel(iTh), numel(iTa), numel(iFh), ...
			iCorrSafe(vL, vTh, numel(iTh)), iCorr(vL, vTa), iCorr(vL, vFh)}; %#ok<SAGROW>
	end
end

if ~isempty(logMsg)
	fprintf('\n跳过的鼠:\n');
	for i = 1:numel(logMsg), fprintf('  %s\n', logMsg(i)); end
end

T2 = cell2table(Rows, 'VariableNames', ["Cohort", "Mouse", "NCells", "nLrnHit", ...
	"nTrnHit", "nTrnAll", "nFinHit", "r_LT_hit", "r_LT_all", "r_LF_hit"]);
csvPath = fullfile(thisDir, 'Check_V7DelayControl.csv');
writetable(T2, csvPath);
fprintf('\nWrote: %s\n', csvPath);

%% 汇总
fprintf('\n=== 与 Learned(hit) 的模式相关 ===\n');
f = @(x) sprintf('%.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan') / sqrt(sum(isfinite(x))));
pp = @(x) sprintf('p=%.3g', signrank(x(isfinite(x))));
for c = cohorts
	sel = T2.Cohort == c;
	if sum(sel) < 3, continue; end
	fprintf('%-4s n=%d | hit 率: Trn=%.2f Fin=%.2f\n', c, sum(sel), ...
		mean(T2.nTrnHit(sel) ./ T2.nTrnAll(sel)), mean(T2.nFinHit(sel) ./ T2.nTrnAll(sel)));
	fprintf('     r(L,T hit)=%s (%s)\n', f(T2.r_LT_hit(sel)), pp(T2.r_LT_hit(sel)));
	fprintf('     r(L,T all)=%s (%s)\n', f(T2.r_LT_all(sel)), pp(T2.r_LT_all(sel)));
	fprintf('     r(L,F hit)=%s (%s)\n', f(T2.r_LF_hit(sel)), pp(T2.r_LF_hit(sel)));
end
sa = T2.Cohort == "ALB"; sv = T2.Cohort == "V7";
fprintf('\n组间:\n');
fprintf('  r_LT_hit p=%.3g | r_LT_all p=%.3g | r_LF_hit p=%.3g\n', ...
	ranksum(T2.r_LT_hit(sa), T2.r_LT_hit(sv)), ...
	ranksum(T2.r_LT_all(sa), T2.r_LT_all(sv)), ...
	ranksum(T2.r_LF_hit(sa), T2.r_LF_hit(sv)));

%% ========== local ==========
function M = iMat(nts, cells, iW)
Tu = unique(nts.TrialUID, 'stable');
[~, jj] = ismember(nts.TrialUID, Tu);
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal(:, iW));
M = nan(numel(cells), numel(Tu), numel(iW));
for i = 1:numel(cells)
	r = find(cu == cells(i));
	if isempty(r), continue; end
	M(i, jj(r), :) = sig(r, :);
end
end

function b = iBeh(nts, uT, bAll)
Tu = unique(nts.TrialUID, 'stable');
[ok, ib] = ismember(uint64(Tu), uT);
b = nan(numel(Tu), 1); b(ok) = bAll(ib(ok));
end

function r = iCorrSafe(a, b, nMin)
if nMin < 5, r = NaN; return; end
r = iCorr(a, b);
end

function r = iCorr(a, b)
ok = isfinite(a) & isfinite(b);
a = a(ok); b = b(ok);
a = a - mean(a); b = b - mean(b);
r = (a' * b) / (norm(a) * norm(b));
end
