# SAVE_FORMAT — 存檔格式

> 本檔是 [autoload/spike_save.gd](autoload/spike_save.gd) 目前存檔內容的**可讀快照**，不是正本。
> 正本永遠是程式碼——欄位語意、預設值、白名單回填規則以程式碼註解為準，
> 本檔過期時以 `_to_save_dict()` 與 `_apply_save_dict()` 為準重新對照。
> 相容性承諾（能不能改、怎麼改）住 [COMPATIBILITY.md](COMPATIBILITY.md)，本檔只記錄「現在長什麼樣」。

## 檔案位置

| 用途 | 路徑 |
|---|---|
| 正式存檔 | `user://spike_save.json` |
| 測試沙盒（headless 冒煙測試專用，不動玩家存檔） | `user://spike_save_test.json` |
| 寫檔暫存（原子寫入用，正常情況下瞬間出現又消失） | `user://spike_save.json.tmp` |
| 壞檔備份 | `user://spike_save.json.corrupt-<timestamp>` |
| 存檔版本比程式新時的備份 | `user://spike_save.json.future-version-<timestamp>` |
| 匯入覆蓋前備份 | `user://spike_save.json.before-import-<timestamp>` |

## 頂層欄位

| 欄位 | 型別 | 說明 |
|---|---|---|
| `schema_version` | int | 存檔格式版本，見下方「版本沿革」。現行 = 3 |
| `game_version` | string | 寫檔當下的遊戲版本號（`SpikeConfig.GAME_VERSION`），除錯用，不參與讀檔邏輯 |
| `coins` | int | 金幣總數 |
| `levels` | Dictionary\<String,int\> | 永久升級等級，key 對齊 `SpikeConfig.UPGRADE_TABLE` |
| `best_height_m` | float | 歷史最高高度（一般／極限取大值，墓碑機制讀這個） |
| `best_height_normal_m` / `best_height_extreme_m` | float | 分模式最高高度 |
| `best_time_level_normal` / `best_time_level_extreme` | Array\<float\> | 每關最佳登頂用時，index 對齊 `SpikeConfig.LEVEL_GOALS`；`-1.0`＝未登頂 |
| `last_run_seed` | int | 最近一局的 RNG seed，供未來榜單審核重現用 |
| `extreme_mode` / `endless_mode` | bool | 兩個模式開關（互相獨立，需先解鎖） |
| `selected_level` | int | 目前選的關卡（0-based） |
| `unlocked_level` | int | 已解鎖到第幾關（只增不減） |
| `cleared_max` | int | 通關過的最高關卡 index，`-1`＝一關都沒通（解鎖獎勵門檻讀這個，不是 `unlocked_level`） |
| `ledge_enabled` / `watch_enabled` | bool | 攀爬手套／懷錶的啟用開關（「有沒有拿到」另外由 `cleared_max` 判定） |
| `story_seen` | Dictionary\<String,bool\> | 播過的劇情 id |
| `tutorial_done` | bool | 教學關是否玩過 |
| `achievements` | Dictionary\<String,int\> | 成就三態：0 未解鎖／1 已解鎖未領獎／2 已領獎 |
| `stats` | Dictionary\<String,int\> | 跨局累計計數，key 表見 `SpikeConfig.STAT_KEYS` |
| `corpse_deaths` | Dictionary\<String,int\> | 井底屍體堆死亡次數，key＝`"<關卡>|<模式>"` |

## 版本沿革

| schema_version | 內容 |
|---|---|
| v1 | 最早格式，只有共用的 `best_height_m`，無 `schema_version` 欄位本身（缺此欄位一律視為 v1） |
| v2 | 加入 `schema_version` 欄位；高度與登頂用時拆成一般／極限兩份 |
| v3（08-10 關卡制） | 登頂用時從單一數值拆成「每關一格」的陣列；v2 時代的舊值遷入關卡一（1000m）那格 |

遷移邏輯目前是 `_apply_save_dict()` 內的**版本門檻級聯**（`if version < 2` / `if version < 3`），
不是清單建議的鏈式函式（`migrate_1_to_2()`…）。現行寫法在只有 3 個版本時仍然清楚可讀，
維持不動；若版本數繼續增加到程式碼段落難以一眼看懂時，再回頭拆成鏈式函式（見 COMPATIBILITY.md）。

## 讀檔安全機制（已實作）

- 缺欄位一律吃預設值，不 crash、不整份重置。
- 讀到非 Dictionary 的壞 JSON → 備份原檔（`.corrupt-*`）→ 這次當新檔跑。
- 讀到 `schema_version` **高於**目前程式版本 → 備份原檔（`.future-version-*`）→ 不讀取、不覆寫、這次當新檔跑。
- `levels` / `achievements` / `stats` 只認目前資料表**有列出**的 key（白名單回填），
  多餘 key 直接忽略；`corpse_deaths` / `story_seen` 不比對白名單（見程式碼註解的理由）。
  ⚠ 此白名單機制與清單「不認得的欄位要保留」的建議有意識地不同，取捨記錄在 COMPATIBILITY.md。
- 寫檔採原子寫入：`.tmp` → 讀回驗證是合法 JSON → 才改名覆蓋正式檔。

## 存檔匯出／匯入碼

`RAORA1-<base64(JSON)>.<sha256前12碼校驗碼>`。校驗碼只擋「貼錯/漏貼/手滑改字」，
**不是防作弊**（鹽值寫死在 client code，玩家本來就能直接改 IndexedDB）。
匯入版本高於目前程式一律拒絕（訊息：「這串代碼是比較新版本的遊戲存的」），覆蓋前自動備份匯入前狀態。
