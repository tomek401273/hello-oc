# Etap 1: budowanie aplikacji
FROM registry.access.redhat.com/ubi9/openjdk-17:latest AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B package -DskipTests

# Etap 2: obraz uruchomieniowy
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest
WORKDIR /deployments
COPY --from=build /build/target/hello-logic-*.jar app.jar

# OpenShift uruchamia kontenery z losowym UID nalezacym do grupy root (GID 0),
# dlatego nie ustawiamy USER na konkretny numer ani nie wymagamy roota.
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
