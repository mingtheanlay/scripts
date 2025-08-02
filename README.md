# Utility Scripts

Simple shell scripts for image processing and WebP conversion.

## Scripts

### `convert_to_webp.sh`

Converts images to WebP format with quality control and resizing options.

**Usage:**

```bash
./convert_to_webp.sh image.jpg
./convert_to_webp.sh -q 90 image.png
./convert_to_webp.sh -b /path/to/folder
```

### `compress_webp.sh`

Compresses existing WebP files for smaller file sizes while maintaining quality.

**Usage:**

```bash
./compress_webp.sh image.webp
./compress_webp.sh -B /path/to/folder
```

## Requirements

- `webp` tools: `brew install webp`
- `ImageMagick` (optional): `brew install imagemagick`
- `bc` (for calculations): `brew install bc`

## Quick Start

1. Make scripts executable: `chmod +x *.sh`
2. Convert images: `./convert_to_webp.sh image.jpg`
3. Compress WebP: `./compress_webp.sh image.webp`

Run `./script.sh --help` for full options.
