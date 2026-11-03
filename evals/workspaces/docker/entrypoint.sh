#!/bin/sh
set -e
npm run migrate
node dist/main.js
