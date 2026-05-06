# SPDX-License-Identifier: MIT

# SPDX-License-Identifier: MIT

import os
# This should trigger a security finding
def unsafe_command(user_input):
    os.system(user_input)  # Command injection vulnerability
