# a helper function that checks if there is enough memory for the output data frame
_check_allocation_limit(T, rows, cols) = isconcretetype(T) ? sizeof(T)*rows*cols / Base.Sys.total_memory() : rows*cols/typemax(Int32)

_default_colid_function_withoutid(x) = "_c" * string(x)
_default_colid_function_withid(x) = identity(x)
_default_rowid_function(x) = identity(x)
# handling simplest case
function _simple_df_transpose!(outx, inx)
    for j in 1:size(outx,2)
        @simd for i in 1:size(outx,1)
            @inbounds outx[i,j] = inx[i][j]
        end
    end
end

function _simple_generate_names_withoutid(colid, rowid, size1, dfnames)
    new_col_names = map(colid, 1:size1)

    row_names = map(rowid, dfnames)
    (new_col_names, row_names)
end
function _simple_generate_names_withid(colid, rowid, ids, dfnames)

    if eltype(ids) <: Union{Number, Symbol, AbstractString}
        new_col_names = map(colid, string.(ids))
    else
        throw(ArgumentError("The type of `id` variable should be Number, Symbol, or String."))
    end

    row_names = map(rowid, dfnames)
    (new_col_names, row_names)
end

function _simple_transpose_df_generate(T, in_cols, row_names, new_col_names, variable_name)
    outputmat = Matrix{T}(undef,length(row_names), length(new_col_names))

    _simple_df_transpose!(outputmat, in_cols)

    new_var_label = Symbol(variable_name)
    insertcols!(DataFrame(outputmat, new_col_names), 1,  new_var_label => row_names)
end

"""
    df_transpose(df::AbstractDataFrame, cols;
        id = nothing,
        colid = (x -> "_c" * string(x)),
        rowid = identity,
        variable_name = "_variables_")

transposes `df[!, cols]`. When `id` is set, the values of `df[!, id]` will be used to label the columns in the new data frame. The function uses the `colid` function to generate the new columns labels. The `rowid` function is applied to stringified names of `df[!, cols]` and attached them to the output as a new column with the label `variable_name`.

* `colid`: When `id` is not set, the argument to `colid` must be an `Int`. And when `id` is set, the `colid` will be applied to stringified `df[!, id]`.
"""
function df_transpose(df::AbstractDataFrame, cols; id = nothing, colid = nothing, rowid = _default_rowid_function, variable_name = "_variables_")
    ECol = eachcol(df[!,cols])
    T = promote_type(eltype.(ECol)...)
    in_cols = Vector{T}[x for x in ECol]

    if id === nothing
        if colid === nothing
            colid = _default_colid_function_withoutid
        end
        new_col_names, row_names = _simple_generate_names_withoutid(colid, rowid, nrow(df), names(ECol))
    else
        if colid === nothing
            colid = _default_colid_function_withid
        end
        @assert length(unique(df[!, id])) == nrow(df) "Duplicate ids are not allowed."
        new_col_names, row_names = _simple_generate_names_withid(colid, rowid, df[!,id], names(ECol))
    end

    _simple_transpose_df_generate(T, in_cols, row_names, new_col_names, variable_name)

end


# groupby case
function _obtain_maximum_groups_levels(gridx, ngroups)
    levels = zeros(Int32, ngroups)
    @simd for i in 1:length(gridx)
        @inbounds levels[gridx[i]] += 1
    end
    maximum(levels)
end

function update_group_info!(group_info, row_t, gridx, row_names, i)
    n_row_names = length(row_names)
    gid = gridx[i]
    _rows_ = (gid-1)*n_row_names+1:(gid*n_row_names)
    @views fill!(group_info[_rows_], row_t[i])
end

function update_outputmat!(outputmat, x, gridx, which_col, row_names, i)
    n_row_names = length(row_names)
    gid = gridx[i]
    selected_col = which_col[gid]
    for j in 1:n_row_names
        outputmat[(gid-1)*n_row_names+j, selected_col] = x[j][i]
    end
end

function update_outputmat!(outputmat, x, gridx, ids::Vector, dict_cols::Dict, row_names, i, row_t)
    n_row_names = length(row_names)
    gid = gridx[i]
    selected_col = dict_cols[ids[i]]
    if !ismissing(outputmat[(gid-1)*n_row_names+1, selected_col])
        throw(ErrorException("Duplicate id for $(ids[i]) in group $(row_t[gid])"))
    end
    for j in 1:n_row_names
        outputmat[(gid-1)*n_row_names+j, selected_col] = x[j][i]
    end
