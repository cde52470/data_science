# CPBL 2024 Context Labeling Analysis

這個資料夾是給組員看的整理版說明文件，重點是說明目前分析的定位、流程、資料產出與主要發現。

## 建議閱讀順序

1. [`project_overview.md`](project_overview.md)  
   先看這份，了解整體目標與目前做到哪裡。

2. [`analysis_workflow_and_findings.md`](analysis_workflow_and_findings.md)  
   說明完整流程、EDA、模型比較、SHAP、特徵重要性共識與模型標記結果。

3. [`feature_dictionary.md`](feature_dictionary.md)  
   說明目前主要欄位的來源、計算方式與意義。

4. [`context_labeling_model_design.md`](context_labeling_model_design.md)  
   說明目前模型如何作為未來打席預測模型的場景資訊層。

## 目前核心定位

目前不是在做最終打席預測模型，而是在建立：

```text
game-context labeling model
```

它的功能是：

```text
原始比賽資料
→ 特徵工程
→ 語意化欄位
→ 模型輔助標記
→ 轉換成未來模型可使用的場景資訊
```

## 目前最重要結論

2024 年 CPBL 主場勝率略高於客場，但平均分差沒有同步擴大。多模型與 SHAP 分析顯示，主場本身不是最核心的直接特徵；主場影響更可能透過攻守效率、投手壓制與比賽節奏間接呈現。
