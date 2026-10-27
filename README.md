# nestapp

A minimal NestJS 11 API using TypeScript. Requires Node.js 24 and npm.

## Development

```sh
npm ci
npm run start:dev
```

The server uses port 3000 by default; set `PORT` to override it. No credentials or external services are required.

- `GET /` returns `Hello World!`
- `GET /health` returns `{"status":"ok"}`

## Validation

```sh
npm run build
npm test -- --runInBand
npm run test:e2e -- --runInBand
npx eslint "{src,test}/**/*.ts"
```

## Production startup

```sh
npm run build
npm run start:prod
```
