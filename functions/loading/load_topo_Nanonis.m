function topo = load_topo_Nanonis(folder, topoFileName)
%Wrapper function for loading topos from Nanonis
%   V.K. - 2024, J.T. - 2026
%   Uses the Nanonis-made loadsxm.m function, processes the data into a structure 
%   Known possible channels: 'Z', 'Current', and 'LI_D1_X_1_omega'.
%   One extra channel of unknown name will be saved as 'other_channel'.
%   This is a temporary solution. Best practice is to add appropriate names 
%   for any additional channels into the Extract Channels if blocks.
% Input: 
%   folder: string of folder containing data
%   topoFileName: string of the fileName including the extension
% Output: 
%   topo: structure containing all the topo associated data
%   comment: string containing log comment


arguments
    folder          {mustBeText}
    topoFileName    {mustBeText}
end

%regular function processing:

loadStr = strcat(folder,'/',topoFileName);
%load the raw sxm data:
[header, raw_data] = loadsxm(loadStr);

%Return the entire header, in case we need it
topo.header = header;

%Calculate the x and y values from the header
x_range = header.scan_range(1); %in m
y_range = header.scan_range(2); %in m
x_range = x_range * 1e9; %convert m to nm
y_range = y_range * 1e9; %convert m to nm
number_x_points = header.scan_pixels(1);
number_y_points = header.scan_pixels(2);
topo.x = transpose(linspace((-x_range/2.0), (x_range/2.0), number_x_points));
if topo.header.scan_dir == "up" %y direction is positive
    y_all = transpose(linspace((-y_range/2.0), (y_range/2.0), number_y_points));
elseif topo.header.scan_dir == "down" %y direction is negative
    y_all = transpose(linspace((y_range/2.0), (-y_range/2.0), number_y_points));
else
    fprintf('Invalid scan direction in header.\n');
    return
end


%Get the center position of the topo (in m)
topo.x_position = header.scan_offset(1);
topo.y_position = header.scan_offset(2);

%Get the available channels of data
channels = topo.header.data_info{:,'Name'};
number_channels = height(topo.header.data_info);

% Create array of default selected channels
defaultChannelSelection(number_channels) = struct('channelName', [], 'fieldName', [], 'selected', []);

for channel = 1:number_channels
    switch channels{channel}
        case "Z"
            fieldName = "z";
            selected = true;
        case "Current"
            fieldName = "I";
            selected = true;
        case "LI_D1_X_1_omega"
            fieldName = "lock_in";
            selected = true;
        otherwise
            fieldName = "";
            selected = false;
    end

    defaultChannelSelection(channel).channelName = channels{channel};
    defaultChannelSelection(channel).fieldName = fieldName;
    defaultChannelSelection(channel).selected = selected;
end

% Prompt user to select channels to load
channelSelection = selectChannels(defaultChannelSelection);

% Reshape the raw data by channel and direction. Assumption is that both
% directions are taken, and so there is 2 images per channel
data = reshape(raw_data,[number_x_points,number_y_points,number_channels * 2]);

%This section is to determine if we have a partial image and remove NaN
%values if so. Note that this wasn't necessary for x since it's always full
% find y pixels where there is data
[~, y_coordinates] = find(~isnan(data(:,:,1)));

% Check if topo is unfinished
unfinished = any(isnan(data(:,:,1)), 'all');

if unfinished
    topo.y_all = y_all;
    topo.y = topo.y_all(1:max(y_coordinates)-1);
else
    topo.y = y_all;
end

% Extract out the channels
for channel = 1:number_channels
    if channelSelection(channel).selected
        fieldName = channelSelection(channel).fieldName;
        channelDataAll = data(:, :, 2*channel-1);
        channelDataBackwardAll = data(:, :, 2*channel);

        if unfinished
            channelData = channelDataAll(:, 1:max(y_coordinates)-1);
            channelDataBackward = channelDataBackwardAll(:, 1:max(y_coordinates)-1);

            %Apply orientation transformation
            [channelData, channelDataBackward] = sxmPermute(channelData, channelDataBackward, topo.header.scan_dir);
            [channelDataAll, channelDataBackwardAll] = sxmPermute(channelDataAll, channelDataBackwardAll, topo.header.scan_dir);

            topo.(fieldName) = channelData;
            topo.(fieldName + "_backward") = channelDataBackward;
            topo.(fieldName + "_all") = channelDataAll;
            topo.(fieldName + "_backward_all") = channelDataBackwardAll;
        else
            %Apply orientation transformation
            [channelDataAll, channelDataBackwardAll] = sxmPermute(channelDataAll, channelDataBackwardAll, topo.header.scan_dir);

            topo.(fieldName) = channelDataAll;
            topo.(fieldName + "_backward") = channelDataBackwardAll;
        end
    end
end

end

function [header, data] = loadsxm(fn)
%Nanonis-made SXM file loader
% Edited by V. King Oct 2024, D. Cohn, Sept 2024
% Input:
%   fn: string of the filename
% Output:
%   header: structure containing all header information from the file
%   data: array containing dataset
 
