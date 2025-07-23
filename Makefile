deploy-test-upgrade:
	@./script/upgrades/script-callers/run-upgrades.sh test_upgrade

.PHONY: deploy-test-upgrade
