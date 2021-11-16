.PHONY: help
help: ## This help message
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)"

publish: ## Publish the binding
	twine upload target/wheels/dhall*.whl

.PHONY: build
build: dev-packages ## Builds Rust code and dhall-python Python modules
	poetry run maturin build --rustc-extra-args="-Wall"

.PHONY: build-release
build-release: dev-packages ## Build dhall-python module in release mode
	poetry run maturin build --release

.PHONY: install
install: dev-packages ## Install dhall-python module into current virtualenv
	poetry run maturin develop --release

.PHONY: publish
publish: ## Publish crate on Pypi
	poetry run maturin publish

.PHONY: clean
clean: ## Clean up build artifacts
	cargo clean

.PHONY: dev-packages
dev-packages: ## Install Python development packages for project
	poetry install

.PHONY: test
test: dev-packages install quicktest ## Intall dhall-python module and run tests

.PHONY: quicktest
quicktest: ## Run tests on already installed dhall-python module
	poetry run pytest tests
