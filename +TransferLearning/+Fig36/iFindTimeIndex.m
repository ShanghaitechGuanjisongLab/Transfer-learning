function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
% TransferLearning.Fig36.iFindTimeIndex
[dt, idx] = min(abs(double(xsSec) - double(tSec)));
ok = ~isempty(idx) && isfinite(dt) && dt <= tolSec;
end
