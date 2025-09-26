# Musical Buckets CDK Project

This project demonstrates how to migrate S3 buckets between CDK stacks without data loss or downtime. It includes two stacks (StackA and StackB) and tooling to safely transfer bucket ownership.

## Project Structure

```
├── lib/
│   ├── stack-a.ts          # Source stack with S3 bucket
│   └── stack-b.ts          # Target stack for bucket migration
├── scripts/
│   ├── load-files.js       # Script to populate bucket with sample data
│   └── migrate-bucket.sh   # Automated migration script
├── .github/workflows/
│   └── migrate-bucket.yml  # GitHub Actions pipeline for production
└── test/                   # Unit tests for both stacks
```

## S3 Bucket Migration Guide

This guide shows how to migrate an S3 bucket from Stack A to Stack B while preserving all data and ensuring zero downtime.

### Prerequisites

- AWS CLI configured with appropriate permissions
- AWS CDK CLI installed (`npm install -g aws-cdk`)
- Node.js and npm installed

### Manual Migration Steps

#### Step 1: Initial Deployment

Deploy both stacks initially with the bucket in Stack A:

```bash
# Install dependencies
npm install

# Deploy Stack A (contains the S3 bucket)
cdk deploy StackA

# Deploy Stack B (initially empty)
cdk deploy StackB
```

#### Step 2: Load Sample Data (Optional)

Populate the bucket with sample files for testing:

```bash
# Auto-generate bucket name using current AWS account (recommended)
node scripts/load-files.js

# Or specify bucket name explicitly
node scripts/load-files.js stack-a-bucket-<account>-<region>
```

#### Step 3: Remove Bucket from Stack A

Deploy Stack A with the migration flag to remove bucket from its management:

```bash
# Remove bucket from Stack A management
cdk deploy StackA --context migrateBucket=true
```

⚠️ **Important**: The bucket remains in AWS due to `RemovalPolicy.RETAIN` - only CloudFormation management is removed.

#### Step 4: Prepare Stack B for Import

Deploy Stack B with the import flag to add bucket resource definition:

```bash
# Prepare Stack B for import (adds bucket resource to template)
cdk deploy StackB --context importBucket=true
```

#### Step 5: Import Bucket into Stack B

Use CDK's import feature to transfer ownership:

**Option A: Interactive Import (Recommended)**
```bash
# Import the existing bucket into Stack B (interactive)
cdk import StackB --context importBucket=true

# When prompted, enter the bucket name:
# StackB/ImportedStackABucket/Resource (AWS::S3::Bucket): enter BucketName
# Type: stack-a-bucket-<your-account>-<your-region>
```

**Option B: Automated Import with Pipeline**
```bash
# For automation, use echo to pipe the bucket name
echo "stack-a-bucket-<account>-<region>" | cdk import StackB --context importBucket=true
```

#### Step 6: Verify Migration

Check that the migration completed successfully:

```bash
# Verify bucket is now managed by Stack B
aws cloudformation describe-stack-resources --stack-name StackB \
  --query 'StackResources[?ResourceType==`AWS::S3::Bucket`]'

# Verify bucket is no longer managed by Stack A
aws cloudformation describe-stack-resources --stack-name StackA \
  --query 'StackResources[?ResourceType==`AWS::S3::Bucket`]'

# Test bucket access and data integrity
aws s3 ls s3://stack-a-bucket-$(aws sts get-caller-identity --query Account --output text)-$(aws configure get region || echo us-east-1) --recursive
```

#### Step 7: Cleanup (Optional)

When you're done with the demo, use the cleanup script to remove all resources:

```bash
# Remove all resources (bucket contents, stacks, and bucket itself)
./scripts/cleanup.sh

# The script will:
# 1. Empty the S3 bucket (with confirmation)
# 2. Delete both CDK stacks
# 3. Remove the bucket completely
# 4. Clean up generated files
```

### Automated Migration

For production environments, use the automated migration script:

```bash
# Make script executable
chmod +x scripts/migrate-bucket.sh

# Get your bucket name
BUCKET_NAME="stack-a-bucket-$(aws sts get-caller-identity --query Account --output text)-$(aws configure get region || echo us-east-1)"

# Run migration steps in sequence
./scripts/migrate-bucket.sh validate $BUCKET_NAME
./scripts/migrate-bucket.sh remove-source $BUCKET_NAME
./scripts/migrate-bucket.sh prepare-target $BUCKET_NAME
./scripts/migrate-bucket.sh import $BUCKET_NAME
./scripts/migrate-bucket.sh verify $BUCKET_NAME
```

### Quick Start Commands

For a complete demo run from start to finish:

```bash
# 1. Deploy initial stacks
cdk deploy StackA
cdk deploy StackB

# 2. Load sample data
node scripts/load-files.js

# 3. Migrate bucket from Stack A to Stack B
cdk deploy StackA --context migrateBucket=true
cdk deploy StackB --context importBucket=true
echo "stack-a-bucket-$(aws sts get-caller-identity --query Account --output text)-$(aws configure get region || echo us-east-1)" | cdk import StackB --context importBucket=true

# 4. Verify migration
aws cloudformation describe-stack-resources --stack-name StackB --query 'StackResources[?ResourceType==`AWS::S3::Bucket`]'

# 5. Clean up when done
./scripts/cleanup.sh
```

### GitHub Actions Pipeline

For production deployments, use the included GitHub Actions workflow:

1. Set up repository secrets:
   - `AWS_ROLE_ARN`: IAM role with CDK and S3 permissions

2. Run the workflow with manual dispatch:
   - Go to Actions → "S3 Bucket Migration Pipeline"
   - Select migration step (validate, remove-source, prepare-target, import, verify)
   - Enter bucket name and stack names
   - Execute step

### Key Safety Features

- ✅ **Zero Data Loss**: `RemovalPolicy.RETAIN` ensures bucket persists
- ✅ **Zero Downtime**: Bucket remains accessible throughout migration
- ✅ **Validation**: Multiple verification steps ensure successful migration
- ✅ **Rollback**: Process can be reversed if needed
- ✅ **Step-by-Step**: Each step can be executed and verified independently

### Context Parameters

The project uses CDK context parameters to control stack behavior:

- **`migrateBucket=true`** - Tells Stack A to NOT create the bucket (for migration)
- **`importBucket=true`** - Tells Stack B to create the bucket resource (for import)

### Scripts Overview

| Script | Purpose |
|--------|---------|
| `scripts/load-files.js` | Loads 5 sample files into the S3 bucket |
| `scripts/migrate-bucket.sh` | Automated migration script with step-by-step process |
| `scripts/cleanup.sh` | Complete cleanup of all resources and data |

### Troubleshooting

**Error: "Bucket already exists"**
- This means you're trying to create a new bucket instead of importing. Ensure you're using the context parameters correctly.

**Error: "Access Denied"**
- Ensure your AWS credentials have permissions for S3, CloudFormation, and CDK operations.

**Import fails with "Unrecognized resource identifiers"**
- Use interactive import instead of resource mapping file: `cdk import StackB --context importBucket=true`
- Ensure the bucket name matches exactly what CDK expects.

**Error: "Stack A has no bucket to migrate"**
- Make sure you deployed Stack A initially without the `migrateBucket=true` context.

**Cleanup script fails**
- The script includes fallbacks and force options. Check AWS console if issues persist.

## Standard CDK Commands

* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `cdk deploy`      deploy this stack to your default AWS account/region
* `cdk diff`        compare deployed stack with current state
* `cdk synth`       emits the synthesized CloudFormation template
* `cdk import`      import existing resources into a stack
