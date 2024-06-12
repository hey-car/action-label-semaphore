#!/usr/bin/env bash

function get_formatted_comment_id() {
  _comment_id="${1}"
  echo "<!-- comment-id:${GITHUB_ACTION_NAME}:${_comment_id} -->"
}

# The `delete_previous_comments` function deletes comments by their ids from pull requests.
function delete_previous_comments() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pr_number="${3}"

  _nextPage="1"
  while [[ "${_nextPage}" != "0" ]]; do
    _comments="$(gh api "/repos/${_repo_org}/${_repo_name}/issues/${_pr_number}/comments?direction=asc&per_page=20&page=${_nextPage}")" || exit 1
    if [[ "$(echo "${_comments}" | jq '.|length')" == 0 ]]; then
      _nextPage="0"
    else
      _nextPage="$((_nextPage + 1))"
    fi
    while read -r _previous_comment_id; do
      log_out "Deleting previous comment with ID: ${_previous_comment_id}"
      gh api "/repos/${_repo_org}/${_repo_name}/issues/comments/${_previous_comment_id}" -X DELETE >/dev/null || exit 1
    done < <(echo "${_comments}" | jq ".[] | select(.body|startswith(\"$(get_formatted_comment_id "${_comment_id}")\")) | .id")
  done
}

# The `comment_on_pull_request` function pushes a comment to a pull request.
function comment_on_pull_request() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pr_number="${3}"
  _comment_body="${4}"
  _delete_previous_comments="${5}"
  _comment_id="${6}"

  if [[ "$(check_bool "${_delete_previous_comments}")" ]]; then
    if [[ -z "${_comment_id}" ]]; then
      log_out "No comment id was provided for deleting previous comments. Aborting." "FATAL" 1
    else
      delete_previous_comments "${_repo_org}" "${_repo_name}" "${_pr_number}"
    fi
  fi

  log_out "Commenting on ${_repo_org}/${_repo_name}#${_pr_number}"
  if [[ -z "${_comment_id}" ]]; then
    printf "%s" "${_comment_body}" | gh pr comment "${_pr_number}" -R "${_repo_org}/${_repo_name}" -F -
  else
    printf "%s \n %s" "$(get_formatted_comment_id "${_comment_id}")" "${_comment_body}" | gh pr comment "${_pr_number}" -R "${_repo_org}/${_repo_name}" -F -
  fi
}

# The `check_status_of_pr` function checks if a pull request is open, closed, or merged
function check_status_of_pr() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pr_number="${3}"

  gh pr view "${_pr_number}" -R "${_repo_org}/${_repo_name}" --json state | jq -cr '.state'
}

# The `check_label_on_current_pr` function checks if a certain label exists on a pull request
function check_label_on_current_pr() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pr_number="${3}"
  _pr_label="${4}"

  _label_result="$(gh pr view "${_pr_number}" -R "${_repo_org}/${_repo_name}" --json labels |
    jq "[.labels[].name] | index(\"${_pr_label}\")")"

  if [[ "${_label_result}" == "null" ]]; then
    echo "false"
  else
    echo "true"
  fi
}

# The `list_other_prs_with_label` function fetches pull requests with a label that are not the pull request in input
function list_other_prs_with_label() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pr_number="${3}"
  _pr_label="${4}"

  gh pr list -R "${_repo_org}/${_repo_name}" -l "${_pr_label}" --json number |
    jq "[.[] | select(.number != ${_pr_number})]"
}

# The `check_label_on_other_prs` function returns true if there are other pull requests have a certain label
function check_label_on_other_prs() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pr_number="${3}"
  _pr_label="${4}"

  _label_result="$(list_other_prs_with_label "${_repo_org}" "${_repo_name}" "${_pr_number}" "${_pr_label}")"

  if [[ "${_label_result}" == "[]" ]]; then
    echo "false"
  else
    echo "true"
  fi
}

# The `remove_label_from_pr` function deletes a label from a pull request
function remove_label_from_pr() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pr_number="${3}"
  _pr_label="${4}"

  gh pr edit "${_pr_number}" -R "${_repo_org}/${_repo_name}" --remove-label "${_pr_label}" >/dev/null
}

