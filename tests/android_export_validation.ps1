[CmdletBinding()]
param(
	[Parameter(Position = 0)]
	[string]$ApkPath = (Join-Path $PSScriptRoot "..\build\android\Bespren-debug.apk")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-ByteSize {
	param([long]$Bytes)

	if ($Bytes -ge 1GB) {
		return "{0:N2} GiB" -f ($Bytes / 1GB)
	}
	if ($Bytes -ge 1MB) {
		return "{0:N2} MiB" -f ($Bytes / 1MB)
	}
	if ($Bytes -ge 1KB) {
		return "{0:N2} KiB" -f ($Bytes / 1KB)
	}
	return "$Bytes bytes"
}

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
	Write-Error "APK does not exist: $ApkPath"
	exit 1
}

$resolvedApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
if ([System.IO.Path]::GetExtension($resolvedApkPath) -ine ".apk") {
	Write-Error "Expected an .apk file: $resolvedApkPath"
	exit 1
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = $null
try {
	$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedApkPath)
	$entries = @(
		foreach ($entry in $archive.Entries) {
			[pscustomobject]@{
				Name             = $entry.FullName.Replace("\", "/").TrimStart("/")
				NormalizedName   = $entry.FullName.Replace("\", "/").TrimStart("/").ToLowerInvariant()
				Length           = [long]$entry.Length
				CompressedLength = [long]$entry.CompressedLength
			}
		}
	)
}
catch {
	Write-Error "Could not read APK as a ZIP archive: $($_.Exception.Message)"
	exit 1
}
finally {
	if ($null -ne $archive) {
		$archive.Dispose()
	}
}

$entryNames = [System.Collections.Generic.HashSet[string]]::new(
	[System.StringComparer]::OrdinalIgnoreCase
)
foreach ($entry in $entries) {
	[void]$entryNames.Add($entry.NormalizedName)
}

$failures = [System.Collections.Generic.List[string]]::new()

function Require-ExactEntry {
	param(
		[string]$Label,
		[string]$ExpectedPath
	)

	$normalizedExpectedPath = $ExpectedPath.Replace("\", "/").TrimStart("/").ToLowerInvariant()
	if (-not $entryNames.Contains($normalizedExpectedPath)) {
		$failures.Add("$Label missing exact entry '$ExpectedPath'")
	}
}

function Require-MatchingEntry {
	param(
		[string]$Label,
		[string]$Pattern
	)

	$matched = $false
	foreach ($entry in $entries) {
		if ($entry.NormalizedName -match $Pattern) {
			$matched = $true
			break
		}
	}
	if (-not $matched) {
		$failures.Add("$Label missing entry matching /$Pattern/")
	}
}

function Require-CompiledScript {
	param(
		[string]$Label,
		[string]$ProjectScriptPath
	)

	$scriptWithoutExtension = $ProjectScriptPath.Substring(0, $ProjectScriptPath.Length - 3)
	Require-ExactEntry "$Label compiled bytecode" "assets/$scriptWithoutExtension.gdc"
	Require-ExactEntry "$Label source remap" "assets/$ProjectScriptPath.remap"
}

function Require-ImportedAsset {
	param(
		[string]$Label,
		[string]$ProjectAssetPath,
		[string]$ImportedExtensionPattern
	)

	# A VRAM-compressed texture is imported once per GPU format, and Godot spells
	# the format into the compiled name: enemy_walker_walk.png-<md5>.etc2.ctex on
	# Android, .s3tc.ctex on desktop. Lossless imports carry no qualifier at all, so
	# the segment has to be optional rather than assumed either way.
	$fileName = [System.IO.Path]::GetFileName($ProjectAssetPath)
	$escapedFileName = [regex]::Escape($fileName.ToLowerInvariant())
	Require-ExactEntry "$Label import metadata" "assets/$ProjectAssetPath.import"
	Require-MatchingEntry `
		"$Label compiled import" `
		(
			"^assets/\.godot/imported/{0}-[0-9a-f]+(?:\.(?:astc|bptc|etc2|s3tc))?\.(?:{1})$" `
				-f $escapedFileName, $ImportedExtensionPattern
		)
}

function Require-ExportedResource {
	param(
		[string]$Label,
		[string]$ProjectResourcePath
	)

	# A text resource is exported exactly like a scene - a .remap beside the source
	# path plus a binary blob under .godot/exported - only the blob ends in .res.
	$resourceFileName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectResourcePath)
	$escapedResourceFileName = [regex]::Escape($resourceFileName.ToLowerInvariant())
	Require-ExactEntry "$Label resource remap" "assets/$ProjectResourcePath.remap"
	Require-MatchingEntry `
		"$Label binary resource" `
		("^assets/\.godot/exported/[^/]+/export-[0-9a-f]+-{0}\.res$" -f $escapedResourceFileName)
}

function Require-ExportedScene {
	param(
		[string]$Label,
		[string]$ProjectScenePath
	)

	$sceneFileName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectScenePath)
	$escapedSceneFileName = [regex]::Escape($sceneFileName.ToLowerInvariant())
	Require-ExactEntry "$Label scene remap" "assets/$ProjectScenePath.remap"
	Require-MatchingEntry `
		"$Label packed scene" `
		("^assets/\.godot/exported/[^/]+/export-[0-9a-f]+-{0}\.scn$" -f $escapedSceneFileName)
}

# Export bootstrap files must always be present, independently of dependency closure.
Require-ExactEntry "Godot project" "assets/project.binary"
Require-ExactEntry "Godot sparse pack" "assets/assets.sparsepck"

# The checked-in closure manifest is the single source of truth for runtime payload.
# Requiring every entry here prevents the APK gate from silently drifting behind UI,
# world, shader, enemy, audio, or terrain changes.
$workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$closureManifestPath = Join-Path $workspaceRoot "data\runtime_export_closure.json"
if (-not (Test-Path -LiteralPath $closureManifestPath -PathType Leaf)) {
	$failures.Add("Workspace runtime closure manifest is missing: $closureManifestPath")
	$closureResources = @()
}
else {
	try {
		$closureDocument = Get-Content -Raw -LiteralPath $closureManifestPath | ConvertFrom-Json
		if ([int]$closureDocument.schema_version -ne 1) {
			$failures.Add("Unsupported runtime closure manifest schema '$($closureDocument.schema_version)'")
		}
		$closureResources = @($closureDocument.resources)
		if ($closureResources.Count -eq 0) {
			$failures.Add("Runtime closure manifest contains no resources")
		}
	}
	catch {
		$failures.Add("Could not parse runtime closure manifest: $($_.Exception.Message)")
		$closureResources = @()
	}
}

Require-ExactEntry "Runtime closure manifest" "assets/data/runtime_export_closure.json"
Require-ExportedScene `
	"Runtime dependency scene" `
	"scenes/build/runtime_export_dependencies.tscn"

$allowedSourceImportMetadata = [System.Collections.Generic.HashSet[string]]::new(
	[System.StringComparer]::OrdinalIgnoreCase
)
$seenClosurePaths = [System.Collections.Generic.HashSet[string]]::new(
	[System.StringComparer]::OrdinalIgnoreCase
)
foreach ($closureResource in $closureResources) {
	$resourcePath = [string]$closureResource.path
	$resourceType = [string]$closureResource.type
	if (-not $resourcePath.StartsWith("res://", [System.StringComparison]::Ordinal)) {
		$failures.Add("Runtime closure contains invalid path '$resourcePath'")
		continue
	}
	$projectPath = $resourcePath.Substring(6).Replace("\", "/")
	if (-not $seenClosurePaths.Add($projectPath)) {
		$failures.Add("Runtime closure contains duplicate path '$resourcePath'")
		continue
	}
	$label = "Runtime $resourceType '$resourcePath'"
	switch ($resourceType) {
		"Script" {
			Require-CompiledScript $label $projectPath
		}
		"PackedScene" {
			Require-ExportedScene $label $projectPath
		}
		"SpriteFrames" {
			Require-ExportedResource $label $projectPath
		}
		"Texture2D" {
			Require-ImportedAsset $label $projectPath "ctex"
			if ($projectPath.StartsWith("assets/2d/_source_imports/", [System.StringComparison]::OrdinalIgnoreCase)) {
				[void]$allowedSourceImportMetadata.Add("assets/$projectPath.import")
			}
		}
		"AudioStream" {
			$audioExtension = [System.IO.Path]::GetExtension($projectPath).ToLowerInvariant()
			switch ($audioExtension) {
				".ogg" { Require-ImportedAsset $label $projectPath "oggvorbisstr" }
				".wav" { Require-ImportedAsset $label $projectPath "sample" }
				default { $failures.Add("Unsupported runtime audio extension '$audioExtension' for '$resourcePath'") }
			}
		}
		"Shader" {
			Require-ExactEntry $label "assets/$projectPath"
		}
		default {
			$failures.Add("Unsupported runtime closure type '$resourceType' for '$resourcePath'")
		}
	}
}

# Release exports may include compiled runtime dependencies, but never audit vaults,
# development outputs, validation suites, editor tooling, or bundled source archives.
$forbiddenPathPattern = "^assets/(?:addons|artifacts|docs|tests|tools)/"
$sourceImportPrefixPattern = "^assets/assets/2d/_source_imports/"
$sourceArchivePattern = "^assets/.*\.(?:7z|bz2|gz|rar|tar|tgz|xz|zip)$"
$forbiddenEntries = @(
	$entries | Where-Object {
		$_.NormalizedName -match $forbiddenPathPattern -or
		(
			$_.NormalizedName -match $sourceImportPrefixPattern -and
			-not $allowedSourceImportMetadata.Contains($_.NormalizedName)
		) -or
		$_.NormalizedName -match $sourceArchivePattern
	}
)
if ($forbiddenEntries.Count -gt 0) {
	$preview = ($forbiddenEntries | Select-Object -First 12 -ExpandProperty Name) -join ", "
	$failures.Add(
		"Forbidden development/source payload contains $($forbiddenEntries.Count) entries: $preview"
	)
}

$apkFile = Get-Item -LiteralPath $resolvedApkPath
$assetEntries = @($entries | Where-Object { $_.NormalizedName.StartsWith("assets/") })
$compiledScripts = @($entries | Where-Object { $_.NormalizedName -match "^assets/src/.+\.gdc$" })
$remapEntries = @($entries | Where-Object { $_.NormalizedName.EndsWith(".remap") })
$compiledImports = @(
	$entries | Where-Object {
		$_.NormalizedName -match "^assets/\.godot/imported/.+\.(?:ctex|oggvorbisstr|sample)$"
	}
)
$packedScenes = @(
	$entries | Where-Object {
		$_.NormalizedName -match "^assets/\.godot/exported/[^/]+/.+\.scn$"
	}
)
$sparsePack = $entries | Where-Object { $_.NormalizedName -eq "assets/assets.sparsepck" } | Select-Object -First 1

Write-Host "ANDROID EXPORT INVENTORY"
Write-Host "APK: $resolvedApkPath"
Write-Host "APK file size: $(Format-ByteSize $apkFile.Length) ($($apkFile.Length) bytes)"
Write-Host "ZIP entries: $($entries.Count) total; $($assetEntries.Count) Godot payload entries"
Write-Host "Runtime closure contract: $($closureResources.Count) resources"
Write-Host "Runtime evidence: $($compiledScripts.Count) compiled scripts; $($remapEntries.Count) remaps; $($packedScenes.Count) packed scenes; $($compiledImports.Count) compiled imports"
if ($null -ne $sparsePack) {
	Write-Host "Sparse PCK: $(Format-ByteSize $sparsePack.Length) uncompressed; $(Format-ByteSize $sparsePack.CompressedLength) compressed"
}
Write-Host "Forbidden payload entries: $($forbiddenEntries.Count)"
Write-Host "SHA-256: $((Get-FileHash -LiteralPath $resolvedApkPath -Algorithm SHA256).Hash)"

if ($failures.Count -gt 0) {
	Write-Host "ANDROID EXPORT VALIDATION FAILED ($($failures.Count) issues)"
	foreach ($failure in $failures) {
		Write-Host " - $failure"
	}
	exit 1
}

Write-Host "ANDROID EXPORT VALIDATION OK"
exit 0
