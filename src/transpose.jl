# a helper function that checks if there is enough memory for the output data frame
#  If type is not Number, probably something is wrong about setting the variables and it is better to be conservative. here 10^7 threshhold is arbitarary
_check_allocation_limit(T, rows, cols) = T <: Number ? sizeof(T)*rows*cols / Base.Sys.total_memory() : rows*cols/10^7

_default_renamecolid_function_withoutid(x) = "_c" * string(x)
_default_renamecolid_function_withid(x) = identity(string(values(x)))
_default_renamerowid_function(x) = identity(x)
# handling simplest case
function _simple_df_transpose!(outx, inx)
    n = size(outx,2)
    for i in 1:size(outx,1)
            @views copy!(outx[i,1:n], inx[i])
    end
end

function _generate_col_row_names(renamecolid, renamerowid, size1, dfnames)
    new_col_names = map(renamecolid, 1:size1)

    row_names = map(renamerowid, dfnames)
    (new_col_names, row_names)
end
function _generate_col_row_names(renamecolid, renamerowid, ids, dfnames)

    new_col_names = map(renamecolid, ids)

    row_names = map(renamerowid, dfnames)
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
        renamecolid = (x -> "_c" * string(x)),
        renamerowid = identity,
        variable_name = "_variables_")

transposes `df[!, cols]`. When `id` is set, the values of `df[!, id]` will be used to label the columns in the new data frame. The function uses the `renamecolid` function to generate the new columns labels. The `renamerowid` function is applied to stringified names of `df[!, cols]` and attached them to the output as a new column with the label `variable_name`.

* `renamecolid`: When `id` is not set, the argument to `renamecolid` must be an `Int`. And when `id` is set, the `renamecolid` will be applied to each row of `df[!, id]` as Tuple.
* When `id` is set, `renamecolid` is defined as `x -> identity(string(values(x)))`
"""

function df_transpose(df::AbstractDataFrame, cols::DataFrames.MultiColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_")
    ECol = eachcol(df[!,cols])
    T = mapreduce(eltype, promote_type, ECol)
    in_cols = Vector{T}[x for x in ECol]

    if id === nothing
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withoutid
        end
        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, 1:nrow(df), names(ECol))
    else
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withid
        end
        if size(df[!,id],2) > 1
            ids_vals = Tables.rowtable(df[!,id])
        else
            ids_vals = df[!,id]
        end
        @assert length(unique(ids_vals)) == nrow(df) "Duplicate ids are not allowed."
        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, ids_vals, names(ECol))
    end

    _simple_transpose_df_generate(T, in_cols, row_names, new_col_names, variable_name)

end


# groupby case
function _obtain_maximum_groups_size(gridx, ngroups)
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

function update_outputmat!(outputmat, x, gridx, ids, dict_cols::Dict, row_names, i, row_t, which_col)
    n_row_names = length(row_names)
    gid = gridx[i]
    selected_col = dict_cols[ids[i]]
    if which_col[gid] > selected_col
        throw(AssertionError("Duplicate id for $(ids[i]) in group $(row_t[i])"))
    end
    for j in 1:n_row_names
        outputmat[(gid-1)*n_row_names+j, selected_col] = x[j][i]
    end
end

function _fill_outputmat_and_group_info_withoutid(T, in_cols, gdf, gridx, new_col_names, row_names, row_t; default_fill = missing)

    @assert _check_allocation_limit(nonmissingtype(T), length(row_names)*gdf.ngroups, length(new_col_names)) < 1.0 "The output data frame is huge and there is not enough resource to allocate it."

    outputmat = fill!(Matrix{Union{T, Missing}}(undef,length(row_names)*gdf.ngroups, length(new_col_names)),default_fill)

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

function _fill_outputmat_and_group_info_withid(T, in_cols, gdf, gridx, ids, new_col_names, row_names, dict_cols, row_t; default_fill = missing)

    @assert _check_allocation_limit(nonmissingtype(T), length(row_names)*gdf.ngroups, length(new_col_names)) < 1.0 "The output data frame is huge and there is not enough resource to allocate it."

    outputmat = fill!(Matrix{Union{T, Missing}}(undef,length(row_names)*gdf.ngroups, length(new_col_names)), default_fill)

    which_col = zeros(Int, gdf.ngroups)

    group_info = Vector{eltype(row_t)}(undef, gdf.ngroups*length(row_names))

    for i in 1:length(gridx)
        gid = gridx[i]
        which_col[gid] += 1
        if which_col[gid] == 1
            update_group_info!(group_info, row_t, gridx, row_names, i)
        end
        update_outputmat!(outputmat, in_cols, gridx, ids, dict_cols, row_names, i, row_t, which_col)
    end
    (group_info, outputmat)
end

# if want a faster way in the case of stack
function _fill_outputmat_and_group_info_fast_stack(in_cols, row_t)

    outputmat = vcat(in_cols...)

    group_info = repeat(row_t, outer = length(in_cols))

    (group_info, outputmat)
end

"""
    df_transpose(df::AbstractDataFrame, cols, gcols;
        id = nothing,
        renamecolid = (x -> "_c" * string(x)),
        renamerowid = identity,
        variable_name = "_variables_",
        default_fill = missing)

