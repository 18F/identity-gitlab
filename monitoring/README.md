# Monitoring

This is intended to be run as a scheduled pipeline every 10 minutes from within
GitLab. A corresponding CloudWatch alarm alerts if the job stops sending data.

Example `.gitlab-ci.yml` snippet:

```
write_metrics:
  image: golang:latest
  script:
    - cd monitoring
    - go run metrics.go --cluster=$CLUSTER_NAME
```
