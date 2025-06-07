#!/usr/bin/env python3

import sys
import zipfile
import xml.etree.ElementTree as ET
import re
import os
from pathlib import Path

def get_slide_count(pptx_path):
    """PPTXファイルのスライド数を取得"""
    try:
        with zipfile.ZipFile(pptx_path, 'r') as zip_ref:
            # スライドファイルの数をカウント
            slide_files = [f for f in zip_ref.namelist() if f.startswith('ppt/slides/slide') and f.endswith('.xml')]
            return len(slide_files)
    except Exception as e:
        print(f"Error getting slide count from {pptx_path}: {e}", file=sys.stderr)
        return 1

def extract_notes_from_slide(pptx_path, slide_number):
    """PPTXファイルの指定スライドからノート欄のテキストを抽出"""
    try:
        with zipfile.ZipFile(pptx_path, 'r') as zip_ref:
            # 指定スライドのノートファイルを取得
            notes_file = f'ppt/notesSlides/notesSlide{slide_number}.xml'
            if notes_file not in zip_ref.namelist():
                return None
                
            with zip_ref.open(notes_file) as notes_xml:
                content = notes_xml.read().decode('utf-8')
                
                # XML名前空間を処理
                root = ET.fromstring(content)
                
                # ノート欄専用のテキストを抽出（スライド番号プレースホルダーは除外）
                text_elements = []
                for sp in root.findall('.//{http://schemas.openxmlformats.org/presentationml/2006/main}sp'):
                    # プレースホルダーの種類を確認
                    ph_type = None
                    for ph in sp.findall('.//{http://schemas.openxmlformats.org/presentationml/2006/main}ph'):
                        ph_type = ph.get('type')
                        break
                    
                    # ノート欄（body）のテキストのみを抽出
                    if ph_type == 'body':
                        for elem in sp.iter():
                            if elem.tag.endswith('}t'):  # テキスト要素
                                if elem.text and elem.text.strip():
                                    text_elements.append(elem.text.strip())
                
                if text_elements:
                    # 全てのテキストを結合
                    full_text = ' '.join(text_elements).strip()
                    
                    # ファイル名として使用できない文字を除去
                    safe_filename = re.sub(r'[<>:"/\\|?*]', '_', full_text)
                    safe_filename = re.sub(r'\s+', '_', safe_filename)  # 空白をアンダースコアに
                    safe_filename = safe_filename[:50]  # 長すぎる場合は制限
                    
                    return safe_filename if safe_filename else None
                    
    except Exception as e:
        print(f"Error extracting notes from slide {slide_number} of {pptx_path}: {e}", file=sys.stderr)
        return None
    
    return None

def generate_filenames(pptx_path, output_dir):
    """全スライドの出力ファイル名を生成"""
    base_name = Path(pptx_path).stem
    slide_count = get_slide_count(pptx_path)
    filenames = []
    
    for slide_num in range(1, slide_count + 1):
        # 各スライドのノート欄からファイル名を抽出
        notes_filename = extract_notes_from_slide(pptx_path, slide_num)
        
        if notes_filename and notes_filename.strip():
            # ノート欄にテキストがある場合：そのままファイル名として使用
            filename = f"{notes_filename}.png"
        else:
            # ノート欄が空の場合：PPTXファイル名 + 連番
            filename = f"{base_name}_{slide_num:03d}.png"
        
        filenames.append(filename)
    
    return filenames

def generate_filename(pptx_path, output_dir):
    """後方互換性のため：全スライドのファイル名をJSON形式で出力"""
    filenames = generate_filenames(pptx_path, output_dir)
    import json
    return json.dumps(filenames)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 extract_notes.py <pptx_file> <output_dir>")
        sys.exit(1)
    
    pptx_file = sys.argv[1]
    output_dir = sys.argv[2]
    
    filename = generate_filename(pptx_file, output_dir)
    print(filename)