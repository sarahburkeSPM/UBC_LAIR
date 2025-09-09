function [f, comment] = plotOneXYGraph(LayoutCase, X, Y)
%This function plots a graph with one set of X and Y.
% LayoutCase will determin the format of the graph this function generates.
% If you need a specific format for your graph, which is not already in
% setGraphLayout function, please add your format there. This way, your
% preferred formatting won't change anyone else's graph output. 

 arguments
    LayoutCase  {mustBeText} %string
    X
    Y
 end

% Ensure X and Y are vectors of compatible sizes
if ~isvector(X) || ~isvector(Y)
    error('Inputs X and Y must be vectors.');
end
if numel(X) ~= numel(Y)
    error('X and Y must have the same number of elements.');
end

 f = figure();
 plot(X, Y);
 [ax] = setGraphLayout(LayoutCase);

 comment = sprintf("plotOneXYGraph(%s:%s, %s:%s)",  ...
                  ax.XLabel.String, mat2str(size(X)), ...
                  ax.YLabel.String, mat2str(size(Y)));
end