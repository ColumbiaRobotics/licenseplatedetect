function CarColorDetect(InputCar)

set(figure,'Position',[100 100 700 700])
subplot(2,2,1);
imshow(InputCar);title('Original image');
%%

%Create binary image from input file
BinaryCar=im2bw(InputCar);
subplot(2,2,2);
imshow(BinaryCar);title('Binary Car image');


%Create the compliment of the binary image file (inverts black and white
%sections)
ComplementCar=imcomplement(BinaryCar);
subplot(2,2,3);
imshow(ComplementCar);title('Complement of binary car image');
%%
%Get rid of the holes in the binary image to eliminate small objects, this 
%creates a 'mask' which should be a white shadow of the car on a black
%background
HolesClearedCar = imfill(ComplementCar,'holes');
subplot(2,2,4); 
imshow(HolesClearedCar);title('Car Mask');
pause
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
croppedCar = imcrop(InputCar,carBB);

%%
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
str = sprintf('Cropped Image used for color detection [DETECTED COLOR = %s]',color);

figure;
imshow(croppedCar);title(str);
end
