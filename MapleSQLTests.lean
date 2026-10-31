import Lean
import MapleSQL

open MapleSQL

def rendersAs (statement : Statement) (expectedSql : String) (expectedParams : Array Value) : Bool :=
  match render statement with
  | .ok formatted => formatted.sql == expectedSql && formatted.params == expectedParams
  | .error _ => false

def failsWith (statement : Statement) (expectedError : String) : Bool :=
  match render statement with
  | .ok _ => false
  | .error message => message == expectedError

def readExample : Statement :=
  .select #[.named "id", .named "name"] "users"
    (.some (.equal (.column "active") (.parameter (.integer 1))))

#guard rendersAs readExample
  "SELECT \"id\", \"name\" FROM \"users\" WHERE \"active\" = ?"
  #[.integer 1]

def insertExample : Statement :=
  .insert "properties" #["name", "surname", "age"]
    #[#[.text "Jon", .text "Smith", .integer 34],
      #[.text "Jane", .text "Daniels", .integer 56]]

#guard rendersAs insertExample
  "INSERT INTO \"properties\" (\"name\", \"surname\", \"age\") VALUES (?, ?, ?), (?, ?, ?)"
  #[.text "Jon", .text "Smith", .integer 34, .text "Jane", .text "Daniels", .integer 56]

def updateExample : Statement :=
  .update "films"
    #[("kind", .parameter (.text "dramatic")),
      ("watched", .add (.column "watched") (.parameter (.integer 1)))]
    (.some (.equal (.column "kind") (.parameter (.text "drama"))))

#guard rendersAs updateExample
  "UPDATE \"films\" SET \"kind\" = ?, \"watched\" = (\"watched\" + ?) WHERE \"kind\" = ?"
  #[.text "dramatic", .integer 1, .text "drama"]

def deleteExample : Statement :=
  .delete "films" (.some (.notEqual (.column "kind") (.parameter (.text "musical"))))

#guard rendersAs deleteExample
  "DELETE FROM \"films\" WHERE \"kind\" <> ?"
  #[.text "musical"]

#guard failsWith (.select #[] "users" none)
  "SELECT requires at least one column"
#guard rendersAs
  (.select #[.all] "foo"
    (.some (.and #[
      .equal (.column "a") (.parameter (.integer 1)),
      .greaterThan (.column "b") (.parameter (.integer 10))])))
  "SELECT * FROM \"foo\" WHERE (\"a\" = ? AND \"b\" > ?)"
  #[.integer 1, .integer 10]
#guard failsWith (.select #[.all] "foo" (.some (.and #[])))
  "AND requires at least one predicate"
#guard failsWith (.insert "t" #["a", "b"] #[#[.integer 1]])
  "INSERT row width must match the column count"
#guard rendersAs
  (.select #[.named "odd\"name"] "users" none)
  "SELECT \"odd\"\"name\" FROM \"users\""
  #[]
