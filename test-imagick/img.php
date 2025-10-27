<?php
// Simple imagick test image generator
// Based on web-core style - minimal, safe, robust

// Check if Imagick is available
if (!extension_loaded('imagick')) {
    header('Content-Type: text/plain');
    die('ERROR: Imagick extension is not loaded!');
}

// Get the requested image type
$type = $_GET['type'] ?? 'gradient';

try {
    $imagick = new Imagick();
    
    switch ($type) {
        case 'gradient':
            // Simple gradient using newPseudoImage
            $imagick->newPseudoImage(400, 300, 'gradient:#667eea-#764ba2');
            $imagick->setImageFormat('png');
            break;
            
        case 'text':
            // Create image with text
            $imagick->newPseudoImage(400, 200, 'gradient:#f6f8fa-#e6e0f8');
            $imagick->setImageFormat('png');
            
            $draw = new ImagickDraw();
            $draw->setFillColor('#1f2937');
            $draw->setFont('DejaVu-Sans');
            $draw->setFontSize(32);
            $draw->setGravity(Imagick::GRAVITY_CENTER);
            $imagick->annotateImage($draw, 0, 0, 0, 'Imagick Works!');
            break;
            
        case 'resize':
            // Create and resize
            $imagick->newPseudoImage(400, 300, 'gradient:#FF6B6B-#4ECDC4');
            $imagick->setImageFormat('png');
            $imagick->resizeImage(200, 150, Imagick::FILTER_LANCZOS, 1);
            break;
            
        default:
            // Fallback - simple colored image
            $imagick->newImage(200, 200, '#667eea');
            $imagick->setImageFormat('png');
            break;
    }
    
    // Output the image
    header('Content-Type: image/png');
    echo $imagick->getImageBlob();
    $imagick->clear();
    
} catch (Throwable $e) {
    // Return error as plain text
    header('Content-Type: text/plain');
    echo 'ERROR: ' . $e->getMessage();
}
