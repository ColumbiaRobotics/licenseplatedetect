% Emblem Detect Code works only for car picture 20.jpg. Filters will be
% tuned for other images. Note that this is not included with
% main/main_with_steps.
clear; clc; close all;

[file,path]=uigetfile(fullfile(pwd,'Test Set','*.bmp;*.png;*.jpg'),'select file'); % To select desired image
s=[path,file];
A = imread(s);
% make image grayscale
I = rgb2gray(A);

% blob detection using MSER algorithm
[mserRegions, mserConnComp] = detectMSERFeatures(I,'RegionAreaRange',[10 8000],'ThresholdDelta', 1);

% define MSER properties for filtering
mserStats = regionprops(mserConnComp, 'BoundingBox', 'Eccentricity', ...
    'Solidity', 'Extent', 'Euler', 'EquivDiameter', 'MajorAxisLength','Image', 'Orientation');

% compute bounding box ratio to add additional filtering parameter 
bbox = vertcat(mserStats.BoundingBox);
w = bbox(:,3);
h = bbox(:,4);
aspectRatio = w./h;

% filterIdx specs optimized for reasonably flexible detection 
filterIdx = aspectRatio' > 3 | aspectRatio' < 0.5;
filterIdx = filterIdx | [mserStats.EquivDiameter] > 40 | [mserStats.EquivDiameter] < 20;
filterIdx = filterIdx | abs([mserStats.Orientation]) > 25;
filterIdx = filterIdx | [mserStats.Eccentricity] > .6;
filterIdx = filterIdx | [mserStats.Extent] < 0.25 | [mserStats.Extent] > 0.75;
filterIdx = filterIdx | [mserStats.EulerNumber] > 1;

% remove filtered regions; if a region returned a '1' for any of the above
% criteria, it got removed; if a region returned a '0', it was kept

mserStats(filterIdx) = [];
mserRegions(filterIdx) = [];

% define bounding boxes over remaining MSER blobs 
bboxes = vertcat(mserStats.BoundingBox);

% convert from the [x y width height] bounding box format to the [xmin ymin
% xmax ymax] format for convenience.
xmin = bboxes(:,1);
ymin = bboxes(:,2);
xmax = xmin + bboxes(:,3) - 1;
ymax = ymin + bboxes(:,4) - 1;

 
% expand bounding boxes a little bit for neatness  
expansionAmount = 0.02;
xmin = (1-expansionAmount) * xmin;
ymin = (1-expansionAmount) * ymin;
xmax = (1+expansionAmount) * xmax;
ymax = (1+expansionAmount) * ymax;
cropbox = [xmin ymin xmax-xmin ymax-ymin];

% crop the image to just the bounding box 
emblem = imcrop(I, cropbox);
imshow(emblem)
%take emblem size for resizing of stock emblems 
imsize = size(emblem); 

Emblem{1} = imread('Nissan_Logo.jpg');
Emblem{2} = imread('Audi_Logo.jpg');
Emblem{3} = imread('Mercedes_Logo.jpg');
Emblem{4} = imread('Hyundai_Logo.jpg');
Emblem{5} = imread('Kia_Logo.jpg');
Emblem{6} = imread('BMW_Logo.jpg');
Emblem{7} = imread('Honda_Logo.jpg');
Emblem{8} = imread('Toyota_Logo.jpg');
Emblem{9} = imread('Daewoo_Logo.jpg');
Emblem{10} = imread('Chevy_Logo.jpg');
for i=1:10
    Emblem{i} = rgb2gray(Emblem{i});
    Emblem{i} = imresize(Emblem{i}, [imsize(1) imsize(2)]);
    ECorr(i) = corr2(Emblem{i}, emblem);
end
[val ind] = max(ECorr);
if ind == 1
    disp('Nissan')
    else if ind == 2
    disp('Audi')
    else if ind == 3 
    disp('Mercedes')
    else if ind == 4
    disp ('Hyundai')
    else if ind == 5
    disp ('Kia')
    else if ind == 6
    disp ('BMW')
    else if ind == 7 
    disp ('Honda')
    else if ind == 8 
    disp ('Toyota')
    else if ind ==9
    disp ('Daewoo')
    else if ind == 10
    disp ('Chevy')
    end
    end
    end
    end
    end
    end
    end
    end
    end
end
