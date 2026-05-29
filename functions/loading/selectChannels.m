function channelSelection = selectChannels(defaultChannelSelection)
% Prompt user to select channels to load from a list of available channels
%
% Both input and output are struct arrays that
% contain all channels present in the raw data file along with user defined
% field names. They contain the following fields:
%   channelName (string): name of channel from data file header
%   fieldName (string): name of corresponding field that will be added to the data struct
%   selected (logical): indicates whether channel is selected
% The order of channels should be the same as in the data file.
%
% The caller can set fieldName and selected in the input to control the
% default behaviour of the channel selector. If fieldName is empty, a field
% name will be created from channelName.
%
% The user is given the option to modify fieldName and selected in for each
% channel in through the command line interface. The user's choices are
% then returned to the caller for processing.
%
% J. Townsend, 2026

arguments
    defaultChannelSelection (1,:) struct {mustBeNonempty}
end

channelSelection = defaultChannelSelection;
numChannels = numel(channelSelection);

% If there is no default field name, construct an appropriate one from the channel name
for i = 1:numChannels
    if channelSelection(i).fieldName == ""
        fieldName = channelSelection(i).channelName;
        fieldName = strrep(fieldName, " ", "_");
        fieldName = regexprep(fieldName, "(.*", "");
        fieldName = strip(fieldName, "right", "_");
        fieldName = replace(fieldName, "[bwd]", "backward");
        fieldName = lower(fieldName);
        channelSelection(i).fieldName = fieldName;
    end
end

% Continue showing the available/selected channels to the user and allowing
% them to make changes until they indicate that they are finished
finished = false;

while ~finished
    disp("Please select the data channels you would like to load:");

    % Display all selected/available channels and field names
    for i = 1:numChannels
        displayStr = string(i) + ":  " + channelSelection(i).fieldName + "  [ " + channelSelection(i).channelName + " ]";
        if channelSelection(i).selected
            displayStr = "[✓]  " + displayStr;
        else
            displayStr = "[ ]  " + displayStr;
        end
        disp(displayStr);
    end

    % Prompt user to select/deselect/rename channels
    disp("Type # to select/deselect a channel, or type # <name> to select and rename a channel.")
    disp("Type 0 if you are happy with your selection.")

    inputStr = input("> ", "s");

    % Extract the channel index and field name (if present) from the user's input
    if contains(inputStr, " ")
        channelIndex = str2double(extractBefore(inputStr, " "));
        fieldName = extractAfter(inputStr, " ");
    else
        channelIndex = str2double(inputStr);
        fieldName = "";
    end

    if channelIndex == 0
        if fieldName == ""
            % Exit loop when user gives "0" command
            finished = true;
        else
            disp("Invalid command.");
        end
    elseif channelIndex > 0 && channelIndex <= numChannels
        if fieldName == ""
            % If user entered a channel number with no text, toggle between selected/deselected
            channelSelection(channelIndex).selected = ~channelSelection(channelIndex).selected;
        else
            % Otherwise, select and rename the channel
            % Filter out forbidden characters from field name
            fieldName = regexprep(fieldName,"[^\w\s]","");
            fieldName = erase(fieldName, "");
            if strlength(fieldName) < 65
                channelSelection(channelIndex).selected = true;
                channelSelection(channelIndex).fieldName = fieldName;
            else
                disp("Name exceeds limit of 64 characters.");
            end
        end
    else
        disp("Invalid channel index.");
    end

end

end