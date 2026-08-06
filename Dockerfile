# Etap 1: budowanie aplikacji
FROM registry.access.redhat.com/ubi9/openjdk-17:latest AS build
USER 0
WORKDIR /build
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B package -DskipTests

# Etap 2: obraz uruchomieniowy — BEZ ZMIAN
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest
WORKDIR /deployments
COPY --from=build /build/target/hello-logic-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]