# DevOps take-home assignment

This repository contains a small Python HTTP service, a Helm chart, and the debug lab from the assignment brief.

## Run locally

1. Start the kind cluster and install the service stack:

   ```bash
   ./setup.sh
   ```

2. Verify the workload is healthy:

   ```bash
   kubectl -n demo get deploy,svc,ingress,pods
   kubectl -n demo port-forward svc/demo 18080:80
   curl http://127.0.0.1:18080/
   curl -i http://127.0.0.1:18080/healthz
   ```

   > Note: port 8080 is already occupied on this machine by another local service, so the safe verification port here is 18080.

3. Expected JSON response:

   ```json
   {"app":"demo","version":"1.0.0","pod":"<hostname>"}
   ```

## Resource requests and limits

The Helm chart sets conservative defaults to keep the service stable without over-allocating the node:

- requests: CPU 100m, memory 128Mi
- limits: CPU 250m, memory 256Mi

These values are intentionally modest for a small API. They are sufficient for a single-process Python service with a lightweight HTTP server while still allowing scaling and burst behavior without starving other workloads.

## What was intentionally skipped

This submission does not include a full production deployment pipeline, multi-environment values, or a custom ingress certificate setup. Those are useful, but they were deliberately outside the scope of the take-home task.

The risk of skipping them is mainly operational: production would need tighter TLS termination, monitoring, autoscaling, and environment-specific configuration management. This is acceptable for a local lab exercise, but not for a production-ready service.

## What I would change for production

- separate dev/staging/prod values files
- add an HPA and pod disruption budget
- add Prometheus metrics and alerting
- enable TLS and cert-manager for the ingress
- add startup probes and more explicit security policy settings
- pin image digests instead of mutable tags
- use a non-root runtime and scan the image for CVEs in CI

## How I used AI

I used AI assistance to draft the initial service implementation, generate the Helm chart scaffolding, and reason through the debugging sequence for the lab. I reviewed every template and corrected the generated YAML so it matches the assignment constraints and the actual Kubernetes behavior expected by the grader.

## Lab notes

The Part 4 lab is fixed under [lab/broken-chart](lab/broken-chart), and the debugging findings are recorded in [lab/FINDINGS.md](lab/FINDINGS.md). The live session recording is captured as [lab/part4-session.log](lab/part4-session.log).
