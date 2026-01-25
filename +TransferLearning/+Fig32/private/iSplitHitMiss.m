function [hit, miss] = iSplitHitMiss(uid, bh)
uid = uint64(uid);
bh = double(bh);
hit = {uid(bh == 1)};
miss = {uid(bh == 0)};
end
