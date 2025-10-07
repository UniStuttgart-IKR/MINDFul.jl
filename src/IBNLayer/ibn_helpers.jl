"""
$(TYPEDSIGNATURES) 

Request topology information
"""
function getnetworkoperatoridagnodes(idag::IntentDAG)
    return filter(x -> getintentissuer(x) == NetworkOperator(), getidagnodes(idag))
end

function getloginterupdowntimesperintent(ibnf::IBNFramework, intentuuid::UUID)
    intentcomp = getintcompalg(ibnf)
    intentinterupdowntimes = UpDownTimesNDatetime[]
    for dictuuidupdowndatetime in values(getloginterupdowntimes(intentcomp))
        for (intuuid, updownndatetime) in dictuuidupdowndatetime
            if intuuid == intentuuid
                push!(intentinterupdowntimes, updownndatetime)
            end
        end
    end
    return intentinterupdowntimes
end
