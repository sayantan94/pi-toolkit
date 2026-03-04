# Setting Up Mom with Amazon Bedrock

End-to-end guide: AWS IAM, credentials, Docker sandbox, and running mom with Bedrock.

## Prerequisites

- Node.js >= 20
- Docker installed and running
- AWS account with Bedrock access enabled in your target region
- Slack app configured ([see Slack setup guide](slack-bot-minimal-guide.md))

## 1. Enable Bedrock Model Access

Bedrock models require explicit activation per-region.

1. Go to **AWS Console → Amazon Bedrock → Model access** (in your target region, e.g. `us-east-1`)
2. Click **Manage model access**
3. Enable the Anthropic Claude models you want (e.g. Claude Sonnet 4)
4. Wait for status to show **Access granted** (usually instant, can take a few minutes)

## 2. Create an IAM User for Mom

Create a dedicated IAM user with only Bedrock invoke permissions.

```bash
# Create the user (no console access)
aws iam create-user --user-name mom-bedrock

# Create the policy
cat > /tmp/mom-bedrock-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:*::foundation-model/anthropic.*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:*::foundation-model/us.anthropic.*"
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name mom-bedrock \
  --policy-name BedrockInvokeOnly \
  --policy-document file:///tmp/mom-bedrock-policy.json

# Create access keys
aws iam create-access-key --user-name mom-bedrock
# Save the AccessKeyId and SecretAccessKey from the output
```

## 3. Store AWS Credentials

Option A — AWS credentials file (recommended):

```bash
mkdir -p ~/.aws

# Add a named profile
cat >> ~/.aws/credentials << 'EOF'
[mom]
aws_access_key_id = AKIA...your-key...
aws_secret_access_key = ...your-secret...
EOF

cat >> ~/.aws/config << 'EOF'
[profile mom]
region = us-east-1
EOF
```

Option B — Environment variables (simpler, less secure):

```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
```

## 4. Install Mom

```bash
npm install -g @mariozechner/pi-mom
```

## 5. Create the Docker Sandbox

```bash
# Create a data directory for mom's workspace
mkdir -p ~/mom-data

# Create and start the container
docker run -d \
  --name mom-sandbox \
  -v ~/mom-data:/workspace \
  alpine:latest \
  tail -f /dev/null
```

## 6. Run Mom

Using the AWS profile from step 3:

```bash
export MOM_SLACK_APP_TOKEN=xapp-...
export MOM_SLACK_BOT_TOKEN=xoxb-...
export AWS_PROFILE=mom

mom --provider=amazon-bedrock \
    --model=us.anthropic.claude-sonnet-4-6 \
    --sandbox=docker:mom-sandbox \
    ~/mom-data
```

Or with env vars instead of CLI args:

```bash
export MOM_SLACK_APP_TOKEN=xapp-...
export MOM_SLACK_BOT_TOKEN=xoxb-...
export AWS_PROFILE=mom
export MOM_PROVIDER=amazon-bedrock
export MOM_MODEL=us.anthropic.claude-sonnet-4-6

mom --sandbox=docker:mom-sandbox ~/mom-data
```

## 7. Verify It Works

1. Open Slack and @mention mom in a channel she's been added to
2. Send a simple message like `@mom hello`
3. She should respond within a few seconds
4. Check terminal output for any credential errors

## Launch Script (Optional)

Save this as `~/bin/run-mom.sh` to avoid repeating config:

```bash
#!/bin/bash
export MOM_SLACK_APP_TOKEN=xapp-...
export MOM_SLACK_BOT_TOKEN=xoxb-...
export AWS_PROFILE=mom
export MOM_PROVIDER=amazon-bedrock
export MOM_MODEL=us.anthropic.claude-sonnet-4-6

exec mom --sandbox=docker:mom-sandbox ~/mom-data
```

```bash
chmod +x ~/bin/run-mom.sh
```

## Available Bedrock Models

Common model IDs for `--model`:

| Model | ID |
|-------|-----|
| Claude Sonnet 4 | `us.anthropic.claude-sonnet-4-20250514` |
| Claude Sonnet 4.5 | `us.anthropic.claude-sonnet-4-5-20241022` |
| Claude Haiku 3.5 | `us.anthropic.claude-3-5-haiku-20241022` |

Cross-region model IDs (prefixed with `us.`) route to the nearest available region and are generally preferred.

## Troubleshooting

**"No API key found for amazon-bedrock"**
- AWS credentials not detected. Check `AWS_PROFILE` is set and `~/.aws/credentials` has the profile, or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` are exported.

**"Unknown model ... for provider amazon-bedrock"**
- The model ID doesn't match any known model. Check the model ID spelling. Run with a known ID from the table above.

**"AccessDeniedException" from AWS**
- The IAM user doesn't have Bedrock permissions, or the model isn't enabled in the region. Check IAM policy and Bedrock model access in the console.

**"Could not resolve credentials"**
- The AWS SDK can't find credentials. Verify `aws sts get-caller-identity --profile mom` works.
