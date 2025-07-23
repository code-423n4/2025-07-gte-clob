#!/bin/bash

# cast hash-message "i know what im doing"
SCRIPT_CALLER_KEY="0x3b33cf1fc7c4e49a355ed5f1cd7a5e22fe25e0aa3201a4e371b6a99c1bd29af0"

upgrade_protections_test() {
    export SCRIPT_CALLER_KEY="$SCRIPT_CALLER_KEY"

    forge script script/upgrades/UpgradeProtection.s.sol:UpgradeProtection --broadcast
}

#temp_upgrade_clob_manager() {}

#upgrade_bonding_curve() {

#}

#upgrade_clob_script() {}

#upgrade_clob_manager_script() {}

#upgrade_gtl_script() {}

#upgrade_launchpad_script() {}

#upgrade_perp_manager_script() {}

#upgrade_router_script() {}



main() {

    # Ensure scripts are run from dev main
    if [[ "$(git branch --show-current)" != "dev-main" ]]; then
        echo -e "Error: Must be on dev-main to deploy upgrade impls!\n"
        exit 1
    fi

    # Ensure no local unstaged changes
    if git status --porcelain | grep -q .; then
        echo -e "Error: Working directory is not clean. Commit or stash your changes first!\n"
        exit 1;
    fi

    case "$1" in
        "test_upgrade")
            upgrade_protections_test
            ;;
        *)
            echo "Usage TODO"

    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
