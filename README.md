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
# Get the bucket name from Stack A deployment output
BUCKET_NAME="stack-a-bucket-<account>-<region>"

# Load 5 sample files into the bucket
node scripts/load-files.js $BUCKET_NAME
```

#### Step 3: Remove Bucket from Stack A

1. **Comment out or remove** the bucket definition in `lib/stack-a.ts`:
   ```typescript
   // Comment out the entire bucket creation block
   // this.bucket = new s3.Bucket(this, 'StackABucket', {
   //   ...
   // });
   ```

2. **Deploy Stack A** to remove bucket from its management:
   ```bash
   cdk deploy StackA
   ```

   ⚠️ **Important**: The bucket remains in AWS due to `RemovalPolicy.RETAIN` - only CloudFormation management is removed.

#### Step 4: Prepare Stack B for Import

1. **Update `lib/stack-b.ts`** to define the bucket resource:
   ```typescript
   this.bucket = new s3.Bucket(this, 'ImportedStackABucket', {
     bucketName: 'stack-a-bucket-<account>-<region>', // Use actual bucket name
     versioned: true,
     removalPolicy: cdk.RemovalPolicy.RETAIN,
     autoDeleteObjects: false,
   });
   ```

2. **Synthesize Stack B** to verify configuration:
   ```bash
   cdk synth StackB
   ```

#### Step 5: Import Bucket into Stack B

Use CDK's import feature to transfer ownership:

```bash
# Import the existing bucket into Stack B
cdk import StackB

# When prompted, confirm the import:
# StackB/ImportedStackABucket/Resource (AWS::S3::Bucket): import with BucketName=stack-a-bucket-xxx-xxx-x
# Type 'y' to confirm
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
aws s3 ls s3://$BUCKET_NAME --recursive
```

### Automated Migration

For production environments, use the automated migration script:

```bash
# Make script executable
chmod +x scripts/migrate-bucket.sh

# Run migration steps in sequence
./scripts/migrate-bucket.sh validate $BUCKET_NAME
./scripts/migrate-bucket.sh remove-source $BUCKET_NAME
./scripts/migrate-bucket.sh prepare-target $BUCKET_NAME
./scripts/migrate-bucket.sh import $BUCKET_NAME
./scripts/migrate-bucket.sh verify $BUCKET_NAME
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

### Troubleshooting

**Error: "Bucket already exists"**
- This means you're trying to create a new bucket instead of importing. Use `Bucket.fromBucketName()` for referencing or follow the import process.

**Error: "Access Denied"**
- Ensure your AWS credentials have permissions for S3, CloudFormation, and CDK operations.

**Import fails**
- Verify the bucket name exactly matches between Stack A and Stack B definitions.
- Ensure Stack A has been deployed without the bucket definition.

## Standard CDK Commands

* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `cdk deploy`      deploy this stack to your default AWS account/region
* `cdk diff`        compare deployed stack with current state
* `cdk synth`       emits the synthesized CloudFormation template
* `cdk import`      import existing resources into a stack
