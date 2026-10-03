# IDX Exchange - AWS Cloud Engineer Internship

Work for the IDX Exchange AWS Cloud Engineer internship (2026). The program is a 12-week, SAA-C03-aligned track built around one small Flask application, PropertyLite: deploying it, scaling it, securing it, containerizing it, automating its releases, and monitoring it on AWS.

## Repository layout

```
propertylite/          Flask property API provided by the program (Week 0)
week-01/               Cloud fundamentals and account setup
scripts/
  check_secrets.sh     pre-push safety check
```

A new `week-NN/` folder is added as each week's deliverable is completed.

## Progress

| Week | Topic |
|------|-------|
| [Week 1](week-01/README.md) | Cloud fundamentals and account setup: root MFA, zero-spend budget, IAM admin user, AWS CLI |

## Running PropertyLite locally

Developed on Ubuntu 22.04 (WSL) with Python 3.10.

The repo holds code only, so the sample data file is not committed. Create `propertylite/rets_property_sample.csv` with the starter rows from Week 0 of the program handbook, or point `PROPERTY_DATA_PATH` at your own copy.

```bash
cd propertylite
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

In a second terminal:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/properties
curl http://localhost:8080/properties/R100234
```

## Safety

Credentials, data files (CSV/SQL), Terraform state, and key files are never committed; see `.gitignore`. AWS account IDs are written as `<account-id>` in committed files.

Before pushing, run:

```bash
bash scripts/check_secrets.sh
```
