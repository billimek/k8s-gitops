FROM golang:1.10 as builder

ARG VERSION=unknown
ARG GITCOMMIT=unknown

RUN mkdir -p /go/src/github.com/stefanprodan/k8s-podinfo/

WORKDIR /go/src/github.com/stefanprodan/k8s-podinfo

ADD https://github.com/stefanprodan/k8s-podinfo/archive/v0.4.0.tar.gz .

RUN tar xzf v0.4.0.tar.gz --strip 1

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags "-s -w \
  -X github.com/stefanprodan/k8s-podinfo/pkg/version.GITCOMMIT=${GITCOMMIT} \
  -X github.com/stefanprodan/k8s-podinfo/pkg/version.VERSION=${VERSION}" \
  -a -installsuffix cgo -o podinfo ./cmd/podinfo

FROM alpine:3.7

RUN addgroup -S app \
    && adduser -S -g app app

WORKDIR /home/app

COPY --from=builder /go/src/github.com/stefanprodan/k8s-podinfo/podinfo .

RUN chown -R app:app ./

USER app

CMD ["./podinfo"]
