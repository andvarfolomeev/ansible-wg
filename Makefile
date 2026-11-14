IMAGE_NAME=ansible-wg-test
CONTAINER_NAME=ansible-wg-test
SSH_PORT=2222
# Keep in sync with inventory_docker_example.ini
SSH_USER=ansible
SSH_PASS=ansible123
DOCKERFILE=Dockerfile

.PHONY: help docker-build docker-run docker-info docker-clean wg xray swap secrets

help:
	@echo "Deploy:  make wg | xray | swap   (extra ansible-playbook flags: ARGS=\"--tags quota --check\")"
	@echo "Docker:  make docker-build | docker-run | docker-info | docker-clean"
	@echo "Checks:  make secrets   (leaked keys in git history: own checks, gitleaks, trufflehog)"

docker-build:
	@echo "🔧 Building image from $(DOCKERFILE)..."
	docker build -f $(DOCKERFILE) --build-arg SSH_USER=$(SSH_USER) --build-arg SSH_PASS=$(SSH_PASS) -t $(IMAGE_NAME) .

docker-run:
	@echo "🧹 Removing old container (if exists)..."
	-@docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	@echo "🚀 Starting container $(CONTAINER_NAME)..."
	docker run -d --name $(CONTAINER_NAME) -p $(SSH_PORT):22 --privileged $(IMAGE_NAME)

docker-info:
	@CONTAINER_IP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CONTAINER_NAME)); \
	echo ""; \
	echo "✅ Container launched and ready to use!"; \
	echo "➡️  SSH access: ssh $(SSH_USER)@127.0.0.1 -p $(SSH_PORT)"; \
	echo "🔐 Password: $(SSH_PASS)"; \
	echo "🌐 Internal container IP (Docker): $$CONTAINER_IP"

docker-clean:
	@echo "🗑 Removing container and image..."
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	-docker rmi $(IMAGE_NAME) 2>/dev/null || true

wg:
	ansible-playbook -i inventory.ini setup-wireguard.yml --ask-become-pass $(ARGS)

xray:
	ansible-playbook -i inventory.ini setup-xray.yml --ask-become-pass $(ARGS)

swap:
	ansible-playbook -i inventory.ini setup-swap.yml --ask-become-pass $(ARGS)

secrets:
	./scripts/secrets-check.sh
	gitleaks git --redact --no-banner --log-opts="--all" .
	trufflehog git file://. --no-verification --fail
