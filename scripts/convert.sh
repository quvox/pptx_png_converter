#!/bin/bash

# エラーが発生したら即座に終了
set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引数の検証
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_file> <relative_path>"
    exit 1
fi

INPUT_FILE="$1"
RELATIVE_PATH="$2"

# パス設定
DATA_DIR="/data"
TEMP_DIR="/tmp/pptx_convert"
ERROR_HANDLER="$SCRIPT_DIR/error_handle.sh"

# 一時ディレクトリの作成
mkdir -p "$TEMP_DIR"

# 出力ディレクトリの準備（入力と同じディレクトリ）
prepare_output_dir() {
    local dir_path="$DATA_DIR/$(dirname "$RELATIVE_PATH")"
    mkdir -p "$dir_path"
    echo "$dir_path"
}

# 一時ファイルのクリーンアップ
cleanup() {
    rm -rf "$TEMP_DIR"/*
}

# エラーハンドリング
handle_error() {
    local error_msg="$1"
    "$ERROR_HANDLER" "$RELATIVE_PATH" "$error_msg"
    cleanup
    exit 1
}

# 出力ファイル名を生成
generate_output_filenames() {
    local input_file="$1"
    local output_dir="$2"
    
    # Pythonスクリプトを使用してファイル名を生成（JSON配列で返される）
    python3 "$SCRIPT_DIR/extract_notes.py" "$input_file" "$output_dir"
}

# 指定ページのスライドをPNG画像に変換
convert_page_to_image() {
    local input_file="$1"
    local page_number="$2"
    local output_png="$3"
    local temp_pdf="$TEMP_DIR/$(basename "$input_file" .pptx).pdf"
    
    # PPTXをPDFに変換（初回のみ）
    if [ ! -f "$temp_pdf" ]; then
        soffice --headless \
            --convert-to pdf \
            --outdir "$TEMP_DIR" \
            "$input_file" || handle_error "PDF conversion failed"
    fi
    
    # PDFから指定ページを抽出し、高品質なPNGに変換
    local page_index=$((page_number - 1))
    convert -density 300 \
        "$temp_pdf[$page_index]" \
        -colorspace sRGB \
        -background none \
        -alpha Background \
        -quality 100 \
        "$TEMP_DIR/temp_page_$page_number.png" || handle_error "PNG conversion failed for page $page_number"
    
    # 白背景を透明に変換
    convert "$TEMP_DIR/temp_page_$page_number.png" \
        -alpha set \
        -background none \
        -channel RGBA \
        -fuzz 1% \
        -fill none \
        -opaque white \
        -trim \
        +repage \
        -bordercolor none -border 5% \
        "$output_png" || handle_error "Transparency conversion failed for page $page_number"
}

# メイン処理
main() {
    local output_dir=$(prepare_output_dir)
    
    # 全ページのファイル名を生成（JSON配列で返される）
    local filenames_json=$(generate_output_filenames "$INPUT_FILE" "$output_dir")
    
    # JSONを解析してファイル名配列を取得
    local filenames_array=($(echo "$filenames_json" | python3 -c "
import sys, json
filenames = json.load(sys.stdin)
for f in filenames:
    print(f)
"))
    
    # 各ページを変換
    local page_count=${#filenames_array[@]}
    for i in $(seq 0 $((page_count - 1))); do
        local page_number=$((i + 1))
        local output_filename="${filenames_array[$i]}"
        local output_png="$output_dir/$output_filename"
        
        echo "Converting page $page_number -> $output_filename"
        convert_page_to_image "$INPUT_FILE" "$page_number" "$output_png"
    done
    
    # クリーンアップ
    cleanup
    
    echo "Successfully converted: $RELATIVE_PATH -> $page_count pages"
}

# 変換処理の実行
main