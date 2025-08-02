#!/bin/sh

# Image to WebP Converter Script
# Supports lossless quality, custom quality, and unlimited dimensions
# Uses webp and magick (ImageMagick) tools

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo -e "${BLUE}Image to WebP Converter${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] <input_file> [output_file]"
    echo ""
    echo "OPTIONS:"
    echo "  -q, --quality <0-100>    Quality setting (0-100, default: 80)"
    echo "  -l, --lossless          Use lossless compression"
    echo "  -r, --resize <width>    Resize to specified width (maintains aspect ratio)"
    echo "  -h, --height <height>   Resize to specified height (maintains aspect ratio)"
    echo "  -d, --dimensions <WxH>  Resize to specific dimensions (WxH format)"
    echo "  -o, --output <file>     Specify output file name"
    echo "  -f, --force             Overwrite existing output file"
    echo "  -v, --verbose           Verbose output"
    echo "  -d, --delete-original   Delete original file after conversion"
    echo "  -b, --batch             Process all images in a folder"
    echo "  --help                  Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 image.jpg                    # Convert with default quality (80)"
    echo "  $0 -q 90 image.png              # Convert with 90% quality"
    echo "  $0 -l image.jpg                 # Convert with lossless compression"
    echo "  $0 -r 1920 image.jpg            # Resize to 1920px width"
    echo "  $0 -d 1920x1080 image.jpg       # Resize to 1920x1080"
    echo "  $0 -q 85 -o output.webp image.jpg"
    echo "  $0 -d image.jpg                    # Convert and delete original"
    echo "  $0 -b /path/to/folder              # Convert all images in folder"
    echo "  $0 -b -d /path/to/folder           # Convert all and delete originals"
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if file exists
file_exists() {
    [ -f "$1" ]
}

# Function to get file extension
get_extension() {
    echo "${1##*.}"
}

# Function to get filename without extension
get_filename() {
    echo "${1%.*}"
}

# Function to check if file is an image
is_image_file() {
    local file="$1"
    local ext=$(get_extension "$file" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|svg|ico|heic|heif)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get all image files in a directory
get_image_files() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f | while read -r file; do
        if is_image_file "$file"; then
            echo "$file"
        fi
    done
}

# Function to process a single file
process_single_file() {
    local input_file="$1"
    local output_file="$2"
    local quality="$3"
    local lossless="$4"
    local resize_params="$5"
    local delete_original="$6"

    # Display conversion settings
    echo -e "${GREEN}=== Converting: $(basename "$input_file") ===${NC}"
    show_file_info "$input_file"
    echo -e "${BLUE}Output:${NC} $output_file"
    echo -e "${BLUE}Quality:${NC} $([ "$lossless" = "true" ] && echo "Lossless" || echo "$quality%")"
    if [ -n "$resize_params" ]; then
        echo -e "${BLUE}Resize:${NC} $resize_params"
    fi
    echo ""

    # Perform conversion
    if command_exists cwebp; then
        echo -e "${GREEN}Using cwebp tool for conversion...${NC}"
        convert_with_webp "$input_file" "$output_file" "$quality" "$lossless" "$resize_params"
    else
        echo -e "${GREEN}Using ImageMagick for conversion...${NC}"
        convert_with_magick "$input_file" "$output_file" "$quality" "$lossless" "$resize_params"
    fi

    # Check if conversion was successful
    if file_exists "$output_file"; then
        echo -e "${GREEN}✓ Conversion successful!${NC}"
        echo ""
        echo -e "${GREEN}=== Output File Info ===${NC}"
        show_file_info "$output_file"

        # Calculate compression ratio
        local input_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)
        local output_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
        if [ -n "$input_size" ] && [ -n "$output_size" ] && [ "$input_size" -gt 0 ]; then
            local ratio=$(echo "scale=1; $output_size * 100 / $input_size" | bc 2>/dev/null || echo "0")
            echo -e "${BLUE}Compression ratio:${NC} ${ratio}% of original size"
        fi

        # Delete original if requested
        if [ "$delete_original" = "true" ]; then
            echo -e "${YELLOW}Deleting original file: $input_file${NC}"
            rm "$input_file"
        fi

        echo ""
        return 0
    else
        echo -e "${RED}✗ Conversion failed!${NC}"
        return 1
    fi
}

