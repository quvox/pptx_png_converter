# PPTX to PNG Converter

PowerPointファイルの1ページ目のスライドから図形を抽出し、PNG画像として保存するDockerコンテナです。

## 機能

- 指定ディレクトリ（とそのサブディレクトリ）内のPPTXファイルを監視
- 新規作成・更新されたPPTXファイルを自動検知
- 1ページ目のスライドをPNG形式で出力
- ディレクトリ構造を維持したまま出力
- エラー時のログ記録とアラート通知

## 必要条件

- Docker
- Docker Compose

## セットアップ

1. リポジトリをクローン
```bash
git clone [repository-url]
cd [repository-name]
```

2. テスト用ディレクトリの確認
```bash
tree test/
test/
├── input/
│   ├── dir1/
│   └── dir2/
│       └── subdir/
└── output/
```

3. Dockerイメージのビルドと起動
```bash
docker-compose up -d --build
```

## 使用方法

1. PPTXファイルを配置
   - `test/input/`ディレクトリ（またはそのサブディレクトリ）にPPTXファイルを配置
   - 自動的に変換が開始されます

2. 変換結果の確認
   - `test/output/`ディレクトリに、入力と同じディレクトリ構造でPNGファイルが出力されます
   - 例：
     ```
     input/dir1/example.pptx → output/dir1/example.png
     ```

## エラーハンドリング

### エラーログの確認
- エラーログは`logs/error.log`に記録されます
- JSONフォーマットで詳細な情報が保存されます

### アラート通知
- 変換エラー時は`output/.alerts/`ディレクトリにアラートファイルが生成されます
- アラートファイル名：`{元のファイル名}.error`

### エラーファイルの保管
- 処理に失敗したファイルは`error_files/YYYY-MM-DD/`ディレクトリに保管されます

## 制限事項

- 対応ファイル形式：PPTX形式のみ
- ファイルサイズ制限：100MB以下
- 一時ファイル（`~$`で始まるファイル）は無視されます
- 処理タイムアウト：PDF変換は300秒

## トラブルシューティング

### コンテナログの確認
```bash
docker-compose logs -f
```

### コンテナの再起動
```bash
docker-compose restart
```

### 完全な再構築
```bash
docker-compose down
docker-compose up -d --build