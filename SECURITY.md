# Security Policy

This document outlines the security policies, procedures, and best practices for AGNOS (A General Networked Operating System).

## Supported Versions

Security updates are provided for the following versions:

| Version | Supported | Status |
|---------|-----------|--------|
| Latest stable | ✅ Yes | Full support |
| Previous stable | ✅ Yes | 6 months after new release |
| Beta/RC | ⚠️ Limited | Critical fixes only |
| Development | ❌ No | Use at your own risk |

## Notable Hardening — Structural Immunity

The AGNOS-native kernel is **structurally immune** to **CVE-2026-31431** (Linux LPE in `algif_aead`/AF_ALG via `splice()`, disclosed 2026-04-29). The sovereign AGNOS syscall table exposes no `socket`, no `splice`, no AF_ALG family — the bug class is unreachable. This is a durable property of the *shape* of the surface, not its size: the table has grown (26 → 34 calls) as the kernel matured and the immunity holds regardless, which is why this section anchors on the absent families rather than a count that drifts. Verified in `agnos/kernel/core/syscall.cyr`.

This is the canonical example of the **absence-by-design** security pattern: the kernel doesn't *patch* the vulnerability, doesn't *contain* the vulnerable subsystem — whole categories of Linux kernel CVEs become structurally inapplicable. Linux host defconfigs in this repo (`kernel/{6.6-lts,6.x-stable,7.0-devel}/configs/` and `kernel/configs/edge-*.config`) pin `# CONFIG_CRYPTO_USER_API{,_HASH,_SKCIPHER,_AEAD,_RNG} is not set` to remove the equivalent surface from host kernels used in the bootstrap path.

For more on the pattern, see [`docs/security/security-guide.md`](docs/security/security-guide.md).

## Security Principles

### 1. Defense in Depth

AGNOS implements multiple layers of security:

- **Kernel Level**: Landlock, seccomp-bpf, namespaces
- **System Level**: Mandatory access control, encrypted storage
- **Application Level**: Sandboxing, capability restrictions
- **Network Level**: Firewall, TLS, network namespaces
- **Audit Level**: Immutable logs, cryptographic verification
- **Structural Level**: Whole CVE classes unreachable because the syscall surface doesn't expose them (see *Notable Hardening* above)

### 2. Least Privilege

- Agents run with minimal required permissions
- Capabilities are granted per-agent, not system-wide
- Root access is restricted and audited
- Privilege escalation requires explicit authorization

### 3. Transparency

- All security-relevant events are logged
- Audit logs are cryptographically signed
- Source code is open for review
- Security decisions are documented

### 4. Human Sovereignty

- Humans retain ultimate control
- All agent actions can be audited
- Override mechanisms exist for critical operations
- No autonomous privileged operations

## Reporting Security Vulnerabilities

### Private Disclosure (Preferred)

If you discover a security vulnerability, please report it privately:

**Email**: security@agnos.io

**GPG Key**: Contact security@agnos.io for the GPG public key.

**Include in your report**:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)
- Your contact information

### Response Timeline

| Timeframe | Action |
|-----------|--------|
| 24 hours | Acknowledgment of receipt |
| 72 hours | Initial assessment |
| 1 week | Fix development begins |
| 30 days | Target fix completion |
| 90 days | Public disclosure (coordinated) |

### Public Disclosure

After the vulnerability is fixed:

1. Security advisory published
2. CVE assigned (if applicable)
3. Credit given to reporter (with permission)
4. Fix backported to supported versions

### Bug Bounty

We offer a bug bounty program for eligible vulnerabilities:

| Severity | Reward |
|----------|--------|
| Critical | $5,000 - $10,000 |
| High | $1,000 - $5,000 |
| Medium | $500 - $1,000 |
| Low | $100 - $500 |

Scope: Kernel modules, agent runtime, sandbox implementation, cryptographic systems

## Security Architecture

For the full security architecture, threat model, and technical details (sandboxing, permissions, audit logging, Aegis, Sigil, post-quantum cryptography, mTLS, zero-trust), see [docs/security/security-guide.md](docs/security/security-guide.md).

## Security Hardening Guide

### System Installation

1. **Enable Full Disk Encryption**
   ```bash
   agnos-install --encrypt --tpm
   ```

2. **Configure Secure Boot**
   ```bash
   agnos-secureboot enable
   ```

3. **Set Up Audit Logging**
   ```bash
   agnos-audit enable --remote-logging syslog.example.com
   ```

