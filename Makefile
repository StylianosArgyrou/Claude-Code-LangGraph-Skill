VERSION := $(shell cat VERSION | tr -d '[:space:]')
SKILL_NAME := langgraph
DIST_DIR := dist
SRC_DIR := src

.PHONY: all clean package package-tarball package-combined help install uninstall

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: package package-tarball package-combined ## Build all distribution formats

clean: ## Remove dist directory
	rm -rf $(DIST_DIR)

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

package: $(DIST_DIR) ## Create zip package for ~/.claude/skills/ installation
	@echo "Building $(SKILL_NAME) v$(VERSION) zip package..."
	@rm -rf $(DIST_DIR)/$(SKILL_NAME)
	@mkdir -p $(DIST_DIR)/$(SKILL_NAME)/examples
	@cp $(SRC_DIR)/SKILL.md $(DIST_DIR)/$(SKILL_NAME)/SKILL.md
	@cp $(SRC_DIR)/api-reference.md $(DIST_DIR)/$(SKILL_NAME)/api-reference.md
	@cp $(SRC_DIR)/patterns.md $(DIST_DIR)/$(SKILL_NAME)/patterns.md
	@cp $(SRC_DIR)/examples/*.md $(DIST_DIR)/$(SKILL_NAME)/examples/
	@cd $(DIST_DIR) && zip -r $(SKILL_NAME)-v$(VERSION).zip $(SKILL_NAME)/
	@rm -rf $(DIST_DIR)/$(SKILL_NAME)
	@echo "Created $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION).zip"

package-tarball: $(DIST_DIR) ## Create tar.gz package
	@echo "Building $(SKILL_NAME) v$(VERSION) tarball..."
	@rm -rf $(DIST_DIR)/$(SKILL_NAME)
	@mkdir -p $(DIST_DIR)/$(SKILL_NAME)/examples
	@cp $(SRC_DIR)/SKILL.md $(DIST_DIR)/$(SKILL_NAME)/SKILL.md
	@cp $(SRC_DIR)/api-reference.md $(DIST_DIR)/$(SKILL_NAME)/api-reference.md
	@cp $(SRC_DIR)/patterns.md $(DIST_DIR)/$(SKILL_NAME)/patterns.md
	@cp $(SRC_DIR)/examples/*.md $(DIST_DIR)/$(SKILL_NAME)/examples/
	@cd $(DIST_DIR) && tar -czf $(SKILL_NAME)-v$(VERSION).tar.gz $(SKILL_NAME)/
	@rm -rf $(DIST_DIR)/$(SKILL_NAME)
	@echo "Created $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION).tar.gz"

package-combined: $(DIST_DIR) ## Create single-file combined SKILL.md
	@echo "Building $(SKILL_NAME) v$(VERSION) combined file..."
	@echo "<!-- LangGraph Skill v$(VERSION) - Combined Single File -->" > $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@cat $(SRC_DIR)/SKILL.md >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "---" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@cat $(SRC_DIR)/api-reference.md >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "---" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@cat $(SRC_DIR)/patterns.md >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "---" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "" >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@cat $(SRC_DIR)/examples/complete-examples.md >> $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md
	@echo "Created $(DIST_DIR)/$(SKILL_NAME)-v$(VERSION)-combined.md"

install: ## Install to ~/.claude/skills/langgraph/
	@echo "Installing $(SKILL_NAME) v$(VERSION) to ~/.claude/skills/$(SKILL_NAME)/"
	@rm -rf ~/.claude/skills/$(SKILL_NAME)
	@mkdir -p ~/.claude/skills/$(SKILL_NAME)/examples
	@cp $(SRC_DIR)/SKILL.md ~/.claude/skills/$(SKILL_NAME)/SKILL.md
	@cp $(SRC_DIR)/api-reference.md ~/.claude/skills/$(SKILL_NAME)/api-reference.md
	@cp $(SRC_DIR)/patterns.md ~/.claude/skills/$(SKILL_NAME)/patterns.md
	@cp $(SRC_DIR)/examples/*.md ~/.claude/skills/$(SKILL_NAME)/examples/
	@echo "Installed to ~/.claude/skills/$(SKILL_NAME)/"

uninstall: ## Remove from ~/.claude/skills/langgraph/
	@echo "Removing $(SKILL_NAME) from ~/.claude/skills/"
	@rm -rf ~/.claude/skills/$(SKILL_NAME)
	@echo "Uninstalled $(SKILL_NAME)"
