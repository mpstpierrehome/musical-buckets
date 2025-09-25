import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export class StackA extends cdk.Stack {
  public readonly bucket: s3.Bucket;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create S3 bucket for Stack A
    // this.bucket = new s3.Bucket(this, 'StackABucket', {
    //   bucketName: `stack-a-bucket-${this.account}-${this.region}`,
    //   versioned: true,
    //   removalPolicy: cdk.RemovalPolicy.RETAIN, // Bucket will remain when stack is deleted
    //   autoDeleteObjects: false, // Objects will not be deleted automatically
    // });

    // // Output the bucket name
    // new cdk.CfnOutput(this, 'StackABucketName', {
    //   value: this.bucket.bucketName,
    //   description: 'Name of the S3 bucket in Stack A',
    // });
  }
}