# Сборка статического бинарника: на сервере не нужен ни Dart SDK, ни pub-кэш.
FROM dart:3.6 AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Рантайм без Dart: меньше образ и меньше того, что может быть уязвимым.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

# Секреты и адреса приходят окружением, в образ не зашиваются.
EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
