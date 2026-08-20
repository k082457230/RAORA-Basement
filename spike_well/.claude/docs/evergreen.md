# 常青認知 — 跨 session 都成立，動對應系統前先讀

**這份清單唯一的家。** 進度住 [../../../HANDOFF.md](../../../HANDOFF.md)、規則綱要住
[../../CLAUDE.md](../../CLAUDE.md)、發生過什麼住 `HANDOFF_ARCHIVE.md` 與 git log；
這裡只放「以後換個系統、換個人也會再踩一次」的知識。

新增一條的門檻：**下次還會再踩**。只在某一次成立的細節不要進來（那是 archive 的事）。

1. **「大小 ×2」要連判定一起乘**——只放大視覺等於偷偷把判定變寬鬆。
2. **淡出必須在畫面內演完**——時長算到超出畫面底才算數，否則等於白做。
3. **衝擊波是累加常駐的獨立速度分量**，三種干擾解鎖後不互斥，`Interference.stage()` 用 `>=`。
4. **稽核容易騙過自己**：邊玩邊生成／回收的東西要模擬真實路徑（蟲洞曾因串流 prune 早於出口
   綁定而機率為零）；稽核之間會互相污染狀態，每條自己定死依賴狀態。
5. **階梯成就三階共用同一張卡片版位**：`SpikeSave.current_tier_id(slot)` 動態決定，不能在
   卡片建構時把 id 綁死。
6. **稽核本身也可能是壞的**：「保命條款」型常數要另寫一條驗常數關係的斷言（範本
   `tests/audit_hazards.gd` 的 `_audit_pameloe`），新稽核要用突變測試驗它抓得到。
   ⚠ 突變測試走 `tools/mutation_check.py`（加一列進 `tools/mutations.json`），**不要手動
   改壞再改回**——手動每條 4 次 round-trip，正是 08-13 三批燒掉 80 萬 token 的大宗。
   ⚠ **稽核端也讀的常數突變不出東西**（改常數＝同時改斷言，永遠 MISS），要挑只被實作端
   用的常數、或直接改壞遊戲資料；細節與已知覆蓋缺口見 [verification-matrix.md](verification-matrix.md)。
7. **死亡不是同一幀的事**：`_die()` 只起爆，`died` 要等爆炸演完（`_settle_death`）才 emit。
8. **貼圖繪製常見坑**：`modulate` 是乘法不是取代，染色前先做全白剪影（`_make_silhouette`）；
   `draw_texture_rect` 負寬度即原地鏡像，不用補 `+size.x`；鏡像方向要實測不用猜；**站在平台
   上的東西**用腳底錨點（懸浮物例外），**平台本身**用頂部錨點；輪廓描邊畫在本體之前。
9. **生成鏈用「上一塊的高度」決定「這一塊的性質」**：`_generate_next` 的 `h_m` 是上一塊的，
   高度分區判斷會差一格 ⇒ 稽核不准拿高度反推分區，改存旗標（`WellPlatform.segment_id`）。
10. **同 y 的兩塊板不能靠排序認人**：`sort_custom` 不保證穩定 ⇒「群裡最高那塊＝主鏈」會偶發
    失效。同第 9 條：**身分要存旗標**（`is_band_extra`），不要從幾何反推。
11. **共用的「純函式」可能偷偷在骰 RNG**：`WellGenerator.spacing_at()` 看起來只是查表插值，
    內部卻有一行 `randf_range()`，固定佈局路徑呼叫到它會讓生成序列偏移、**既有固定 seed 稽核
    照樣全綠**。⚠ 新路徑要先確認 helper 沒碰 `_rng`，並補「同 seed 下 `_rng.state` 前後不變」。
12. **新的 `class_name` 檔要先跑一次 `--import` 才註冊得到**——否則會是
    `Could not find type "X" in the current scope`，看起來像打錯字。
13. **UI 的兩個坑**（只有 `visual_check` 截圖看得出來）：①`set_anchors_preset` 之後 `position`
    是相對**錨點**算的，BOTTOM_LEFT ＋ 正 y 會把子節點推到框外 ②「畫 N 層同心環近似漸層」
    重疊處 alpha 疊兩次會看到接痕，改用 `GradientTexture2D`（FILL_RADIAL）。
14. **紅燈先懷疑斷言**：「不污染主 RNG」第一版比錯對象（兩座井爬到同一高度後的下一個亂數本來
    就會不同），正確比法是 `_rng.state` 前後不變。
15. **`process_mode` 沒設就是繼承父節點**，不是獨立生效 PAUSABLE——`Main` 底下掛新節點沒明確
    設就會悄悄繼承 `ALWAYS`，`get_tree().paused` 對它沒用。
16. **headless 模擬按鍵，`Input.parse_input_event()` 不會立刻生效**：要接著
    `Input.flush_buffered_events()` 才會反映在 `is_key_pressed()`。
17. **新增一種「模式」時，所有時間驅動的 UI 與所有存檔寫入各盤點一次**——教學關把干擾改成高度
    觸發，右上角「Raora 登場倒數」卻照 elapsed 跑、67 秒後謊報「已登場」。這種 bug 不報錯、
    稽核也不紅（每個元件單獨看都正常）。存檔同理（教學關七個寫入點全要跳過）。
18. **玩家可見文案裡不准寫死按鍵，也不准寫死吃升級的數字**——「按 E 甩鞭子」在玩家改鍵之後就是
    **在教學玩家按錯鍵**且不報錯；「鞭子有 5 次」會被永久升級改掉。一律整句模板 ＋ 展開函式
    （`SpikeConfig.tutorial_cue_text()` 走 `SpikeKeys.label_of()`），這也是 i18n 條款的寫法。
