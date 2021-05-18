# DFTranspose.jl

`DFTranspose.jl` is a `Julia` package to explore the implementation of a new function for reshaping `DataFrame`s.

See https://github.com/JuliaData/DataFrames.jl/issues/2732#issue-865607582

## Installation

run the following code inside a `Julia` session.

```julia
julia> using Pkg
julia> Pkg.add(url = "https://github.com/sl-solution/DFTranspose.jl")
```

# Introduction

The `DFTranspose.jl` package only exports one function, `df_transpose`, which can be used to reshape a `DataFrame`.

```
   df_transpose(df, cols [, groupbycols]; kwargs...)
```

In its simplest form `df_transpose` transposes the specified columns, `cols`, of a `DataFrame`, and attaches a new column to the output data frame to track the original names of the transposed variables. The label of this column can be controlled by `variable_name` keyword.

![Simple Transposing](/images/simple-transpose.svg)

When an `id` variable is specified, `df_transpose` transpose the data as above, however, it uses the values of the `id` variable to label the columns of the output data frame. `renamecolid` can be used to modify these labels on fly. When there are multiple `id` variables, the default `renamecolid` function assigns each label by a Tuple of the values of those variables (see examples).

When a set of groupby variables, `groupbycols`, are specified, the `df_transpose` function repeats the simple transposing of data within each group constructed by groupby variables. Like the simplest case, an `id` variable can be used to label the columns of the output data frame.

**The following behaviours may change in future**
> * The order of the output data frame is based on the order returned by `groupby` function.
> * The order of columns labels is based on their order of appearance in the original data.
> * Currently if `id` value(s) is repeated within a group, `df_transpose` throws an error.
> * Missing values can be a group level or a value for the `id` variable. They will be treated as a category.

![Groupby Transposing](/images/groupby-transpose.svg)

## Examples

**Basic usage**

```julia
julia> df = DataFrame(x1 = [1,2,3,4], x2 = [1,4,9,16])
 4×2 DataFrame
 Row │ x1     x2    
     │ Int64  Int64
─────┼──────────────
   1 │     1      1
   2 │     2      4
   3 │     3      9
   4 │     4     16

julia> df_transpose(df, [:x1,:x2])
2×5 DataFrame
 Row │ _variables_  _c1    _c2    _c3    _c4   
     │ String       Int64  Int64  Int64  Int64
─────┼─────────────────────────────────────────
   1 │ x1               1      2      3      4
   2 │ x2               1      4      9     16
```

**Specifying ID variable**

```julia
julia> df = DataFrame(id = ["r1", "r2", "r3" , "r4"], x1 = [1,2,3,4], x2 = [1,4,9,16])
4×3 DataFrame
 Row │ id      x1     x2    
     │ String  Int64  Int64
─────┼──────────────────────
   1 │ r1          1      1
   2 │ r2          2      4
   3 │ r3          3      9
   4 │ r4          4     16

julia> df_transpose(df, [:x1,:x2], id = :id)
2×5 DataFrame
 Row │ _variables_  r1     r2     r3     r4    
     │ String       Int64  Int64  Int64  Int64
─────┼─────────────────────────────────────────
   1 │ x1               1      2      3      4
   2 │ x2               1      4      9     16
```

**Specifying groupby variables**