end

function _fill_outputmat_and_group_info_withoutid(T, in_cols, gdf, gridx, new_col_names, row_names, row_t)

    @assert _check_allocation_limit(T, length(row_names)*gdf.ngroups, length(new_col_names)) < 1.0 "The output data frame is huge and there is not enough resource to allocate it."

    outputmat = fill!(Matrix{Union{T, Missing}}(undef,length(row_names)*gdf.ngroups, length(new_col_names)),missing)

    which_col = zeros(Int, gdf.ngroups)

    group_info = Vector{eltype(row_t)}(undef, gdf.ngroups*length(row_names))

    for i in 1:length(gridx)
        gid = gridx[i]
        which_col[gid] += 1
        if which_col[gid] == 1
            update_group_info!(group_info, row_t, gridx, row_names, i)
        end
        update_outputmat!(outputmat, in_cols, gridx, which_col, row_names, i)
    end
    (group_info, outputmat)
end

function _fill_outputmat_and_group_info_withid(T, in_cols, gdf, gridx, ids, new_col_names, row_names, dict_cols, row_t)

    @assert _check_allocation_limit(T, length(row_names)*gdf.ngroups, length(new_col_names)) < 1.0 "The output data frame is huge and there is not enough resource to allocate it."

    outputmat = fill!(Matrix{Union{T, Missing}}(undef,length(row_names)*gdf.ngroups, length(new_col_names)),missing)

    which_col = zeros(Int, gdf.ngroups)

    group_info = Vector{eltype(row_t)}(undef, gdf.ngroups*length(row_names))

    for i in 1:length(gridx)
        gid = gridx[i]
        which_col[gid] += 1
        if which_col[gid] == 1
            update_group_info!(group_info, row_t, gridx, row_names, i)
        end
        update_outputmat!(outputmat, in_cols, gridx, ids, dict_cols, row_names, i, row_t)
    end
    (group_info, outputmat)
end


"""
    df_transpose(df::AbstractDataFrame, cols, gcols;
        id = nothing,
        colid = (x -> "_c" * string(x)),
        rowid = identity,
        variable_name = "_variables_")

transposes `df[!, cols]` within each group constructed by `gcols`.
"""
function df_transpose(df::AbstractDataFrame, cols, gcols; id = nothing, colid = nothing, rowid = _default_rowid_function, variable_name = "_variables_")
    ECol = eachcol(df[!,cols])
    EColG = eachcol(df[!,gcols])
    T = promote_type(eltype.(ECol)...)
    row_t = Tables.rowtable(EColG)

    in_cols = Vector{T}[x for x in ECol]

    gdf = groupby(df, gcols)
    gridx = gdf.groups


    if id === nothing
        if colid === nothing
            colid = _default_colid_function_withoutid
        end

        out_ncol = _obtain_maximum_groups_levels(gridx, gdf.ngroups)

        new_col_names, row_names = _simple_generate_names_withoutid(colid, rowid, out_ncol, names(ECol))

        (group_info, outputmat) = _fill_outputmat_and_group_info_withoutid(T, in_cols, gdf, gridx, new_col_names, row_names, row_t)
    else
        if colid === nothing
            colid = _default_colid_function_withid
        end

        unique_ids = unique(df[!,id])
        out_ncol = length(unique_ids)

        new_col_names, row_names = _simple_generate_names_withid(colid, rowid, unique_ids, names(ECol))

        dict_out_col = Dict(unique_ids .=> 1:out_ncol)

        (group_info, outputmat) = _fill_outputmat_and_group_info_withid(T, in_cols, gdf, gridx, df[!, id], new_col_names, row_names, dict_out_col, row_t)
    end

    new_var_label = Symbol(variable_name)

    df1 = insertcols!(DataFrame(outputmat, new_col_names),1, new_var_label => repeat(row_names, outer = gdf.ngroups))

    DataFrames.hcat!(DataFrame(group_info),df1)
end


"""
# permutedims

`df_transpose(df::AbstractDataFrame, cols)` is similar to `permutedims()` with some flexibility.

* `df_transpose` only permutes the columns `cols`.
* If no variable is provided as `id`, it generates the column names of the new data set by maping a function (`colid`) on the sequence of rows in `df`.
* A function (`rowid`) applied to the row id in the output data frame before generating the `variable_name` columns.
* If `id` is set from a column in `df`, it applies `colid` on the strigified values of `id` and uses the result as the column names for the new data frame.

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
"""
