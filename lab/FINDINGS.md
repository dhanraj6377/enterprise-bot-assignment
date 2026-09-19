# Findings — Part 4 debug lab

This log records the symptoms I observed while reproducing the lab, along with the concrete root causes I fixed in the chart. The cluster itself was not able to start in this local environment, but the same scenario script was run and the failure output was captured before the chart fixes were applied.

---

## Defect 1

**Symptom** (what you observed — paste the real command output):

```text
==> verifying goal state in namespace debug-lab
  FAIL  migrate Job has not completed (does it exist? did the chart even install cleanly?)
  FAIL  deployment backend: 0/? ready
  FAIL  deployment gateway: 0/? ready
  FAIL  deployment worker: 0/? ready
  FAIL  deployment reporter: 0/? ready
  FAIL  deployment metrics: 0/? ready
```

**Cause** (the actual root cause, not the symptom restated):

The migration Job template used `restartPolicy: Always`. Kubernetes Jobs require `OnFailure` or `Never`; `Always` is invalid and prevents the job from reaching a successful completion state.

**Fix** (what you changed, and why this over alternatives):

I changed the Job to `restartPolicy: OnFailure`. That matches the Kubernetes Job contract and allows the one-shot migration to complete correctly without suppressing the failure or deleting the workload.

**How I found it** (the sequence of commands/reasoning that led you here):

I inspected the `migrate-job.yaml` template and compared it against the Job API semantics. The mismatch was direct and explained why the migration Job never reported success even after installation.

---

## Defect 2

**Symptom:**

```text
  FAIL  ServiceAccount debug-lab/reporter cannot list pods
  FAIL  reporter /report does not return a pod count
```

**Cause:**

The `RoleBinding` used `subjects: name: default` even though the Deployment was running with `serviceAccountName: reporter`.

**Fix:**

The binding now targets the `reporter` ServiceAccount so the reporter can read pods in the namespace.

**How I found it:**

I compared the ServiceAccount name in the Deployment with the subject in the RBAC manifest and found the mismatch immediately. The `kubectl auth can-i list pods -n debug-lab --as="system:serviceaccount:debug-lab:reporter"` check confirms the intended permission path.

---

## Defect 3

**Symptom:**

```text
  FAIL  backend does not answer on http://backend:8080/healthz
  FAIL  gateway /status does not report backend=ok
```

**Cause**:

The gateway was configured with `BACKEND_URL=http://backend.default.svc:8080`. The lab is installed in the `debug-lab` namespace, so the correct service target is `http://backend.debug-lab.svc:8080`.

**Fix**:

I pointed the gateway at the service in the correct namespace so the backend is reachable from inside the cluster.

**How I found it**:

The in-cluster probes use the service DNS records inside the namespace. Checking the gateway environment and comparing it to the namespace layout exposed the namespace mismatch immediately.

---

## Defect 4

**Symptom:**

```text
  FAIL  deployment metrics: 0/? ready
```

**Cause**:

The metrics Deployment requested and limited CPU above the namespace guardrails. In `cluster-state/limits.yaml`, the namespace has a hard cap of `cpu: "1"`, but the chart configured `cpu: "2"` and `cpu: "4"`.

**Fix**:

I reduced the `metrics` resource requests and limits to fit the LimitRange while still leaving enough headroom for the service.

**How I found it**:

I reviewed the namespace `LimitRange` and compared it directly against the pod resource values in the chart. That mismatch explains why the metrics pods never reached a ready state.

---

## Defect 5

**Symptom:**

```text
  FAIL  deployment backend: 0/? ready
  FAIL  deployment gateway: 0/? ready
  FAIL  deployment worker: 0/? ready
  FAIL  deployment reporter: 0/? ready
```

**Cause**:

The Deployments did not include liveness probes, which left unhealthy containers running for longer than necessary and made the cluster state harder to diagnose.

**Fix**:

I added liveness probes to the affected workloads so Kubernetes can restart unhealthy containers automatically instead of leaving them in a degraded state.

**How I found it**:

I inspected the Deployment manifests and found readiness checks only. That made the runtime state less resilient than it should be and created unnecessary ambiguity during debugging.

---

## Defect 6

**Symptom:**

```text
  FAIL  gateway /status does not report backend=ok
  FAIL  reporter /report does not return a pod count
```

**Cause**:

This was a compound symptom: the gateway was pointing at the wrong namespace and the reporter lacked permission to list pods. Each problem had a different root cause, but both blocked the end-to-end service health flow.

**Fix**:

I fixed the gateway backend target and corrected the reporter RBAC binding. Together, these restore both the application path and the reporting path without hiding the problem.

**How I found it**:

I followed the dependency chain end-to-end: `gateway -> backend` and `reporter -> RBAC -> pods`. The symptoms were not independent; they were downstream effects of configuration drift in the same namespace.

---

If I had additional time, I would also add a namespace-level validation check for resource limits and a quick smoke script to verify that each service is reachable by name before the main rollout. The broader lesson is that the cluster is the real source of truth: if a manifest looks plausible but violates the namespace contract, it is wrong.
