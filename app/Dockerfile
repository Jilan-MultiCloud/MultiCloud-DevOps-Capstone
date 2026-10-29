FROM python:3.12-slim

# Use a private AWS ECR mirror of the AWS Lambda Web Adapter.
# This avoids the public ECR 429 rate-limit issue that was failing the build.
COPY --from=319918321628.dkr.ecr.ap-south-1.amazonaws.com/multicloud/lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app
COPY app.py .

USER nobody

EXPOSE 8080
CMD ["python", "app.py"]