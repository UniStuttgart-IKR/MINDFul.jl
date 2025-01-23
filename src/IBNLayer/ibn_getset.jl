function getsdncontroller(s)
    return s.sdncontroller
end

function getibnag(s)
    return s.ibnag
end

function getibnfid(s)
    return s.ibnfid
end

function getintentdag(s::IBNFramework)
    return s.intentdag
end

function getinteribnfs(s::IBNFramework)
    return s.interIBNFs
end

function getidagcounter(intentdaginfo::IntentDAGInfo)
    return intentdaginfo.intentcounter
end

function getidagnodeid(idagnode::IntentDAGNode)
    return idagnode.idagnodeid
end

function getidagnodestate(idagnode::IntentDAGNode)
    return getcurrentstate(getlogstate(idagnode))
end

function getlogstate(idagnode::IntentDAGNode)
    return idagnode.logstate
end

function getcurrentstate(intentlogstate::IntentLogState)
    return intentlogstate.logstate[end][2]
end
