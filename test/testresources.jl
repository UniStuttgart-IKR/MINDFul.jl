using Unitful

@testset "testresources.jl" begin
    rt = MINDFul.Router(5)
    rtv = RouterView(rt)
    @test MINDFul.hasport(rtv)
    @test MINDFul.useport!(rtv, 1, 1) !== nothing
    @test MINDFul.availableports(rtv) == 4

    f = MINDFul.Fiber(100u"km")

    fv =FiberView(f, frequency_slots=15)
    @test !MINDFul.hasslots(fv, 0)
    @test MINDFul.hasslots(fv, 15)
    @test !MINDFul.hasslots(fv, 16)
    @test MINDFul.useslots!(fv, 10, MINDFul.firstfit)
    @test !MINDFul.useslots!(fv, 10, MINDFul.firstfit)
end

