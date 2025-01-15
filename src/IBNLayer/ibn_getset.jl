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

function getintentcounter(intentdaginfo::IntentDAGInfo)
    return intentdaginfo.intentcounter
end
