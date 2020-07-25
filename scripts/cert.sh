#!/bin/bash

# Obtain a list of node
kubectl get nodes | awk '{print $1}' | sed '1d';

# Create variable for instance name, zone, and project
INSTANCE="";
ZONE="";
PROJECT=""

# Upload the certificate file to instance
gcloud compute scp ${PWD}/domain.crt "${INSTANCE}":~/ca.crt;

# SSH into Instance
gcloud beta compute ssh --zone "${ZONE}" --project "${PROJECT}" "${INSTANCE}";

# Create certs directory
REGISTRY_DOMAIN="";
REGISTRY_PORT="";
sudo mkdir -p /etc/docker/certs.d/${REGISTRY_DOMAIN}:${REGISTRY_PORT};

# Copy cert file
sudo cp $PWD/domain.crt /etc/docker/certs.d/${REGISTRY_DOMAIN}:${REGISTRY_PORT}/ca.crt