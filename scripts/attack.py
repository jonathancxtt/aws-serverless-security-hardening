import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

import requests
import boto3
from boto3.dynamodb.conditions import Attr

PAYLOADS = [
    {"name": "' OR 1=1--", "email": "sqli@test.com", "message": "test"},
    {"name": "Ec22322", "email": "test@test.com", "message": "'; DROP TABLE submissions;--"},
    {"name": "Ec22322", "email": "sqli2@test.com", "message": "test"},
    {"name": "Ec22322", "email": "xss@test.com", "message": "test"},
    {"name": "Ec22322", "email": "xss2@test.com", "message": "<img src=x onerror=alert(1)>"},
    {"name": "Ec22322", "email": "xss3@test.com", "message": "<svg onload=alert('xss')>"},
    {"name": "' UNION SELECT null,null--", "email": "sqli3@test.com", "message": "test"},
    {"name": "Ec22322", "email": "xss4@test.com", "message": "javascript:alert(1)"},
    {"name": "1; SELECT SLEEP(5)--", "email": "sqli4@test.com", "message": "test"},
]

BURST_PAYLOAD = {"name": "burst", "email": "burst@test.com", "message": "rate limit test"}


def parse_args():
    parser = argparse.ArgumentParser(description="Attack script for testing the serverless application.")
    parser.add_argument("stage", help="before, after-waf, after-recaptcha")
    parser.add_argument("--api-url", default=os.environ.get("API_URL"), help="API Gateway URL. Defaults to the API_URL environment variable.")
    parser.add_argument("--dynamodb-table", default="aws-serverless-security-hardening-submissions", help="The DynamoDB table name to check for submissions.")
    parser.add_argument("--burst-count", type=int, default=200, help="Number of requests to send in burst mode.")
    parser.add_argument("--region", default="ap-southeast-1", help="AWS default region. Defaults to ap-southeast-1.")

    args = parser.parse_args()
    if args.api_url is None:
        parser.error("No API URL provided. Set the API_URL environment variable or pass --api-url argument.")
    return args