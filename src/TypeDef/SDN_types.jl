"""
The abstract type of the SDN controllers
"""
abstract type AbstractSDNController end

"""
$(TYPEDEF)

$(TYPEDFIELDS)
"""
struct SDNdummy <: AbstractSDNController end

function allocate_transmissionmodule(sdn::SDNdummy, node::LocalNode, transmissionmodulereservationentry::TransmissionModuleReservationEntry)
    return true
end
