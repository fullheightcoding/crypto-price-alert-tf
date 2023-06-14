Steps:
- Create lambda function, create lambda function exec IAM role
- Create SNS topic, create SNS subscription with email address
- Environment variables and event parameters are stored outside of this folder
- Add github actions workflow secrets used in deploy yaml file for secrets.AWS_ACCESS_KEY_ID, secrets.AWS_SECRET_ACCESS_KEY, secrets.AWS_REGION, secrets.SNS_TOPIC_ARN
- How to make sure it doesn't send multiple emails when price goes to x? Only run once every 24 hours, but what happens at next 24 hour point?
- Create terraform version of lambda function, lambda function exec role, event bridge event scheduler, sns topic and subscriber, lambda sns exec role
- Update cron jobs so they use ohio (us east) time to run