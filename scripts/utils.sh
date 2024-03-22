#!/usr/bin/env bash

########################################################################################################
##### This script hosts common functions and utils for all the scripts
#####   Common Environment Variables: Environment variables to configure for all scripts are
#####     LOG_LEVEL:
#####       description: For setting log level during the execution
#####       type: enum ["DEBUG" "INFO" "WARNING" "ERROR" "FATAL"]
#####       default: INFO
#####     LOG_TIMESTAMPED:
#####       description: For adding timestamps to log messages
#####       type: bool
#####       default: false
#####     DEBUG_MODE:
#####       description: For setting debug output
#####       type: bool
#####       default: false
########################################################################################################

set -e

# Defining available log levels.
case "$(echo "${LOG_LEVEL:-INFO}" | tr '[:lower:]' '[:upper:]')" in
"DEBUG")
  availableLogLevels=("DEBUG" "INFO" "WARNING" "ERROR" "FATAL")
  ;;
"INFO")
  availableLogLevels=("INFO" "WARNING" "ERROR" "FATAL")
  ;;
"WARNING")
  availableLogLevels=("WARNING" "ERROR" "FATAL")
  ;;
"ERROR" | "FATAL")
  availableLogLevels=("ERROR" "FATAL")
  ;;
*)
  availableLogLevels=("INFO" "WARNING" "ERROR" "FATAL")
  echo -e "[Warning] unrecognized log level variable '${LOG_LEVEL}'." \
    "\n\tDefaulting to 'INFO' level" \
    "\n\tAvailable log levels are: 'DEBUG' 'INFO' 'WARNING' 'ERROR' 'FATAL'."
  ;;
esac

# The `log_out` function logs out a message with timestamp and exists with a specific code if is set.
# Parameters:
#   [REQUIRED] ${1} the log message
#   [OPTIONAL] ${2} the log level of the message. Defaults to 'INFO'
#   [OPTIONAL] ${3} exit code. Default empty.
function log_out() {
  _message="${1}"
  _level="${2:-INFO}"
  _exitCode="${3}"

  for _lvl in "${availableLogLevels[@]}"; do
    [[ "${_lvl,,}" == "${_level,,}" && "$(check_bool "${LOG_TIMESTAMPED}")" ]] && echo -e "[$(date +"%FT%T%Z") | ${_level^^}] ${_message}"
    [[ "${_lvl,,}" == "${_level,,}" && -z "$(check_bool "${LOG_TIMESTAMPED}")" ]] && echo -e "[${_level^^}] ${_message}"
  done

  [[ -z "${_exitCode}" ]] || exit "${_exitCode}"
}

function log_debug() {
  _message="${1}"
  log_out "${_message}" "DEBUG"
}
function log_info() {
  _message="${1}"
  log_out "${_message}" "INFO"
}
function log_warning() {
  _message="${1}"
  log_out "${_message}" "WARNING"
}
function log_error() {
  _message="${1}"
  _exitCode="${2}"
  log_out "${_message}" "ERROR" "${_exitCode}"
}
function log_fatal() {
  _message="${1}"
  _exitCode="${2:-1}"
  log_out "${_message}" "FATAL" "${_exitCode}"
}

# The `check_bool` function checks if a value is equal to: 'true', 'yes', 'y', 'enable', or 'enabled'.
# If the value is one of the above, it returns 'true' otherwise, returns empty.
# Parameters:
#   [REQUIRED] ${1} the value to check
function check_bool() {
  _input="${1}"
  if [[ "${_input,,}" =~ ^(true)|(y(es)?)|(enable(d)?)$ ]]; then
    echo "true"
  fi
}

# The `check_env_var` function checks if an environment variable is required or not
# by its name which is passed as the first parameter. Depending on the value fo the
# second parameter, either exists with an error if the variable is not set, or logs
# out a warning staging that it is missing.
# Parameters:
#   [REQUIRED] ${1} environment variable name
#   [OPTIONAL] ${2} bool flag stating that the variable is required. Defaults to 'true'
function check_env_var() {
  _envVar="${1}"
  _required="${2:-true}"

  [[ (-z "${!_envVar}" || "${!_envVar,,}" == "null") && "$(check_bool "${_required}")" ]] && log_out "The required environment variable '${_envVar}' is missing. Aborting." "FATAL" 1
  [[ (-z "${!_envVar}" || "${!_envVar,,}" == "null") && -z "$(check_bool "${_required}")" ]] && log_out "The environment variable '${_envVar}' is missing." "WARNING"
}

if [[ "$(check_bool "${DEBUG_MODE}")" ]]; then
  set -x
fi
