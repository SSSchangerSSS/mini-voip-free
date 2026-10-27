# Control service image (.NET 10 LTS) — build reproducibly, no floating tags (spec 3.2).
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/ ./src/
RUN dotnet publish src/Smi.Control/Smi.Control.csproj -c Release -o /out /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
# non-root user, no shell writes to app dir; data lives on the mounted volume
RUN useradd --system --uid 1001 --no-create-home smi
WORKDIR /app
COPY --from=build /out ./
ENV ASPNETCORE_URLS=http://127.0.0.1:5080 \
    DOTNET_gcserver=0
USER smi
ENTRYPOINT ["dotnet", "Smi.Control.dll"]
