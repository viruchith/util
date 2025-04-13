#!/bin/zsh

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it with Homebrew: brew install ffmpeg"
    exit 1
fi

# Check if zip is installed (should be included in macOS)
if ! command -v zip &> /dev/null; then
    echo "Error: zip is not available. It should be included with macOS."
    exit 1
fi

# Default values
INPUT_DIR="."
OUTPUT_DIR="compressed_media"
ZIP_NAME="compressed_archive.zip"
COMPRESSION_LEVEL=9 # Maximum compression

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -z|--zip-name)
            ZIP_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-i input_dir] [-o output_dir] [-z zip_name]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-i input_dir] [-o output_dir] [-z zip_name]"
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Convert to absolute paths
INPUT_DIR=$(cd "$INPUT_DIR" && pwd)
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)

echo "Starting media compression from $INPUT_DIR to $OUTPUT_DIR"

# Counter for processed files
processed=0
skipped=0

# Improved file type detection
is_image_file() {
    local file="$1"
    # More comprehensive image detection
    file "$file" | grep -qiE "image|bitmap|JPEG|PNG|GIF|TIFF|BMP|WebP"
}

is_video_file() {
    local file="$1"
    # More comprehensive video detection
    file "$file" | grep -qiE "video|movie|MP4|AVI|MOV|MKV|WebM|FLV|WMV|MPEG|Media|ISO Media" || 
    ffprobe "$file" 2>&1 | grep -qiE "Stream.*Video"
}

# Move to the input directory and work from there
cd "$INPUT_DIR"

# Process files using a recursive function
process_directory() {
    local dir="$1"
    local files=("$dir"/*)
    
    for file in "${files[@]}"; do
        if [[ -d "$file" ]]; then
            # If directory, process it recursively
            process_directory "$file"
        elif [[ -f "$file" ]]; then
            # Get the relative path from input directory
            rel_path="${file#./}"
            
            # Get the file extension in lowercase
            base_name=$(basename "$file")
            ext="${base_name##*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            base_without_ext="${base_name%.*}"
            
            # Create output directory structure
            out_dir="$OUTPUT_DIR/$(dirname "$rel_path")"
            mkdir -p "$out_dir"
            
            echo "Processing: $rel_path"
            
            # Process based on file type
            case "$ext" in
                # Image formats
                jpg|jpeg|png|gif|bmp|tiff|tif|webp)
                    if is_image_file "$file"; then
                        if [[ "$ext" == "png" ]]; then
                            out_file="$out_dir/$base_without_ext.png"
                            echo "Output to: $out_file"
                            ffmpeg -loglevel error -i "$file" -compression_level 10 -pred mixed "$out_file"
                        else
                            out_file="$out_dir/$base_without_ext.webp"
                            echo "Output to: $out_file"
                            ffmpeg -loglevel error -i "$file" -compression_level 6 -q:v 75 "$out_file"
                        fi
                        processed=$((processed+1))
                    else
                        echo "Skipping non-image file with image extension: $rel_path"
                        skipped=$((skipped+1))
                    fi
                    ;;
                
                # Video formats
                mp4|mov|avi|mkv|webm|flv|wmv|m4v|3gp|mpeg|mpg)
                    if is_video_file "$file"; then
                        out_file="$out_dir/$base_without_ext.mkv"
                        echo "Output to: $out_file"
                        ffmpeg -loglevel error -i "$file" -c:v libx265 -preset slow -crf 28 -c:a aac -b:a 128k "$out_file"
                        processed=$((processed+1))
                    else
                        echo "Skipping non-video file with video extension: $rel_path"
                        skipped=$((skipped+1))
                    fi
                    ;;
                
                *)
                    # Try to detect file type regardless of extension
                    if is_image_file "$file"; then
                        out_file="$out_dir/$base_without_ext.webp"
                        echo "Detected image file without standard extension: $rel_path"
                        echo "Output to: $out_file"
                        ffmpeg -loglevel error -i "$file" -lossless 1 -compression_level 6 "$out_file"
                        processed=$((processed+1))
                    elif is_video_file "$file"; then
                        out_file="$out_dir/$base_without_ext.mkv"
                        echo "Detected video file without standard extension: $rel_path"
                        echo "Output to: $out_file"
                        ffmpeg -loglevel error -i "$file" -c:v libx265 -preset slow -crf 28 -c:a aac -b:a 128k "$out_file"
                        processed=$((processed+1))
                    else
                        echo "Skipping unsupported file type: $rel_path"
                        skipped=$((skipped+1))
                    fi
                    ;;
            esac
        fi
    done
}

# Start processing from the current directory (which is INPUT_DIR)
process_directory "."

# Return to the original directory
cd - > /dev/null

echo "Compression completed: $processed files processed, $skipped files skipped."

# Create zip archive with maximum compression
echo "Creating zip archive with maximum compression..."
cd "$(dirname "$OUTPUT_DIR")"
zip -r -"$COMPRESSION_LEVEL" "$ZIP_NAME" "$(basename "$OUTPUT_DIR")"

echo "Archive created: $(pwd)/$ZIP_NAME"
echo "All done!"
