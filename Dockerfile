FROM quay.io/jupyter/pytorch-notebook:x86_64-cuda12-8890fc557a2c

# Install lab python requirements
COPY requirements.txt .

RUN pip install -r requirements.txt

# Change to root user to install some packages
USER root

# Install common linux packages
RUN apt update && apt install -y vim ncdu curl gpg ca-certificates software-properties-common

# # Install miniconda
# RUN curl https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | gpg --dearmor > conda.gpg

# RUN install -o root -g root -m 644 conda.gpg /usr/share/keyrings/conda-archive-keyring.gpg

# RUN gpg --keyring /usr/share/keyrings/conda-archive-keyring.gpg --no-default-keyring --fingerprint 34161F5BF5EB1D4BFBBB8F0A8AEB4F8B29D82806

# RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/conda-archive-keyring.gpg] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" > /etc/apt/sources.list.d/conda.list

# RUN apt update && apt install -y conda

# Install previous python versions
RUN add-apt-repository ppa:deadsnakes/ppa

RUN apt update && apt install -y python3.7 python3.7-venv python3.8 python3.8-venv python3.9 python3.9-venv python3.10 python3.10-venv python3.11 python3.11-venv python3.12 python3.12-venv

# Change back to jovyan user
USER jovyan
