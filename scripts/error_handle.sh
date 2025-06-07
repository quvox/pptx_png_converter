#!/bin/bash

# エラーが発生したら即座に終了
set -e

# 引数の検証
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <relative_path> <error_message>"
    exit 1
fi

RELATIVE_PATH="$1"
ERROR_MESSAGE="$2"

# パス設定
LOG_DIR="/app/logs"
ALERT_DIR="/app/output/.alerts"
STATUS_FILE="/app/status/status.json"
ERROR_FILES_DIR="/app/error_files/$(date +%Y-%m-%d)"

# ディレクトリの作成
mkdir -p "$LOG_DIR" "$ALERT_DIR" "$ERROR_FILES_DIR"

# エラーログの記録
log_error() {
    local timestamp=$(date -Iseconds)
    local log_entry=$(cat << EOF
{
    "timestamp": "$timestamp",
    "level": "ERROR",
    "event": "conversion_failed",
    "file": "$RELATIVE_PATH",
    "error": "$ERROR_MESSAGE",
    "details": {
        "input_path": "/app/input/$RELATIVE_PATH",
        "output_path": "/app/output/$(dirname "$RELATIVE_PATH")"
    }
}
EOF
)
    echo "$log_entry" >> "$LOG_DIR/error.log"
}

# アラートファイルの作成
create_alert() {
    local alert_path="$ALERT_DIR/$(dirname "$RELATIVE_PATH")"
    mkdir -p "$alert_path"
    local alert_file="$alert_path/$(basename "$RELATIVE_PATH").error"
    echo "$log_entry" > "$alert_file"
}

# ステータスの更新
update_status() {
    local timestamp=$(date -Iseconds)
    cat > "$STATUS_FILE" << EOF
{
    "status": "error",
    "last_update": "$timestamp",
    "last_error": {
        "file": "$RELATIVE_PATH",
        "message": "$ERROR_MESSAGE",
        "timestamp": "$timestamp"
    }
}
EOF
}

# エラーファイルの移動
move_error_file() {
    local source_file="/app/input/$RELATIVE_PATH"
    if [ -f "$source_file" ]; then
        local target_dir="$ERROR_FILES_DIR/$(dirname "$RELATIVE_PATH")"
        mkdir -p "$target_dir"
        cp "$source_file" "$target_dir/"
    fi
}

# メイン処理
main() {
    log_error
    create_alert
    update_status
    move_error_file
    
    echo "Error handled for: $RELATIVE_PATH"
}

# エラーハンドリングの実行
main