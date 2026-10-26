FROM python:3.12-slim

# AWS Lambda Web Adapter: Allows standard HTTP web apps to run on AWS Lambda natively.
# GCP and Azure will simply ignore this extension.
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app
COPY app.py .
USER nobody

EXPOSE 8080
CMD ["python", "app.py"]