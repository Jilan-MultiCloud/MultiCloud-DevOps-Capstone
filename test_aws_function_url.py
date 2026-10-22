
import boto3
import requests
from requests_aws4auth import AWS4Auth

REGION = "ap-south-1"
SERVICE = "lambda"
URL = (
    "https://hr5wkrgtaoxun4fbodccb6a7zu0bqjya"
    ".lambda-url.ap-south-1.on.aws/health"
)


def main():
    session = boto3.Session(region_name=REGION)
    credentials = session.get_credentials()

    if credentials is None:
        raise RuntimeError(
            "AWS credentials were not found. Check your AWS CLI configuration."
        )

    frozen = credentials.get_frozen_credentials()

    auth = AWS4Auth(
        frozen.access_key,
        frozen.secret_key,
        REGION,
        SERVICE,
        session_token=frozen.token,
    )

    response = requests.get(URL, auth=auth, timeout=15)

    print("HTTP status:", response.status_code)
    print("Response:", response.text)
    response.raise_for_status()


if __name__ == "__main__":
    main()
