#!/bin/bash

echo -e "\n+++++ Starting deployment +++++\n"

rm -rf ./bin

echo "+++++ build go packages +++++"

cd source/hello
go get
go test ./...
env GOOS=linux GOARCH=amd64 go build -o ../../bin/hello
cd ../..

echo "+++++ hello module +++++"
cd terraform
terraform init -input=false
terraform apply -input=false -auto-approve
cd ..

echo -e "\n+++++ Deployment done +++++\n"