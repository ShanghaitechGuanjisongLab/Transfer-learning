---
name: matlab-figure
description: MATLAB作图规范
---
图的高度通常应为4㎝。但包含legend的图应放大到8㎝高，并在ExportStandardFigure中设置缩放2。在tiledlayout中，不要重复相同的xylabel：如果所有的x或ylabel都一样，则应只在Layout级别放置单个label。
导出SVG应用fetch_images工具视觉检查，不要导出PNG。检查应避免图中有任何文本之间或与重要图元重叠；但是不准为此直接手动微调图元位置数值，只能在MATLAB规定的框架内调整，或者将过长的文字缩写。如果在这些限制下你想不到能不让图元重叠的办法，就直接问用户。
用户对作图的要求如果有不明确之处，优先发问，避免自己瞎猜后再让用户回头来改。