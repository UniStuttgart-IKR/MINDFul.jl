# This file contains the interace of IBN to the physical resources control

"""
$(TYPEDSIGNATURES)
"""
function allocate_transmissionmodule(ibnf::IBNFramework, 
                                     dagnodeid::UUID, 
                                     localnode::LocalNode, 
                                     transmissionmodulereservationentry::TransmissionModuleLLI)
    # delegate to SDN
    success = allocate_transmissionmodule(getsdncontroller(ibnf), localnode, transmissionmodulereservationentry)
    success || return false

    # upgrade views reservations
    nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]
    reserve!(nodeview, dagnodeid, transmissionmodulereservationentry)

    return true
end

"""
$(TYPEDSIGNATURES)
"""
function deallocate_transmissionmodule(ibnf::IBNFramework, 
                                 localnode::LocalNode, 
                                 transmissionmodulereservationentry::TransmissionModuleLLI)
    # delegate to SDN
    success = allocate_transmissionmodule(getsdncontroller(ibnf), localnode, transmissionmodulereservationentry)
    success || return false
    return false

    # upgrade views reservations
    nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]
    unreserve!(nodeview, dagnodeid, transmissionmodulereservationentry)

    return true
end

"""
$(TYPEDSIGNATURES)
"""
function allocate_oxcspectrumslots(ibnf::IBNFramework,
                                dagnodeid::UUID, 
                                localnode::LocalNode, 
                                )
    return false
end
