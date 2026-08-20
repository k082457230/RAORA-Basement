# REMOTE_OPS.md — 無電腦期遠端開發手冊

**背景**：2026-08-20 交還工作電腦，後續約三週手上只有手機＋平板（偶爾借得到電腦）。
這份文件說明那三週內要怎麼繼續開發爬井專案。

- 進度／下一步 → `HANDOFF.md`（不在這裡複述）
- 專案規則／驗證矩陣 → `spike_well/CLAUDE.md`（不在這裡複述）
- **本檔只放「沒有本機時，怎麼把東西改進去」**

---

## 1. 鑰匙清單（全部應在手機密碼管理器，不是隨身碟）

| 鑰匙 | 用途 | 沒有它會怎樣 |
|---|---|---|
| Claude 訂閱長期 token（`claude setup-token` 產出） | 雲端跑 Claude Code | 路線 A 斷 |
| GitHub 帳號登入（`k082457230`） | 所有路線的基礎 | 全斷 |
| Oracle VM 私鑰 `ssh-key-2026-04-07.key` | 進 VM（連線參數見 §1.1） | 路線 A 斷 |
| Telegram bot token（@BotFather） | 路線 A 的操控介面 | 路線 A 只剩 SSH |

**私鑰核對指紋**：`SHA256:We1TBNUYI7yQsin5W0is6cUr/PDKuf2qkgwj+9GgqVA`（RSA 2048，無密碼保護）
→ 該私鑰無密碼，遺失即 VM 被接管。要加保護：先複製一份，再 `ssh-keygen -p -f <複本>`。

### 1.1 VM 連線參數（2026-08-20 實測通過）

| 項目 | 值 |
|---|---|
| 公網 IP | `161.33.14.206` |
| 使用者 | `ubuntu`（**不是 opc**，Oracle 會明確拒絕 opc） |
| 架構 | `aarch64`（Ampere A1）→ 用 Godot 的 `linux.arm64` build |
| hostname | `instance-20260407-1420` |
| 同機服務 | n8n（`n8n.gnt.com.tw` 解析到同一 IP）→ **別把它弄掛** |

```bash
chmod 600 <私鑰>   # 權限太開放 ssh 會拒絕
ssh -i <私鑰> ubuntu@161.33.14.206
```

⚠ Oracle 重開機可能換 ephemeral IP。連不上先去 Oracle Cloud 網頁 console 確認 IP。

---

## 2. 三條路（按推薦度）

### 路線 B — claude.ai/code（**主力，平板用**）
零架設、直接吃訂閱額度、沙箱在雲端。

1. 平板瀏覽器開 claude.ai/code
2. 授權 GitHub → 選 `k082457230/RAORA-Basement`
3. 素材直接在對話裡當附件上傳，請 Claude 接線並 commit

**弱點**：沙箱每個 session 重建，跑 Godot 驗證不保證穩 → 驗證交給路線 C。

### 路線 C — GitHub Actions（**驗證安全網，自動**）
`.github/workflows/smoke.yml`。每次 push 到 master 自動跑七組稽核＋headless bot。

- 判定依據＝ `smoke.gd` 的 `quit(0 if failures == 0 else 1)`，**是真判定不是假綠燈**
- **已實測**（2026-08-20 首輪即綠）：CI 輸出 101 行、exit 0，與本機實跑**逐行數一致**
  → 證明 CI 沒有靜默跳過稽核。日後懷疑假綠燈時，重跑這個比對即可
- 手機看結果：GitHub app → Actions 分頁 → 紅/綠
- 細節：下載 `smoke-logs` artifact（保留 30 天）
- 手動觸發：Actions 分頁 → smoke → Run workflow
- **`deploy-web` job（2026-08-20 實測通過）**：smoke 綠燈後自動匯出 Web 版並推上 itch.io
  - 目標：`paperstormingowo/raoras-basement:html5`，維持 draft
  - 版本標記：`ci-<run編號>-<commit前7碼>`，在 itch.io 後台看得到，可對照是哪次 push
  - 金鑰走 GitHub Secret `BUTLER_API_KEY`，不在任何檔案裡

### 路線 A — Oracle VM ＋ Telegram（**選配，手機隨手用**）
唯一能「傳圖進去、截圖傳回手機」的路，但架設與維運成本最高。

**2026-08-20 已完成的前置（斷點狀態）**：
- Claude Code `2.1.237` 已裝（`~/.local/bin/claude`）
- Godot `4.6.1 arm64` 已裝（`~/godot/Godot_v4.6.1-stable_linux.arm64`），實跑驗證通過
- repo 已 clone 到 `~/RAORA`，走 deploy key（read-write，GitHub 端已掛）
- `tmux`、`unzip`、`libfontconfig1` 已裝
- **VM 實跑七組稽核：101 行、exit 0，與本機／Actions 逐行數一致**

