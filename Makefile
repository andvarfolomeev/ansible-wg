IMAGE_NAME=ubuntu:ssh-enabled
CONTAINER_NAME=ansible-test-ubuntu
SSH_PORT=2222
SSH_USER=ansible
SSH_PASS=ansible123
DOCKERFILE=Dockerfile

.PHONY: all build wg xray clean info

all: build wg xray info

docker-build:
	@echo "🔧 Building image from $(DOCKERFILE)..."
	docker build -f $(DOCKERFILE) -t $(IMAGE_NAME) .

docker-run:
	@echo "🧹 Removing old container (if exists)..."
	-@docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	@echo "🚀 Starting container $(CONTAINER_NAME)..."
	docker run -d --name $(CONTAINER_NAME) -p $(SSH_PORT):22 --cap-add=NET_ADMIN --device /dev/net/tun $(IMAGE_NAME)

docker-info:
	@CONTAINER_IP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CONTAINER_NAME)); \
	echo ""; \
	echo "✅ Container launched and ready to use!"; \
	echo "➡️  SSH access: ssh $(SSH_USER)@127.0.0.1 -p $(SSH_PORT)"; \
	echo "🔐 Password: $(SSH_PASS)"; \
	echo "🌐 Internal container IP (Docker): $$CONTAINER_IP"

dcoker-clean:
	@echo "🗑 Removing container and image..."
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	-docker rmi $(IMAGE_NAME) 2>/dev/null || true

wg:
	ansible-playbook -i inventory.ini setup-wireguard.yml --ask-become-pass

xray:
	ansible-playbook -i inventory.ini setup-xray.yml --ask-become-pass
