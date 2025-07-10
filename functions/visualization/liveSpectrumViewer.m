function liveSpectrumViewer(dataset, LOGpath, LOGfile)
%LIVESPECTRUMVIEWER Displays 3D RGB dI/dV slices with live-updating spectrum.
%   Displays a 4D RGB stack of dI/dV slices with navigation (slider, scroll, play)
%   and a live-updating point spectrum (dI/dV vs. voltage) for the (x, y) point
%   under the cursor, in a side-by-side axes. Data is pulled from the base
%   workspace: data.(dataset).sliced_grid, data.(dataset).voltages,
%   data.(dataset).dIdV, data.(dataset).V_reduced.
%
% Usage:
%   liveSpectrumViewer(dataset)
%   liveSpectrumViewer(dataset, LOGpath, LOGfile)
%
% Inputs:
%   dataset:    Name of dataset field (e.g., 'grid') for data.(dataset)
%   LOGpath:    Path to log file (for capture logging, default: '')
%   LOGfile:    Log file name (for capture logging, default: '')
%
% Notes:
%   - Requires data.(dataset).sliced_grid (MxNxKx3), data.(dataset).voltages (Kx1),
%     data.(dataset).dIdV (MxNxK), data.(dataset).V_reduced (Kx1) in base workspace.
%   - Spectrum displayed in axes to the right of slice with buffer space.
%   - Capture button stores selectedSlice and selectedVoltage in data.(dataset).
%
% Edited by James June 2025 for live spectrum display.

% Validate inputs
arguments
    dataset (1,:) char = 'grid'
    LOGpath (1,:) char = ''
    LOGfile (1,:) char = ''
end

% Validate base workspace data
if ~evalin('base', 'exist(''data'', ''var'')') || ...
   ~evalin('base', sprintf('isfield(data, ''%s'')', dataset)) || ...
   ~evalin('base', sprintf('isfield(data.%s, ''sliced_grid'')', dataset)) || ...
   ~evalin('base', sprintf('isfield(data.%s, ''voltages'')', dataset)) || ...
   ~evalin('base', sprintf('isfield(data.%s, ''dIdV'')', dataset)) || ...
   ~evalin('base', sprintf('isfield(data.%s, ''V_reduced'')', dataset))
    error('Base workspace must contain data.%s with fields sliced_grid, voltages, dIdV, V_reduced', dataset);
end
Img = evalin('base', sprintf('data.%s.sliced_grid', dataset));
voltages = evalin('base', sprintf('data.%s.voltages', dataset));
dIdV = evalin('base', sprintf('data.%s.dIdV', dataset));
V_reduced = evalin('base', sprintf('data.%s.V_reduced', dataset));
if size(Img, 3) ~= length(voltages) || size(dIdV, 3) ~= size(Img, 3) || size(V_reduced, 1) ~= size(Img, 3)
    error('data.%s fields must have consistent dimensions: sliced_grid (%d slices), voltages (%d), dIdV (%d), V_reduced (%d)', ...
        dataset, size(Img, 3), length(voltages), size(dIdV, 3), size(V_reduced, 1));
end

sno = size(Img, 3); % Number of slices
S = round(sno/2); % Initial slice
PlayFlag = false;
Tinterv = 100; % Play interval (ms)

global InitialCoord;

% Initialize window/level
MinV = 0;
MaxV = max(Img(:));
LevV = (MaxV + MinV) / 2;
Win = MaxV - MinV;
WLAdjCoe = (Win + 1)/1024;
FineTuneC = [1 1/16];

% Handle data type
if isa(Img, 'uint8')
    MaxV = uint8(Inf); MinV = uint8(-Inf);
    LevV = (double(MaxV) + double(MinV)) / 2;
    Win = double(MaxV) - double(MinV);
    WLAdjCoe = (Win + 1)/1024;
elseif isa(Img, 'uint16')
    MaxV = uint16(Inf); MinV = uint16(-Inf);
    LevV = (double(MaxV) + double(MinV)) / 2;
    Win = double(MaxV) - double(MinV);
    WLAdjCoe = (Win + 1)/1024;
elseif isa(Img, 'logical')
    MaxV = 0; MinV = 1; LevV = 0.5; Win = 1; WLAdjCoe = 0.1;
else
    MaxV = max(Img(:)); MinV = min(Img(:));
    LevV = (MaxV + MinV) / 2;
    Win = MaxV - MinV;
    WLAdjCoe = (Win + 1)/1024;
end

