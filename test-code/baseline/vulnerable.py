# SPDX-License-Identifier: MIT

import os

def unsafe_command(user_input):
    os.system(f"ls {user_input}")
