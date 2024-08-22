
# This script contains unit tests for the gcp-batchdecomm.sh script.

# Import bats testing framework
# Load bats-support and bats-assert libraries
load '/path/to/bats-support/load.bash'
load '/path/to/bats-assert/load.bash'

# Source the script to test
source /path/to/gcp-batchdecomm.sh

# Test case: move_project moves project to destination folder
@test "move_project moves project to destination folder" {
    run move_project
    assert_success
    assert_output --partial "Moving project ${prj} to folder ${dest}"
}

# Test case: get_iam_members retrieves owner, editor and custom role members
@test "get_iam_members retrieves owner, editor and custom role members" {
    run get_iam_members
    assert_success
    assert [ -n "$owner" ]
    assert [ -n "$editor" ]
    assert [ -n "$custom" ]
}

# Test case: disable_api_keys disables all API keys
@test "disable_api_keys disables all API keys" {
    mock_command gcloud "echo 'key1\nkey2'"
    run disable_api_keys
    assert_success
    assert_output --partial "Disabling API key: key1"
    assert_output --partial "Disabling API key: key2"
}

# Test case: disable_service_accounts disables all service accounts
@test "disable_service_accounts disables all service accounts" {
    mock_command gcloud "echo 'account1@project.iam.gserviceaccount.com\naccount2@project.iam.gserviceaccount.com'"
    run disable_service_accounts
    assert_success
    assert_output --partial "Disabling service account: account1@project.iam.gserviceaccount.com"
    assert_output --partial "Disabling service account: account2@project.iam.gserviceaccount.com"
}

# Test case: save_project_iam saves and uploads IAM policy
@test "save_project_iam saves and uploads IAM policy" {
    mock_command gsutil "echo 'File uploaded'"
    run save_project_iam
    assert_success
    assert_output --partial "File uploaded"
}

# Test case: dismiss_recommendation dismisses existing recommendation
@test "dismiss_recommendation dismisses existing recommendation" {
    rec_id="test_rec_id"
    etag="test_etag"
    run gcloud recommender recommendations mark-dismissed "${rec_id}" --etag="${etag}" --location=global --recommender=google.resourcemanager.projectUtilization.Recommender --organization="${orgid}"
    assert_success
}

# Test case: process_project performs all decommissioning steps
@test "process_project performs all decommissioning steps" {
    run process_project
    assert_success
    assert_output --partial "Project ${prj} moved to folder ${dest}"
    assert_output --partial "labeled with ${label_key}=${label_value}"
    assert_output --partial "billing has been removed"
    assert_output --partial "owner/editor/custom roles have been disabled"
    assert_output --partial "service accounts, api keys and oauth clients have been disabled"
    assert_output --partial "recommendations marked as completed"
    assert_output --partial "has been unmarked from Recommendeder Dashboard"
}
  assert_success
  assert_output --partial "Project ${prj} moved to folder ${dest}"
  assert_output --partial "labeled with ${label_key}=${label_value}"
  assert_output --partial "billing has been removed"
  assert_output --partial "owner/editor/custom roles have been disabled"
  assert_output --partial "service accounts, api keys and oauth clients have been disabled"
  assert_output --partial "recommendations marked as completed"
  assert_output --partial "has been unmarked from Recommendeder Dashboard"
}