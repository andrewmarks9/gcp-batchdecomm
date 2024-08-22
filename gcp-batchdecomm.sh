#!/bin/bash

# prj: Project ID variable to store current project being processed
# dest: Destination folder ID for moving the project
# timestamp: Generates a timestamp string to use in log/error log filenames
# log: Log file name constructed from timestamp
# err_log: Error log filename constructed from timestamp
# expire_date: Decommission expiration date string in YYYY-MM-DD format
# orgid: Organization ID
# label_key: Label key for decomm_expiration label
# label_value: Label value set to expire_date for decomm_expiration label
# label_key2: Label key for decomm-ticket label
# label_value2: Label value for decomm-ticket label

dest=FOLDER_ID
timestamp=$(date +%Y-%m-%d_%H:%M:%S)
log=${timestamp}_log.txt
err_log=${timestamp}_error_log.txt
expire_date=$(date +%Y-%m-%d)
orgid=ORGANIZATION_ID
label_key=decomm_expiration
label_value=${expire_date}
label_key2=decomm-ticket
label_value2=TICKET_NUMBER



# Read project id from csv into an array
# update test.csv to current file name
mapfile -t prj_list < PROJECT_LIST.csv

# Loop through each project id
for prj in "${prj_list[@]}";  # ./Use prj_list here
do
# Remove newlines and whitespace from Project ID
prj=$(echo "${prj}" | tr -d '[:space:]')
# Print project for debugging
echo "Project: ${prj}"
  


# Call function to move project to destination folder

function move_project() {

  echo "Moving project ${prj} to folder ${dest}" >>"${log}"
  gcloud beta projects move "${prj}" -q --folder "${dest}" >>"${log}"
  gcloud alpha projects update "${prj}" --update-labels="${label_key}"="${label_value}"
  gcloud alpha projects update "${prj}" --update-labels="${label_key2}"="${label_value2}"
  gcloud alpha billing projects unlink "${prj}" >>"${log}"

}


# Get the IAM policy for the current project
# Use jq to extract just the members for the owner,editor,and legacy custom role

function get_iam_members() {

  owner=$(gcloud projects get-iam-policy "${prj}" --format=json | jq -r '.bindings[] | select(.role == "roles/owner") | .members[]')

  editor=$(gcloud projects get-iam-policy "${prj}" --format=json | jq -r '.bindings[] | select(.role == "roles/editor") | .members[]')
   
  custom=$(gcloud projects get-iam-policy "${prj}" --format=json | jq -r '.bindings[] | select(.role == "organizations/387112372795/roles/svcandauthmgr") | .members[]')

}

#Delete API Keys Function

function disable_api_keys() {
	# Get list of API keys
	api_keys=$(gcloud services api-keys list --project="${prj}" --format="value(name)")

	# Check for errors
	if [[ $? -ne 0 ]]; then
		echo "Error getting API keys: ${api_keys}" >>"${error_log}"
		exit 1
	fi

	# Loop through and delete keys
	# API Keys can be restored for 30 days
	if [[ -n ${api_keys} ]]; then
		for key in ${api_keys}; do
			echo "Disabling API key: ${key}"
			gcloud beta services api-keys delete "${key}" --project="${prj}" &
		done
	else
		echo "No API keys found" >>"${log}"
	fi

	wait
}

#Disable service accounts function

function disable_service_accounts() {

	# Get list of service accounts
	service_accounts=$(gcloud iam service-accounts list --project="${prj}" --format="value(email)")

	# Check for errors
	if [[ $? -ne 0 ]]; then
		echo "Error getting service accounts: ${service_accounts}" >>"${error_log}"
		exit 1
	fi

	# Loop through and disable accounts
	if [[ -n ${service_accounts} ]]; then
		for account in ${service_accounts}; do
			echo "Disabling service account: ${account}"
			gcloud iam service-accounts disable "${account}" --project="${prj}" &
		done
	else
		echo "No service accounts found" >>"${log}"
	fi

	wait

}

#Save Iam policy for project before modifying and upload
#to GCS Bucket in case of rollback

# Saves the IAM policy for the current project to a file
# before making any modifications to roles/members.
# Uploads the policy file to a GCS bucket for backup.
# This allows the original policy to be restored if needed.

function save_project_iam() {
	#set file name
	iam=${label_value2}_${prj}_iam_users.json

	# Get IAM policy
	policy=$(gcloud projects get-iam-policy "${prj}" --format=json)

	# Save policy to local file
	echo "${policy}" >>"${iam}"

	# Upload file to GCS bucket
	gsutil cp "${iam}" gs://decommissioning-projects-backup/iam_policy/

	# Remove local file
	rm "${iam}"

}


# Call functions in sequence to prepare project for decommissioning
# 1. Move project to decommissioning folder
# 2. Get IAM members for project
# 3. Save IAM policy for project before modifying

move_project
wait
get_iam_members
wait
save_project_iam

# Disables API keys and service accounts for the project.
# Calls disable_api_keys() and disable_service_accounts() functions.
# Waits for asynchronous calls to complete before continuing.
# Call Function to  Disable API Keys & service accounts

disable_api_keys
wait
disable_service_accounts
wait

#get owners for project and add viewer role and remove owner role

if [[ -z ${owner} ]]; then
	echo "No members found for role roles/owner" >>"${log}"
