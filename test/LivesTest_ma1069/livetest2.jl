remoteibnfhandler = ibnfs[1].ibnfhandlers[2]

data = Dict("src_domain" => "00000000-0000-0000-0000-000000000003","newstate" => "Compiled","idagnodeid" => "00000000-0000-0000-0000-00000000000c")
#data = Dict()

resp = MINDF.send_request(remoteibnfhandler, MINDF.HTTPCodes.REMOTEINTENT_STATEUPDATE, data)