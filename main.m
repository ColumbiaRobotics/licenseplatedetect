clear; clc; close all
[file,path]=uigetfile(fullfile(pwd,'Test Set','*.bmp;*.png;*.jpg'),'select file'); % To select desired image
s=[path,file];

A = imread(s);

Condensed_Functions(A); % Calls script that has both the algorithms with condensed outputs