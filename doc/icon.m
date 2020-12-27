## Load Octave logo
img = imread ("octave-logo-128.png");

## Draw box
#    B1 - M1 --- B2
#   /      | |     \
#  F1 -----  M2 --- F2
#  |                 |
#  |                 |
#  |         T       |
#  |                 |
#  F3 ------------- F4
#

N = size (img, 1);  # logo size
frame_size = 10;

light_blue = [28, 124, 222] / 255;
brown = [250, 191, 132 ] / 255;

F1 = [0 0] + [-1 -1] * frame_size;
F2 = [N 0] + [ 1 -1] * frame_size;
F4 = [N N] + [ 1  1] * frame_size;
B1 = F1 + [ 30 -30];
B2 = F2 + [-30 -30];
M1 = (B1 + B2) / 2 - [10 0];
M2 = (F1 + F2) / 2 + [10 0];
T =  (F1 + F4) / 2 + [20 0];

prop = {"LineWidth", 12, "FaceColor"};

rectangle ("Position", [F1, F4 - F1], prop{:}, brown);
hold on;
patch ("xdata", [F1(1), B1(1), B2(1), F2(1)], ...
       "ydata", [F1(2), B1(2), B2(2), F2(2)], prop{:}, brown);
rectangle ("Position", [M1, M2 - M1], prop{:}, "k");


## Brown background for Octave logo
img_r = img(:,:,1);
img_g = img(:,:,2);
img_b = img(:,:,3);
idx = ((img_r == 0) & (img_g == 0) & (img_b == 0));
img_r(idx) = brown(1) * 255;
img_g(idx) = brown(2) * 255;
img_b(idx) = brown(3) * 255;
img = cat (3, img_r, img_g, img_b);

## Plot Octave logo
imshow (img);

## Text "pkg"
rectangle ("Position", [T - [10 20], T - [25 25]],
           "Curvature", 0.2,
           "LineWidth", 12,
           "EdgeColor", "b",
           "FaceColor", light_blue);
text (T(1), T(2), "pkg", "FontSize", 36, "Color", "w");

axis auto;