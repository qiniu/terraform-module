#!/bin/bash
set -euo pipefail

hostname -I | awk '{print $1}'
