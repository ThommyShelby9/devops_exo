# MedSecure - Multi-stage Dockerfile for .NET 8
# Optimized for production deployment with HDS compliance

# ============================================
# Stage 1: Build
# ============================================
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
ARG BUILD_VERSION=1.0.0
WORKDIR /src

# Copy solution and project files (layer caching optimization)
COPY ["eShopOnWeb.sln", "./"]
COPY ["src/Web/Web.csproj", "src/Web/"]
COPY ["src/ApplicationCore/ApplicationCore.csproj", "src/ApplicationCore/"]
COPY ["src/Infrastructure/Infrastructure.csproj", "src/Infrastructure/"]
COPY ["src/BlazorAdmin/BlazorAdmin.csproj", "src/BlazorAdmin/"]
COPY ["src/BlazorShared/BlazorShared.csproj", "src/BlazorShared/"]
COPY ["src/PublicApi/PublicApi.csproj", "src/PublicApi/"]
COPY ["Directory.Packages.props", "./"]

# Restore dependencies
RUN dotnet restore "src/Web/Web.csproj"

# Copy all source code
COPY . .

# Build application
WORKDIR "/src/src/Web"
RUN dotnet build "Web.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/build \
    /p:Version=$BUILD_VERSION \
    --no-restore

# ============================================
# Stage 2: Publish
# ============================================
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
ARG BUILD_VERSION=1.0.0

RUN dotnet publish "Web.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/publish \
    /p:UseAppHost=false \
    /p:Version=$BUILD_VERSION \
    --no-build

# ============================================
# Stage 3: Runtime (Production)
# ============================================
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final

# Security: Run as non-root user (HDS requirement)
RUN groupadd -r medsecure && useradd -r -g medsecure medsecure

# Install curl for health checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy published application
COPY --from=publish /app/publish .

# Change ownership to non-root user
RUN chown -R medsecure:medsecure /app

# Switch to non-root user
USER medsecure

# Expose ports (non-privileged ports)
EXPOSE 8080
EXPOSE 8081

# Health check (HDS compliance - monitoring)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Environment variables
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Metadata labels (OCI standard + HDS compliance)
LABEL org.opencontainers.image.title="MedSecure Web Application" \
      org.opencontainers.image.description="HealthTech platform - HDS compliant" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.vendor="MedSecure Team" \
      org.opencontainers.image.licenses="MIT" \
      com.medsecure.compliance="HDS,RGPD,ISO27001" \
      com.medsecure.security="TLS1.3,TDE,AlwaysEncrypted"

ENTRYPOINT ["dotnet", "Web.dll"]
