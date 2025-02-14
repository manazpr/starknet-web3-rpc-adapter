import os


def require_env(name):
    value = os.getenv(name)
    assert value, f"Env {name} not provided."
    return value


ACCOUNT_CONTRACT_HASH = int(require_env("ACCOUNT_CONTRACT_HASH"), 0)
CONTRACT_SALT = int(require_env("CONTRACT_SALT"), 0)
NODE_URL = require_env("NODE_URL")
DOMAIN_NAME = require_env("DOMAIN_NAME")
