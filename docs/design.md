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

## HoneySQL の用途と MapleSQL の現実的な範囲

HoneySQL の中心的な役割は、Clojure のデータ構造から実行可能な SQL と順序付き
パラメーターを生成することにある。生成した SQL は `next.jdbc` などの別の
ライブラリに渡す設計であり、接続管理、SQL の実行、結果のオブジェクト化は
担当しない。したがって MapleSQL でも、まずはクエリ生成器を目標とし、DB
ドライバーや ORM までを同じ機能範囲に含めないのが自然である。

公開されている利用例からは、次のような層で使われていることが分かる。

- アプリケーションのデータアクセス層で、実行時の条件に応じてクエリを組み立て、
  パラメーター化した SQL を JDBC に渡す。
- Toucan のようなモデル／ORM 層で、モデル操作を SQL に変換する基盤として使う。
- HoneyEQL のようなライブラリで、関連データを宣言的なクエリから SQL に変換し、
  ネストした結果形状を取得する下位層として使う。関連の解決や結果の組み立ては
  HoneySQL そのものではなく、上位ライブラリの責務である。
- PostgreSQL 拡張のように、基本的な SQL 生成に特定 DB の構文や関数を追加する。

HoneySQL の句リファレンスには、基本的な SELECT / INSERT / UPDATE / DELETE
だけでなく、JOIN、集約、サブクエリ、CTE、ウィンドウ関数、DDL、UPSERT なども
記載されている。この広さは、SQL の各要素をデータ構造として合成するモデルと
相性がよい。一方、全ての句や DB 方言を一度に再現するのは、MapleSQL の最初の
実用目標としては大きすぎる。

### 機能の段階

| 段階 | 対象 | MapleSQL での見通し |
| --- | --- | --- |
| 現在 | SELECT / INSERT / UPDATE / DELETE、基本比較と AND、加算式、値のパラメーター化 | 実装済み。現状のテストは SQL とパラメーター順序を検証する。 |
| 無理なく次に広げられる範囲 | OR / NOT、NULL・IN・LIKE 等の述語、列別名、JOIN、ORDER BY、LIMIT / OFFSET、GROUP BY / HAVING | 既存の AST と整形器を少しずつ拡張すれば対応可能。機能ごとに AST、レンダラー、境界条件のテストが必要。 |
| 中規模の拡張 | サブクエリ、CTE、UNION、関数・CAST、RETURNING、UPSERT | 値の順序や句のネストを保つ仕組みは再利用できるが、式の種類と文構造が増える。RETURNING や UPSERT は DB ごとの差を明示する必要がある。 |
| 後回しが妥当 | 広範な DDL、複数 DB の完全な方言互換、ウィンドウ関数、DB 固有の JSON / 配列演算、HoneySQL の helper API 互換 | 実現は可能だが、構文仕様・方言差・回帰テストが大きく増える。対象 DB と利用要件を決めてから追加するのがよい。 |
| 別プロジェクト相当 | DB 接続・実行、スキーマの自動検証、ORM、EQL からの関連解決、結果のネスト化 | SQL 生成の外側にある責務。必要になった場合も、まず生成器と分離した層として設計する。 |

したがって、無理のない実用上の到達点は「単一の SQL 方言を対象にした、型付きの
クエリ構築・整形ライブラリ」である。基本 CRUD に加えて、よくある絞り込み、
JOIN、並べ替え、ページング、集約までなら、現在の「AST を定義し、パラメーター
付き SQL に整形する」設計の延長で段階的に実装できる。サブクエリや CTE も十分
射程に入るが、方言の全面対応や HoneySQL との完全互換は別の規模の目標となる。

実装順としては、まず述語と式を拡充し、その後 SELECT の JOIN・集約・ページング、
次にサブクエリ等の入れ子構造を追加するのがよい。最初は方言を一つに固定し、
各追加機能について生成 SQL、パラメーターの個数と順序、不正な入力のエラーを
テストする。方言対応は、具体的な利用先が決まってから差分を小さな機能単位で
加える。現在は `?` プレースホルダーと二重引用符による識別子引用を使っている
ため、方言を増やす際にはプレースホルダー形式や識別子規則も方言設定に含める
必要がある。

### 調査した資料と利用例

- [HoneySQL README（2.8.85）](https://cljdoc.org/d/com.github.seancorfield/honeysql/2.8.85/doc/readme) — SQL とパラメーターの生成、JDBC への接続、方言サポート。
- [HoneySQL の SQL clause reference](https://github.com/seancorfield/honeysql/blob/develop/doc/clause-reference.md) — 対応する SQL / DDL 句と例。
- [Metabase Toucan](https://github.com/metabase/toucan) — HoneySQL を使うモデル／ORM 層の例。
- [HoneyEQL](https://github.com/tamizhvendan/honeyeql) — EQL から関連データを問い合わせる上位層の例。
- [honeysql-postgres](https://github.com/nilenso/honeysql-postgres) — PostgreSQL 固有の拡張例。

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
に `lake test` を実行させる。`MapleSQLTests` を Lake の test driver として登録し、
Lean の `#guard` がコンパイル時に評価結果を検査するため、独立したテスト実行器
なしで SQL とパラメーターの回帰を検出できる。
Action は `.lake` をキャッシュし、Mathlib 依存がないため Mathlib キャッシュ取得は
明示的に無効にする。将来 Mathlib 等を追加した場合は、その依存に対応した
キャッシュを有効化してから、キャッシュヒットを前提としたビルド時間を測定する。
