from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from pathlib import Path
from stats import (get_win_rate, get_result_breakdown,
                   get_fisher_result, get_scored_first_fisher, df)
from model import clf, pca_df, model_info, predict_matchup

app = FastAPI()

teams = sorted(df["team"].unique().tolist())

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>CPBL 分析系統</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: "Noto Sans TC", "Microsoft JhengHei", sans-serif; background: #f0f4f8; color: #222; }

    header { background: #1a237e; color: white; padding: 16px 32px; display: flex; align-items: center; gap: 16px; }
    header h1 { font-size: 1.4rem; font-weight: 700; }
    nav { display: flex; margin-left: auto; }
    nav button {
      padding: 8px 24px; border: none; cursor: pointer;
      font-size: 0.95rem; font-weight: 600;
      background: transparent; color: rgba(255,255,255,0.7);
      border-bottom: 3px solid transparent; transition: all 0.2s;
    }
    nav button.active { color: white; border-bottom: 3px solid #64b5f6; }
    nav button:hover { color: white; }

    main { max-width: 960px; margin: 40px auto; padding: 0 16px; display: flex; flex-direction: column; gap: 20px; }

    .page { display: none; flex-direction: column; gap: 20px; }
    .page.active { display: flex; }

    .card {
      background: white; border-radius: 12px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08); padding: 28px 32px;
    }
    .card h2 {
      font-size: 1.1rem; color: #1a237e; margin-bottom: 20px;
      border-left: 4px solid #1a237e; padding-left: 12px;
    }

    /* form */
    .form-row { display: flex; gap: 16px; align-items: flex-end; flex-wrap: wrap; }
    .form-group { display: flex; flex-direction: column; gap: 6px; flex: 1; min-width: 160px; }
    label { font-size: 0.82rem; font-weight: 600; color: #555; }
    select {
      padding: 9px 12px; border: 1.5px solid #d0d7de; border-radius: 8px;
      font-size: 0.92rem; background: white; transition: border 0.2s;
    }
    select:focus { outline: none; border-color: #1a237e; }
    .vs-label { font-size: 1rem; font-weight: 700; color: #bdbdbd; align-self: flex-end; padding-bottom: 10px; }
    .btn-query {
      padding: 9px 28px; background: #1a237e; color: white;
      border: none; border-radius: 8px; font-size: 0.95rem; font-weight: 600;
      cursor: pointer; transition: background 0.2s; align-self: flex-end;
    }
    .btn-query:hover { background: #283593; }

    /* win rate card */
    .stat-row { display: flex; gap: 16px; flex-wrap: wrap; }
    .stat-card {
      min-width: 140px; max-width: 200px; background: #f5f7ff;
      border-radius: 10px; padding: 14px 16px; text-align: center;
      border: 1.5px solid #c5cae9;
    }
    .stat-card .s-label { font-size: 0.75rem; color: #555; margin-bottom: 6px; }
    .stat-card .s-value { font-size: 1.5rem; font-weight: 700; color: #2e7d32; }
    .stat-card .s-sub { font-size: 0.7rem; color: #888; margin-top: 4px; }

    /* chart */
    .chart-wrap { position: relative; height: 260px; }

    /* fisher */
    .fisher-section { display: flex; gap: 24px; flex-wrap: wrap; align-items: flex-start; }
    .contingency { border-collapse: collapse; font-size: 0.85rem; }
    .contingency th, .contingency td {
      border: 1px solid #c5cae9; padding: 7px 16px; text-align: center;
    }
    .contingency th { background: #e8eaf6; font-weight: 600; }
    .contingency td.win-cell { color: #2e7d32; font-weight: 600; }
    .contingency td.loss-cell { color: #c62828; font-weight: 600; }
    .fisher-result {
      background: #f5f7ff; border: 1.5px solid #c5cae9;
      border-radius: 10px; padding: 16px 20px;
      display: flex; flex-direction: column; gap: 8px; min-width: 200px;
    }
    .fisher-result .f-row { display: flex; justify-content: space-between; gap: 24px; font-size: 0.85rem; }
    .fisher-result .f-label { color: #666; }
    .fisher-result .f-val { font-weight: 700; color: #1a237e; }
    .conclusion-badge {
      margin-top: 4px; padding: 6px 12px; border-radius: 20px;
      font-size: 0.82rem; font-weight: 700; text-align: center;
    }
    .conclusion-badge.sig { background: #e8f5e9; color: #2e7d32; }
    .conclusion-badge.nosig { background: #fafafa; color: #757575; border: 1px solid #e0e0e0; }

    .error-msg { color: #c62828; background: #ffebee; padding: 10px 14px; border-radius: 8px; display: none; font-size: 0.88rem; }
    .error-msg.show { display: block; }
    .hidden { display: none; }

    /* inning stats */
    .inning-cards { display: flex; gap: 14px; flex-wrap: wrap; }
    .inning-card {
      flex: 1; min-width: 140px; border-radius: 10px; padding: 14px 16px;
      border: 1.5px solid #c5cae9; background: #f5f7ff; transition: all 0.2s;
    }
    .inning-card.active { border-color: #1a237e; background: #e8eaf6; }
    .inning-card .i-phase { font-size: 0.8rem; font-weight: 700; color: #1a237e; margin-bottom: 10px; }
    .inning-row { display: flex; justify-content: space-between; align-items: center;
                  font-size: 0.8rem; margin-bottom: 6px; }
    .inning-row .i-tag { color: #555; }
    .inning-row .i-val { font-weight: 700; }
    .i-val.win  { color: #2e7d32; }
    .i-val.lose { color: #c62828; }

    /* predict page */
    .coming-soon { text-align: center; padding: 60px 0; color: #9e9e9e; }
    .coming-soon .icon { font-size: 3rem; margin-bottom: 12px; }

    .predict-vs { display: flex; align-items: stretch; gap: 0; margin-top: 28px; }
    .team-block {
      flex: 1; display: flex; flex-direction: column; align-items: center;
      gap: 10px; padding: 24px 20px; background: #f5f7ff;
      border: 1.5px solid #c5cae9; border-radius: 12px;
    }
    .team-block.winner { background: #e8f5e9; border-color: #a5d6a7; }
    .team-block .t-name { font-size: 1.15rem; font-weight: 700; color: #1a237e; }
    .team-block .venue-tag {
      font-size: 0.72rem; font-weight: 600; padding: 2px 10px;
      border-radius: 20px;
    }
    .home-tag  { background: #e3f2fd; color: #1565c0; }
    .away-tag  { background: #fce4ec; color: #c62828; }
    .prob-pct  { font-size: 2rem; font-weight: 700; color: #1a237e; }
    .prob-bar-bg {
      width: 100%; height: 10px; background: #e0e0e0;
      border-radius: 6px; overflow: hidden;
    }
    .prob-bar  { height: 100%; border-radius: 6px; transition: width 0.5s ease; }
    .home-bar  { background: #1565c0; }
    .away-bar  { background: #c62828; }
    .winner-crown { font-size: 1.4rem; }

    .vs-divider {
      display: flex; align-items: center; justify-content: center;
      padding: 0 20px; font-size: 1.1rem; font-weight: 700; color: #bdbdbd;
    }

    /* 預測結果：精簡橫排 */
    .winner-row {
      display: flex; align-items: center; gap: 14px;
      padding: 14px 0 10px; flex-wrap: wrap;
    }
    .winner-row .wr-label { font-size: 0.78rem; color: #888; white-space: nowrap; }
    .winner-row .wr-name  { font-size: 1.25rem; font-weight: 700; color: #1a237e; }
    .winner-row .wr-prob  { font-size: 1.1rem; font-weight: 700; color: #2e7d32; }
    .w-tag {
      display: inline-block; padding: 2px 12px; border-radius: 20px;
      font-size: 0.75rem; font-weight: 600;
    }
    .w-tag.home-tag { background: #e3f2fd; color: #1565c0; }
    .w-tag.away-tag { background: #fce4ec; color: #c62828; }
    .pred-note { font-size: 0.72rem; color: #aaa; margin-top: 6px; }

    /* decision plot */
    .plot-loading { color: #aaa; font-size: 0.88rem; padding: 40px 0; text-align: center; }
    .plot-error   { color: #c62828; font-size: 0.85rem; padding: 12px 0; }
    #decision-plot-img { max-width: 100%; border-radius: 8px; display: block; margin: 0 auto; }

    .model-meta {
      display: flex; gap: 16px; flex-wrap: wrap; align-items: center;
      font-size: 0.82rem; color: #666; margin-top: 8px;
    }
    .model-meta strong { color: #1a237e; }
    .imp-list { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }
    .imp-item {
      display: flex; flex-direction: column; align-items: center; gap: 3px;
      min-width: 72px;
    }
    .imp-item .imp-label { font-size: 0.68rem; color: #666; }
    .imp-item .imp-bar-bg {
      width: 100%; height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden;
    }
    .imp-item .imp-fill { height: 100%; background: #1a237e; border-radius: 4px; }
    .imp-item .imp-val { font-size: 0.68rem; color: #333; font-weight: 600; }
  </style>
</head>
<body>
<header>
  <h1>⚾ CPBL 分析系統</h1>
  <nav>
    <button class="active" onclick="switchPage('stats', this)">勝負統計分析</button>
    <button onclick="switchPage('predict', this)">勝負預測</button>
  </nav>
</header>

<main>
  <!-- 勝負統計分析 -->
  <div id="page-stats" class="page active">

    <!-- 查詢表單 -->
    <div class="card">
      <h2>勝負統計分析</h2>
      <div class="form-row">
        <div class="form-group">
          <label>主場球隊</label>
          <select id="team-select" onchange="updateOpponentOptions()">
            <option value="">-- 請選擇 --</option>
            __TEAM_OPTIONS__
          </select>
        </div>
        <div class="vs-label">VS</div>
        <div class="form-group">
          <label>客場球隊（對手）</label>
          <select id="opponent-select">
            <option value="">-- 請選擇 --</option>
            __TEAM_OPTIONS__
          </select>
        </div>
        <button class="btn-query" onclick="queryStats()">查詢</button>
      </div>
      <div class="error-msg" id="error-msg">請選擇主場與客場球隊</div>
    </div>

    <!-- 勝率 -->
    <div class="card hidden" id="card-winrate">
      <h2 id="winrate-title">主場勝率</h2>
      <div class="stat-row">
        <div class="stat-card">
          <div class="s-label">勝率</div>
          <div class="s-value" id="win-rate">—</div>
          <div class="s-sub" id="win-record">—</div>
        </div>
        <div class="stat-card">
          <div class="s-label">平均淨勝分</div>
          <div class="s-value" style="color:#1565c0" id="avg-diff">—</div>
          <div class="s-sub" id="diff-range">—</div>
        </div>
      </div>
    </div>

    <!-- 勝負結果直方圖 -->
    <div class="card hidden" id="card-chart">
      <h2 id="chart-title">勝負結果分佈</h2>
      <div class="chart-wrap">
        <canvas id="result-chart"></canvas>
      </div>
    </div>

    <!-- Fisher 檢定 -->
    <div class="card hidden" id="card-fisher">
      <h2 id="fisher-title">主客場與勝負關係（Fisher 精確檢定）</h2>
      <div class="fisher-section">
        <table class="contingency">
          <thead>
            <tr><th></th><th>勝</th><th>敗</th></tr>
          </thead>
          <tbody>
            <tr>
              <th>主場</th>
              <td class="win-cell" id="f-hw">—</td>
              <td class="loss-cell" id="f-hl">—</td>
            </tr>
            <tr>
              <th>客場</th>
              <td class="win-cell" id="f-aw">—</td>
              <td class="loss-cell" id="f-al">—</td>
            </tr>
          </tbody>
        </table>
        <div class="fisher-result">
          <div class="f-row">
            <span class="f-label">主場勝算</span>
            <span class="f-val" id="f-home-odds">—</span>
          </div>
          <div class="f-row">
            <span class="f-label">客場勝算</span>
            <span class="f-val" id="f-away-odds">—</span>
          </div>
          <div class="f-row">
            <span class="f-label">p-value</span>
            <span class="f-val" id="f-pv">—</span>
          </div>
          <div class="conclusion-badge" id="f-conclusion">—</div>
        </div>
      </div>
    </div>

    <!-- 先得分 Fisher 檢定 -->
    <div class="card hidden" id="card-sf-fisher">
      <h2 id="sf-fisher-title">先得分與勝負關係（Fisher 精確檢定）</h2>
      <div class="fisher-section">
        <table class="contingency">
          <thead><tr><th></th><th>勝</th><th>敗</th></tr></thead>
          <tbody>
            <tr><th>先得分</th>
              <td class="win-cell"  id="sf-w">—</td>
              <td class="loss-cell" id="sf-l">—</td></tr>
            <tr><th>未先得分</th>
              <td class="win-cell"  id="nsf-w">—</td>
              <td class="loss-cell" id="nsf-l">—</td></tr>
          </tbody>
        </table>
        <div class="fisher-result">
          <div class="f-row"><span class="f-label">先得分勝算</span> <span class="f-val" id="sf-odds">—</span></div>
          <div class="f-row"><span class="f-label">未先得分勝算</span><span class="f-val" id="nsf-odds">—</span></div>
          <div class="f-row"><span class="f-label">p-value</span>    <span class="f-val" id="sf-pval">—</span></div>
          <div class="conclusion-badge" id="sf-conclusion">—</div>
        </div>
      </div>
    </div>

  </div>

  <!-- 勝負預測 -->
  <div id="page-predict" class="page">

    <!-- 查詢表單 -->
    <div class="card">
      <h2>勝負預測</h2>
      <div class="form-row">
        <div class="form-group">
          <label>主場球隊</label>
          <select id="pred-home" onchange="updatePredAway()">
            <option value="">-- 請選擇 --</option>
            __TEAM_OPTIONS__
          </select>
        </div>
        <div class="vs-label">VS</div>
        <div class="form-group">
          <label>客場球隊</label>
          <select id="pred-away">
            <option value="">-- 請選擇 --</option>
            __TEAM_OPTIONS__
          </select>
        </div>
        <div class="form-group" style="max-width:150px">
          <label>局段領先情境</label>
          <select id="pred-phase">
            <option value="led3">3 局後主場領先</option>
            <option value="led6">6 局後主場領先</option>
          </select>
        </div>
        <button class="btn-query" onclick="queryPredict()">預測</button>
      </div>
      <div class="error-msg" id="pred-error">請選擇主場與客場球隊</div>
    </div>

    <!-- 預測結果 -->
    <div class="card hidden" id="card-pred-result">
      <h2 id="pred-result-title">預測結果</h2>
      <div class="winner-row">
        <span class="wr-label">預測勝隊</span>
        <span class="wr-name" id="pred-winner-name">—</span>
        <span class="w-tag" id="pred-winner-tag">—</span>
        <span class="wr-prob" id="pred-winner-prob">—</span>
      </div>
      <div class="pred-note">※ 依各球隊歷史 PCA 特徵及局段領先情境預測，僅供參考</div>
    </div>

    <!-- Decision Plot -->
    <div class="card hidden" id="card-decision-plot">
      <h2 id="decision-plot-title">決策邊界圖</h2>
      <div id="decision-plot-wrap">
        <div class="plot-loading">圖表載入中...</div>
      </div>
    </div>

    <!-- 模型資訊 -->
    <div class="card" id="card-model-info">
      <h2>模型資訊</h2>
      <div class="model-meta">
        <span>5-fold CV 準確率：<strong id="cv-acc">__CV_MEAN__%</strong></span>
        <span style="color:#bbb">±</span>
        <span><strong id="cv-std">__CV_STD__%</strong></span>
      </div>
      <div class="imp-list" id="imp-list">__IMP_BARS__</div>
    </div>

  </div>
</main>

<script>
  let chartInstance = null;

  function switchPage(page, btn) {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('nav button').forEach(b => b.classList.remove('active'));
    document.getElementById('page-' + page).classList.add('active');
    btn.classList.add('active');
  }

  function updateOpponentOptions() {
    const home = document.getElementById('team-select').value;
    Array.from(document.getElementById('opponent-select').options).forEach(opt => {
      opt.disabled = opt.value !== '' && opt.value === home;
    });
    if (document.getElementById('opponent-select').value === home)
      document.getElementById('opponent-select').value = '';
  }

  async function queryStats() {
    const home = document.getElementById('team-select').value;
    const opponent = document.getElementById('opponent-select').value;
    const errEl = document.getElementById('error-msg');

    if (!home || !opponent || home === opponent) {
      errEl.classList.add('show');
      ['card-winrate','card-chart','card-fisher','card-sf-fisher'].forEach(id => document.getElementById(id).classList.add('hidden'));
      return;
    }
    errEl.classList.remove('show');

    const [statsRes, fisherRes, sfRes] = await Promise.all([
      fetch(`/api/stats?home=${encodeURIComponent(home)}&opponent=${encodeURIComponent(opponent)}`).then(r => r.json()),
      fetch(`/api/fisher?team=${encodeURIComponent(home)}`).then(r => r.json()),
      fetch(`/api/scored_first_fisher?team=${encodeURIComponent(home)}`).then(r => r.json()),
    ]);

    // 勝率
    document.getElementById('winrate-title').textContent = `${home} 主場 對上 ${opponent} 勝率`;
    document.getElementById('win-rate').textContent = statsRes.win_rate;
    document.getElementById('win-record').textContent = statsRes.win_record;
    document.getElementById('avg-diff').textContent = statsRes.avg_run_diff;
    document.getElementById('diff-range').textContent = statsRes.diff_range;
    document.getElementById('card-winrate').classList.remove('hidden');

    // 直方圖
    document.getElementById('chart-title').textContent = `${home} 主場 對上 ${opponent} 勝負結果分佈`;
    renderChart(statsRes.breakdown);
    document.getElementById('card-chart').classList.remove('hidden');

    // Fisher 主客場
    document.getElementById('fisher-title').textContent = `${home} 主客場與勝負關係（Fisher 精確檢定）`;
    const t = fisherRes.table;
    document.getElementById('f-hw').textContent = t.hw;
    document.getElementById('f-hl').textContent = t.hl;
    document.getElementById('f-aw').textContent = t.aw;
    document.getElementById('f-al').textContent = t.al;
    document.getElementById('f-home-odds').textContent = fisherRes.home_odds;
    document.getElementById('f-away-odds').textContent = fisherRes.away_odds;
    document.getElementById('f-pv').textContent = fisherRes.p_value;
    const badge = document.getElementById('f-conclusion');
    badge.textContent = fisherRes.conclusion;
    badge.className = 'conclusion-badge ' + (fisherRes.significant ? 'sig' : 'nosig');
    document.getElementById('card-fisher').classList.remove('hidden');

    // Fisher 先得分
    document.getElementById('sf-fisher-title').textContent = `${home} 先得分與勝負關係（Fisher 精確檢定）`;
    const st = sfRes.table;
    document.getElementById('sf-w').textContent   = st.sf_w;
    document.getElementById('sf-l').textContent   = st.sf_l;
    document.getElementById('nsf-w').textContent  = st.nsf_w;
    document.getElementById('nsf-l').textContent  = st.nsf_l;
    document.getElementById('sf-odds').textContent  = sfRes.sf_odds;
    document.getElementById('nsf-odds').textContent = sfRes.nsf_odds;
    document.getElementById('sf-pval').textContent  = sfRes.p_value;
    const sfBadge = document.getElementById('sf-conclusion');
    sfBadge.textContent = sfRes.conclusion;
    sfBadge.className = 'conclusion-badge ' + (sfRes.significant ? 'sig' : 'nosig');
    document.getElementById('card-sf-fisher').classList.remove('hidden');
  }

  function renderChart(breakdown) {
    if (chartInstance) chartInstance.destroy();
    chartInstance = new Chart(document.getElementById('result-chart'), {
      type: 'bar',
      data: {
        labels: breakdown.labels,
        datasets: [{
          label: '場數',
          data: breakdown.counts,
          backgroundColor: breakdown.colors,
          borderRadius: 6,
          borderSkipped: false,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: { label: ctx => ` ${ctx.parsed.y} 場` } }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: { stepSize: 1 },
            title: { display: true, text: '場數' }
          }
        }
      }
    });
  }

  function updatePredAway() {
    const home = document.getElementById('pred-home').value;
    Array.from(document.getElementById('pred-away').options).forEach(opt => {
      opt.disabled = opt.value !== '' && opt.value === home;
    });
    if (document.getElementById('pred-away').value === home)
      document.getElementById('pred-away').value = '';
  }

  async function queryPredict() {
    const home  = document.getElementById('pred-home').value;
    const away  = document.getElementById('pred-away').value;
    const phase = document.getElementById('pred-phase').value;
    const errEl   = document.getElementById('pred-error');
    const resCard = document.getElementById('card-pred-result');

    if (!home || !away || home === away) {
      errEl.classList.add('show');
      resCard.classList.add('hidden');
      document.getElementById('card-decision-plot').classList.add('hidden');
      return;
    }
    errEl.classList.remove('show');

    const data = await fetch(
      `/api/predict?home=${encodeURIComponent(home)}&away=${encodeURIComponent(away)}&phase=${phase}`
    ).then(r => r.json());

    // 精簡預測結果
    const winner = data.predicted_winner;
    const isHome = data.winner_is_home;
    document.getElementById('pred-result-title').textContent =
      `${home}（主）vs ${away}（客）預測結果`;
    document.getElementById('pred-winner-name').textContent = winner;
    document.getElementById('pred-winner-prob').textContent =
      (isHome ? data.home_win_prob : data.away_win_prob) + '%';
    const tag = document.getElementById('pred-winner-tag');
    tag.textContent = isHome ? '主場' : '客場';
    tag.className = 'w-tag ' + (isHome ? 'home-tag' : 'away-tag');
    resCard.classList.remove('hidden');

    // Decision plot：向 R plumber API 取圖（port 8001）
    const plotWrap = document.getElementById('decision-plot-wrap');
    document.getElementById('decision-plot-title').textContent =
      `決策邊界圖：${home}（主）vs ${away}（客）`;
    plotWrap.innerHTML = '<div class="plot-loading">圖表載入中...</div>';
    document.getElementById('card-decision-plot').classList.remove('hidden');

    const img = new Image();
    img.id = 'decision-plot-img';
    const url = `http://localhost:8001/decision_plot?home=${encodeURIComponent(home)}&away=${encodeURIComponent(away)}&t=${Date.now()}`;
    img.onload  = () => { plotWrap.innerHTML = ''; plotWrap.appendChild(img); };
    img.onerror = () => {
      plotWrap.innerHTML =
        '<div class="plot-error">圖表載入失敗 — 請確認 R Plumber API 已於 port 8001 啟動</div>';
    };
    img.src = url;
  }
</script>
</body>
</html>
"""


def _render_imp_bars() -> str:
    imp = model_info["importances"]
    max_v = max(imp.values()) or 1
    labels = {
        "Off_PC1": "進攻PC1", "Off_PC2": "進攻PC2", "Off_PC3": "進攻PC3",
        "Def_PC1": "防守PC1", "Def_PC2": "防守PC2", "Def_PC3": "防守PC3",
        "is_home": "主客場", "led_after_3": "3局後領先", "led_after_6": "6局後領先",
    }
    items = []
    for f, v in sorted(imp.items(), key=lambda x: -x[1]):
        pct = round(v / max_v * 100)
        items.append(
            f'<div class="imp-item">'
            f'<span class="imp-label">{labels.get(f, f)}</span>'
            f'<div class="imp-bar-bg"><div class="imp-fill" style="width:{pct}%"></div></div>'
            f'<span class="imp-val">{v:.3f}</span>'
            f'</div>'
        )
    return "".join(items)


@app.get("/", response_class=HTMLResponse)
async def index():
    options = "\n".join(f'<option value="{t}">{t}</option>' for t in teams)
    html = HTML_TEMPLATE.replace("__TEAM_OPTIONS__", options)
    html = html.replace("__CV_MEAN__", str(model_info["cv_mean"]))
    html = html.replace("__CV_STD__",  str(model_info["cv_std"]))
    html = html.replace("__IMP_BARS__", _render_imp_bars())
    return HTMLResponse(html)


@app.get("/api/stats")
async def api_stats(home: str, opponent: str):
    result = get_win_rate(home, opponent)
    result["breakdown"] = get_result_breakdown(home, opponent)
    return result


@app.get("/api/fisher")
async def api_fisher(team: str):
    return get_fisher_result(team)


@app.get("/api/scored_first_fisher")
async def api_scored_first_fisher(team: str):
    return get_scored_first_fisher(team)


@app.get("/api/predict")
async def api_predict(home: str, away: str, phase: str = "led3"):
    return predict_matchup(home, away, phase)
