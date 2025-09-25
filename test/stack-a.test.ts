import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { StackA } from '../lib/stack-a';

test('Stack A has S3 Bucket', () => {
  const app = new cdk.App();
  // WHEN
  const stack = new StackA(app, 'MyTestStack');
  // THEN
  const template = Template.fromStack(stack);

  template.hasResourceProperties('AWS::S3::Bucket', {
    VersioningConfiguration: {
      Status: 'Enabled'
    }
  });
});