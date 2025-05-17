import os
import sys

def validate_env_vars(*required_env_vars):
    missing_vars = [var for var in required_env_vars if not os.getenv(var)]
    if missing_vars:
        if len(missing_vars) == 1:
            print(f"Error: The environment variable '{missing_vars[0]}' is not set.")
        else:
            missing_list = ", ".join(f"'{var}'" for var in missing_vars)
            print(f"Error: The environment variables {missing_list} are not set.")
        sys.exit(1)