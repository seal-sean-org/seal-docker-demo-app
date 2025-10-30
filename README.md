# Seal Security ASP.NET Deserialization Demo Project

This demo is a minimal ASP.NET 7 web application (Razor Pages) that intentionally uses an insecure JSON deserialization pattern. It includes a vulnerable version of Newtonsoft.Json 10.0.3 configured with an unsafe setting (TypeNameHandling.Auto).

## 🚨 Security Vulnerabilities (Intentional)

This project contains **intentional security vulnerabilities** for demonstration purposes:

1. **Insecure Deserialization (CWE-502)**: Uses `TypeNameHandling.Auto` which allows JSON `$type` field to control object instantiation
2. **Vulnerable Dependency (CVE-2024-21907)**: Uses Newtonsoft.Json 10.0.3 which has a known high-severity stack overflow vulnerability

## Project Structure

```
.
├── AppDemo.csproj              # .NET 7 project with vulnerable Newtonsoft.Json 10.0.3
├── Program.cs                  # Minimal ASP.NET setup
├── Pages/
│   ├── Index.cshtml           # Razor page with JSON input form
│   └── Index.cshtml.cs        # Code-behind with insecure deserialization
├── original.Dockerfile        # Vulnerable Docker build
├── fixed.Dockerfile          # Seal Security integrated build
├── .seal-actions.yml         # Seal configuration for remediation
├── .github/workflows/
│   └── build_and_run.yml     # CI/CD pipeline with vulnerability scanning
└── .grype/templates/
    └── md.tmpl               # Vulnerability report template
```

## Vulnerability Demonstration

The web application presents a form where users can input JSON. When submitted, the app deserializes the JSON using unsafe settings:

```csharp
// UNSAFE: TypeNameHandling.Auto allows $type control
var settings = new JsonSerializerSettings { TypeNameHandling = TypeNameHandling.Auto };
object? obj = JsonConvert.DeserializeObject(JsonInput, settings);
```

### Example Exploit

Try entering this JSON to see how `$type` controls object instantiation:

```json
{ "$type": "System.Version, System.Private.CoreLib", "Major": 1, "Minor": 2, "Build": 3, "Revision": 4 }
```

This will create a `System.Version` object instead of the expected type, demonstrating the vulnerability.

## Docker Builds

### Vulnerable Build (original.Dockerfile)
```bash
docker build -f original.Dockerfile -t seal-demo:vulnerable .
docker run -p 80:80 seal-demo:vulnerable
```

### Remediated Build (fixed.Dockerfile)
Requires Seal Security token:
```bash
docker build -f fixed.Dockerfile -t seal-demo:fixed \
  --secret id=SEAL_TOKEN,src=<(echo $SEAL_TOKEN) .
docker run -p 80:80 seal-demo:fixed
```

## Seal Security Integration

The `fixed.Dockerfile` integrates Seal Security CLI to automatically:

1. **Detect vulnerabilities** in application dependencies and OS packages
2. **Download patched versions** of vulnerable packages (e.g., Newtonsoft.Json 10.0.3-sp1)
3. **Apply OS security updates** to base image
4. **Upload scan results** to Seal Security platform

### Configuration (.seal-actions.yml)

```yaml
projects:
  app-demo:
    targets:
      - AppDemo.csproj
    manager:
      ecosystem: nuget
      name: nuget
    overrides:
      Newtonsoft.Json:
        "10.0.3":
          use: "10.0.3-sp1"  # Seal's patched version
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build_and_run.yml`) automates:

1. Building both vulnerable and remediated images
2. Running container vulnerability scans with Snyk
3. Generating security reports and artifacts
4. Demonstrating before/after security posture

### Trigger the Workflow

```bash
# Manual trigger via GitHub UI or:
gh workflow run "Build and Scan .NET demo" \
  --field app_fix_mode=all \
  --field os_fix_mode=all
```

## Security Scan Results

Based on Snyk Code analysis, the project contains:

### Static Analysis Security Testing (SAST)
- **2 Deserialization vulnerabilities detected**
- **Severity**: Medium to High
- **CWE-502**: Deserialization of Untrusted Data
- **Location**: `Pages/Index.cshtml.cs` lines 18-19

### Software Composition Analysis (SCA)
- **Newtonsoft.Json 10.0.3**: Known vulnerable dependency
- **CVE-2024-21907**: Stack overflow leading to DoS
- **Severity**: High
- **Fixed in**: Newtonsoft.Json 13.0.1+

## Remediation

### For Deserialization Vulnerability
Replace unsafe deserialization settings:
```csharp
// SAFE: Use TypeNameHandling.None (default)
var settings = new JsonSerializerSettings { TypeNameHandling = TypeNameHandling.None };
// Or use System.Text.Json instead of Newtonsoft.Json
```

### For Vulnerable Dependencies
Seal Security automatically remediates by:
- Replacing Newtonsoft.Json 10.0.3 with patched version 10.0.3-sp1
- Or upgrading to safe version 13.0.1+

## Development Setup

### Prerequisites
- .NET 7 SDK
- Docker
- Seal Security CLI (for remediation)

### Local Development
```bash
# Restore dependencies
dotnet restore

# Run the application
dotnet run

# Build for release
dotnet publish -c Release
```

### Security Testing
```bash
# Scan for SAST issues
snyk code test

# Scan for dependency vulnerabilities  
snyk test

# Container scanning
docker build -t test-image .
snyk container test test-image --severity-threshold=medium
```

## Educational Value

This demo illustrates:

1. **Common .NET Security Pitfalls**: Unsafe JSON deserialization patterns
2. **Supply Chain Security**: Impact of vulnerable dependencies
3. **Automated Remediation**: How Seal Security addresses both issues
4. **DevSecOps Integration**: Security scanning in CI/CD pipelines
5. **Vulnerability Management**: Before/after security posture comparison

## ⚠️ Important Security Notice

**This project contains intentional vulnerabilities and should never be deployed in production.** It is designed solely for educational and demonstration purposes to showcase security vulnerabilities and remediation techniques.

## Resources

- [Microsoft Security Advisory - CA2326](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2326)
- [Newtonsoft.Json Security Advisory](https://github.com/advisories/GHSA-5crp-9r3c-p9vr)
- [Seal Security Platform](https://seal.security)
- [OWASP Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)