# Function to convert image using webp tool
convert_with_webp() {
    local input_file="$1"
    local output_file="$2"
    local quality="$3"
    local lossless="$4"
    local resize_params="$5"

    local webp_args=""

    if [ "$lossless" = "true" ]; then
        webp_args="-lossless"
    else
        webp_args="-q $quality"
    fi

    if [ -n "$resize_params" ]; then
        webp_args="$webp_args -resize $resize_params"
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}Converting with webp tool...${NC}"
        echo "cwebp $webp_args -o $output_file $input_file"
    fi

    # Try conversion
    if ! cwebp $webp_args -o "$output_file" "$input_file" 2>/dev/null; then
        # If conversion fails due to dimensions, try with automatic resizing
        local dims=$(get_image_dimensions "$input_file")
        local width=$(echo "$dims" | sed -n 's/^\([0-9]*\)x\([0-9]*\)$/\1/p')
        local height=$(echo "$dims" | sed -n 's/^\([0-9]*\)x\([0-9]*\)$/\2/p')
        if [ -n "$width" ] && [ -n "$height" ]; then
            local max_dim=16383

            if [ "$width" -gt "$max_dim" ] || [ "$height" -gt "$max_dim" ]; then
                echo -e "${YELLOW}Image dimensions ($width x $height) exceed WebP limit (16383px). Auto-resizing...${NC}"

                # Calculate new dimensions maintaining aspect ratio
                local scale=1
                if [ "$width" -gt "$height" ]; then
                    scale=$(echo "scale=4; $max_dim / $width" | bc)
                else
                    scale=$(echo "scale=4; $max_dim / $height" | bc)
                fi

                local new_width=$(echo "scale=0; $width * $scale / 1" | bc)
                local new_height=$(echo "scale=0; $height * $scale / 1" | bc)

                echo -e "${BLUE}Resizing to: ${new_width}x${new_height}${NC}"

                # Try conversion with auto-resize
                if ! cwebp $webp_args -resize "$new_width" "$new_height" -o "$output_file" "$input_file" 2>/dev/null; then
                    echo -e "${RED}Conversion failed even with auto-resize${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Conversion failed for unknown reason${NC}"
                return 1
            fi
        else
            echo -e "${RED}Could not determine image dimensions${NC}"
            return 1
        fi
    fi
}

# Function to convert image using ImageMagick
convert_with_magick() {
    local input_file="$1"
    local output_file="$2"
    local quality="$3"
    local lossless="$4"
    local resize_params="$5"

    local magick_args=""

    if [ "$lossless" = "true" ]; then
        magick_args="-define webp:lossless=true"
    else
        magick_args="-quality $quality"
    fi

    if [ -n "$resize_params" ]; then
        magick_args="$magick_args -resize $resize_params"
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}Converting with ImageMagick...${NC}"
        echo "magick $input_file $magick_args WEBP:$output_file"
    fi

    # Try conversion
    if ! magick "$input_file" $magick_args "WEBP:$output_file" 2>/dev/null; then
        # If conversion fails due to dimensions, try with automatic resizing
        local dims=$(get_image_dimensions "$input_file")
        local width=$(echo "$dims" | sed -n 's/^\([0-9]*\)x\([0-9]*\)$/\1/p')
        local height=$(echo "$dims" | sed -n 's/^\([0-9]*\)x\([0-9]*\)$/\2/p')
        if [ -n "$width" ] && [ -n "$height" ]; then
            local max_dim=16383

            if [ "$width" -gt "$max_dim" ] || [ "$height" -gt "$max_dim" ]; then
                echo -e "${YELLOW}Image dimensions ($width x $height) exceed WebP limit (16383px). Auto-resizing...${NC}"

                # Calculate new dimensions maintaining aspect ratio
                local scale=1
                if [ "$width" -gt "$height" ]; then
                    scale=$(echo "scale=4; $max_dim / $width" | bc)
                else
                    scale=$(echo "scale=4; $max_dim / $height" | bc)
                fi

                local new_width=$(echo "scale=0; $width * $scale / 1" | bc)
                local new_height=$(echo "scale=0; $height * $scale / 1" | bc)

                echo -e "${BLUE}Resizing to: ${new_width}x${new_height}${NC}"

                # Try conversion with auto-resize
                if ! magick "$input_file" $magick_args -resize "${new_width}x${new_height}" "WEBP:$output_file" 2>/dev/null; then
                    echo -e "${RED}Conversion failed even with auto-resize${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Conversion failed for unknown reason${NC}"
                return 1
            fi
        else
            echo -e "${RED}Could not determine image dimensions${NC}"
            return 1
        fi
    fi
}

