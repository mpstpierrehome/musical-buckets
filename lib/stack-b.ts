import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export class StackB extends cdk.Stack {
  public readonly bucket?: s3.Bucket;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create bucket resource only when ready to import
    const importBucket = this.node.tryGetContext('importBucket') === 'true';
    
    if (importBucket) {
      const bucketName = `stack-a-bucket-${this.account}-${this.region}`;
      
      this.bucket = new s3.Bucket(this, 'ImportedStackABucket', {
        bucketName: bucketName,
        versioned: true,
        removalPolicy: cdk.RemovalPolicy.RETAIN,
        autoDeleteObjects: false,
      });

      // Output the bucket name
      new cdk.CfnOutput(this, 'BucketName', {
        value: this.bucket.bucketName,
        description: 'Name of the S3 bucket now managed by Stack B',
      });

      new cdk.CfnOutput(this, 'StackBStatus', {
        value: 'Stack B now fully manages the bucket',
        description: 'Status of Stack B',
      });
    } else {
      // Stack B without bucket - ready for initial deployment
      new cdk.CfnOutput(this, 'StackBStatus', {
        value: 'Stack B ready - no bucket imported yet',
        description: 'Status of Stack B',
      });
    }
  }
}