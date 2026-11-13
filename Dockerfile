FROM debian:12

# Keep in sync with Makefile and inventory_docker_example.ini
ARG SSH_USER=ansible
ARG SSH_PASS=ansible123

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server sudo python3 \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash -G sudo "$SSH_USER" \
    && echo "$SSH_USER:$SSH_PASS" | chpasswd
# sshd refuses to start without its privilege separation directory
RUN mkdir -p /run/sshd
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
