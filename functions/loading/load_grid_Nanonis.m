function grid = load_grid_Nanonis(folder,gridFileName)
%Wrapper function for loading grids from Nanonis
%   V.K. - 2024, J.T. - 2026
%   Uses the Nanonis-made load3ds.m function, processes the data into a structure 
% Input: 
%   folder: string of folder containing data
%   stamp_project: the filename leader, takes the form 'yyyymmdd-XXXXXX_CaPt--STM_Spectroscopy--'
%   grid_number: string of 3ds file number, ie: 'NbIrPtTe001'
% Output: 
%   grid: structure containing all the grid associated data
%   comment: string containing log comment
arguments
    folder          {mustBeText}
    gridFileName    {mustBeText}
end

%regular function processing:

%load the raw 3ds data:
[header, par, data] = load3ds_Nanonis(strcat(folder,'/',gridFileName));

%Return the entire header, in case we need it
grid.header = header;

%Calculate the x and y values from the header
%Get x_position and y_position (in m) off of parameters in the header:
grid.x_position = header.grid_settings(1); 
grid.y_position = header.grid_settings(2); 
x_range = header.grid_settings(3);%in m
y_range = header.grid_settings(4);%in m
x_range = x_range * 1e9; %convert m to nm
y_range = y_range * 1e9; %convert m to nm
number_x_points = header.grid_dim(1);
number_y_points = header.grid_dim(2);

%Get x out of the experimental parameters:
grid.x = transpose(linspace((-x_range/2.0), (x_range/2.0), number_x_points));

%Get y out of the experimental parameters:
if par{1,1}(4) < grid.y_position %y direction is up
    y_all = transpose(linspace((-y_range/2.0), (y_range/2.0), number_y_points));
elseif par{1,1}(4) > grid.y_position %y direction is down
    y_all = transpose(linspace((y_range/2.0), (-y_range/2.0), number_y_points));
else
    fprintf('Invalid scan direction in header.\n');
    return
end

%Calculate V based off of parameters in the header:
bias_start = par{1,1}(1);
bias_end = par{1,1}(2);
number_bias_points = header.points;
grid.V = transpose(linspace(bias_start,bias_end,number_bias_points));

% Create array of default selected channels
number_channels = size(data{1,1},2);
defaultChannelSelection(number_channels) = struct('channelName', [], 'fieldName', [], 'selected', []);

for channel = 1:number_channels
    switch header.channels{channel}
        case "Z (m)"
            fieldName = "z";
            selected = true;
        case "Z [bwd] (m)"
            fieldName = "z_backward";
            selected = true;
        case "Current (A)"
            fieldName = "I";
            selected = true;
        case "Current [bwd] (A)"
            fieldName = "I_backward";
            selected = true;
        case "LI D1 X 1 omega (A)"
            fieldName = "lock_in";
            selected = true;
        otherwise
            fieldName = "";
            selected = false;
    end

    defaultChannelSelection(channel).channelName = header.channels{channel};
    defaultChannelSelection(channel).fieldName = fieldName;
    defaultChannelSelection(channel).selected = selected;
end

% Prompt user to select channels to load
channelSelection = selectChannels(defaultChannelSelection);

% This section is to determine if we have a partial image and remove 0 values if so. 
% Note this wasn't necessary for x or V since they're always full
[~,y_coordinates] = find(~cellfun(@isempty, data)); %pixels where there are spectra

% Check if grid is finished
finished = ~any(cellfun(@isempty, data), "all");

if finished
    grid.y = y_all;
else
    grid.y_all = y_all;
    grid.y = grid.y_all(1:max(y_coordinates)-1);
end

