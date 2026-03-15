# ==========================================
# MEDIAHUB: Dockerized & Linked Makefile
# ==========================================

.PHONY: help build docker-up docker-down docker-status test-api clean

SERVICES = user-service media-service subscription-service api-gateway discovery-server mediahub-config-server

help:
	@echo ""
	@echo "============================================="
	@echo "    MEDIAHUB MICROSERVICES CONTROL"
	@echo "============================================="
	@echo "Usage: make [command]"
	@echo ""
	@echo "Commands:"
	@echo "  build          Build all Maven jars (required before docker-up)"
	@echo "  docker-up      Start the entire stack (DBs, Eureka, Config, Apps)"
	@echo "  docker-down    Stop and remove all containers"
	@echo "  docker-status  Show status of containers"
	@echo "  test-api       Run an automated integration test (curl series)"
	@echo "  clean          Clean all Maven target folders"
	@echo "============================================="
	@echo ""

# 1. Build everything
build:
	@echo "=== Building all Microservices ==="
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		(cd $$service && ./mvnw clean package -DskipTests); \
		if [ -f $$service/target/*-SNAPSHOT.jar ]; then \
			mv $$service/target/*-SNAPSHOT.jar $$service/target/app.jar; \
		fi; \
	done
	@echo "✔ All services built!"

# 2. Start the stack
docker-up:
	@echo "=== Starting Global Stack ==="
	docker compose up -d
	@echo "✔ Stack is starting up. Check Eureka at http://localhost:8761"

# 3. Stop the stack
docker-down:
	@echo "=== Stopping Global Stack ==="
	docker compose down
	@echo "✔ Stack stopped!"

# 4. Status
docker-status:
	@docker compose ps

# 5. Automated Integration Test
test-api:
	@echo "=== Running Multi-Step Integration Test ==="
	@echo "Step 1: Creating a test user..."
	@EMAIL="test_$$(date +%s)@mediahub.com"; \
	RESPONSE=$$(curl -s -X POST http://localhost:8080/api/v1/users \
		-H "Content-Type: application/json" \
		-d "{\"firstName\": \"Test\", \"lastName\": \"User\", \"email\": \"$$EMAIL\", \"password\": \"password123\", \"role\": \"USER\"}"); \
	USER_ID=$$(echo $$RESPONSE | grep -o '"id":[0-9]*' | cut -d: -f2 | head -n 1); \
	if [ -z "$$USER_ID" ]; then echo "❌ User creation failed: $$RESPONSE"; exit 1; fi; \
	echo "✔ User created with ID: $$USER_ID (Email: $$EMAIL)"; \
	echo "\nStep 2: Creating a test media item..."; \
	MEDIA_TITLE="Test Movie $$(date +%s)"; \
	MEDIA_RESPONSE=$$(curl -s -X POST http://localhost:8080/api/v1/media \
		-H "Content-Type: application/json" \
		-d "{\"title\": \"$$MEDIA_TITLE\", \"description\": \"Microservices Demo Description Long Enough\", \"genre\": \"ACTION\", \"category\": \"MOVIE\", \"releaseYear\": 2024, \"duration\": 120, \"rating\": 8.5}"); \
	MEDIA_ID=$$(echo $$MEDIA_RESPONSE | grep -o '"id":[0-9]*' | cut -d: -f2 | head -n 1); \
	if [ -z "$$MEDIA_ID" ]; then echo "❌ Media creation failed: $$MEDIA_RESPONSE"; exit 1; fi; \
	echo "✔ Media created with ID: $$MEDIA_ID"; \
	echo "\nStep 3: Creating a subscription via Feign validation..."; \
	curl -s -X POST http://localhost:8080/api/v1/subscriptions \
		-H "Content-Type: application/json" \
		-d "{\"userId\": $$USER_ID, \"planType\": \"PREMIUM\", \"price\": 9.99, \"startDate\": \"2024-03-12T00:00:00\", \"endDate\": \"2025-03-12T00:00:00\"}"; \
	echo "\n\nStep 4: Fetching Media Info via WebClient..."; \
	curl -s http://localhost:8080/api/v1/subscriptions/media-info/$$MEDIA_ID; \
	echo "\n\nStep 5: Verifying Gateway Actuator exposure..."; \
	curl -s http://localhost:8080/actuator/gateway/routes | head -c 100; \
	echo "\n\n✔ Integration test sequence complete!"

clean:
	@for service in $(SERVICES); do \
		(cd $$service && ./mvnw clean); \
	done
