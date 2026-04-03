# 実現可能性まとめ

前提デバイス:

- Watch: Apple Watch Series 11
- Watch OS: watchOS 26.2
- Phone: iPhone 15

この構成では、watch 側のリアルタイム計測と軽量推定、iPhone 側の履歴確認は十分現実的です。

## 1. 技術判断

### MVP で保証すること

- watchOS のワークアウトセッション中に、`HKLiveWorkoutBuilder` 経由でライブ心拍を受け取り、Watch 画面へ即時反映する
- watch 側で 30〜60 秒のスライディング窓を持ち、特徴量計算と軽量ルールベース推定をリアルタイム実行する
- Core Motion の動き量を併用し、静止中かどうかや低信頼時の `unknown` 判定を作る
- watch 側でログ保存し、セッション終了後に iPhone 側へ転送して履歴表示する

### 実機検証後に昇格すること

- `CMHighFrequencyHeartRateData` が対象実機で安定利用できるなら、1 Hz 優先の心拍パイプラインへ差し替える
- Core Motion 側 confidence を状態推定の confidence に取り込む
- RR 系列の後処理解析を追加する

### MVP では保証しないこと / 要確認

- `HKLiveWorkoutBuilder` だけで「厳密に毎秒 1 回」心拍が来るとはみなしません
- RR 間隔の低遅延ライブストリームは、MVP 前提にしない方が安全です
- HealthKit の `HRV(SDNN)` は取得できますが、公開 API 上は「ライブ連続値」として設計しない方が安全です
- `CMHighFrequencyHeartRateData` は 1 Hz 心拍と confidence を扱える候補ですが、実際の導入可否は対象 watchOS / 端末で要確認です

### RR 間隔 / HRV まわりの判断

- HealthKit は `HKDataTypeIdentifierHeartbeatSeries` と `HKHeartbeatSeriesQuery` を持つため、心拍系列そのものへ後追いでアクセスする道はあります
- ただし、RR 間隔の低遅延ライブ API として扱えることは、今回確認した公開資料からは前提化しません
- よって MVP では「真の RR ベース HRV」ではなく、短時間 HR 変動・HR 傾き・動き量・有効率で自律神経寄りの状態を推定します

### watch 単体か iPhone 連携か

- 計測・特徴量計算・状態推定は watch 単体で完結させます
- iPhone 15 は companion として履歴保存・一覧・将来の再解析を担当させます
- したがって、実装判断は `watch-first, iPhone-optional for viewing and sync` です

## 2. 推奨アーキテクチャ

### watchOS app の構成

- `WorkoutSessionManager`
  - HealthKit 権限要求
  - `HKWorkoutSession` 開始 / 停止
  - `HKLiveWorkoutBuilder` からライブ心拍受信
- `MotionSignalProvider`
  - `CMMotionManager` で 1 秒ごとの動き量を取得
  - 静止フラグを生成
- `SlidingHeartWindow`
  - 30〜60 秒窓のサンプル保持
  - 特徴量算出
- `StateEstimator`
  - ルールベース推定
  - low confidence 時に `unknown`
- `SessionLogStore`
  - watch ローカル JSON 保存
- `ConnectivityBridge`
  - 終了セッションを iPhone へ転送

### iPhone app の構成

- `HistoryStore`
  - WatchConnectivity でログ受信
  - アプリローカル保存
  - 一覧読み込み
- `HistoryView`
  - セッション一覧
  - 最新状態とサンプル数を確認
  - セッション詳細を確認

### API の使い分け

- `HealthKit`
  - 心拍、ワークアウト、将来の HRV / heartbeat series 読み出し
- `HKWorkoutSession`
  - watch 側バックグラウンド継続計測の土台
- `HKLiveWorkoutBuilder`
  - ライブ心拍の実装第一弾
- `Core Motion`
  - 動き量、静止中フラグ、アーチファクト補助指標
- `WatchConnectivity`
  - 終了ログを iPhone に渡す

### データフロー図を文章で説明

