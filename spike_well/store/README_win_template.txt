# store/README_win_template.txt — Windows 下載版 README 範本
#
# 用途：checklist.md §2.3 要求每個下載版 zip 內附 README.txt。這份是「範本」，
# 每次重新打包 Windows 版時複製這份、把下面標 <<...>> 的地方換成當次實際值，
# 存成 build_win/README.txt 一起打包進 zip。
#
# SSOT 提醒——以下三項一律去源頭抓真實值，不要憑印象/上次記憶填：
#   - 版本號          -> autoload/spike_config.gd 的 GAME_VERSION 常數
#   - 按鍵配置        -> autoload/spike_config.gd 的 DEFAULT_KEYS / KEY_NAMES
#   - 免責聲明        -> autoload/spike_config.gd 的 DISCLAIMER_TEXT_BY_LANG（逐字抄，不要重寫）
#   - 存檔路徑        -> project.godot 的 config/name（若有 use_custom_user_dir 要另外查），
#                        預設 Godot 4 規則是 %APPDATA%\Godot\app_userdata\<config/name>\
#                        （可用實跑一次 exe 產生存檔資料夾來驗證，勝過純推導）
#   - 已知問題        -> ../../HANDOFF.md（把內部開發用語翻成玩家看得懂的白話，不要照搬）
#   - 聯絡方式        -> 使用者提供，不可編造
#
# 下面這份「上一版實際內容」留著當格式參考，複製後把 <<VERSION>> 等標記換掉即可。
# 這份範本本身不會被打包進 zip。

========================================
RAORA'S BASEMENT — Windows 下載版
版本 / Version: <<VERSION 例如 0.1.0，去 spike_config.gd GAME_VERSION 抓>>
========================================


【安裝方式】

本遊戲免安裝，解壓縮 zip 後即可執行：
  1. 將整包 zip 解壓縮到任意資料夾（路徑避免中文或特殊符號，以策安全）。
  2. 資料夾內找到 RAORASBasement.exe，直接雙擊執行。
  3. 若 Windows SmartScreen 跳出「已封鎖此應用程式保護您的電腦」，這是未簽署數位
     憑證的獨立開發者遊戲常見現象（本作未購買代碼簽署憑證），非病毒警示。
     可點「其他資訊」→「仍要執行」繼續啟動。

不需要另外安裝任何執行環境或 DirectX / .NET 套件。


【操作說明】

預設鍵盤配置（可在遊戲內「設定」頁面重新綁定）：

  <<逐條去 spike_config.gd 的 DEFAULT_KEYS + KEY_NAMES 抓，照 KEY_ORDER 順序列出
    「中文名稱｜實際按鍵」，目前七項：left/right/aim/jet/watch/item/pause>>

（滑鼠拖曳為可切換的替代輸入模式，預設關閉，可於設定頁開啟。）


【系統需求】

  作業系統：Windows 10 / 11（64 位元）
  顯示卡：需支援 Vulkan 1.0（近十年內多數獨立顯卡與內顯皆支援；若啟動後黑畫面
          或立即當掉，優先更新顯示卡驅動）
  硬碟空間：約 <<實際 zip 解壓後大小，抓 build_win/ 資料夾實測值>> MB 可用空間
  以上為 Godot 4 引擎 Forward+ 渲染管線的一般需求，本作尚未針對特定機型做效能
  基準測試，不同硬體的實際效能表現可能有落差。


【已知問題】

  <<去 ../../HANDOFF.md 最新一節抓「尚未真人試玩」「已知限制」等條目，翻成玩家
    看得懂的白話，不要出現內部開發代號（如 preset 名、稽核名、mutation 等）。
    沒有新增/變動就沿用上一版清單。>>


【存檔位置】

存檔會寫在 Windows 使用者資料夾，與遊戲安裝位置無關（解壓縮到別的地方或刪除
遊戲本體都不會影響存檔）：

  %APPDATA%\Godot\app_userdata\<<project.godot 的 config/name，逐字抄含大小寫與符號>>\

在檔案總管網址列貼上 %APPDATA%\Godot\app_userdata\ 即可快速抵達。資料夾內的
spike_save.json 是進度存檔，spike_keys.json 是自訂按鍵設定；更新版本前建議先
複製整個資料夾備份。


【聯絡方式】

<<使用者提供的聯絡管道，未提供前寫「（待補：使用者的聯絡管道）」，不可編造>>


【免責聲明】

<<去 spike_config.gd 的 DISCLAIMER_TEXT_BY_LANG 逐字抄，至少含 zh + en 兩版；
  若當次上架有指定其他語言玩家群，可視情況多附 ja / id>>