**還差的最後一步（三週後有電腦再做，需要瀏覽器授權）**：
```bash
ssh -i <私鑰> ubuntu@161.33.14.206
cd ~/RAORA/spike_well          # 一定要在專案目錄，home 目錄的信任不會被保存
claude                          # 互動式登入 + 接受 workspace trust
tmux new -d 'claude remote-control'
```
⚠ Remote Control **不接受 `setup-token` 產的長期 token**，必須走 `/login` 完整帳號登入。
⚠ 官方只建議用 tmux/screen 保命，**沒有官方的開機自動重啟方案**，要自己包 systemd。
- **必須配 systemd 自動重啟**，只用 tmux 的話 session 一斷、VM 一重開就沒人接訊息，
  而你在手機上很難修
- 只有在 B 與 C 都通了、且確認 SSH 進得去，才值得花時間

---

## 3. 雲端做得到／做不到

| 事項 | 雲端可行性 |
|---|---|
| 改程式碼、接素材、commit | ✅ 路線 B |
| 七組稽核＋headless bot | ✅ 路線 C 自動跑 |
| 突變測試 `tools/mutation_check.py` | ✅ 需 Python，沙箱可裝 |
| 字型子集化 `tools/subset_font.py` | ✅ 改過中文文案後**必跑**，否則 Web 版新字是豆腐 |
| `visual_check.tscn` 目視版面 | ⚠ 需 xvfb，workflow 尚未接（要接就加一步 xvfb-run ＋ upload-artifact） |
| `record.tscn` 動態錄影 | ⚠ 需 xvfb，且 190ms/格 → 20 秒錄影約 4 分鐘 |
| Windows／Web 匯出 | ⚠ 需另外下載 export templates |

---

## 3.5 itch.io（唯一能「真的玩到」的管道）

**兩個專案，標籤制分流**（2026-08-20 起）：

| 專案 | 用途 | 誰觸發部署 | 版本標記 |
|---|---|---|---|
| `raoras-basement`（**public，玩家看的正式頁**） | 正式發布 | push 一個 `v*` git tag（如 `v0.4.0`） | tag 名稱本身 |
| `raoras-basement-test`（draft，暫存倉庫） | 發布前測試 | 每次 push master 自動 | `ci-<run編號>-<commit前7碼>` |

- 流程：日常 push master → 自動更新到 `raoras-basement-test`（draft，只有你自己上得去）→
  在那邊測完確認沒問題 → **你跟 Claude 說「這版可以發正式版」，Claude 下
  `git tag vX.Y.X && git push origin vX.Y.X`**（版本號來源＝
  `autoload/spike_config.gd` 的 `GAME_VERSION`，目前 `0.4.0`）→ CI 自動匯出並推上
  `raoras-basement`。
- ⚠ **`raoras-basement-test` 這個專案需要你自己去 itch.io 後台建**（Claude 不能替你開新
  itch.io 專案）：New Project → slug 建議 `raoras-basement-test` → 可見度設 Draft 或
  Restricted。跟正式專案共用同一把 `BUTLER_API_KEY`（itch.io API key 是帳號層級，不分專案）。
- 正式頁：https://paperstormingowo.itch.io/raoras-basement （2026-08-20 已改 public）
- ⚠ **不要勾 SharedArrayBuffer support**：本作 `variant/thread_support=false`（單執行緒匯出），
  不使用 SharedArrayBuffer，勾了只會要求 cross-origin isolation、徒增 Safari/Firefox 相容性問題
- ⚠ 一個頁面只能有一個「在瀏覽器執行」的檔案。確認旗標掛在 CI 產出的
  `raoras-basement-html5.zip` 上，否則你玩到的會是舊版
- API key 已存進 GitHub Secret。**若 key 需要更換**：itch.io 產新的 → GitHub repo →
  Settings → Secrets → 更新 `BUTLER_API_KEY`（手機瀏覽器可操作）

## 4. 卡關 fallback

| 症狀 | 處置 |
|---|---|
| push 被拒：`without workflow scope` | 動到 `.github/workflows/` 需要 `workflow` scope。`gh auth refresh -h github.com -s workflow`，或直接在 GitHub 網頁編輯該檔 |
| Actions 紅燈但看不懂 | 下載 `smoke-logs` artifact，只看 `[SMOKE]` 與 `!!` 行 |
| 平板 sandbox 沒有 Godot | 別在沙箱硬跑驗證，push 上去讓路線 C 驗 |
| VM 連不上 | 先確認 IP 沒變（Oracle 重開機可能換 ephemeral IP），再確認私鑰權限 |
| itch.io 玩到的是舊版 | 後台檢查「在瀏覽器執行」的旗標掛在哪個檔案上（見 §3.5） |
| 改完中文文案 Web 版變豆腐字 | 重跑 `python tools/subset_font.py`（來源字型 2026-08-20 起已進版控，雲端跑得動） |
| 三條路全斷 | 專案完整副本在隨身碟＋雲端硬碟，等借到電腦再接手 |

---

## 5. 三週內的工作紀律

- **改中文文案後必跑 `tools/subset_font.py`**（唯一容易在雲端被忘掉、且會直接壞掉的一件事）
- 素材接線流程不變：走 `spike_well/.claude/skills/import-art-asset`、`import-sound-asset`
- 每次收工照樣更新 `HANDOFF.md`，別讓三週後的自己接不上
