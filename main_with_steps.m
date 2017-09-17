% This code is identical in functionality to main.m, but shows a
% step-by-step process of the algorith. Please press ENTER (or any key) as
% each figure is presented to proceed with the algorithm.


clear; clc; close all
[file,path]=uigetfile(fullfile(pwd,'Test Set','*.bmp;*.png;*.jpg'),'select file'); % To get desired file
s=[path,file];

A = imread(s);

MSER_LicensePlate(A) % Calls License Plate Recognition Script

CarColorDetect(A) % Calls Color Recognition Script