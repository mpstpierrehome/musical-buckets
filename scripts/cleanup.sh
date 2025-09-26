#!/bin/bash

# Cleanup script for Musical Buckets CDK project
# This script will:
# 1. Empty the S3 bucket
# 2. Delete both CDK stacks
# 3. Remove the bucket completely

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

confirm_action() {
    local message="$1"
    echo -e "${YELLOW}⚠️  $message${NC}"
    read -p "Are you sure you want to continue? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
}

get_bucket_name() {
    # Try to get bucket name from current AWS account
    local account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    local region=$(aws configure get region 2>/dev/null || echo "us-east-1")
    
    if [ -n "$account" ]; then
        echo "stack-a-bucket-${account}-${region}"
    else
        log_error "Could not determine AWS account. Please ensure AWS credentials are configured."
        exit 1
    fi
}

empty_bucket() {
    local bucket_name="$1"
    
    log_info "Checking if bucket exists: $bucket_name"
    
    if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        log_info "Bucket exists. Checking contents..."
        
        # Count objects in bucket
        local object_count=$(aws s3 ls "s3://$bucket_name" --recursive | wc -l | tr -d ' ')
        
        if [ "$object_count" -gt 0 ]; then
            log_warning "Bucket contains $object_count objects"
            confirm_action "This will permanently delete all objects in the bucket!"
            
            log_info "Emptying bucket: $bucket_name"
            
            # Delete all objects (including versioned objects)
            aws s3 rm "s3://$bucket_name" --recursive
            
            # Delete all versions if versioning is enabled
            log_info "Removing all object versions..."
            aws s3api list-object-versions --bucket "$bucket_name" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | while read key version_id; do
                if [ -n "$key" ] && [ -n "$version_id" ]; then
                    aws s3api delete-object --bucket "$bucket_name" --key "$key" --version-id "$version_id" >/dev/null
                fi
            done
            
            # Delete all delete markers
            aws s3api list-object-versions --bucket "$bucket_name" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | while read key version_id; do
                if [ -n "$key" ] && [ -n "$version_id" ]; then
                    aws s3api delete-object --bucket "$bucket_name" --key "$key" --version-id "$version_id" >/dev/null
                fi
            done
            
            log_success "Bucket emptied successfully"
        else
            log_info "Bucket is already empty"
        fi
    else
        log_warning "Bucket does not exist or is not accessible"
    fi
}

delete_stacks() {
    log_info "Deleting CDK stacks..."
    
    # Check which stacks exist
    local stack_a_exists=$(aws cloudformation describe-stacks --stack-name StackA 2>/dev/null | jq -r '.Stacks[0].StackName' 2>/dev/null || echo "")
    local stack_b_exists=$(aws cloudformation describe-stacks --stack-name StackB 2>/dev/null | jq -r '.Stacks[0].StackName' 2>/dev/null || echo "")
    
    # Delete Stack B first (if it exists and manages the bucket)
    if [ -n "$stack_b_exists" ]; then
        log_info "Deleting Stack B..."
        cdk destroy StackB --force --context importBucket=true || {
            log_warning "Failed to delete Stack B with CDK. Trying CloudFormation directly..."
            aws cloudformation delete-stack --stack-name StackB
            log_info "Waiting for Stack B deletion to complete..."
            aws cloudformation wait stack-delete-complete --stack-name StackB
        }
        log_success "Stack B deleted"
    else
        log_info "Stack B does not exist"
    fi
    
    # Delete Stack A
    if [ -n "$stack_a_exists" ]; then
        log_info "Deleting Stack A..."
        cdk destroy StackA --force --context migrateBucket=true || {
            log_warning "Failed to delete Stack A with CDK. Trying CloudFormation directly..."
            aws cloudformation delete-stack --stack-name StackA
            log_info "Waiting for Stack A deletion to complete..."
            aws cloudformation wait stack-delete-complete --stack-name StackA
        }
        log_success "Stack A deleted"
    else
        log_info "Stack A does not exist"
    fi
}

force_delete_bucket() {
    local bucket_name="$1"
    
    log_info "Attempting to force delete bucket: $bucket_name"
    
    if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        log_warning "Bucket still exists after stack deletion"
        confirm_action "Force delete the bucket completely?"
        
        # Try to delete the bucket
        aws s3 rb "s3://$bucket_name" --force || {
            log_error "Failed to delete bucket with S3 CLI. Trying API directly..."
            aws s3api delete-bucket --bucket "$bucket_name" || {
                log_error "Could not delete bucket. It may have remaining objects or be managed by another stack."
                return 1
            }
        }
        
        log_success "Bucket deleted successfully"
    else
        log_success "Bucket has been successfully removed"
    fi
}

cleanup_generated_files() {
    log_info "Cleaning up generated files..."
    
    # Remove generated CDK files
    [ -f "stackb-template.json" ] && rm -f stackb-template.json && log_info "Removed stackb-template.json"
    [ -f "cdk.out" ] && rm -rf cdk.out && log_info "Removed cdk.out directory"
    
    log_success "Generated files cleaned up"
}

# Main execution
main() {
    echo "🧹 Musical Buckets Cleanup Script"
    echo "=================================="
    
    log_warning "This script will completely remove all resources created by the Musical Buckets demo"
    log_warning "This includes:"
    log_warning "  - All objects in the S3 bucket"
    log_warning "  - The S3 bucket itself"
    log_warning "  - Both CDK stacks (StackA and StackB)"
    log_warning "  - Generated files and templates"
    
    confirm_action "This action cannot be undone!"
    
    # Get bucket name
    BUCKET_NAME=$(get_bucket_name)
    log_info "Target bucket: $BUCKET_NAME"
    
    # Step 1: Empty the bucket
    empty_bucket "$BUCKET_NAME"
    
    # Step 2: Delete the stacks
    delete_stacks
    
    # Step 3: Force delete bucket if it still exists
    force_delete_bucket "$BUCKET_NAME"
    
    # Step 4: Clean up generated files
    cleanup_generated_files
    
    echo ""
    log_success "🎉 Cleanup completed successfully!"
    log_info "All Musical Buckets resources have been removed."
}

# Check prerequisites
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    exit 1
fi

if ! command -v cdk &> /dev/null; then
    log_error "AWS CDK is not installed"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    exit 1
fi

# Run main function
main "$@"