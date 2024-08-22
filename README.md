# GCP Batch Decommissioning Script

This repository contains a Bash script for decommissioning Google Cloud Platform (GCP) projects in batch. The script performs various tasks such as moving projects to a destination folder, disabling API keys, disabling service accounts, saving IAM policies, and dismissing recommendations.

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

2. **Clone the repository:**
