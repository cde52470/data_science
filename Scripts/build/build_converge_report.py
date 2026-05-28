"""Build a clean, code-free HTML report from converge_analysis.ipynb.

Each section is rendered in three parts (same convention as the
data-analysis Results/notebook_executed.html report):
  1. pre  — 「如何解讀」：讀法指引 + 判讀方向（越大越好 / 越小越好 / 越接近 X 越好）
  2. 渲染後的輸出（圖 / 表 / print）
  3. post — 「本次結果與意義」：對照本次實際 output 寫成的觀察與解讀

The shell (CSS + sidebar JS) is reused verbatim from scripts/report_assets/,
so styling matches the sibling feature-engineering report. Section text is
authored against the executed notebook outputs; specific numbers quoted in the
post blocks reflect the 2023+2024 (SEASON_SCOPE) run that produced Results/.
"""
from __future__ import annotations
import nbformat, html, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
NB = ROOT / "Scripts" / "converge_analysis.ipynb"
OUT = ROOT / "Results" / "notebook_executed.html"
ASSETS = Path(__file__).resolve().parent / "report_assets"
CSS = (ASSETS / "report.css").read_text(encoding="utf-8")
SIDEBAR_JS = (ASSETS / "sidebar.js").read_text(encoding="utf-8")

nb = nbformat.read(str(NB), as_version=4)

# ── section detection ──────────────────────────────────────────────────────
# (signature substring on a markdown header line) -> section id.
# Last match within a markdown cell wins, so a stage-opening cell that bundles
# "## 階段 0" + "### 0.1 ..." maps to 0.1.
SIG = [
    ("0.1 套件", "0.1"), ("0.2 分析開關", "0.2"), ("0.3 下載並解析", "0.3"),
    ("0.4 特徵工程", "0.4"), ("0.5 節奏", "0.5"),
    ("1.1 主客輪廓", "1.1"), ("1.2 得分分布", "1.2"), ("由 EDA 浮現", "1.3"),
    ("2.1 主客比較", "2.1"), ("2.2 Pythagorean", "2.2"),
    ("3.1 情勢", "3.1"), ("3.2", "3.2"), ("3.3 先馳得點檢定", "3.3"), ("3.4 連勝", "3.4"),
    ("4a 解釋性模型", "4.1"), ("4a（補）", "4.2"), ("4a（續）", "4.3"),
    ("4b 預測性模型", "4.4"), ("4c Bradley", "4.5"), ("4d 主場優勢的成因", "4.6"),
    ("階段 5 — 非監督", "5.1"),
    ("階段 6 — 由分析收斂", "6.1"), ("6.2 收斂報告", "6.2"),
    ("階段 7 — 輸出", "7.1"),
]


def header_sid(md_src):
    sid = None
    for line in md_src.splitlines():
        s = line.strip()
        if not s.startswith("#"):
            continue
        for sig, k in SIG:
            if sig in s:
                sid = k
    return sid


def collect_outputs(cell):
    res = []
    for o in cell.get("outputs", []):
        t = o.get("output_type")
        if t == "stream":
            txt = o.get("text", "")
            txt = "".join(txt) if isinstance(txt, list) else txt
            res.append(("text", txt))
            continue
        d = o.get("data", {})
        if "image/png" in d:
            res.append(("png", d["image/png"]))
        if "text/html" in d:
            h = d["text/html"]
            res.append(("html", "".join(h) if isinstance(h, list) else h))
        elif "text/markdown" in d:
            pass  # notebook 的動態【解釋】，由本報告 curated post 取代
        elif "text/plain" in d:
            tp = d["text/plain"]
            tp = "".join(tp) if isinstance(tp, list) else tp
            if not tp.strip().startswith("<Figure"):
                res.append(("text", tp))
    return res


OUT_BY_SID, MD_BY_SID = {}, {}
_cur = None
for c in nb.cells:
    if c.cell_type == "markdown":
        sid = header_sid(c.source)
        if sid:
            _cur = sid
            body = "\n".join(l for l in c.source.splitlines() if not l.strip().startswith("#"))
            MD_BY_SID[sid] = body.strip()
    elif c.cell_type == "code" and _cur:
        OUT_BY_SID.setdefault(_cur, []).extend(collect_outputs(c))


# ── rendering helpers ──────────────────────────────────────────────────────
def md_inline(s):
    s = html.escape(s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"`([^`]+?)`", r"<code>\1</code>", s)
    return s


def md_to_html(text):
    if not text.strip():
        return ""
    out, in_ul = [], False

    def close_ul():
        nonlocal in_ul
        if in_ul:
            out.append("</ul>")
            in_ul = False

    for raw in text.splitlines():
        s = raw.strip()
        if not s:
            close_ul()
            continue
        if s.startswith("> "):
            close_ul()
            out.append(f'<blockquote style="border-left:3px solid #ccc;margin:.4rem 0;padding:.2rem .8rem;color:#555;">{md_inline(s[2:])}</blockquote>')
        elif s.startswith("- "):
            if not in_ul:
                out.append("<ul>")
                in_ul = True
            out.append(f"<li>{md_inline(s[2:])}</li>")
        else:
            close_ul()
            out.append(f"<p>{md_inline(s)}</p>")
    close_ul()
    return f'<div class="md-out">{"".join(out)}</div>'


def render_out(kind, data, max_lines=70):
    if kind == "png":
        return f'<img src="data:image/png;base64,{data}" alt="figure">'
    if kind == "html":
        return f'<div class="table-wrap">{data}</div>'
    lines = data.rstrip("\n").splitlines()
    if len(lines) > max_lines:
        data = "\n".join(lines[:max_lines]) + f"\n… (+{len(lines) - max_lines} 行)"
    else:
        data = "\n".join(lines)
    return f'<pre class="stream">{html.escape(data)}</pre>'


