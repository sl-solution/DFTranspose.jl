# DFTranspose.jl

This is a temporary package to explore the implementation of reshaping `DataFrames` objects in `Julia` (JuliaData/DataFrames.jl/issues/#2732).
# permutedims

`df_transpose(df::AbstractDataFrame, cols)` is similar to `permutedims()` with some flexibility.

* `df_transpose` only permutes the columns `cols`.
* If no variable is provided as `id`, it generates the column names of the new data set by mapping a function (`colid`) on the sequence of rows in `df`.
* A function (`rowid`) applied to the row id in the output data frame before generating the `variable_name` columns.
* If `id` is set from a column in `df`, it applies `colid` on the stringified values of `id` and uses the result as the column names for the new data frame.

## Examples

```jldoctest
julia> df = DataFrame(x1 = [9,2,8,6,8], x2 = [8,1,6,2,3], x3 = [6,5,3,10,8])
5×3 DataFrame
 Row │ x1     x2     x3
     │ Int64  Int64  Int64
─────┼─────────────────────
   1 │     9      8      6
   2 │     2      1      5
   3 │     8      6      3
   4 │     6      2     10
   5 │     8      3      8

julia> df_transpose(df, r"x")
3×6 DataFrame
 Row │ _variables_  _c1    _c2    _c3    _c4    _c5
     │ String       Int64  Int64  Int64  Int64  Int64
─────┼────────────────────────────────────────────────
   1 │ x1               9      2      8      6      8
   2 │ x2               8      1      6      2      3
   3 │ x3               6      5      3     10      8

julia> df_transpose(df, r"x", rowid = x -> match(r"[0-9]+",x).match, colid = x -> "_column_" * string(x))
3×6 DataFrame
 Row │ _variables_  _column_1  _column_2  _column_3  _column_4  _column_5
     │ SubString…   Int64      Int64      Int64      Int64      Int64
─────┼────────────────────────────────────────────────────────────────────
   1 │ 1                    9          2          8          6          8
   2 │ 2                    8          1          6          2          3
   3 │ 3                    6          5          3         10          8


julia> df1 = DataFrame(a=["x", "y"], b=[1.0, 2.0], c=[3, 4], d=[true, false])
2×4 DataFrame
 Row │ a       b        c      d
     │ String  Float64  Int64  Bool
─────┼───────────────────────────────
   1 │ x           1.0      3   true
   2 │ y           2.0      4  false

julia> t_function(df, [:b, :c, :d], id = :a) # note the column types
3×3 DataFrame
 Row │ _variables_  x        y
     │ String       Float64  Float64
─────┼───────────────────────────────
   1 │ b                1.0      2.0
   2 │ c                3.0      4.0
   3 │ d                1.0      0.0


julia> df2 = DataFrame(a=["x", "y"], b=[1, "two"], c=[3, 4], d=[true, false])
2×4 DataFrame
 Row │ a       b    c      d
     │ String  Any  Int64  Bool
─────┼───────────────────────────
   1 │ x       1        3   true
   2 │ y       two      4  false

julia> df_transpose(df2, [:b, :c, :d], id = :a, variable_name = "new_col")
3×3 DataFrame
 Row │ new_col  x     y
     │ String   Any   Any
─────┼──────────────────────
   1 │ b        1     two
   2 │ c        3     4
   3 │ d        true  false
```

# stack
`df_transpose(df::AbstractDataFrame, cols, gcols)` can be used to emulate `stack` functionalities.

## Examples
```jldoctest
julia> df = DataFrame(a = repeat(1:3, inner = 2),
                             b = repeat(1:2, inner = 3),
                             c = repeat(1:1, inner = 6),
                             d = repeat(1:6, inner = 1),
                             e = string.('a':'f'))
6×5 DataFrame
 Row │ a      b      c      d      e
     │ Int64  Int64  Int64  Int64  String
─────┼────────────────────────────────────
   1 │     1      1      1      1  a
   2 │     1      1      1      2  b
   3 │     2      1      1      3  c
   4 │     2      2      1      4  d
   5 │     3      2      1      5  e
   6 │     3      2      1      6  f

julia> df_transpose(df, [:c, :d], Not([:c, :d]), variable_name = "variable", colid = x -> "value")
12×5 DataFrame
 Row │ a      b      e       variable  value
     │ Int64  Int64  String  String    Int64?
─────┼────────────────────────────────────────
   1 │     1      1  a       c              1
   2 │     1      1  a       d              1
   3 │     1      1  b       c              1
   4 │     1      1  b       d              2
   5 │     2      1  c       c              1
   6 │     2      1  c       d              3
   7 │     2      2  d       c              1
   8 │     2      2  d       d              4
   9 │     3      2  e       c              1
  10 │     3      2  e       d              5
  11 │     3      2  f       c              1
  12 │     3      2  f       d              6

julia> insertcols!(df, 1, :RowID => 1:nrow(df))
julia> df_transpose(df, [:c, :d], [:RowID, :a])
12×4 DataFrame
 Row │ RowID  a      _variables_  _c1
     │ Int64  Int64  String       Int64?
─────┼───────────────────────────────────
   1 │     1      1  c                 1
   2 │     1      1  d                 1
   3 │     2      1  c                 1
   4 │     2      1  d                 2
   5 │     3      2  c                 1
   6 │     3      2  d                 3
   7 │     4      2  c                 1
   8 │     4      2  d                 4
   9 │     5      3  c                 1
  10 │     5      3  d                 5
  11 │     6      3  c                 1
  12 │     6      3  d                 6
```

# unstack

`df_transpose(df::AbstractDataFrame, cols, gcols)` can be used to emulate `unstack` functionalities.
