# SmartRent Backend

FastAPI backend for SmartRent platform - blockchain-enabled rental and asset-sharing system.

## 🚀 Quick Start

### Prerequisites
- Python 3.9+
- PostgreSQL (or Supabase account)
- Redis (optional, for caching)

### Installation

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate  # On Windows
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Run the server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

5. Access API documentation:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 📁 Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry point
│   ├── api/
│   │   ├── __init__.py
│   │   └── routes/
│   │       ├── users.py        # User endpoints
│   │       ├── assets.py       # Asset endpoints
│   │       └── rentals.py      # Rental endpoints
│   ├── core/
│   │   ├── config.py           # Configuration
│   │   └── web3_utils.py       # Web3 utilities
│   └── db/
│       ├── database.py         # Database connection
│       ├── models.py           # SQLAlchemy models
│       └── schema.py           # Pydantic schemas
├── requirements.txt
├── .env.example
└── README.md
```

## 🔗 API Endpoints

### Users
- `POST /api/v1/users` - Create user
- `GET /api/v1/users/{id}` - Get user by ID
- `GET /api/v1/users/wallet/{address}` - Get user by wallet
- `PUT /api/v1/users/{id}` - Update user

### Assets
- `POST /api/v1/assets` - Create asset
- `GET /api/v1/assets` - List assets
- `GET /api/v1/assets/{id}` - Get asset details
- `PUT /api/v1/assets/{id}` - Update asset
- `POST /api/v1/assets/{id}/toggle-availability` - Toggle availability

### Rentals
- `POST /api/v1/rentals` - Create rental
- `GET /api/v1/rentals` - List rentals
- `GET /api/v1/rentals/{id}` - Get rental details
- `POST /api/v1/rentals/{id}/activate` - Activate rental
- `POST /api/v1/rentals/{id}/complete` - Complete rental
- `POST /api/v1/rentals/{id}/cancel` - Cancel rental

## 🔧 Development

### Run tests:
```bash
pytest
```

### Code formatting:
```bash
black app/
```

### Type checking:
```bash
mypy app/
```

## 📝 TODO

See [DEVELOPMENT_CHECKLIST.md](../../DEVELOPMENT_CHECKLIST.md) for detailed development tasks.

## 📄 License

MIT
