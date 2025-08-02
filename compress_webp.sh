#!/bin/sh

# WebP Lossless Compression Script
# Optimizes WebP images for smaller file size while maintaining quality
# Similar to ImageOptim but specifically for WebP files

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
LOSSLESS=true
QUALITY=100
METHOD=6
SHARPNESS=0
FILTER_STRENGTH=60
AUTO_FILTER=true
FILTER_TYPE=0
PASS=1
PREPROCESSING=0
PARTITIONS=0
PARTITION_LIMIT=0
ALPHA_QUALITY=100
ALPHA_FILTER=1
ALPHA_CLEANUP=true
NO_ALPHA=false
NEAR_LOSSLESS=100
DELTA_PALETTE=false
USE_DELTA_PALETTE=false
SHARPNESS_YUV=0
SNS_STRENGTH=50
FILTER_SHARPNESS=0
FILTER_STRENGTH=60
STRONG=false
VERBOSE=false
FORCE=false
BACKUP=true
BATCH_MODE=false
DELETE_ORIGINAL=false

# Function to display usage
show_usage() {
    echo -e "${BLUE}WebP Lossless Compression Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] <input_file> [output_file]"
    echo ""
    echo "OPTIONS:"
    echo "  -q, --quality <0-100>      Quality setting (0-100, default: 100 for lossless)"
    echo "  -l, --lossy               Use lossy compression (default: lossless)"
    echo "  -m, --method <0-6>         Compression method (0-6, default: 6)"
    echo "  -s, --sharpness <0-7>      Sharpness (0-7, default: 0)"
    echo "  -f, --filter-strength <0-100>  Filter strength (0-100, default: 60)"
    echo "  -a, --auto-filter         Enable auto filter (default: true)"
    echo "  -t, --filter-type <0-4>   Filter type (0-4, default: 0)"
    echo "  -p, --pass <1-10>         Passes (1-10, default: 1)"
    echo "  -r, --preprocessing <0-1> Preprocessing (0-1, default: 0)"
    echo "  -n, --near-lossless <0-100> Near lossless (0-100, default: 100)"
    echo "  -d, --delta-palette       Use delta palette"
    echo "  -S, --strong              Strong compression"
    echo "  -o, --output <file>       Specify output file name"
    echo "  -f, --force               Overwrite existing output file"
    echo "  -v, --verbose             Verbose output"
    echo "  -b, --backup              Create backup of original (default: true)"
    echo "  -D, --delete-original     Delete original file after compression"
    echo "  -B, --batch               Process all WebP files in a folder"
    echo "  --help                    Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 image.webp                    # Compress with lossless settings"
    echo "  $0 -l -q 90 image.webp           # Compress with 90% quality (lossy)"
    echo "  $0 -m 6 -s 2 image.webp          # Use method 6 with sharpness 2"
    echo "  $0 -S image.webp                 # Use strong compression"
    echo "  $0 -B /path/to/folder            # Compress all WebP files in folder"
    echo "  $0 -B -D /path/to/folder         # Compress all and delete originals"
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

# Function to check if file is a WebP image
is_webp_file() {
    local file="$1"
    local ext=$(get_extension "$file" | tr '[:upper:]' '[:lower:]')
    [ "$ext" = "webp" ]
}

# Function to get file size in bytes
get_file_size() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo "0"
}

# Function to format file size
format_size() {
    local size="$1"
    if [ "$size" -gt 1048576 ]; then
        echo "$(echo "scale=1; $size / 1048576" | bc) MB"
    elif [ "$size" -gt 1024 ]; then
        echo "$(echo "scale=1; $size / 1024" | bc) KB"
    else
        echo "${size} B"
    fi
}

# Function to calculate compression ratio
calculate_compression_ratio() {
    local original_size="$1"
    local compressed_size="$2"
    if [ "$original_size" -gt 0 ]; then
        local ratio=$(echo "scale=1; (1 - $compressed_size / $original_size) * 100" | bc)
        echo "$ratio"
    else
        echo "0"
    fi
}

