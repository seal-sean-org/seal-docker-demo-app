# ========================================
# Vulnerable ASP.NET Demo - Original Build
# Contains intentional security vulnerabilities
# ========================================

FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Copy project file and restore vulnerable dependencies
COPY AppDemo.csproj .
RUN dotnet restore

# Copy source code and build application
COPY . .
# Publish the specific project to avoid MSBuild ambiguity when a solution file is present
RUN dotnet publish AppDemo.csproj -c Release -o /app/publish --no-restore

# Runtime image with vulnerabilities
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS runtime
WORKDIR /app

# Copy published application
COPY --from=build /app/publish .

# WARNING: This image contains:
# - Newtonsoft.Json 10.0.3 (CVE-2024-21907)
# - Insecure deserialization code (CWE-502)
# - Potentially vulnerable OS packages

EXPOSE 80
ENTRYPOINT ["dotnet", "AppDemo.dll"]