# ── per-section text: (title, pre_html, post_html) ─────────────────────────
S = {
"0.1": ("套件、中文字型與動態報表工具",
"<p><strong>讀法指引</strong>：這格只印環境字串，沒有圖表。重點檢查三件事——(a) 套件都成功匯入、(b) <strong>中文字型有載入</strong>（否則後面所有圖的中文會變成方框）、(c) 亂數種子釘死以利重現。</p>",
"<p><strong>本次結果</strong>：中文字型採用 <code>WenQuanYi Zen Hei</code>（直接以 <code>font_manager.addfont</code> 註冊，避開 matplotlib 字型快取過期問題），<code>RANDOM_STATE = 42</code> 固定。<br><strong>意義</strong>：後續所有圖的中文標籤可正常顯示；所有含隨機性的流程（bootstrap、置換檢定、KMeans 初始化）都可重現。</p>"),

"0.2": ("分析開關（gates）",
"<p><strong>讀法指引</strong>：三個開關控制整份分析的範圍與嚴謹度。<code>SEASON_SCOPE</code> 決定球季；<code>EXPORT_OUTPUTS</code> 是否把圖表落地到 <code>Results/</code>；<code>USE_TIME_LAG</code> 控制預測階段是否<strong>只用賽前資訊</strong>（leak-free）。</p>",
"<p><strong>本次結果</strong>：本報告以 <code>SEASON_SCOPE = 2023+2024</code>（兩季併池）、<code>EXPORT_OUTPUTS = True</code>（圖表寫入 Results/）、<code>USE_TIME_LAG = True</code>（預測階段嚴格無洩漏）跑出。<br><strong>意義</strong>：把球季與洩漏控制做成開關，換成單季（<code>2024</code>）或關閉時控只需改環境變數，結論的穩健性可被檢驗。</p>"),

"0.3": ("下載並解析 rebas 原始資料",
"<p><strong>讀法指引</strong>：印出下載與解析到的場次數與資料出處。重點在於資料是 notebook <strong>執行時直接下載原始 release zip</strong> 並自行解析，<strong>不依賴任何由結果反推的預製檔</strong>。</p>",
"<p><strong>本次結果</strong>：成功下載並解析 <strong>660 場</strong>原始比賽 JSON（球季 2023+2024），出處 <code>rebas-tw/rebas.tw-open-data</code>，授權 ODC-By 1.0（已標註）。<br><strong>意義</strong>：資料來源完全綁定官方 release tag，任何沒有本機檔案的環境重跑都能得到同一份原始資料——透明、可重現。</p>"),

"0.4": ("特徵工程：節奏／情勢 + WPA 情勢掌控",
"<p><strong>讀法指引</strong>：把原始 JSON 轉成兩個視角——game-level（每場一列、主隊視角）與 team-game（每隊一列、保留球隊身分），並自行衍生透明特徵。<code>HAS_WPA</code> 偵測逐打席 <code>WPA / homeWE / RE24</code> 是否存在：<strong>存在則以真實情勢指標為核心，缺漏則自動退回逐局推導特徵</strong>（絕不自建勝率矩陣）。</p>",
"<p><strong>本次結果</strong>：去和局後 <strong>647 場有效比賽 → 1294 列 team-game</strong>，涵蓋 6 隊、日期 2023-04-01 ~ 2024-10-11。<strong><code>HAS_WPA = True</code></strong>——故以真實 per-PA WPA / homeWE / RE24 作為節奏／情勢核心。主場勝率 <strong>52.9%</strong>。<br><strong>意義</strong>：team-game 粒度保留球隊身分（後續可加球隊固定／隨機效果避免 Simpson's paradox）；真實 WPA 讓「情勢掌控」不靠人工假設。</p>"),

"0.5": ("節奏／攻勢 類別標籤（為顯著檢定鋪路）",
"<p><strong>讀法指引</strong>：為階段 3 的檢定鋪路，把每場標上<strong>不含最終勝負</strong>的節奏標籤（先馳得點、六局領先態勢、後段得分占比）與攻勢標籤（攻勢強度 RE24、得分水準、情勢掌控 正WPA）。<br><strong>判讀方向</strong>：表中 <code>mean</code> = 該類別的勝率；某類別勝率<strong>越偏離 0.5</strong>，代表該節奏／攻勢維度<strong>越可能與勝負相關</strong>（正式檢定見 3.2）。</p>",
"<p><strong>本次結果</strong>：6 個不含結果的標籤建立完成，各類別勝率已呈明顯梯度——六局領先 <strong>0.892</strong> vs 六局落後 0.108；火力強勢(RE24) <strong>0.854</strong> vs 攻勢受阻 0.125；高得分 0.824 vs 低得分 0.146。<br><strong>意義</strong>：梯度明顯預示這些維度與勝負強相關。另建含結果的 <code>game_flow_label</code>（領先守成／後段逆轉…）<strong>僅供描述與非監督觀察、不進推論檢定</strong>，避免「用勝負定義的標籤去解釋勝負」的套套邏輯。</p>"),

"1.1": ("主客輪廓與每隊主場優勢",
"<p><strong>讀法指引</strong>：雙軸圖（柱＝平均得分、線＝勝率）＋各隊主／客勝率長條（依主場優勢排序）。<br><strong>判讀方向</strong>：勝率線<strong>高於 0.5</strong> 才算有優勢；若出現「<strong>勝率較高但得分柱沒較高</strong>」，就是「贏不靠得分量」的第一個線索。主場優勢 = 主場勝率 − 客場勝率，<strong>數值越大代表該隊主場優勢越強</strong>（可為負）。</p>",
"<p><strong>本次結果</strong>：主場勝率 <strong>52.9%</strong> 高於客場 47.1%，但主場平均得分 <strong>4.19 反而略低於</strong>客場 4.25——勝率與得分量並不同向。主場優勢<strong>因隊而異</strong>：台鋼雄鷹 <strong>+0.158</strong>（最強）到 中信兄弟 <strong>−0.056</strong>（唯一為負）。<br><strong>意義</strong>：直接支持後續 H3（主場優勢非由得分驅動）與 H5（每隊各有 population，不能混為單一母體）。</p>"),

"1.2": ("得分分布、勝差形狀與 Spearman 關聯",
"<p><strong>讀法指引</strong>：主／客得分 KDE、主場勝 vs 客場勝的 <code>|勝差|</code> KDE、team-game 數值特徵與 <code>win</code> 的 Spearman 相關熱圖。<br><strong>判讀方向</strong>：Spearman <code>|ρ|</code> <strong>越接近 1 越強相關</strong>（0 = 無關），正號同向、負號反向；KDE 兩條曲線<strong>分得越開</strong>代表該變數對勝負的區隔力越強。</p>",
"<p><strong>本次結果</strong>：每隊<strong>自身</strong>量與勝負正相關——<code>run_diff</code> ρ=<strong>0.87</strong>（最強）、<code>runs_scored</code> ρ=0.60、<code>hits</code> ρ=0.41（修正舊版只有「兩隊合計」的限制）。但主場勝平均勝差 <strong>3.37 &lt; 客場勝 3.90</strong>。<br><strong>意義</strong>：自身得分量確實與勝負相關；然而主隊偏向<strong>近身戰（小分差）取勝</strong>，再次呼應「主場優勢不是靠得分更多」。</p>"),

"1.3": ("由 EDA 浮現的待檢驗假設",
"<p><strong>讀法指引</strong>：本節沒有輸出運算，而是把上面 EDA <strong>觀察到</strong>的現象，整理成可被檢定的假設。刻意在「看過資料之後」才提出假設，避免一開始就預設立場。</p>",
"<p><strong>本次結果</strong>：浮現 H1（情勢結構）、H2（勝差大小）、H3（得分量 vs 主場優勢）、H4（節奏／情勢，核心）、H5（球隊異質性）共 5 條。<br><strong>意義</strong>：這 5 條假設將在階段 3 逐一以推論統計檢定，其中 <strong>H4（節奏／情勢）是整份研究的核心</strong>。</p>"),

"2.1": ("主客比較與每勝得分效率",
"<p><strong>讀法指引</strong>：主客均值差表 ＋ 勝場子集的平均得分。<br><strong>判讀方向</strong>：「主-客差」欄 <strong>&gt;0 代表主場較高、&lt;0 代表主場較低</strong>；每勝得分<strong>越小代表用越少分數就能贏（效率越高）</strong>。</p>",
"<p><strong>本次結果</strong>：多數量化差異都很小；最值得注意的是主隊<strong>每勝平均得分 5.82 &lt; 客隊 6.26</strong>——主隊用更少的分數就拿下勝場。先馳得點率主場反而 −0.100。<br><strong>意義</strong>：「主隊得分沒較多、每勝用分卻更少」是效率取勝的描述性線索，是否在統計上顯著留待 3.x 正式檢定。</p>"),

"2.2": ("Pythagorean / Pythagenpat 殘差",
"<p><strong>讀法指引</strong>：比較<strong>實際勝率</strong>與「得失分結構應有的<strong>期望勝率</strong>」。Pythagenpat 用動態指數 <code>((RS+RA)/G)^0.287</code>（比固定指數 1.83 更貼合本資料得分環境）。<br><strong>判讀方向</strong>：<strong>殘差 = 實際 − 期望</strong>，<strong>&gt;0 代表把相同得失分更有效率地轉成勝場（超越期望）</strong>，&lt;0 代表低於期望。</p>",
"<p><strong>本次結果</strong>：主場殘差 <strong>+0.035</strong>、客場 <strong>−0.035</strong>——主隊系統性<strong>超越</strong>其得失分對應的期望勝率。各隊亦異：樂天桃猿 +0.031（超越自身期望最多），統一獅 −0.037（雖實力最強，卻略低於自身期望）。<br><strong>意義</strong>：這是「贏在分配效率而非總量」最直接的量化證據——主隊把同樣的得失分，更常分配在「贏下來」的比賽上。</p>"),

"3.1": ("情勢 × 勝負（H1）與連續勝差（H2）",
"<p><strong>讀法指引</strong>：卡方 + Cramér's V（情勢 險勝／常態／大比分 × 主客勝）；不分箱的邏輯迴歸 <code>home_win ~ |分差|</code>；勝差 Mann-Whitney U（附 rank-biserial 與 bootstrap CI）。<br><strong>判讀方向</strong>：卡方 <strong>p&lt;0.05 代表不獨立（有關聯）</strong>；Cramér's V <strong>越接近 1 關聯越強</strong>（≈0.1 小 / 0.3 中 / 0.5 大）；OR<strong>&lt;1 代表勝差每大 1 分、主隊勝算越低</strong>；MWU 的 CI <strong>不含 0</strong> 才顯著。</p>",
"<p><strong>本次結果</strong>：情勢×勝負 卡方 <strong>p=0.009、V=0.121</strong>（顯著但效果量偏小）；<code>home_win~|分差|</code> <strong>OR=0.93（p=0.011）</strong>——分差越大主隊越吃虧。H2：主場勝勝差 3.37 &lt; 客場勝 3.90，MWU <strong>p=0.002</strong>、rank-biserial 0.139、CI [0.052, 0.226]（不含 0）。<br><strong>意義</strong>：H1、H2 都成立——主場優勢集中在<strong>小分差的勝負情勢</strong>，分差一拉大優勢就被稀釋。</p>"),

"3.2": ("★ 節奏／攻勢 標籤顯著檢定（H4 核心）",
"<p><strong>讀法指引</strong>：對 0.5 節 6 個<strong>不含結果</strong>的節奏／攻勢標籤，逐一做 <strong>卡方(標籤×win) + Cramér's V 效果量 + 各類別勝率 bootstrap 95% CI</strong>，整個標籤家族再套 <strong>Holm/BH 多重比較校正</strong>。<br><strong>判讀方向</strong>：Cramér's V <strong>越大關聯越強</strong>；勝率差距（最高−最低類別）<strong>越大代表該維度越能區隔勝負</strong>；圖中各類別誤差棒（CI）<strong>不重疊</strong>代表勝率差異穩健；<code>p_BH &lt; .05</code> 才算顯著。<strong>circularity 安全閥</strong>：含結果的 <code>game_flow_label</code> 不進此檢定。</p>",
"<p><strong>本次結果</strong>：<strong>6/6 標籤經 Holm/BH 校正後全部顯著</strong>。效果量排序（Cramér's V）：<strong>六局領先態勢 0.73（勝率差 78%，最強）</strong> &gt; 攻勢強度RE24 0.60 &gt; 得分水準 0.56 &gt; 先馳得點 0.41 &gt; 情勢掌控正WPA 0.32 &gt; 後段得分占比 0.18（最弱但仍顯著）。各類別 bootstrap CI 多不重疊。<br><strong>意義</strong>：這正面回答 H4——<strong>節奏／攻勢型態確實強烈區隔勝率</strong>，而且「<strong>過程是否領先（六局領先）」比「誰先得分」更具決定性</strong>，「掌控情勢」(WPA) 也比「後段得分占比」更關鍵。</p>"),

"3.3": ("先馳得點、球隊異質性（H5）與多重比較",
"<p><strong>讀法指引</strong>：先馳得點×勝負卡方；逐隊主／客勝率 + Wilcoxon 符號檢定（檢驗主場優勢是否<strong>跨隊一致</strong>，H5）；最後把主檢定家族一起做 Holm/BH。<br><strong>判讀方向</strong>：Wilcoxon <strong>p&lt;0.05 才能說「跨隊一致地有主場優勢」</strong>；多重校正後仍 <code>p_BH&lt;.05</code> 代表結論<strong>不是多檢定碰運氣</strong>而是穩健。</p>",
"<p><strong>本次結果</strong>：先馳得點者勝率 <strong>70.5%</strong>，卡方 p&lt;0.001。主場優勢隨隊 −0.056 ~ +0.158，<strong>Wilcoxon p=0.156</strong>（n=6 檢力有限，<strong>無法宣稱跨隊一致</strong>）。多重校正後 H1／H2／H4 與最強標籤<strong>全部 p_BH&lt;.05 穩健顯著</strong>。<br><strong>意義</strong>：先馳得點的優勢很大；但「主場優勢人人有份」這點受限於只有 6 隊而無法統計確立——與 1.1 的「因隊而異」一致。</p>"),

"3.4": ("連勝／手熱檢定（Miller–Sanjurjo 偏誤校正）",
"<p><strong>讀法指引</strong>：比較 <code>P(勝|前一場勝)</code> 與 <code>P(勝|前一場敗)</code>，並以<strong>置換檢定</strong>（打散每隊勝負序列重算）建立虛無分布。<br><strong>判讀方向</strong>：兩者之差<strong>須明顯 &gt;0</strong> 才支持「手熱」；置換虛無均值本身就量化並內含 <strong>Miller–Sanjurjo 有限樣本偏誤</strong>；雙尾 <strong>p 越小越顯著</strong>，<strong>p ≥ 0.05 表示無法拒絕「沒有手熱」</strong>。</p>",
"<p><strong>本次結果</strong>：P(勝|前勝)=0.495、P(勝|前敗)=0.504，差 <strong>−0.009（方向甚至相反）</strong>，置換 <strong>p=0.623</strong>——<strong>未見顯著手熱效應</strong>。置換虛無均值 +0.0045 顯示 MS 偏誤很小但確實存在，已被置換檢定內含校正。<br><strong>意義</strong>：「球隊最近連勝、下一場更會贏」在本資料<strong>不成立</strong>；單場勝負更像獨立事件，呼應後面 4.4「賽前難預測」。</p>"),

"4.1": ("解釋性模型（球隊固定效果 + cluster-robust）",
"<p><strong>讀法指引</strong>：邏輯迴歸 <code>win ~ 得分 + is_home + 節奏特徵 + C(team)</code>，cluster-robust 標準誤。<br><strong>判讀方向</strong>：係數 <strong>&gt;0 增加勝算、&lt;0 降低</strong>；<code>OR = exp(係數)</code>，<strong>OR&gt;1 為正向、越大效果越強</strong>；加入 <code>C(team)</code> 球隊固定效果前後，<code>is_home</code> 係數<strong>越穩定</strong>，越能說明主場是「<strong>隊內</strong>真實效應」而非球隊實力混淆。</p>",
"<p><strong>本次結果</strong>：控制得分、節奏與球隊後，<code>is_home</code> 的 OR <strong>pooled 2.04 → 加 C(team) 2.09（p=0.006），幾乎不變</strong>。節奏項中 <strong><code>led_after_6</code>（係數 2.83）、<code>scored_first</code>（0.83）最大，得分量 <code>runs_scored</code>（0.53）反而較小</strong>。<br><strong>意義</strong>：主場是隊內真實效應（不是強隊剛好主場多）；而且「<strong>過程領先</strong>」對勝負的邊際貢獻大於「<strong>純得分量</strong>」——再次指向節奏／情勢。</p>"),

"4.2": ("隨機效果 + 情勢掌控（WPA）模型",
"<p><strong>讀法指引</strong>：(1) 混合效果模型（team 隨機截距）再次佐證主場；(2) 用 WPA／情勢特徵建模。<br><strong>判讀方向</strong>：後驗平均<strong>與固定效果同號、且 |值| 遠大於後驗 SD</strong> 代表估計穩健；OR&gt;1 正向；<code>we_volatility</code>（勝率期望波動）係數<strong>極端負</strong>，意思是<strong>勝率期望擺盪越大越不利</strong>（多為被逆轉的一方）。</p>",
"<p><strong>本次結果</strong>：混合效果 <code>is_home</code> 後驗平均 <strong>0.679（SD 0.137）</strong>，與固定效果一致——主場效應穩健。情勢模型：攻勢壓力 <code>bat_re24</code> <strong>OR=2.01</strong>、高槓桿 WPA <strong>OR=2.27（p&lt;0.001）</strong>、先馳得點 OR=5.23。<br><strong>意義</strong>：用真實 WPA／RE24 量到的「<strong>情勢掌控</strong>」與勝負顯著相關，且為正向——情勢不只是描述，是可建模的勝負驅動力。</p>"),

"4.3": ("樣本外 AUC 與 permutation importance",
"<p><strong>讀法指引</strong>：GroupKFold(5) 樣本外 AUC，比較「只用得分量」vs「加入主場＋節奏」；再用 permutation importance 看哪個特徵帶來增益。<br><strong>判讀方向</strong>：AUC <strong>越接近 1 越好</strong>（0.5＝隨機猜測）；permutation importance <strong>數值越大代表移除該特徵後 AUC 掉越多（越重要）</strong>。</p>",
"<p><strong>本次結果</strong>：只用得分量 AUC <strong>0.843</strong> → 加主場+節奏 <strong>0.960</strong>（節奏資訊帶來明顯增益）。permutation importance 由 <strong><code>led_after_6</code>（0.256）壓倒性主導</strong>，<code>runs_scored</code> 次之（0.053），<strong><code>is_home</code> 僅 0.003</strong>。<br><strong>意義</strong>：關鍵反差——<strong>統計顯著（4.1 的 is_home OR 2.09）≠ 預測增益大</strong>。主場是真實但<strong>邊際</strong>的效應；真正帶動同場可分性的是「過程領先」這個節奏變數。</p>"),

"4.4": ("預測性模型（leak-free 滯後特徵）",
"<p><strong>讀法指引</strong>：只用<strong>賽前可得</strong>資訊（先前勝率／淨分差／近 10 場得失分／休息天數／序列式 Elo 賽前勝率…）預測勝負，GroupKFold(game_id) 估 AUC，並與「同場洩漏」特徵對照。<br><strong>判讀方向</strong>：leak-free AUC <strong>越接近 1 預測力越強</strong>，<strong>≈0.5 代表幾乎不可預測</strong>；同場洩漏 AUC 高只反映「結果已部分發生」，不算真正預測。</p>",
"<p><strong>本次結果</strong>：<strong>賽前 leak-free AUC = 0.506（≈隨機 0.5）</strong>，同場洩漏 AUC = 0.960。賽前最有用的弱訊號是 <code>is_home</code>（標準化係數 0.25）與 <code>prior_run_diff</code>（0.22）。<br><strong>意義</strong>：這是全研究最重要的反差之一——<strong>主場優勢可以「解釋」，卻幾乎無法「預測」</strong>單場勝負。與 3.4「沒有手熱」一致：單場結果高度受臨場節奏左右，賽前資訊資訊量很低。</p>"),

"4.5": ("Bradley–Terry：實力 vs 主場",
"<p><strong>讀法指引</strong>：用成對比較模型同時估計<strong>球隊潛在實力</strong>與<strong>主場優勢（HFA）</strong>，把兩者拆開（設計矩陣 = 主隊指標 − 客隊指標 ＋ 一個主場項）。<br><strong>判讀方向</strong>：BT 實力(logit) <strong>越大代表球隊越強</strong>；HFA <strong>&gt;0 代表有主場優勢</strong>，但要 <strong>p&lt;0.05 才算統計顯著</strong>。</p>",
"<p><strong>本次結果</strong>：實力排序 <strong>統一獅 +0.17（最強）</strong> &gt; 中信 +0.16 &gt; 樂天 +0.09 &gt; 味全 +0.07 &gt; 富邦 −0.20 &gt; <strong>台鋼 −0.30（最弱）</strong>。<strong>HFA = +0.116 logit（p=0.143）→ 對等對戰主隊勝率 0.529</strong>，與 raw 主場勝率一致。<br><strong>意義</strong>：把實力與主場分開後，主場優勢<strong>真實但溫和</strong>（此處未達 0.05 顯著，反映球隊數少、樣本有限）——與「可解釋、難預測」的整體圖像吻合。</p>"),

"4.6": ("主場優勢的成因（球場層級）",
"<p><strong>讀法指引</strong>：嘗試拆解主場優勢來源。先檢查 rebas 原始欄位是否含 <code>attendance／umpire／天氣</code>；若沒有，就<strong>誠實標註並改以可得的「球場」層級</strong>（≥15 場）檢視。<br><strong>判讀方向</strong>：球場的主隊勝率<strong>越高代表該主場優勢越強</strong>，0.5 為無優勢基準。</p>",
"<p><strong>本次結果</strong>：rebas 原始資料<strong>不含觀眾／裁判／天氣</strong>欄位，故略過該拆解（標註而非編造）。球場層級：主隊勝率最高 <strong>臺南市立棒球場 63.4%</strong>、最低 <strong>新北市立新莊棒球場 43.8%（竟低於 0.5）</strong>。<br><strong>意義</strong>：主場優勢<strong>連在球場之間都不一致</strong>——有些主場是堡壘、有些反成負擔，呼應 H5 的異質性，也說明「平均主場優勢」掩蓋了不少結構差異。</p>"),

"5.1": ("非監督：哪些節奏／情勢型態驅動勝負",
"<p><strong>讀法指引</strong>：<strong>不以勝負為標籤</strong>，純由節奏／情勢／攻勢特徵的結構分群，再回頭對照勝率。流程：標準化 → PCA（scree／2D 散點以 win 上色／loadings）→ KMeans（k 由 silhouette 選）→ 各群剖面（平均特徵＋勝率＋主客比例）→ 與規則標籤交叉表。<br><strong>判讀方向</strong>：silhouette <strong>越大分群越乾淨</strong>（取最高的 k）；若「資料自己分出的群」同時對應「規則節奏標籤」又對應「勝率高低」，代表<strong>節奏／情勢就是資料的主要結構軸</strong>。</p>",
"<p><strong>本次結果</strong>：PCA 需 <strong>10 個主成分</strong>才達 90% 變異；silhouette 在 <strong>k=2 最高（0.208）</strong>。兩群勝率天差地別：<strong>群#0 勝率 84%</strong>（得分 6.85、淨分差 +3.2、六局領先 +0.59、攻勢RE24 +2.15）vs <strong>群#1 勝率 22%</strong>（淨分差 −2.69、六局領先 −0.50）。<strong>兩群主場比例皆 ≈0.5</strong>。交叉表：群#0 多為「先馳壓制型／後段逆轉型」，群#1 多為「一般拉鋸型」。<br><strong>意義</strong>：資料自發分出的兩個原型，<strong>分界不是主客、而是「節奏／情勢掌控」</strong>；它與規則標籤、與勝率三者一致——這是「節奏／情勢是勝負主軸」最強的非監督佐證。</p>"),

"6.1": ("收斂關鍵數據",
"<p><strong>讀法指引</strong>：把支撐結論的核心數字集中印出，<strong>全部取自前面已算出的變數，不重算、不新增主張</strong>。可當作整份分析的一頁速查。</p>",
"<p><strong>本次結果</strong>：主場勝率 52.9%（得分未較高）、Pythagenpat 主場殘差 +0.035、節奏／攻勢標籤 <strong>6/6 顯著</strong>（最強 六局領先 V=0.73）、解釋 <code>is_home</code> OR 2.09、Bradley-Terry HFA +0.116、手熱 p=0.623、預測 AUC <strong>0.506 vs 0.960</strong>。<br><strong>意義</strong>：所有數字指向<strong>同一個故事</strong>——得分量不足以解釋主場優勢，節奏／情勢補上關鍵，而且這套機制可解釋卻難以賽前預測（見 6.2）。</p>"),

"6.2": ("收斂報告（敘事）",
"<p><strong>讀法指引</strong>：下列為固定的<strong>方法論結論框架</strong>；所有<strong>數值</strong>請見上方各 cell 動態生成的【解釋】與 6.1 彙整（換資料時數字自動更新，框架不變）。</p>",
"<p><strong>研究問題的回答</strong>：單看「得分量」<strong>不足以</strong>解釋主場優勢（主場得分 4.19 未高於客場 4.25，勝率卻較高、Pythagenpat 正殘差）。關鍵在<strong>節奏／情勢</strong>：6/6 個節奏／攻勢標籤經多重校正後仍顯著（最強為六局領先態勢），控制得分與球隊後 <code>is_home</code> 仍穩健、且為隊內效應，Bradley–Terry 亦確認主場真實但溫和。然而<strong>賽前可預測性極低</strong>（leak-free AUC 0.506）——<strong>主場優勢「可解釋、難預測」</strong>。<br><strong>侷限</strong>：原始資料無觀眾／裁判，成因僅能看球場層級；單一聯盟、球隊數少（H5 檢力受限）；跨年為 pooled（台鋼 2024 才加入，已逐季重置滾動特徵並控 season）。</p>"),

"7.1": ("輸出（資料表與圖落地）",
"<p><strong>讀法指引</strong>：列出所有輸出物件；<code>EXPORT_OUTPUTS=True</code> 時依 <code>stage</code> 寫到 <code>Results/</code> 各子資料夾。</p>",
"<p><strong>本次結果</strong>：共登錄 <strong>27 個輸出（9 圖 / 18 表）</strong>，已寫入 <code>Results/stage1_eda … stage5_unsupervised</code>。<br><strong>意義</strong>：本 HTML 報告即由這些 figure／table 組成；下游若要重用，直接讀 <code>Results/</code> 對應 CSV／PNG 即可。</p>"),

"R.1": ("References / 參考來源",
"",
"""<p>本研究的方法與報告風格受到下列材料啟發；技術細節（演算法、效果量、多重比較）皆從通用統計與棒球分析文獻取得，實作為原創。</p>

<h4 class='sub-heading'>A. 同源 repo（cde52470/data_science）</h4>
<ul>
  <li><strong><code>cde52470/data_science@data-analysis</code></strong>（本 repo 落地 cde52470 後置於 <code>legacy/version2/</code>）
    <ul>
      <li><code>Scripts/cpbl_unsupervised_feature_discovery.ipynb</code> — stage 結構、K 共識六方法投票、bootstrap-Jaccard、PCA → 分群 → 解讀 的流程樣板。</li>
      <li><code>Scripts/build/build_report_html.py</code> + <code>inject_explanations.py</code> — 本 HTML 報告的「三段式（讀法指引 → output → 本次結果與意義）」模板與 sidebar TOC 直接沿用；CSS／JS 同款（<code>Scripts/build/report_assets/report.css</code>、<code>sidebar.js</code>）。</li>
      <li><code>docs/knowledge_base/</code> — 10 份 KB markdown（PCA-SVD、unsupervised、measurement、SHAP/LIME、featureReduction…），是本研究演算法選擇的學理依據。</li>
    </ul>
  </li>
  <li><strong><code>cde52470/data_science@analyze_wang</code></strong> — 王學長監督式分析（logistic / RF / XGBoost + SHAP）；本研究的 <code>scored_first</code>、<code>led_after_6</code>、<code>late_runs</code>、<code>run_per_hit</code>、<code>whip_like</code> 等特徵定義與其 R 程式對齊。</li>
</ul>

<h4 class='sub-heading'>B. 公開資料與授權</h4>
<ul>
  <li><strong>rebas-tw open data</strong> — <a href='https://github.com/rebas-tw/rebas.tw-open-data'>github.com/rebas-tw/rebas.tw-open-data</a>，CPBL 官方資料社群整理版，授權 <strong>ODC-By 1.0</strong>。Notebook 階段 0.3 直接從 GitHub releases 下載原始 zip（2023.0／2023.1／2024）。</li>
</ul>

<h4 class='sub-heading'>C. 方法論</h4>
<ul>
  <li><strong>Pythagenpat 動態指數</strong> — Davenport / Patriot；指數 = <code>((RS+RA)/G)^0.287</code>。</li>
  <li><strong>Bradley–Terry 模型</strong> — 以邏輯迴歸實作，主場項分離 HFA。</li>
  <li><strong>Miller–Sanjurjo 偏誤</strong> — Miller &amp; Sanjurjo (2018, <em>Econometrica</em> 86(6): 2019–2047)；本研究以置換檢定內含校正。</li>
  <li><strong>Holm / Benjamini–Hochberg</strong> — 多重比較校正（statsmodels 實作）。</li>
  <li><strong>Cramér's V</strong> — 卡方效果量；circularity 安全閥概念見 0.5 / 3.2 節。</li>
  <li><strong>per-PA WPA / homeWE / RE24</strong> — rebas schema 內建欄位；用於情勢掌控、攻勢壓力指標。</li>
</ul>

<h4 class='sub-heading'>D. 開發過程</h4>
<p>本 repo 與 <code>jiangjiangian/data_science_final_project@converge_analysis</code> 分支同步開發；HTML 報告由 <code>Scripts/build/build_converge_report.py</code> 自動產生。</p>"""),
}

