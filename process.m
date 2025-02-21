clear all;
close all;
clc;

%% load dataset
load('data.mat');

%% verify dataset
fprintf('ตรวจสอบฐานข้อมูล...\n');
for i = 1:70
    if isempty(db_img{i}) || isempty(db_chr{i})
        fprintf('WARNING: Index %d is missing data!\n', i);
    end
end
fprintf('Database verification complete.\n\n');

%% read image from folder Source and impoet to varieble
sourceFolder = 'Source';
filePattern = fullfile(sourceFolder, '*.bmp');
bmpFiles = dir(filePattern);

if isempty(bmpFiles)
    error('ไม่พบไฟล์ .bmp ในโฟลเดอร์ Source');
end

fprintf('พบไฟล์ .bmp จำนวน %d ไฟล์ในโฟลเดอร์ Source\n', length(bmpFiles));

%% varieble for results
results = struct('No', {}, 'License_Plate', {});

%% function for find license plate
function [found, plate_img] = findLicensePlate(img_bw, min_w, max_w, min_h, max_h)
    obj = regionprops(img_bw);
    found = false;
    plate_img = [];
    
    for i = 1:size(obj, 1)
        w = obj(i).BoundingBox(3);
        h = obj(i).BoundingBox(4);
        if (w >= min_w && w <= max_w && h >= min_h && h <= max_h)
            plate_img = ~imcrop(img_bw, obj(i).BoundingBox);
            found = true;
            break;
        end
    end
end

%% loop all file
for fileIdx = 1:length(bmpFiles)
    currentFile = fullfile(sourceFolder, bmpFiles(fileIdx).name);
    fprintf('\n\nกำลังประมวลผลไฟล์ %s (%d จาก %d)\n', bmpFiles(fileIdx).name, fileIdx, length(bmpFiles));
    
    try
        %% read image
        img_rgb = imread(currentFile);
        img_gray = rgb2gray(img_rgb);
        
        % find  the best threshold for image
        best_plate = [];
        best_char_count = 0;
        best_threshold = 0;
        
        % range of threhold
        for threshold = 0.20:0.01:0.99
            img_bw = imbinarize(img_gray, threshold);
            
            % license plate sizes
            plate_sizes = [
                [200, 300, 50, 200];
                [200, 300, 50, 150];
                [200, 350, 80, 140];
                [200, 350, 90, 140];
                [200, 350, 90, 150];
                [200, 385, 90, 150];
                [200, 300, 90, 150];
                [200, 400, 50, 150];
                [200, 400, 90, 140];
                [200, 400, 100, 150];
                [210, 350, 90, 140];
                [220, 350, 90, 140]; 
                [220, 350, 90, 150]; 
                [220, 350, 90, 200];  
                [220, 350, 100, 140];
                [230, 350, 90, 140];   
                [230, 350, 100, 140];  
                [240, 350, 80, 140]; 
                [240, 350, 90, 140];   
                [240, 350, 100, 140];  
                [250, 350, 100, 140]; 
                [270, 350, 100, 140];   
                [290, 350, 100, 140];
                [200, 320, 80, 130];
                [230, 350, 100, 140]; 
                [260, 380, 120, 160]  
            ];
            
            for size_idx = 1:size(plate_sizes, 1)
                [found, plate] = findLicensePlate(img_bw, ...
                    plate_sizes(size_idx, 1), plate_sizes(size_idx, 2), ...
                    plate_sizes(size_idx, 3), plate_sizes(size_idx, 4));
                
                if found
                    % count character
                    obj = regionprops(plate);
                    char_count = 0;
                    
                    for i = 1:size(obj, 1)
                        w = obj(i).BoundingBox(3);
                        h = obj(i).BoundingBox(4);
                        if (w >= 10 && w <= 65 && h >= 40 && h <= 75)
                            char_count = char_count + 1;
                        end
                    end
                    
                    % determine the number of characters
                    if char_count > best_char_count && char_count <= 6
                        best_char_count = char_count;
                        best_plate = plate;
                        best_threshold = threshold;
                    end
                end
            end
        end
        
        if isempty(best_plate)
            warning('ไม่พบป้ายทะเบียนใน %s', bmpFiles(fileIdx).name);
            results(fileIdx).No = fileIdx;
            results(fileIdx).License_Plate = 'ไม่พบป้ายทะเบียน';
            continue;
        end
        
        fprintf('Found optimal threshold: %.2f with %d characters\n', best_threshold, best_char_count);
        
        obj = regionprops(best_plate);
        count = 0;
        img_char = cell(1, 10);
        char_positions = [];
        
        % แยกตัวอักษร
        for i = 1:size(obj, 1)
            w = obj(i).BoundingBox(3);
            h = obj(i).BoundingBox(4);
            if (w >= 10 && w <= 65 && h >= 40 && h <= 75)
                count = count + 1;
                img_char{count} = imcrop(best_plate, obj(i).BoundingBox);
                char_positions(count) = obj(i).BoundingBox(1);
            end
        end
        
        % sort the letters left to right.
        [~, order] = sort(char_positions);
        img_char = img_char(order);
        
        % compare characters
        output_chr = cell(1, count);
        output_acc = zeros(1, count);
        
        for i=1:count
            output_chr{i} = '_';
            output_acc(i) = 0;
            
            for j=1:length(db_img)
                if isempty(db_img{j})
                    continue;
                end
                
                db_img_resize = imresize(db_img{j}, size(img_char{i}));
                
                if size(db_img_resize, 3) > 1
                    db_img_resize = rgb2gray(db_img_resize);
                end
                if size(img_char{i}, 3) > 1
                    img_char_gray = rgb2gray(img_char{i});
                else
                    img_char_gray = img_char{i};
                end
                
                db_img_resize = double(db_img_resize);
                img_char_gray = double(img_char_gray);
                
                img_acc = corr2(img_char_gray, db_img_resize) * 100;
                
                if img_acc > output_acc(i)
                    output_chr{i} = db_chr{j};
                    output_acc(i) = img_acc;
                end
            end
        end
        
        %% save results to varieble
        output_license_plate = strjoin(output_chr, '');
        results(fileIdx).No = fileIdx;
        results(fileIdx).License_Plate = output_license_plate;
        
    catch ME
        warning('เกิดข้อผิดพลาดในการประมวลผลไฟล์ %s: %s', bmpFiles(fileIdx).name, ME.message);
        results(fileIdx).No = fileIdx;
        results(fileIdx).License_Plate = 'ERROR';
    end
end

%% save varieble to output.xls
try
    filename = 'output.xls';
    resultTable = struct2table(results);
    writetable(resultTable, filename);
    fprintf('\nบันทึกผลลัพธ์ลงไฟล์ Excel สำเร็จ!\n');
catch ME
    warning('ไม่สามารถบันทึกผลลัพธ์ลง Excel ได้: %s', ME.message);
    save('output.mat', 'results');
    fprintf('บันทึกผลลัพธ์เป็นไฟล์ .mat แทน\n');
end