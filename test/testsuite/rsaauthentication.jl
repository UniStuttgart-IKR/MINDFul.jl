function testsuitersa()
    secret = rand(UInt8, 32)

    CONFIGDIR = joinpath(TESTDIR, "data")
    generatekeysfilepath = joinpath(dirname(TESTDIR), "scripts/generatekeys.sh")
    run(`$generatekeysfilepath $CONFIGDIR`)
    
    rsapublickeyb64 = MINDF.readb64keys(joinpath(CONFIGDIR, "rsa_pub1.pem"))
    rsapublickeypem = """
    -----BEGIN PUBLIC KEY-----
    $rsapublickeyb64
    -----END PUBLIC KEY-----
    """

    rsaprivatekeyb64= MINDF.readb64keys(joinpath(CONFIGDIR, "rsa_priv1.pem"))
    rsaprivatekeypem = """
    -----BEGIN PRIVATE KEY-----
    $rsaprivatekeyb64
    -----END PRIVATE KEY-----
    """
    
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

@testset ExtendedTestSet "rsaauthentication.jl"  begin

testsuitersa()

end