else
	for member in ${owner}; do
		gcloud projects add-iam-policy-binding "${prj}" --member "${member}" --role roles/viewer
		echo "${timestamp} ${member} roles/viewer has been added" >>"${log}"
		wait
		gcloud projects remove-iam-policy-binding "${prj}" --member "${member}" --role roles/owner --condition=None
		echo "${timestamp} ${member} - roles/owner has been removed" >>"${log}"
	done
fi

# Gets editors for the project and adds viewer role, then removes editor role.

if [[ -z ${editor} ]]; then
	echo "No members found for role roles/editor" >>"${log}"
else
	for member in ${editor}; do
		gcloud projects add-iam-policy-binding "${prj}" --member "${member}" --role roles/viewer
		echo "${timestamp} ${member} roles/viewer has been added" >>"${log}"
		wait
		gcloud projects remove-iam-policy-binding "${prj}" --member "${member}" --role roles/editor --condition=None
		echo "${timestamp} ${member} - roles/editor has been removed" >>"${log}"
	done
fi

# Gets custom role for project and adds viewer role, then removes custom role.


if [[ -z ${custom} ]]; then
	echo "No members found for role organizations/387112372795/roles/svcandauthmgr" >>log.txt
else
	for member in ${custom}; do
		gcloud projects add-iam-policy-binding "${prj}" --member "${member}" --role roles/viewer
		echo "${timestamp} ${member} roles/viewer has been added" >>"${log}"
		wait
		gcloud projects remove-iam-policy-binding "${prj}" --member "${member}" --role organizations/387112372795/roles/svcandauthmgr --condition=None
		echo "${timestamp} ${member} - organizations/387112372795/roles/svcandauthmgr has been removed" >>"${log}"
	done
fi

# Get project number from gcloud
# Get recommendation ID for project from Recommender API
# Check if recommendation ID is empty
# If empty, log and skip
# If not empty, log found ID

# get prj number
prjnum=$(gcloud projects describe "${prj}" | grep projectNumber | awk '{print $2}')

# get org level recommendation id
rec_id=$(gcloud recommender recommendations list --organization="${orgid}" --location=global --recommender=google.resourcemanager.projectUtilization.Recommender --format=yaml --filter="content.operationGroups.operations.resource:${prjnum}" | awk -F/ '/name:/{print $NF}')

# get org level etag
etag=$(gcloud recommender recommendations describe "${rec_id}" --organization="${orgid}" --location=global --recommender=google.resourcemanager.projectUtilization.Recommender --format="value(etag)")


# Check if output is empty
if [[ -z "${rec_id}" ]]; then
  echo "No recommendation found for project ${prjnum}" >>"${log}"
  #skip to line 202
  continue
else
 echo "Found recommendation ID: ${rec_id}" >>"${log}"
fi

# Dismiss project utilization recommendation if it exists.
# First check if a recommendation ID was found for the project.
# If so, mark the recommendation dismissed through the Recommender API.
# Then verify if the recommendation is already dismissed before dismissing again.
# Log appropriately based on dismissed state.

# Only dismiss if rec_id is set
if [[ -n "${rec_id}" ]]; then
  gcloud recommender recommendations mark-dismissed --location=global --recommender=google.resourcemanager.projectUtilization.Recommender --organization="${orgid}" --recommendation="${rec_id}"
fi

# Check if recommendation is already dismissed
dismissed=$(gcloud recommender recommendations describe $rec_id --location=global --recommender=google.resourcemanager.projectUtilization.Recommender --organization=$orgid --format="value(stateInfo.state)" 2>/dev/null)

if [[ ${dismissed} == "DISMISSED" ]]; then
	echo "Recommendation ${rec_id} already dismissed, skipping mark-dismissed" "${log}"
else
	#remove from dashboard
	gcloud recommender recommendations mark-dismissed "${rec_id}" --etag="${etag}" --location=global --recommender=google.resourcemanager.projectUtilization.Recommender --organization="${orgid}" >>"${log}"
fi


# Logs a message with the current timestamp to the log file

echo "${timestamp} Project ${prj} moved to folder ${dest}, labeled with ${label_key}=${label_value}, and billing has been removed." >>"${log}"
echo "${timestamp}  Project  ${prj} decommissioned, owner/editor/custom roles have been disabled, service accounts, api keys and oauth clients have been disabled, and recommendations marked as completed." >>"${log}"
echo "${timestamp}  Project  ${prj} has been unmarked from Recommendeder Dashboard" >>"${log}"


# edit csv file_name on line 242
done < PROJECT_LIST.csv


# Check if any errors occurred during CSV processing and exit if so
# Upload log files to GCS buckets
# Check if log files exist before attempting to upload
# Set exit code variable and exit script with exit code

# Check exit code of last command
if [[ $? -ne 0 ]]; then
  echo "Error occurred during CSV processing" >>"${err_log}"
  exit 1
fi

# Set exit code variable
EXIT_CODE=0


# Check if log file exists before uploading
if [[ -f "${log}" ]]; then
  echo "Uploading ${log} to GCS Bucket"
  gsutil cp "${log}" gs://decommissioning-projects-backup/logs/
else
  echo "No log file found at ${log}"
fi


# Check if error log exists before uploading
if [[ -f "${err_log}" ]]; then
  echo "Uploading ${err_log} to GCS Bucket"
  gsutil cp "${err_log}" gs://decommissioning-projects-backup/errors/
else
  echo "No error log file found at ${err_log}"
fi

# Exit script with EXIT_CODE
exit "${EXIT_CODE}"