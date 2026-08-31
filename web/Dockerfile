# Built from the repository root so the shared question bank can be copied in.
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY web/IqTest.sln ./web/
COPY web/src/ ./web/src/
COPY web/tests/ ./web/tests/
RUN dotnet restore web/src/IqTest.Web/IqTest.Web.csproj

RUN dotnet publish web/src/IqTest.Web/IqTest.Web.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish ./
# The item bank is generated from the Flutter project and shared by both.
COPY shared/questions.json ./shared/questions.json

ENV QuestionBank__Path=/app/shared/questions.json
EXPOSE 8080
ENTRYPOINT ["dotnet", "IqTest.Web.dll"]
