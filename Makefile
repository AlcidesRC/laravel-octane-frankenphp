.DEFAULT_GOAL := help

MAKEFLAGS += $(if $(value VERBOSE),,--no-print-directory)

###
# ENVIRONMENT VARIABLES
###

# Create a dotEnv file if does not exists
$(shell test -f .env || echo "APP_ENV=dev" > .env)

# Load variables from dotEnv file
include .env
export $(shell sed 's/=.*//' .env);

###
# CONSTANTS
###

SERVICE_APP = app
SERVICE_AB  = ab

#---

HOST_USER_ID    := $(shell id --user)
HOST_USER_NAME  := $(shell id --user --name)
HOST_GROUP_ID   := $(shell id --group)
HOST_GROUP_NAME := $(shell id --group --name)

#---

WEBSITE_URL = https://localhost:8000

#---

DOCKER_COMPOSE_APP = docker compose --file docker/docker-compose.yml --file docker/docker-compose.override.$(APP_ENV).yml
DOCKER_COMPOSE_AB  = docker compose --file docker/ab/docker-compose.yml

DOCKER_RUN_AS_ROOT = $(DOCKER_COMPOSE_APP) run -it --rm $(SERVICE_APP)

DOCKER_EXEC_AS_ROOT = $(DOCKER_COMPOSE_APP) exec -it $(SERVICE_APP)

#---

IS_INSTALLED_GUM := $(shell dpkg -s gum 2>/dev/null | grep -q 'Status: install ok installed' && echo 0 || echo 1)

###
# FUNCTIONS
###

define showInfo
	@echo ":small_orange_diamond: $(1)" | gum format -t emoji
	@echo ""
endef

define showAlert
	@echo ":heavy_exclamation_mark: $(1)" | gum format -t emoji
	@echo ""
endef

define taskDone
	@echo ""
	@echo ":small_blue_diamond: Task done!" | gum format -t emoji
	@echo ""
endef

###
# MISCELANEOUS
###

.PHONY: set-environment
set-environment:
	$(eval APP_ENV=$(shell gum choose --header "Setting up Makefile environment..." --selected "dev" "dev" "prod"))
	@gum spin --spinner dot --title "Persisting your selection..." -- sleep 1
	@sed -i 's/^APP_ENV=.*/APP_ENV=$(APP_ENV)/' .env
	$(MAKE) help

.PHONY: ensure_gum_is_installed
ensure_gum_is_installed:
	@if [ "${IS_INSTALLED_GUM}" = "1" ] ; then \
    	clear ; \
    	echo "🔸 Installing dependencies..." ; \
    	echo "" ; \
    	sudo mkdir -p /etc/apt/keyrings ; \
		curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg ; \
		echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list ; \
		sudo apt update && sudo apt install gum ; \
	fi;

.PHONY: require-confirmation
require-confirmation:
	$(eval CONFIRMATION=$(shell gum confirm "Are you sure?" && echo "Y" || echo "N"))

.PHONY: exit
exit:
	$(call showInfo,"See you soon!")
	@exit 0;

.PHONY: welcome
welcome:
	$(eval SERVICES=$(shell docker ps --format '{{.Names}}'))
	@clear
	@gum style --align center --width 80 --padding "1 2" --border double --border-foreground 99 ".: AVAILABLE COMMANDS :."
	@echo ':small_blue_diamond: ENVIRONMENT ... {{ Color "212" "0" " $(APP_ENV) " }}' | gum format -t emoji | gum format -t template; echo ''
	@echo ':small_blue_diamond: DOMAIN URL .... {{ Color "212" "0" " $(WEBSITE_URL) " }}' | gum format -t emoji | gum format -t template; echo ''
	@echo ':small_blue_diamond: SERVICE(S) .... {{ Color "212" "0" " $(SERVICES) " }}' | gum format -t emoji | gum format -t template; echo ''
	@echo ''

###
# HELP
###

.PHONY: help
help: ensure_gum_is_installed welcome
	$(eval OPTION=$(shell gum choose --height 20 --header "Choose a command..." --selected "exit" "exit" "set-environment" "build" "up" "down" "restart" "logs" "inspect" "shell" "install-caddy-certificate" "open-website" "test-stress"))
	@$(MAKE) ${OPTION}

