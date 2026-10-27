# Stage 1: Build the Flutter web application
FROM ubuntu:22.04 AS build

# Prerequisites
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa

# Setup Flutter
RUN git init /usr/local/flutter && git -C /usr/local/flutter remote add origin https://github.com/flutter/flutter.git && git -C /usr/local/flutter fetch --depth 1 origin refs/tags/3.47.2:refs/tags/3.47.2 && git -C /usr/local/flutter checkout --detach refs/tags/3.47.2 && test "$(git -C /usr/local/flutter rev-parse HEAD)" = d3b14c876900e553bc736ca19295fc09e3853e8e
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --enable-web

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY . .
ARG USE_SAME_ORIGIN=true
ARG BUILD_COMMIT=0000000000000000000000000000000000000000
RUN USE_SAME_ORIGIN=$USE_SAME_ORIGIN BUILD_COMMIT=$BUILD_COMMIT bash scripts/build-render-web.sh

# Stage 2: Serve the app with Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
