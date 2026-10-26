FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app
COPY app.py runtime_metrics.py ./
USER nobody

EXPOSE 8080
CMD ["python", "app.py"]
