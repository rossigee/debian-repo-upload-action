BINARY_NAME=debian-repo-upload-action
IMAGE_NAME=rossigee/debian-repo-upload-action

VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
FULL_IMAGE_NAME=${IMAGE_NAME}:${VERSION}

all: build

build:
	go build -ldflags "-X main.version=${VERSION}" -o ${BINARY_NAME} .

run: build
	./${BINARY_NAME}

test:
	go test -v ./...

lint:
	golangci-lint run

fmt:
	go fmt ./...
	gofmt -s -w .

sec:
	gosec ./...

image:
	docker build -t ${FULL_IMAGE_NAME} .
	docker tag ${FULL_IMAGE_NAME} ${IMAGE_NAME}:latest

push:
	docker push ${FULL_IMAGE_NAME}
	docker push ${IMAGE_NAME}:latest

clean:
	go clean
	rm -f ${BINARY_NAME}

dev-deps:
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.9.0
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest

version:
	@echo ${VERSION}

.PHONY: all build run test lint fmt sec clean image push dev-deps version
