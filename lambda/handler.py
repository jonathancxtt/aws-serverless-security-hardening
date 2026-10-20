import boto3
import json
from datetime import datetime, timezone
import uuid
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')

table = dynamodb.Table(os.environ['DYNAMODB_TABLE_NAME'])

HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*"
}

def response(status_code, message):
    return {
        "statusCode": status_code,
        "headers": HEADERS,
        "body": json.dumps({"message": message})
    }

def lambda_handler(event, context):
    try:
        submission_payload = json.loads(event.get('body') or '')
        if not isinstance(submission_payload, dict):
            raise ValueError("Request body is not a JSON object")
    except (json.JSONDecodeError, ValueError) as e:
        logger.warning("Rejected invalid request body: %s", e)
        return response(400, "Invalid request body.")

    try:
        ct = datetime.now(timezone.utc).isoformat()

        submission = {
        "submission_id" : str(uuid.uuid4()),
        "name" : submission_payload.get('name', ''),
        "email" : submission_payload.get('email', ''),
        "message" : submission_payload.get('message', ''),
        "timestamp" : ct
        }

        table.put_item(Item=submission)

        return response(200, "Submission received.")
    except Exception:
        # Full details go to CloudWatch only; the client gets a generic message
        logger.exception("Failed to process submission")
        return response(500, "Failed to process submission.")
