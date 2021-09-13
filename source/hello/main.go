package main

import (
	"github.com/JaderDias/go-aws-lambda-video-gen/source/hello/handler"
	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	handler := handler.Create()
	lambda.Start(handler.Run)
}
