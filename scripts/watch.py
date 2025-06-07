#!/usr/bin/env python3

import os
import sys
import time
import json
import hashlib
import subprocess
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileModifiedEvent, FileMovedEvent
from collections import defaultdict
from threading import Lock, Timer

# パス設定
INPUT_DIR = "/app/input"
STATUS_FILE = "/app/status/status.json"
COOLDOWN_PERIOD = 2  # 同じファイルの処理間隔（秒）
SCRIPT_DIR = Path(__file__).parent.absolute()

class EventBuffer:
    """イベントバッファリングシステム"""
    def __init__(self, processor, delay=0.1):
        self.processor = processor
        self.delay = delay
        self.buffer = defaultdict(int)
        self.timers = {}
        self.lock = Lock()
    
    def add_event(self, file_path):
        """イベントをバッファに追加"""
        with self.lock:
            # 既存のタイマーをキャンセル
            if file_path in self.timers and self.timers[file_path]:
                self.timers[file_path].cancel()
            
            # イベントカウントを増やす
            self.buffer[file_path] += 1
            
            # 新しいタイマーをセット
            timer = Timer(self.delay, self.process_buffered_event, args=[file_path])
            self.timers[file_path] = timer
            timer.start()
    
    def process_buffered_event(self, file_path):
        """バッファされたイベントを処理"""
        with self.lock:
            if file_path in self.buffer:
                # 複数のイベントが発生していた場合のみ処理
                if self.buffer[file_path] > 1:
                    self.processor.process_file(file_path)
                
                # バッファをクリア
                del self.buffer[file_path]
                if file_path in self.timers:
                    del self.timers[file_path]

class FileProcessor:
    def __init__(self):
        self.last_processed = {}
        self.last_hash = {}
    
    def get_relative_path(self, full_path):
        """入力ディレクトリからの相対パスを取得"""
        return str(Path(full_path).relative_to(INPUT_DIR))
    
    def validate_file(self, file_path):
        """ファイルの検証"""
        if not os.path.isfile(file_path):
            return False
            
        basename = os.path.basename(file_path)
        
        # PPTXファイルかどうかの確認
        if not basename.lower().endswith('.pptx'):
            return False
            
        # 一時ファイル・バックアップファイルの除外
        if any(basename.startswith(prefix) for prefix in ['~$', '.#', '._']):
            return False
            
        # ファイルサイズの確認（100MB制限）
        try:
            if os.path.getsize(file_path) > 104857600:
                return False
        except OSError:
            return False
            
        return True
    
    def can_process_file(self, file_path):
        """ファイル処理の制御"""
        current_time = time.time()
        
        # クールダウン期間のチェック
        if file_path in self.last_processed:
            if current_time - self.last_processed[file_path] < COOLDOWN_PERIOD:
                return False
        
        # ファイル内容の変更チェック
        try:
            with open(file_path, 'rb') as f:
                current_hash = hashlib.md5(f.read()).hexdigest()
        except:
            return False
        
        if file_path in self.last_hash and current_hash == self.last_hash[file_path]:
            return False
        
        self.last_hash[file_path] = current_hash
        self.last_processed[file_path] = current_time
        return True
    
    def process_file(self, file_path):
        """ファイル処理の実行"""
        if not self.validate_file(file_path):
            return
            
        if not self.can_process_file(file_path):
            return
            
        try:
            rel_path = self.get_relative_path(file_path)
            convert_script = str(SCRIPT_DIR / 'convert.sh')
            subprocess.run([convert_script, file_path, rel_path], check=True)
        except (subprocess.SubprocessError, OSError) as e:
            print(f"Error processing file {file_path}: {e}", file=sys.stderr)

class FileChangeHandler(FileSystemEventHandler):
    def __init__(self, processor):
        self.processor = processor
        self.event_buffer = EventBuffer(processor)
    
    def on_modified(self, event):
        """ファイル変更イベントの処理"""
        if event.is_directory:
            return
            
        file_path = event.src_path
        if not file_path.lower().endswith('.pptx'):
            return
            
        # イベントをバッファに追加
        self.event_buffer.add_event(file_path)

    def on_created(self, event):
        """ファイル作成イベントの処理"""
        if event.is_directory:
            return
            
        file_path = event.src_path
        if not file_path.lower().endswith('.pptx'):
            return
            
        self.event_buffer.add_event(file_path)

    def on_moved(self, event):
        """ファイル移動イベントの処理"""
        if not isinstance(event, FileMovedEvent) or event.is_directory:
            return

        # 移動元または移動先のファイルが.pptxかチェック
        src_path = event.src_path
        dest_path = event.dest_path
        is_src_pptx = src_path.lower().endswith('.pptx')
        is_dest_pptx = dest_path.lower().endswith('.pptx')

        # 監視対象ディレクトリ内の移動かチェック
        is_src_in_input = src_path.startswith(INPUT_DIR)
        is_dest_in_input = dest_path.startswith(INPUT_DIR)

        # パターン1: 監視対象ディレクトリ内でのPPTXファイルの移動
        if is_src_pptx and is_dest_pptx and is_src_in_input and is_dest_in_input:
            self.event_buffer.add_event(dest_path)
            return

        # パターン2: PPTXファイルが監視対象ディレクトリに移動された
        if is_dest_pptx and is_dest_in_input:
            self.event_buffer.add_event(dest_path)
            return

def main():
    # ディレクトリの作成
    Path(STATUS_FILE).parent.mkdir(parents=True, exist_ok=True)
    Path(INPUT_DIR).mkdir(parents=True, exist_ok=True)
    
    print(f"Monitoring directory: {INPUT_DIR}")
    
    # 監視の設定
    processor = FileProcessor()
    event_handler = FileChangeHandler(processor)
    observer = Observer()
    observer.schedule(event_handler, INPUT_DIR, recursive=True)
    
    try:
        observer.start()
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

if __name__ == "__main__":
    main()