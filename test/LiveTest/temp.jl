 # MINDFM.intentplot(ibnfs[1]; intentid=intentuuid1, showstate = true, showintent=true, multidomain=true, subidag=:connected, graphattr=(;arrow_size=15, nlabels_fontsize=20))

 for ibnf in ibnfs
     idag = MINDF.getidag(ibnf)
     for idagnode in MINDF.getidagnodes(idag)
	 for ls in MINDF.getlogstate(idagnode)
	     if ls[2] == MINDF.IntentState.Pending
		 @show MINDF.getibnfid(ibnf), MINDF.getidagnodeid(idagnode)
	     end
	 end
     end
 end
