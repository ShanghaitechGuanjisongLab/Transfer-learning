function dt = iNormalizeDateTime(dt)
try
    dt = datetime(dt);
    if isdatetime(dt) && ~isempty(dt.TimeZone)
        dt.TimeZone = '';
    end
catch
end
end
