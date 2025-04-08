## Public getters interface
```@autodocs
Modules = [MINDFul, MINDFul.IntentState]
Private = false
Order   = [:function]
Filter = t -> t isa Function && occursin(r"^get", String(Symbol(t)))
```

## Other public interface
```@autodocs
Modules = [MINDFul, MINDFul.IntentState]
Private = false
Order   = [:module, :constant, :type, :function, :macro]
Filter = t -> !(t isa Function) || !occursin(r"^get", String(Symbol(t)))
```

## Non-public interface

```@autodocs
Modules = [MINDFul, MINDFul.IntentState]
Public = false
```
