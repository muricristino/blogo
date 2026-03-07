# syntax=docker/dockerfile:1

# --- STAGE 1: Development ---
FROM golang:1.19-bullseye AS development

WORKDIR /app

RUN apt-get update && apt-get install -y curl

COPY go.mod go.sum ./
RUN go mod download
COPY . .

CMD ["go", "run", "main.go"]

# --- STAGE 2: Build ---
FROM development AS builder
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/app .

# --- STAGE 3: Production ---
FROM gcr.io/distroless/base-debian11 AS production
WORKDIR /
COPY --from=builder /app/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]