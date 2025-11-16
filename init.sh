#!/bin/bash

chmod +x init.sh nginx.sh services/Gateway/deploy.sh services/TwoCars/deploy.sh services/TypeItToLoseIt/deploy.sh services/Portfolio/deploy.sh services/WindBorne/deploy.sh basic-config.sh

echo "Starting initial configuration..."
./basic-config.sh
./services/Gateway/deploy.sh
./services/TwoCars/deploy.sh
./services/TypeItToLoseIt/deploy.sh
./services/Portfolio/deploy.sh
./services/WindBorne/deploy.sh

# ./database/deploy.sh
./nginx.sh
echo "Configuration complete."