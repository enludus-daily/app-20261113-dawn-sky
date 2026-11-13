# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.008（枠 008。本人が App Store Connect に App を足すのを待っている。2026-11-13 時点で requested） |
| アプリ名 | あさやけ図鑑：起きたら空を集める / Dawn Atlas: Catch the Sky |
| サポート URL | https://github.com/enludus-daily/app-20261113-dawn-sky/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261113-dawn-sky/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」（暴力・性的・ギャンブル・Web 閲覧・利用者どうしのやりとり・生成 AI なし）→ 4+ の見込み。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：目覚まし・タイマー・壁紙ではない。起きた時刻の判定と、撮った空の色の取り出し・図鑑の分類を持つ収集のアプリ
- 既存のアプリとの意味のある違い：空を撮る目覚まし（Wayk など）は止めるための作業で、空は残らない。ここでは撮った空の色が図鑑とパレットに集まり、寝坊は欠けたマスとして見える
- 長く使える価値（4.2）：1 年の輪・季節と日付でしか出ないページ（夏至・冬至・1 月 1 日）・続けた日数のページで、1 年使うほど埋まる
- 他社の名前・商標・見た目を使っていないか：使っていない。部品はすべて自作の Shape / Canvas
- Apple Intelligence：使わない
- カメラ：NSCameraUsageDescription を日本語・英語で。拒否されたら「設定を開く」の案内、カメラのない端末は見本の空で試せる

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro ¥480（`com.enludus.daily.008.pro`、StoreKit 2）。理由と比べた表・勝算の表は README の「課金」
- 商品は TestFlight の前に asc.yml の products で作る（今日は枠 008 が未作成のため未実施）

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない（StoreKit を除く）、解析・広告 SDK なし。写真は色を読むためだけに使い、設定に従って縮めた JPEG をアプリの中（Application Support）にだけ保存。記録は JSON をアプリの中に、設定は UserDefaults に）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
