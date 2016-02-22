% This will generate a 3D file from DICOM images, of the skull ONLY
% Very useful link http://dicomiseasy.blogspot.sg/2012/08/chapter-12-pixel-data.html
path_name = 'E:\DICOM\CT scan stuff\PA1\ST1\SE1\';
file_list = dir(path_name);
file_list = file_list(~cellfun('isempty', {file_list.date}));   % exclude invalid entries

% Generate PLY file and keep
ply = fopen('a.ply', 'w+');
fprintf(ply, 'ply\nformat ascii 1.0\n');
points = zeros(1,3);

% First we sort the file list acc to name
for f = 1:size(file_list, 1)
   % Check if file is DICOM, read it in
   file = file_list(f).name;
   if size(file, 2) > 3 && strcmp(file(end-2:end), 'dcm')
       % read in the file
       dc = dicomread(fullfile(path_name, file));
       
       % Calculate voxel spacing parameters
       % http://stackoverflow.com/questions/8847632/how-to-measure-the-distance-in-dicom
       header = dicominfo(fullfile(path_name, file));
       pixel_spacing = header.PixelSpacing;
       z_spacing = header.SpacingBetweenSlices;
       
       % Now, we convert pixel values to Hounsefield Units (HU) https://en.wikipedia.org/wiki/Hounsfield_scale
       % This way we can segment out bone, or any other tissue
       % For this we need the RescaleSlope and RescaleIntercept
       % http://www.idlcoyote.com/fileio_tips/hounsfield.html
       slope = header.RescaleSlope;
       intercept = header.RescaleIntercept;
       
       % Rescale the pixel values to HU
       dc = dc*slope + intercept;
       
       % Display only bones, i.e. items with HU range 600,3000
       % imshow(dc, [600 3000], 'InitialMagnification', 60)
       bone_image = zeros(size(dc));
       bone_pixels = find(dc >= 600 & dc < 3000);
       bone_image(bone_pixels) = dc(bone_pixels);   % Now we have an image of only the bone
       % imshow(bone_image, [], 'InitialMagnification', 60)
       
       % Now we find edges of this image, these are the boundaries of the
       % bone regions
       bone_boundary = edge(bone_image);   % Sobel filter is the default
       
       % generate X,Y,Z values and dump into PLY
       [X, Y] = meshgrid(0:pixel_spacing(1):(size(bone_boundary,2) - 1)*pixel_spacing(1), 0:pixel_spacing(2):pixel_spacing(2)*(size(bone_boundary,1) -1));   % This should be generated only once at the start
       X = X.*bone_boundary;
       Y = Y.*bone_boundary;
       Z = str2num(file(3:end-4))*z_spacing;
       
       current_points = [X(~(X == 0))];                 % added X points
       current_points(:,2) = [Y(~(Y == 0))];            % added Y
       current_points(:,3) = ones(size(current_points,1), 1)*Z; % added Z
       
       points = [points; current_points];
   end
end

points = points(2:end,:,:);         % remove unecessary first point

fprintf(ply, 'element vertex %d\n', size(points, 1));
fprintf(ply, 'property float x\nproperty float y\nproperty float z\n');
fprintf(ply, 'end_header\n');

% writing the actual points..
fclose(ply);
dlmwrite('a.ply', points, '-append', 'delimiter', ' ');