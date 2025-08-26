function [z_flat,comment] = topoPlaneSub(x,y,z,mask,n,plot)
% Description :
% Subtracts the plane in topography images according to some mask, local flat/global flat
% Parameters
%%  Input parameters:
    % x(double): x axis
    % y(double): y axis
    % z(double): topo image
    % mask(double): mask
    % n(integer): number of points to sample, the default number is 200
    % plot(boolean): choose to plot the process of plane sub, the default is F
%%  Output parameters:
    % z_flatten(double): flattened image

arguments
x       {mustBeNumeric}
y       {mustBeNumeric}
z       {mustBeNumeric}
mask = ones(size(z))
n       {mustBeNumeric}=200
plot    {mustBeNumeric}=0
end

% comment
comment = sprintf("topoPaneSub(x, y, z, mask: %s x %s, n = %s, plot = %s)|", mat2str(size(mask,1)),mat2str(size(mask,2)),num2str(n), num2str(plot));

if isempty(mask)
    mask=ones(size(z));
end

% Find valid (nonzero) mask indices
[valid_x, valid_y] = find(mask);
num_valid_points = numel(valid_x);
if num_valid_points < n
    warning('Not enough valid points in mask; using all available points.');
    n = num_valid_points; % Adjust n if there aren't enough valid points
end

valid_coords = [valid_x(:), valid_y(:)];

if n>size(valid_coords, 1)
    warning('Requested more points than available. Using all.')
    sampledCoords = validCoords;
else
    idx = round(linspace(1, size(valid_coords, 1), n)); %take n evenly spaced samples from the list of valid coordinates defined by given mask
    sampledCoords = valid_coords(idx, :);
end

zsample = diag(z(sampledCoords(:,1), sampledCoords(:,2)));

% fit
f = fit([sampledCoords(:,1), sampledCoords(:,2)], zsample, 'poly11'); % do a fit for a plane, poly11 is for 2D 1st order polynomial
[Y,X] = meshgrid(1:numel(y), 1:numel(x));
plane = f.p00 + f.p10*X + f.p01*Y;
z_flat = imsubtract(z,plane); % new topography image
% plot the process if desired
if plot == 1
    figure;
    subplot(1,3,1)
    imagesc(z'); axis image; axis xy; %takes transpose of image to plot
    title('Raw Topography')
    subplot(1,3,2)
    imagesc(plane'); axis image; axis xy; %takes transpose of image to plot
    title('Fitted Plane')
    subplot(1,3,3)
    imagesc(z_flat'); axis image; axis xy; %takes transpose of image to plot
    title('Plane Subtracted Topography')
    colormap(gray);
end
end








