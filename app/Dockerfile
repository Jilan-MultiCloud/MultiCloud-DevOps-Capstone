FROM python:3.12-slim

# Pull the official AWS Lambda Web Adapter from the AWS ECR Public Gallery 
# to fix the Docker Hub resolution error.
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app
COPY app.py .
USER nobody

EXPOSE 8080
CMD ["python", "app.py"]
