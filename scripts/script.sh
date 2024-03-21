#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"

# Your action logic goes here

# TODO(user): Use this helper function to check if a required env variable is set or not
check_env_var "SOME_INPUT"

# TODO(user): Use the `check_bool` helper function to check for bool values
if [[ "$(check_bool "true")" ]]; then
  # TODO(user): Use the `log_out` helper function to log messages
  log_out "hello world" "INFO"
  # The following are some handy logging functions
  log_debug "This is a DEBUG log"
  log_info "This is a INFO log"
  log_warning "This is a WARNING log"
  log_error "This is a ERROR log"
  log_fatal "This is a FATAL log"                         # <- This one exists with an error
  log_fatal "This is a FATAL log with custom exit code" 5 # <- This one exists with an error
  log_out "This is a custom log message that exits with code 10" "FATAL" 10
fi

# TODO(user): This is how to output something to GH actions
echo "some-output=HelloThereGeneralKenobi" >>"${GITHUB_OUTPUT}"
