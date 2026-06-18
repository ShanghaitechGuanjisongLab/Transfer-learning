function [dlX, dlT] = PreprocessImageBatch(dataX, dataY, inputSize, classNames)
miniBatch = numel(dataX);
X = zeros([inputSize miniBatch], "single");

for i = 1:miniBatch
    img = dataX{i};
    if size(img, 3) == 1
        img = repmat(img, 1, 1, 3);
    end
    img = im2single(imresize(img, inputSize(1:2)));
    X(:, :, :, i) = img;
end

Y = cat(1, dataY{:});
T = onehotencode(Y, 2, ClassNames=classNames);

dlX = dlarray(X, "SSCB");
dlT = dlarray(single(T'), "CB");
end
