# syntax=docker/dockerfile:1

# --- STAGE 1: Development ---
FROM golang:1.22-bookworm AS development

WORKDIR /app

RUN apt-get update && apt-get install -y curl
RUN go install github.com/air-verse/air@v1.52.3

COPY go.mod go.sum ./
RUN go mod download
COPY . .

CMD ["air"]

# --- STAGE 2: Build ---
FROM development AS builder
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/app .

# --- STAGE 3: Production ---
FROM gcr.io/distroless/base-debian11 AS production
WORKDIR /
COPY --from=builder /app/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]