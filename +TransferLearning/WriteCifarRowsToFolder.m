function WriteCifarRowsToFolder(X, rowIndices, outDir, fileNames, useParallelWrite)
count = numel(rowIndices);
if count == 0
    return;
end

Xsel = X(rowIndices, :);

if useParallelWrite
    parfor k = 1:count
        img = TransferLearning.DecodeCifarRowToImage(Xsel(k, :));
        imwrite(img, fullfile(outDir, fileNames{k}));
    end
else
    for k = 1:count
        img = TransferLearning.DecodeCifarRowToImage(Xsel(k, :));
        imwrite(img, fullfile(outDir, fileNames{k}));
    end
end
end
