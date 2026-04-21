# ============================================
# Terraform Backend Configuration
# ============================================

# This file configures the Terraform backend for state management.
# By default, it uses local backend. For production, uncomment the S3 backend configuration.

# ============================================
# Local Backend (Default)
# ============================================

# State is stored locally in terraform.tfstate file
# This is suitable for development and testing
# For production, use S3 backend below

# ============================================
# S3 Backend (Recommended for Production)
# ============================================

# Uncomment the block below to use S3 backend with DynamoDB state locking
# Before using, create the S3 bucket and DynamoDB table:
#
# aws s3 mb s3://YOUR-BUCKET-NAME --region YOUR-REGION
# aws s3api put-bucket-versioning \
#   --bucket YOUR-BUCKET-NAME \
#   --versioning-configuration Status=Enabled
# aws s3api put-bucket-encryption \
#   --bucket YOUR-BUCKET-NAME \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
#   --region YOUR-REGION

# terraform {
#   backend "s3" {
#     # S3 bucket name - MUST be globally unique
#     bucket = "my-terraform-state-bucket"
#     
#     # Path within the bucket where state file will be stored
#     key = "infrastructure/terraform.tfstate"
#     
#     # AWS region where the bucket is located
#     region = "us-east-1"
#     
#     # Enable encryption at rest
#     encrypt = true
#     
#     # DynamoDB table for state locking
#     dynamodb_table = "terraform-state-lock"
#     
#     # Enable versioning for state file history
#     # versioning = true  # This is set on the bucket itself
#     
#     # Workspace key prefix (for multiple environments)
#     # workspace_key_prefix = "workspaces"
#   }
# }

# ============================================
# Alternative: Terraform Cloud Backend
# ============================================

# Uncomment to use Terraform Cloud for state management
# Requires Terraform Cloud account and organization

# terraform {
#   cloud {
#     organization = "my-organization"
#     
#     workspaces {
#       name = "aws-infrastructure"
#     }
#   }
# }

# ============================================
# Backend Configuration Notes
# ============================================

# 1. Local Backend:
#    - State stored in local terraform.tfstate file
#    - No state locking (risk of concurrent modifications)
#    - Not suitable for team collaboration
#    - Good for development and testing
#
# 2. S3 Backend:
#    - State stored in S3 bucket
#    - State locking via DynamoDB
#    - Supports team collaboration
#    - Versioning for state history
#    - Encryption at rest
#    - Recommended for production
#
# 3. Terraform Cloud:
#    - Managed state storage
#    - Built-in state locking
#    - Remote execution
#    - Team collaboration features
#    - Free tier available
#
# To migrate from local to S3 backend:
# 1. Uncomment the S3 backend configuration above
# 2. Update the bucket name and region
# 3. Run: terraform init -migrate-state
# 4. Confirm the migration when prompted
#
# To migrate back to local:
# 1. Comment out the S3 backend configuration
# 2. Run: terraform init -migrate-state
# 3. Confirm the migration when prompted

# ============================================
# State File Security Best Practices
# ============================================

# 1. Never commit terraform.tfstate to version control
#    - Add to .gitignore: *.tfstate*
#
# 2. Enable encryption for S3 backend
#    - Use encrypt = true in backend config
#    - Enable bucket encryption
#
# 3. Enable versioning on S3 bucket
#    - Allows recovery from accidental deletions
#    - Maintains state history
#
# 4. Use state locking
#    - Prevents concurrent modifications
#    - DynamoDB table for S3 backend
#
# 5. Restrict access to state files
#    - Use IAM policies
#    - Limit who can read/write state
#
# 6. Regular backups
#    - S3 versioning provides automatic backups
#    - Consider cross-region replication
#
# 7. Audit access
#    - Enable CloudTrail for S3 bucket
#    - Monitor state file access