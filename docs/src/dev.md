# Notes for developes and contributors

## Mental classification of functions per functionality
(must clarify these notes)
To expand upon:
allocate - deallocate
reserve - unreserve
function getters
get... -> get field
new... -> construct something new


## How to read variables
transmission -> trans\
module -> mdl\
mode -> mode\
index -> idx\
uuid -> id\
ibn framework -> ibnf\

## Testing

Usefull testing functions are in the `TestModule` weak dependency.
To access them you first need to load `Test` and `JET` and then use `Base.get_extention`.
```julia
# get the test module from MINDFul
import Test, JET
TestModule = Base.get_extension(MINDFul, :TestModule)
@test !isnothing(TM)
```
Now, with dot notation (`TestModule.`) you can access all the following functions. 

### Testing API

```@autodocs
Modules = [Base.get_extension(MINDFul, :TestModule)]
```
