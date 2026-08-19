# COMPLIANCE — hololive 二創合規檢視紀錄

> 適用文件：COVER Corp.「二次創作ガイドライン／二次創作ゲームに関するガイドライン」
> （`https://hololivepro.com/terms/`）。逐項要求住 `checklist.md` §6，本檔只記錄
> **檢視時間點**與**自評結果**，不重複清單本身。
> ⚠ 指南可能無預告修改，COVER 保留隨時要求下架的權利——上架前一週務必重新檢視官方頁面。

## 檢視紀錄

| 檢視日期 | 當時指南改訂日期 | 檢視人 | 備註 |
|---|---|---|---|
| 2026-08-16 | 2025-08-20 改訂版 | AI 盤點（checklist.md 彙整當下） | 首次系統性自評，見下方逐項結果 |

## §6 逐項自評（2026-08-16 當下）

| 項目 | 狀態 | 備註 |
|---|---|---|
| 6.1 完全免費、無變現 | ✅ 符合 | 遊戲內無任何 IAP／廣告／贊助程式碼，itch.io 端「Free＋不開 Donate」屬 §1 手動設定，尚待執行 |
| 6.2 三處非官方聲明 | 🟡 部分 | 標題／工作人員名單頁已加繁中版免責聲明（本次新增）；itch.io 頁面與 README 尚未存在（頁面／README 本身還沒做） |
| 6.2 不用官方 logo／商標字體／官方立繪 | 🟡 待你目視確認 | 現有美術（`assets/sprites/*`）依 `.claude/docs/art-assets.md` 記錄皆為原創／AI 生成，角色命名（Kaela／Chattini／Pameloe／Raora／Dahlah）非官方正式名稱；程式面查不出「是否神似到有爭議」，這是視覺判斷，需你親自過一次 |
| 6.3 個人名義發佈 | ⏳ 未執行 | itch.io username／developer 顯示名稱屬 §1 手動帳號設定，尚未註冊 |
| 6.5 內容紅線 | 🟡 待你確認 | 就目前可見的遊戲內容（爬井、鞭子、buff、干擾機制）未見明顯牴觸；talent 觀感／是否越界屬編輯判斷，非程式可驗證項目 |
| 6.6 THIRD_PARTY_LICENSES.md | ✅ 已建立 | 見 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)，隨新素材增補 |
| 6.6 官方歌曲／語音合成 | ✅ 符合 | 專案目前零音效系統，不涉及官方歌曲或 talent 聲音 |
| 6.7 本檔本身 | ✅ 已建立 | 本次盤點順帶建立 |

## AI 生成內容揭露提醒

專案已知使用 AI 生成美術素材（見 `.claude/skills/import-art-asset/SKILL.md` 定位敘述）。
itch.io Metadata 的 **AI Disclosure** 欄位需勾選揭露，已在 [store/metadata.md](store/metadata.md)
預填，上架時記得帶入實際頁面設定。

## 下次檢視提醒

- [ ] 上架前一週：重新讀一次 `https://hololivepro.com/terms/`，更新上表的「當時指南改訂日期」欄。
- [ ] 每次新增角色／美術／音樂／音效：重跑本檔的 §6 自評（尤其「不用官方素材」那條）。
