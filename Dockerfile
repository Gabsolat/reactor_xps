# SWI-Prolog expert system web service (pure Prolog at runtime)
FROM swipl:stable
WORKDIR /app
COPY src ./src
COPY data ./data
COPY server ./server
ENV PORT=10000
EXPOSE 10000
ENTRYPOINT []
CMD ["swipl", "-q", "-s", "server/server.pl", "-g", "start", "-t", "halt"]
