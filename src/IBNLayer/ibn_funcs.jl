"""
$(TYPEDSIGNATURES)

Add a new user intent to the IBN framework.
"""
function addintent!(ibnf::IBNFramework, intent::AbstractIntent, intentissuer::IntentIssuer)
    intentdag = getintentdag(ibnf)
    addidagnode!(intentdag, intent; intentissuer)
end

"""
$(TYPEDSIGNATURES)
"""
function removeintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    intentdag = getintentdag(ibnf)
    intentdagstate = getidagnodestate(intentdag, idagnodeid)
    @returniffalse(verbose, intentdagstate == IntentState.Uncompiled)
    return removeidagnode!(intentdag, idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function compileintent!(ibnf::IBNFramework, idagnodeid::UUID)
end

"""
$(TYPEDSIGNATURES)
"""
function decompileintent!(ibnf::IBNFramework, idagnodeid::UUID)
end

"""
$(TYPEDSIGNATURES)
"""
function installintent!(ibnfid::IBNFramework, idagnodeid::UUID)
end

"""
$(TYPEDSIGNATURES)
"""
function uninstallintent!(ibnfid::IBNFramework, idagnodeid::UUID)
end
