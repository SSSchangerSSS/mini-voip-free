# Control service image (.NET 10 LTS) — build reproducibly, no floating tags (spec 3.2).
FROM mcr.microsoft.com/dotnet/sdk:10.0.403@sha256:de4fe90a98845d75910b9769662465c84de1a934665c431279d1382b2bddc02b AS build
WORKDIR /src
COPY src/ ./src/
RUN dotnet publish src/Smi.Control/Smi.Control.csproj -c Release -o /out /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0.14@sha256:de0ee358cdd672f7017a003bed21e9ac9ed48a27c922a59b18175b6e82fa7fee AS final
# non-root user, no shell writes to app dir; data lives on the mounted volume
RUN groupadd --system --gid 1001 smi \
    && useradd --system --uid 1001 --gid 1001 --no-create-home smi
WORKDIR /app
COPY --from=build /out ./
ENV ASPNETCORE_URLS=http://127.0.0.1:5080 \
    DOTNET_gcserver=0
USER smi
ENTRYPOINT ["dotnet", "Smi.Control.dll"]