### Agent Security

1. **Create Restricted Agent**
   ```yaml
   # /agnos/agents/my-agent/config.yaml
   name: my-agent
   capabilities:
     - file.read:/home/user/documents/**
     - network.connect:api.example.com:443
   sandbox:
     landlock: enforce
     seccomp: strict
     network_isolation: true
   audit_level: verbose
   ```

2. **Verify Agent Permissions**
   ```bash
   agnos-agent verify my-agent
   ```

3. **Monitor Agent Activity**
   ```bash
   agnos-agent logs my-agent --follow
   ```

### Network Security

Default firewall rules (AGNOS uses nftables):

```bash
#!/usr/sbin/nft -f
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow established connections
        ct state established,related accept

        # Allow loopback
        iif lo accept

        # Allow specific ports for daimon (agent-runtime)
        tcp dport 8090 meta skuid "agent-runtime" accept

        # Allow specific ports for hoosh (LLM gateway)
        tcp dport 8088 meta skuid "llm-gateway" accept
    }
}
```

## Security Testing

### Automated Testing

```bash
# Boot pipeline security checks
cd scripts && ./build/boot --test --kernel /path/to/agnos

# Subsystem security tests (in respective repos)
cd /path/to/subsystem
cyrius test   # .tcyr test suites
cyrius fuzz   # .fcyr fuzz harnesses (e.g., kavach: 9 CWE fixes found via fuzz)
```

### Manual Testing

- [ ] Attempt privilege escalation
- [ ] Test sandbox escape vectors
- [ ] Verify audit log integrity
- [ ] Check network isolation
- [ ] Test human override mechanisms
- [ ] Verify encryption at rest
- [ ] Test recovery procedures

## Incident Response

### Severity Levels

| Level | Criteria | Response Time |
|-------|----------|---------------|
| Critical | RCE, privilege escalation, data breach | 1 hour |
| High | DoS, information disclosure | 4 hours |
| Medium | Security bypass, misconfiguration | 24 hours |
| Low | Documentation, hardening | 7 days |

### Response Process

1. **Detection**: Automated monitoring or user report
2. **Assessment**: Determine severity and impact
3. **Containment**: Limit damage and exposure
4. **Investigation**: Root cause analysis
5. **Remediation**: Develop and test fix
6. **Recovery**: Deploy fix and verify
7. **Post-incident**: Review and improve

### Emergency Procedures

**Agent Compromise**:
```bash
# Isolate agent
agnos-agent isolate <agent-id>

# Dump forensic data
agnos-agent forensics <agent-id> --output /tmp/forensics

# Kill agent process
agnos-agent kill <agent-id> --force

# Review audit logs
agnos-audit search --agent <agent-id> --since "1 hour ago"
```

**System Compromise**:
```bash
# Enable emergency lockdown
agnos-security lockdown

# Preserve evidence
agnos-forensics capture --full

# Contact security team
agnos-security alert --severity critical
```

## Compliance

### Standards Alignment

| Standard | Status | Notes |
|----------|--------|-------|
| CIS Benchmarks | ~85% compliant | Target Level 2 |
| NIST 800-53 | 📋 Planned | Moderate impact |
| Common Criteria | 📋 Planned | Target EAL4+ |
| FIPS 140-2 | 📋 Planned | Cryptographic modules |

### Certifications

Planned security certifications:

- **Common Criteria (EAL4+)**: Targeting government/enterprise use
- **FIPS 140-2 Level 2**: For cryptographic operations
- **CIS Benchmarks**: Hardening compliance

## Security Resources

- [Security Guide](docs/security/security-guide.md)
- [Penetration Testing](docs/security/penetration-testing.md)
- [Security Checklist](docs/security/security-checklist.md)
- [Vulnerability Management](docs/security/vulnerability-management.md)
- [CIS Benchmarks](docs/security/cis-benchmarks.md)

## Contact

- **Security Team**: security@agnos.io
- **GPG Key**: Contact security@agnos.io for the GPG public key
- **Bug Bounty**: [bugcrowd.com/agnos](https://bugcrowd.com/agnos)
- **Security Advisories**: [agnos.io/security/advisories](https://agnos.io/security/advisories)

## Acknowledgments

We thank the security researchers who have responsibly disclosed vulnerabilities:

- *No disclosures yet - be the first!*

---

**Last Updated**: 2026-05-09
**Version**: 2026.5.9
**Next Review**: 2026-08-09
