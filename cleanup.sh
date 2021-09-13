#!/bin/sh
cd terraform
terraform apply -destroy -input=false -auto-approve
cd ..
