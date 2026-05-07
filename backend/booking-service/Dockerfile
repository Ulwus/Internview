FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY . .
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw -DskipTests --no-transfer-progress \
    -Dmaven.repo.local=/root/.m2 \
    -Dmaven.wagon.http.retryHandler.count=10 \
    -Dmaven.wagon.http.pool=false \
    -Dmaven.wagon.rto=600000 \
    package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/target/*.jar /app/app.jar
EXPOSE 8084
ENTRYPOINT ["java","-jar","/app/app.jar"]

