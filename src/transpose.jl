# a helper function that checks if there is enough memory for the output data frame
#  If type is not concrete, probably something is wrong about setting the variables and it is better to be conservative
_check_allocation_limit(T, rows, cols) = isconcretetype(T) ? sizeof(T)*rows*cols / Base.Sys.total_memory() : rows*cols/10^6

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

# FIXME currently there are some allocations which I cannot figure out why they happens
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
# FIXME currently there are some allocations which I cannot figure out why they happens
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