```julia
julia> df = DataFrame(group = repeat(1:3, inner = 2),
                             b = repeat(1:2, inner = 3),
                             c = repeat(1:1, inner = 6),
                             d = repeat(1:6, inner = 1),
                             e = string.('a':'f'))
6×5 DataFrame
Row │ group  b      c      d      e      
    │ Int64  Int64  Int64  Int64  String
────┼────────────────────────────────────
  1 │     1      1      1      1  a
  2 │     1      1      1      2  b
  3 │     2      1      1      3  c
  4 │     2      2      1      4  d
  5 │     3      2      1      5  e
  6 │     3      2      1      6  f

julia> df_transpose(df, 2:4, [:group])
9×4 DataFrame
 Row │ group  _variables_  _c1     _c2    
     │ Int64  String       Int64?  Int64?
─────┼────────────────────────────────────
   1 │     1  b                 1       1
   2 │     1  c                 1       1
   3 │     1  d                 1       2
   4 │     2  b                 1       2
   5 │     2  c                 1       1
   6 │     2  d                 3       4
   7 │     3  b                 2       2
   8 │     3  c                 1       1
   9 │     3  d                 5       6

julia> df_transpose(df, 2:4, :group, id = :e)
9×8 DataFrame
 Row │ group  _variables_  a        b        c        d        e        f       
     │ Int64  String       Int64?   Int64?   Int64?   Int64?   Int64?   Int64?  
─────┼──────────────────────────────────────────────────────────────────────────
   1 │     1  b                  1        1  missing  missing  missing  missing
   2 │     1  c                  1        1  missing  missing  missing  missing
   3 │     1  d                  1        2  missing  missing  missing  missing
   4 │     2  b            missing  missing        1        2  missing  missing
   5 │     2  c            missing  missing        1        1  missing  missing
   6 │     2  d            missing  missing        3        4  missing  missing
   7 │     3  b            missing  missing  missing  missing        2        2
   8 │     3  c            missing  missing  missing  missing        1        1
   9 │     3  d            missing  missing  missing  missing        5        6

julia> df_transpose(df, 2:4, :group, id = :e, default_fill = 0)
9×8 DataFrame
 Row │ group  _variables_  a      b      c      d      e      f
     │ Int64  String       Int64  Int64  Int64  Int64  Int64  Int64
─────┼──────────────────────────────────────────────────────────────
   1 │     1  b                1      1      0      0      0      0
   2 │     1  c                1      1      0      0      0      0
   3 │     1  d                1      2      0      0      0      0
   4 │     2  b                0      0      1      2      0      0
   5 │     2  c                0      0      1      1      0      0
   6 │     2  d                0      0      3      4      0      0
   7 │     3  b                0      0      0      0      2      2
   8 │     3  c                0      0      0      0      1      1
   9 │     3  d                0      0      0      0      5      6
```

**Advanced usage**

