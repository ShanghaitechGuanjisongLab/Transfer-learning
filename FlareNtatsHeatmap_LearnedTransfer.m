%[text] # FLARE：Learned/Transfer × hM4D(Gi)/Others 的 NTATS 热图（仅 Learned/Transfer）
%[text] 输出：SVG + PNG(300dpi)

outDir = "\\Data-Server-2\个人数据\张天夫\202512";
mkdir(outDir);

Fig = TransferLearning.FlareNtatsHeatmapFigure("LearnedTransfer");

baseName = "FLARE hM4D(Gi)与Others细胞NTATS热图 LearnedTransfer";
svgPath = fullfile(outDir, baseName + ".svg");
pngPath = fullfile(outDir, baseName + ".png");

print(Fig, svgPath, '-dsvg');
exportgraphics(Fig, pngPath, 'Resolution', 300);

fprintf('Saved:\n  %s\n  %s\n', svgPath, pngPath);
