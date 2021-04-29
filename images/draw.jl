using Luxor

@svg begin
    t1 = Table(5, 5, 55, 20, Point(-240,0))
    for i in 1:size(t1,1)
        for j in 1:size(t1,2)
            setline(.1)
            box(t1[i,j], 55, 20, :stroke)
            if i == 1
                setfont("Helvetica Bold", 10)
                settext("var" * string(j), t1[i,j], halign="center", valign = "center")
            end
            @layer begin
                if j ∈ 2 && i > 1
                    setcolor(0,1,0,.5)
                    box(t1[i,j], 55,20, :fill)
                end
                if j ∈ 3 && i > 1
                    setcolor(0,0,1,.5)
                    box(t1[i,j], 55,20, :fill)
                end
                if j ∈ 5 && i > 1
                    setcolor(1,0,0,.5)
                    box(t1[i,j], 55,20, :fill)
                end
            end
            @layer begin
                sethue(0,0,0)
                setopacity(.1)
                arrow(Point(-100, 0), Point(80, 0), arrowheadlength=5, arrowheadangle=pi/4, linewidth=1)
            end
            @layer begin
                setfont("New Courier",10)
                settext("df_transpose(df, [:var2, :var3, :var5])", Point(-90, -10))
            end
        end
    end
    t2 = Table(4, 5, 55, 20, Point(225,0))
    for i in 1:size(t2,1)
        for j in 1:size(t2,2)
            setline(.1)
            box(t2[i,j], 55, 20, :stroke)
            if i == 1 && j > 1
                setfont("Helvetica Bold", 10)
                settext("_c" * string(j - 1), t2[i,j], halign="center", valign = "center")
            end
            if i == 1 && j == 1
                setfont("Helvetica Bold", 10)
                settext("_variables_", t2[i,j], halign="center", valign = "center")
            end


        @layer begin
            if i ∈ 2 && j > 1
                setcolor(0,1,0,.5)
                box(t2[i,j], 55,20, :fill)
            end
            if i ∈ 3 && j > 1
                setcolor(0,0,1,.5)
                box(t2[i,j], 55,20, :fill)
            end
            if i ∈ 4 && j > 1
                setcolor(1,0,0,.5)
                box(t2[i,j], 55,20, :fill)
            end
        end
    end
    end
    setfont("Helvetica", 10)
    settext("var2", t2[2,1], halign="center", valign = "center")
    settext("var3", t2[3,1], halign="center", valign = "center")
    settext("var5", t2[4,1], halign="center", valign = "center")
end 800 150 joinpath(@__DIR__, "simple-transpose.svg")
