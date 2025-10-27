<?php
// Simple imagick test page based on web-core index.php style
// Tests if imagick extension works correctly

function check_imagick(): array {
		$loaded = extension_loaded('imagick');
		$version = 'N/A';
		$formats_count = 0;
		$can_create = false;
		
		if ($loaded) {
				try {
						$version = Imagick::getVersion()['versionString'];
						$imagick = new Imagick();
						$formats_count = count($imagick->queryFormats());
						
						// Test if we can actually create an image
						$test = new Imagick();
						$test->newImage(10, 10, '#ffffff');
						$test->setImageFormat('png');
						$can_create = true;
						$test->clear();
				} catch (Throwable $e) {
						// Imagick loaded but not functional
				}
		}
		
		return [
				'loaded' => $loaded,
				'version' => $version,
				'formats' => $formats_count,
				'functional' => $can_create
		];
}

$imagick_status = check_imagick();
$phpVersion = PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION . '.' . PHP_RELEASE_VERSION;
$sapi = php_sapi_name();
$server = $_SERVER['SERVER_SOFTWARE'] ?? 'unknown';

?>
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width,initial-scale=1">
	<title>Imagick test — web-core</title>
	<style>
		body{font-family:Inter,system-ui,Segoe UI,Roboto,Arial,sans-serif;background:linear-gradient(120deg,#f6f8fa 60%,#e6e0f8 100%);color:#0b1220;padding:28px}
		.card{max-width:760px;margin:0 auto;background:#fff;border-radius:16px;padding:28px 22px 22px 22px;box-shadow:0 6px 18px rgba(120,60,180,0.08);border:2px solid #e2d6f7;position:relative}
		h1{font-size:2em;margin:0 0 20px;color:#1f2937;font-weight:700}
		.status{margin:20px 0;padding:16px 20px;border-radius:12px;border-left:5px solid}
		.status.ok{background-color:#d1fae5;border-color:#10b981;color:#065f46}
		.status.warn{background-color:#fef3c7;border-color:#f59e0b;color:#92400e}
		.status.fail{background-color:#fee2e2;border-color:#ef4444;color:#991b1b}
		.status-title{font-size:1.15em;font-weight:600;margin-bottom:4px}
		.status-detail{font-size:0.95em;opacity:0.85}
		.info-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin:20px 0}
		.info-item{background:#f9fafb;padding:14px;border-radius:8px;border:1px solid #e5e7eb}
		.info-label{font-size:0.85em;color:#6b7280;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:6px}
		.info-value{font-size:1em;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;color:#1f2937;word-break:break-all}
		.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin:20px 0}
		.gallery-item{background:#f9fafb;border-radius:8px;padding:10px;border:1px solid #e5e7eb;text-align:center}
		.gallery-item img{width:100%;height:auto;border-radius:4px;background:#fff}
		.gallery-caption{margin-top:8px;font-size:0.85em;color:#6b7280;font-weight:500}
		footer{margin-top:28px;padding-top:18px;border-top:1px solid #e5e7eb;font-size:0.9em;color:#6b7280;text-align:center}
	</style>
</head>
<body>
	<div class="card">
		<h1>🎨 Imagick Extension Test</h1>
		
		<div class="status <?php echo $imagick_status['functional'] ? 'ok' : ($imagick_status['loaded'] ? 'warn' : 'fail'); ?>">
			<div class="status-title">
				<?php 
				if ($imagick_status['functional']) {
						echo '✓ Imagick extension is loaded and functional';
				} elseif ($imagick_status['loaded']) {
						echo '⚠ Imagick extension loaded but not functional';
				} else {
						echo '✗ Imagick extension not loaded';
				}
				?>
			</div>
			<?php if (!$imagick_status['functional']): ?>
			<div class="status-detail">Unable to create test images. Check installation.</div>
			<?php endif; ?>
		</div>

		<div class="info-grid">
			<div class="info-item">
				<div class="info-label">PHP version</div>
				<div class="info-value"><?php echo $phpVersion; ?></div>
			</div>
			<div class="info-item">
				<div class="info-label">SAPI</div>
				<div class="info-value"><?php echo $sapi; ?></div>
			</div>
			<div class="info-item">
				<div class="info-label">Server</div>
				<div class="info-value"><?php echo htmlspecialchars($server); ?></div>
			</div>
			<div class="info-item">
				<div class="info-label">ImageMagick</div>
				<div class="info-value"><?php echo htmlspecialchars($imagick_status['version']); ?></div>
			</div>
			<div class="info-item">
				<div class="info-label">Formats</div>
				<div class="info-value"><?php echo $imagick_status['formats']; ?></div>
			</div>
		</div>

		<?php if ($imagick_status['functional']): ?>
		<h2 style="margin-top:30px;font-size:1.3em;">Test Images</h2>
		<div class="gallery">
			<div class="gallery-item">
				<img src="img.php?type=gradient" alt="Gradient">
				<div class="gallery-caption">Gradient</div>
			</div>
			<div class="gallery-item">
				<img src="img.php?type=text" alt="Text">
				<div class="gallery-caption">Text Overlay</div>
			</div>
			<div class="gallery-item">
				<img src="img.php?type=resize" alt="Resize">
				<div class="gallery-caption">Resize + Filter</div>
			</div>
		</div>
		<?php endif; ?>

		<footer>
			web-core imagick test · <?php echo date('Y-m-d H:i:s'); ?>
		</footer>
	</div>
</body>
</html>
