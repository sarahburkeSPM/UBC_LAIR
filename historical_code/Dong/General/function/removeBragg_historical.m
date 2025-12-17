function [Y_removed] = removeBragg(Y)
% This function removes the lattice corrugation of the grid map by removing
% the bragg peaks in the reciprocal space. 


% Identify the bragg peaks
% 1. Fourier transform the image
% 2. Identify the bragg peaks in the reciprocal space
% 3. Remove the bragg peaks in the reciprocal space
% 4. Inverse Fourier transform the image

% Fourier transform the image
QPI = zeros(size(Y));
for i = 1:size(Y,3)
    QPI(:,:,i) = fftshift(fft2(Y(:,:,i)));
end
%QPI_logabs = log(abs(QPI));
QPI_logabs = (abs(QPI));
% display the QPI
figure;
d3gridDisplay(QPI_logabs, 'dynamic');
slice = input('Enter the slice number to remove the bragg peaks: ');
close;

% let the user select the bragg peaks with circular ROI(by symmetry, also apply it to the center symmetric point in the reciprocal space)
% Display the selected slice for user to select Bragg peaks
figure;
imagesc(QPI_logabs(:,:,slice)); axis image; colormap hot; title('Select Bragg peaks to apply Gaussian window');

% Initialize variables to store ROI information
num_peaks = input('Enter the number of unique Bragg peaks to process: ');
Y_removed = Y;
QPI_removed = QPI;

% Get image dimensions
[rows, cols, ~] = size(QPI);
center_row = floor(rows/2)+1;
center_col = floor(cols/2)+1;

% Create a mask for Gaussian window application (start with all ones)
mask = ones(rows, cols);

% Ask user for removal method
removal_method = input('Choose removal method (1 for Gaussian window, 2 for complete removal): ');

