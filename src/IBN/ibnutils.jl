distance(ibn::IBN, path::Vector{Int}) = sum(distance(get_prop(ibn.ngr, l, :link)) for l in edgeify(path))

function purgeintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    deploy!(ibn, intentidx, MINDFul.douncompile, MINDFul.SimpleIBNModus(), () -> nothing; time)
    remintent!(ibn, intentidx)
end

function restartintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    deploy!(ibn, intentidx, MINDFul.douncompile, MINDFul.SimpleIBNModus(); time)
end

function uninstallallintents!(ibn::IBN; time)
    for dag in ibn.intents
        deploy!(ibn, getid(dag), MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    end
end