# Function to get image dimensions
get_image_dimensions() {
    local file="$1"
    if command_exists magick; then
        magick identify -format "%wx%h" "$file" 2>/dev/null
    elif command_exists sips; then
        local dims=$(sips -g pixelWidth -g pixelHeight "$file" 2>/dev/null | grep -E "(pixelWidth|pixelHeight)" | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "$dims"
    else
        echo "unknown"
    fi
}

# Function to display file info
show_file_info() {
    local file="$1"
    local dims=$(get_image_dimensions "$file")
    local size=$(du -h "$file" | cut -f1)
    echo -e "${BLUE}File:${NC} $file"
    echo -e "${BLUE}Size:${NC} $size"
    echo -e "${BLUE}Dimensions:${NC} $dims"
}

# Initialize variables
QUALITY=80
LOSSLESS=true  # Default to lossless
RESIZE_WIDTH=""
RESIZE_HEIGHT=""
RESIZE_DIMENSIONS=""
OUTPUT_FILE=""
FORCE=false
VERBOSE=false
INPUT_FILE=""
DELETE_ORIGINAL=false
BATCH_MODE=false

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -l|--lossless)
            LOSSLESS=true
            shift
            ;;
        -r|--resize)
            RESIZE_WIDTH="$2"
            shift 2
            ;;
        -h|--height)
            RESIZE_HEIGHT="$2"
            shift 2
            ;;
        -d|--dimensions)
            RESIZE_DIMENSIONS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--delete-original)
            DELETE_ORIGINAL=true
            shift
            ;;
        -b|--batch)
            BATCH_MODE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            else
                echo -e "${RED}Error: Multiple input files specified${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if input file/directory is provided
if [ -z "$INPUT_FILE" ]; then
    echo -e "${RED}Error: No input file or directory specified${NC}"
    show_usage
    exit 1
fi

