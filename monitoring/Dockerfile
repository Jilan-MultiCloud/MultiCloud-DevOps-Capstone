FROM python:3.12-slim
WORKDIR /workspace
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
COPY scripts ./scripts
ENV PYTHONPATH=/workspace
USER nobody
CMD ["python", "-m", "scripts.monitor"]
