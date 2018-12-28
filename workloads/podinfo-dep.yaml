---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: demo
  labels:
    app: podinfo
  annotations:
    flux.weave.works/automated: "true"
    flux.weave.works/tag.init: regexp:^3.*
    flux.weave.works/tag.podinfod: semver:~1.3
spec:
  strategy:
    rollingUpdate:
      maxUnavailable: 0
    type: RollingUpdate
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
      labels:
        app: podinfo
    spec:
      initContainers:
      - name: init
        image: alpine:3.5
        command:
        - sleep
        - "1"
      containers:
      - name: podinfod
        image: stefanprodan/podinfo:1.3.2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9898
          name: http
          protocol: TCP
        command:
        - ./podinfo
        - --port=9898
        - --level=info
        - --random-delay=false
        - --random-error=false
        env:
        - name: PODINFO_UI_COLOR
          value: green
        livenessProbe:
          httpGet:
            path: /healthz
            port: 9898
        readinessProbe:
          httpGet:
            path: /readyz
            port: 9898
        resources:
          limits:
            cpu: 1000m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi
