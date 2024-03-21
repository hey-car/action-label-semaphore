#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"
. "$(dirname "$0")/gh-utils.sh"
. "$(dirname "$0")/label-semaphore/utils.sh"
# Your action logic goes here

export REPO_NAME="${GITHUB_REPOSITORY#*/}"
check_env_var "GITHUB_TOKEN"
check_env_var "PR_NUMBER"
check_env_var "PR_LABEL"
check_env_var "ARGO_REPO"
check_env_var "PR_USE_ALPHA_CHANNEL"
check_env_var "ARGO_APP_PATH"
check_env_var "ARGO_REVISION_PATH"
check_env_var "SEMAPHORE_ACTION"

case "${SEMAPHORE_ACTION}" in
publish)
  . "$(dirname "$0")/label-semaphore/publish.sh"
  ;;
unpublish)
  . "$(dirname "$0")/label-semaphore/unpublish.sh"
  ;;
sync)
  . "$(dirname "$0")/label-semaphore/sync.sh"
  ;;
*)
  log_fatal "Unrecognized label semaphore action '${SEMAPHORE_ACTION}'. Must be one of the following: publish, unpublish, or sync"
  ;;
esac