transposes `df[!, cols]` within each group constructed by `gcols`.
"""

function df_transpose(df::AbstractDataFrame, cols::DataFrames.MultiColumnIndex, gcols::DataFrames.MultiColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing)
    ECol = eachcol(df[!,cols])
    EColG = eachcol(df[!,gcols])
    T = mapreduce(eltype, promote_type, ECol)
    row_t = Tables.rowtable(EColG)

    in_cols = Vector{T}[x for x in ECol]

    gdf = groupby(df, gcols)
    gridx = gdf.groups

    # fast_stack = false
    # if gdf.ngroups == nrow(df)
    #     # we are doing a stack
    #     if nonmissingtype(T) <: Number
    #         # we can use faster approach or implement view option
    #         fast_stack = true
    #     end
    # end

    if id === nothing
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withoutid
        end

        out_ncol = _obtain_maximum_groups_size(gridx, gdf.ngroups)

        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, 1:out_ncol, names(ECol))

        group_info, outputmat = _fill_outputmat_and_group_info_withoutid(T, in_cols, gdf, gridx, new_col_names, row_names, row_t; default_fill = default_fill)
    else
        if renamecolid === nothing
            renamecolid = _default_renamecolid_function_withid
        end
        # we assume the unique function keep the same order as original data, which is the case sofar

        if size(df[!,id],2) > 1
            ids_vals = Tables.rowtable(df[!,id])
        else
            ids_vals = df[!,id]
        end
        unique_ids = unique(ids_vals)
        out_ncol = length(unique_ids)

        new_col_names, row_names = _generate_col_row_names(renamecolid, renamerowid, unique_ids, names(ECol))

        dict_out_col = Dict(unique_ids .=> 1:out_ncol)
        group_info, outputmat = _fill_outputmat_and_group_info_withid(T, in_cols, gdf, gridx, ids_vals, new_col_names, row_names, dict_out_col, row_t; default_fill = default_fill)
    end

    new_var_label = Symbol(variable_name)

    df1 = insertcols!(DataFrame(outputmat, new_col_names),1, new_var_label => repeat(row_names, outer = gdf.ngroups))
    DataFrames.hcat!(DataFrame(group_info),df1)

end


df_transpose(df::AbstractDataFrame, cols::DataFrames.ColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_") = df_transpose(df,[cols]; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name)

df_transpose(df::AbstractDataFrame, cols::DataFrames.MultiColumnIndex, gcols::DataFrames.ColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing) = df_transpose(df,cols, [gcols]; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name, default_fill = default_fill)

df_transpose(df::AbstractDataFrame, cols::DataFrames.ColumnIndex, gcols::DataFrames.MultiColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing) = df_transpose(df, [cols], gcols; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name, default_fill = default_fill)

df_transpose(df::AbstractDataFrame, cols::DataFrames.ColumnIndex, gcols::DataFrames.ColumnIndex; id = nothing, renamecolid = nothing, renamerowid = _default_renamerowid_function, variable_name = "_variables_", default_fill = missing) = df_transpose(df, [cols], [gcols]; id = id, renamecolid = renamecolid, renamerowid = renamerowid, variable_name = variable_name, default_fill = default_fill)
