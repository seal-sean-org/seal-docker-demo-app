# fixed.Dockerfile
# Stage 1: Build (same as original build stage)
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src
COPY AppDemo.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Runtime (start same as original)
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS final
WORKDIR /app
COPY --from=build /app/publish ./

# Seal Security integration
ARG SEAL_APP_FIX_MODE=all
ARG SEAL_OS_FIX_MODE=all
ENV SEAL_USE_SEALED_NAMES=true

# Download Seal Security CLI (latest release)
ADD --chmod=755 https://github.com/seal-community/cli/releases/download/latest/seal-linux-amd64-latest seal

# Run Seal fixes: 
#  - Use secret SEAL_TOKEN for authentication to Seal platform (for downloading fixes & uploading results)
#  - Fix application package vulnerabilities (SEAL_PROJECT=app-demo)
#  - Fix OS-level vulnerabilities (SEAL_PROJECT=os-demo)
RUN --mount=type=secret,id=SEAL_TOKEN,env=SEAL_TOKEN \
    SEAL_PROJECT=app-demo ./seal fix --mode=$SEAL_APP_FIX_MODE --upload-scan-results && \
    SEAL_PROJECT=os-demo  ./seal fix os --mode=$SEAL_OS_FIX_MODE --upload-scan-results --remove-cli

# Expose port and set entrypoint (unchanged)
EXPOSE 80
CMD ["dotnet", "AppDemo.dll"]