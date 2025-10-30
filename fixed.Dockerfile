# ==========================================
# Seal Security Remediated ASP.NET Demo
# Automatically fixes vulnerabilities at build time
# ==========================================

# Build stage - identical to original
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Copy and restore dependencies (still vulnerable at this stage)
COPY AppDemo.csproj .
RUN dotnet restore

# Build application
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# Runtime stage with Seal Security integration
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS runtime
WORKDIR /app

# Copy published application
COPY --from=build /app/publish .

# Configure Seal Security
ARG SEAL_APP_FIX_MODE=all
ARG SEAL_OS_FIX_MODE=all  
ARG SEAL_PROJECT_ID=seal-docker-demo-app
ENV SEAL_USE_SEALED_NAMES=true

# Download Seal CLI
ADD --chmod=755 \
    https://github.com/seal-community/cli/releases/download/latest/seal-linux-amd64-latest \
    /usr/local/bin/seal

# 🛡️ Apply Seal Security fixes
RUN --mount=type=secret,id=SEAL_TOKEN,env=SEAL_TOKEN \
    # Fix application vulnerabilities (Newtonsoft.Json, etc.)
    SEAL_PROJECT=${SEAL_PROJECT_ID} \
    /usr/local/bin/seal fix \
        --mode=${SEAL_APP_FIX_MODE} \
        --upload-scan-results \
    && \
    # Fix OS-level vulnerabilities  
    SEAL_PROJECT=${SEAL_PROJECT_ID}-os \
    /usr/local/bin/seal fix os \
        --mode=${SEAL_OS_FIX_MODE} \
        --upload-scan-results \
    && \
    # Clean up CLI binary
    rm -f /usr/local/bin/seal

# ✅ This image now contains:
# - Patched Newtonsoft.Json (10.0.3-sp1 or equivalent)
# - Updated OS packages with security fixes
# - Same vulnerable application code (for demo purposes)

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

ENTRYPOINT ["dotnet", "AppDemo.dll"]