STAGES = [
    ("0", "階段 0 — 環境、開關與資料載入", ["0.1", "0.2", "0.3", "0.4", "0.5"]),
    ("1", "階段 1 — EDA（不預設立場）", ["1.1", "1.2", "1.3"]),
    ("2", "階段 2 — 描述統計（Pythagenpat）", ["2.1", "2.2"]),
    ("3", "階段 3 — 推論統計（H1–H5）", ["3.1", "3.2", "3.3", "3.4"]),
    ("4", "階段 4 — 建模（解釋 vs 預測）", ["4.1", "4.2", "4.3", "4.4", "4.5", "4.6"]),
    ("5", "階段 5 — 非監督觀察", ["5.1"]),
    ("6", "階段 6 — 收斂結論", ["6.1", "6.2"]),
    ("7", "階段 7 — 輸出", ["7.1"]),
    ("R", "附錄 — 參考來源 (References)", ["R.1"]),
]

STAGE_SUMMARIES = {
    "0": ["環境可重現（中文字型載入成功、RANDOM_STATE=42 釘死）。",
          "notebook 內直接下載 660 場 rebas 原始資料（ODC-By），不依賴預製檔。",
          "去和局後 647 場 → 1294 列 team-game，HAS_WPA=True（用真實 per-PA WPA/RE24）。",
          "建立 6 個『不含結果』的節奏／攻勢標籤，為階段 3 檢定鋪路。"],
    "1": ["主場勝率 52.9% 但主場得分 4.19 未高於客場 4.25——勝率與得分量不同向。",
          "主場優勢因隊而異（台鋼 +0.158 ~ 中信 −0.056）。",
          "自身得分量與勝負正相關（run_diff ρ=0.87）；主場偏向小分差取勝。",
          "由觀察浮現 H1–H5，H4（節奏／情勢）為核心。"],
    "2": ["量化主客差多半很小，但主隊每勝得分較少（5.82 < 6.26）。",
          "Pythagenpat 主場殘差 +0.035——把相同得失分更有效率轉成勝場。"],
    "3": ["H1 情勢×勝負顯著（p=0.009）；H2 主場勝勝差較小（MWU p=0.002）。",
          "★ 6/6 節奏／攻勢標籤經 Holm/BH 後全顯著，最強為六局領先態勢（V=0.73、勝率差 78%）。",
          "先馳得點者勝率 70.5%；主場優勢跨隊一致性檢力不足（Wilcoxon p=0.156）。",
          "手熱效應不存在（差 −0.009、置換 p=0.623），且已內含 Miller–Sanjurjo 校正。"],
    "4": ["控制球隊後 is_home OR=2.09（p=0.006）穩健——隊內真實效應。",
          "情勢模型 WPA/RE24 顯著（高槓桿 WPA OR=2.27）。",
          "解釋 AUC 0.843→0.960，由 led_after_6 主導；is_home 邊際貢獻極小（顯著 ≠ 預測增益大）。",
          "leak-free 賽前預測 AUC 僅 0.506≈隨機；Bradley–Terry HFA +0.116 溫和。",
          "主場成因無觀眾/裁判資料，球場層級看：臺南最高 63.4%、新莊最低 43.8%。"],
    "5": ["PCA 需 10 個主成分達 90% 變異；KMeans 取 k=2（silhouette 最高）。",
          "兩原型勝率 84% vs 22%，但主場比例皆≈0.5——分群是『節奏／情勢』而非主客。",
          "資料驅動分群與規則節奏標籤一致，佐證節奏／情勢是勝負主軸。"],
    "6": ["得分『量』不足以解釋主場優勢，節奏／情勢補上關鍵。",
          "控制後 is_home 穩健、Bradley–Terry 確認主場真實但溫和。",
          "賽前 leak-free 預測力≈隨機——主場優勢『可解釋、難預測』。"],
    "7": ["共 27 個輸出（9 圖 / 18 表）寫入 Results/，本報告即由其組成。"],
    "R": ["列出本研究借用／參考的 cde52470/data-analysis 材料（notebook、build template、KB markdown）。",
          "公開資料授權 ODC-By 1.0；方法論文獻（Pythagenpat、Bradley–Terry、Miller–Sanjurjo、Holm/BH、Cramér's V）。",
          "技術實作為原創；風格與 stage 結構受同學的非監督式特徵發現專案影響。"],
}

