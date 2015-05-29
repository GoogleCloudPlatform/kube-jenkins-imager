#!/bin/bash
set -e
./cluster_up.sh imagertest
./cluster_down.sh imagertest