# Function to process a single WebP file
process_single_file() {
    local input_file="$1"
    local output_file="$2"
    local quality="$3"
    local lossless="$4"
    local method="$5"
    local sharpness="$6"
    local filter_strength="$7"
    local auto_filter="$8"
    local filter_type="$9"
    local pass="${10}"
    local preprocessing="${11}"
    local near_lossless="${12}"
    local delta_palette="${13}"
    local strong="${14}"
    local backup="${15}"
    local delete_original="${16}"

    local original_size=$(get_file_size "$input_file")
    local temp_output="${output_file}.tmp"

    # Build cwebp arguments
    local webp_args="-m $method"
    
    if [ "$lossless" = "true" ]; then
        webp_args="$webp_args -lossless"
    else
        webp_args="$webp_args -q $quality"
    fi

    if [ "$sharpness" -gt 0 ]; then
        webp_args="$webp_args -sharpness $sharpness"
    fi

    if [ "$filter_strength" -gt 0 ]; then
        webp_args="$webp_args -f $filter_strength"
    fi

    if [ "$auto_filter" = "true" ]; then
        webp_args="$webp_args -af"
    fi

    if [ "$filter_type" -gt 0 ]; then
        webp_args="$webp_args -filter_type $filter_type"
    fi

    if [ "$pass" -gt 1 ]; then
        webp_args="$webp_args -pass $pass"
    fi

    if [ "$preprocessing" -gt 0 ]; then
        webp_args="$webp_args -preprocessing $preprocessing"
    fi

    if [ "$near_lossless" -lt 100 ]; then
        webp_args="$webp_args -near_lossless $near_lossless"
    fi

    if [ "$delta_palette" = "true" ]; then
        webp_args="$webp_args -delta_palette"
    fi

    if [ "$strong" = "true" ]; then
        webp_args="$webp_args -strong"
    fi

    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}Compressing with cwebp...${NC}"
        echo "cwebp $webp_args -o \"$temp_output\" \"$input_file\""
    fi

    # Try compression
    if ! cwebp $webp_args -o "$temp_output" "$input_file" 2>/dev/null; then
        echo -e "${RED}Compression failed for: $(basename "$input_file")${NC}"
        return 1
    fi

    # Check if compression was successful
    local compressed_size=$(get_file_size "$temp_output")
    if [ "$compressed_size" -eq 0 ]; then
        echo -e "${RED}Compression failed - output file is empty${NC}"
        rm -f "$temp_output"
        return 1
    fi

    # Calculate compression ratio
    local compression_ratio=$(calculate_compression_ratio "$original_size" "$compressed_size")

    # Check if compression actually reduced file size
    if [ "$compressed_size" -ge "$original_size" ]; then
        echo -e "${YELLOW}No compression achieved for: $(basename "$input_file")${NC}"
        echo -e "${BLUE}Original:${NC} $(format_size "$original_size")"
        echo -e "${BLUE}Compressed:${NC} $(format_size "$compressed_size")"
        rm -f "$temp_output"
        return 1
    fi

    # Create backup if requested
    if [ "$backup" = "true" ]; then
        local backup_file="${input_file}.backup"
        cp "$input_file" "$backup_file"
        if [ "$VERBOSE" = "true" ]; then
            echo -e "${BLUE}Backup created:${NC} $(basename "$backup_file")"
        fi
    fi

    # Move temp file to final output
    mv "$temp_output" "$output_file"

    # Delete original if requested
    if [ "$delete_original" = "true" ]; then
        rm -f "$input_file"
        if [ "$VERBOSE" = "true" ]; then
            echo -e "${BLUE}Original deleted:${NC} $(basename "$input_file")"
        fi
    fi

    # Display results
    echo -e "${GREEN}✓ Compressed:${NC} $(basename "$input_file")"
    echo -e "${BLUE}Original:${NC} $(format_size "$original_size")"
    echo -e "${BLUE}Compressed:${NC} $(format_size "$compressed_size")"
    echo -e "${BLUE}Reduction:${NC} ${compression_ratio}%"
    echo ""

    return 0
}