% Font and button sizes
SFntSz = 9; txtFntSz = 10; LVFntSz = 9; WVFntSz = 9; BtnSz = 10;

% Handle display range
[Rmin, Rmax] = WL2R(Win, LevV);

% Create figure
fig = figure('Name', 'Live Spectrum Viewer');
clf;

% Slice axes (left side)
sliceAx = axes('Position', [0, 0.2, 0.6, 0.8]);
imshow(squeeze(Img(:,:,S,:)), [Rmin Rmax], 'Parent', sliceAx);

% Spectrum axes (right side with adjusted position to avoid overlap)
spectrumAx = axes('Position', [0.65, 0.2, 0.3, 0.7]);
plot(spectrumAx, V_reduced, zeros(size(V_reduced)), 'b', 'LineWidth', 1.5);
title(spectrumAx, 'Spectrum at (x, y)');
xlabel(spectrumAx, 'Voltage (V)');
ylabel(spectrumAx, 'dI/dV');
grid(spectrumAx, 'on');

% UI controls positions
FigPos = get(fig, 'Position');
S_Pos = [30 45 uint16(FigPos(3)-100)+1 20];
Stxt_Pos = [30 65 uint16(FigPos(3)-100)+1 15];
Wtxt_Pos = [20 18 60 20];
Wval_Pos = [75 20 50 20];
Ltxt_Pos = [130 18 45 20];
Lval_Pos = [170 20 50 20];
Btn_Pos = [240 20 70 20];
ChBx_Pos = [320 20 80 20];
Play_Pos = [uint16(FigPos(3)-100)+40 45 30 20];
Time_Pos = [uint16(FigPos(3)-100)+35 20 40 20];
Ttxt_Pos = [uint16(FigPos(3)-100)-50 18 90 20];
Capture_Pos = [uint16(FigPos(3)-200)+1 65 80 20];

% Button styles
WL_BG = ones(Btn_Pos(4), Btn_Pos(3), 3)*0.85;
WL_BG(1,:,:) = 1; WL_BG(:,1,:) = 1; WL_BG(:,end-1,:) = 0.4; WL_BG(:,end,:) = 0.2; WL_BG(end,:,:) = 0.2;

Play_BG = ones(Play_Pos(4), Play_Pos(3), 3)*0.85;
Play_BG(1,:,:) = 1; Play_BG(:,1,:) = 1; Play_BG(:,end-1,:) = 0.4; Play_BG(:,end,:) = 0.2; Play_BG(end,:,:) = 0.2;
Play_Symb = [0,0,1,1,1,1,1,1,1,1,1,1,1,1; 0,0,0,0,1,1,1,1,1,1,1,1,1,1; 0,0,0,0,0,0,1,1,1,1,1,1,1,1;...
             0,0,0,0,0,0,0,0,1,1,1,1,1,1; 0,0,0,0,0,0,0,0,0,0,1,1,1,1; 0,0,0,0,0,0,0,0,0,0,0,0,1,1;...
             0,0,0,0,0,0,0,0,0,0,0,0,0,0; 0,0,0,0,0,0,0,0,0,0,0,0,1,1; 0,0,0,0,0,0,0,0,0,0,1,1,1,1;...
             0,0,0,0,0,0,0,0,1,1,1,1,1,1; 0,0,0,0,0,0,1,1,1,1,1,1,1,1; 0,0,0,0,1,1,1,1,1,1,1,1,1,1;...
             0,0,1,1,1,1,1,1,1,1,1,1,1,1];
Play_BG(floor((Play_Pos(4)-13)/2)+1:floor((Play_Pos(4)-13)/2)+13, floor(Play_Pos(3)/2)-7:floor(Play_Pos(3)/2)+6, :) = ...
    repmat(Play_Symb, 1, 1, 3) .* Play_BG(floor((Play_Pos(4)-13)/2)+1:floor((Play_Pos(4)-13)/2)+13, floor(Play_Pos(3)/2)-7:floor(Play_Pos(3)/2)+6, :);
Pause_BG = ones(Play_Pos(4), Play_Pos(3), 3)*0.85;
Pause_BG(1,:,:) = 1; Pause_BG(:,1,:) = 1; Pause_BG(:,end-1,:) = 0.4; Pause_BG(:,end,:) = 0.2; Pause_BG(end,:,:) = 0.2;
Pause_Symb = repmat([0,0,0,1,1,1,1,0,0,0], 13, 1);
Pause_BG(floor((Play_Pos(4)-13)/2)+1:floor((Play_Pos(4)-13)/2)+13, floor(Play_Pos(3)/2)-5:floor(Play_Pos(3)/2)+4, :) = ...
    repmat(Pause_Symb, 1, 1, 3) .* Pause_BG(floor((Play_Pos(4)-13)/2)+1:floor((Play_Pos(4)-13)/2)+13, floor(Play_Pos(3)/2)-5:floor(Play_Pos(3)/2)+4, :);

