FROM python:3.9-slim

# Install kubectl
RUN apt-get update && apt-get install -y curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Copy controller script
COPY webapp-controller.py /app/webapp-controller.py
WORKDIR /app

# Run the controller
CMD ["python3", "webapp-controller.py"]
