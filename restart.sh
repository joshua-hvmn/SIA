#!/bin/bash

sudo lsof -i 

app=$(sudo lsof -i :80 | awk 'NR>1 {print $1; exit}')
echo "App name: $app"