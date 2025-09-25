import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { StackB } from '../lib/stack-b';

test('Stack B is initially empty', () => {
  const app = new cdk.App();
  // WHEN
  const stack = new StackB(app, 'MyTestStack');
  // THEN
  const template = Template.fromStack(stack);

  // Should not have any S3 buckets initially
  template.resourceCountIs('AWS::S3::Bucket', 0);
});