import json


def lambda_handler(event, context):
    """Handle requests from an AWS Lambda Function URL."""
    request_context = event.get("requestContext", {})
    http = request_context.get("http", {})
    path = http.get("path", "/")

    if path == "/health":
        status_code = 200
        body = {
            "status": "healthy",
            "cloud": "aws",
        }
    elif path == "/":
        status_code = 200
        body = {
            "project": "Multi-Cloud Deployment and Management with Terraform",
            "cloud": "aws",
            "status": "running",
        }
    else:
        status_code = 404
        body = {"error": "not found"}

    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
