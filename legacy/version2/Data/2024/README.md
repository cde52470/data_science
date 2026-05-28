# Data/2024/

佔位資料夾。本 repo 不直接 commit 2024 raw release。

`Scripts/cpbl_unsupervised_feature_discovery.ipynb` 的 **Stage 1** 在第一次執行時會自動從
rebas.tw release `v0.1.0-2024` 下載 `CPBL-2024-OpenData.zip` 到這裡並解壓使用。

要手動預先下載：

```bash
curl -L -o Data/2024/CPBL-2024-OpenData.zip \
  https://github.com/rebas-tw/rebas.tw-open-data/releases/download/v0.1.0-2024/CPBL-2024-OpenData.zip
unzip -d Data/2024/ Data/2024/CPBL-2024-OpenData.zip
```
