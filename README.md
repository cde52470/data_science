# CPBL 分析系統

## 啟動方式

### 1. Build Image
```
cd path
docker build -t cpbl-app .
```
首次 build 約需 15–20 分鐘。

### 2. 啟動容器
```
docker run -p 8000:8000 -p 8001:8001 cpbl-app
```

### 3. 開啟瀏覽器
```
http://localhost:8000
```

---

## 注意事項

- Port 8000：FastAPI 主程式
- Port 8001：R Plumber API（決策邊界圖）
- 容器啟動後 R 模型訓練需約 30 秒，decision plot 才會正常顯示
- 若 port 已被佔用，改用其他 port：
  ```
  docker run -p 8080:8000 -p 8081:8001 cpbl-app
  ```
  然後開 `http://localhost:8080`
