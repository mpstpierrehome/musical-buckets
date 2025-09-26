#!/bin/bash

# S3 Bucket Migration Script for CI/CD
# This script handles the step-by-step migration of an S3 bucket between CDK stacks

set -e  # Exit on any error

STEP=${1:-"help"}
BUCKET_NAME=${2}
SOURCE_STACK=${3:-"StackA"}
TARGET_STACK=${4:-"StackB"}

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

show_help() {
    echo "S3 Bucket Migration Script"
    echo ""
    echo "Usage: $0 <step> <bucket_name> [source_stack] [target_stack]"
    echo ""
    echo "Steps:"
    echo "  validate         - Validate bucket exists and check current ownership"
    echo "  remove-source    - Remove bucket from source stack management"
    echo "  prepare-target   - Prepare target stack for import"
    echo "  import          - Import bucket into target stack"
    echo "  verify          - Verify migration completed successfully"
    echo "  rollback        - Rollback migration (emergency use)"
    echo ""
    echo "Example:"
    echo "  $0 validate stack-a-bucket-123456789012-us-east-1"
    echo "  $0 remove-source stack-a-bucket-123456789012-us-east-1 StackA StackB"
    echo ""
}

validate_prereqs() {
    if [ -z "$BUCKET_NAME" ]; then
        log_error "Bucket name is required"
        show_help
        exit 1
    fi
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check if CDK is available
    if ! command -v cdk &> /dev/null; then
        log_error "AWS CDK is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
}

validate_bucket() {
    log_info "Validating bucket: $BUCKET_NAME"
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        log_success "Bucket exists and is accessible"
    else
        log_error "Bucket does not exist or is not accessible"
        exit 1
    fi
    
    # Check current ownership
    log_info "Checking current stack ownership..."
    
    if aws cloudformation describe-stack-resources --stack-name "$SOURCE_STACK" --query "StackResources[?ResourceType=='AWS::S3::Bucket' && PhysicalResourceId=='$BUCKET_NAME']" --output text | grep -q "$BUCKET_NAME"; then
        log_info "Bucket is currently managed by $SOURCE_STACK"
    else
        log_warning "Bucket is not currently managed by $SOURCE_STACK"
    fi
    
    # List bucket contents (first 10 objects)
    log_info "Bucket contents preview:"
    aws s3 ls "s3://$BUCKET_NAME" --recursive | head -10 || log_warning "Could not list bucket contents"
}

remove_from_source() {
    log_info "Removing bucket from $SOURCE_STACK management..."
    
    # First, check if bucket is actually managed by source stack
    if ! aws cloudformation describe-stack-resources --stack-name "$SOURCE_STACK" --query "StackResources[?ResourceType=='AWS::S3::Bucket' && PhysicalResourceId=='$BUCKET_NAME']" --output text | grep -q "$BUCKET_NAME"; then
        log_warning "Bucket is not managed by $SOURCE_STACK, skipping removal"
        return 0
    fi
    
    # Deploy source stack without bucket
    log_info "Deploying $SOURCE_STACK without bucket..."
    cdk deploy "$SOURCE_STACK" --require-approval never
    
    # Verify bucket was removed from stack management
    if aws cloudformation describe-stack-resources --stack-name "$SOURCE_STACK" --query "StackResources[?ResourceType=='AWS::S3::Bucket' && PhysicalResourceId=='$BUCKET_NAME']" --output text | grep -q "$BUCKET_NAME"; then
        log_error "Failed to remove bucket from $SOURCE_STACK"
        exit 1
    else
        log_success "Bucket successfully removed from $SOURCE_STACK management"
    fi
}

prepare_target() {
    log_info "Preparing $TARGET_STACK for import..."
    
    # Synthesize target stack to verify configuration
    log_info "Synthesizing $TARGET_STACK..."
    cdk synth "$TARGET_STACK" > /dev/null
    
    log_success "$TARGET_STACK ready for import"
}

import_bucket() {
    log_info "Importing bucket into $TARGET_STACK..."
    
    # Use CDK import with resource mapping (non-interactive)
    log_info "Starting CDK import process with resource mapping..."
    cdk import "$TARGET_STACK" --resource-mapping resource-mapping.json --context importBucket=true || {
        log_error "CDK import failed"
        exit 1
    }
    
    # Verify import was successful
    if aws cloudformation describe-stack-resources --stack-name "$TARGET_STACK" --query "StackResources[?ResourceType=='AWS::S3::Bucket' && PhysicalResourceId=='$BUCKET_NAME']" --output text | grep -q "$BUCKET_NAME"; then
        log_success "Bucket successfully imported into $TARGET_STACK"
    else
        log_error "Import verification failed"
        exit 1
    fi
}

verify_migration() {
    log_info "Verifying migration..."
    
    # Check target stack has the bucket
    if aws cloudformation describe-stack-resources --stack-name "$TARGET_STACK" --query "StackResources[?ResourceType=='AWS::S3::Bucket' && PhysicalResourceId=='$BUCKET_NAME']" --output text | grep -q "$BUCKET_NAME"; then
        log_success "Bucket is managed by $TARGET_STACK"
    else
        log_error "Bucket is not managed by $TARGET_STACK"
        exit 1
    fi
    
    # Check source stack doesn't have the bucket
    if aws cloudformation describe-stack-resources --stack-name "$SOURCE_STACK" --query "StackResources[?ResourceType=='AWS::S3::Bucket' && PhysicalResourceId=='$BUCKET_NAME']" --output text | grep -q "$BUCKET_NAME"; then
        log_error "Bucket is still managed by $SOURCE_STACK"
        exit 1
    else
        log_success "Bucket is no longer managed by $SOURCE_STACK"
    fi
    
    # Test bucket access
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        log_success "Bucket is still accessible"
    else
        log_error "Bucket is not accessible"
        exit 1
    fi
    
    # Check bucket contents are intact
    log_info "Verifying bucket contents..."
    OBJECT_COUNT=$(aws s3 ls "s3://$BUCKET_NAME" --recursive | wc -l)
    log_info "Bucket contains $OBJECT_COUNT objects"
    
    log_success "Migration verification completed successfully!"
}

# Main execution
case "$STEP" in
    "validate")
        validate_prereqs
        validate_bucket
        ;;
    "remove-source")
        validate_prereqs
        remove_from_source
        ;;
    "prepare-target")
        validate_prereqs
        prepare_target
        ;;
    "import")
        validate_prereqs
        import_bucket
        ;;
    "verify")
        validate_prereqs
        verify_migration
        ;;
    "help"|*)
        show_help
        ;;
esac