using MINDFul: getoxcview
# import MINDFulMakie as MINDFM
using MINDFul, Test
using Graphs
import AttributeGraphs as AG
using JLD2, UUIDs
using Unitful, UnitfulData

const MINDF = MINDFul

# using GLMakie

compalg = MINDF.BestEmpiricalAvailabilityCompilation(10, 5; nodenum=1)

ibnfs = loadmultidomaintestibnfs(compalg)

avcon1 = MINDF.AvailabilityConstraint(0.94, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[2]), 8), u"5.0Gbps", [avcon1])

intentuuid1, _ = MINDF.addintent!(ibnfs[1], conintent1, NetworkOperator())
returncode, _  = MINDF.compileintent!(ibnfs[1], intentuuid1)
returncode, _  = MINDF.installintent!(ibnfs[1], intentuuid1)
returncode, _  = MINDF.uninstallintent!(ibnfs[1], intentuuid1)

 # MINDFM.intentplot(ibnfs[1]; intentid=intentuuid1, showstate = true, showintent=true, multidomain=true, subidag=:connected, graphattr=(;arrow_size=15, nlabels_fontsize=20))