MERMAID = """
flowchart TD
    A0[階段0 環境+下載 rebas 原始資料<br/>647 場 → 1294 team-game · HAS_WPA] --> A1
    A1[階段1 EDA<br/>主場勝率↑ 但得分未↑ · 主場優勢因隊而異] --> A1h{假設 H1–H5 浮現}
    A1h --> A2[階段2 描述<br/>Pythagenpat 主場殘差 +0.035]
    A2 --> A3[階段3 推論<br/>★ 6/6 節奏攻勢標籤顯著 · 手熱 p=0.62 不存在]
    A3 --> A4[階段4 建模<br/>is_home OR 2.09 · 解釋AUC 0.96 vs 預測 0.51 · BT HFA 0.12]
    A4 --> A5[階段5 非監督<br/>KMeans 勝率 84% vs 22% · 分界是節奏非主客]
    A5 --> A6[階段6 收斂<br/>得分量不足→節奏情勢 · 可解釋難預測]
    A6 --> A7[階段7 輸出 27 artifacts]
    classDef setup fill:#e3f2fd,stroke:#1976d2
    classDef data fill:#fff8e1,stroke:#f57c00
    classDef gate fill:#fce4ec,stroke:#c2185b
    classDef analyze fill:#e8f5e9,stroke:#388e3c
    classDef result fill:#f3e5f5,stroke:#7b1fa2
    class A0 setup
    class A1,A2 data
    class A1h gate
    class A3,A4,A5 analyze
    class A6,A7 result
"""


