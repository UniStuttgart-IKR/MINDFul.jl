distance(ibn::IBN, path::Vector{Int}) = sum(distance(get_prop(ibn.cgr, l, :link)) for l in edgeify(path))

function purgeintent!(ibn::IBN, intentidx::Int)
    deploy!(ibn, intentidx, IBNFramework.douninstall, IBNFramework.SimpleIBNModus(), IBNFramework.directuninstall!)
    deploy!(ibn, intentidx, IBNFramework.douncompile, IBNFramework.SimpleIBNModus(), () -> nothing)
    remintent!(ibn, intentidx)
end

function restartintent!(ibn::IBN, intentidx::Int)
    deploy!(ibn, intentidx, IBNFramework.douninstall, IBNFramework.SimpleIBNModus(), IBNFramework.directuninstall!)
    deploy!(ibn, intentidx, IBNFramework.douncompile, IBNFramework.SimpleIBNModus(), () -> nothing)
end

function uninstallallintents!(ibn::IBN)
    for dag in ibn.intents
        deploy!(ibn, getid(dag), IBNFramework.douninstall, IBNFramework.SimpleIBNModus(), IBNFramework.directuninstall!)
    end
end
