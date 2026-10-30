# MapleSQL の設計メモ

## 目的と HoneySQL の調査

[HoneySQL の README](https://github.com/seancorfield/honeysql/blob/develop/README.md)
では、SQL を Clojure の map や vector として組み立て、`format` で SQL と
バインド値の列に変換する。README のサンプルには、条件付き SELECT、
複数行 INSERT、式を含む UPDATE、DELETE、JOIN、サブクエリ、UNION、
関数呼び出しなどがある。また、README 内のサンプルはテストとして実行される。

MapleSQL は同じ「値を SQL に埋め込まず、SQL とパラメーターを分けて生成する」
基本動作を Lean 4 で試す。最初の対象は README の SELECT / INSERT / UPDATE /
DELETE の例で、`MapleSQLTests.lean` の `#guard` が SQL 文字列とパラメーターの
順序を検証する。現在は基本句のみであり、JOIN、サブクエリ、方言ごとの構文、
HoneySQL の helper API との互換性は未実装である。

## 動的型付けと Lean のトレードオフ

HoneySQL の map/vector DSL は実行時に組み立てやすく、句の順序を意識せず
追加できる。一方、誤った句や値の形も実行時まで見つからない可能性がある。
Lean の代数的データ型では、文、式、値、述語を明示し、未対応の形を型で
制限できる。たとえば `Statement` の各構築子が対応する文型を区別し、
値は `Value` として SQL パラメーターに分離する。

その代わり、動的な map の柔軟さは減り、構築子や変換関数を定義する初期コストが
増える。Lean の型だけで SQL 方言・テーブルスキーマとの整合性を自動的に保証
できるわけではなく、型付けしたスキーマ表現や方言層は別途設計が必要になる。
現実的には、型で表せる誤りを早期に排除しつつ、条件句などを実行時に合成する
API を提供するのが両者の折衷となる。現在の初期実装は、識別子を二重引用符で
エスケープし、値は `?` と順序付きパラメーターにする。方言は未選択である。

## Mathlib と標準ライブラリ

SQL の AST、文字列整形、配列操作、パラメーター保持には Lean の標準ライブラリ
で足り、定理証明用の Mathlib は現在必要ない。依存を増やさずに済むため、
`lakefile.lean` に Mathlib を追加せず、CI でも Mathlib 用のキャッシュ取得を
行わない。

将来、クエリ変換の性質を証明する必要が出た場合は、必要な Mathlib モジュール
だけを `import` する（たとえば集合の基本 API が必要なら
`Mathlib.Data.Set.Basic`）方針がよい。全モジュールを取り込む `import Mathlib`
は避ける。`Std` や Batteries の追加機能も現状の実装では不要である。

## Lean での CI

`lean-toolchain` で Lean のバージョンを固定し、CI では `leanprover/lean-action`
に `lake build` を実行させる。Lean の `#guard` はコンパイル時に評価結果を
検査するため、独立したテスト実行器なしで SQL とパラメーターの回帰を検出できる。
Action は `.lake` をキャッシュし、Mathlib 依存がないため Mathlib キャッシュ取得は
明示的に無効にする。将来 Mathlib 等を追加した場合は、その依存に対応した
キャッシュを有効化してから、キャッシュヒットを前提としたビルド時間を測定する。
