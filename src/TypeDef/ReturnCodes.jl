"""
    The return codes defined for functions to give back explaining the situation.
    Mostly used for the compilation of an intent.
    All the `const` variables have a `Symbol` value that is the same as the variable name but only the first letter capitalized.
 """
module ReturnCodes

public SUCCESS, FAIL, FAIL_SPECTRUM, FAIL_OPTICALREACH, FAIL_OPTICALREACH_OPTINIT, FAIL_OPTICALREACH_OPTINIT_RETRY, FAIL_SRCROUTERPORT, FAIL_DSTROUTERPORT

"Signifies everything worked as planned"
const SUCCESS = :Success

"Signifies generic failure"
const FAIL = :Fail

"No available spectrum was found"
const FAIL_SPECTRUM = :Fail_availabilityspectrum

"No available connection for the given optical reach was found"
const FAIL_OPTICALREACH = :Fail_opticalreach

"No available connection for the given optical reach, coming from an initiate optical constraint, was found"
const FAIL_OPTICALREACH_OPTINIT = :Fail_opticalreach_optinit

"No available connection for the given optical reach, coming from an initiate optical constraint, was found even after retrying/recompiling"
const FAIL_OPTICALREACH_OPTINIT_RETRY = :Fail_opticalreach_optinit_retry

"No available router ports were found in source node"
const FAIL_SRCROUTERPORT = :Fail_srcrouterport

"No available router ports were found in destination node"
const FAIL_DSTROUTERPORT = :Fail_dstrouterport

"Source transmission module not found"
const FAIL_SRCTRANSMDL = :Fail_srctrnsmdl

"Destination transmission module not found"
const FAIL_DSTTRANSMDL = :Fail_srctrnsmdl

"Source OXC Add/Drop port not found"
const FAIL_SRCOXCADDDROPPORT = :Fail_srcoxcadddropport

"Destination OXC Add/Drop port not found"
const FAIL_DSTOXCADDDROPPORT = :Fail_dstoxcadddropport

end
