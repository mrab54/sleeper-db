# Sleeper API Documentation

## Overview
The Sleeper API provides read-only access to fantasy football league data. This document covers the essential information for working with the API.

## Base URL
```
https://api.sleeper.app/v1
```

## Authentication
The Sleeper API is **publicly accessible** and requires **no authentication** or API keys.

## Rate Limiting
- No official rate limits documented
- Best practice: Stay under 1000 API calls per minute
- Implement reasonable delays between requests

## Primary League ID
```
1199102384316362752
```

## API Reference
For complete endpoint documentation, request/response schemas, and detailed parameter descriptions, see the **[OpenAPI/Swagger specification](./sleeper-api-swagger.yaml)**.


## Tools & Resources

- Use the Swagger file with tools like:
  - [Swagger UI](https://swagger.io/tools/swagger-ui/) for interactive documentation
  - [Postman](https://www.postman.com/) for API testing
  - [OpenAPI Generator](https://openapi-generator.tech/) for client SDK generation

## Support

For API issues or questions:
- Official documentation: https://docs.sleeper.com
- Community resources and discussions available on Sleeper's platform