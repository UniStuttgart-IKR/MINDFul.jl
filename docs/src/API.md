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

## Public return codes
```@autodocs
Modules = [MINDFul.ReturnCodes]
Private = false
Order   = [:module, :constant, :type, :function, :macro]
```

## Non-public interface

```@autodocs
Modules = [MINDFul, MINDFul.IntentState]
Public = false
Order   = [:module, :constant, :type, :function, :macro]
```
