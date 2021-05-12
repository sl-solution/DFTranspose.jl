# a helper function that checks if there is enough memory for the output data frame
#  If type is not Number, probably something is wrong about setting the variables and it is better to be conservative. here 10^7 threshhold is arbitarary
_check_allocation_limit(T, rows, cols) = T <: Number ? sizeof(T)*rows*cols / Base.Sys.total_memory() : rows*cols/10^7

_default_renamecolid_function_withoutid(x) = "_c" * string(x)
_default_renamecolid_function_withid(x) = identity(string(values(x)))
_default_renamerowid_function(x) = identity(x)
# handling simplest case
function _simple_df_transpose!(outx, inx, i)
    @views copy!(outx[i,:], inx)
end

function _generate_col_row_names(renamecolid, renamerowid, ids, dfnames)

    new_col_names = map(renamecolid, ids)

    row_names = map(renamerowid, dfnames)
    (new_col_names, row_names)
end

function _simple_transpose_df_generate(T, in_cols, row_names, new_col_names, variable_name)
    outputmat = Matrix{T}(undef,length(row_names), length(new_col_names))

    for i in 1:length(in_cols)
        _simple_df_transpose!(outputmat, in_cols[i], i)
    end

    new_var_label = Symbol(variable_name)
    insertcols!(DataFrame(outputmat, new_col_names), 1,  new_var_label => row_names, copycols = false)
end

function _find_unique_values(df, cols)
    gdf = groupby(df, cols)
    _unique_rows = _find_group_row(gdf)
    df[_unique_rows, cols]
end

"""
    df_transpose(df::AbstractDataFrame, cols [, gcols];
        id = nothing,
        renamecolid = (x -> "_c" * string(x)),
        renamerowid = identity,
        variable_name = "_variables_")

transposes `df[!, cols]`. When `id` is set, the values of `df[!, id]` will be used to label the columns in the new data frame. The function uses the `renamecolid` function to generate the new columns labels. The `renamerowid` function is applied to stringified names of `df[!, cols]` and attached them to the output as a new column with the label `variable_name`. When `gcols` is used the transposing is done within each group constructed by `gcols`. If the number of rows in a group is smaller than other groups, the extra columns in the output data frame is filled with `missing` (the default value can be changed by using `default_fill` argument) for that group.

* `renamecolid`: When `id` is not set, the argument to `renamecolid` must be an `Int`. And when `id` is set, the `renamecolid` will be applied to each row of `df[!, id]` as Tuple.
* When `id` is set, `renamecolid` is defined as `x -> identity(string(values(x)))`

```jldoctest
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

julia> pop = DataFrame(country = ["c1","c1","c2","c2","c3","c3"],
                       sex = repeat(["male", "female"],3),
                       pop_2000 = [100, 120, 150, 155, 170, 190],
                       pop_2010 = [110, 120, 155, 160, 178, 200],
                       pop_2020 = [115, 130, 161, 165, 180, 203])
6×5 DataFrame
Row │ country  sex     pop_2000  pop_2010  pop_2020
    │ String   String  Int64     Int64     Int64
────┼───────────────────────────────────────────────
  1 │ c1       male         100       110       115
  2 │ c1       female       120       120       130
  3 │ c2       male         150       155       161
  4 │ c2       female       155       160       165
  5 │ c3       male         170       178       180
  6 │ c3       female       190       200       203

julia> df_transpose(pop, r"pop_", :country,
                id = :sex, variable_name = "year",
                renamerowid = x -> match(r"[0-9]+",x).match,
                renamecolid = x -> x * "_pop")
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

```
"""
function df_transpose(df::AbstractDataFrame, cols::DataFrames.MultiColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_")
    colidx = DataFrames.index(df)[cols]
    ECol = view(getfield(df, :columns), colidx)
    T = mapreduce(eltype, promote_type, ECol)
    # in_cols = [x for x in ECol]

    if id === nothing
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withoutid
        end
        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, 1:nrow(df), names(df)[colidx])
    else
        ididx = DataFrames.index(df)[id]
        length(ididx) == 1 ? ididx = ididx[1] : nothing
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withid
        end
        if size(df[!,ididx],2) > 1
            ids_vals = Tables.rowtable(df[!,ididx])
        else
            ids_vals = df[!,ididx]
        end
        ids_unique_vals = _find_unique_values(df, ididx)

        @assert (size(ids_unique_vals,1)) == nrow(df) "Duplicate ids are not allowed."
        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, ids_vals, names(df)[colidx])
    end

    _simple_transpose_df_generate(T, ECol, row_names, new_col_names, variable_name)

