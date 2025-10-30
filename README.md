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
├── original.Dockerfile        # Vulnerable Docker build (for comparison)
├── fixed.Dockerfile          # Seal Security integrated build (production-ready)
├── .seal-actions.yml         # Seal configuration for vulnerability remediation
└── .github/workflows/
    └── build_and_run.yml     # CI/CD pipeline with Snyk security scanning
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

### Vulnerable Build (Baseline Comparison)
```bash
docker build -f original.Dockerfile -t seal-demo:vulnerable .
docker run -p 8080:80 seal-demo:vulnerable
```

### Seal-Secured Build (Production Ready)
```bash
# Requires SEAL_TOKEN environment variable
docker build -f fixed.Dockerfile -t seal-demo:secure \
  --secret id=SEAL_TOKEN,src=<(echo $SEAL_TOKEN) .
docker run -p 8080:80 seal-demo:secure
```

Visit http://localhost:8080 to test the application.

## Seal Security Integration

The `fixed.Dockerfile` integrates Seal Security CLI to automatically:

1. **Detect vulnerabilities** in application dependencies and OS packages
2. **Download patched versions** of vulnerable packages (e.g., Newtonsoft.Json 10.0.3-sp1)
3. **Apply OS security updates** to base image
4. **Upload scan results** to Seal Security platform

### Configuration (.seal-actions.yml)

```yaml
projects:
  seal-docker-demo-app:
    targets:
      - AppDemo.csproj
    manager:
      ecosystem: nuget
    overrides:
      Newtonsoft.Json:
        "10.0.3":
          use: "10.0.3-sp1"           # Seal's patched version  
          reason: "Fixes CVE-2024-21907"
          
settings:
  prefer_sealed_packages: true       # Use Seal patches over upgrades
  upload_results: true              # Track fixes in Seal platform
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build_and_run.yml`) automates:

1. **Build**: Creates Seal-secured Docker image with vulnerability fixes
2. **Deploy**: Runs the application container for testing
3. **Scan**: Performs comprehensive security analysis with Snyk
4. **Report**: Generates detailed vulnerability reports and artifacts

### Workflow Triggers

- **Push/PR**: Automatic security validation on code changes
- **Manual**: On-demand execution via GitHub UI with custom parameters

```bash
# Manual trigger with custom fix modes
gh workflow run "Seal Security ASP.NET Demo" \
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

# Container security scanning
docker build -f fixed.Dockerfile -t secure-image .
snyk container test secure-image \
  --severity-threshold=medium \
  --file=fixed.Dockerfile
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

## 🌐 Live Vulnerability Demo

To demonstrate the vulnerability in action, the workflow can expose the application via ngrok:

### Setup ngrok (Optional):
1. Get ngrok auth token from https://ngrok.com
2. Add `NGROK_AUTHTOKEN` secret to your repository
3. Optionally add `NGROK_DOMAIN` for custom URL

### Demo Flow:
1. Run the GitHub Actions workflow
2. Get the live URL from the job summary
3. Test the vulnerability by entering malicious JSON:
   ```json
   { "$type": "System.Version, System.Private.CoreLib", "Major": 1, "Minor": 2 }
   ```
4. See how the app unsafely deserializes the input!

## 🔐 Required GitHub Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `DEMO_SEAL_TOKEN` | ✅ | Seal Security API token |
| `SNYK_TOKEN` | ✅ | Snyk API token |
| `SNYK_ORG` | ⚪ | Snyk organization (optional) |
| `SEAL_PROJECT_ID` | ⚪ | Custom project ID (optional) |
| `NGROK_AUTHTOKEN` | ⚪ | For live demo (optional) |
| `NGROK_DOMAIN` | ⚪ | Custom ngrok domain (optional) |

## Resources

- [Microsoft Security Advisory - CA2326](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2326)
- [Newtonsoft.Json Security Advisory](https://github.com/advisories/GHSA-5crp-9r3c-p9vr)
- [Seal Security Platform](https://seal.security)
- [OWASP Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)