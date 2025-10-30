# Seal Apps + Seal OS Demo (ASP.NET 7)

A procedural walkthrough to demo Seal Security remediations in a .NET 7 container while showcasing an intentional insecure JSON deserialization vulnerability.

## Preparations

### One-time setup

1. Create a Seal Security tenant and a Production token
2. Add your token as a GitHub Actions Secret in this repo
   - Settings → Secrets and variables → Actions → New repository secret
   - Name: `DEMO_SEAL_TOKEN` (or your preferred name)
   - Value: your Seal Production token
3. Optional: Add `SEAL_PROJECT_ID` as a repo variable/env (project ID is generally non-secret)

### Before each demo

1. Log in to Seal and open Protection page (timeframe: Last 15 minutes)
2. Clear previous rules (if any) so the demo shows fresh results
3. Open these tabs in your browser:
   - [1 - CI](https://github.com/seal-sean-org/seal-docker-demo-app/actions/workflows/build_and_run.yml)
   - [2 - Original Dockerfile](https://github.com/seal-sean-org/seal-docker-demo-app/blob/main/original.Dockerfile)
   - [3 - Project manifest (AppDemo.csproj)](https://github.com/seal-sean-org/seal-docker-demo-app/blob/main/AppDemo.csproj)
   - [4 - Newtonsoft.Json package info](https://www.nuget.org/packages/Newtonsoft.Json)
   - [5 - Live app](https://sealdemo.ngrok.dev/)
   - [6 - Exploit payload](#exploit-payload-copy-paste)
   - [7 - Seal Platform](https://app.sealsecurity.io/)
   - [8 - Fixed Dockerfile](https://github.com/seal-sean-org/seal-docker-demo-app/blob/main/fixed.Dockerfile)

## Demo flow

1. Explain the scenario: an ASP.NET 7 Razor Pages app with an intentional insecure JSON deserialization using `Newtonsoft.Json 10.0.3` and `TypeNameHandling.Auto`.
2. In tab (1) CI, run the workflow. It will:
   - Build the image using `fixed.Dockerfile`
   - Run Seal "app" fixes in the build stage
   - Re-run `dotnet restore` to align assets with patched packages
   - Publish and run the container
   - Optionally expose via ngrok and scan with Snyk
3. For technical audiences:
   - Open tab (2) Original Dockerfile to show the baseline build
   - Open tab (3) AppDemo.csproj and point out:
     - `Newtonsoft.Json` pinned to `10.0.3` (vulnerable on purpose)
     - `System.Net.Http` referenced as `4.3.0` (Seal upgrades this to `4.3.0-sp1`)
     - `RestoreNoWarn`/`NoWarn` for `NU1605`
   - Open tab (4) NuGet and note that `Newtonsoft.Json 13.0.1+` is the secure path, but we leave 10.0.3 to demo CWE-502
4. In tab (5) the Live app, show the form. Paste the exploit from tab (6). Submit and show the result: the app instantiates `System.Diagnostics.ProcessStartInfo`, proving arbitrary type instantiation (CWE-502).
5. Back in tab (1) CI, open the build logs and point out:
   - Seal replaced `system.net.http@4.3.0` → `4.3.0-sp1` (4 CVEs remediated)
   - We re-ran `dotnet restore` after Seal so `project.assets.json` matches
   - Publish succeeded; the app started and ngrok exposed it
6. In tab (7) Seal Platform, refresh to see the project and the applied remediations.
7. Emphasize the distinction:
   - Seal patches infra/library vulnerabilities it has fixes for (here: System.Net.Http)
   - The app-level vulnerability (Newtonsoft.Json + `TypeNameHandling.Auto`) remains by design to demonstrate CWE-502 and requires a code/library change.
8. (Optional) Show tab (8) Fixed Dockerfile to highlight the minimal commands added for Seal integration.

### Exploit payload (copy/paste)

Use this in the app form (tab 5):

```json
{
  "$type": "System.Diagnostics.ProcessStartInfo, System.Diagnostics.Process",
  "FileName": "echo",
  "Arguments": "Vulnerable: TypeNameHandling.Auto allows arbitrary types!"
}
```

## Key talking points

- Seal provides secure hotfix packages (often with "-sp1" suffix) and OS remediation, applied during your Docker build
- Pre-release semantics can trigger NuGet downgrade warnings (NU1605). Fix by:
  - Referencing base versions (e.g., `4.3.0`) and letting Seal upgrade to `4.3.0-sp1`
  - Adding `<RestoreNoWarn>NU1605</RestoreNoWarn>` and re-running `restore` after `seal fix`
- Application-level vulns (like insecure deserialization) often need a library upgrade and/or code change; Seal won’t change your business logic

## Troubleshooting on stage

- Build fails with NU1605: ensure you re-run `dotnet restore` after `seal fix` and have `RestoreNoWarn` set
- Docker RUN line fails with weird MSBuild args: ensure comments are on separate lines; trailing `#` text is passed to the shell
- ngrok doesn’t come up: check that `NGROK_AUTHTOKEN` is set and the CI step isn’t gated
- No Seal results: verify `DEMO_SEAL_TOKEN` is provided as a BuildKit secret to the Docker build step

## Closing

- Show exploit still works to highlight CWE-502
- Explain the proper mitigation: upgrade to `Newtonsoft.Json 13.0.1+` and change `TypeNameHandling` to `None`
- Reinforce how Seal reduced risk by fixing infra libraries automatically without code changes
