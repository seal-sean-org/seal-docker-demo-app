# Seal Security: Implementation Notes and FAQ

A concise guide to integrating Seal Security CLI into containerized .NET builds. Focused on practical gotchas, fixes, and patterns that work reliably in CI.

## What Seal does (in this demo)
- Remediates vulnerable dependencies at build time by replacing them with sealed packages (for example, System.Net.Http 4.3.0 → 4.3.0-sp1).
- Applies OS-level security updates in the runtime image.
- Uploads scan results to the Seal platform when configured.

Note: Sealed packages often carry a pre-release suffix (like "-sp1"). They are secure hotfixes, not upstream version upgrades.

## Minimal Dockerfile pattern that works

Use this 4-step flow to keep dependency assets consistent:

```dockerfile
# Stage: build
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Copy project first to leverage layer caching
COPY AppDemo.csproj .
RUN dotnet restore AppDemo.csproj

# Add Seal CLI (pin a version for reproducibility when possible)
ADD --chmod=755 https://github.com/seal-community/cli/releases/download/latest/seal-linux-amd64-latest /usr/local/bin/seal

# Copy the rest of the sources
COPY . .

# Apply app-level fixes using BuildKit secret for the token
# SEAL_TOKEN is provided via:  docker build --secret id=SEAL_TOKEN,src=/path/to/token
RUN --mount=type=secret,id=SEAL_TOKEN,env=SEAL_TOKEN \
    SEAL_PROJECT=${SEAL_PROJECT_ID} \
    /usr/local/bin/seal fix --mode=all --upload-scan-results \
  && rm -f /usr/local/bin/seal

# Re-run restore so project.assets.json reflects sealed packages
RUN dotnet restore AppDemo.csproj

# Publish with patched dependencies
RUN dotnet publish AppDemo.csproj -c Release -o /app/publish

# Stage: runtime (optionally apply OS fixes with Seal)
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS runtime
WORKDIR /app

# Optionally download Seal again for OS-level fixes
ADD --chmod=755 https://github.com/seal-community/cli/releases/download/latest/seal-linux-amd64-latest /usr/local/bin/seal

# Apply OS remediations (if desired)
RUN --mount=type=secret,id=SEAL_TOKEN,env=SEAL_TOKEN \
    /usr/local/bin/seal fix --mode=all || true \
  && rm -f /usr/local/bin/seal

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "AppDemo.dll"]
```

Key points:
- Do an initial `dotnet restore`, then run `seal fix`, then restore again, then publish.
- Avoid comments at the end of RUN lines; trailing `#` text is passed to the shell.
- Provide SEAL_TOKEN via BuildKit secrets; do not bake it into the image.

## Common NuGet gotchas (and fixes)

1) NU1605: Detected package downgrade (for example, 4.3.0 → 4.3.0-sp1)
- Cause: Sealed packages use a pre-release suffix; NuGet may treat 4.3.0-sp1 as lower precedence than 4.3.0.
- Fixes:
  - Prefer referencing the non-sealed version in the project (for example, `System.Net.Http` 4.3.0) and let Seal upgrade it.
  - Add restore-time suppression in your project file:
    ```xml
    <PropertyGroup>
      <RestoreNoWarn>$(RestoreNoWarn);NU1605</RestoreNoWarn>
      <NoWarn>$(NoWarn);NU1605</NoWarn>
    </PropertyGroup>
    ```
  - Re-run `dotnet restore` after `seal fix` to regenerate project.assets.json.

2) NU1603: Package not found when referencing `-sp1` directly
- Cause: Referencing a sealed package version (for example, 4.3.0-sp1) before Seal has provided it can fail during `dotnet restore`.
- Fix: Reference the base version (for example, 4.3.0) and allow Seal to supply the sealed variant.

3) WarningsNotAsErrors does not affect NuGet restore warnings
- `WarningsNotAsErrors` only affects compiler/MSBuild warnings. Use `RestoreNoWarn` for restore-time warnings.

4) `--no-restore` after Seal fixes can cause mismatches
- If you skip restore after Seal, `project.assets.json` may not match what is on disk. Re-run restore after `seal fix`.

## Secrets and environment

- Pass the Seal token as a BuildKit secret:
  - Docker CLI:
    ```bash
    docker build -f fixed.Dockerfile -t myapp:secure \
      --secret id=SEAL_TOKEN,src=<(echo "$SEAL_TOKEN") .
    ```
- `SEAL_PROJECT_ID` can be a build-arg or env var. Treat the token as a secret; project ID can typically be non-secret.
- If your build runs behind a proxy, set `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` for both build and runtime stages.

## CI/CD notes

- Use Docker BuildKit for secrets and caching.
- Re-run restore after Seal inside the same build stage to keep the dependency graph consistent.
- Consider pinning a specific Seal CLI release tag instead of `latest` for reproducibility.
- If you scan with additional tools (for example, Snyk), avoid hard-failing the job on findings unless required.

## FAQ

Q: Why does NU1605 appear right after Seal patches a package?
A: Because the sealed package (for example, 4.3.0-sp1) is considered pre-release and may be treated as lower precedence than 4.3.0. Re-run restore and/or add `RestoreNoWarn`.

Q: Can I reference the sealed package (`-sp1`) directly in the project?
A: You can, but it may fail at restore time (NU1603) unless the sealed package is resolvable. Prefer referencing the base version and let Seal replace it.

Q: Do I have to change my application code?
A: For infrastructure libraries (for example, System.Net.Http) usually not. For application-level vulnerabilities (for example, insecure Newtonsoft.Json settings), code changes or library upgrades may be required.

Q: What `--mode` should I use for `seal fix`?
A: `--mode=all` is commonly used in demos and CI. Always check `seal fix --help` for the latest options.

Q: Is `-sp1` a downgrade?
A: No. It is a secure hotfix build. NuGet may label it as pre-release; use `RestoreNoWarn` to avoid restore-time downgrade errors.

## Troubleshooting checklist

- Verify the build order: restore → seal fix → restore → publish.
- Ensure no trailing comments remain on RUN commands.
- Confirm that the token is passed via BuildKit secret and not baked into an image layer.
- Re-run restore after Seal to synchronize `project.assets.json`.
- Suppress NU1605 at restore time using `RestoreNoWarn` when needed.
- If network-restricted, set proxy variables for both stages.
