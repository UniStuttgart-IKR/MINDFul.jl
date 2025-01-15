"""
$(TYPEDSIGNATURES)

Add a new user intent to the IBN framework.
"""
function addintent!(ibnf::IBNFramework, intent::AbstractIntent)
    intentdag = getintentdag(ibnf)
    intentcounter = getintentcounter(intentdag)
    intentdagnode = IntentDAGNode(intent, UUID(intentcounter), NetworkOperator(), IntentLogState())
    addchild!(intentdag, intent)
end
