FROM ubuntu:22.04

# 環境変数の設定
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    libreoffice \
    libreoffice-impress \
    imagemagick \
    python3 \
    python3-pip \
    unzip \
    grep \
    tzdata \
    && pip3 install watchdog \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ImageMagickのポリシー設定を更新してPDF変換を許可
RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml

# アプリケーションディレクトリの作成
WORKDIR /app

# 必要なディレクトリの作成
RUN mkdir -p \
    /app/scripts \
    /app/input \
    /app/output \
    /app/logs \
    /app/status \
    /app/error_files

# 実行権限の設定
RUN chmod -R 755 /app

# スクリプトファイルのコピー
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh /app/scripts/*.py

# コンテナ起動時のコマンド
CMD ["/usr/bin/python3", "/app/scripts/watch.py"]

# ボリュームの設定
VOLUME ["/app/input", "/app/output"]