1. ユーザーが Watch で計測開始
2. watch アプリが HealthKit 権限を確認し、`HKWorkoutSession` と `HKLiveWorkoutBuilder` を開始
3. 心拍更新が来るたびに、直近の motion 指標と結合して `HeartSample` を生成
4. `SlidingHeartWindow` が直近 45 秒のデータから特徴量を計算
5. `StateEstimator` が `calm / focused / aroused / stressed_like / unknown` を推定
6. Watch UI が「最新心拍」「現在状態」「confidence」を更新する
7. 途中ログは watch ローカルに保存される
8. iPhone 15 が接続可能なら、計測停止時に確定セッションを転送する
9. iPhone 側が履歴として保持し、あとから一覧と詳細を表示する

## 3. MVP 実装方針

### MVP の範囲

- Watch で計測開始 / 停止
- 心拍ライブ表示
- 45 秒窓で特徴量計算
- 5 クラス状態表示
- confidence しきい値未満なら `unknown`
- セッションログ保存
- iPhone 側で履歴一覧表示
- iPhone 側で簡易詳細表示

### 心拍更新の扱い

- 初版は `HKLiveWorkoutBuilder` 更新に追従する
- UI は「最後に取得した心拍」を即時表示する
- 仕様上は「毎秒固定更新」ではなく「可能な限り高頻度のライブ更新」と表現する
- 将来的に `CMHighFrequencyHeartRateData` が対象環境で安定利用できるなら、心拍供給源を差し替えて 1 Hz 優先へ移行する

### 品質評価

- motion が大きい
- 有効サンプル率が低い
- サンプル数が少ない

この 3 条件で confidence を下げ、判定不能を返しやすくします。

## 4. 推定ロジック案

### 特徴量

- `meanHR`
- `shortTermVariation`
- `heartRateSlopePerMinute`
- `motionMean`
- `stationaryRatio`
- `validRatio`

### クラス

- `calm`
  - 低〜中 HR
  - 低 motion
  - 低傾き
- `focused`
  - 中 HR
  - 低 motion
  - 変動小さめ
- `aroused`
  - HR 高めまたは上昇
  - motion 高め
- `stressed_like`
  - HR 高め
  - motion 低め
  - 変動が硬い
- `unknown`
  - confidence 不足
  - サンプル不足

## 5. 実装計画

### プロジェクト構成

- iPhone App target
- Watch App target
- Shared group

### entitlement / capability / permission

- HealthKit
- Background Modes
- Watch Connectivity
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`
- `NSMotionUsageDescription`

### 主要クラス

- `WorkoutSessionManager`
- `MotionSignalProvider`
- `SlidingHeartWindow`
- `StateEstimator`
- `SessionLogStore`
- `ConnectivityBridge`
- `HistoryStore`

### 画面構成

- Watch
  - 現在心拍
  - 現在状態
  - confidence
  - start / stop
- iPhone
  - セッション履歴一覧
  - 最新推定結果

### ログ保存

- watch: `Application Support/Sessions/<uuid>.json`
- iPhone 15: 受信後に `Application Support/ReceivedSessions/<uuid>.json` で保持

### テスト計画

- 共有ロジックのユニットテスト
  - 窓計算
  - 特徴量
  - ルールベース推定
- 手動検証
  - 静止状態
  - 腕振り
  - 軽い歩行
  - 計測開始 / 停止連打
  - 権限拒否時

### App Review で注意する点

- 医療診断表現を避ける
- 「気分を診断する」とは書かない
- `stress tendency` や `recovery tendency` のようなウェルネス表現にとどめる
- 取得データ、保存目的、端末内 / iPhone 保存の説明を明確にする
- バックグラウンド実行は workout 計測の文脈で説明できる状態にする

## 6. ここまでの整合性確認

- watch 単体優先と iPhone 連携は矛盾していません
- RR / HRV を将来拡張に回したので、MVP と公開 API 制約の間に矛盾はありません
- 1 秒固定更新ではなく「高頻度ライブ表示」に落としたため、初版の `HKLiveWorkoutBuilder` 実装と仕様が一致しています
- 将来の `CMHighFrequencyHeartRateData` 差し替え余地を残しているため、Series 11 / watchOS 26.2 の実機検証を次段に安全に回せます