end


# groupby case
function _fill_onecol!(y, x, ntimes)
    for i in 1:length(x)
        @views fill!(y[(i-1)*ntimes+1:(i*ntimes)], x[i])
    end
end

function _fill_row_names!(res, row_names, ntimes)
    n = length(row_names)
    for i in 1:ntimes
        @views copy!(res[(i-1)*n+1:i*n], row_names)
    end
    res
end

function _fill_gcol!(res, df, gcolindex, colsidx)

    ntimes = length(colsidx)
    totalrow = nrow(df) * ntimes
    for i in 1:length(gcolindex)
        _temp = df[!,gcolindex[i]]
        push!(res, similar(_temp, totalrow))
        _fill_onecol!(res[i], _temp, ntimes)
    end
    res
end

function _fill_col_val!(res, in_cols, ntimes, df_n_row)
    for j in 1:ntimes
        for i in 1:df_n_row
            res[(i-1)*ntimes+j] = in_cols[j][i]
        end
    end
end


function fast_stack(T, df, in_cols, colsidx, gcolsidx, colid, row_names, variable_name)
    # construct group columns
    g_array = AbstractArray[]
    _fill_gcol!(g_array, df, gcolsidx, colsidx)
    df1 = DataFrame(g_array, DataFrames._names(df)[gcolsidx], copycols = false)

    # construct variable names column
    _repeat_row_names = Vector{eltype(row_names)}(undef, nrow(df)*length(colsidx))
    _fill_row_names!(_repeat_row_names, row_names, nrow(df))
    new_var_label = Symbol(variable_name)
    insertcols!(df1, new_var_label => _repeat_row_names, copycols = false)

    # fill the stacked column
    res = Vector{T}(undef, nrow(df)*length(colsidx))
    _fill_col_val!(res, in_cols, length(colsidx), nrow(df))
    new_col_id = Symbol(colid)
    insertcols!(df1, new_col_id => res, copycols = false)
end


function _obtain_maximum_groups_size(gridx, ngroups)
    levels = zeros(Int32, ngroups)
    @simd for i in 1:length(gridx)
        @inbounds levels[gridx[i]] += 1
    end
    maximum(levels)
end

# from DataFrames/reshape.jl
function _find_group_row(gdf::GroupedDataFrame)
    rows = zeros(Int, length(gdf))
    isempty(rows) && return rows

    filled = 0
    i = 1
    groups = gdf.groups
    while filled < length(gdf)
        group = groups[i]
        if rows[group] == 0
            rows[group] = i
            filled += 1
        end
        i += 1
    end
    return rows
end

# gaining information about group info with out any assumption about the orders
# function update_group_info!(group_info, row_t, gridx, row_names, i)
#     n_row_names = length(row_names)
#     gid = gridx[i]
#     _rows_ = (gid-1)*n_row_names+1:(gid*n_row_names)
#     @views fill!(group_info[_rows_], row_t[i])
# end

function update_outputmat!(outputmat, x, gridx, n_row_names, which_col)
    for j in 1:n_row_names
        fill!(which_col, 0)
        for i in 1:length(gridx)
            gid = gridx[i]
            which_col[gid] += 1
            selected_col = which_col[gid]
            _row_ = (gid-1)*n_row_names+j
            outputmat[selected_col][_row_] = x[j][i]
        end
    end
end


function update_outputmat!(outputmat, x, gridx, ids, dict_cols::Dict, n_row_names, _is_cell_filled)
    for i in 1:length(gridx)
        gid = gridx[i]
        selected_col = dict_cols[ids[i]]
        for j in 1:n_row_names
            _row_ = (gid-1)*n_row_names+j
            if _is_cell_filled[_row_, selected_col]
                throw(AssertionError("Duplicate id within a group is not allowed"))
            else
                outputmat[selected_col][_row_] = x[j][i]
                _is_cell_filled[_row_, selected_col] = true
            end
        end
    end
end

function _fill_outputmat_withoutid(T, in_cols, gdf, gridx, new_col_names, row_names; default_fill = missing)

    @assert _check_allocation_limit(nonmissingtype(T), length(row_names)*gdf.ngroups, length(new_col_names)) < 1.0 "The output data frame is huge and there is not enough resource to allocate it."
    CT = promote_type(T, typeof(default_fill))
    outputmat = [fill!(Vector{CT}(undef, length(row_names)*gdf.ngroups), default_fill) for _ in 1:length(new_col_names)]
    which_col = Vector{Int}(undef, gdf.ngroups)

    update_outputmat!(outputmat, in_cols, gridx, length(row_names), which_col)

    outputmat
