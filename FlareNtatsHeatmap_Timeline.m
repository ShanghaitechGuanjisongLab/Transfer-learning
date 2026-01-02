%[text] # FLARE：Learned→Transfer→Final（含过渡会话）× hM4D(Gi)/Others 的 NTATS 热图
%[text] 输出：SVG + PNG(300dpi)

outDir = "\\Data-Server-2\个人数据\张天夫\202512";
mkdir(outDir);

Fig = TransferLearning.FlareNtatsHeatmapFigure("Timeline");

baseName = "FLARE hM4D(Gi)与Others细胞NTATS热图 Timeline";
svgPath = fullfile(outDir, baseName + ".svg");
pngPath = fullfile(outDir, baseName + ".png");

print(Fig, svgPath, '-dsvg');
exportgraphics(Fig, pngPath, 'Resolution', 300);

fprintf('Saved:\n  %s\n  %s\n', svgPath, pngPath);
