distance(ibn::IBN, path::Vector{Int}) = sum(distance(get_prop(ibn.ngr, l, :link)) for l in edgeify(path))

function purgeintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, IBNFramework.douninstall, IBNFramework.SimpleIBNModus(), IBNFramework.directuninstall!; time)
    deploy!(ibn, intentidx, IBNFramework.douncompile, IBNFramework.SimpleIBNModus(), () -> nothing; time)
    remintent!(ibn, intentidx)
end

function restartintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, IBNFramework.douninstall, IBNFramework.SimpleIBNModus(), IBNFramework.directuninstall!; time)
    deploy!(ibn, intentidx, IBNFramework.douncompile, IBNFramework.SimpleIBNModus(); time)
end

function uninstallallintents!(ibn::IBN; time)
    for dag in ibn.intents
        deploy!(ibn, getid(dag), IBNFramework.douninstall, IBNFramework.SimpleIBNModus(), IBNFramework.directuninstall!; time)
    end
end