```julia
julia> pop = DataFrame(country = ["c1","c1","c2","c2","c3","c3"],
                        sex = ["male", "female", "male", "female", "male", "female"],
                        pop_2000 = [100, 120, 150, 155, 170, 190],
                        pop_2010 = [110, 120, 155, 160, 178, 200],
                        pop_2020 = [115, 130, 161, 165, 180, 203])
6×5 DataFrame
 Row │ country  sex     pop_2000  pop_2010  pop_2020
     │ String   String  Int64     Int64     Int64    
─────┼───────────────────────────────────────────────
   1 │ c1       male         100       110       115
   2 │ c1       female       120       120       130
   3 │ c2       male         150       155       161
   4 │ c2       female       155       160       165
   5 │ c3       male         170       178       180
   6 │ c3       female       190       200       203

julia> df_transpose(pop, r"pop_", :country, id = :sex, variable_name = "year",
                renamerowid = x -> match(r"[0-9]+",x).match, renamecolid = x -> x * "_pop")
9×4 DataFrame
  Row │ country  year       male_pop  female_pop
      │ String   SubStrin…  Int64?    Int64?     
 ─────┼──────────────────────────────────────────
    1 │ c1       2000            100         120
    2 │ c1       2010            110         120
    3 │ c1       2020            115         130
    4 │ c2       2000            150         155
    5 │ c2       2010            155         160
    6 │ c2       2020            161         165
    7 │ c3       2000            170         190
    8 │ c3       2010            178         200
    9 │ c3       2020            180         203

julia> using Dates
julia> df = DataFrame([[1, 2, 3], [1.1, 2.0, 3.3],[1.1, 2.1, 3.0],[1.1, 2.0, 3.2]]
                    ,[:person, Symbol("11/2020"), Symbol("12/2020"), Symbol("1/2021")])
3×4 DataFrame
Row │ person   11/2020  12/2020  1/2021  
    │ Float64  Float64  Float64  Float64
────┼────────────────────────────────────
  1 │     1.0      1.1      1.1      1.1
  2 │     2.0      2.0      2.1      2.0
  3 │     3.0      3.3      3.0      3.2

julia> df_transpose(df, Not(:person), :person,
                           variable_name = "Date",
                           renamerowid = x -> Date(x, dateformat"m/y"),
                           renamecolid = x -> "measurement")
   9×3 DataFrame
 Row │ person   Date        measurement
     │ Float64  Date        Float64    
─────┼──────────────────────────────────
   1 │     1.0  2020-11-01          1.1
   2 │     1.0  2020-12-01          1.1
   3 │     1.0  2021-01-01          1.1
   4 │     2.0  2020-11-01          2.0
   5 │     2.0  2020-12-01          2.1
   6 │     2.0  2021-01-01          2.0
   7 │     3.0  2020-11-01          3.3
   8 │     3.0  2020-12-01          3.0
   9 │     3.0  2021-01-01          3.2          

julia> df = DataFrame(region = repeat(["North","North","South","South"],2),
             fuel_type = repeat(["gas","coal"],4),
             load = rand(8),
             time = [1,1,1,1,2,2,2,2],
             )
8×4 DataFrame
  Row │ region  fuel_type  load      time  
      │ String  String     Float64   Int64
 ─────┼────────────────────────────────────
    1 │ North   gas        0.877347      1
    2 │ North   coal       0.412013      1
    3 │ South   gas        0.969407      1
    4 │ South   coal       0.641831      1
    5 │ North   gas        0.856583      2
    6 │ North   coal       0.409253      2
    7 │ South   gas        0.235768      2
    8 │ South   coal       0.655087      2

julia> df_transpose(df, :load, :time, id = 1:2)
2×6 DataFrame
 Row │ time   _variables_  ("North", "gas")  ("North", "coal")  ("South", "gas")  ("South", "coal")
     │ Int64  String       Float64?          Float64?           Float64?          Float64?          
─────┼──────────────────────────────────────────────────────────────────────────────────────────────
   1 │     1  load                 0.877347           0.412013          0.969407           0.641831
   2 │     2  load                 0.856583           0.409253          0.235768           0.655087

julia> df = DataFrame(A_2018=1:4, A_2019=5:8, B_2017=9:12,
                        B_2018=9:12, B_2019 = [missing,13,14,15],
                         ID = [1,2,3,4])
4×6 DataFrame
  Row │ A_2018  A_2019  B_2017  B_2018  B_2019   ID    
      │ Int64   Int64   Int64   Int64   Int64?   Int64
 ─────┼────────────────────────────────────────────────
    1 │      1       5       9       9  missing      1
    2 │      2       6      10      10       13      2
    3 │      3       7      11      11       14      3
    4 │      4       8      12      12       15      4

julia> f(x) =  match(r"[0-9]+",x).match
julia> dfA = df_transpose(df, r"A", :ID, renamerowid = f, variable_name = "Year", renamecolid = x->"A");
julia> dfB = df_transpose(df, r"B", :ID, renamerowid = f, variable_name = "Year", renamecolid = x->"B");
julia> outerjoin(dfA, dfB, on = [:ID, :Year])
12×4 DataFrame
 Row │ ID     Year       A        B       
     │ Int64  SubStrin…  Int64?   Int64?  
─────┼────────────────────────────────────
   1 │     1  2018             1        9
   2 │     1  2019             5  missing
   3 │     2  2018             2       10
   4 │     2  2019             6       13
   5 │     3  2018             3       11
   6 │     3  2019             7       14
   7 │     4  2018             4       12
   8 │     4  2019             8       15
   9 │     1  2017       missing        9
  10 │     2  2017       missing       10
  11 │     3  2017       missing       11
  12 │     4  2017       missing       12

# emulating the pivoting in python pandas
julia> df = DataFrame(paddockId= [0, 0, 1, 1, 2, 2],
                        color= ["red", "blue", "red", "blue", "red", "blue"],
                        count= [3, 4, 3, 4, 3, 4],
                        weight= [0.2, 0.3, 0.2, 0.3, 0.2, 0.2])
6×4 DataFrame
 Row │ paddockId  color   count  weight  
     │ Int64      String  Int64  Float64
─────┼───────────────────────────────────
   1 │         0  red         3      0.2
   2 │         0  blue        4      0.3
   3 │         1  red         3      0.2
   4 │         1  blue        4      0.3
   5 │         2  red         3      0.2
   6 │         2  blue        4      0.2

julia> df_transpose( df_transpose(df, [:count,:weight], [:paddockId,:color]),
                     :_c1, :paddockId, id = 2:3)
3×6 DataFrame
 Row │ paddockId  _variables_  ("red", "count")  ("red", "weight")  ("blue", "count")  ("blue", "weight")
     │ Int64      String       Float64?          Float64?           Float64?           Float64?           
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │         0  _c1                       3.0                0.2                4.0                 0.3
   2 │         1  _c1                       3.0                0.2                4.0                 0.3
   3 │         2  _c1                       3.0                0.2                4.0                 0.2


```

