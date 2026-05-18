function pattern = BinaryPattern(values)
values = values(:);
pattern = zeros(size(values), 'like', values);
pattern(values > 0) = 1;
end