#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { StackA } from '../lib/stack-a';
import { StackB } from '../lib/stack-b';

const app = new cdk.App();

// Create Stack A with S3 bucket
new StackA(app, 'StackA', {
  /* Uncomment the next line to specialize this stack for the AWS Account
   * and Region that are implied by the current CLI configuration. */
  // env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
});

// Create Stack B (initially without bucket)
new StackB(app, 'StackB', {
  /* Uncomment the next line to specialize this stack for the AWS Account
   * and Region that are implied by the current CLI configuration. */
  // env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
});