def render_section(sid):
    if sid not in S:
        return ""
    title, pre, post = S[sid]
    outs = OUT_BY_SID.get(sid, [])
    output_html = "\n".join(render_out(k, d) for k, d in outs) if outs else md_to_html(MD_BY_SID.get(sid, ""))
    parts = [f'<div class="section" id="sec-{sid}">',
             f'<h3 class="sec-head">{sid} — {html.escape(title)}</h3>']
    if pre:
        parts.append(f'<div class="pre-explanation"><div class="badge">如何解讀</div>{pre}</div>')
    if output_html:
        parts.append(f'<div class="outputs">{output_html}</div>')
    if post:
        parts.append(f'<div class="post-explanation"><div class="badge">本次結果與意義</div>{post}</div>')
    parts.append('</div>')
    return '\n'.join(parts)


def render_stage(num, title, sids):
    parts = [f'<section id="stage-{num}" class="tab-page stage">', f'<h2>{html.escape(title)}</h2>']
    summ = STAGE_SUMMARIES.get(num, [])
    if summ:
        parts.append('<div class="stage-summary"><strong>本 stage 小結：</strong><ul>')
        parts += [f'<li>{md_inline(b)}</li>' for b in summ]
        parts.append('</ul></div>')
    parts += [render_section(sid) for sid in sids]
    parts.append('</section>')
    return '\n'.join(parts)


