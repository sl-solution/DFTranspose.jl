using DFTranspose
using Test

using Test, DataFrames, Random, CategoricalArrays, Dates
const ≅ = isequal
@testset "general usage" begin

    df = DataFrame(x1 = [1,2,3,4], x2 = [1,4,9,16])
    dft =DataFrame(_variables_ =["x1","x2"], _c1 = [1,1], _c2 = [2,4],
                    _c3 = [3,9], _c4 = [4,16])
    @test df_transpose(df, [:x1, :x2]) == dft

    df = DataFrame(rand(10,5), :auto)
    df2 = df_transpose(df, r"x")

    @test Matrix(df) == permutedims(Matrix(df2[!,r"_c"]))

    df = DataFrame(rand(10,5), :auto)
    allowmissing!(df)
    df2 = df_transpose(df, r"x")

    @test df_transpose(df, r"x") == df_transpose(df, :)
    @test df_transpose(df, r"x") == df_transpose(df, [1,2,3,4,5])
    @test Matrix(df) == permutedims(Matrix(df2[!,2:end]))

    df = DataFrame(rand(10,5), :auto)
    allowmissing!(df)
    df[1, 4] = missing
    df[4, 5] = missing
    df2 = df_transpose(df, r"x")
    @test Matrix(df) ≅ permutedims(Matrix(df2[!,Not(:_variables_)]))


    df = DataFrames.hcat!(DataFrame(rand(Bool, 15,2),[:b1,:b2]), DataFrame(rand(15,5),:auto))
    df2 = df_transpose(df, :)
    @test Matrix(df) == permutedims(Matrix(df2[!,Not(:_variables_)]))



    df = DataFrame(foo = ["one", "one", "one", "two", "two","two"],
                    bar = ['A', 'B', 'C', 'A', 'B', 'C'],
                    baz = [1, 2, 3, 4, 5, 6],
                    zoo = ['x', 'y', 'z', 'q', 'w', 't'])
    df2 = df_transpose(df, :baz, :foo, id = :bar)
    df3 = DataFrame(foo = ["one", "two"], _variables_ = ["baz", "baz"], A = [1, 4], B = [2, 5], C = [3, 6])

    @test df_transpose(df, :baz, :foo, id = :bar) == df_transpose(df, [:baz], :foo, id = :bar)
    @test df_transpose(df, :baz, :foo, id = :bar) == df_transpose(df, [:baz], [:foo], id = :bar)
    @test df_transpose(df, :baz, :foo, id = :bar) == df_transpose(df, :baz, [:foo], id = :bar)
    @test df2 == df3

    df = DataFrame(id = [1, 2, 3, 1], x1 = rand(4), x2 = rand(4))
    @test_throws AssertionError df_transpose(df, r"x", id = :id)


    df = DataFrame(rand(1:100, 1000, 10), :auto)
    insertcols!(df, 1, :g => repeat(1:100, inner = 10))
    insertcols!(df, 2, :id => repeat(1:10, 100))
    # duplicate and id within the last group
    df[1000, :id] = 1
    @test_throws AssertionError df_transpose(df, r"x", [:g], id = :id )


    df = DataFrame(rand(1000, 100), :auto)
    mdf = Matrix(df)

    @test describe(df_transpose(df, r"x"), sum => :sum, cols = r"_c").sum ≈ sum(mdf, dims = 2)

    df = DataFrame([[1, 2], [1.1, 2.0],[1.1, 2.1],[1.1, 2.0]]
                    ,[:person, Symbol("11/2020"), Symbol("12/2020"), Symbol("1/2021")])
    dft = df_transpose(df, Not(:person), :person,
                        renamerowid = x -> Date(x, dateformat"m/y"),
                        variable_name = "Date",
                         renamecolid = x -> "measurement")
    dftm = DataFrame(person = [1,1,1,2,2,2],
                Date = Date.(repeat(["2020-11-01","2020-12-01","2021-01-01"], 2)),
                measurement = [1.1, 1.1, 1.1, 2.0, 2.1, 2.0])
    @test dft == dftm
end


@testset "Outputs - from DataFrames test set" begin
    df = DataFrame(Fish = CategoricalArray{Union{String, Missing}}(["Bob", "Bob", "Batman", "Batman"]),
                   Key = CategoricalArray{Union{String, Missing}}(["Mass", "Color", "Mass", "Color"]),
                   Value = Union{String, Missing}["12 g", "Red", "18 g", "Grey"])
    levels!(df[!, 1], ["XXX", "Bob", "Batman"])
    levels!(df[!, 2], ["YYY", "Color", "Mass"])
#     Not sure if it is relevant, however, we are doing it here
    df2 = df_transpose(df, [:Value], [:Fish], id = :Key)
    @test levels(df[!, 1]) == ["XXX", "Bob", "Batman"] # make sure we did not mess df[!, 1] levels
    @test levels(df[!, 2]) == ["YYY", "Color", "Mass"] # make sure we did not mess df[!, 2] levels
