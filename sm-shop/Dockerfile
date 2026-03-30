FROM eclipse-temurin:11-jre
WORKDIR /opt/app
COPY target/shopizer.jar .
COPY files /files
CMD ["java", "-jar", "shopizer.jar"]
