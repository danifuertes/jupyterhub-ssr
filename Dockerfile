FROM quay.io/jupyter/pytorch-notebook:x86_64-cuda12-8890fc557a2c

# Install lab python requirements
COPY requirements.txt .

RUN pip install -r requirements.txt

# Change to root user to install some packages
USER root

# Install common linux packages
RUN apt update && apt install -y vim ncdu curl gpg ca-certificates software-properties-common

# Install previous python versions
RUN add-apt-repository ppa:deadsnakes/ppa

RUN apt update && apt install -y python3.7 python3.7-venv python3.8 python3.8-venv python3.9 python3.9-venv python3.10 python3.10-venv python3.11 python3.11-venv python3.12 python3.12-venv

# Change back to jovyan user
USER jovyan
