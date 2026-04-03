# HeartStateLab Scaffold

このディレクトリには、Apple Watch 向けのウェルネス用途アプリの設計メモと、Xcode に組み込める最小実装コードを置いています。

## 目的

- watchOS で心拍をできるだけ高頻度にライブ表示する
- 30〜60 秒の短時間窓で特徴量を計算する
- 軽量なルールベースで状態を推定する
- セッションログを保存し、iPhone 側でも履歴 UI を持てるようにする

## このスキャフォールドに含めたもの

- `docs/FeasibilityAndArchitecture.md`
  - 公開 API の実現可能性整理
  - 推奨アーキテクチャ
  - MVP 実装方針
- `Sources/Shared`
  - 共有モデル
  - スライディング窓
  - 状態推定ロジック
- `Sources/WatchApp`
  - watch 側 UI
  - HealthKit ワークアウト計測
  - watch シミュレータ用のモック心拍ストリーム
  - Core Motion ベースの動き量算出
  - ログ保存
  - 将来の WatchConnectivity 転送土台
- `Sources/iPhoneApp`
  - iPhone 側履歴一覧
  - iPhone 側セッション詳細
  - 履歴 UI

## Xcode での組み込み手順

1. このフォルダの `HeartStateLab.xcodeproj` を Xcode で開きます。
2. もしファイル参照が赤く見える場合は `scripts/setup_build_link.sh` を 1 回実行します。
3. Xcode の Signing で自分の Team を iPhone / Watch 両ターゲットに設定します。
4. 必要なら Bundle Identifier を自分の識別子に変更します。
5. `HeartStateLabWatch` を Apple Watch 実機にビルドします。
6. `HeartStateLabPhone` は iPhone 実機に別アプリとしてビルドします。

## 必要な Capability / Permission

- iPhone ターゲット
  - `HealthKit`
- Watch ターゲット
  - `HealthKit`
  - `Background Modes`

`Info.plist` には最低限以下を入れてください。

- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`
- `NSMotionUsageDescription`

用途メッセージ例:

- Health read: `心拍やワークアウト情報を読み取り、ストレス・回復傾向を推定するために使用します。`
- Health write: `計測セッションをワークアウトとして保存するために使用します。`
- Motion: `動きの大きさを用いて、心拍推定の信頼度を補正するために使用します。`

## 実装上の前提

- 最小コードは `HKWorkoutSession + HKLiveWorkoutBuilder` を使用します。
- watch シミュレータでは HealthKit ライブ心拍の代わりに、状態遷移確認用のモック心拍ストリームを自動使用します。
- `CMHighFrequencyHeartRateData` は将来の差し替え候補として設計上考慮していますが、この初期コードでは未使用です。
- RR 間隔や真の HRV リアルタイム算出は MVP の前提にしていません。
- 現在の実装は `watch 単体インストール優先` です。Apple Watch 側の計測アプリと iPhone 側履歴アプリは、まず別々に動かせる状態にしています。
- iPhone 15 への自動同期は次段の companion / connectivity 整備で追加します。
- プロジェクトは `/tmp/HeartStateLabWorkspace` へのシンボリックリンクを参照します。`/tmp` が消えた場合は `scripts/setup_build_link.sh` を再実行してください。

## 次の拡張候補

- `CMHighFrequencyHeartRateData` による 1 Hz 優先のハートレート供給
- `HKHeartbeatSeriesQuery` を用いたセッション後 RR 解析
- iPhone 側のチャート表示
- セッションメモやタグ付け
