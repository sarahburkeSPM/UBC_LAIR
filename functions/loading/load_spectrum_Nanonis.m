function spectrum = load_spectrum_Nanonis(folder,spectrumFileName)
%Wrapper load function for point spectrum '.dat' files
%   V.K. - 2024, J.T. - 2026
%   Uses specLoad.m function, processes the data into a structure 
% Input: 
%   folder: string of folder containing data
%   spectrumFileName: the filename, including the extension
% Output: 
%   spectrum: structure containing all the point spectrum associated data

arguments
    folder              {mustBeText}
    spectrumFileName    {mustBeText}
end

%regular function processing:

%load the raw dat data:
[header, channels, data] = specLoad(strcat(folder,'/',spectrumFileName));

%Return the entire header, in case we need it
spectrum.header = header;
spectrum.header.channels = channels;

% Create array of default selected channels
number_channels = size(data,1);
defaultChannelSelection(number_channels) = struct('channelName', [], 'fieldName', [], 'selected', []);

for channel = 1:number_channels
    switch channels{channel}
        case "Current (A)"
            fieldName = "I";
            selected = true;
        case "Current [bwd] (A)"
            fieldName = "I_backward";
            selected = true;
        case "Bias calc (V)"
            fieldName = "V";
            selected = true;
        case "Bias calc [bwd] (V)"
            fieldName = "V_backward";
            selected = true;
        case "LI Demod 1 X (A)"
            fieldName = "lock_in_x";
            selected = true;
        case "LI Demod 1 Y (A)"
            fieldName = "lock_in_y";
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

%Get the selected channels from the data:
for channel = 1:number_channels
    if channelSelection(channel).selected
        fieldName = channelSelection(channel).fieldName;
        spectrum.(fieldName) = data(channel,:);
    end
end

end

function [header, channels, data] = specLoad(fileName)
%Nanonis-made DAT ASCII file loader
% Input:  
%   fileName: string of the file name
% Output:
%   header: structure containing all header information from the file
%   channels: array containing string titles of each channel
%   data: array containing the dataset in shape [channels, energy]

data=''; header=''; channels='';

if exist(fileName, 'file')
    fid = fopen(fileName, 'r', 'ieee-be');    % open with big-endian
else
    fprintf('File does not exist.\n');
    return;
end

% read header data
% The header consists of key-value pairs, separated by a tab character
% e.g. Settling time (s)	200E-6	
% The beginning of the data block starts with [DATA]
while 1
    s = strtrim(fgetl(fid));
    if strcmp(upper(s),'[DATA]')
        break
    end
    
    %s1 = strsplit(s,char(9));  % not defined in older Matlab versions
    s1 = strsplit_i(s,char(9));
    s1_s = prod(size(s1));
    if s1_s > 0 % line contains a tab
        s_key = strrep(lower(s1{1}), ' ', '_');
        s_val = '';
        if s1_s > 1
            s_val = strrep(s1{2}, '"', '');
        end
        
        s_key = regexprep(lower(s_key), '[^a-z0-9_]', '_');
        header.(s_key) = s_val;
    end
end

% read the channel names
s = strtrim(fgetl(fid));
%channels = strsplit(s,'=');  % not defined in older Matlab versions
channels = strsplit_i(s,char(9));

% read the data
data = fscanf(fid, '%f', [prod(size(channels)) Inf]);
fclose(fid);
end

function s = strsplit_i(str, delim)
    s = {};
    while ~isempty(str),
        [t,str] = strtok(str, delim);
        s{end+1} = t;
    end
end

