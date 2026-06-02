# Port Configuration Guide (Still not decided yet!!!)

## Port Scheme

Meritbox API uses different ports for different environments:

- **Production**: Port `3000`
- **UAT**: Port `3001`
- **Local Development**: Port `3002` (default)

## Configuration

### Local Development (Port 3002)

Default configuration in `.env`:

```bash
PORT=3002
VITE_REACT_APP_CLIENT_BASE_URL=http://localhost:3002
VITE_REACT_APP_PORT_MAP=3002:3002
```

### UAT Environment (Port 3001)

To deploy to UAT, update `.env`:

```bash
NODE_ENV=uat
PORT=3001
VITE_REACT_APP_CLIENT_BASE_URL=https://uat.meritbox.me
VITE_REACT_APP_PORT_MAP=3001:3001
```

### Production Environment (Port 3000)

To deploy to production, update `.env`:

```bash
NODE_ENV=production
PORT=3000
VITE_REACT_APP_CLIENT_BASE_URL=https://meritbox.me
VITE_REACT_APP_PORT_MAP=3000:3000
```

## Running Locally

The app will automatically use port 3002 for local development:

```bash
# Using Docker
sh dev.sh

# Or directly with npm/yarn
npm run dev
```

The port is configured in:

- `vite.config.ts` - Reads from `VITE_PORT` or `PORT` env variable
- `docker-compose.dev.yaml` - Uses `VITE_REACT_APP_PORT_MAP`
- `.env` - Contains port configuration

## Port Availability

Ports 3000, 3001, and 3002 are safe to use on macOS and don't conflict with system services.
