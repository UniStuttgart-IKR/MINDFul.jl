nowtime = starttime = DateTime("2026-01-01")
compalg = KShorestPathFirstFitCompilation(10; nodenum=1)

ibnfs = loadmultidomaintestibnfs(compalg, starttime;  useshortreachtransmissionmodules=true)

conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[3]), 11), GlobalNode(getibnfid(ibnfs[3]), 28), u"5.0Gbps")
intentuuid1, _ = addintent!(ibnfs[3], conintent1, NetworkOperator())

returncode, nowtime = compileintent!(ibnfs[3], intentuuid1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
