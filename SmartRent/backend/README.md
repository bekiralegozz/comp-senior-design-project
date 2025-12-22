# SmartRent Backend API

A FastAPI-based backend for the SmartRent blockchain-enabled rental and asset-sharing platform.

## Features

- 🚀 **FastAPI** with automatic API documentation
- 🔗 **Web3 Integration** for Ethereum blockchain interaction
- 🗄️ **PostgreSQL** database with SQLAlchemy ORM
- 📝 **Pydantic** models for data validation
- 🔐 **Security** features ready for authentication
- 🐳 **Docker** containerization
- 📊 **Database migrations** with Alembic (ready to configure)

## API Endpoints

### Health Check
- `GET /ping` - Health check endpoint
- `GET /` - API information

### Users
- `GET /api/v1/users/` - List all users
- `POST /api/v1/users/` - Create new user
- `GET /api/v1/users/{user_id}` - Get user by ID
- `GET /api/v1/users/wallet/{wallet_address}` - Get user by wallet
- `PUT /api/v1/users/{user_id}` - Update user
- `DELETE /api/v1/users/{user_id}` - Deactivate user

### Assets
- `GET /api/v1/assets/` - List all assets
- `POST /api/v1/assets/` - Create new asset
- `GET /api/v1/assets/{asset_id}` - Get asset by ID
- `GET /api/v1/assets/owner/{owner_id}` - Get assets by owner
- `PUT /api/v1/assets/{asset_id}` - Update asset
- `DELETE /api/v1/assets/{asset_id}` - Delete asset

### Rentals
- `GET /api/v1/rentals/` - List all rentals
- `POST /api/v1/rentals/` - Create new rental
- `GET /api/v1/rentals/{rental_id}` - Get rental by ID
- `GET /api/v1/rentals/user/{user_id}` - Get user's rentals
- `POST /api/v1/rentals/{rental_id}/activate` - Activate rental
- `POST /api/v1/rentals/{rental_id}/complete` - Complete rental

## Quick Start

### Prerequisites

- Python 3.11+
- PostgreSQL 13+
- Redis (optional, for caching)

### Environment Setup

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\\Scripts\\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set environment variables:
```bash
# Create .env file
cp .env.example .env

# Edit .env with your configuration
DATABASE_URL=postgresql://username:password@localhost:5432/smartrent_db
WEB3_PROVIDER_URL=https://goerli.infura.io/v3/YOUR_INFURA_PROJECT_ID
SECRET_KEY=your-secret-key-here
```

### Database Setup

1. Create PostgreSQL database:
```sql
CREATE DATABASE smartrent_db;
CREATE USER smartrent WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE smartrent_db TO smartrent;
```

2. Initialize database tables:
```bash
# The app will create tables automatically on first run
# Or use Alembic for migrations (recommended for production)
```

### Running the Application

#### Local Development
```bash
# From the backend directory
python -m app.main

# Or use uvicorn directly
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

#### Using Docker
```bash
# Build and run with Docker Compose (from project root)
docker-compose up --build

# Or build and run manually
docker build -t smartrent-backend .
docker run -p 8000:8000 smartrent-backend
```

### API Documentation

Once the server is running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENVIRONMENT` | development | App environment |
| `DEBUG` | True | Debug mode |
| `DATABASE_URL` | postgresql://... | PostgreSQL connection string |
| `WEB3_PROVIDER_URL` | https://goerli.infura.io/... | Ethereum node URL |
| `PRIVATE_KEY` | "" | Ethereum private key for transactions |
| `SECRET_KEY` | change-this | JWT secret key |
| `REDIS_URL` | redis://localhost:6379 | Redis connection string |

### Web3 Configuration

The backend integrates with Ethereum blockchain for:
- Asset tokenization (NFTs)
- Rental agreements (smart contracts)
- Payment processing

Configure your Web3 provider (Infura, Alchemy, etc.) and deploy the smart contracts from the `blockchain/` module.

## Development

### Code Quality
```bash
# Format code
black app/

# Lint code
flake8 app/

# Type checking
mypy app/
```

### Testing
```bash
# Run tests
pytest

# With coverage
pytest --cov=app tests/
```

### Database Migrations

For production deployments, set up Alembic:

```bash
# Initialize Alembic
alembic init alembic

# Create migration
alembic revision --autogenerate -m "Initial migration"

# Apply migration
alembic upgrade head
```

## Deployment

### Production Checklist

- [ ] Set `ENVIRONMENT=production`
- [ ] Use strong `SECRET_KEY`
- [ ] Configure production database
- [ ] Set up SSL/TLS
- [ ] Configure firewall rules
- [ ] Set up monitoring and logging
- [ ] Configure backup strategy

### Docker Production

```dockerfile
# Use production-ready configuration
ENV ENVIRONMENT=production
ENV DEBUG=False
```

## Integration with Other Modules

- **Blockchain**: Deploy smart contracts and update contract addresses in config
- **Mobile**: Mobile app connects to this API for all backend operations
- **IoT**: IoT devices can call specific endpoints for status updates

## Contributing

1. Follow PEP 8 style guidelines
2. Add tests for new features
3. Update documentation
4. Use meaningful commit messages

## License

This project is part of the SmartRent platform.









