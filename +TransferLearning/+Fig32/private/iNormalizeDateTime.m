function dt = iNormalizeDateTime(dt)
try
	dt = datetime(dt);
catch
	% leave as-is
end
try
	if isdatetime(dt)
		dt.TimeZone = '';
	end
catch
end
end