% Extract out the channels
for channel = 1:number_channels
    if channelSelection(channel).selected
        fieldName = channelSelection(channel).fieldName;
        gridDataAll = zeros(number_x_points, number_y_points, number_bias_points);

        for x = 1:number_x_points
            for y = 1:number_y_points
                if ~isempty(data{x,y})
                    gridDataAll(x,y,:) = data{x,y}(:,channel);
                end
            end
        end

        if finished
            grid.(fieldName) = gridDataAll;
        else
            grid.(fieldName + "_all") = gridDataAll;
            grid.(fieldName) = gridDataAll(:, 1:max(y_coordinates)-1, :);
        end
    end
end

end


function [header, par, data] = load3ds_Nanonis(fn)
% Description: 
%   Reads a .3ds NANONIS file. Imports the header information into a struct,
%   all raw data into a (grid_dimension x grid dimension) cell array, where
%   each cell consists of a (points x 4) array, containing information on the
%   bias sweeps at each pixel for current, bias, and lock in data. A 5th
%   column is added to each cell array which consists of the Gaussian
%   filtered dIdV data and LockindIdV data. The Fourier transform of the dIdV/ LockindIdV data is taken, and
%   stored in QPI/ LockinQPI array.

% Input: 
%   fn: file name of the 3ds file(.3ds)
% Output: 
%   header: 1*1 file contains all the parameters/ notes in the 3ds file 
%   par: N-dim file with N being #parameters in the 3ds file
%   data: full set of data from 3ds file
%% DEFINE VARIABLES
header = ''; % Variable where header information is stored
par = '';
data = {}; % Raw data from .3ds file, stored in cell array

%% FIND AND OPEN .3ds FILE
if exist(fn, 'file')
    fid = fopen(fn, 'r', 'ieee-be');    % open with big-endian
else
    fprintf('File does not exist.\n');
    return;
end

%% READ THE HEADER DATA
% The header consists of key-value pairs, separated by an equal sign,
% e.g. Grid dim="64 x 64". If the value contains spaces it is enclosed by
% double quotes (").
while 1
    s = strtrim(fgetl(fid));
    if strcmp(upper(s),':HEADER_END:')
        break
    end
    
    s1 = strsplit(s,'=');  % not defined in Matlab
    %s1 = strsplit_i(s,'=');

    s_key = strrep(lower(s1{1}), ' ', '_');
    s_val = strrep(s1{2}, '"', '');
    
    switch s_key
    
    % dimension:
    case 'grid_dim'
        s_vals = strsplit(s_val, 'x');
        %s_vals = strsplit_i(s_val, 'x');
        header.grid_dim = [str2num(s_vals{1}), str2num(s_vals{2})];
        
    % grid settings
    case 'grid_settings'
        header.grid_settings = sscanf(s_val, '%f;%f;%f;%f;%f');
         
    % fixed parameters, experiment parameters, channels:
    case {'fixed_parameters', 'experiment_parameters', 'channels'}
        s_vals = strsplit(s_val, ';');
        %s_vals = strsplit_i(s_val, ';');
        header.(s_key) = s_vals;
        
    % number of parameters
    case '#_parameters_(4_byte)'
        header.num_parameters = str2num(s_val);
        
    % experiment size
    case 'experiment_size_(bytes)'
        header.experiment_size = str2num(s_val);

    % spectroscopy points
    case 'points'
        header.points = str2num(s_val);

    % delay before measuring
    case 'delay_before_measuring_(s)'
        header.delay_before_meas = str2num(s_val);
    
    % other parameters -> treat as strings
    otherwise
        s_key = regexprep(s_key, '[^a-z0-9_]', '_');
        header.(s_key) = s_val;
    end
end

%% READS THE DATA FROM THE .3ds FILE INTO A CELL ARRAY
fprintf('Reading data \n')

for j = 1:header.grid_dim(2) % Size of the grid in the y-direction
    for i = 1:header.grid_dim(1) % Size of the grid in the x-direction
        par{i,j} = fread(fid, header.num_parameters, 'float'); % Reads the parameters
        data{i,j} = fread(fid, [header.points prod(size(header.channels))], 'float'); % Reads data
    end
end
end