Capture_BG = ones(Capture_Pos(4), Capture_Pos(3), 3)*0.6; % Light blue
Capture_BG(:,:,1) = 0.6; Capture_BG(:,:,2) = 0.8; Capture_BG(:,:,3) = 1;
Capture_BG(1,:,:) = 1; Capture_BG(:,1,:) = 1; Capture_BG(:,end-1,:) = 0.4; Capture_BG(:,end,:) = 0.2; Capture_BG(end,:,:) = 0.2;

% UI controls
if sno > 1
    shand = uicontrol('Style', 'slider', 'Min', 1, 'Max', sno, 'Value', S, 'SliderStep', [1/(sno-1) 10/(sno-1)], 'Position', S_Pos, 'Callback', {@SliceSlider, Img, spectrumAx});
    stxthand = uicontrol('Style', 'text', 'Position', Stxt_Pos, 'String', sprintf('Slice# %d (V = %.4f) / %d', S, voltages(S), sno), 'FontSize', SFntSz);
    playhand = uicontrol('Style', 'pushbutton', 'Position', Play_Pos, 'Callback', @Play, 'CData', Play_BG);
    ttxthand = uicontrol('Style', 'text', 'Position', Ttxt_Pos, 'String', 'Interval (ms): ', 'FontSize', txtFntSz);
    timehand = uicontrol('Style', 'edit', 'Position', Time_Pos, 'String', sprintf('%d', Tinterv), 'BackgroundColor', [1 1 1], 'FontSize', LVFntSz, 'Callback', @TimeChanged);
    capturehand = uicontrol('Style', 'pushbutton', 'Position', Capture_Pos, 'String', 'Capture', 'FontSize', BtnSz, 'FontWeight', 'bold', 'CData', Capture_BG, 'Callback', @CaptureSlice);
else
    stxthand = uicontrol('Style', 'text', 'Position', Stxt_Pos, 'String', '2D image', 'FontSize', SFntSz);
end
ltxthand = uicontrol('Style', 'text', 'Position', Ltxt_Pos, 'String', 'Level: ', 'FontSize', txtFntSz);
wtxthand = uicontrol('Style', 'text', 'Position', Wtxt_Pos, 'String', 'Window: ', 'FontSize', txtFntSz);
lvalhand = uicontrol('Style', 'edit', 'Position', Lval_Pos, 'String', sprintf('%6.0f', LevV), 'BackgroundColor', [1 1 1], 'FontSize', LVFntSz, 'Callback', @WinLevChanged);
wvalhand = uicontrol('Style', 'edit', 'Position', Wval_Pos, 'String', sprintf('%6.0f', Win), 'BackgroundColor', [1 1 1], 'FontSize', WVFntSz, 'Callback', @WinLevChanged);
Btnhand = uicontrol('Style', 'pushbutton', 'Position', Btn_Pos, 'String', 'Auto W/L', 'FontSize', BtnSz, 'Callback', @AutoAdjust, 'CData', WL_BG);
ChBxhand = uicontrol('Style', 'checkbox', 'Position', ChBx_Pos, 'String', 'Fine-tune', 'FontSize', txtFntSz);

% Callbacks
set(fig, 'WindowScrollWheelFcn', @mouseScroll);
set(fig, 'ButtonDownFcn', @mouseClick);
set(get(sliceAx, 'Children'), 'ButtonDownFcn', @mouseClick);
set(fig, 'WindowButtonUpFcn', @mouseRelease);
set(fig, 'WindowButtonMotionFcn', {@updateSpectrum, sliceAx, spectrumAx, dIdV, V_reduced});