% Let user select each Bragg peak
for i = 1:num_peaks
    disp(['Select Bragg peak #', num2str(i), ' with elliptical ROI']);
    
    % Let user draw an elliptical ROI
    h = drawellipse('Color', 'b');
    wait(h);
    
    % Get ROI properties
    center = h.Center;
    semi_axes = h.SemiAxes;
    rotation = h.RotationAngle;
    
    % Validate and ensure independent control of semi-axes
    if length(semi_axes) ~= 2
        error('Semi-axes must be a 2-element vector for independent control');
    end
    
    % Display current semi-axes values
    disp(['Current semi-axes: [', num2str(semi_axes(1)), ', ', num2str(semi_axes(2)), ']']);
    disp('You can adjust these values independently using the ellipse handles');
    
    % Calculate center-symmetric point(q-space inversion symmetry)
    sym_center_x = 2*center_row - center(1);  
    sym_center_y = 2*center_col - center(2);   
    
    % Create center point markers first
    hold on;
    h_marker = plot(center(1), center(2), 'g+', 'MarkerSize', 10);
    sym_marker = plot(sym_center_x, sym_center_y, 'g+', 'MarkerSize', 10);
    
    % Create and display the symmetric ellipse
    sym_h = drawellipse('Center', [sym_center_x, sym_center_y], ...
                       'SemiAxes', semi_axes, ...
                       'RotationAngle', rotation, ...
                       'Color', 'b');
    
    % Enable interactive mode for both ellipses
    h.InteractionsAllowed = 'all';
    sym_h.InteractionsAllowed = 'all';
    
    % Add listeners to keep ellipses and markers synchronized
    addlistener(h, 'MovingROI', @(src,evt) updateEllipseAndMarker(src, sym_h, sym_marker, h_marker, rows, cols));
    addlistener(sym_h, 'MovingROI', @(src,evt) updateEllipseAndMarker(src, h, h_marker, sym_marker, rows, cols));
    
    % Wait for user to confirm both ellipses
    disp('Adjust the ellipses as needed. Press any key when done...');
    pause;
    
    % Get final positions and properties
    center = h.Center;
    semi_axes = h.SemiAxes;
    rotation = h.RotationAngle;
    sym_center = sym_h.Center;
    
    % Create elliptical mask for this peak
    [X_grid, Y_grid] = meshgrid(1:cols, 1:rows);
    
    % Rotate coordinates to align with ellipse axes
    theta = deg2rad(rotation);
    X_rot = (X_grid - center(1)) * cos(theta) + (Y_grid - center(2)) * sin(theta);
    Y_rot = -(X_grid - center(1)) * sin(theta) + (Y_grid - center(2)) * cos(theta);
    
    % Create elliptical mask
    ellipse_mask = (X_rot.^2/semi_axes(1)^2 + Y_rot.^2/semi_axes(2)^2) <= 1;
    
    % Apply chosen removal method
    if removal_method == 1
        % Gaussian window method
        sigma_x = semi_axes(1);
        sigma_y = semi_axes(2);
        gaussian_window = exp(-(X_rot.^2/(2*sigma_x^2) + Y_rot.^2/(2*sigma_y^2)));
        peak_mask = 1 - gaussian_window .* ellipse_mask;
    else
        % Complete removal method
        peak_mask = 1 - ellipse_mask;
    end
    
    % Rotate coordinates for symmetric point
    X_sym_rot = (X_grid - sym_center(1)) * cos(theta) + (Y_grid - sym_center(2)) * sin(theta);
    Y_sym_rot = -(X_grid - sym_center(1)) * sin(theta) + (Y_grid - sym_center(2)) * cos(theta);
    
    % Apply same method to symmetric point
    if removal_method == 1
        sym_gaussian_window = exp(-(X_sym_rot.^2/(2*sigma_x^2) + Y_sym_rot.^2/(2*sigma_y^2)));
        sym_ellipse_mask = (X_sym_rot.^2/semi_axes(1)^2 + Y_sym_rot.^2/semi_axes(2)^2) <= 1;
        sym_peak_mask = 1 - sym_gaussian_window .* sym_ellipse_mask;
    else
        sym_ellipse_mask = (X_sym_rot.^2/semi_axes(1)^2 + Y_sym_rot.^2/semi_axes(2)^2) <= 1;
        sym_peak_mask = 1 - sym_ellipse_mask;
    end
    
    % Combine the masks
    mask = mask .* peak_mask .* sym_peak_mask;
    
    % Remove the ellipses and markers from display
    delete(h);
    delete(sym_h);
    delete(h_marker);
    delete(sym_marker);
end
close;

% Apply the mask to all slices
for i = 1:size(QPI, 3)
    QPI_removed(:,:,i) = QPI(:,:,i) .* mask;
    % Inverse Fourier transform to get the filtered image
    Y_removed(:,:,i) = real(ifft2(ifftshift(QPI_removed(:,:,i))));
end

% Display the result
figure;
subplot(2,2,1); imagesc(Y(:,:,slice)); axis image; title('Original Image');
subplot(2,2,2); imagesc(log(abs(QPI(:,:,slice)))); axis image; title('Original FFT');
subplot(2,2,3); imagesc(Y_removed(:,:,slice)); axis image; title('Filtered Image');
subplot(2,2,4); imagesc(log(abs(QPI_removed(:,:,slice)))); axis image; title('Filtered FFT with Gaussian Window');

% Add helper function for ellipse and marker synchronization
function updateEllipseAndMarker(src, target, marker, src_marker, rows, cols)
    % Calculate distances from source point to edges
    dist_to_left = src.Center(1) - 1;
    dist_to_top = src.Center(2) - 1;
    
    % The symmetric point should have the same distances but to opposite edges
    sym_center = [cols - dist_to_left, rows - dist_to_top];
    
    % Update target ellipse position
    target.Center = sym_center;
    target.SemiAxes = src.SemiAxes;
    target.RotationAngle = src.RotationAngle;
    
    % Update both marker positions
    src_marker.XData = src.Center(1);
    src_marker.YData = src.Center(2);
    marker.XData = sym_center(1);
    marker.YData = sym_center(2);
end

end % End of main function



