# SPDX-License-Identifier: MIT

import hashlib

def safe_function():
    return hashlib.sha256(b"test").hexdigest()
