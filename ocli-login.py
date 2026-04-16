#!/usr/bin/env python3
"""ocli-login.py - Auto-login ocli on startup using pyocli

This script automatically performs OAuth device code flow to authenticate
with the OIDC provider and obtain an access token.
"""

import sys
from pyocli import start_device_code_flow, finish_device_code_flow

# OIDC configuration
OIDC_ISSUER_URL = "https://authentik-server-runai-sharedllm-ralf.inference.compute.datascience.ch/application/o/vllm/"
OIDC_CLIENT_ID = "P8dW2vrNPDa8d43qd4BK49eEDYJFtvYk"
SCOPES = ["openid", "profile", "email"]


def main():
    """Main login function."""
    print("Starting ocli device code flow...")
    print("If this is your first time, please authenticate when prompted.")

    try:
        # Start device code flow
        data = start_device_code_flow(OIDC_ISSUER_URL, OIDC_CLIENT_ID, SCOPES)
        print(f"Please navigate to: {data.verify_url_full()} and log in")
        
        # Finish device code flow and get token
        token = finish_device_code_flow(data)
        
        print("Successfully obtained access token")
        print(f"Access token: {token.access_token}")
        return 0
        
    except KeyboardInterrupt:
        print("\nLogin cancelled by user")
        return 1
    except Exception as e:
        print(f"Failed to obtain token: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
