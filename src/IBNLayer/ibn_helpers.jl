"""
$(TYPEDSIGNATURES) 

Request topology information
"""
function getnetworkoperatoridagnodes(idag::IntentDAG)
    return filter(x -> getintentissuer(x) == NetworkOperator(), getidagnodes(idag))
end
