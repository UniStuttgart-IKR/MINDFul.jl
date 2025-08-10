"""
$(TYPEDSIGNATURES)
Implementation of Diffiie-Hellman exchange for authentication. The shared secret serves as unilateral authentication challenge.
The post macro is used to handle the Diffie-Hellman exchange inside the Oxygen server module.
Also, the agreed prime number and one of its roots must be stored in the corresponding handlers of each domain.
"""
function diffiehellman_init(ibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler)
    initiatoribnfid = string(getibnfid(ibnf))

    publicnumber, privatenumber = diffiehellman_term(remoteibnfhandler)

    url = getbaseurl(remoteibnfhandler) * HTTPMessages.URI_DIFFIEHELLMAN
    headers = Dict("Content-Type" => "application/json")
    data = Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, HTTPMessages.KEY_PUBLICNUMBER => publicnumber)
    body = JSON.json(data)  
    
    response = HTTP.post(url, headers, body; keepalive=false, require_ssl_verification=false)
    if response.status == 200
        parsedresponse = JSON.parse(String(response.body))
        recievednumber = parsedresponse[HTTPMessages.KEY_PUBLICNUMBER]
        receivedsecret = parsedresponse[HTTPMessages.KEY_DHSECRET]
        return (receivedsecret == powermod(recievednumber, privatenumber, remoteibnfhandler.prime))
    else
        error("DH failed with $remoteibnfhandler: $(response.status)")
    end
end

function diffiehellman_term(remoteibnfhandler::RemoteHTTPHandler)
    prime = remoteibnfhandler.prime
    root = remoteibnfhandler.root
    privatenumber = rand(1:100)
    publicnumber = powermod(root, privatenumber, prime)
    return publicnumber, privatenumber
end


#=
@post api("/diffiehellman") function (req; context)
        ibnf = getmyibnf(req, context)
        
        parsedbody = JSON.parse(String(HTTP.payload(req)))
        remoteibnfid = parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID]
        publicnumberA = parsedbody[MINDF.HTTPMessages.KEY_PUBLICNUMBER]
        
        remotehandler = MINDF.getibnfhandler(ibnf, UUID(remoteibnfid))
     
        if !isnothing(publicnumberA) 
            publicnumberB, privatenumber = MINDF.diffiehellman_term(remotehandler)
            dhsecret = powermod(publicnumberA, privatenumber, remotehandler.prime)
            return HTTP.Response(200, JSON.json(Dict(MINDF.HTTPMessages.KEY_PUBLICNUMBER => publicnumberB, MINDF.HTTPMessages.KEY_DHSECRET => dhsecret)))
        else
            return HTTP.Response(403, "Nonce not received")
        end        
    end
=#