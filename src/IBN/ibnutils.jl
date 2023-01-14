"$(TYPEDSIGNATURES) Get total distance of `path` in `ibn`"
distance(ibn::IBN, path::Vector{Int}) = sum(distance(get_prop(ibn.ngr, l, :link)) for l in edgeify(path))

"$(TYPEDSIGNATURES) Uninstall, uncompile and delete all intents of `ibn`"
function purgeintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    deploy!(ibn, intentidx, MINDFul.douncompile, MINDFul.SimpleIBNModus(), () -> nothing; time)
    remintent!(ibn, intentidx)
end

"$(TYPEDSIGNATURES) Uninstall and uncompile intent `intentidx` in `ibn`"
function restartintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    deploy!(ibn, intentidx, MINDFul.douncompile, MINDFul.SimpleIBNModus(); time)
end

"$(TYPEDSIGNATURES) Uninstall all intents in `ibn`"
function uninstallallintents!(ibn::IBN; time)
    for dag in ibn.intents
        deploy!(ibn, getid(dag), MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    end
end
