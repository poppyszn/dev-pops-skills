#!/bin/bash
# Run in CI as: ssh deploy@host 'bash -s' < scripts/deploy.sh
cd ~/orders-api
source .env
docker compose pull
docker compose up -d
