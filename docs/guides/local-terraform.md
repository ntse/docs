---
title: Working on Terraform Locally
parent: Guides
---

To work on Terraform locally, you can either use actual AWS resources or run against Localstack. Both approaches are fully compatible with [Terrarunt](https://github.com/ntse/Terrarunt).

---

### Running Locally with Real AWS

Install Terrarunt and [aws-vault](https://github.com/99designs/aws-vault). For help configuring aws-vault, see the [aws-vault guide](./guides/aws-vault.md).

```bash
pip install git+https://github.com/ntse/terrarunt.git
brew install aws-vault
```

Once aws-vault is configured, use it to open a shell and run Terrarunt to bootstrap and deploy your environment. Replace values in <> as appropriate:

```bash
cd <your-terraform-project>
aws-vault exec <aws-profile-name> --
terrarunt --env=<dev> bootstrap
terrarunt --env=<dev> apply-all
```

### Running Locally with Localstack
If you want to simulate AWS locally without provisioning real infrastructure, you can use Localstack with tflocal.

Install Terrarunt and terraform-local:

```bash
pip install git+https://github.com/ntse/terrarunt.git
pip install terraform-local
```

Start Localstack in Docker:
```bash
docker run -d -p 4566:4566 localstack/localstack
```

Override the Terraform binary used by Terrarunt (--terraform-bin=tflocal) and run your workflow as normal:
```bash
terrarunt --terraform-bin=tflocal --env=<dev> bootstrap
terrarunt --terraform-bin=tflocal --env=<dev> apply-all
```