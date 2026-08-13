---
name: import-art-asset
description: 要把 AI 產生的圖接進 spike_well 遊戲時用——新增或替換角色立繪、怪物貼圖、平台／道具圖、多姿勢動作圖，或發現貼圖位置跑掉／姿勢切換會跳動時觸發。涵蓋量測目標尺寸、等比縮放、選縮圖演算法、用 tools/measure_anchor.py 定腳底錨點、匯入設定、程式接線、三層驗證。已用過三輪（Kaela／怪物系／Pameloe），流程穩定可重複，不用每次重新想一次。
argument-hint: "[素材名稱或來源檔路徑]"
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

給下一次「把 AI 畫的圖換成遊戲貼圖」照著做。完成後把新素材登記進
`spike_well/.claude/docs/art-assets.md`（唯一的美術資產現況清單）。

1. **量測目標尺寸**：目標＝角色在 `spike_config.gd` 的碰撞尺寸（如 `PLAYER_SIZE`）× 2（已拍板慣例）。
2. **等比縮放，不要雙軸硬拉**：量實際來源檔尺寸算縮放比，若跟目標有落差（AI 畫圖常見）就
   **鎖長或寬其中一軸**等比縮小，兩軸各自分別拉到目標值＝變形不是縮放。
3. **判斷是不是硬邊像素風**再選縮圖演算法：抽樣幾列像素跑 run-length，長度若卡在固定倍數
   （真正的像素網格）才用整數倍＋nearest；平滑抗鋸齒插畫（多數 AI 產圖屬此類）用
   Lanczos/bicubic 不會有破網格風險。
4. **多姿勢貼圖共用同一個錨點——跑 `tools/measure_anchor.py`，不要用眼睛量**：

   ```
   python tools/measure_anchor.py assets/sprites/kaela_steady.png assets/sprites/kaela_jump.png assets/sprites/kaela_jetpack.png --anchor assets/sprites/kaela_steady.png --const-name KAELA_FEET_ANCHOR_FRAC
   ```

   它做三件事：①**檢查所有畫布尺寸完全一致**，不一致直接 exit 1 拒絕出常數（那代表縮放
   步驟做壞了，繼續往下接一定會跳動）②算 alpha bbox ③印出可直接貼進 `spike_config.gd`
   的常數行（如 `const KAELA_FEET_ANCHOR_FRAC := 99.0 / 108.0`）。
   `--anchor` 指定「最需要精準貼合」的那張（例如踩到平台的姿勢）當**唯一**基準，其他姿勢
   沿用同一比例，不要各自重新量——每張各量各的，切換姿勢時角色會跳動。
   ⚠ 餵給工具的必須是縮圖「之後」的檔案，縮放取整會有 1~2px 誤差，拿原始檔量、貼縮圖後
   的比例會對不齊。
   ⚠⚠ **這條不只適用多姿勢角色**：凡是「站在平台上」的東西（玩家、怪物、蟲洞）**一律要量
   腳底錨點，不准用中心對齊**。art 尺寸是碰撞尺寸的 2 倍，中心對齊會讓貼圖底邊沉到平台上緣
   下方 21px、而平台只有 18px 厚 ⇒ 整塊平台被蓋掉（08-10 第一次接怪物與蟲洞就是這樣接錯的，
   使用者看畫面才發現）。懸浮的東西（Pameloe）才用中心對齊——它沒有「腳底」這條基準線。
5. **檔案落地** `spike_well/assets/sprites/`。路徑常數住在實際 `load()` 它的那個檔案（同
   `SpikeUI.FONT_PATH` 慣例），不進 `spike_config.gd`——config 只管可調數值，不是資源路徑。
6. **匯入設定不用逐檔調**：`project.godot` 的 `[importer_defaults] texture` 已統一開
   `mipmaps/generate=true`，`[rendering]` 已設 `textures/canvas_textures/default_texture_filter=2`
   （Linear Mipmap），新圖直接吃這組預設。存檔後記得跑一次
   `Godot..._console.exe --headless --path <spike> --import`——跟換中文字型同一個坑：
   不重新 import，`ResourceLoader.exists()` 會是 false。
7. **程式接線延用既有 `_draw()`**：`draw_texture_rect()` 接進去，不新增 Sprite2D 節點、
   不手刻 .tscn（spike_well/CLAUDE.md 硬規則）。載入用 `ResourceLoader.exists()` 判斷，缺檔要
   退回色塊 fallback，不能讓玩家整個消失看不見。
8. **驗證三層都要做**：① headless 回歸（`smoke.tscn`）確認 0 import error、無邏輯回歸；
   ② 肉眼看貼圖位置、姿勢切換有沒有跳動、有沒有穿模——這層數字測不出來，省不掉。
   **用 `res://visual_check.tscn`**（08-09 為 Kaela 三態寫的一次性小工具，留著沿用）：
   直接把 `WellWorld` 建出來、手動撥 `player` 狀態、`queue_redraw()` 後用
   `get_viewport().get_texture().get_image().save_png()` 把畫面存成 PNG，不用截圖工具、
   不用滑鼠去戳遊戲視窗。⚠⚠ **這條路一定不能加 `--headless`**：headless 底下
   `RenderingServer` 是 dummy driver，貼圖會是空白（08-08 那次「截圖抓到空白幀」的根因）。
   指令：`Godot..._console.exe --path <spike> res://visual_check.tscn`（會真的開一下 Vulkan
   視窗，正常，腳本跑完會自己 `quit()`）。輸出在 `tools/out/`（不進版控，見根目錄 `.gitignore`）。
   ③ **動態錄影**（`res://record.tscn`）：visual_check 是「手動撥狀態、擺靜態姿勢」，驗不到
   「真的動起來時對不對」——移動中切換姿勢會不會跳、特效有沒有接上、死亡演出長怎樣。
   錄影讓既有的 headless bot 在**會渲染**的模式下實跑，逐格輸出 PNG，事後挑頭／中／尾回讀。
   指令與可選參數見 `spike_well/CLAUDE.md`「執行方式」節。同樣**一定不能加 `--headless`**。
   ⚠ 目前錄的是 `WellWorld` 本身、**不含 HUD／UI 層**（未接 main.gd 流程），UI 版面仍靠
   visual_check ＋ `tests/audit_ui.gd` 的稽核。

完成後：把這次的素材、比例、任何 ⚠ 坑記錄進 `spike_well/.claude/docs/art-assets.md`（美術資產現況唯一的家），不要另開文件。
