# StateLensHeart Release Readiness

## バージョン
- `MARKETING_VERSION`: `1.1.0`
- `CURRENT_PROJECT_VERSION`: `2`

## リリース前チェック
- iPhone 15 / Apple Watch 11 (42mm) 実機でWatchコンパニオン動作確認
- HealthKit / Motion の許可説明文に「医療診断用途ではない」旨を明記
- ユーザー別の履歴分離、ベースライン分離、ライブ表示分離を確認
- 感情推定・自律神経スコア・イベントログが履歴に残ることを確認
- リアルタイム受信の重複排除と順序乱れ耐性を確認

## ストア説明向け注意
- 感情・状態は推定であり診断ではない
- 医療目的ではなくウェルネス支援目的であることを明示
