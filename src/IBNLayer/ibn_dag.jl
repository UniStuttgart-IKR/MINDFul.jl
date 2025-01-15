# IntentDAG customizations

function getintentcounter(intentdag::IntentDAG)
    return getintentcounter(AG.graph_attr(intentdag))
end

function addchild(intentdag::IntentDAG, intent::AbstractIntent)

end