data=''; header='';
 
if exist(fn, 'file')
               fid = fopen(fn, 'r', 'ieee-be');    % open with big-endian
else
               fprintf('File does not exist.\n');
               return;
end
 
% check whether file is a Nanonis data file.
s1 = fgetl(fid);
if ~strcmp(s1, ':NANONIS_VERSION:')
               fprintf('File seems not to be a Nanonis file\n');
               return;
end
% get header
header.version = str2num(fgetl(fid));
read_tag = 1;
 
% read header data
% The header consists of key-value pairs. Usually the key is on one line, embedded in colons 
% e.g. :SCAN_PIXELS:, the next line contains the value.
% Some special keys may have multi-line values (like :COMMENT:), in this case read value
% until next key is detected (line starts with a colon) and set read_tag to 0 (because key has
% been read already).
while 1
               if read_tag
                               s1 = strtrim(fgetl(fid));
               end
               s1 = s1(2:length(s1)-1);    % remove leading and trailing colon
               read_tag = 1;
               switch s1
               % strings:
               case {'SCANIT_TYPE', 'REC_DATE', 'REC_TIME', 'SCAN_FILE', 'SCAN_DIR'}
                               s2 = strtrim(fgetl(fid)); 
                               header.(lower(s1)) = s2;
               % comment:
               case 'COMMENT'
                               s_com = '';
                               s2 = strtrim(fgetl(fid));
                               while ~strncmp(s2, ':', 1)
                                              s_com = [s_com s2 char(13)];
                                              s2 = strtrim(fgetl(fid)); 
                               end
                               header.comment = s_com;
                               s1 = s2;
                               read_tag = 0;  % already read next key (tag)
               % Z-controller settings:
               case 'Z-CONTROLLER'
                               header.z_ctrl_tags = strtrim(fgetl(fid));
                               header.z_ctrl_values = strtrim(fgetl(fid));
               % numbers:
               case {'BIAS', 'REC_TEMP', 'ACQ_TIME', 'SCAN_ANGLE'}
                               s2 = fgetl(fid);
                               header.(lower(s1)) = str2num(s2);
               % array of two numbers:
               case {'SCAN_PIXELS', 'SCAN_TIME', 'SCAN_RANGE', 'SCAN_OFFSET'}
                               s2=fgetl(fid);
                               header.(lower(s1)) = sscanf(s2, '%f');
               % data info:
               % section edited by D. Cohn, Sept 2024 (Ask V.King)
               case 'DATA_INFO'
                    % parse header row
                    header_row = strtrim(fgetl(fid));
                    num_fields = length(split(header_row));
                    field_names = transpose(split(header_row));
                   
                    % parse values
                    values = cell(0, num_fields);

                    while true
                        value_row = strtrim(fgetl(fid));

                        if length(split(value_row)) < 2
                            break
                        end

                        values = [values; transpose(split(value_row))];          
                    end

                   header.data_info = cell2table(values, VariableNames=field_names);
               case 'SCANIT_END'
                               break;
    otherwise % treat as strings
                               s1 = regexprep(lower(s1), '[^a-z0-9_]', '_');
                               s_line = strtrim(fgetl(fid));
                               s2 = '';
                               while ~strncmp(s_line, ':', 1)
                                              s2 = [s2 s_line char(13)];
                                              s_line = strtrim(fgetl(fid)); 
                               end
                               header.(s1) = s2;
                               s1 = s_line;
                               read_tag = 0;  % already read next key (tag)
               end
end
 
% \1A\04 (hex) indicates beginning of binary data
s1 = [0 0];
while s1~=[26 4]
               s2 = fread(fid, 1, 'char');
               s1(1) = s1(2);
               s1(2) = s2;
end
 
% Read all data as one long column array
% section edited by V. King, Oct 2024
data = fread(fid, 'float');
 
fclose(fid);
end


function [permuted_forward,permuted_backward] = sxmPermute(channel_forward, channel_backward, scan_direction)
%Permutation operation for all channels in a 'sxm' file
%   Permutes a channel from a sxm file so that its orientation matches what
%   we see as a user in Nanonis.
% Input: 
%   channel_forward: array, channel variable in the forward scan direction
%   channel_backward: array, channel variable in the backward scan direction
%   scan_direction: string, whether the scan was made 'Up' or 'Down'
% Output: 
%   permuted_forward: array, the forward variable permuted
%   permuted_backward: array, the backward variable permuted


arguments
    channel_forward
    channel_backward 
    scan_direction      {mustBeText}
end


%no transformation necessary for UP-FORWARD
permuted_forward = channel_forward;

%transformation for UP-BACKWARD
permuted_backward = flip(channel_backward,1);

if scan_direction == "down"
    %transformation for DOWN-FORWARD
    permuted_forward = flip(permuted_forward,2);
    %transformation for DOWN-BACKWARD
    permuted_backward = flip(permuted_backward,2);
end

end