% -=< Figure resize callback >=-
    function figureResized(~, ~)
        FigPos = get(fig, 'Position');
        S_Pos = [30 45 uint16(FigPos(3)-100)+1 20];
        Stxt_Pos = [30 65 uint16(FigPos(3)-100)+1 15];
        Play_Pos = [uint16(FigPos(3)-100)+40 45 30 20];
        Time_Pos = [uint16(FigPos(3)-100)+35 20 40 20];
        Ttxt_Pos = [uint16(FigPos(3)-100)-50 18 90 20];
        Capture_Pos = [uint16(FigPos(3)-200)+1 65 80 20];
        if sno > 1
            set(shand, 'Position', S_Pos);
            set(playhand, 'Position', Play_Pos);
            set(ttxthand, 'Position', Ttxt_Pos);
            set(timehand, 'Position', Time_Pos);
            set(capturehand, 'Position', Capture_Pos);
        end
        set(stxthand, 'Position', Stxt_Pos);
        set(ltxthand, 'Position', Ltxt_Pos);
        set(wtxthand, 'Position', Wtxt_Pos);
        set(lvalhand, 'Position', Lval_Pos);
        set(wvalhand, 'Position', Wval_Pos);
        set(Btnhand, 'Position', Btn_Pos);
        set(ChBxhand, 'Position', ChBx_Pos);
    end

% -=< Slice slider callback >=-
    function SliceSlider(hObj, ~, Img, spectrumAx)
        S = round(get(hObj, 'Value'));
        set(get(sliceAx, 'Children'), 'CData', squeeze(Img(:,:,S,:)));
        caxis(sliceAx, [Rmin Rmax]);
        set(stxthand, 'String', sprintf('Slice# %d (V = %.4f) / %d', S, voltages(S), sno));
        % Clear spectrum
        cla(spectrumAx);
        plot(spectrumAx, V_reduced, zeros(size(V_reduced)), 'b', 'LineWidth', 1.5);
        title(spectrumAx, 'Spectrum at (x, y)');
        xlabel(spectrumAx, 'Voltage (V)');
        ylabel(spectrumAx, 'dI/dV');
        grid(spectrumAx, 'on');
    end

% -=< Mouse scroll callback >=-
    function mouseScroll(~, eventdata)
        UPDN = eventdata.VerticalScrollCount;
        S = S - UPDN;
        if S < 1, S = 1; elseif S > sno, S = sno; end
        set(shand, 'Value', S);
        set(stxthand, 'String', sprintf('Slice# %d (V = %.4f) / %d', S, voltages(S), sno));
        set(get(sliceAx, 'Children'), 'CData', squeeze(Img(:,:,S,:)));
        % Clear spectrum
        cla(spectrumAx);
        plot(spectrumAx, V_reduced, zeros(size(V_reduced)), 'b', 'LineWidth', 1.5);
        title(spectrumAx, 'Spectrum at (x, y)');
        xlabel(spectrumAx, 'Voltage (V)');
        ylabel(spectrumAx, 'dI/dV');
        grid(spectrumAx, 'on');
    end

% -=< Mouse button release callback >=-
    function mouseRelease(~, ~)
        set(fig, 'WindowButtonMotionFcn', {@updateSpectrum, sliceAx, spectrumAx, dIdV, V_reduced});
    end

% -=< Mouse click callback >=-
    function mouseClick(~, ~)
        MouseStat = get(fig, 'SelectionType');
        if MouseStat(1) == 'a' % Right click
            InitialCoord = get(0, 'PointerLocation');
            set(fig, 'WindowButtonMotionFcn', @WinLevAdj);
        end
    end

% -=< Window and level adjust >=-
    function WinLevAdj(~, ~)
        PosDiff = get(0, 'PointerLocation') - InitialCoord;
        Win = Win + PosDiff(1) * WLAdjCoe * FineTuneC(get(ChBxhand, 'Value')+1);
        LevV = LevV - PosDiff(2) * WLAdjCoe * FineTuneC(get(ChBxhand, 'Value')+1);
        if Win < 1, Win = 1; end
        [Rmin, Rmax] = WL2R(Win, LevV);
        caxis(sliceAx, [Rmin Rmax]);
        set(lvalhand, 'String', sprintf('%6.0f', LevV));
        set(wvalhand, 'String', sprintf('%6.0f', Win));
        InitialCoord = get(0, 'PointerLocation');
    end

% -=< Window and level text adjust >=-
    function WinLevChanged(~, ~)
        LevV = str2double(get(lvalhand, 'String'));
        Win = str2double(get(wvalhand, 'String'));
        if Win < 1, Win = 1; end
        [Rmin, Rmax] = WL2R(Win, LevV);
        caxis(sliceAx, [Rmin Rmax]);
    end

