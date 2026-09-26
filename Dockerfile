# Build stage
FROM golang:1.27.1-alpine AS builder

RUN apk add --no-cache ca-certificates

WORKDIR /build

COPY go.mod go.sum* ./
RUN go mod download 2>/dev/null || true

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -X main.version=1.0.0 -extldflags "-static"' \
    -a -installsuffix cgo \
    -o debian-repo-upload-action .

# Final stage
FROM alpine:3.24

RUN apk add --no-cache ca-certificates

RUN adduser -D -g '' appuser

COPY --from=builder /build/debian-repo-upload-action /debian-repo-upload-action

USER appuser

ENTRYPOINT ["/debian-repo-upload-action"]
