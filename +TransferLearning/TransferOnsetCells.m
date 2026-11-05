function R = TransferOnsetCells(DS, Options)
% TransferOnsetCells  在同一批细胞上比较训练模态与转移模态试次的活动起始时刻。
%
% 分别在训练模态与转移模态试次下调用EarlyOnsetCells，再用OnsetAgreement对齐并检验：
% 训练态标定出的early-onset细胞在转移模态试次中是否仍为early-onset。
%
% 对齐方式(Options.AlignBy)：
%   "session" — 按(Mouse, Session, CellUID)对齐。适用于穿插数据库：同一会话内同时含
%               两种模态试次，可直接配对。
%   "cell"    — 按(Mouse, CellUID)对齐，跨会话聚合。适用于非穿插数据库：训练模态与
%               转移模态分处不同会话，只能依赖慢性成像的细胞追踪。
%
% 输出R为struct：Cells（对齐后的表）、Stats（见OnsetAgreement）、Trained、Transfer。

arguments
	DS
	Options.TrainedStimulus (1,1) string
	Options.TransferStimulus (1,1) string
	Options.TrainedDesigns (1,:) string = strings(1, 0)
	Options.TransferDesigns (1,:) string = strings(1, 0)
	Options.TrainedSessions (:,1) datetime = NaT(0, 1)
	Options.TransferSessions (:,1) datetime = NaT(0, 1)
	Options.AlignBy (1,1) string {mustBeMember(Options.AlignBy, ["session", "cell"])} = "session"
	Options.ExcludePhases (1,:) string = "Naive"
	Options.MinRT (1,1) double = 0.10
	Options.MaxRT (1,1) double = 0.50
	Options.MovementOnset (1,1) string {mustBeMember(Options.MovementOnset, ["lick", "outcome"])} = "lick"
	Options.MinTrialsPerSession (1,1) double = 3
	Options.NShuffle (1,1) double = 1000
	Options.Seed (1,1) double = 42
end

common = namedargs2cell(rmfield(Options, {'TrainedStimulus', 'TransferStimulus', 'TrainedDesigns', 'TransferDesigns', 'TrainedSessions', 'TransferSessions', 'AlignBy'}));
Trained = TransferLearning.EarlyOnsetCells(DS, 'Stimulus', Options.TrainedStimulus, 'Designs', Options.TrainedDesigns, 'Sessions', Options.TrainedSessions, common{:});
Transfer = TransferLearning.EarlyOnsetCells(DS, 'Stimulus', Options.TransferStimulus, 'Designs', Options.TransferDesigns, 'Sessions', Options.TransferSessions, common{:});

Agreed = TransferLearning.OnsetAgreement(Trained, Transfer, AlignBy=Options.AlignBy);

R.Cells = renamevars(Agreed.Cells, ...
	["NSessionFirst", "ActiveFirst", "FirstOnset", "FirstEarly", "NSessionSecond", "ActiveSecond", "SecondOnset", "SecondEarly"], ...
	["NSessionTrained", "ActiveTrained", "TrainedOnset", "TrainedEarly", "NSessionTransfer", "ActiveTransfer", "TransferOnset", "TransferEarly"]);
R.Stats = Agreed.Stats;
R.Trained = Trained;
R.Transfer = Transfer;
end
