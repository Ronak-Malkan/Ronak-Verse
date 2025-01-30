#!/bin/bash
echo "Starting initial configuration..."
./basic-config.sh
./nginx.sh
./services/portfolio/deploy.sh
./services/TwoCars/deploy.sh
./services/TypeItToLoseIt/deploy.sh
./database/deploy.sh
echo "Configuration complete."