# The `find_repo_by_name` function fetches a repo by its name and checks if it exists
function find_repo_by_name() {
  _repo_org="${1}"
  _repo_name="${2}"

  _repo_search_result="$(gh search repos --owner "${_repo_org}" --match name "${_repo_name}" --json 'name,fullName' | jq "[.[] | select(.name == \"${_repo_name}\")]")"

  if [[ "${_repo_search_result}" == "[]" ]]; then
    echo "false"
  else
    echo "true"
  fi
}

# The `get_remote_file_metadata` function fetches the download url of a file
function get_remote_file_metadata() {
  _repo_org="${1}"
  _repo_name="${2}"
  _file_path="${3}"
  _base_ref="${4}"

  gh api "/repos/${_repo_org}/${_repo_name}/contents/${_file_path}?ref=${_base_ref}" | jq -cr '{"download_url":.download_url,"sha":.sha}'
}

# The `validate_argo_dependencies` function checks if a certain file exists in a repo
function validate_argo_dependencies() {
  _repo_org="${1}"
  _repo_name="${2}"
  _file_path="${3}"

  log_out "Validating Argo Dependencies"
  log_out "Validating Argo Repo"
  _argo_repo_found="$(find_repo_by_name "${_repo_org}" "${_repo_name}")"
  if [[ "${_argo_repo_found}" == "false" ]]; then
    log_out "The provided Argo Repo '${_repo_org}/${_repo_name}' was not found. Aborting." "ERROR" 1
  fi
  log_out "Validating Argo App Path"
  _argo_app_file_found="$(get_remote_file_metadata "${_repo_org}" "${_repo_name}" "${_file_path}" 'master' | jq -cr '.download_url')"
  if [[ "${_argo_app_file_found}" == "null" ]]; then
    log_out "The provided Argo App Path '${_file_path}' was not found under the repo '${_repo_org}/${_repo_name}'. Aborting." "ERROR" 1
  fi
}

# The `create_revision_publish_branch` function creates a branch on a remote repo
function create_revision_publish_branch() {
  _repo_org="${1}"
  _repo_name="${2}"
  _base_ref="${3}"
  _branch_name="${4}"

  _head_sha="$(gh api "/repos/${_repo_org}/${_repo_name}/git/refs/heads/${_base_ref}" | jq -cr '.object.sha')"

  gh api "/repos/${_repo_org}/${_repo_name}/git/refs" -X POST -F ref="refs/heads/${_branch_name}" -F sha="${_head_sha}" >/dev/null
}

# The `commit_file_to_branch` function commits a file to a remote repo
function commit_file_to_branch() {
  _repo_org="${1}"
  _repo_name="${2}"
  _publish_action="${3}"
  _desired_revision="${4}"
  _argo_app_path="${5}"
  _remote_src_file_sha="${6}"
  _local_file_path="${7}"
  _branch_name="${8}"

  _local_file_b64="$(base64 -i "${_local_file_path}" | tr -d '\n')"

  gh api "/repos/${_repo_org}/${_repo_name}/contents/${_argo_app_path}" -X PUT \
    -F message="chore(sem:${_publish_action}): changes app version to ${_desired_revision}" \
    -F sha="${_remote_src_file_sha}" \
    -F branch="${_branch_name}" \
    -F content="${_local_file_b64}" >/dev/null
}

# The `create_pull_request` function creates a pull request on a remote repo
function create_pull_request() {
  _repo_org="${1}"
  _repo_name="${2}"
  _base_ref="${3}"
  _publish_action="${4}"
  _desired_revision="${5}"
  _branch_name="${6}"

  gh pr create -R "${_repo_org}/${_repo_name}" -B "${_base_ref}" -H "${_branch_name}" \
    --body "This PR has been created by the Label Semaphore Workflow inside HeyCar's Argo Workflows." \
    -t "chore(sem:${_publish_action}): changes app version to ${_desired_revision}" 2>/dev/null |
    grep "${_repo_org}/${_repo_name}" | cut -d '/' -f 7
}

# The `merge_pull_request` function merges a remote pull request
function merge_pull_request() {
  _repo_org="${1}"
  _repo_name="${2}"
  _pull_request_number="${3}"

  gh pr merge "${_pull_request_number}" -R "${_repo_org}/${_repo_name}" --squash --admin --delete-branch
}
