# SPDX-License-Identifier: MIT

import hashlib
def f(x):
    return hashlib.sha256(x.encode()).hexdigest()
