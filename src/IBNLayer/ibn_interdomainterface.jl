# Every function in this file should be implemented for all `AbstractIBNFHandler`

"""
$(TYPEDSIGNATURES) 

Request topology information
"""
function requestibnattributegraph(myibnf::IBNFramework, remoteibnf::IBNFramework)
    return getibnag(remoteibnf)
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation
If far away, think about authorization and permissions.
That's the reason why there are 2 arguments: The first argument should have the authorization.
"""
function requestibnattributegraph(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    error("not implemented")
end
