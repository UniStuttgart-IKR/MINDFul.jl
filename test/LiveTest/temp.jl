findfirst(idndescs) do idagnode
    plightpathintent = getintent(idagnode)
    if plightpathintent isa MINDF.ProtectedLightpathIntent
        all(x -> MINDF.isonlyoptical(x), MINDF.getprdestinationnodeallocations(plightpathintent)) || return false
        prlightpaths = MINDF.getprpath(plightpathintent)
        all(x -> length(x) > 1, prlightpaths) || return false
        all(lightpath -> MINDF.getglobalnode(getibnag(ibnf), lightpath[end]) == MINDF.getglobalnode(splitbordernode), prlightpaths) || return false
        all(lightpath -> MINDF.getglobalnode(MINDF.getibnag(ibnf), lightpath[end - 1]) == MINDF.getglobalnode_input(opticalinitiateconstraint), prlightpaths) || return false
        all(spectrumslotrange -> spectrumslotrange == MINDF.getspectrumslotsrange(opticalinitiateconstraint), MINDF.getprspectrumslotsrange(plightpathintent)) || return false
        return true
    end
end

