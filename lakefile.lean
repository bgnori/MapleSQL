import Lake
open Lake DSL

package maplesql where

lean_lib MapleSQL

@[test_driver]
lean_lib MapleSQLTests where
  roots := #[`MapleSQLTests]