###
# DOCKER RELATED
###

.PHONY: build
build:
	$(call showInfo,"Building Docker image\(s\)...")
	@COMPOSE_BAKE=true $(DOCKER_COMPOSE_APP) build
	$(call taskDone)

.PHONY: up
up:
	$(call showInfo,"Starting service\(s\)...")
	@$(DOCKER_COMPOSE_APP) up --remove-orphans --detach
	$(call taskDone)

.PHONY: down
down:
	$(call showInfo,"Starting service\(s\)...")
	@$(DOCKER_COMPOSE_APP) down --remove-orphans
	$(call taskDone)

.PHONY: restart
restart:
	$(call showInfo,"Starting service\(s\)...")
	@$(DOCKER_COMPOSE_APP) restart
	$(call taskDone)

.PHONY: logs
logs:
	$(call showInfo,"Exposing [ $(SERVICE_APP) ] logs...")
	@$(DOCKER_COMPOSE_APP) logs -f $(SERVICE_APP)
	$(call taskDone)

.PHONY: inspect
inspect:
	$(call showInfo,"Inspecting [ $(SERVICE_APP) ] health...")
	@docker inspect --format "{{json .State.Health}}" $(SERVICE_APP) | jq
	$(call taskDone)

.PHONY: shell
shell:
	$(call showInfo,"Establishing a shell terminal with [ $(SERVICE_APP) ] service...")
	@$(DOCKER_EXEC_AS_ROOT) bash
	$(call taskDone)

###
# CADDY / SSL CERTIFICATE
###

.PHONY: install-caddy-certificate
install-caddy-certificate:
	$(call showInfo,"Installing [ Caddy 20XX ECC Root ] as a valid Local Certificate Authority")
	@gum spin --spinner dot --title "Copy the root certificate from Caddy Docker container..." -- sleep 1
	@docker cp $(SERVICE_APP):/data/caddy/pki/authorities/local/root.crt ./caddy-root-ca-authority.crt
	@gum pager < README-CADDY.md
	$(call taskDone)

###
# SHORTCUTS
###

.PHONY: open-website
open-website: ## Application: opens the application URL
	$(call showInfo,"Opening the application URL...")
	@echo ""
	@xdg-open $(WEBSITE_URL)
	@$(call showAlert,"Press Ctrl+C to resume your session")
	$(call taskDone)

###
# APPLICATION
###

.PHONY: reload
reload: ## Application: reloads the Application
	$(call showInfo,"Reload the Application...")
	@$(DOCKER_EXEC_AS_ROOT) php artisan cache:clear
	@$(DOCKER_EXEC_AS_ROOT) php artisan octane:reload
	$(call taskDone)

###
# APACHE-BENCHMARK
###

.PHONY: get-webserver-ip-address
get-webserver-ip-address:
	$(eval WEBSERVER_IPADDRESS=$(shell docker inspect --format "{{json .NetworkSettings.Networks.docker_default.Gateway}}" $(SERVICE_APP) | jq -r))

.PHONY: test-stress
test-stress: get-webserver-ip-address ## Apache Benchmark stress test
	$(call showInfo,"Apache Benchmark on [ $(WEBSERVER_IPADDRESS) ] - Endpoint [ / ]...")
	@WEBSERVER_IPADDRESS=$(WEBSERVER_IPADDRESS) $(DOCKER_COMPOSE_AB) run --rm -it --user $(HOST_USER_ID):$(HOST_GROUP_ID) $(SERVICE_AB) sh -c "cd homepage; sh runner.sh"
	@echo "" && gum spin --spinner minidot --title "Taking a breath..." -- sleep 5 && echo ""
	$(call showInfo,"Apache Benchmark on [ $(WEBSERVER_IPADDRESS) ] - Endpoint [ /post ]...")
	@WEBSERVER_IPADDRESS=$(WEBSERVER_IPADDRESS) $(DOCKER_COMPOSE_AB) run --rm -it --user $(HOST_USER_ID):$(HOST_GROUP_ID) $(SERVICE_AB) sh -c "cd post; sh runner.sh"
	$(call taskDone)
