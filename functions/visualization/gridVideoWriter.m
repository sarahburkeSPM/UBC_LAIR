function [comment,file,location] = gridVideoWriter(data, V, rangeType, delay, colormapName, croppedVid, videoSize)
% GRIDSLICEVIEWER Processes 3D dIdV data into an RGB image stack for visualization.
%   Edited by Jiabin Nov 2024, James May 2025
%
% Inputs:
%   data: 3D matrix (x, y, V) of dIdV data.
%   V: Voltage vector (column) matching data's third dimension.
%   rangeType: 'global' or 'dynamic'.
%   colormapName: Colormap name (default 'invgray').
%   LOGpath: Path to log file (for capture logging).
%   LOGfile: Log file name (for capture logging).
%
% Outputs:
%   sliced_grid: 4D RGB stack (x, y, slices, 3).
%   voltages: Corresponding voltages from V as column.

arguments
    data        (:,:,:) {mustBeNumeric}
    V           (:,1) {mustBeNumeric}
    rangeType   (1,:) char {mustBeMember(rangeType, {'global', 'dynamic'})}
    delay       (1,1) {mustBeNumeric,mustBePositive} 
    colormapName (1,:) char = 'invgray'
    croppedVid  (1,1) {mustBeNumericOrLogical} = 1
    videoSize     (2,1) {mustBeNumeric} = [800 800]
end

% Validate inputs
if size(data, 3) ~= length(V)
    error('Length of V (%d) must match third dimension of data (%d)', length(V), size(data, 3));
end

% Load colormap
if strcmp(colormapName, 'invgray')
    load('InverseGray', 'invgray');
    map = invgray;
else
    try
        map = colormap(colormapName);
    catch
        warning('Invalid colormap "%s". Using invgray.', colormapName);
        load('InverseGray', 'invgray');
        map = invgray;
    end
end

% Prepare data
Grid = permute(data, [2 1 3]);
Grid = flip(Grid, 1);

% Set range
if strcmp(rangeType, 'global')
    globalMin = min(Grid(:));
    globalMax = max(Grid(:));
end

% Pre-allocate output
sliced_grid = zeros(size(Grid, 1), size(Grid, 2), size(data, 3), 3);
sliceNumbers = (1:size(data, 3))';
voltages = V(1:size(data, 3));

% Process slices
for k = 1:size(data, 3)
    sliceData = Grid(:,:,k);
    if strcmp(rangeType, 'dynamic')
        med = median(sliceData(:));
        stdv = std(sliceData(:));
        range = [med - 8*stdv, med + 8*stdv];
    else
        range = [globalMin, globalMax];
    end
    sliced_grid(:,:,k,:) = mat2im(sliceData, map, range);
end


% select path and title for video:
filter = {'*.mp4';'*.avi';'*.mj2';'*.*'};
[file,location] = uiputfile(filter,'Select file loaction for video','GridVideo');
% set video writer type by file extension
[~, ~, ext] = fileparts(file);
switch ext % see VideoWriter documentation for details on Profile settings
    case '.avi'
        videoProfile  = "Motion JPEG AVI"; % AVI file using Motion JPEG encoding
    case '.mp4'
        videoProfile  = "MPEG-4"; % MPEG-4 file with H.264 encoding
    case '.mj2'
        videoProfile  = "Archival"; % Motion JPEG 2000 file with lossless compression, alternative "Motion JPEG 2000" for regular compression
    otherwise
        disp("Invalid file type for video selected!")
        return 
end

% open video writer
v = VideoWriter([location,file],videoProfile);
v.FrameRate = max(min((1000./delay),172),1); %set framerate from delay in ms
open(v);

% Display
fig = figure('Name', sprintf('3D Grid View - %s Range, %s Colormap', rangeType, colormapName));
ax = axes(fig);

% Display progress bar window
progressMsg = sprintf("Note: Video not displayed at set framerate! \n \n Writing video frame by frame: [%i/%i].", 0, size(data, 3));
progressFig = waitbar(0,progressMsg, 'Name',"Video writer progress");

% Number of frames 
frameNum = size(data, 3);

if croppedVid == 1
    %plot only image
    fig.Position = [100 100 videoSize(1)+250 videoSize(1)+250];
    ax.Units = "pixels";
    ax.Position = [125 125 videoSize(1) videoSize(2)];
    for k = 1:frameNum
        img = imshow(squeeze(sliced_grid(:,:,k,:)), 'InitialMagnification', 'fit');
        setGraphLayout('gridsliceImage');
        frame = getframe;
        writeVideo(v,frame);
        % update progress bar window
        progressMsg = sprintf("Note: Video not displayed at set framerate! \n \n Writing video frame by frame: [%i/%i].", k, frameNum);
        waitbar(k/frameNum,progressFig,progressMsg);
    end
else
    %plot image with voltag text overlay
    fig.Position = [100 100 videoSize(1) videoSize(2)];
    for k = 1:frameNum
        img = imshow(squeeze(sliced_grid(:,:,k,:)), 'InitialMagnification', 'fit');
        setGraphLayout('gridsliceImage');
        ax = imgca(fig);
        ax.Title.String = sprintf("%.3f V",V(k));
        frame = getframe(fig);
        writeVideo(v,frame);
        % update progress bar window
        progressMsg = sprintf("Note: Video not displayed at set framerate! \n \n Writing video frame by frame: [%i/%i].", k, frameNum);
        waitbar(k/frameNum,progressFig,progressMsg)
    end
end
close(v);
close(fig);
close(progressFig);

% LOG comment
comment = sprintf("Grid video: <name> = %s saved in: <dir> = %s ", file, location);

end


% Nested mat2im
function im = mat2im(mat, cmap, limits)
    if ~isa(mat, 'double')
        mat = double(mat) + 1;
    end
    if ~isnumeric(cmap)
        error('cmap must be a numeric colormap');
    end
    if nargin < 3
        minVal = min(mat(:));
        maxVal = max(mat(:));
    else
        minVal = limits(1);
        if isnan(minVal), minVal = min(mat(:)); end
        mat(mat < minVal) = minVal;
        maxVal = limits(2);
        if isnan(maxVal), maxVal = max(mat(:)); end
        mat(mat > maxVal) = maxVal;
    end
    L = size(cmap, 1);
    mat = mat - minVal;
    mat = (mat / (maxVal - minVal)) * (L - 1);
    mat = mat + 1;
    mat = round(mat);
    im = reshape(cmap(mat(:), :), [size(mat), 3]);
end


