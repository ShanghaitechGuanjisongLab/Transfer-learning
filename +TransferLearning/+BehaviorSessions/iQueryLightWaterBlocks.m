function T = iQueryLightWaterBlocks(DS, IncludeBlockUID, AnyDesign)
%IQUERYLIGHTWATERBLOCKS 含光水试次的逐试次行为表
%
%   默认口径（2026-11-02 起）：按 **Design = "LightWater"** 选块，而不是按
%   逐试次的 Stimulus。原因：LightAudioBaseline 里存在 design = LLw、
%   LAInterspersed 里存在 design = LAuWLw / LAuWLwAuw 的混合块，它们含
%   LightWater 试次，但整块并非纯光水设计。
%
%   AnyDesign = true 时**不做 Design 过滤**，返回所有含 LightWater 试次的块。
%   这是 naive 组「首次接触光水」的正确口径：naive 的定义是未接触过光水线索，
%   而混合块（LLw / LAuWLw）里已经包含首批配对过的光水试次，用 Design 口径
%   会跳过它们、把第二次训练当作起点（会把 naive 首块从 0.160 抬到 0.243）。
%
%   同时剔除无行为记录的试次（Performance 为 NaN；例如 AudioLightBaseline 的
%   block 47 虽然 design 是 LightWater，但整块缺行为记录）。
%
%   输出列：Mouse | DateTime | Stimulus | Design | Phase | Performance [| BlockUID]

if nargin < 2
	IncludeBlockUID = false;
end
if nargin < 3
	AnyDesign = false;
end

varsTry = ["Mouse","DateTime","Stimulus","Design","Phase","Behavior"];
varsFallback = ["Mouse","DateTime","Stimulus","Design","Phase","Performance"];
if IncludeBlockUID
	varsTry = [varsTry, "BlockUID"];
	varsFallback = [varsFallback, "BlockUID"];
end

try
	T = DS.TableQuery(varsTry, Stimulus="LightWater");
catch
	T = DS.TableQuery(varsFallback, Stimulus="LightWater");
end

if isempty(T)
	return;
end

% 选块口径：Design 必须是纯 LightWater
% （注意：直接 TableQuery(..., Design=...) 会让 Phase 标注大量丢失，
%  因此先按 Stimulus 取出、再用 Design 过滤，两者结合）
if ~ismember('Design', T.Properties.VariableNames)
	error('TransferLearning:BehaviorSessions:MissingDesign', ...
		'TableQuery result lacks Design; cannot enforce Design=LightWater.');
end
T.Design = string(T.Design);
if ~AnyDesign
	T = T(T.Design == "LightWater", :);
end

if ismember('Behavior', T.Properties.VariableNames) && ~ismember('Performance', T.Properties.VariableNames)
	T.Performance = T.Behavior;
end
if ismember('Behavior', T.Properties.VariableNames)
	T = removevars(T, 'Behavior');
end

% 无行为记录的试次不计入（否则整块 Performance 平均会变 NaN）
if ismember('Performance', T.Properties.VariableNames)
	T = T(~isnan(T.Performance), :);
end

if ismember('Stimulus', T.Properties.VariableNames)
	T.Stimulus = string(T.Stimulus);
end
end
