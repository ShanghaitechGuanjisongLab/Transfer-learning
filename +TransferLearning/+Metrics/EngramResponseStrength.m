function R = EngramResponseStrength(DS, options)
%ENGRAMRESPONSESTRENGTH 印迹细胞在旧任务与新任务首个 block 的响应强度
%
%   R = TransferLearning.Metrics.EngramResponseStrength(DS)
%   R = TransferLearning.Metrics.EngramResponseStrength(DS, LearnedPhase="Learned", ...)
%
%   对每只鼠：
%     1. 取最后一个 "学会" 的旧任务会话（默认 Phase=Learned, Stimulus=AudioWater）；
%     2. 取新任务的首个会话（默认 Phase=Transfer, Stimulus=LightWater）；
%     3. 在两会话共同记录的细胞上，按 cue +1 s 判据（z > 基线均值 + 3σ，
%        基线 −3–0 s）定义印迹细胞（learned-active）；
%     4. 计算这些细胞在旧任务 block 与新区块 cue +1 s 的平均 z（响应强度），
%        并给出被再次招募（learned-active 且 transfer-active）的细胞数与强度。
%
%   输出列：Mouse | NEngram | AmpLearned | AmpTransfer | NReact | AmpReact
%
%   用途：判断间隔造成的衰减是"细胞变弱"还是"能被招募的细胞变少"。
%
%   注意：强度以 z 表示（相对该细胞自身试次变异），跨组可比但非绝对幅度。

arguments
	DS
	options.LearnedPhase (1, 1) string = "Learned"
	options.LearnedStimulus (1, 1) string = "AudioWater"
	options.TransferPhase (1, 1) string = "Transfer"
	options.TransferStimulus (1, 1) string = "LightWater"
	options.KSigma (1, 1) double = 3
end

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx1s] = min(abs(xsSec(:) - 1));
kSigma = options.KSigma;

R = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
	'VariableNames', {'Mouse', 'NEngram', 'AmpLearned', 'AmpTransfer', 'NReact', 'AmpReact'});

TL = DS.TableQuery(["Mouse","DateTime"], Phase=options.LearnedPhase, ...
	Stimulus=options.LearnedStimulus, Design=options.LearnedStimulus);
TT = DS.TableQuery(["Mouse","DateTime"], Phase=options.TransferPhase, ...
	Stimulus=options.TransferStimulus, Design=options.TransferStimulus);
if isempty(TL) || isempty(TT)
	return;
end
TL.Mouse = string(TL.Mouse);
TT.Mouse = string(TT.Mouse);
gL = groupsummary(TL, "Mouse", "max", "DateTime");
gT = groupsummary(TT(:, ["Mouse","DateTime"]), "Mouse", "min", "DateTime");
S = innerjoin(gL(:, {'Mouse','max_DateTime'}), gT(:, {'Mouse','min_DateTime'}), 'Keys', 'Mouse');
if isempty(S)
	return;
end

for i = 1:height(S)
	m = S.Mouse(i);
	QL = table(categorical(options.LearnedPhase), categorical(options.LearnedStimulus), ...
		categorical(options.LearnedStimulus), categorical(m), S.max_DateTime(i), "Learned", ...
		'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
	QT = table(categorical(options.TransferPhase), categorical(options.TransferStimulus), ...
		categorical(options.TransferStimulus), categorical(m), S.min_DateTime(i), "Transfer", ...
		'VariableNames', {'Phase','Stimulus','Design','Mouse','DateTime','GroupName'});
	GL = DS.QueryNTATS(QL, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	GT = DS.QueryNTATS(QT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	XL = iResponseMatrix(GL.NTATS);
	XT = iResponseMatrix(GT.NTATS);
	if isempty(XL) || isempty(XT)
		continue;
	end
	[~, iL, iT] = intersect(uint64(GL.CellUID), uint64(GT.CellUID), 'stable');
	if numel(iL) < 3
		continue;
	end
	XL = XL(iL, :);
	XT = XT(iT, :);

	learnedActive = iActiveAt1s(XL, baseMask, idx1s, kSigma);
	transferActive = iActiveAt1s(XT, baseMask, idx1s, kSigma);
	if ~any(learnedActive)
		continue;
	end
	react = learnedActive & transferActive;
	ampReact = NaN;
	if any(react)
		ampReact = mean(XT(react, idx1s), 'omitnan');
	end
	R = [R; table(m, nnz(learnedActive), mean(XL(learnedActive, idx1s), 'omitnan'), ...
		mean(XT(learnedActive, idx1s), 'omitnan'), nnz(react), ampReact, ...
		'VariableNames', R.Properties.VariableNames)]; %#ok<AGROW>
end
end

function X = iResponseMatrix(X)
if isa(X, 'MATLAB.DataTypes.NDTable')
	X = X.Data;
end
X = double(X);
if ndims(X) == 3
	X = squeeze(X(:, :, 1));
end
end

function active = iActiveAt1s(X, baseMask, idx1s, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
active = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > baseMu + kSigma .* baseSd);
end
