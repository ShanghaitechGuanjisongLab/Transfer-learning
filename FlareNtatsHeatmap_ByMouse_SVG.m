%[text] # FLARE：按鼠导出 NTATS 热图（SVG）
% 生成 4 张图：vtf0442/vtf0451 × (LearnedTransfer/Timeline)

outDir = "\\Data-Server-2\个人数据\张天夫\202512";
mkdir(outDir);

mice = ["vtf0442", "vtf0451"];
modes = ["LearnedTransfer", "Timeline"];

for m = mice
	for mode = modes
		Fig = TransferLearning.FlareNtatsHeatmapFigure(mode, m);
		try
			Fig = TransferLearning.FlareNtatsHeatmapFigure(mode, m);
			outName = "FLARE " + m + " hM4D(Gi)与Others细胞NTATS热图 " + mode + ".svg";
			outPath = fullfile(outDir, outName);
			exportgraphics(Fig, outPath, 'ContentType', 'vector');
			disp("Saved: " + outPath);
			close(Fig);
		catch ME
			warning('Failed: Mouse=%s Mode=%s (%s)', m, mode, ME.identifier);
			disp(ME.message);
			if exist('Fig','var') && ~isempty(Fig) && isvalid(Fig)
				close(Fig);
			end
			clear Fig
		end
	end
end
