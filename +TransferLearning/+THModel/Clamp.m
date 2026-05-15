function values = Clamp(values, lowerBound, upperBound)
values = max(min(values, upperBound), lowerBound);
end