# Relation to other functions

## permutedims

`df_transpose(df::AbstractDataFrame, cols)` is similar to `permutedims()` with some differences.

* `df_transpose` only permutes the columns `cols`.
* If no variable is provided as `id`, it generates the column names of the new data set by mapping a function (`renamecolid`) on the sequence of rows in `df`.
* A function (`renamerowid`) applies to the rows ids in the output data frame before generating the `variable_name` columns.

### Examples

```julia
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

julia> df_transpose(df, r"x", renamerowid = x -> match(r"[0-9]+",x).match,
                     renamecolid = x -> "_column_" * string(x))
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

julia> df_transpose(df, [:b, :c, :d], id = :a) # note the column types
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

## stack

`df_transpose(df::AbstractDataFrame, cols, gcols)` can be used to emulate `stack` functionalities. Generally speaking, `stack` transposes each row of a data frame. Thus, to achieve the `stack` functionality each row of the input data frame should be an individual group. This can be done by inserting a new column to the input data frame or using `df_transpose` twice.

`df_transpose` cannot create the output data as a `view` (see help for `stack` function).

### Examples

```julia
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

julia> df_transpose(df, [:c, :d], Not([:c, :d]),
                     variable_name = "variable",
                     renamecolid = x -> "value")
12×5 DataFrame
 Row │ a      b      e       variable  value
     │ Int64  Int64  String  String    Int64
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
     │ Int64  Int64  String       Int64
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

## unstack

When only one column is set for `cols` argument  `df_transpose(df::AbstractDataFrame, cols, gcols)` can be used to emulate `unstack` functionality.

### Examples

```julia
wide = DataFrame(id = 1:6,
                  a  = repeat(1:3, inner = 2),
                  b  = repeat(1.0:2.0, inner = 3),
                  c  = repeat(1.0:1.0, inner = 6),
                  d  = repeat(1.0:3.0, inner = 2))
6×5 DataFrame
 Row │ id     a      b        c        d       
     │ Int64  Int64  Float64  Float64  Float64
─────┼─────────────────────────────────────────
   1 │     1      1      1.0      1.0      1.0
   2 │     2      1      1.0      1.0      1.0
   3 │     3      2      1.0      1.0      2.0
   4 │     4      2      2.0      1.0      2.0
   5 │     5      3      2.0      1.0      3.0
   6 │     6      3      2.0      1.0      3.0            

# stacking to make data long
julia> long = df_transpose(wide, 3:5, [:id, :a],
                           variable_name = "variable",
                           renamecolid = x->"value")
18×4 DataFrame
 Row │ id     a      variable  value    
     │ Int64  Int64  String    Float64
─────┼──────────────────────────────────
   1 │     1      1  b              1.0
   2 │     1      1  c              1.0
   3 │     1      1  d              1.0
   4 │     2      1  b              1.0
   5 │     2      1  c              1.0
   6 │     2      1  d              1.0
   7 │     3      2  b              1.0
   ⋮ │   ⋮      ⋮       ⋮         ⋮
  12 │     4      2  d              2.0
  13 │     5      3  b              2.0
  14 │     5      3  c              1.0
  15 │     5      3  d              3.0
  16 │     6      3  b              2.0
  17 │     6      3  c              1.0
  18 │     6      3  d              3.0
                          4 rows omitted
# unstack to make the long data wide again
julia> df_transpose(long, [:value], [:id, :a], id = :variable)
6×6 DataFrame
 Row │ id     a      _variables_  b         c         d        
     │ Int64  Int64  String       Float64?  Float64?  Float64?
─────┼─────────────────────────────────────────────────────────
   1 │     1      1  value             1.0       1.0       1.0
   2 │     2      1  value             1.0       1.0       1.0
   3 │     3      2  value             1.0       1.0       2.0
   4 │     4      2  value             2.0       1.0       2.0
   5 │     5      3  value             2.0       1.0       3.0
   6 │     6      3  value             2.0       1.0       3.0
```