19. **（08-14）reset 要按「誰會寫這顆欄位」盤點，不是按「主流程用不用得到」**——干擾跨局殘留的
    真兇是兩顆**只有教學關手動 API 會碰**的欄位，`reset()` 從沒清過；而 `_process()` 在死亡
    演出與登頂時整個 early-return，狀態就凍在半途帶進下一局。
20. **（08-14）成本是三條軸，最貴的不是「跑測試花多久」**——① 進 context 的字數（東西進去
    就一直躺著，之後**每一次**工具呼叫都重付一次＝乘法）② round-trip 次數（每次來回重送整包
    context ＋ 等模型想）③ 工具執行時間（實測是三者裡最小的）。實測完整 smoke 只要 **4~8 秒**，
    08-13 的檢討報告卻估成「1.5~3 分鐘」並據此提改善方案——錯 20~35 倍，方案自然也錯。
    ⚠ **斷言耗時前先實測一次**，跟斷言數值前先讀 code 是同一條規矩。省成本的順序永遠是
    「少讀 → 少來回 → 最後才輪到跑快一點」。
21. **（08-19）「只讀 `[SMOKE]` 與 `!!` 行」這條省 token 規則會濾掉真訊號**——headless smoke 的
    輸出裡**一直**有 **72 行 `Unicode parsing error`**（開機階段、engine banner 之後），三個
    session 沒人看到，因為它既不是 `[SMOKE]` 也不是 `!!`。是在瀏覽器實跑 Web 版、被 console
    的紅字砸到臉上才發現，追下去才挖出四首 BGM 的授權問題。
    ⚠ 規則不必改（照讀整份輸出的代價更大），但**每個里程碑至少完整看一次 smoke 輸出的前 20 行**，
    以及**換平台跑（web／不同 renderer）時一定重看**——新平台會把舊平台藏起來的東西吐出來。
22. **（08-19）文件裡的「現況：⋯⋯，暫不適用」註記會過期，而且過期時不會有人通知你**——
    checklist §2.2 的音訊條寫「現況：專案零音效系統，暫不適用」，但 08-17 起專案有 39 個音檔、
    08-18 起有兩條音訊匯流排；§6.6 有兩條因為同一句話被勾成完成，其中一條蓋住的是上架級風險。
    ⚠ 凡是「因為現況 X 所以這條不適用」的勾選，**X 本身就是一個待失效的斷言**——寫的時候要
    連「X 什麼時候會不成立」一起寫進去，或乾脆別勾、只寫備註。

23. **（08-20）同一份 working tree 禁止兩個行程並行「改檔＋commit」**——主線在子 agent 施工中
    commit，把子 agent 剛落地的半成品夾帶進不相干的 commit。而且 commit 前的安全檢查 grep 因
    pathspec 寫錯而**靜默回空**（cwd 已在 spike_well 內卻寫 `spike_well/...` 前綴，git 對無效
    pathspec 不報錯、直接給空 diff ＝假陰性）。規則：①派了會改檔的 agent，working tree 凍結
    ——不 commit／stash／reset，等它收工再動 git；②git pathspec 一律照 `git status --short`
    顯示的路徑樣式寫，「空 diff」先驗證 pathspec 有效再相信。

24. **（08-20）觸控輸入是 `SpikeKeys.is_action_pressed()` 的隱性覆寫層，不是另一條路徑**——
    `_touch_held` 字典比鍵盤狀態優先判定；查「按鍵沒反應」除了查 `key_of()`/`DEFAULT_KEYS`，
    還要查這層有沒有卡 true/false。⚠ 切畫面（暫停/回選單）忘記呼叫
    `SpikeKeys.clear_touch_held()`，手指離開按鈕範圍但沒放開的那次觸控會卡在 true，恢復
    遊戲後角色不受控自走。同批容易搞混的另一個是 `WellWorld.kb_dir_override`（只有
    `record.gd`／`tests/bot_run.gd`／`tests/audit_buffs.gd` 三處測試工具會設，正式遊戲路徑
    永遠 null）——查「移動沒反應」先確認不是在查錯這顆。
25. **（08-20）既有 HUD 格子（`HudCell` 等）都是 `mouse_filter = Control.MOUSE_FILTER_IGNORE`
    的純顯示元件**，不能直接當觸控／滑鼠熱區用；新增互動要另外疊一層 Control（本次做法：
    `SpikeUI._touch_controls`，跟 `_hud` 同層不巢狀——巢狀會被 `_audit_dev_teleport` 等遞迴
    收集 `_hud` 底下所有 Button 的稽核誤判為 dev 按鈕）。
26. **（08-20）觸控覆寫層只蓋得到「輪詢」路徑，蓋不到「事件」路徑**——`set_touch_held()`
    影響的是 `SpikeKeys.is_action_pressed()`（left／right／jet 這類長按型）；而 aim／watch／
    item 是在 `well_world.gd _unhandled_input` 直接比對 `InputEventKey.keycode`，觸控層
    **產不出 InputEventKey**，所以怎麼設 held 都沒用。watch／item 當時靠「UI 發訊號 →
    main.gd 呼叫 world 方法」繞過去，aim 漏接 → 平板上鞭子完全叫不出來（08-20 使用者實測）。
    新增任何觸控動作前，先分辨那顆動作走的是輪詢還是事件。
