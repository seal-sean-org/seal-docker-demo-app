# ==========================================
# Seal Security Remediated ASP.NET Demo
# Automatically fixes vulnerabilities at build time
# ==========================================

# Build stage with Seal application remediation
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Establish restore cache by copying project file first and performing initial restore
COPY AppDemo.csproj .
RUN dotnet restore AppDemo.csproj

# Bring in the rest of the source
COPY . .

# Configure Seal Security (application remediation)
ARG SEAL_APP_FIX_MODE=all
ARG SEAL_PROJECT_ID=seal-docker-demo-app
ENV SEAL_USE_SEALED_NAMES=true

# Download Seal CLI
ADD --chmod=755 \
        https://github.com/seal-community/cli/releases/download/latest/seal-linux-amd64-latest \
        /usr/local/bin/seal

    # Apply application-level fixes AFTER initial restore so package manager output is available
RUN --mount=type=secret,id=SEAL_TOKEN,env=SEAL_TOKEN \
        SEAL_PROJECT=${SEAL_PROJECT_ID} \
        /usr/local/bin/seal fix \
            --mode=${SEAL_APP_FIX_MODE} \
            --upload-scan-results \
    && rm -f /usr/local/bin/seal

    # Re-run restore after Seal modifies packages to regenerate consistent project.assets.json
    # Then publish with the Seal-patched dependencies
    RUN dotnet restore AppDemo.csproj \
        && dotnet publish AppDemo.csproj -c Release -o /app/publish    # Runtime stage with Seal Security integration
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS runtime
WORKDIR /app

# Copy published application
COPY --from=build /app/publish .

# Configure Seal Security (OS remediation at runtime stage)
ARG SEAL_OS_FIX_MODE=all  
ARG SEAL_PROJECT_ID=seal-docker-demo-app
ENV SEAL_USE_SEALED_NAMES=true

# Download Seal CLI
ADD --chmod=755 \
    https://github.com/seal-community/cli/releases/download/latest/seal-linux-amd64-latest \
    /usr/local/bin/seal

# Apply OS-level fixes for the runtime base
RUN --mount=type=secret,id=SEAL_TOKEN,env=SEAL_TOKEN \
    SEAL_PROJECT=${SEAL_PROJECT_ID}-os \
    /usr/local/bin/seal fix os \
      --mode=${SEAL_OS_FIX_MODE} \
      --upload-scan-results \
  && rm -f /usr/local/bin/seal

# This image now contains:
# - Patched Newtonsoft.Json (10.0.3-sp1 or equivalent)
# - Updated OS packages with security fixes
# - Same vulnerable application code (for demo purposes)

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

ENTRYPOINT ["dotnet", "AppDemo.dll"]