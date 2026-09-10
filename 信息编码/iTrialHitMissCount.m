function beh = iTrialHitMissCount(tt)
% Per-trial behavior label (mode of Behavior within each TrialUID).
% Empty input returns an empty column vector. Beh values: hit=1, miss=0.
if height(tt) == 0; beh = zeros(0,1); return; end
tu = unique(uint64(tt.TrialUID));
beh = nan(numel(tu),1);
for k = 1:numel(tu)
    beh(k) = mode(tt.Behavior(uint64(tt.TrialUID)==tu(k)));
end
end