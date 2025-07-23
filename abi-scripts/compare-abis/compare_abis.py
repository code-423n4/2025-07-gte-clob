#!/usr/bin/env python3


import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional
from dataclasses import dataclass, field
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class ContractMetadata:
    path: str
    abi_version: int
    identifiers: Dict[str, str]

def main() -> None:
    """Main function that orchestrates the contract processing."""
    try:
        compre_abis()
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


def compre_abis():
    """
    Compares the abis between the current branch and staging,
    asserting that changes to function or event identifiers include an ABI_VERSION bump in the contracts
    """

    result = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True)


    if iter(result.stdout.splitlines()):
        raise AssertionError("Branch must be clean to perform this check. Commit all changes or run in a git workflow!")


    local = current_branch_contracts()
    base = base_branch_contracts()

    for name, data in base.items():
        print(name, data)
        for identifier, signature in data.identifiers.items:
            print(identifier, signature)
            local_contract = local[name]

            # todo add condition back
            if True:
                raise AssertionError(f"""
                    Local contract {local_contract.path} is overriding the base branch's abi, but does not contain a new ABI_VERSION
                    Local: function/event {identifier} - signature {local_contract.identifiers[identifier]}
                    Base: function/event {identifier} - signature {signature}

                    Suggestion: Bump {name}.sol's public constant ABI_VERSION = {local_contract.abi_version}
                """)

    raise AssertionError("add branch check back")

def current_branch_contracts() -> Dict[str, ContractMetadata]:
    """
    Gets the current branch's contract metadata
    """

    print("Compiling current contracts...")
    subprocess.run(["forge", "clean"], capture_output=True)
    subprocess.run(["forge", "compile"], capture_output=True)

    print("Parsing ABIs...")
    return get_upgradeable_contract_metadata()

def base_branch_contracts() -> Dict[str, ContractMetadata]:
    """
    Gets staging's contract metadata
    """

    result = subprocess.run(["git", "branch", "--show-current"], text=True, capture_output=True)

    current_branch = result.stdout.splitlines()[0]

    subprocess.run(["git", "fetch", "origin", "staging"], capture_output=True)
    subprocess.run(["git", "checkout", "staging"], capture_output=True)

    result = subprocess.run(["git", "branch", "--show-current"], text=True, capture_output=True)
    base_branch = result.stdout.splitlines()[0]

    if base_branch == current_branch:
        raise AssertionError("Could not checkout staging. Commit or stash all changes before running this check")

    print("Compiling staging contracts...")
    subprocess.run(["forge", "clean"], capture_output=True)
    subprocess.run(["forge", "compile"], capture_output=True)


    print("Parsing ABIs...")
    abis = get_upgradeable_contract_metadata()

    subprocess.run(["git", "checkout", current_branch], capture_output=False)
    subprocess.run(["forge", "clean"])

    return abis



def get_upgradeable_contract_metadata() -> Dict[str, ContractMetadata]:
    """
    Gets the metadata (name, path, abi version, and identifiers) of all the upgradeable contracts in the repo
    """

    contracts_dir = Path("./contracts/")
    version_identifier = "uint256 public constant ABI_VERSION ="
    upgradeable_contracts: Dict[str, ContractMetadata] = {}

    if not contracts_dir.exists():
        logger.error(f"Contracts directory does not exist: {contracts_dir}")
        return upgradeable_contracts

    # Walk through all .sol files in the contracts directory
    for sol_file in contracts_dir.rglob("*.sol"):

        with open(sol_file, 'r', encoding='utf-8') as file:
            for line in file:
                line = line.strip()

                if line.startswith(version_identifier):
                    # Extract version string after the identifier
                    version_str = line[len(version_identifier):].strip()

                    # Remove semicolon at the end
                    if version_str.endswith(';'):
                        version_str = version_str[:-1]

                    abi_version = int(version_str)


                    # Get contract name (filename without .sol extension)
                    contract_name = sol_file.stem

                    # Check for duplicate contract names
                    if contract_name in upgradeable_contracts:
                        logger.error("Proxy contracts must have different names")
                        sys.exit(1)

                    identifiers = parse_abi(str(sol_file))

                    upgradeable_contracts[contract_name] = ContractMetadata(
                        path=str(sol_file),
                        abi_version=abi_version,
                        identifiers=identifiers
                    )

                    break  # Found the version line, move to next file
        continue

    return upgradeable_contracts


def parse_abi(contract_path: str) -> Dict[str, str]:
    """
    Gets the function and event identifiers from a contract
    """
    ids: Dict[str, str] = {}

    result = subprocess.run(["forge", "inspect", contract_path, "abi"], capture_output=True, text=True)

    for line in iter(result.stdout.splitlines()):
        if line.startswith("| event") |  line.startswith("| function"):
            name, sig = parse_abi_line(line)
            ids[name] = sig
        else:
            continue

    return ids

def parse_abi_line(line: str) -> str | str:
    """
    Cleans the forge inspect output line to get just the identifier name and signature
    """
    subs = line.split("|", 3)

    name = subs[2].split("(")[0]
    sig = subs[3].split(' ')[1]

    return name, sig

if __name__ == "__main__":
    main()
