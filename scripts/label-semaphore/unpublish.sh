#!/usr/bin/env bash

validate_argo_dependencies "${GITHUB_REPOSITORY_OWNER}" "${ARGO_REPO}" "${ARGO_APP_PATH}"


_work_dir="/tmp/semaphore-workdir"
_local_file_path="${_work_dir}/file.yaml"
_alpha_release_config_path=".enableAlphaChannelForImage"
log_out "creating temporary working directory"
mkdir "${_work_dir}"

## Label Checks

log_out "Starting Label Semaphore for Unpublishing PR Environment!"

log_out "Checking label on other Pull Requests."
_label_present_on_other_prs="$(check_label_on_other_prs "${GITHUB_REPOSITORY_OWNER}" "${REPO_NAME}" "${PR_NUMBER}" "${PR_LABEL}")"
log_out "Was the label present on other Pull Requests? ${_label_present_on_other_prs}"

log_out "Outputting flag for changing revision on ArgoCD"

if [[ "$(check_bool "${_label_present_on_other_prs}")" ]]; then
  log_out "Label present on other Pull Requests. Halting revision change on ArgoCD." "INFO" 0
else
  log_out "Label not present on other Pull Requests. Proceeding with revision change on ArgoCD."
fi

## Semaphore Operations
log_out "Fetching target file to update"
_file_metadata="$(get_remote_file_metadata "${GITHUB_REPOSITORY_OWNER}" "${ARGO_REPO}" "${ARGO_APP_PATH}" 'master')"
_remote_src_file_download_url="$(echo "${_file_metadata}"  | jq -cr '.download_url')"
_remote_src_file_sha="$(echo "${_file_metadata}"  | jq -cr '.sha')"
download_file "${_local_file_path}" "${_remote_src_file_download_url}"

log_out "Fetching current live revision"
_live_revision="$(yq e "${ARGO_REVISION_PATH}" "${_local_file_path}")"

DESIRED_REVISION="$(read_previous_revision_from_comment "${_local_file_path}" "${ARGO_REVISION_PATH}")"
[[ -z "${DESIRED_REVISION}" || "${DESIRED_REVISION}" == "null" ]] && log_out "The env variable 'DESIRED_REVISION' is required. Aborting." "ERROR" 1

[[ "${DESIRED_REVISION}" == "${_live_revision}" ]] && log_out "Current live version '${_live_revision}' is the same as the desired version '${DESIRED_REVISION}'. Exiting." "INFO" 0

log_out "Working with the following configs:"
log_out "  - DESIRED_REVISION: ${DESIRED_REVISION}"
log_out "  - LIVE_REVISION: ${_live_revision}"
log_out "  - REPO_NAME: ${REPO_NAME}"
log_out "  - ARGO_REPO: ${ARGO_REPO}"
log_out "  - ARGO_APP_PATH: ${ARGO_APP_PATH}"

log_out "Updating revision in file"
yq -i e "${ARGO_REVISION_PATH} |= \"${DESIRED_REVISION}\"" "${_local_file_path}"

delete_previous_revision_comment "${_local_file_path}" "${ARGO_REVISION_PATH}"

if [[ "$(check_bool "${PR_USE_ALPHA_CHANNEL}")" ]]; then
  log_out "Disabling Alpha Release on image."
  yq e "${_alpha_release_config_path} |= false" "${_local_file_path}" -i
fi

deploy_semaphore_changes "${GITHUB_REPOSITORY_OWNER}" "${REPO_NAME}" "${PR_NUMBER}" "${ARGO_REPO}" \
  'unpublish' "${DESIRED_REVISION}" "${ARGO_APP_PATH}" "${_remote_src_file_sha}" "${_local_file_path}"
