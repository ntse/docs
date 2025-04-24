---
title: AWS Vault
parent: Guides
---

# AWS Vault
From the [aws-vault Github repo](https://github.com/99designs/aws-vault):

> AWS Vault is a tool to securely store and access AWS credentials in a development environment.
> 
> AWS Vault stores IAM credentials in your operating system's secure keystore and then generates temporary credentials from those to expose to your shell and applications. It's designed to be complementary to the AWS CLI tools, and is aware of your profiles and configuration in ~/.aws/config.

## Installing and configuring AWS Vault (for OHID)
Install aws-vault on a Mac using brew:

```bash
brew install --cask aws-vault
```

Ask somebody else for the config. It will look like the below snippet. You will need to find and replace firstname.lastname with your own:

```
[default]
region = eu-west-2

[profile pheroot]
mfa_serial = arn:aws:iam::root account id:mfa/firstname.lastname

[profile talktofrank-dev]
source_profile = pheroot 
role_arn = arn:aws:iam::<account id>:role/AdminRole
mfa_serial = arn:aws:iam::<root account id>:mfa/firstname.lastname
```

### Using aws-vault
You can now use AWS vault from your terminal by running `aws-vault`. See the below examples for commands you can run.

```bash
# open a browser window and login to the AWS Console
$ aws-vault login jonsmith

# List credentials
$ aws-vault list
Profile                  Credentials              Sessions
=======                  ===========              ========
jonsmith                 jonsmith                 -

# Start a subshell with temporary credentials
$ aws-vault exec jonsmith
Starting subshell /bin/zsh, use `exit` to exit the subshell
$ aws s3 ls
bucket_1
bucket_2
```

