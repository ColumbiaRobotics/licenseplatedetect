function MSER_LicensePlate(A)
close all

G = rgb2gray(A);
imshowpair(A,G,'montage');
axis equal
title('Selected Picture in RGB and BW')
pause;

I = G;

[mserRegions, mserConnComp] = detectMSERFeatures(I,'RegionAreaRange',[10 8000],'ThresholdDelta',4);

figure
imshow(I)
hold on
plot(mserRegions, 'showPixelList', false,'showEllipses',true)
title('Blobs Detected by MSER (Ellipses)')
hold off
pause;

% Using regionprops to extract properties
mserStats = regionprops(mserConnComp, 'BoundingBox', 'Eccentricity', ...
    'Solidity', 'Extent', 'Euler', 'Image');

% Compute the aspect ratio using bounding box data.
bbox = vertcat(mserStats.BoundingBox);
w = bbox(:,3);
h = bbox(:,4);
aspectRatio = w./h;

% Filtering out data. These thresholds may need to be tuned for other image
% set.

filterIdx = aspectRatio' > 2.5;
filterIdx = filterIdx | [mserStats.Eccentricity] > .995 ;
filterIdx = filterIdx | [mserStats.Solidity] < .4;
filterIdx = filterIdx | [mserStats.Extent] < 0.2 | [mserStats.Extent] > 0.8;
filterIdx = filterIdx | [mserStats.EulerNumber] < 0;

% Remove regions
mserStats(filterIdx) = [];
mserRegions(filterIdx) = [];

%Show remaining regions
figure
imshow(I)
hold on
plot(mserRegions, 'showPixelList', false,'showEllipses',true)
title('After Removing Regions Based On Filters')
hold off
pause;


%%STROKE WIDTH
% Get a binary image of the a region, and pad it to avoid boundary effects
% during the stroke width computation.
regionImage = mserStats(6).Image;
regionImage = padarray(regionImage, [1 1]);

% Compute the stroke width image.
distanceImage = bwdist(~regionImage);
skeletonImage = bwmorph(regionImage, 'thin', inf);

strokeWidthImage = distanceImage;
strokeWidthImage(~skeletonImage) = 0;

strokeWidthValues = distanceImage(skeletonImage);
strokeWidthMetric = std(strokeWidthValues)/mean(strokeWidthValues);

strokeWidthThreshold = 0.3;
strokeWidthFilterIdx = strokeWidthMetric > strokeWidthThreshold;

% Processing the remaining regions
for j = 1:numel(mserStats)

    regionImage = mserStats(j).Image;
    regionImage = padarray(regionImage, [1 1], 0);

    distanceImage = bwdist(~regionImage);
    skeletonImage = bwmorph(regionImage, 'thin', inf);

    strokeWidthValues = distanceImage(skeletonImage);

    strokeWidthMetric = std(strokeWidthValues)/mean(strokeWidthValues);

    strokeWidthFilterIdx(j) = strokeWidthMetric > strokeWidthThreshold;

end

% Remove regions based on the stroke width variation
mserRegions(strokeWidthFilterIdx) = [];
mserStats(strokeWidthFilterIdx) = [];

%Show remaining regions
figure
imshow(I)
hold on
plot(mserRegions, 'showPixelList', false,'showEllipses',true)
title('After Removing Non-Text Regions Based On Stroke Width Algorithm')
hold off
pause;

%%BOUNDING BOXES
% Get bounding boxes for all the regions
bboxes = vertcat(mserStats.BoundingBox);

% Changing format of box definitons for ease of use.
xmin = bboxes(:,1);
ymin = bboxes(:,2);
xmax = xmin + bboxes(:,3) - 1;
ymax = ymin + bboxes(:,4) - 1;

% Expand the bounding boxes by a small amount.
expansionAmount = 0.02;
xmin = (1-expansionAmount) * xmin;
ymin = (1-expansionAmount) * ymin;
xmax = (1+expansionAmount) * xmax;
ymax = (1+expansionAmount) * ymax;


% Show the expanded bounding boxes
expandedBBoxes = [xmin ymin xmax-xmin+1 ymax-ymin+1];
IExpandedBBoxes = insertShape(G,'Rectangle',expandedBBoxes,'LineWidth',3);

%Show every single Bounding Box
figure
imshow(IExpandedBBoxes)
title('Bounding Boxes after applying expansion')
pause;

% Compute the overlap ratio
overlapRatio = bboxOverlapRatio(expandedBBoxes, expandedBBoxes);

% Set the overlap ratio between a bounding box and itself to zero to
% simplify the graph representation.
n = size(overlapRatio,1);
overlapRatio(1:n+1:n^2) = 0;

% Create the graph
g = graph(overlapRatio);

% Find the connected text regions within the graph
componentIndices = conncomp(g);

% Merge the boxes based on the minimum and maximum dimensions.
xmin = accumarray(componentIndices', xmin, [], @min);
ymin = accumarray(componentIndices', ymin, [], @min);
xmax = accumarray(componentIndices', xmax, [], @max);
ymax = accumarray(componentIndices', ymax, [], @max);

% Compose the merged bounding boxes and applying a rectangular shape to
% optimize for overlap
textBBoxes = [xmin-25 ymin-25 xmax-xmin+50 ymax-ymin+50];

% Remove bounding boxes that only contain at least 5 blobs (Assuming number
% plates have atleast that many blobs)
numRegionsInGroup = histcounts(componentIndices);
textBBoxes(numRegionsInGroup <= 4, :) = [];


% Showing the final text detection result.
ITextRegion = insertShape(G, 'Rectangle', textBBoxes,'LineWidth',3);

figure
imshow(ITextRegion)
title('Detected Text based on Box Overlap')
pause;

%Looping through every single bounded box that is finally detected
%(Usually 1, but extracting the largest one just in case)
nb = size(textBBoxes,1);
if nb>0
    narea = size(nb,1);
    for i = 1:nb
        B = imcrop(I,textBBoxes(i,:));
        narea(i) = bwarea(B);
    end
end
if nb== 0
    narea = [1];
end

[m,i] = max(narea);

if m~=1 %If a license plate is successfully found
    
    NP = imcrop(I,textBBoxes(i,:));
    imshow(NP);
    title('Detected Number Plate')
    axis equal
    pause

    %Deskew
    angle = horizonHough(NP, 2);

    skew = mod(45+angle,90)-45; 
    fprintf(strcat('skew:\t',int2str(skew),' degrees\n'))

    imshow(imrotate(NP, -skew, 'bicubic'));
    title('Deskewed Detected Number Plate')
    axis equal
    pause
    end

if m== 1
    fprintf('License Plate could not be located\n')
end

function angle = horizonHough(image, precision) % Using Hough Transform to Correct Skew
    
    % Edge Detection (Also works OK with 'Sobel')
    BW = edge(image,'prewitt');

    % Perform the Hough transform.
    [H, T, ~] = hough(BW,'Theta',-90:precision:90-precision);  

    % Find the most dominant line direction.
    data=var(H);                      % Measure Variance
    fold=floor(90/precision);         % Assume Right angles 
    data=data(1:fold) + data(end-fold+1:end);
    [~, column] = max(data);          % Finding the column with the sharpest peaks
    angle = -T(column);               % Converting to degrees 
end

end