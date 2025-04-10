"""
    The return codes defined for functions to give back explaining the situation.
    Mostly used for the compilation of an intent.
    All the `const` variables have a `Symbol` value that is the same as the variable name but only the first letter capitalized.
 """
module ReturnCodes

public SUCCESS, FAIL, FAIL_SPECTRUM, FAIL_OPTICALREACH, FAIL_ROUTERPORT

"Signifies everything worked as planned"
const SUCCESS = :Success

"Signifies generic failure"
const FAIL = :Fail

"No available spectrum was found"
const FAIL_SPECTRUM = :Fail_availabilityspectrum

"No available connection for the given optical reach was found"
const FAIL_OPTICALREACH = :Fail_opticalreach

"No available router ports were found"
const FAIL_ROUTERPORT = :Fail_routerport

end
