# Seal Security ASP.NET Demo

A minimal ASP.NET 7 application demonstrating Seal Security's automated vulnerability remediation in Docker builds.

## 🎯 What This Demo Shows

**Live Demo:** https://sealdemo.ngrok.dev/

This project demonstrates:
- ✅ **Seal Security patches working** - Automatically remediates infrastructure CVEs (System.Net.Http)
- ⚠️ **Application vulnerabilities** - Shows Newtonsoft.Json deserialization exploit (requires code changes)
- 🐳 **Docker integration** - Multi-stage builds with Seal CLI
- 🔄 **CI/CD automation** - GitHub Actions with Snyk scanning

## 🔓 Intentional Vulnerabilities

### 1. Infrastructure Vulnerability (PATCHED BY SEAL)
- **Package:** System.Net.Http 4.3.0
- **Fix:** Seal upgrades to 4.3.0-sp1
- **CVEs Fixed:** CVE-2018-8292, CVE-2017-0247, CVE-2017-0248, CVE-2017-0249

### 2. Application Vulnerability (DEMO PURPOSES - STILL EXPLOITABLE)
- **Package:** Newtonsoft.Json 10.0.3
- **Issue:** Insecure deserialization (CWE-502) with `TypeNameHandling.Auto`
- **CVE:** CVE-2024-21907
- **Why Not Patched:** Requires upgrade to 13.0.1+ and code changes (breaking change)

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

## 🧪 Try the Exploit

Visit **https://sealdemo.ngrok.dev/** and paste this JSON:

```json
{
  "$type": "System.Diagnostics.ProcessStartInfo, System.Diagnostics.Process",
  "FileName": "echo",
  "Arguments": "Vulnerable: TypeNameHandling.Auto allows arbitrary types!"
}
```

**Result:** The app instantiates `ProcessStartInfo` - proving arbitrary type instantiation is possible.

**Why This Matters:** An attacker could execute commands, read files, or take over the server.

### The Vulnerable Code

```csharp
// UNSAFE: TypeNameHandling.Auto allows $type control
var settings = new JsonSerializerSettings { TypeNameHandling = TypeNameHandling.Auto };
object? obj = JsonConvert.DeserializeObject(JsonInput, settings);
```

## 🐳 Local Testing

### Build Without Seal (Vulnerable Baseline)
```bash
docker build -f original.Dockerfile -t seal-demo:vulnerable .
docker run -p 8080:80 seal-demo:vulnerable
```

### Build With Seal (Patched Infrastructure)
```bash
export SEAL_TOKEN="your-seal-token"
docker build -f fixed.Dockerfile -t seal-demo:secure \
  --secret id=SEAL_TOKEN,src=<(echo $SEAL_TOKEN) .
docker run -p 8080:80 seal-demo:secure
```

**Note:** Both builds show the Newtonsoft.Json vulnerability - Seal patches System.Net.Http only.

## 🛡️ Seal Security Integration

The `fixed.Dockerfile` integrates Seal CLI to automatically remediate vulnerabilities:

**What Seal Fixed:**
- ✅ System.Net.Http 4.3.0 → 4.3.0-sp1 (4 CVEs remediated)
- ✅ OS package updates in runtime image
- ✅ Scan results uploaded to Seal platform

**What Seal Didn't Fix (Intentionally):**
- ⚠️ Newtonsoft.Json 10.0.3 remains vulnerable for demo purposes
- ⚠️ TypeNameHandling.Auto code pattern requires manual fix

### Build Process

```dockerfile
# 1. Restore dependencies
RUN dotnet restore AppDemo.csproj

# 2. Seal patches vulnerable packages
RUN seal fix --mode=all --upload-scan-results

# 3. Re-restore to update project.assets.json
RUN dotnet restore AppDemo.csproj

# 4. Publish with patched dependencies
RUN dotnet publish AppDemo.csproj -c Release -o /app/publish
```

## 🔄 CI/CD Pipeline

The GitHub Actions workflow automates:

1. 🏗️ **Build** - Docker image with Seal CLI integration
2. 🚀 **Deploy** - Runs container for testing
3. 🌐 **Expose** - Creates ngrok tunnel (optional)
4. 🔍 **Scan** - Snyk container security analysis
5. 📊 **Report** - Uploads scan results as artifacts

**Trigger:** Automatic on push, or manual via GitHub UI

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

## Important Security Notice

**This project contains intentional vulnerabilities and should never be deployed in production.** It is designed solely for educational and demonstration purposes to showcase security vulnerabilities and remediation techniques.

## Live Vulnerability Demo

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
| `DEMO_SEAL_TOKEN` | Yes | Seal Security API token |
| `SNYK_TOKEN` | Yes | Snyk API token |
| `SNYK_ORG` | Optional | Snyk organization (optional) |
| `SEAL_PROJECT_ID` | Optional | Custom project ID (optional) |
| `NGROK_AUTHTOKEN` | Optional | For live demo (optional) |
| `NGROK_DOMAIN` | Optional | Custom ngrok domain (optional) |

## Resources

- [Microsoft Security Advisory - CA2326](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2326)
- [Newtonsoft.Json Security Advisory](https://github.com/advisories/GHSA-5crp-9r3c-p9vr)
- [Seal Security Platform](https://seal.security)
- [OWASP Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)
- [Seal Integration Guide for .NET + Docker](./SEAL-Integration-Guide.md)