end

function _fill_outputmat_withid(T, in_cols, gdf, gridx, ids, new_col_names, row_names, dict_cols; default_fill = missing)

    @assert _check_allocation_limit(nonmissingtype(T), length(row_names)*gdf.ngroups, length(new_col_names)) < 1.0 "The output data frame is huge and there is not enough resource to allocate it."
    CT = promote_type(T, typeof(default_fill))
    outputmat = [fill!(Vector{CT}(undef, length(row_names)*gdf.ngroups), default_fill) for _ in 1:length(new_col_names)]

    _is_cell_filled = falses(length(row_names)*gdf.ngroups, length(new_col_names))

    which_col = zeros(Int, gdf.ngroups)

    update_outputmat!(outputmat, in_cols, gridx, ids, dict_cols, length(row_names), _is_cell_filled)

    outputmat
end

function df_transpose(df::AbstractDataFrame, cols::DataFrames.MultiColumnIndex, gcols::DataFrames.MultiColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing)
    colsidx = DataFrames.index(df)[cols]
    gcolsidx = DataFrames.index(df)[gcols]

    ECol = eachcol(df[!,colsidx])

    T = mapreduce(eltype, promote_type, ECol)

    in_cols = Vector{T}[x for x in ECol]

    gdf = groupby(df, gcols)
    gridx = gdf.groups

    need_fast_stack = false
    if gdf.ngroups == nrow(df)
        need_fast_stack = true
    end

    if id === nothing
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withoutid
        end
        # fast_stack path, while keeping the row order consistent
        if need_fast_stack
            return fast_stack(T, df, in_cols, colsidx, gcolsidx, renamecolid(1), renamerowid.(names(df, colsidx)), variable_name)
        end

        out_ncol = _obtain_maximum_groups_size(gridx, gdf.ngroups)

        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, 1:out_ncol, names(df)[colsidx])

        outputmat = _fill_outputmat_withoutid(T, in_cols, gdf, gridx, new_col_names, row_names; default_fill = default_fill)
    else
        ididx = DataFrames.index(df)[id]
        length(ididx) == 1 ? ididx = ididx[1] : nothing
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withid
        end
        # we assume the unique function keep the same order as original data, which is the case sofar

        if size(df[!,ididx],2) > 1
            ids_vals = Tables.rowtable(df[!,ididx])
            unique_ids = Tables.rowtable(_find_unique_values(df, ididx))
        else
            ids_vals = df[!,ididx]
            unique_ids = _find_unique_values(df, ididx)
        end

        out_ncol = length(unique_ids)

        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, unique_ids, names(df)[colsidx])

        dict_out_col = Dict(unique_ids .=> 1:out_ncol)
        outputmat = _fill_outputmat_withid(T, in_cols, gdf, gridx, ids_vals, new_col_names, row_names, dict_out_col; default_fill = default_fill)
    end
    rows_with_group_info = _find_group_row(gdf)
    new_var_label = Symbol(variable_name)

    g_array = AbstractArray[]
    _fill_gcol!(g_array, view(df, rows_with_group_info, :), gcolsidx, colsidx)
    outdf = DataFrame(g_array, DataFrames._names(df)[gcolsidx], copycols = false)
    _repeat_row_names = Vector{eltype(row_names)}(undef, gdf.ngroups*length(colsidx))
    _fill_row_names!(_repeat_row_names, row_names, gdf.ngroups)
    insertcols!(outdf, new_var_label => _repeat_row_names, copycols = false)

    hcat(outdf, DataFrame(outputmat, new_col_names, copycols = false), copycols = false)



end


df_transpose(df::AbstractDataFrame, cols::DataFrames.ColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_") = df_transpose(df,[cols]; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name)

df_transpose(df::AbstractDataFrame, cols::DataFrames.MultiColumnIndex, gcols::DataFrames.ColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing) = df_transpose(df,cols, [gcols]; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name, default_fill = default_fill)

df_transpose(df::AbstractDataFrame, cols::DataFrames.ColumnIndex, gcols::DataFrames.MultiColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing) = df_transpose(df, [cols], gcols; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name, default_fill = default_fill)

df_transpose(df::AbstractDataFrame, cols::DataFrames.ColumnIndex, gcols::DataFrames.ColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing) = df_transpose(df, [cols], [gcols]; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name, default_fill = default_fill)
