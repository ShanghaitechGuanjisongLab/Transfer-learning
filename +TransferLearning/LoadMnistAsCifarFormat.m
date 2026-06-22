function [Xrows, y] = LoadMnistAsCifarFormat(dataRoot, splitName, valRatio, randomSeed)
rawDir = fullfile(dataRoot, "raw", "mnist");

if splitName == "train"
    imgFile = fullfile(rawDir, "train-images-idx3-ubyte");
    lblFile = fullfile(rawDir, "train-labels-idx1-ubyte");
else
    imgFile = fullfile(rawDir, "t10k-images-idx3-ubyte");
    lblFile = fullfile(rawDir, "t10k-labels-idx1-ubyte");
end

fid = fopen(imgFile, "rb");
fread(fid, 1, "int32", 0, "ieee-be");
nImgs = fread(fid, 1, "int32", 0, "ieee-be");
nRows = fread(fid, 1, "int32", 0, "ieee-be");
nCols = fread(fid, 1, "int32", 0, "ieee-be");
imgs = fread(fid, inf, "uint8");
fclose(fid);
imgs = reshape(imgs, [nCols nRows nImgs]);
imgs = permute(imgs, [2 1 3]);

fid = fopen(lblFile, "rb");
fread(fid, 1, "int32", 0, "ieee-be");
nLbls = fread(fid, 1, "int32", 0, "ieee-be");
labels = fread(fid, inf, "uint8") + 1;
fclose(fid);

assert(nImgs == nLbls);

nTotal = nImgs;
Xrows = zeros([nTotal 3072], "uint8");
for i = 1:nTotal
    img28 = single(imgs(:, :, i));
    img32 = imresize(img28, [32 32]);
    img32u = uint8(round(img32));
    Xrows(i, 1:1024) = reshape(img32u', 1, []);
    Xrows(i, 1025:2048) = reshape(img32u', 1, []);
    Xrows(i, 2049:3072) = reshape(img32u', 1, []);
end
y = labels;

if nargin >= 3 && ~isempty(valRatio) && valRatio > 0
    rng(randomSeed);
    uniqueClasses = unique(y);
    XrowsOut = {};
    yOut = {};
    for ci = 1:numel(uniqueClasses)
        idx = find(y == uniqueClasses(ci));
        idx = idx(randperm(numel(idx)));
        nVal = round(valRatio * numel(idx));
        trainIdx = idx(nVal+1:end);
        XrowsOut{ci} = Xrows(trainIdx, :);
        yOut{ci} = y(trainIdx);
    end
    Xrows = vertcat(XrowsOut{:});
    y = vertcat(yOut{:});
end
end
