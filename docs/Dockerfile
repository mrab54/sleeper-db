FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod serve.go ./
RUN go build -o docs-server serve.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /docs

COPY --from=builder /app/docs-server /usr/local/bin/
COPY sleeper-api-swagger.yaml sleeper-api-swagger.html ./

EXPOSE 8080

CMD ["docs-server"]