# Function to try different compression settings
try_aggressive_compression() {
    local input_file="$1"
    local output_file="$2"
    local original_size=$(get_file_size "$input_file")
    local best_size="$original_size"
    local best_output="$output_file"
    local best_settings=""

    echo -e "${YELLOW}Trying aggressive compression settings...${NC}"

    # Try different method and quality combinations
    local methods="6 5 4"
    local qualities="80 70 60"
    local sharpness_values="0 1 2"

    for method in $methods; do
        for quality in $qualities; do
            for sharpness in $sharpness_values; do
                local temp_output="${output_file}.test"
                local webp_args="-q $quality -m $method -sharpness $sharpness -af -strong"

                if cwebp $webp_args -o "$temp_output" "$input_file" 2>/dev/null; then
                    local test_size=$(get_file_size "$temp_output")
                    if [ "$test_size" -lt "$best_size" ] && [ "$test_size" -gt 0 ]; then
                        best_size="$test_size"
                        best_output="$temp_output"
                        best_settings="method=$method, quality=$quality, sharpness=$sharpness"

                        if [ "$VERBOSE" = "true" ]; then
                            local ratio=$(calculate_compression_ratio "$original_size" "$test_size")
                            echo -e "${BLUE}New best:${NC} $(format_size "$test_size") (${ratio}%) - $best_settings"
                        fi
                    else
                        rm -f "$temp_output"
                    fi
                fi
            done
        done
    done

    if [ "$best_size" -lt "$original_size" ]; then
        mv "$best_output" "$output_file"
        echo -e "${GREEN}Best compression found:${NC} $best_settings"
        return 0
    else
        echo -e "${YELLOW}No better compression found with aggressive settings${NC}"
        return 1
    fi
}

# Initialize variables
INPUT_FILE=""
OUTPUT_FILE=""

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -l|--lossy)
            LOSSLESS=false
            shift
            ;;
        -m|--method)
            METHOD="$2"
            shift 2
            ;;
        -s|--sharpness)
            SHARPNESS="$2"
            shift 2
            ;;
        -f|--filter-strength)
            FILTER_STRENGTH="$2"
            shift 2
            ;;
        -a|--auto-filter)
            AUTO_FILTER=true
            shift
            ;;
        -t|--filter-type)
            FILTER_TYPE="$2"
            shift 2
            ;;
        -p|--pass)
            PASS="$2"
            shift 2
            ;;
        -r|--preprocessing)
            PREPROCESSING="$2"
            shift 2
            ;;
        -n|--near-lossless)
            NEAR_LOSSLESS="$2"
            shift 2
            ;;
        -d|--delta-palette)
            DELTA_PALETTE=true
            shift
            ;;
        -S|--strong)
            STRONG=true
            shift
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
        -b|--backup)
            BACKUP=true
            shift
            ;;
        -D|--delete-original)
            DELETE_ORIGINAL=true
            shift
            ;;
        -B|--batch)
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

# Validate parameters
if ! echo "$QUALITY" | grep -q '^[0-9]*$' || [ "$QUALITY" -lt 0 ] || [ "$QUALITY" -gt 100 ]; then
    echo -e "${RED}Error: Quality must be a number between 0 and 100${NC}"
    exit 1
fi

if ! echo "$METHOD" | grep -q '^[0-9]*$' || [ "$METHOD" -lt 0 ] || [ "$METHOD" -gt 6 ]; then
    echo -e "${RED}Error: Method must be a number between 0 and 6${NC}"
    exit 1
fi

# Check for required tools
if ! command_exists cwebp; then
    echo -e "${RED}Error: 'cwebp' is not installed${NC}"
    echo "Please install webp: brew install webp"
    exit 1
fi

# Check for bc (basic calculator) for calculations
if ! command_exists bc; then
    echo -e "${YELLOW}Warning: 'bc' not found. Installing for calculations...${NC}"
    if command_exists brew; then
        brew install bc
    else
        echo -e "${RED}Error: 'bc' is required for calculations. Please install it manually.${NC}"
        exit 1
    fi
fi

