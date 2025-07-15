clc; clear; close all;

%% 1. Select & Load Image**
[filename, pathname] = uigetfile({'*.jpg;*.png;*.bmp', 'Image Files'}, 'Select an Image');
if isequal(filename, 0)
    disp('No file selected. Exiting...');
    return;
end
img = imread(fullfile(pathname, filename));

% Convert to Grayscale if RGB
if size(img, 3) == 3
    img = rgb2gray(img);
end

%% 2. Convert Image to Double Precision**
img = double(img);

%% 3. Define JPEG Standard Quantization Table (Luminance Q50)**
Q50 = [
    16 11 10 16 24 40 51 61;
    12 12 14 19 26 58 60 55;
    14 13 16 24 40 57 69 56;
    14 17 22 29 51 87 80 62;
    18 22 37 56 68 109 103 77;
    24 35 55 64 81 104 113 92;
    49 64 78 87 103 121 120 101;
    72 92 95 98 112 100 103 99
];

%% 4. Pad Image to be Multiple of 8x8 Blocks**
[row, col] = size(img);
padded_row = row + mod(8 - mod(row, 8), 8);
padded_col = col + mod(8 - mod(col, 8), 8);
img_padded = padarray(img, [padded_row - row, padded_col - col], 'replicate', 'post');

%% 5. Initialize Storage for Transformed & Quantized Images
dct_img = zeros(size(img_padded));  
quantized_img = zeros(size(img_padded));
reconstructed_img = zeros(size(img_padded));
n_blocks = (size(img_padded, 1) / 8) * (size(img_padded, 2) / 8);
zigzag_blocks = zeros(64, n_blocks);
block_index = 1;

%% 6. Process Image in 8×8 Blocks (Apply DCT, Quantization, Zigzag Scanning)
for i = 1:8:size(img_padded,1)
    for j = 1:8:size(img_padded,2)
        block = img_padded(i:i+7, j:j+7);
        dct_block = dct2(block - 128);  % Shift and Apply 2D DCT
        quantized_block = round(dct_block ./ Q50);  % Quantization
        dct_img(i:i+7, j:j+7) = dct_block;  % Store DCT Block
        quantized_img(i:i+7, j:j+7) = quantized_block;  % Store Quantized Block
        zigzag_blocks(:, block_index) = reshape(zigzag_scan(quantized_block), [], 1); % Store zigzag result
        block_index = block_index + 1;
    end
end

%% **7. Apply Inverse Quantization & IDCT to Reconstruct Image**
for i = 1:8:size(img_padded,1)
    for j = 1:8:size(img_padded,2)
        quantized_block = quantized_img(i:i+7, j:j+7);
        dequantized_block = quantized_block .* Q50; % Inverse Quantization
        idct_block = idct2(dequantized_block) + 128; 
        reconstructed_img(i:i+7, j:j+7) = idct_block;
    end
end

%% 8. Convert Image Back to uint8 & Crop to Original Size**
reconstructed_img = uint8(reconstructed_img(1:row, 1:col));

%% 9. Display Results**
figure;
subplot(1,3,1);
imshow(uint8(img)), title('Original Image');

subplot(1,3,2);
imagesc(log(abs(dct_img) + 1)), colormap(gray);
title('2D DCT of Image');
colorbar;

subplot(1,3,3);
imshow(reconstructed_img), title('Reconstructed Image');

%% 10. Save Compressed & Reconstructed Image
desktop_path = fullfile(getenv('USERPROFILE'), 'Desktop'); 
save_folder = fullfile(desktop_path, 'JPEG_Compression_Output');
if ~exist(save_folder, 'dir')
    mkdir(save_folder);
end
save(fullfile(save_folder, 'dct_image.mat'), 'dct_img');
save(fullfile(save_folder, 'quantized_image.mat'), 'quantized_img');
imwrite(reconstructed_img, fullfile(save_folder, 'reconstructed_image.jpg'));
disp('Compression & Reconstruction Completed! Files saved to Desktop.');

%% 11. Zigzag Scanning Function (Moved to End of Script)
function zigzag = zigzag_scan(block)
    index_order = [
        1  2  6  7 15 16 28 29;
        3  5  8 14 17 27 30 43;
        4  9 13 18 26 31 42 44;
        10 12 19 25 32 41 45 54;
        11 20 24 33 40 46 53 55;
        21 23 34 39 47 52 56 61;
        22 35 38 48 51 57 60 62;
        36 37 49 50 58 59 63 64
    ];
    zigzag = block(index_order);
end
