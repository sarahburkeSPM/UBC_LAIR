function [f, comment] = plot2DImage(LayoutCase, data, n, V_reduced, imageV)
%This function plots a 2D Image of the data.
% LayoutCase will determin the format of the Image(grid or topo) this function generates.
% If you need a specific format for your Image, which is not already in
% setGraphLayout function, please add your format there. This way, your
% preferred formatting won't change anyone else's graph output. 

%Dong Chen 2024/??; M. Altthaler 2024/12; Jisun 2025/4

arguments
    LayoutCase      {mustBeText}        %string "gridsliceImage" or "topoImage"
    data                                %topo or grid slice
    n           {mustBePositive} = []   % optional, only for 3D data
    V_reduced   {mustBeNumeric} = []    % optional, only for 3D data
    imageV      {mustBeNumeric} = []    % optional, only for 3D data
end
    % Check if data is 2D or 3D
    [data_slice, imN, V_actual] = dataSlice2D(data,n,V_reduced,imageV);
   
    % plot image of data slice
    f = figure();   
    imagesc(data_slice');
    setGraphLayout(LayoutCase);
    comment = sprintf("plot2DImage(data(:,:,imN = %s | V_actual = %s), V_reduced, imageV =%s|", num2str(imN),num2str(V_actual), num2str(imageV));
end