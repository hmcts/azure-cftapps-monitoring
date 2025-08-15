FROM golang:1.25 AS builder

WORKDIR /build
COPY go.mod go.sum /build/
RUN go mod download

COPY . /build
ENV CGO_ENABLED=0
RUN go build -v
RUN groupadd -g 1000 user && \
    useradd -r -u 1000 -g user user
RUN pwd
RUN ls

FROM scratch
COPY --from=builder /etc/passwd /etc/passwd
USER user
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /build/azure-cftapps-monitoring /app
ENTRYPOINT ["/app"]