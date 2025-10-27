<?php
// Simple, safe status page for service checks.
// Shows minimal non-sensitive information for quick verification.

function check_extensions(array $exts): array {
		$res = [];
		foreach ($exts as $e) {
				$res[$e] = extension_loaded($e);
		}
		return $res;
}

function write_test(?string $dir = null): bool {
	$dir ??= sys_get_temp_dir();
		$file = rtrim($dir, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . 'status_write_test.txt';
		$ok = false;
		try {
				$bytes = @file_put_contents($file, "ok");
				if ($bytes !== false) {
						$ok = true;
						@unlink($file);
				}
		} catch (Throwable $e) {
				$ok = false;
		}
		return $ok;
}

$exts = ['pdo_mysql','gd','imagick','curl','xml','zip'];
$ext_status = check_extensions($exts);
$write_ok = write_test('/var/www/html') || write_test();


$phpVersion = PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION . '.' . PHP_RELEASE_VERSION;
$sapi = php_sapi_name();
$memLimit = ini_get('memory_limit');
$tz = date_default_timezone_get();
$uploadMax = ini_get('upload_max_filesize');
$server = $_SERVER['SERVER_SOFTWARE'] ?? 'unknown';

?>
<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width,initial-scale=1">
	<title>Service status — web-core</title>
	<style>
		body{font-family:Inter,system-ui,Segoe UI,Roboto,Arial,sans-serif;background:linear-gradient(120deg,#f6f8fa 60%,#e6e0f8 100%);color:#0b1220;padding:28px}
		.card{max-width:760px;margin:0 auto;background:#fff;border-radius:16px;padding:28px 22px 22px 22px;box-shadow:0 6px 18px rgba(120,60,180,0.08);border:2px solid #e2d6f7;position:relative}
		h1{margin:0 0 8px;font-size:22px;letter-spacing:-1px;color:#7c3aed;display:flex;align-items:center;gap:8px}
		h1 .emoji{font-size:1.2em;vertical-align:-2px}
		p.lead{margin:0 0 18px;color:#5b6b77}
		.grid{display:flex;gap:12px;flex-wrap:wrap}
		.box{flex:1 1 220px;background:#fbfdff;border-radius:10px;padding:14px 12px 12px 12px;border:1.5px solid #e9e3f7;box-shadow:0 2px 8px rgba(124,58,237,0.03)}
		.ok{color:#4fbb6b;font-weight:700}
		.bad{color:#d23f44;font-weight:700}
		.foot{margin-top:14px;font-size:13px;color:#69727a}
		.ext-list{list-style:none;padding:0;margin:0}
		.ext-list li{padding:6px 0;border-bottom:1px dashed #e2d6f7}
		.tele{margin:18px 0 0 0;display:grid;grid-template-columns:1fr 1fr;gap:10px 24px}
		.tele-label{color:#7c3aed;font-weight:500;letter-spacing:0.2px}
		.tele-val{font-family:monospace;font-size:15px}
		.cute{font-size:1.1em;display:inline-block;margin-right:4px;vertical-align:-2px}
	</style>
</head>
<body>
	<div class="card">
		<h1><span class="emoji">🐾</span> web-core status</h1>
		<p class="lead">This instance is running! Here are some quick checks to verify your base image (no sensitive details exposed).</p>

		<div class="grid">
			<div class="box">
				<strong>HTTP <span class="cute">💜</span></strong>
				<div class="foot">Page served successfully — web server is responding.</div>
			</div>

			<div class="box">
				<strong>PHP <span class="cute">🐘</span></strong>
				<div class="foot">Version: <?php echo htmlspecialchars($phpVersion, ENT_QUOTES); ?> — SAPI: <?php echo htmlspecialchars($sapi, ENT_QUOTES); ?></div>
			</div>

			<div class="box">
				<strong>Filesystem <span class="cute">📁</span></strong>
				<div class="foot"><?php echo $write_ok ? '<span class="ok">Writable</span>' : '<span class="bad">Not writable</span>'; ?></div>
			</div>
		</div>

		<div class="tele">
			<div><span class="tele-label">Memory limit</span><br><span class="tele-val"><?php echo htmlspecialchars($memLimit, ENT_QUOTES); ?></span></div>
			<div><span class="tele-label">Timezone</span><br><span class="tele-val"><?php echo htmlspecialchars($tz, ENT_QUOTES); echo date_format(new DateTime(), ' (d.m.Y H:i:s)'); ?></span></div>
			<div><span class="tele-label">Max upload size</span><br><span class="tele-val"><?php echo htmlspecialchars($uploadMax, ENT_QUOTES); ?></span></div>
			<div><span class="tele-label">Server software</span><br><span class="tele-val"><?php echo htmlspecialchars($server, ENT_QUOTES); ?></span></div>
		</div>

		<h2 style="margin-top:22px;font-size:16px;color:#7c3aed">Selected PHP extensions</h2>
		<ul class="ext-list">
			<?php foreach ($ext_status as $ext => $ok): ?>
				<li><?php echo $ok ? '<span class="ok">✔</span>' : '<span class="bad">✖</span>'; ?>
					&nbsp;<strong><?php echo htmlspecialchars($ext, ENT_QUOTES); ?></strong>
				</li>
			<?php endforeach; ?>
		</ul>

		<p class="foot">Note: this page intentionally does not expose full phpinfo() or environment variables. For deeper diagnostics, consult container logs.</p>
	</div>
</body>
</html>
