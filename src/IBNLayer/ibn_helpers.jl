"""
$(TYPEDSIGNATURES) 
"""
function getnetworkoperatoridagnodes(idag::IntentDAG)
    return filter(x -> getintentissuer(x) == NetworkOperator(), getidagnodes(idag))
end

"""
$(TYPEDSIGNATURES) 
"""
function getnetworkoperatornremotenotinitidagnodes(idag::IntentDAG)
    return filter(x -> getintentissuer(x) == NetworkOperator() || (getintent(x) isa RemoteIntent && !getisinitiator(getintent(x))), getidagnodes(idag))
end

function getloginterupdowntimesperintent(ibnf::IBNFramework, intentuuid::UUID)
    intentcomp = getintcompalg(ibnf)
    intentinterupdowntimes = UpDownTimesNDatetime{IntentState.T}[]
    for dictuuidupdowndatetime in values(getloginterupdowntimes(intentcomp))
        for (intuuid, condata) in dictuuidupdowndatetime
	    updownndatetime = getupdowntimesndatetime(condata)
            if intuuid == intentuuid
                push!(intentinterupdowntimes, updownndatetime)
            end
        end
    end
    return intentinterupdowntimes
end
