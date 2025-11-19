#!/bin/bash

# Script de démarrage pour Lambda avec Lambda Web Adapter
# Configure les chemins Python et lance uvicorn

PATH=$PATH:$LAMBDA_TASK_ROOT/bin \
    PYTHONPATH=$LAMBDA_TASK_ROOT/packages:$PYTHONPATH:/opt/python:$LAMBDA_RUNTIME_DIR \
    exec python -m uvicorn --port=$PORT main:app
