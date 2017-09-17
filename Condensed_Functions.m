function Condensed_Functions(A)
close all

G = rgb2gray(A);

I = G;

%% LICENSE PLATE DETECTION

[mserRegions, mserConnComp] = detectMSERFeatures(I,'RegionAreaRange',[10 8000],'ThresholdDelta',4); %Applying MSER to detect blobs in a specified region

% Using regionprops to extract properties
mserStats = regionprops(mserConnComp, 'BoundingBox', 'Eccentricity', ...
    'Solidity', 'Extent', 'Euler', 'Image');

% Defining Aspect Ratio
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

% Removing regions
mserStats(filterIdx) = [];
mserRegions(filterIdx) = [];


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

%%BOUNDING BOXES
% Get bounding boxes for all the regions
bboxes = vertcat(mserStats.BoundingBox);

% Changing format of box definitions for ease of use.
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

% Ensuring that the values are within the image boundary
xmin = max(xmin, 1);
ymin = max(ymin, 1);
xmax = min(xmax, size(I,2));
ymax = min(ymax, size(I,1));

% Expanded bounding boxes
expandedBBoxes = [xmin ymin xmax-xmin+1 ymax-ymin+1];
IExpandedBBoxes = insertShape(G,'Rectangle',expandedBBoxes,'LineWidth',3);

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
% optimize overlap for the license plate
textBBoxes = [xmin-25 ymin-25 xmax-xmin+50 ymax-ymin+50];

% Remove bounding boxes that only contain at least 5 blobs (Assuming number
% plates have atleast that many blobs)
numRegionsInGroup = histcounts(componentIndices);
textBBoxes(numRegionsInGroup <= 4, :) = [];


% Showing the final text detection result.
ITextRegion = insertShape(G, 'Rectangle', textBBoxes,'LineWidth',3);

%% COLOUR DETECTION

%Create binary image from input file
BinaryCar=im2bw(A);

%Create the compliment of the binary image file (inverts black and white
%sections)
ComplementCar=imcomplement(BinaryCar);

%Get rid of the holes in the binary image to eliminate small objects, this 
%creates a 'mask' which should be a white shadow of the car on a black
%background
HolesClearedCar = imfill(ComplementCar,'holes');

%Label the connected components in the binary car mask
labeledCarMask = logical(HolesClearedCar);

%Use region props to find bounding boxes and areas
st = regionprops(labeledCarMask,'BoundingBox','Area');
allAreas = [st.Area];

%The largest area should correspond to the car 'mask' in most cases, sort the
%areas to find the largest area's index and use that index to find the
%corresponding bounding box
[sortedAreas, sortingIndexes] = sort(allAreas, 'descend');
carMaskBoxIndex = sortingIndexes(1);
carBB = st(carMaskBoxIndex).BoundingBox;


%Crop the original image using the bounding box of the car mask. Cropped
%car wil be an RGB image
croppedCar = imcrop(A,carBB);

%Find the average HSV values of the cropped car image
cropHSV = rgb2hsv(croppedCar); %change this to use rgb2hsv(croppedCar)
meanHSV = reshape(mean(mean(cropHSV)),[1,3]);

%Find the standard deviation of meanHSV's hue value from expected values of
%red,yellow, green, blue, purple (pink-reds) hues 
%std = (Expected Value - Mean)^2
red_std = ((0/360)-meanHSV(1))^2;
yellow_std = ((60/360)-meanHSV(1))^2;
green_std = ((120/360)-meanHSV(1))^2;
blue_std = ((210/360)-meanHSV(1))^2;
pinkred_std = ((290/360)-meanHSV(1))^2;

%Put these standard deviations into a list, and pick the minimum standard
%deviation as the probable color of the car
colors = [red_std,yellow_std,green_std,blue_std, pinkred_std];
car_color = min(colors);

%Compare car_color to colors, AND check to make sure the car isn't white or
%black by looking at the value/brightness component of the HSV mean. If the
%meanHSV(3) value, which corresponds to brightness, is less than 0.2 - the
%car is likely black or a very dark gray. If the mean_HSV(2) value which
%corresponds to saturation is less than 0.4, the car is likely white or
%silver. These thresholds for black/white have been tweaked by testing but
%would be more optimized if they were found through a learning method
if (car_color == red_std)&&(meanHSV(3)>0.2)&& (meanHSV(2)>0.4)
    color_out = 'RED';
elseif (car_color == blue_std)&&(meanHSV(3)>0.2)&&(meanHSV(2)>0.4)
    color_out = 'BLUE';
elseif (car_color == yellow_std)&&(meanHSV(3)>0.2)&&(meanHSV(2)>0.4)
    color_out = 'YELLOW';
elseif (car_color == green_std)&&(meanHSV(3)>0.2)&&(meanHSV(2)>0.4)
    color_out = 'GREEN';
elseif (car_color == pinkred_std)&&(meanHSV(3)>0.2)&&(meanHSV(2)>0.4)
    color_out = 'RED or PINK';
elseif (meanHSV(3)>0.2)&&(meanHSV(2)<0.4)
    color_out = 'SILVER or WHITE';
elseif meanHSV(3)<0.2
    color_out = 'BLACK';
end

color = color_out;
fprintf(strcat('color:\t',color,'\n'))
str = sprintf('Deskewed Number Plate [DETECTED COLOR = %s]',color);

%% RESULTS

%Looping through every single bounded box that is finally detected
%(Usually 1, but extracting the largest one just in case)
nb = size(textBBoxes,1);
narea = size(nb,1);
for i = 1:nb
    B = imcrop(I,textBBoxes(i,:));
    narea(i) = bwarea(B);
end

function angle = horizonHough(image, precision) % Using Hough Transform to Correct Skew
        
        % Edge Detection (Also works OK with 'Sobel')
        BW = edge(image,'prewitt');

        % Perform the Hough transform.
        [H, T, ~] = hough(BW,'Theta',-90:precision:90-precision);  

        % Find the most dominant line direction.
        data=var(H);                      % Measure variance  
        fold=floor(90/precision);         % Assume right angles 
        data=data(1:fold) + data(end-fold+1:end);
        [~, column] = max(data);          % Finding The column with the sharpest peaks
        angle = -T(column);               % Converting to degrees 
end

[m,i] = max(narea);
if m~=1 %If a license plate is successfully found
    set(figure,'Position',[100,100,1000,500]);
    F = imcrop(A,textBBoxes(i,:));
    subplot(1,2,1)
    imshow(A);
    title('Selected Image')
    NP = imcrop(I,textBBoxes(i,:));
    angle = horizonHough(NP, 2);

    skew = mod(45+angle,90)-45;
    fprintf(strcat('skew:\t',int2str(skew),' degrees\n'))

    
    subplot(1,2,2)
    imshow(imrotate(F, -skew, 'bicubic'));
    title(str);
end
if m== 1
    fprintf('License Plate could not be located\n')
end

    
end