def render_sidebar():
    parts = ['<aside class="sidebar">', '<h3 class="sb-title">CPBL 收斂分析</h3>',
             '<div class="pin-top"><a href="#home" data-target="home">首頁 · 流程圖 · 摘要</a></div>',
             '<ul class="nav-top">']
    for num, title, sids in STAGES:
        short = title.split("— ", 1)[1] if "— " in title else title
        parts.append('<li>')
        parts.append(f'<details><summary><a href="#stage-{num}" data-target="stage-{num}">階段 {num} · {html.escape(short)}</a></summary>')
        parts.append('<ul class="subsections">')
        for sid in sids:
            if sid in S:
                parts.append(f'<li><a href="#sec-{sid}" data-target="stage-{num}" data-scroll="sec-{sid}">{sid} · {html.escape(S[sid][0])}</a></li>')
        parts.append('</ul></details></li>')
    parts.append('</ul></aside>')
    return '\n'.join(parts)


def build_html():
    sidebar = render_sidebar()
    body_stages = "\n".join(render_stage(num, title, sids) for num, title, sids in STAGES)
    home = f"""
<section class="tab-page active" id="home">
  <h1>CPBL 主客場勝負分析：節奏／情勢，而非「得分量」</h1>
  <p class="subtitle">team-game 收斂式研究 · 2023+2024 · 主 notebook：<code>converge_analysis.ipynb</code></p>

  <div class="convention-note">
    <p style="margin:0 0 0.6rem 0;"><strong>本報告每個小節採三段式呈現：</strong></p>
    <div style="margin-left:0.5rem;">
      <div style="margin:0.35rem 0;"><span class="badge-inline pre-badge">如何解讀</span></div>
      <div style="margin-left:1.5rem;line-height:1.8;">→ 輸出之前的讀法指引 + 越大越好 / 越小越好 / 越接近 X 越好 的判讀方向</div>
      <div style="margin-left:1.5rem;line-height:1.8;">→ 渲染後的圖表 / 表格 / print 輸出</div>
      <div style="margin:0.35rem 0;"><span class="badge-inline post-badge">本次結果與意義</span></div>
      <div style="margin-left:1.5rem;line-height:1.8;">→ 對照本次實際 output 寫成的觀察與解讀</div>
    </div>
    <p style="margin:0.6rem 0 0 0;">左側可點選任一階段或子節（如 3.2）直接跳到對應 tab。</p>
  </div>

  <h2>Pipeline 流程圖</h2>
  <div class="mermaid-wrap"><pre class="mermaid">{MERMAID}</pre></div>

  <h2>研究問題與一頁摘要</h2>
  <div class="stage-summary">
  <p><strong>研究問題</strong>：單看「得分多寡」是否足以解釋中華職棒的主客勝負？若不夠，是「節奏／情勢」補上了什麼？</p>
  <ol>
  <li><strong>得分量不足以解釋主場優勢</strong>：主場勝率 52.9% 卻得分更低（4.19 vs 4.25），Pythagenpat 主場殘差 +0.035——贏在效率而非總量。</li>
  <li><strong>節奏／情勢是主軸</strong>：6/6 節奏／攻勢標籤經多重校正後全顯著，最強為「六局領先態勢」（Cramér's V=0.73）；KMeans 非監督原型（勝率 84% vs 22%、主場比皆≈0.5）獨立佐證。</li>
  <li><strong>可解釋、難預測</strong>：控制球隊後 is_home OR 2.09 仍穩健（隊內效應），但賽前 leak-free 預測 AUC 僅 0.506≈隨機；手熱效應不存在（p=0.623）。</li>
  <li><strong>方法強化</strong>：真實 per-PA WPA/RE24、Pythagenpat 動態指數、Miller–Sanjurjo 偏誤校正、Bradley–Terry 分離實力/主場、Holm/BH 多重比較、circularity 安全閥。</li>
  </ol>
  </div>

  <h2>收斂關鍵數據（快速一覽）</h2>
  <table class="result-table">
  <tr><th>項目</th><th>數值</th></tr>
  <tr><td>Team-game rows</td><td>1294（647 場 · 2023+2024 去和局）</td></tr>
  <tr><td>主場勝率</td><td>52.9% vs 客場 47.1%（主場得分 4.19 <em>低於</em> 客場 4.25）</td></tr>
  <tr><td>Pythagenpat 主場殘差</td><td>+0.035（贏在效率）</td></tr>
  <tr><td><strong>★ 節奏／攻勢標籤顯著數</strong></td><td><strong>6 / 6</strong>（最強 六局領先態勢 Cramér's V=0.73、勝率差 78%）</td></tr>
  <tr><td>先馳得點勝率</td><td>70.5%</td></tr>
  <tr><td>解釋 is_home OR（加 C(team)）</td><td>2.09（p=0.006，隊內效應）</td></tr>
  <tr><td>Bradley–Terry HFA</td><td>+0.116 logit → 對等主隊勝率 0.529</td></tr>
  <tr><td>手熱效應</td><td>差 −0.009、置換 p=0.623（<strong>不存在</strong>）</td></tr>
  <tr><td><strong>預測 AUC</strong></td><td><strong>leak-free 0.506 ≈ 隨機</strong> / 同場洩漏 0.960</td></tr>
  <tr><td>非監督 KMeans（k=2）</td><td>群#0 勝率 84% vs 群#1 22%（主場比皆≈0.5）</td></tr>
  </table>

  <footer>
  本報告由 <code>scripts/build_converge_report.py</code> 從 <code>converge_analysis.ipynb</code> 自動生成；
  資料來源 <a href="https://github.com/rebas-tw/rebas.tw-open-data">rebas.tw open data</a>，授權 ODC-By 1.0。
  </footer>
</section>"""

    return f"""<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CPBL 主客場勝負分析（節奏／情勢）— 結果報告</title>
<style>{CSS}</style>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>
document.addEventListener("DOMContentLoaded", () => {{
  if (window.mermaid) mermaid.initialize({{ startOnLoad: true, theme: "default", flowchart: {{ useMaxWidth: true }} }});
}});
</script>
</head>
<body>
<div class="app">
{sidebar}
<main class="content">
{home}
{body_stages}
</main>
</div>
{SIDEBAR_JS}
</body>
</html>
"""


if __name__ == "__main__":
    doc = build_html()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(doc, encoding="utf-8")
    covered = [sid for _, _, sids in STAGES for sid in sids if sid in S]
    missing_out = [sid for sid in covered if sid not in OUT_BY_SID and sid not in ("1.3", "6.2")]
    print(f"Wrote {OUT}: {len(doc):,} chars / {OUT.stat().st_size/1024:.0f} KB")
    print(f"Sections covered: {len(covered)} | sections with no captured outputs (expected only 1.3/6.2): {missing_out}")
