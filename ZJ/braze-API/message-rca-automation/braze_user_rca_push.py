from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.operators.python import PythonOperator
from utils import slack_utils as slackutils
from utils import aws_secret_manager_utils as aws
from airflow.models import Variable
from typing import List, Tuple
from functools import partial
from pathlib import Path
from datetime import datetime, timedelta
import requests
import json
import logging

logger = logging.getLogger(__name__)

ERRORS_SLACK_ALERT_CHANNEL = 'marketing-alerts'

# Default arguments for the DAG
DEFAULT_ARGS = {
    "owner": "marketing",
    "depends_on_past": False,
    "start_date": datetime(2020, 1, 31),
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
    "on_failure_callback": partial(slackutils.notify_dag_failure, ERRORS_SLACK_ALERT_CHANNEL),
}

AIRFLOW_ENV = Variable.get("AIRFLOW_ENV")

# Use Path to handle directories and paths properly
DAG_DIR = Path(__file__).parent
SQL_FILE_PATH = 'sql/talent_list.sql'
DEEP_LINK_FILE = DAG_DIR / 'configs/deep_link_mapping.json'

BRAZE_API_KEY = aws.get_secret(f"{AIRFLOW_ENV}/main/bi-pipelines/braze_api_key")

# Load deep link mappings
def load_deep_links(file_path: Path) -> dict:
    with open(file_path, 'r') as file:
        return json.load(file)

# Function to map job categories to deep links for Braze API
def get_deep_link(job_category: str, categories: dict) -> str:
    """
    Dynamically constructs the deep link based on the job category.
    Args:
        job_category (str): The job category name.
        categories (dict): Pre-loaded category mappings.
    Returns:
        str: The dynamically constructed deep link associated with the job category.
    """
    base_url = "zenjob://offers/home/feed=short_term"
    category_key = categories.get(job_category)

    # If a category key is found, append it to the base URL
    if category_key:
        return f"{base_url}&category={category_key}"
    else:
        # Default URL if the category is not found
        return base_url

# Function to prepare payload for Braze API
def prepare_payload(data: List[Tuple]) -> dict:
    """
    Prepares the payload for the Braze API based on the data fetched from the database.
    Args:
        data (List[Tuple]): The data fetched from the database, each row is a tuple.
    Returns:
        dict: A dictionary representing the payload for the Braze API.
    """
    with open(DEEP_LINK_FILE, 'r') as file:
        categories = json.load(file)

    payload = {"attributes": []}

    for row in data:
        uuid = row[1]  # user_uuid
        job_category = row[4]  # job_category_name
        deep_link = get_deep_link(job_category, categories)
        rca_date = datetime.today().strftime('%Y-%m-%d %H:%M:%S')  # attribute for segmentation with date

        payload["attributes"].append({
            "external_id": uuid,
            "rca_job_category": job_category,
            "rca_deep_link": deep_link,
            "is_rca_date": rca_date
        })

    logger.info(payload)
    return payload

# Function to send the prepared payload to Braze API in batches of 50
def send_to_braze(payload: dict, braze_api_key: str, batch_size: int = 50):
    """
    Sends the prepared payload to the Braze API in batches.
    Args:
        payload (dict): The prepared payload to send to Braze.
        braze_api_key (str): The Braze API key.
        batch_size (int): Maximum number of records per batch (default is 50).
    """
    braze_endpoint = 'https://rest.fra-01.braze.eu/users/track'
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {braze_api_key}'
    }

    # Split payload into batches of 50 users
    attributes = payload.get("attributes", [])
    for i in range(0, len(attributes), batch_size):
        # Prepare a batch of 50 users at a time
        batch = {"attributes": attributes[i:i + batch_size]}
        payload_json = json.dumps(batch)
        
        # Log the batch being sent to Braze
        logger.info(f"Sending batch {i // batch_size + 1} to Braze.")

        # Send the request to Braze
        response = requests.post(braze_endpoint, headers=headers, data=payload_json)

        # Check the response status
        if response.status_code == 201:
            logger.info(f"Batch {i // batch_size + 1} successfully sent to Braze.")
        else:
            logger.error(f"Failed to send batch {i // batch_size + 1} to Braze: {response.status_code} - {response.text}")
            exit(1)

# Python callback to process the fetched data
def process_braze_data(**context):
    """
    Fetches data from the PostgreSQL database, prepares a payload, and sends it to Braze API.
    """
    # Get configurations from the main function
    data = context['task_instance'].xcom_pull(task_ids='fetch_data_from_db')
    if data:
        payload = prepare_payload(data)
        logger.info("Sending prepared payload to Braze in batches.")
        send_to_braze(payload, BRAZE_API_KEY)
    else:
        logger.error("No data returned from database or error occurred.")

# Define the DAG
with DAG(
        dag_id='braze_user_rca_push',
        default_args=DEFAULT_ARGS,
        catchup=False,
        max_active_runs=1,
        schedule_interval='0 12 * * *',
        tags=["marketing", "braze"],
) as dag:
    # PostgresOperator to execute SQL from the file
    fetch_data_from_db = PostgresOperator(
        task_id='fetch_data_from_db',
        postgres_conn_id='mkt',  # Replace with your Postgres connection ID
        sql=str(SQL_FILE_PATH),  # Path to the SQL file, converted to a string for compatibility
    )

    # PythonOperator to process the data fetched by PostgresOperator
    process_braze_data_task = PythonOperator(
        task_id='process_braze_data',
        python_callable=process_braze_data,
        provide_context=True
    )

    # Task dependencies
    fetch_data_from_db >> process_braze_data_task
    