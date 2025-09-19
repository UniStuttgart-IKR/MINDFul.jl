nowtime = starttime = DateTime("2026-01-01")
ibnfs = loadmultidomaintestibnfs(starttime;  useshortreachtransmissionmodules=true)

conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[3]), 11), GlobalNode(getibnfid(ibnfs[3]), 28), u"5.0Gbps")
intentuuid1 = addintent!(ibnfs[3], conintent1, NetworkOperator())


intcompalg = KShorestPathFirstFitCompilation(ibnfs[3], 10)

@test compileintent!(ibnfs[3], intentuuid1, intcompalg; offsettime = nowtime) == ReturnCodes.SUCCESS
