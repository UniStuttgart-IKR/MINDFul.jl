using Unitful

@testset "testresources.jl" begin
    rt = IBNFramework.Router(5)
    rtv = RouterView(rt)
    @test IBNFramework.hasport(rtv)
    @test IBNFramework.useport!(rtv, 1, 1) !== nothing
    @test IBNFramework.availableports(rtv) == 4

    f = IBNFramework.Fiber(100u"km")

    fv =FiberView(f, frequency_slots=15)
    @test !IBNFramework.hasslots(fv, 0)
    @test IBNFramework.hasslots(fv, 15)
    @test !IBNFramework.hasslots(fv, 16)
    @test IBNFramework.useslots!(fv, 10, IBNFramework.firstfit)
    @test !IBNFramework.useslots!(fv, 10, IBNFramework.firstfit)
end