% -=< Window and level to range >=-
    function [Rmn Rmx] = WL2R(W, L)
        Rmn = L - (W/2);
        Rmx = L + (W/2);
        if Rmn >= Rmx, Rmx = Rmn + 1; end
    end

% -=< Auto window/level adjust >=-
    function AutoAdjust(~, ~)
        Win = double(max(Img(:)) - min(Img(:)));
        if Win < 1, Win = 1; end
        LevV = double(min(Img(:)) + (Win/2));
        [Rmin, Rmax] = WL2R(Win, LevV);
        caxis(sliceAx, [Rmin Rmax]);
        set(lvalhand, 'String', sprintf('%6.0f', LevV));
        set(wvalhand, 'String', sprintf('%6.0f', Win));
    end

% -=< Play button callback >=-
    function Play(~, ~)
        PlayFlag = ~PlayFlag;
        if PlayFlag
            set(playhand, 'CData', Pause_BG);
        else
            set(playhand, 'CData', Play_BG);
        end
        while PlayFlag
            S = S + 1;
            if S > sno, S = 1; end
            set(shand, 'Value', S);
            set(stxthand, 'String', sprintf('Slice# %d (V = %.4f) / %d', S, voltages(S), sno));
            set(get(sliceAx, 'Children'), 'CData', squeeze(Img(:,:,S,:)));
            % Clear spectrum
            cla(spectrumAx);
            plot(spectrumAx, V_reduced, zeros(size(V_reduced)), 'b', 'LineWidth', 1.5);
            title(spectrumAx, 'Spectrum at (x, y)');
            xlabel(spectrumAx, 'Voltage (V)');
            ylabel(spectrumAx, 'dI/dV');
            grid(spectrumAx, 'on');
            pause(Tinterv/1000);
        end
    end

% -=< Time interval adjust >=-
    function TimeChanged(~, ~)
        Tinterv = str2double(get(timehand, 'String'));
    end

% -=< Capture slice callback >=-
    function CaptureSlice(~, ~)
        if evalin('base', 'exist(''data'', ''var'')')
            data = evalin('base', 'data');
        else
            data.(dataset) = struct();
        end
        if ~isfield(data.(dataset), 'selectedSlice')
            data.(dataset).selectedSlice = [];
            data.(dataset).selectedVoltage = [];
        end
        data.(dataset).selectedSlice = [data.(dataset).selectedSlice; S];
        data.(dataset).selectedVoltage = [data.(dataset).selectedVoltage; voltages(S)];
        assignin('base', 'data', data);
        fprintf('Captured Slice# %d (V = %.4f)\n', S, voltages(S));
        if ~isempty(LOGpath) && ~isempty(LOGfile) && ischar(LOGpath) && ischar(LOGfile)
            LOGcomment = sprintf('Captured Slice# %d (V = %.4f)', S, voltages(S));
            logUsedBlocks(LOGpath, LOGfile, '  ^  ', LOGcomment, 0);
        else
            warning('Logging skipped: LOGpath or LOGfile invalid.');
        end
    end

% -=< Update spectrum callback >=-
    function updateSpectrum(~, ~, sliceAx, spectrumAx, dIdV, V_reduced)
        currentPoint = get(sliceAx, 'CurrentPoint');
        x = floor(currentPoint(1, 1));
        y = floor(currentPoint(1, 2));
        xl = get(sliceAx, 'XLim');
        yl = get(sliceAx, 'YLim');
        if x >= 1 && x <= size(dIdV, 2) && y >= 1 && y <= size(dIdV, 1) && ...
           currentPoint(1, 1) >= xl(1) && currentPoint(1, 1) <= xl(2) && ...
           currentPoint(1, 2) >= yl(1) && currentPoint(1, 2) <= yl(2)
            spectrumData = squeeze(dIdV(y, x, :));
            cla(spectrumAx);
            plot(spectrumAx, V_reduced, spectrumData, 'b', 'LineWidth', 1.5);
            title(spectrumAx, sprintf('Spectrum at (%d, %d)', x, y));
            xlabel(spectrumAx, 'Voltage (V)');
            ylabel(spectrumAx, 'dI/dV');
            grid(spectrumAx, 'on');
        else
            cla(spectrumAx);
            plot(spectrumAx, V_reduced, zeros(size(V_reduced)), 'b', 'LineWidth', 1.5);
            title(spectrumAx, 'Spectrum at (x, y)');
            xlabel(spectrumAx, 'Voltage (V)');
            ylabel(spectrumAx, 'dI/dV');
            grid(spectrumAx, 'on');
        end
    end
end