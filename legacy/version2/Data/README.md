# Data/

原始與外部資料；本資料夾分三個用途：

## 結構

```
Data/
├── 2023/             rebas v0.1.0-2023.0  +  v0.1.0-2023.1（本機已內附；checkout 即可用）
│   ├── CPBL-2023-G1-G150-OpenData/                      150 場 + consolidated
│   ├── CPBL-2023-G151-G300-OpenData/                    150 場 + consolidated
│   ├── CPBL-2023-Challenge-OpenData/                    季後挑戰賽
│   └── CPBL-2023-TaiwanSeries-OpenData/                 台灣大賽
├── 2024/             rebas v0.1.0-2024（佔位資料夾；notebook 在第一次跑時自動下載）
│   └── README.md
└── reference/        對照組資料（學長 cleaned CSV 等）
    └── README.md
```

## 來源

| 年度 | release tag | URL |
|---|---|---|
| 2023 G1-G150 | `v0.1.0-2023.0` | <https://github.com/rebas-tw/rebas.tw-open-data/releases/tag/v0.1.0-2023.0> |
| 2023 G151-G300 | `v0.1.0-2023.1` | <https://github.com/rebas-tw/rebas.tw-open-data/releases/tag/v0.1.0-2023.1> |
| 2024 G1-G360 | `v0.1.0-2024` | <https://github.com/rebas-tw/rebas.tw-open-data/releases/tag/v0.1.0-2024> |

授權：ODC-By（rebas.tw 開放資料）。

## 慣例

- **進 git**：2023 release JSON（本研究主要資料來源；體積 ~76 MB 但對重現性必要）
- **不進 git**：2024 release zip 和解壓檔（notebook 自動下載；若想離線使用，跑一次 `master.sh` 即可快取進 `Data/2024/`）

未來如果要把 2023 也移出 git，可在 `.gitignore` 加上 `Data/2023/`，並在這份 README
補上一段「2023 也要 notebook 下載」的說明。
