function img = DecodeCifarRowToImage(row)
r = reshape(row(1:1024), [32 32])';
g = reshape(row(1025:2048), [32 32])';
b = reshape(row(2049:3072), [32 32])';
img = cat(3, r, g, b);
end
