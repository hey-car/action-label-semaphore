#!/usr/bin/env bash

function download_file() {
  _file_download_url="${1}"
  _remote_src_file_download_url="${2}"
  curl -X GET "${_remote_src_file_download_url}" -s -o "${_file_download_url}"
}

function read_previous_revision_from_comment() {
  _local_file_path="${1}"
  _revision_path="${2}"
  _live_revision_comment="${3}"

  _live_revision_comment="$(yq e "${_revision_path} | line_comment" "${_local_file_path}" | cut -d ';' -f 1)"
  if [[ "${_live_revision_comment}" ]]; then
    echo "${_live_revision_comment}" | jq -cr '.previous_version'
  else
    echo "null"
  fi
}

function add_previous_revision_comment() {
  _local_file_path="${1}"
  _revision_path="${2}"
  _previous_revision="${3}"

  _comment="{\\\"previous_version\\\": \\\"${_previous_revision}\\\"}; This comment is used by the CI. Please do not remove."

  yq -i e "${_revision_path} line_comment=\"${_comment}\"" "${_local_file_path}"
}

function delete_previous_revision_comment() {
  _local_file_path="${1}"
  _revision_path="${2}"

  yq -i e "${_revision_path} line_comment=\"\"" "${_local_file_path}"
}

function is_revision_stable() {
  _previous_revision="${1}"

  if [[ "${_previous_revision}" =~ ^v?[0-9]+((.[0-9]+.[0-9]+)|(-latest))$ ]]; then
    echo "true"
  else
    echo "false"
  fi
}

function deploy_semaphore_changes() {
  _repo_org="${1}"
  _current_repo_name="${2}"
  _pr_number="${3}"
  _argo_repo_name="${4}"
  _publish_operation="${5}"
  _desired_revision="${6}"
  _argo_app_path="${7}"
  _remote_src_file_sha="${8}"
  _local_file_path="${9}"

  _exec_uid="$(date +%s | base64 | tr -d '=')-$((1 + $RANDOM % 10))"
  _branch_name="sem-${_publish_operation}/$(basename "${_argo_app_path%.yaml}" | tr '/' '-')-${_desired_revision}-${_exec_uid}"

  log_out "Creating a temporary branch for pushing the changes into."
  create_revision_publish_branch "${_repo_org}" "${_argo_repo_name}" 'master' "${_branch_name}"

  log_out "Committing file changes to branch."
  commit_file_to_branch "${_repo_org}" "${_argo_repo_name}" "${_publish_operation}" "${_desired_revision}" "${_argo_app_path}" "${_remote_src_file_sha}" "${_local_file_path}" "${_branch_name}"

  log_out "Creating a Pull Request to deploy changes."
  _bump_pull_request="$(create_pull_request "${_repo_org}" "${_argo_repo_name}" 'master' "${_publish_operation}" "${_desired_revision}" "${_branch_name}")"

  log_out "Merging Pull Request  ${_repo_org}/${_argo_repo_name}#${_bump_pull_request} to deploy changes."
  set +e
  merge_pull_request "${_repo_org}" "${_argo_repo_name}" "${_bump_pull_request}"
  _merge_status="$?"
  set -e
  if [[ "${_merge_status}" != "0" ]]; then
    # Wait between 2 and 12 seconds before attempting another merge to bypass Github's concurrent merge block
    _random_wait="$((((RANDOM % 6) + 1) * 2))"
    log_out "Failed to merge pull request due to a concurrency. Waiting for ${_random_wait} until next attempt." "WARN"
    sleep "${_random_wait}"
    merge_pull_request "${_repo_org}" "${_argo_repo_name}" "${_bump_pull_request}"
  fi

  log_out "commenting on Pull Request ${_repo_org}/${_current_repo_name}#${_pr_number} to inform of changes."
  comment_on_pull_request "${_repo_org}" "${_current_repo_name}" "${_pr_number}" ":rocket: Your revision '${_desired_revision}' has been ${_publish_operation}ed by the PR ${_repo_org}/${_argo_repo_name}#${_bump_pull_request}." "true" "label-semaphore:${SEMAPHORE_ACTION}"
}