# Check if processing a directory in batch mode
if [ -d "$INPUT_FILE" ] || [ "$BATCH_MODE" = "true" ]; then
    # Batch processing mode
    input_dir="$INPUT_FILE"
    if [ -f "$INPUT_FILE" ]; then
        input_dir=$(dirname "$INPUT_FILE")
    fi

    echo -e "${GREEN}=== WebP Lossless Compression ===${NC}"
    echo -e "${BLUE}Processing directory:${NC} $input_dir"
    if [ "$LOSSLESS" = "true" ]; then
        echo -e "${BLUE}Compression:${NC} Lossless"
    else
        echo -e "${BLUE}Quality:${NC} $QUALITY%"
    fi
    echo -e "${BLUE}Method:${NC} $METHOD"
    if [ "$SHARPNESS" -gt 0 ]; then
        echo -e "${BLUE}Sharpness:${NC} $SHARPNESS"
    fi
    if [ "$STRONG" = "true" ]; then
        echo -e "${BLUE}Strong compression:${NC} Yes"
    fi
    if [ "$BACKUP" = "true" ]; then
        echo -e "${BLUE}Create backups:${NC} Yes"
    fi
    if [ "$DELETE_ORIGINAL" = "true" ]; then
        echo -e "${BLUE}Delete original:${NC} Yes"
    fi
    echo ""

    # Get all WebP files in the directory
    webp_files=()
    for file in "$input_dir"/*.webp; do
        if [ -f "$file" ] && is_webp_file "$file"; then
            webp_files+=("$file")
        fi
    done

    if [ ${#webp_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No WebP files found in directory: $input_dir${NC}"
        exit 0
    fi

    echo -e "${BLUE}Found ${#webp_files[@]} WebP file(s) to compress:${NC}"
    for file in "${webp_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""

    # Process each WebP file
    success_count=0
    total_count=${#webp_files[@]}
    total_original_size=0
    total_compressed_size=0

    for input_file in "${webp_files[@]}"; do
        output_file="$input_file"  # Overwrite original

        original_size=$(get_file_size "$input_file")
        total_original_size=$((total_original_size + original_size))

        if process_single_file "$input_file" "$output_file" "$QUALITY" "$LOSSLESS" "$METHOD" "$SHARPNESS" "$FILTER_STRENGTH" "$AUTO_FILTER" "$FILTER_TYPE" "$PASS" "$PREPROCESSING" "$NEAR_LOSSLESS" "$DELTA_PALETTE" "$STRONG" "$BACKUP" "$DELETE_ORIGINAL"; then
            success_count=$((success_count + 1))
            compressed_size=$(get_file_size "$output_file")
            total_compressed_size=$((total_compressed_size + compressed_size))
        fi
    done

    echo -e "${GREEN}=== Batch Compression Complete ===${NC}"
    echo -e "${BLUE}Successfully compressed:${NC} $success_count/$total_count files"

    if [ "$total_original_size" -gt 0 ]; then
        total_ratio=$(calculate_compression_ratio "$total_original_size" "$total_compressed_size")
        echo -e "${BLUE}Total original size:${NC} $(format_size "$total_original_size")"
        echo -e "${BLUE}Total compressed size:${NC} $(format_size "$total_compressed_size")"
        echo -e "${BLUE}Total space saved:${NC} ${total_ratio}%"
    fi

else
    # Single file processing mode
    if ! is_webp_file "$INPUT_FILE"; then
        echo -e "${RED}Error: Input file must be a WebP image${NC}"
        exit 1
    fi

    # Determine output filename if not specified
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$INPUT_FILE"  # Overwrite original
    fi

    # Check if output file exists and force flag
    if file_exists "$OUTPUT_FILE" && [ "$FORCE" != "true" ]; then
        echo -e "${YELLOW}Warning: Output file '$OUTPUT_FILE' already exists${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if ! echo "$REPLY" | grep -q '^[Yy]$'; then
            echo "Compression cancelled."
            exit 0
        fi
    fi

    echo -e "${GREEN}=== WebP Lossless Compression ===${NC}"
    echo -e "${BLUE}Input file:${NC} $(basename "$INPUT_FILE")"
    echo -e "${BLUE}Output file:${NC} $(basename "$OUTPUT_FILE")"
    if [ "$LOSSLESS" = "true" ]; then
        echo -e "${BLUE}Compression:${NC} Lossless"
    else
        echo -e "${BLUE}Quality:${NC} $QUALITY%"
    fi
    echo -e "${BLUE}Method:${NC} $METHOD"
    if [ "$SHARPNESS" -gt 0 ]; then
        echo -e "${BLUE}Sharpness:${NC} $SHARPNESS"
    fi
    if [ "$STRONG" = "true" ]; then
        echo -e "${BLUE}Strong compression:${NC} Yes"
    fi
    echo ""

    # Process single file
    if ! process_single_file "$INPUT_FILE" "$OUTPUT_FILE" "$QUALITY" "$LOSSLESS" "$METHOD" "$SHARPNESS" "$FILTER_STRENGTH" "$AUTO_FILTER" "$FILTER_TYPE" "$PASS" "$PREPROCESSING" "$NEAR_LOSSLESS" "$DELTA_PALETTE" "$STRONG" "$BACKUP" "$DELETE_ORIGINAL"; then
        echo -e "${YELLOW}Trying aggressive compression settings...${NC}"
        if try_aggressive_compression "$INPUT_FILE" "$OUTPUT_FILE"; then
            echo -e "${GREEN}Aggressive compression successful!${NC}"
        else
            echo -e "${RED}Compression failed with all settings${NC}"
            exit 1
        fi
    fi
fi