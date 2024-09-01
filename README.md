
# GCP Batch Decommissioning Script

This repository contains a Bash script for decommissioning Google Cloud Platform (GCP) projects in batches. The script performs tasks such as moving projects to a destination folder, disabling API keys, disabling service accounts, saving IAM policies, and dismissing recommendations. It also includes tests to ensure the script's functionality.
I created this script to automate the decommissioning of abandoned projects, ensuring they are properly archived and removed from the GCP environment. The bash script is designed to be run on a Linux or Unix-based system and requires the Google Cloud SDK and Bats (Bash Automated Testing System) for testing. I wanted to release this script to the public domain to help others automate the decommissioning process and ensure the security and integrity of their GCP environment. I recommend refactoring this script into Python to make it more efficient and easier to use.

## Prerequisites

- Bash shell
- Google Cloud SDK (`gcloud` and `gsutil` commands)
- Bats (Bash Automated Testing System) for running tests

## Setup

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yourusername/gcp-batchdecomm.git
   cd gcp-batchdecomm
   ```

2. **Install Bats:**

   ```bash
   git clone https://github.com/bats-core/bats-core.git
   cd bats-core
   ./install.sh /usr/local
   ```

3. **Configure Google Cloud SDK:**

   ```bash
   gcloud auth login
   ```

## Usage

1. **Prepare the project list:**

   Create a CSV file named `PROJECT_LIST.csv` containing the list of project IDs to be decommissioned.

2. **Run the script:**

   ```bash
   ./gcp-batchdecomm.sh
   ```

   The script will read the project IDs from `PROJECT_LIST.csv` and perform the decommissioning steps for each project.

## Script Details

### Variables

- `dest`: Destination folder ID for moving the project.
- `timestamp`: Generates a timestamp string to use in log/error log filenames.
- `log`: Log file name constructed from the timestamp.
- `err_log`: Error log filename constructed from the timestamp.
- `expire_date`: Decommission expiration date string in `YYYY-MM-DD` format.
- `orgid`: Organization ID.
- `label_key`: Label key for the `decomm_expiration` label.
- `label_value`: Label value set to `expire_date` for the `decomm_expiration` label.
- `label_key2`: Label key for the `decomm-ticket` label.
- `label_value2`: Label value for the `decomm-ticket` label.

### Functions

- `move_project`: Moves the project to the destination folder.
- `get_iam_members`: Retrieves owner, editor, and custom role members.
- `disable_api_keys`: Disables all API keys.
- `disable_service_accounts`: Disables all service accounts.
- `save_project_iam`: Saves and uploads the IAM policy.
- `dismiss_recommendation`: Dismisses existing recommendations.
- `process_project`: Performs all decommissioning steps.

## Testing

The repository includes a test suite written using the Bats framework. To run the tests:

1. **Navigate to the tests directory:**

   ```bash
   cd tests
   ```

2. **Run the tests:**

   ```bash
   bats test_gcp_batchdecomm.sh
   ```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
```
