# StateLensHeart

StateLensHeart は、iPhone 本体アプリ `StateLensHeart` と Apple Watch コンパニオンアプリ `StateLensHeart Watch App` で構成される心拍モニタリングアプリです。

## 構成

- iPhone ターゲット: `StateLensHeart`
- Apple Watch ターゲット: `StateLensHeart Watch App`
- Watch app は iPhone app に `Embed Watch Content` で組み込まれる
- Watch 側は `WKCompanionAppBundleIdentifier` で iPhone app に紐付いている

## 対応方針

- Apple Watch Series 7 / 8 は `watchOS 10 以上` を確認対象とする
- `WATCHOS_DEPLOYMENT_TARGET` は `10.0` を維持する
- `watchOS 9` 対応は今回の対象外

## 2026-04-05 時点の確認結果

- iPhone 側アプリは Xcode から実機インストール可能
- Apple Watch Series 7 実機で `StateLensHeart Watch App` の起動を確認
- Series 7 実機が Xcode の `Product > Destination` に出ない主因は、Watch 側の `Developer Mode` 未有効だった
- Apple Watch 側で `Developer Mode` を有効化後、Xcode から Watch app のインストールに成功

## 本日の変更点

- Series 7 / 8 確認方針を `watchOS 10 以上` に整理
- QA 観点として Series 7 / 8 の 41mm / 45mm UI 確認項目を追加
- Mac 側で `StateLensHeart` 関連の Xcode キャッシュを整理し、実機認識の切り分けを実施
- 実機接続の調査結果として、「Apple Watch 側 `Developer Mode` が Xcode 利用の前提条件」であることを確認

## Apple Watch 実機接続メモ

Apple Watch を Xcode の開発用実機として使うには、少なくとも次を満たす必要があります。

- iPhone が Xcode に接続済みである
- 対象 Apple Watch がその iPhone とペアされている
- Apple Watch 側で `Developer Mode` が有効になっている

`Devices and Simulators` に Watch が見えていても `Developer Mode disabled` が出ている場合は、Watch 側の `設定 > プライバシーとセキュリティ > Developer Mode` を有効化してから再確認します。

## 関連ドキュメント

- [RELEASE_READINESS.md](/Users/mahiro/Desktop/Antigravity/AppleWatch＆iPhone心拍取得モニタリングアプリ/StateLens-Heart-repo/RELEASE_READINESS.md)
- [QA_TEST_CHECKLIST.md](/Users/mahiro/Desktop/Antigravity/AppleWatch＆iPhone心拍取得モニタリングアプリ/StateLens-Heart-repo/QA_TEST_CHECKLIST.md)
- [PROJECT_STRUCTURE.md](/Users/mahiro/Desktop/Antigravity/AppleWatch＆iPhone心拍取得モニタリングアプリ/StateLens-Heart-repo/PROJECT_STRUCTURE.md)
