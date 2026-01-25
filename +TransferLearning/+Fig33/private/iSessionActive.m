function tf = iSessionActive(Z, winMask, thr)
m = median(Z, 1, 'omitnan');
pk = max(m(winMask), [], 'omitnan');
tf = isfinite(pk) && pk >= thr;
end
