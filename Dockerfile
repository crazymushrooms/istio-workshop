ARG VERSION="0.0.1-SNAPSHOT"
FROM amazoncorretto:17-alpine as corretto-jdk

# required for strip-debug to work
RUN apk add --no-cache binutils

# Build small JRE image
RUN jlink \
         --add-modules ALL-MODULE-PATH \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /jre

#COPY . /src
#WORKDIR /src
#RUN ./gradlew build --no-daemon

FROM alpine:latest
ARG VERSION
ARG JAVA_OPTS="-Dreactor.netty.http.server.accessLogEnabled=true"
ARG PROFILE

ENV JAVA_OPTS=${JAVA_OPTS}
ENV PROFILE=${PROFILE}
ENV JAVA_HOME=/jre
ENV PATH="${JAVA_HOME}/bin:${PATH}"

COPY --from=corretto-jdk /jre $JAVA_HOME

EXPOSE 8080 8181
COPY ./build/libs/demo-${VERSION}.jar /app/demo.jar
RUN addgroup -g 2000 --system demo && adduser -u 2000 -h /app -D -G demo demo && chown -R demo:demo /app/demo.jar
WORKDIR /app
USER demo

ENTRYPOINT ["sh", "-c", "/jre/bin/java -Dspring.profiles.active=$(echo ${PROFILE}) ${JAVA_OPTS} -jar demo.jar"]
