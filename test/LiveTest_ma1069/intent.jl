#Plot the multidomain graph
ibnplot(ibnf1; multidomain=true, shownodelabels = :local)

#Connectivity Intent between a node from domain 1 and a node from domain 3
intent = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps")

#Add the intent to the IBNFramework
intentid = MINDF.addintent!(ibnf1, intent, MINDF.NetworkOperator())

#Compile the intent with a especific algorithm
MINDF.compileintent!(ibnf1, intentid, MINDF.KShorestPathFirstFitCompilation(5))

#Plot the whole graph with the intent highlighted
ibnplot(ibnf1; multidomain=true, intentids = [intentid], shownodelabels = :local)

#Plot the intent
f,_,_=intentplot(ibnf1, intentid = intentid; multidomain=true, showstate = true, showintent = true); display(GLMakie.Screen(), f);

#Install the intent
MINDF.installintent!(ibnf1, intentid; verbose=true)



intent = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps"); intentid = MINDF.addintent!(ibnf1, intent, MINDF.NetworkOperator()); MINDF.compileintent!(ibnf1, intentid, MINDF.KShorestPathFirstFitCompilation(5))

handler = MINDF.getibnfhandler(ibnf1, UUID(3))
MINDF.requestavailablecompilationalgorithms_init!(ibnf1, handler)


# MINDF.installintent!(ibnf3, UUID(0x1); verbose=true)


#Check the low-level implementation of the intent
# MINDF.getlogicallliorder(ibnf1, intentuuid_neigh; onlyinstalled=false)


# RouterPortLLI(4, 61)
#  TransmissionModuleLLI(4, 11, 1, 61, 1)
#  OXCAddDropBypassSpectrumLLI(4, 0, 1, 1, 1:4)
#  OXCAddDropBypassSpectrumLLI(1, 4, 0, 22, 1:4)
#  OXCAddDropBypassSpectrumLLI(22, 1, 0, 21, 1:4)
#  OXCAddDropBypassSpectrumLLI(21, 22, 0, 23, 1:4)
#  OXCAddDropBypassSpectrumLLI(23, 21, 0, 17, 1:4)
#  OXCAddDropBypassSpectrumLLI(17, 23, 0, 29, 1:4)



#Uninstall the intent
MINDF.uninstallintent!(ibnf1, intentid)

#Uncompile the intent
MINDF.uncompileintent!(ibnf1, intentid)

#Remove the intent
MINDF.removeintent!(ibnf1, intentid)