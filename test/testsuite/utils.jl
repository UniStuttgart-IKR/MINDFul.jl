@testset ExtendedTestSet "utils.jl"  begin

    startingconsecutivelightpaths = let
        lps = [[1, 0, 3], [1, 2, 3], [3, 4, 5], [7, 12, 1], [2, 3, 4], [3, 6, 7], [7, 8, 9]]
        cons = MINDF.consecutivelightpathsidx(lps, 1; startingnode = true)
        [[lps[cel] for cel in c] for c in cons]
    end

    @test startingconsecutivelightpaths == [
        [[1, 0, 3]],
        [[1, 2, 3]],
        [[1, 0, 3], [3, 4, 5]],
        [[1, 0, 3], [3, 6, 7]],
        [[1, 2, 3], [3, 4, 5]],
        [[1, 2, 3], [3, 6, 7]],
        [[1, 0, 3], [3, 6, 7], [7, 8, 9]],
        [[1, 2, 3], [3, 6, 7], [7, 8, 9]],
    ]

    endingconsecutivelightpaths = let
        lps = [[1, 0, 3], [1, 2, 3], [3, 4, 5], [7, 12, 1], [2, 3, 4], [3, 6, 7], [7, 8, 9]]
        cons = MINDF.consecutivelightpathsidx(lps, 3; startingnode = false)
        [[lps[cel] for cel in c] for c in cons]
    end

    @test endingconsecutivelightpaths == [
        [[1, 0, 3]],
        [[1, 2, 3]],
        [[7, 12, 1], [1, 0, 3]],
        [[7, 12, 1], [1, 2, 3]],
    ]

end