# Check if input file/directory exists
if [ ! -e "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Input file/directory '$INPUT_FILE' does not exist${NC}"
    exit 1
fi

# Validate quality parameter
if ! echo "$QUALITY" | grep -q '^[0-9]*$' || [ "$QUALITY" -lt 0 ] || [ "$QUALITY" -gt 100 ]; then
    echo -e "${RED}Error: Quality must be a number between 0 and 100${NC}"
    exit 1
fi

# Check for required tools
if ! command_exists cwebp && ! command_exists magick; then
    echo -e "${RED}Error: Neither 'cwebp' nor 'magick' (ImageMagick) is installed${NC}"
    echo "Please install one of the following:"
    echo "  - webp: brew install webp"
    echo "  - ImageMagick: brew install imagemagick"
    exit 1
fi

# Check for bc (basic calculator) for dimension calculations
if ! command_exists bc; then
    echo -e "${YELLOW}Warning: 'bc' not found. Installing for dimension calculations...${NC}"
    if command_exists brew; then
        brew install bc
    else
        echo -e "${RED}Error: 'bc' is required for dimension calculations. Please install it manually.${NC}"
        exit 1
    fi
fi

# Build resize parameters (default: keep original dimensions)
RESIZE_PARAMS=""
if [ -n "$RESIZE_DIMENSIONS" ]; then
    RESIZE_PARAMS="$RESIZE_DIMENSIONS"
elif [ -n "$RESIZE_WIDTH" ] && [ -n "$RESIZE_HEIGHT" ]; then
    RESIZE_PARAMS="${RESIZE_WIDTH}x${RESIZE_HEIGHT}"
elif [ -n "$RESIZE_WIDTH" ]; then
    RESIZE_PARAMS="${RESIZE_WIDTH}x"
elif [ -n "$RESIZE_HEIGHT" ]; then
    RESIZE_PARAMS="x${RESIZE_HEIGHT}"
fi

# Check if processing a directory in batch mode
if [ -d "$INPUT_FILE" ] || [ "$BATCH_MODE" = "true" ]; then
    # Batch processing mode
    input_dir="$INPUT_FILE"
    if [ -f "$INPUT_FILE" ]; then
        input_dir=$(dirname "$INPUT_FILE")
    fi

    echo -e "${GREEN}=== Batch Image to WebP Converter ===${NC}"
    echo -e "${BLUE}Processing directory:${NC} $input_dir"
    echo -e "${BLUE}Quality:${NC} $([ "$LOSSLESS" = "true" ] && echo "Lossless" || echo "$QUALITY%")"
    if [ -n "$RESIZE_PARAMS" ]; then
        echo -e "${BLUE}Resize:${NC} $RESIZE_PARAMS"
    fi
    if [ "$DELETE_ORIGINAL" = "true" ]; then
        echo -e "${BLUE}Delete original:${NC} Yes"
    fi
    echo ""

        # Get all image files in the directory
    image_files=()
    for file in "$input_dir"/*; do
        if [ -f "$file" ] && is_image_file "$file"; then
            image_files+=("$file")
        fi
    done

    if [ ${#image_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No image files found in directory: $input_dir${NC}"
        exit 0
    fi

    echo -e "${BLUE}Found ${#image_files[@]} image file(s) to process:${NC}"
    for file in "${image_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""

    # Process each image file
    success_count=0
    total_count=${#image_files[@]}

    for input_file in "${image_files[@]}"; do
        base_name=$(get_filename "$input_file")
        output_file="${base_name}.webp"

        # Skip if output file exists and force is not set
        if file_exists "$output_file" && [ "$FORCE" != "true" ]; then
            echo -e "${YELLOW}Skipping $(basename "$input_file") - output file already exists${NC}"
            continue
        fi

        if process_single_file "$input_file" "$output_file" "$QUALITY" "$LOSSLESS" "$RESIZE_PARAMS" "$DELETE_ORIGINAL"; then
            success_count=$((success_count + 1))
        fi
    done

    echo -e "${GREEN}=== Batch Processing Complete ===${NC}"
    echo -e "${BLUE}Successfully converted:${NC} $success_count/$total_count files"

else
    # Single file processing mode
    # Determine output filename if not specified
    if [ -z "$OUTPUT_FILE" ]; then
        base_name=$(get_filename "$INPUT_FILE")
        OUTPUT_FILE="${base_name}.webp"
    fi

    # Check if output file exists and force flag
    if file_exists "$OUTPUT_FILE" && [ "$FORCE" != "true" ]; then
        echo -e "${YELLOW}Warning: Output file '$OUTPUT_FILE' already exists${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if ! echo "$REPLY" | grep -q '^[Yy]$'; then
            echo "Conversion cancelled."
            exit 0
        fi
    fi

    # Process single file
    process_single_file "$INPUT_FILE" "$OUTPUT_FILE" "$QUALITY" "$LOSSLESS" "$RESIZE_PARAMS" "$DELETE_ORIGINAL"
fi