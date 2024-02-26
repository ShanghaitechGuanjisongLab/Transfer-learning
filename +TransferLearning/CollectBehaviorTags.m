function [Table,Min,Max] = CollectBehaviorTags(Table,TagLength)
Table=Table(cellfun(@(T)istable(T)&&height(T)>=TagLength,Table.NormalizedTags),:);
Tags=cellfun(@(T)T.CD2(1:TagLength)',Table.NormalizedTags,UniformOutput=false);
Table.NormalizedTags=vertcat(Tags{:});
[Min,Max]=bounds(Table.NormalizedTags,'all');