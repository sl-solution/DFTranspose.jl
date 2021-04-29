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


@svg begin
    t1 = Table(10, 5, 55, 20, Point(-240,0))
    for i in 1:size(t1,1)
        for j in 1:size(t1,2)
            setline(.1)
            box(t1[i,j], 55, 20, :stroke)
            if i == 1 && j > 1
                setfont("Helvetica Bold", 10)
                settext("var" * string(j-1), t1[i,j], halign="center", valign = "center")
            elseif i==1 && j == 1
                setfont("Helvetica Bold", 10)
                settext("group", t1[i,j], halign="center", valign = "center")
            end

            @layer begin
                setline(1)
                line(t1[6,1] - (55/2, 10), t1[6,5] - (-55/2, 10), :stroke)
            end

            if j == 1 && 1< i < 6
                setfont("Helvetica", 10)
                settext("g1", t1[i,j], halign="center", valign = "center")
            end
            if j == 1 && i > 5
                setfont("Helvetica", 10)
                settext("g2", t1[i,j], halign="center", valign = "center")
            end
            @layer begin
                if j ∈ (2,3,5) && 1 < i < 6
                    setcolor(0,1,0,.5)
                    box(t1[i,j], 55,20, :fill)
                end
                if j ∈ (2,3,5) && 5 < i
                    setcolor(0,0,1,.5)
                    box(t1[i,j], 55,20, :fill)
                end
            end
            @layer begin
                sethue(0,0,0)
                setopacity(.1)
                arrow(Point(-100, 0), Point(90, 0), arrowheadlength=5, arrowheadangle=pi/4, linewidth=1)
            end
            @layer begin
                setfont("New Courier",10)
                settext("df_transpose(df, [:var1, :var2, :var4], [:g])", Point(-95, -10))
            end
        end
    end
    t2 = Table(7, 6, 55, 20, Point(270,0))
    for i in 1:size(t2,1)
        for j in 1:size(t2,2)
            setline(.1)
            box(t2[i,j], 55, 20, :stroke)
            if i == 1 && j > 2
                setfont("Helvetica Bold", 10)
                settext("_c" * string(j - 2), t2[i,j], halign="center", valign = "center")
            end
            if i == 1 && j == 2
                setfont("Helvetica Bold", 10)
                settext("_variables_", t2[i,j], halign="center", valign = "center")
            end
            if i == 1 && j == 1
                setfont("Helvetica Bold", 10)
                settext("group", t2[i,j], halign="center", valign = "center")
            end

        @layer begin
            if 1 < i < 5 && j > 2
                setcolor(0,1,0,.5)
                box(t2[i,j], 55,20, :fill)
            end
            if i > 4 && j > 2
                setcolor(0,0,1,.5)
                box(t2[i,j], 55,20, :fill)
            end
        end
    end
    end
    setfont("Helvetica", 10)
    for k in 0:1
        settext("var1", t2[k * 3 + 2,2], halign="center", valign = "center")
        settext("var2", t2[k * 3 + 3,2], halign="center", valign = "center")
        settext("var4", t2[k * 3 + 4,2], halign="center", valign = "center")
    end
    for k1 in 1:3
        for k2 in 0:1
            settext("g"*string(k2+1), t2[k2 * 3 + k1 + 1, 1],halign="center", valign = "center")
        end
    end
    @layer begin
        setline(1)
        line(t2[5,1] - (55/2, 10), t2[5,6] - (-55/2, 10), :stroke)
    end

end 900 250 joinpath(@__DIR__, "groupby-transpose.svg")
