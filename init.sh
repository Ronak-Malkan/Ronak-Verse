#!/bin/bash
echo "Starting initial configuration..."
./basic-config.sh
./services/Gateway/deploy.sh
# ./services/TwoCars/deploy.sh
# ./services/TypeItToLoseIt/deploy.sh
# ./database/deploy.sh
./nginx.sh
echo "Configuration complete."