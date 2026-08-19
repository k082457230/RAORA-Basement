# THIRD_PARTY_LICENSES — 第三方素材授權清單

> checklist.md §6.6 要求：每一項第三方素材（字型／圖片／插畫／BGM／音效／材質／原始碼／
> Godot 外掛）都要列出來源網址與授權條款。COVER 不會替你解釋第三方條款，缺一項就補一項，
> 不要等上架前才一次補。

| 素材 | 用途 | 授權 | 來源 |
|---|---|---|---|
| Noto Sans CJK TC（`NotoSansCJKtc.otf`，經 `tools/subset_font.py` 子集化） | 遊戲內繁中／英文字型 | SIL Open Font License 1.1（OFL） | Google Noto Fonts |
| Godot Engine | 遊戲引擎 | MIT License | godotengine.org |

## 待補（目前專案已知但尚未在此登記細節的項目）

- [ ] 角色／怪物／道具貼圖（`assets/sprites/*.png`）：依 `.claude/docs/art-assets.md` 為 AI 生成，
      需補「用哪個生成工具／服務」＋該服務的商用授權條款依據。
- [ ] 若之後加入 BGM／音效：逐項補來源與授權（購買授權需附憑證存底，不放在版控但要記得留存）。
- [ ] 若之後加入任何 Godot 外掛（asset library 套件）：補外掛名稱、版本、授權條款。

## 商用／非商用授權判斷提醒

參考 HoloCure 的作法基準：視覺與音樂全為原創、音效全部購買含商用授權版本。本專案目前無音效系統，
暫不適用；一旦加入音效，購買時務必確認授權涵蓋「內嵌進免費遊戲散布」這個使用情境。
