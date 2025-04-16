#!/usr/bin/env python3
import argparse
import boto3
import psycopg2
import secrets
import string
import json
import getpass
import logging
from contextlib import contextmanager
from urllib.parse import urlparse, urlunparse
import os

# Change config here. PG_USER's password will be prompted for when the script is run
CONFIG = {
    "PG_USER": os.getenv("PG_USER", "root"),
    "PG_HOST": os.getenv("PG_HOST", "localhost"),
    "PG_PORT": int(os.getenv("PG_PORT", "5432")),
    "SHORT_PROJECT_NAME": os.getenv("SHORT_PROJECT_NAME", "prj"),
    "SHORT_REGION_NAME": os.getenv("SHORT_REGION_NAME", "euw2"),
    "ENVIRONMENT_NAME": os.getenv("ENVIRONMENT_NAME", "uat"),
    "DB_NAME": os.getenv("DB_NAME", "db_name"),
    "PASSWORD_LENGTH": int(os.getenv("PASSWORD_LENGTH", "30"))
}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

dry_run = False

@contextmanager
def get_db_cursor(pg_password: str):
    connection = psycopg2.connect(
        database=CONFIG["DB_NAME"],
        user=CONFIG["PG_USER"],
        password=pg_password,
        host=CONFIG["PG_HOST"],
        port=CONFIG["PG_PORT"],
    )
    try:
        with connection:
            with connection.cursor() as cursor:
                yield cursor
    finally:
        connection.close()

def generate_password(length: int) -> str:
    """Generate a secure password of given length with required complexity."""
    alphabet = string.ascii_letters + string.digits
    while True:
        password = "".join(secrets.choice(alphabet) for _ in range(length))
        if (
            any(c.islower() for c in password)
            and any(c.isupper() for c in password)
            and sum(c.isdigit() for c in password) >= 5
        ):
            return password

# Manually change these. The username should match the name of the IAM role of the task or EC2 instance that connects to the database.
# this will allow us to use IAM authentication in the future.
users = [
    {
        "username": f"aw-{CONFIG["SHORT_PROJECT_NAME"]}-global-{CONFIG["ENVIRONMENT_NAME"]}-iamrole-task-backend",
        "secret_id": f"aw-{CONFIG["SHORT_PROJECT_NAME"]}-{CONFIG["ENVIRONMENT_NAME"]}-secret-postgres_details",
        "password": None,
        "is_connection_string": False
    }
    # {
    #     "username": f"aw-{CONFIG["SHORT_PROJECT_NAME"]}-global-{CONFIG["ENVIRONMENT_NAME"]}-iamrole-lambda-processor",
    #     "secret_id": f"aw-{CONFIG["SHORT_PROJECT_NAME"]}-{CONFIG["SHORT_REGION_NAME"]}-{CONFIG["ENVIRONMENT_NAME"]}-secret-database_credentials_lambda_processor",
    #     "password": None,
    #     "is_connection_string": False
    # }
]

def update_secret_manager(user: dict, is_connection_string: bool) -> None:
    """Update the secret for a user with new credentials."""
    secret_id = user["secret_id"]
    username = user["username"]
    new_password = user["password"]

    try:
        secret_response = sm.get_secret_value(SecretId=secret_id)
    except Exception as e:
        logger.error(f"Error fetching secret {secret_id}: {e}")
        return

    secret_string = secret_response.get("SecretString")
    if is_connection_string:
        try:
            secret_obj = json.loads(secret_string)
        except json.JSONDecodeError:
            logger.error(f"Secret {secret_id} is not valid JSON.")
            return

        # Assume the JSON has a single key-value pair containing the connection string.
        key = next(iter(secret_obj))
        conn_str = secret_obj[key]
        parsed = urlparse(conn_str)
        # Rebuild the netloc with new password (retain username and hostname/port)
        new_netloc = f"{parsed.username}:{new_password}@{parsed.hostname}"
        if parsed.port:
            new_netloc += f":{parsed.port}"
        new_parsed = parsed._replace(netloc=new_netloc)
        secret_obj[key] = urlunparse(new_parsed)
        new_secret_value = secret_obj
    else:
        try:
            secret_obj = json.loads(secret_string)
        except json.JSONDecodeError:
            logger.error(f"Secret {secret_id} is not valid JSON.")
            return
        secret_obj["DB_USER"] = username
        secret_obj["DB_PASSWORD"] = new_password
        new_secret_value = secret_obj

    if dry_run:
        logger.info(f"DRY RUN: Would update secret {secret_id} with:\n{json.dumps(new_secret_value, indent=2)}")
        return

    try:
        sm.update_secret(SecretId=secret_id, SecretString=json.dumps(new_secret_value))
        logger.info(f"Updated secret {secret_id}")
    except Exception as err:
        logger.error(f"Unable to update secret {secret_id}: {err}")

def update_postgres_password(user: dict, cursor) -> None:
    username = user["username"]
    password = generate_password(CONFIG["PASSWORD_LENGTH"])
    user["password"] = password

    check_user_sql = "SELECT 1 FROM pg_roles WHERE rolname = %s;"
    create_user_sql = f'CREATE USER "{username}" WITH PASSWORD %s;'
    update_password_sql = f'ALTER USER "{username}" WITH PASSWORD %s;'
    grant_privs_sql = f'GRANT ALL PRIVILEGES ON DATABASE "{CONFIG["DB_NAME"]}" TO "{username}";'
    grant_table_privs_sql = f'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "{username}";'
    grant_public_schema_sql = f'GRANT USAGE ON SCHEMA public TO "{username}";'

    if dry_run:
        logger.info("DRY RUN: Would execute SQL for user %s:", username)
        logger.info("  %s", check_user_sql)
        logger.info("  %s", create_user_sql)
        logger.info("  %s", update_password_sql)
        logger.info("  %s", grant_privs_sql)
        logger.info("  %s", grant_public_schema_sql)
        logger.info("  %s", grant_table_privs_sql)
        return

    try:
        cursor.execute(check_user_sql, (username,))
        if cursor.fetchone():
            cursor.execute(update_password_sql, (password,))
        else:
            cursor.execute(create_user_sql, (password,))
        cursor.execute(grant_privs_sql)
        cursor.execute(grant_public_schema_sql)
        cursor.execute(grant_table_privs_sql)
        logger.info(f"Postgres user {username} updated successfully.")
    except Exception as err:
        logger.error(f"Error updating user {username}: {err}")
        cursor.connection.rollback()

def main():
    global dry_run, sm
    parser = argparse.ArgumentParser(
        description="Update Postgres passwords and corresponding AWS Secrets Manager entries."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Perform a dry run (do not execute changes)",
    )
    args = parser.parse_args()
    dry_run = args.dry_run

    sm = boto3.client("secretsmanager")

    if not dry_run:
        pg_password = getpass.getpass(f"Password for {CONFIG['PG_USER']}: ")
        with get_db_cursor(pg_password) as cursor:
            for user in users:
                update_postgres_password(user, cursor)
                update_secret_manager(user, user["is_connection_string"])
    else:
        for user in users:
            update_postgres_password(user, None)
            update_secret_manager(user, user["is_connection_string"])

if __name__ == "__main__":
    main()
