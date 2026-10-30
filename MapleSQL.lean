namespace MapleSQL

inductive Value where
  | text : String → Value
  | integer : Int → Value
  deriving Repr, BEq

inductive Expr where
  | column : String → Expr
  | parameter : Value → Expr
  | add : Expr → Expr → Expr
  deriving Repr, BEq

inductive Predicate where
  | equal : Expr → Expr → Predicate
  | notEqual : Expr → Expr → Predicate
  | greaterThan : Expr → Expr → Predicate
  | and : Array Predicate → Predicate
  deriving Repr, BEq

inductive SelectItem where
  | all : SelectItem
  | named : String → SelectItem
  deriving Repr, BEq

inductive Statement where
  | select : Array SelectItem → String → Option Predicate → Statement
  | insert : String → Array String → Array (Array Value) → Statement
  | update : String → Array (String × Expr) → Option Predicate → Statement
  | delete : String → Option Predicate → Statement
  deriving Repr, BEq

structure Formatted where
  sql : String
  params : Array Value
  deriving Repr, BEq

private def quoteIdentifier (identifier : String) : String :=
  "\"" ++ identifier.replace "\"" "\"\"" ++ "\""

private def renderSelectItem : SelectItem → String
  | .all => "*"
  | .named identifier => quoteIdentifier identifier

private def joinFormatted (separator : String) (parts : Array Formatted) : Formatted :=
  {
    sql := String.intercalate separator (parts.toList.map fun part => part.sql)
    params := parts.foldl (fun params part => params ++ part.params) #[]
  }

private def renderExpr : Expr → Formatted
  | .column name => { sql := quoteIdentifier name, params := #[] }
  | .parameter value => { sql := "?", params := #[value] }
  | .add lhs rhs =>
      let left := renderExpr lhs
      let right := renderExpr rhs
      {
        sql := "(" ++ left.sql ++ " + " ++ right.sql ++ ")"
        params := left.params ++ right.params
      }

private def renderPredicate : Predicate → Except String Formatted
  | .equal lhs rhs =>
      let left := renderExpr lhs
      let right := renderExpr rhs
      .ok { sql := left.sql ++ " = " ++ right.sql, params := left.params ++ right.params }
  | .notEqual lhs rhs =>
      let left := renderExpr lhs
      let right := renderExpr rhs
      .ok { sql := left.sql ++ " <> " ++ right.sql, params := left.params ++ right.params }
  | .greaterThan lhs rhs =>
      let left := renderExpr lhs
      let right := renderExpr rhs
      .ok { sql := left.sql ++ " > " ++ right.sql, params := left.params ++ right.params }
  | .and predicates => do
      if predicates.isEmpty then
        throw "AND requires at least one predicate"
      let parts ← predicates.mapM renderPredicate
      let combined := joinFormatted " AND " parts
      pure { combined with sql := "(" ++ combined.sql ++ ")" }

private def renderWhere (predicate : Option Predicate) : Except String Formatted := do
  match predicate with
  | none => pure { sql := "", params := #[] }
  | some predicate =>
      let formatted ← renderPredicate predicate
      pure { formatted with sql := " WHERE " ++ formatted.sql }

private def renderInsertRow (row : Array Value) : Formatted :=
  let values := row.map fun value => { sql := "?", params := #[value] }
  let formatted := joinFormatted ", " values
  { formatted with sql := "(" ++ formatted.sql ++ ")" }

def render : Statement → Except String Formatted
  | .select columns table predicate => do
      if columns.isEmpty then
        throw "SELECT requires at least one column"
      let whereClause ← renderWhere predicate
      pure {
        sql := "SELECT " ++ String.intercalate ", " (columns.toList.map renderSelectItem) ++
          " FROM " ++ quoteIdentifier table ++ whereClause.sql
        params := whereClause.params
      }
  | .insert table columns rows => do
      if columns.isEmpty then
        throw "INSERT requires at least one column"
      if rows.isEmpty then
        throw "INSERT requires at least one row"
      if !rows.all (fun row => row.size == columns.size) then
        throw "INSERT row width must match the column count"
      let renderedRows := rows.map renderInsertRow
      let values := joinFormatted ", " renderedRows
      pure {
        sql := "INSERT INTO " ++ quoteIdentifier table ++ " (" ++
          String.intercalate ", " (columns.toList.map quoteIdentifier) ++
          ") VALUES " ++ values.sql
        params := values.params
      }
  | .update table assignments predicate => do
      if assignments.isEmpty then
        throw "UPDATE requires at least one assignment"
      let whereClause ← renderWhere predicate
      let renderedAssignments := assignments.map fun (name, value) =>
        let formatted := renderExpr value
        { formatted with sql := quoteIdentifier name ++ " = " ++ formatted.sql }
      let assignments := joinFormatted ", " renderedAssignments
      pure {
        sql := "UPDATE " ++ quoteIdentifier table ++ " SET " ++ assignments.sql ++ whereClause.sql
        params := assignments.params ++ whereClause.params
      }
  | .delete table predicate => do
      let whereClause ← renderWhere predicate
      pure {
        sql := "DELETE FROM " ++ quoteIdentifier table ++ whereClause.sql
        params := whereClause.params
      }

end MapleSQL
