function TrialTable = BuildTHInhibitTrialTable()
% Trial-level light-water learning data for THInhibit imaging mice.
% Include Transfer through Final, including unlabelled intermediate blocks.

DS = TransferLearning.THInhibit();
DT = DS.DateTimes(:,{'Mouse','DateTime','Phase'});
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
DT.DateTime = iNormDT(DT.DateTime);
B = DS.Blocks(:,{'BlockUID','DateTime'});
B.BlockUID = uint64(B.BlockUID);
B.DateTime = iNormDT(B.DateTime);
T = DS.Trials(:,{'TrialUID','BlockUID','TrialIndex','Stimulus','Behavior'});
T.BlockUID = uint64(T.BlockUID);
T.Stimulus = string(T.Stimulus);
T.Behavior = double(T.Behavior);
T = innerjoin(T,B,'Keys','BlockUID');
T = innerjoin(T,DT,'Keys','DateTime');
TrialTable = table();
for mouse = unique(DT.Mouse(DT.Phase == "Transfer")).'
	Q = T(T.Mouse == mouse,:);
	Dm = DT(DT.Mouse == mouse,:);
	startDT = min(Dm.DateTime(Dm.Phase == "Transfer"));
	endCandidates = Dm.DateTime(Dm.Phase == "Final" & Dm.DateTime >= startDT);
	if isempty(endCandidates)
		endDT = max(Q.DateTime(Q.Stimulus == "LightWater"));
	else
		endDT = max(endCandidates);
	end
	Q = Q(Q.DateTime >= startDT & Q.DateTime <= endDT & ...
		Q.Stimulus == "LightWater" & isfinite(Q.Behavior),:);
	if isempty(Q)
		continue;
	end
	Q.Group = repmat("THInhibit",height(Q),1);
	Q.Source = repmat("THInhibit",height(Q),1);
	TrialTable = [TrialTable;Q]; %#ok<AGROW>
end
TrialTable = iAddBlockIndex(TrialTable);
end

function T = iAddBlockIndex(T)
T.Block = zeros(height(T),1);
for mouse = unique(string(T.Mouse)).'
	mask = string(T.Mouse) == mouse;
	[~,~,index] = unique(T.DateTime(mask));
	T.Block(mask) = index;
end
end

function dt = iNormDT(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end
