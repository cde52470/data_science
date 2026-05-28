FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Taipei \
    BASEBALL_DATA_DIR=/app \
    PLUMBER_HOST=0.0.0.0

# ── 系統套件 + R + Python ─────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        dirmngr \
        wget \
        curl \
        ca-certificates \
        gnupg \
        r-base \
        r-base-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libfontconfig1-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libfreetype6-dev \
        libpng-dev \
        libtiff5-dev \
        libjpeg-dev \
        python3-pip \
        python3-dev \
        libsodium-dev && \
    rm -rf /var/lib/apt/lists/*

# ── Python 套件 ───────────────────────────────────────────────
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# ── R 套件（裝完驗證，失敗則中斷 build） ─────────────────────
RUN Rscript -e "\
  pkgs <- c('ggplot2','dplyr','plumber','randomForest'); \
  install.packages(pkgs, repos='https://cloud.r-project.org', Ncpus=4); \
  missing <- pkgs[!sapply(pkgs, requireNamespace, quietly=TRUE)]; \
  if (length(missing) > 0) stop(paste('安裝失敗:', paste(missing, collapse=', ')))"

# ── 應用程式 ──────────────────────────────────────────────────
WORKDIR /app
COPY team_game_features.csv pca_scores.csv ./
COPY main.py model.py stats.py requirements.txt ./
COPY decision_plot.R run_plumber.R ./
COPY start.sh ./
RUN chmod +x start.sh

EXPOSE 8000 8001
CMD ["./start.sh"]
