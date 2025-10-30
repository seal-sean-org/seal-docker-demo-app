# original.Dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Copy project files and restore dependencies (including vulnerable Newtonsoft.Json 10.0.3)
COPY AppDemo.csproj .
RUN dotnet restore

# Copy the remaining source code and build+publish the app
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS final
WORKDIR /app

# Copy app binaries from build stage
COPY --from=build /app/publish ./

# The image contains Newtonsoft.Json 10.0.3 (vulnerable) in the app's published dependencies
EXPOSE 80
CMD ["dotnet", "AppDemo.dll"]