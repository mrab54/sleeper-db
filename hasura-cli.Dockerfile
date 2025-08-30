# Hasura CLI with metadata auto-apply
FROM hasura/graphql-engine:v2.36.0.cli-migrations-v3

# Copy metadata
COPY ./hasura/metadata /hasura-metadata

# The CLI migrations image will automatically apply metadata on startup