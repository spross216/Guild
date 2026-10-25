# Acme engineering standards

- Every change MUST pass `Test-AcmeProject` before review.
- Business logic MUST be separate from transport code and unit-tested without the network.
- Secrets MUST live in the secret store; never in source, configuration files or logs.
- Errors SHOULD say what failed and what to do, without leaking internals.
- Anything that can run twice MUST be safe to run twice.
