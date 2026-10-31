import Lake
open Lake DSL

package maplesql where

lean_lib MapleSQL

lean_lib MapleSQLTests where
  roots := #[`MapleSQLTests]
