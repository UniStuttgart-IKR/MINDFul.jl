
@testset ExtendedTestSet "rsaauthentication.jl"  begin
    secret = rand(UInt8, 32)

    CONFIGDIR = joinpath(TESTDIR, "data")
    MINDF.generateRSAkeys(CONFIGDIR)
    
    rsapublickeyb64 = MINDF.readb64keys(joinpath(CONFIGDIR, "rsa_pub1.pem"))
    rsapublickeypem = MINDF.convertb64keytopem(rsapublickeyb64, MINDF.HTTPMessages.KEY_TYPEOFPUBLICKEY)

    rsaprivatekeyb64= MINDF.readb64keys(joinpath(CONFIGDIR, "rsa_priv1.pem"))
    rsaprivatekeypem = MINDF.convertb64keytopem(rsaprivatekeyb64, MINDF.HTTPMessages.KEY_TYPEOFPRIVATEKEY)
    
    pk_ctx_encrypt = MbedTLS.PKContext()
    MbedTLS.parse_public_key!(pk_ctx_encrypt, rsapublickeypem)

    rng = MbedTLS.CtrDrbg()
    entropy = MbedTLS.Entropy()
    MbedTLS.seed!(rng, entropy, Vector{UInt8}("RSAAuth"))

    encryptedsecret = zeros(UInt8, 256)
    MbedTLS.encrypt!(pk_ctx_encrypt, secret, encryptedsecret, rng)


    pk_ctx_decrypt = MbedTLS.PKContext()
    MbedTLS.parse_key!(pk_ctx_decrypt, rsaprivatekeypem)
    decryptedsecret = zeros(UInt8, length(encryptedsecret))
    outlen = MbedTLS.decrypt!(pk_ctx_decrypt, encryptedsecret, decryptedsecret, rng)

    @test decryptedsecret[1:outlen] == secret

end