#     duplicates
    @test_throws AssertionError df_transpose(df, [:Value], id = :Key)


    df = DataFrame(Fish = CategoricalArray{Union{String, Missing}}(["Bob", "Bob", "Batman", "Batman"]),
                   Key = CategoricalArray{Union{String, Missing}}(["Mass", "Color", "Mass", "Color"]),
                   Value = Union{String, Missing}["12 g", "Red", "18 g", "Grey"])
    levels!(df[!, 1], ["XXX", "Bob", "Batman"])
    levels!(df[!, 2], ["YYY", "Color", "Mass"])
    df2 = df_transpose(df, [:Value], [:Fish], id = :Key, renamecolid=x->string("_", uppercase(string(x)), "_"))
    df4 = DataFrame(Fish = Union{String, Missing}["Bob", "Batman"],
                    _variables_ = String["Value", "Value"],
                    _MASS_ = Union{String, Missing}["12 g", "18 g"],
                    _COLOR_ = Union{String, Missing}["Red", "Grey"])
    @test df2 == df4
    # without categorical array
    df = DataFrame(Fish = ["Bob", "Bob", "Batman", "Batman"],
                   Key = ["Mass", "Color", "Mass", "Color"],
                   Value = ["12 g", "Red", "18 g", "Grey"])
    df2 = df_transpose(df, [:Value], [:Fish], id = :Key)
    df4 = DataFrame(Fish = ["Bob", "Batman"],
                    _variables_ = ["Value", "Value"],
                    Mass = ["12 g", "18 g"],
                    Color = ["Red", "Grey"])
    @test df2 ≅ df4
    @test typeof(df2[!, :Fish]) <: Vector{String}
    #Make sure df_transpose works with missing values at the start of the value column
    allowmissing!(df, :Value)
    df[1, :Value] = missing
    df2 = df_transpose(df, [:Value], [:Fish], id =  :Key)
    #This changes the expected result
    allowmissing!(df4, :Mass)
    df4[1, :Mass] = missing
    @test df2 ≅ df4


    # test missing value in grouping variable
    mdf = DataFrame(RowID = 1:4, id=[missing, 1, 2, 3], a=1:4, b=1:4)
    @test select(df_transpose(df_transpose(mdf, [:a,:b], [:RowID, :id]), [:_c1], [:RowID, :id], id = :_variables_), :RowID, :id, :a, :b) ≅ mdf
    @test select(df_transpose(df_transpose(mdf, Not(1,2), [:RowID, :id]), [:_c1], [:RowID, :id], id = :_variables_), :RowID, :id, :a, :b) ≅ mdf

    # test more than one grouping column
    wide = DataFrame(id = 1:12,
                     a  = repeat([1:3;], inner = [4]),
                     b  = repeat([1:4;], inner = [3]),
                     c  = randn(12),
                     d  = randn(12))
    w2 = wide[:, [1, 2, 4, 5]]
    rename!(w2, [:id, :a, :_C_, :_D_])
    long = df_transpose(wide, [:c, :d], [:id, :a, :b])
    wide3 = df_transpose(long, [:_c1], [:id, :a, :b], id = :_variables_)
    @test select(wide3, Not(:_variables_)) == wide
    df = DataFrame([repeat(1:2, inner=4), repeat('a':'d', outer=2), collect(1:8)],
                       [:id, :variable, :value])

    udf = df_transpose(df, [:value], [:id], id = :variable)
    @test select(udf, Not(:_variables_)) == DataFrame([Union{Int, Missing}[1, 2], Union{Int, Missing}[1, 5],
                                Union{Int, Missing}[2, 6], Union{Int, Missing}[3, 7],
                                Union{Int, Missing}[4, 8]], [:id, :a, :b, :c, :d])

    @test isa(udf[!, 1], Vector{Int})
    @test isa(udf[!,:a], Vector{Union{Int,Missing}})
    @test isa(udf[!,:b], Vector{Union{Int,Missing}})
    @test isa(udf[!,:c], Vector{Union{Int,Missing}})
    @test isa(udf[!,:d], Vector{Union{Int,Missing}})
    df = DataFrame([categorical(repeat(1:2, inner=4)),
                           categorical(repeat('a':'d', outer=2)), categorical(1:8)],
                       [:id, :variable, :value])

    udf = df_transpose(df, [:value], [:id], id = :variable)
    @test isa(udf[!, 1], CategoricalVector{Int})
    @test isa(udf[!, :a], CategoricalVector{Union{Int,Missing}})
    @test isa(udf[!, :b], CategoricalVector{Union{Int,Missing}})
    @test isa(udf[!, :c], CategoricalVector{Union{Int,Missing}})
    @test isa(udf[!, :d], CategoricalVector{Union{Int,Missing}})


    df1 = DataFrame(a=["x", "y"], b=rand(2), c=[1, 2], d=rand(Bool, 2))

    @test_throws MethodError df_transpose(df1)
    @test_throws ArgumentError df_transpose(df1, :bar)

    df1_pd = df_transpose(df1, 2:4, id = 1)
    @test size(df1_pd, 1) == ncol(df1) - 1
    @test size(df1_pd, 2) == nrow(df1) + 1
    @test names(df1_pd) == ["_variables_", "x", "y"]
    @test names(df_transpose(df1, 2:4, id = 1, variable_name = "foo")) == ["foo", "x", "y"]

end
