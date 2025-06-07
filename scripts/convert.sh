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
OUTPUT_DIR="/app/output"
TEMP_DIR="/tmp/pptx_convert"
ERROR_HANDLER="$SCRIPT_DIR/error_handle.sh"

# 一時ディレクトリの作成
mkdir -p "$TEMP_DIR"

# 出力ディレクトリの準備
prepare_output_dir() {
    local dir_path="$OUTPUT_DIR/$(dirname "$RELATIVE_PATH")"
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

# スライドをPNG画像に変換
convert_to_image() {
    local input_file="$1"
    local output_png="$2"
    local temp_pdf="$TEMP_DIR/$(basename "$input_file" .pptx).pdf"
    
    # PPTXをPDFに変換
    soffice --headless \
        --convert-to pdf \
        --outdir "$TEMP_DIR" \
        "$input_file" || handle_error "PDF conversion failed"
    
    # PDFから1ページ目を抽出し、高品質なPNGに変換
    convert -density 300 \
        "$temp_pdf[0]" \
        -colorspace sRGB \
        -background none \
        -alpha Background \
        -quality 100 \
        "$TEMP_DIR/temp.png" || handle_error "PNG conversion failed"
    
    # 白背景を透明に変換
    convert "$TEMP_DIR/temp.png" \
        -alpha set \
        -background none \
        -channel RGBA \
        -fuzz 1% \
        -fill none \
        -opaque white \
        -trim \
        +repage \
        -bordercolor none -border 5% \
        "$output_png" || handle_error "Transparency conversion failed"
}

# メイン処理
main() {
    local output_dir=$(prepare_output_dir)
    local output_png="$output_dir/$(basename "$RELATIVE_PATH" .pptx).png"
    
    # PPTXからPNG変換
    convert_to_image "$INPUT_FILE" "$output_png"
    
    # クリーンアップ
    cleanup
    
    echo "Successfully converted: $RELATIVE_PATH"
}

# 変換処理の実行
main