# SPDX-License-Identifier: MIT

import os

# Simple test case for basic functionality
def test_function(user_input):
    command = f"ls {user_input}"
    os.system(command)  # This should be detected
